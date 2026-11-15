import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../settings_store.dart';

/// Receives live JPEG frames from the Jetson camera via the CT105 relay.
class JetsonCameraService extends ChangeNotifier {
  JetsonCameraService({required this.settings});

  final SettingsStore settings;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  bool _starting = false;
  bool _disposed = false;

  Uint8List? frame;
  DateTime? updatedAt;
  bool connected = false;
  bool connecting = false;
  String? error;

  int _frames = 0;
  DateTime _fpsAt = DateTime.now();
  double fps = 0;

  bool get isFresh =>
      updatedAt != null &&
      DateTime.now().difference(updatedAt!).inSeconds < 2;

  int get ageSeconds => updatedAt == null
      ? 9999
      : DateTime.now().difference(updatedAt!).inSeconds;

  Future<void> start() async {
    if (_disposed || _starting || _socket != null) return;
    _starting = true;
    connecting = true;
    error = null;
    notifyListeners();
    final url = settings.cameraWsUrl.trim();
    try {
      final socket = await WebSocket.connect(url)
          .timeout(const Duration(seconds: 10));
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      connected = true;
      connecting = false;
      error = null;
      notifyListeners();
      _sub = socket.listen(
        (data) {
          if (data is List<int> && data.isNotEmpty) {
            frame = Uint8List.fromList(data);
            updatedAt = DateTime.now();
            _frames++;
            final now = DateTime.now();
            final ms = now.difference(_fpsAt).inMilliseconds;
            if (ms >= 1000) {
              fps = _frames * 1000.0 / ms;
              _frames = 0;
              _fpsAt = now;
            }
            notifyListeners();
          }
        },
        onError: (Object e) => _closed('$e'),
        onDone: () => _closed('連線已關閉'),
        cancelOnError: true,
      );
    } catch (e) {
      connecting = false;
      connected = false;
      error = '$e';
      notifyListeners();
      _scheduleRetry();
    } finally {
      _starting = false;
    }
  }

  void _closed(String reason) {
    if (_disposed) return;
    connected = false;
    _socket = null;
    _sub = null;
    error = reason;
    notifyListeners();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), () {
      if (!_disposed) start();
    });
  }

  Future<void> stop() async {
    _retry?.cancel();
    _retry = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    connected = false;
    connecting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _sub?.cancel();
    _socket?.close();
    super.dispose();
  }
}
