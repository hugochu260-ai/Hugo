import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/radar_models.dart';
import 'mock_radar_source.dart';
import 'radar_source.dart';
import 'usb_radar_source.dart';
import 'ws_radar_source.dart';

/// Owns the active radar source and its latest scans.
class RadarService extends ChangeNotifier {
  RadarSource? _source;
  StreamSubscription<RadarScan>? _sub;
  final List<RadarScan> _pending = <RadarScan>[];
  final List<RadarScan> _history = <RadarScan>[];
  Timer? _staleTimer;

  RadarStatus status = const RadarStatus();
  double angleOffsetDeg = 0;
  String mode = 'usb';

  RadarScan? get latest => status.scan;
  bool get isConnected => status.connected;
  bool get hasFreshScan => status.hasFreshScan;

  /// True only when the WebSocket is connected AND fresh radar data arrived.
  /// The relay may keep the last scan after radar-push disconnects, so
  /// [isConnected] alone is not enough for the UI.
  bool get isLive => status.state == RadarConnectionState.connected &&
      status.hasFreshScan;
  List<RadarScan> get history => List.unmodifiable(_history);

  Future<void> start({
    required String mode,
    required String wsUrl,
    double angleOffsetDeg = 0,
  }) async {
    await stop();
    this.mode = mode;
    this.angleOffsetDeg = angleOffsetDeg;
    final RadarSource source;
    switch (mode) {
      case 'ws':
        source = WsRadarSource(wsUrl);
        break;
      case 'mock':
        source = MockRadarSource();
        break;
      case 'usb':
      default:
        source = UsbRadarSource();
        break;
    }
    _source = source;
    status = RadarStatus(
      state: RadarConnectionState.connecting,
      sourceLabel: source.label,
    );
    notifyListeners();

    _sub = source.scans.listen(
      _onScan,
      onError: (Object e) {
        status = RadarStatus(
          state: RadarConnectionState.error,
          sourceLabel: source.label,
          scan: status.scan,
          error: '$e',
        );
        notifyListeners();
      },
    );
    try {
      await source.start();
      status = RadarStatus(
        state: RadarConnectionState.connected,
        sourceLabel: source.label,
        scan: status.scan,
      );
      notifyListeners();
      _startStaleTimer();
    } catch (e) {
      status = RadarStatus(
        state: RadarConnectionState.error,
        sourceLabel: source.label,
        error: '$e',
      );
      notifyListeners();
    }
  }

  void _onScan(RadarScan raw) {
    final points = angleOffsetDeg == 0
        ? raw.points
        : raw.points
            .map((p) => RadarPoint(
                  angleDeg: (p.angleDeg + angleOffsetDeg) % 360.0,
                  rangeM: p.rangeM,
                  intensity: p.intensity,
                ))
            .toList(growable: false);
    final scan = RadarScan(points: points, at: raw.at);
    _pending.add(scan);
    while (_pending.length > 10) {
      _pending.removeAt(0);
    }
    _history.add(scan);
    while (_history.length > 30) {
      _history.removeAt(0);
    }
    status = status.copyWith(
      state: RadarConnectionState.connected,
      scan: scan,
      error: null,
      hz: _estimateHz(),
    );
    notifyListeners();
  }

  double _estimateHz() {
    if (_history.length < 2) return 0;
    final a = _history[_history.length - 1].at;
    final b = _history[_history.length - 2].at;
    final ms = a.difference(b).inMilliseconds;
    return ms <= 0 ? 0 : (1000.0 / ms);
  }

  void _startStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final scan = status.scan;
      if (status.state != RadarConnectionState.connected || scan == null) {
        return;
      }
      final stale =
          DateTime.now().difference(scan.at).inMilliseconds > 2000;
      if (stale && status.hz != 0) {
        status = status.copyWith(hz: 0);
        notifyListeners();
      }
    });
  }

  /// Scans accumulated since the last drain (oldest first, max 10).
  List<RadarScan> drainScans() {
    final out = List<RadarScan>.from(_pending);
    _pending.clear();
    return out;
  }

  Future<void> stop() async {
    _staleTimer?.cancel();
    _staleTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _source?.stop();
    } catch (_) {}
    _source = null;
    status = const RadarStatus();
    _pending.clear();
    _history.clear();
    notifyListeners();
  }

  Future<void> restart({
    required String wsUrl,
    double? angleOffsetDeg,
  }) async {
    final previous = this.angleOffsetDeg;
    await start(
      mode: mode,
      wsUrl: wsUrl,
      angleOffsetDeg: angleOffsetDeg ?? previous,
    );
  }

  /// Front/rear distances in metres for the current scan.
  double? get frontM => status.scan?.nearestInSector(0);
  double? get rearM => status.scan?.nearestInSector(180);

  /// Nearest point across the whole scan (for diagnostics).
  double? get nearestM {
    final scan = status.scan;
    if (scan == null || scan.points.isEmpty) return null;
    var best = double.infinity;
    for (final p in scan.points) {
      if (p.rangeM < best) best = p.rangeM;
    }
    return best.isFinite ? best : null;
  }

  /// Convert a normalised angle (0..360) to radians, +Y forward.
  static double toRadians(double deg) => deg * math.pi / 180.0;

  @override
  void dispose() {
    _staleTimer?.cancel();
    super.dispose();
  }
}
