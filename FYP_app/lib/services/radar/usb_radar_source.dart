import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

import '../../models/radar_models.dart';
import 'radar_source.dart';
import 'stl27l_parser.dart';

/// STL-27L over Android USB OTG (CP210x, 921600 8N1).
class UsbRadarSource implements RadarSource {
  UsbRadarSource();

  static const int cp210xVid = 0x10C4;
  static const int cp210xPid = 0xEA60;

  final Stl27lParser _parser = Stl27lParser();
  final StreamController<RadarScan> _controller =
      StreamController<RadarScan>.broadcast();

  UsbPort? _port;
  StreamSubscription<Uint8List>? _sub;

  @override
  String get label => 'STL-27L USB';

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Stream<RadarScan> get scans => _controller.stream;

  @override
  Future<void> start() async {
    if (!isSupported) {
      throw UnsupportedError('iOS 不支援 USB 序列雷達，請改用 WebSocket 或 Mock');
    }
    final devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      throw StateError('找不到 USB 序列裝置（STL-27L）');
    }
    UsbDevice? target;
    for (final d in devices) {
      if (d.vid == cp210xVid && d.pid == cp210xPid) {
        target = d;
        break;
      }
    }
    final device = target ?? devices.first;

    final port = await device.create();
    if (port == null) {
      throw StateError('無法建立 USB 序列埠（${device.deviceName}）');
    }
    final opened = await port.open();
    if (!opened) {
      throw StateError('無法開啟 ${device.deviceName}');
    }
    await port.setDTR(true);
    await port.setRTS(true);
    port.setPortParameters(
      921600,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );
    _port = port;
    _sub = port.inputStream?.listen((data) {
      for (final scan in _parser.feed(data)) {
        if (!_controller.isClosed) _controller.add(scan);
      }
    });
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _port?.close();
    } catch (_) {}
    _port = null;
    _parser.reset();
  }
}
