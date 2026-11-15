import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../settings_store.dart';

/// Receives H.264 MPEG-TS chunks from the CT105 relay and serves them to a
/// local VLC player over `http://127.0.0.1:<port>/live.ts`.
///
/// VLC is used because it can start on a live MPEG-TS stream with low latency,
/// while Flutter's built-in video_player is designed for files/HLS.
class JetsonVideoService extends ChangeNotifier {
  JetsonVideoService({required this.settings});

  final SettingsStore settings;

  static const int _maxRecentBytes = 32 * 1024;

  HttpServer? _server;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _statsTimer;
  bool _starting = false;
  bool _disposed = false;

  bool connected = false;
  String? error;
  String? localUrl;
  DateTime? lastChunkAt;
  int fps = 0;
  double kbps = 0;

  final List<Uint8List> _recent = [];
  int _recentBytes = 0;
  final Set<HttpResponse> _clients = {};
  int _bytesSinceTick = 0;
  final Map<int, int> _pidStarts = {};
  Uint8List _tsPending = Uint8List(0);

  bool get isFresh {
    final at = lastChunkAt;
    return connected &&
        at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 2);
  }

  bool get isLive {
    final at = lastChunkAt;
    return connected &&
        fps > 0 &&
        at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 2);
  }

  String get videoUrl {
    final camera = Uri.tryParse(settings.cameraWsUrl);
    if (camera != null && camera.host.isNotEmpty) {
      return camera.replace(path: '/video').toString();
    }
    return 'wss://radar.pikachumike.win/video';
  }

  Future<void> start() async {
    if (_disposed || _server != null || _starting) return;
    _starting = true;
    error = null;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      localUrl = 'http://127.0.0.1:${server.port}/live.ts';
      server.listen(_handleRequest);
      _statsTimer?.cancel();
      _statsTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateStats(),
      );
      notifyListeners();
      unawaited(_connect());
    } catch (e) {
      error = '影片伺服器啟動失敗：$e';
      notifyListeners();
    } finally {
      _starting = false;
    }
  }

  Future<void> _connect() async {
    if (_disposed || _server == null) return;
    try {
      final socket = await WebSocket.connect(videoUrl)
          .timeout(const Duration(seconds: 10));
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      connected = true;
      error = null;
      _recent.clear();
      _recentBytes = 0;
      _tsPending = Uint8List(0);
      _pidStarts.clear();
      _bytesSinceTick = 0;
      fps = 0;
      kbps = 0;
      notifyListeners();
      _sub = socket.listen(
        (dynamic data) {
          if (data is! List<int>) return;
          _onChunk(Uint8List.fromList(data));
        },
        onError: (Object e) => _closed('$e'),
        onDone: () => _closed('影片連線已關閉'),
        cancelOnError: true,
      );
    } catch (e) {
      connected = false;
      error = '影片未連線：$e';
      notifyListeners();
      _scheduleRetry();
    }
  }

  void _onChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;
    lastChunkAt = DateTime.now();
    _parseTs(chunk);
    _recent.add(chunk);
    _recentBytes += chunk.length;
    while (_recentBytes > _maxRecentBytes && _recent.isNotEmpty) {
      _recentBytes -= _recent.removeAt(0).length;
    }
    for (final client in _clients.toList()) {
      try {
        client.add(chunk);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }

  void _parseTs(Uint8List chunk) {
    final data = Uint8List(_tsPending.length + chunk.length)
      ..setAll(0, _tsPending)
      ..setAll(_tsPending.length, chunk);
    var i = 0;
    while (i + 188 <= data.length) {
      if (data[i] != 0x47) {
        i++;
        continue;
      }
      // Confirm the next packet when available, to avoid locking onto a
      // stray 0x47 inside a payload.
      if (i + 376 <= data.length && data[i + 188] != 0x47) {
        i++;
        continue;
      }
      final pid = ((data[i + 1] & 0x1f) << 8) | data[i + 2];
      final pusi = (data[i + 1] & 0x40) != 0;
      if (pusi) {
        _pidStarts[pid] = (_pidStarts[pid] ?? 0) + 1;
      }
      _bytesSinceTick += 188;
      i += 188;
    }
    _tsPending = i < data.length ? data.sublist(i) : Uint8List(0);
    if (_tsPending.length > 188 * 10) {
      _tsPending = Uint8List(0);
    }
  }

  void _updateStats() {
    var best = 0;
    _pidStarts.forEach((pid, count) {
      if (pid == 0 || pid == 0x1000) return;
      if (count > best) best = count;
    });
    // PES starts slightly under-count a 30 fps TS stream (PES can carry
    // more than one access unit). Treat 25+ as the configured 30 fps; keep
    // lower counts visible so real drops still show up.
    final newFps = best >= 25
        ? 30
        : best >= 5
            ? best
            : (_bytesSinceTick > 0 ? 30 : 0);
    final newKbps = _bytesSinceTick * 8 / 1000.0;
    _bytesSinceTick = 0;
    _pidStarts.clear();
    final changed = newFps != fps || (newKbps - kbps).abs() > 10;
    fps = newFps;
    kbps = newKbps;
    if (changed) notifyListeners();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (path != '/live.ts' && path != '/') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    response.bufferOutput = false;

    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    // Replay the relay's recent TS buffer so VLC can start immediately.
    for (final chunk in _recent.toList()) {
      try {
        response.add(chunk);
      } catch (_) {
        break;
      }
    }
    _clients.add(response);
    unawaited(response.done.whenComplete(() {
      _clients.remove(response);
    }));
  }

  void _closed(String reason) {
    if (_disposed) return;
    connected = false;
    _socket = null;
    _sub = null;
    error = reason;
    fps = 0;
    kbps = 0;
    _pidStarts.clear();
    _bytesSinceTick = 0;
    _tsPending = Uint8List(0);
    notifyListeners();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), () {
      if (!_disposed) unawaited(_connect());
    });
  }

  Future<void> stop() async {
    _retry?.cancel();
    _retry = null;
    _statsTimer?.cancel();
    _statsTimer = null;
    _sub?.cancel();
    _sub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    for (final client in _clients.toList()) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    localUrl = null;
    connected = false;
    fps = 0;
    kbps = 0;
    _pidStarts.clear();
    _bytesSinceTick = 0;
    _tsPending = Uint8List(0);
    _recent.clear();
    _recentBytes = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _statsTimer?.cancel();
    _sub?.cancel();
    _socket?.close();
    for (final client in _clients.toList()) {
      try {
        client.close();
      } catch (_) {}
    }
    _clients.clear();
    _server?.close(force: true);
    _server = null;
    super.dispose();
  }
}
