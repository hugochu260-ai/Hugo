import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_app/models/car_command.dart';
import 'package:fyp_app/models/radar_models.dart';
import 'package:fyp_app/services/radar/stl27l_parser.dart';

void main() {
  group('CarCommand', () {
    test('payloads match the BT04-A protocol', () {
      expect(CarCommand.forward.payload, 'ONA');
      expect(CarCommand.backward.payload, 'ONB');
      expect(CarCommand.left.payload, 'ONC');
      expect(CarCommand.right.payload, 'OND');
      expect(CarCommand.stop.payload, 'ONF');
      expect(CarCommand.stopSafety.payload, 'ONE');
    });

    test('API mapping', () {
      expect(CarCommand.fromApi('forward'), CarCommand.forward);
      expect(CarCommand.fromApi('back'), CarCommand.backward);
      expect(CarCommand.fromApi('stop'), CarCommand.stop);
      expect(CarCommand.fromApi('unknown'), isNull);
    });
  });

  group('Radar', () {
    test('nearestInSector ignores far and noisy points', () {
      final scan = RadarScan(points: [
        const RadarPoint(angleDeg: 0, rangeM: 0.9),
        const RadarPoint(angleDeg: 2, rangeM: 0.91),
        const RadarPoint(angleDeg: -2, rangeM: 0.92),
        const RadarPoint(angleDeg: 5, rangeM: 3.0),
        const RadarPoint(angleDeg: 178, rangeM: 2.01),
        const RadarPoint(angleDeg: 179, rangeM: 2.0),
        const RadarPoint(angleDeg: 180, rangeM: 2.0),
        const RadarPoint(angleDeg: 182, rangeM: 2.02),
      ]);
      expect(scan.nearestInSector(0, minRangeM: 0.6), closeTo(0.9, 1e-9));
      expect(scan.nearestInSector(180, minRangeM: 0.6), closeTo(2.0, 1e-9));
    });

    test('scan encoding produces a base64 payload', () {
      final scan = RadarScan(points: [
        for (var i = 0; i < 20; i++)
          RadarPoint(angleDeg: i * 10.0, rangeM: 1.0 + i * 0.1),
      ]);
      final encoded = RadarScan.encodeScan(scan);
      expect(encoded, isNotNull);
      expect(encoded!.length, greaterThan(8));
    });

    test('parser accepts an empty chunk', () {
      final parser = Stl27lParser();
      expect(parser.feed(Uint8List(0)), isEmpty);
    });
  });
}
