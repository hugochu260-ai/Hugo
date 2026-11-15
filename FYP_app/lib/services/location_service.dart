import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class GeoPoint {
  const GeoPoint({
    required this.lat,
    required this.lon,
    this.accuracyM,
  });

  final double lat;
  final double lon;
  final double? accuracyM;
}

/// Cross-platform GPS location wrapper backed by `fyp/location` MethodChannel
/// in Android MainActivity.kt and iOS AppDelegate.swift.
class LocationService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('fyp/location');

  GeoPoint? current;
  bool loading = false;
  String? error;

  Future<GeoPoint?> fetchCurrentLocation() async {
    if (loading) return current;
    loading = true;
    error = null;
    notifyListeners();

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final perm = await Permission.locationWhenInUse.request();
        if (!perm.isGranted) {
          error = '需要位置權限先可以搜尋附近巴士站及發送定位';
          loading = false;
          notifyListeners();
          return null;
        }
      }

      final res = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation')
          .timeout(const Duration(seconds: 6));
      if (res != null && res['ok'] == true) {
        final lat = (res['lat'] as num?)?.toDouble();
        final lon = (res['lon'] as num?)?.toDouble();
        final acc = (res['accuracyM'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          current = GeoPoint(lat: lat, lon: lon, accuracyM: acc);
          error = null;
          loading = false;
          notifyListeners();
          return current;
        }
      }
      error = (res?['error'] as String?) ?? '未能取得目前 GPS 位置';
    } on MissingPluginException {
      error = '此裝置環境暫不支援原生定位通道';
    } catch (e) {
      error = '定位失敗：$e';
    }

    loading = false;
    notifyListeners();
    return null;
  }
}
