import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../models/radar_models.dart';
import 'radar_source.dart';

/// Radar relayed over WebSocket (works on Android and iOS).
///
/// Accepts either:
///   {"points": [[x_m, y_m], ...]}            world coordinates
///   {"angles": [...], "ranges": [...]}       polar
///   {"points": [{"angle": 12.3, "range": 1.2}, ...]}
class WsRadarSource implements RadarSource {
  WsRadarSource(this.url);

  final String url;
  final StreamController<RadarScan> _controller =
      StreamController<RadarScan>.broadcast();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;

  @override
  String get label => 'WebSocket ${Uri.tryParse(url)?.host ?? url}';

  @override
  bool get isSupported => true;

  @override
  Stream<RadarScan> get scans => _controller.stream;

  @override
  Future<void> start() async {
    final uri = Uri.parse(url);
    _socket = await WebSocket.connect(uri.toString())
        .timeout(const Duration(seconds: 8));
    _sub = _socket!.listen((data) {
      try {
        final json = jsonDecode(data as String);
        if (json is! Map) return;
        final points = _parsePoints(json);
        if (points.length >= 4 && !_controller.isClosed) {
          _controller.add(RadarScan(points: points, at: _timestamp(json)));
        }
      } catch (_) {}
    }, onError: (Object e) {
      if (!_controller.isClosed) _controller.addError(e);
    });
  }

  DateTime? _timestamp(Map json) {
    final raw = json['timestamp_ms'];
    if (raw is num) {
      final t = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
      final now = DateTime.now();
      // Keep the real data age so a relay-cached old scan is not shown as
      // freshly connected. Ignore obviously wrong clocks.
      // A timestamp from hours ago is still valid: it means the relay's
      // cached scan is stale and must not be shown as a fresh connection.
      if (t.isAfter(DateTime(2020)) &&
          t.isBefore(now.add(const Duration(minutes: 5)))) {
        return t;
      }
    }
    return null;
  }

  List<RadarPoint> _parsePoints(Map json) {
    final out = <RadarPoint>[];
    final angles = json['angles'];
    final ranges = json['ranges'];
    if (angles is List && ranges is List && angles.length == ranges.length) {
      for (var i = 0; i < angles.length; i++) {
        final a = (angles[i] as num).toDouble();
        final r = (ranges[i] as num).toDouble();
        if (r > 0.05 && r < 25) {
          out.add(RadarPoint(angleDeg: a % 360, rangeM: r));
        }
      }
      return out;
    }
    final pts = json['points'];
    if (pts is List) {
      for (final p in pts) {
        if (p is List && p.length >= 2) {
          final x = (p[0] as num).toDouble();
          final y = (p[1] as num).toDouble();
          final r = math.sqrt(x * x + y * y);
          if (r > 0.05 && r < 25) {
            final a = math.atan2(x, y) * 180.0 / math.pi;
            out.add(RadarPoint(angleDeg: (a + 360) % 360, rangeM: r));
          }
        } else if (p is Map) {
          final a = (p['angle'] as num?)?.toDouble();
          final r = (p['range'] as num?)?.toDouble();
          if (a != null && r != null && r > 0.05 && r < 25) {
            out.add(RadarPoint(angleDeg: (a + 360) % 360, rangeM: r));
          }
        }
      }
    }
    return out;
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }
}
