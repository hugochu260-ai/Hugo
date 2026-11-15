import 'dart:typed_data';

import '../../models/radar_models.dart';

/// CRC8 lookup table (poly 0x4D, init 0).
final List<int> _crcTable = List<int>.generate(256, (i) {
  var crc = i;
  for (var b = 0; b < 8; b++) {
    crc = (crc & 0x80) != 0 ? ((crc << 1) ^ 0x4D) & 0xFF : (crc << 1) & 0xFF;
  }
  return crc;
});

int crc8(List<int> data, [int start = 0, int? end]) {
  var crc = 0;
  final stop = end ?? data.length;
  for (var i = start; i < stop; i++) {
    crc = _crcTable[crc ^ (data[i] & 0xFF)];
  }
  return crc;
}

/// Parses STL-27L 47-byte packets and assembles full 360° scans.
class Stl27lParser {
  static const int frameSize = 47;
  static const int header0 = 0x54;
  static const int header1 = 0x2C;
  static const int pointsPerPacket = 12;
  static const double minRangeM = 0.05;
  static const double maxRangeM = 25.0;
  static const int minIntensity = 5;
  static const int minScanPoints = 220;
  static const int minRawSamples = 500;

  final List<int> _buffer = <int>[];
  final List<RadarPoint> _points = <RadarPoint>[];
  double? _lastAngle;
  int _rawSamples = 0;

  int badCrc = 0;
  int frames = 0;

  List<RadarScan> feed(Uint8List chunk) {
    _buffer.addAll(chunk);
    if (_buffer.length > 256 * 1024) {
      _buffer.removeRange(0, _buffer.length - 128 * 1024);
    }

    final completed = <RadarScan>[];
    var cursor = 0;
    while (true) {
      final start = _findHeader(cursor);
      if (start < 0) {
        if (_buffer.length > 1) {
          _buffer.removeRange(0, _buffer.length - 1);
        }
        break;
      }
      if (_buffer.length - start < frameSize) {
        if (start > 0) _buffer.removeRange(0, start);
        break;
      }
      final frame = _buffer.sublist(start, start + frameSize);
      if (crc8(frame, 0, frameSize - 1) != (frame[frameSize - 1] & 0xFF)) {
        badCrc++;
        cursor = start + 1;
        continue;
      }
      frames++;
      final scan = _consumeFrame(frame);
      if (scan != null) completed.add(scan);
      cursor = start + frameSize;
    }
    if (cursor > 0) _buffer.removeRange(0, cursor);
    return completed;
  }

  int _findHeader(int from) {
    for (var i = from; i + 1 < _buffer.length; i++) {
      if ((_buffer[i] & 0xFF) == header0 &&
          (_buffer[i + 1] & 0xFF) == header1) {
        return i;
      }
    }
    return -1;
  }

  int _u16(List<int> data, int offset) =>
      (data[offset] & 0xFF) | ((data[offset + 1] & 0xFF) << 8);

  RadarScan? _consumeFrame(List<int> frame) {
    final startDeg = _u16(frame, 4) / 100.0;
    final endDeg = _u16(frame, 42) / 100.0;
    var span = (endDeg - startDeg) % 360.0;
    if (span < 0) span += 360.0;

    RadarScan? completed;
    for (var i = 0; i < pointsPerPacket; i++) {
      final native =
          (startDeg + span * i / (pointsPerPacket - 1)) % 360.0;
      if (_lastAngle != null && _lastAngle! > 300.0 && native < 60.0) {
        completed = _finishScan();
      }
      _lastAngle = native;
      _rawSamples++;

      final offset = 6 + 3 * i;
      final range = _u16(frame, offset) / 1000.0;
      final intensity = frame[offset + 2] & 0xFF;
      if (range >= minRangeM &&
          range <= maxRangeM &&
          intensity >= minIntensity) {
        _points.add(RadarPoint(
          angleDeg: native,
          rangeM: range,
          intensity: intensity,
        ));
      }
    }
    return completed;
  }

  RadarScan? _finishScan() {
    RadarScan? scan;
    if (_points.length >= minScanPoints && _rawSamples >= minRawSamples) {
      scan = RadarScan(points: List<RadarPoint>.from(_points));
    }
    _points.clear();
    _rawSamples = 0;
    return scan;
  }

  void reset() {
    _buffer.clear();
    _points.clear();
    _lastAngle = null;
    _rawSamples = 0;
  }
}
