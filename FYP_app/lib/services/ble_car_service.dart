import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/car_command.dart';

enum BleCarState { idle, scanning, connecting, connected, error }

/// BLE transport for the BT04-A car (FFE0 / FFE2).
class BleCarService extends ChangeNotifier {
  static final Guid serviceUuid =
      Guid('0000ffe0-0000-1000-8000-00805f9b34fb');
  static final Guid writeUuid =
      Guid('0000ffe2-0000-1000-8000-00805f9b34fb');

  BleCarState state = BleCarState.idle;
  String? error;
  final List<ScanResult> scanResults = [];
  BluetoothDevice? device;
  BluetoothCharacteristic? _writeCharacteristic;
  CarCommand? _lastCommand;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  bool get isConnected => state == BleCarState.connected;
  bool get isBusy =>
      state == BleCarState.scanning || state == BleCarState.connecting;

  String get deviceName {
    final d = device;
    if (d == null) return '—';
    final name = d.platformName.isNotEmpty ? d.platformName : d.advName;
    return name.isEmpty ? d.remoteId.str : name;
  }

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (scan.isGranted && connect.isGranted) return true;
    // Android 11 and below uses location for BLE scanning.
    final location = await Permission.locationWhenInUse.request();
    if (location.isGranted) return true;
    _setError('缺少藍牙權限：請在系統設定允許「附近裝置」或「位置」');
    return false;
  }

  Future<bool> _ensureBluetoothOn() async {
    BluetoothAdapterState adapter;
    try {
      adapter = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      adapter = FlutterBluePlus.adapterStateNow;
    }
    if (adapter == BluetoothAdapterState.on) return true;
    if (adapter == BluetoothAdapterState.unauthorized) {
      _setError('藍牙權限未授權，請在系統設定允許');
      return false;
    }
    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
        await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 8));
        return true;
      } catch (e) {
        debugPrint('BLE turnOn failed: $e');
      }
    }
    _setError('藍牙未開啟，請先開啟藍牙');
    return false;
  }

  Future<void> startScan({String? nameFilter}) async {
    if (state == BleCarState.scanning) return;
    if (!await _ensurePermissions()) return;
    if (!await _ensureBluetoothOn()) return;
    final wanted = _wantedName(nameFilter);
    error = null;
    scanResults.clear();
    state = BleCarState.scanning;
    notifyListeners();
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      _applyResults(results, wanted);
    });
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 20),
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: false,
      );
    } catch (e) {
      _scanSub?.cancel();
      _scanSub = null;
      _setError('掃描失敗：$e');
      return;
    }
    unawaited(FlutterBluePlus.isScanning.where((v) => !v).first.then((_) {
      if (state == BleCarState.scanning) {
        state = BleCarState.idle;
        notifyListeners();
      }
    }));
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (state == BleCarState.scanning) {
      state = BleCarState.idle;
      notifyListeners();
    }
  }

  Future<bool> connectFirst({String? nameFilter}) async {
    if (state == BleCarState.scanning || state == BleCarState.connecting) {
      return false;
    }
    if (!await _ensurePermissions()) return false;
    if (!await _ensureBluetoothOn()) return false;
    final wanted = _wantedName(nameFilter);

    // Fast path: the BT04-A may already be bonded/paired to the phone.
    if (Platform.isAndroid) {
      try {
        final bonded = await FlutterBluePlus.bondedDevices;
        for (final d in bonded) {
          final name = '${d.platformName} ${d.advName}'.toUpperCase();
          debugPrint('BLE bonded: ${d.remoteId} "$name"');
          if (name.contains(wanted)) {
            return await connect(d);
          }
        }
      } catch (e) {
        debugPrint('BLE bondedDevices failed: $e');
      }
    }

    error = null;
    scanResults.clear();
    state = BleCarState.scanning;
    notifyListeners();

    final found = Completer<BluetoothDevice?>();
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      _applyResults(results, wanted);
      if (found.isCompleted) return;
      for (final r in results) {
        if (_matches(r, wanted)) {
          found.complete(r.device);
          break;
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 20),
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: false,
      );
    } catch (e) {
      _scanSub?.cancel();
      _scanSub = null;
      _setError('掃描失敗：$e');
      return false;
    }

    BluetoothDevice? target;
    try {
      target = await found.future.timeout(const Duration(seconds: 20));
    } catch (_) {
      target = null;
    }
    await stopScan();
    if (target == null) {
      _setError('找不到 $wanted：請確認車輛已通電、手機藍牙已開啟，'
          '且 BT04-A 未被其他裝置連接。也可先在系統藍牙設定配對。');
      return false;
    }
    return connect(target);
  }

  Future<bool> connect(BluetoothDevice target) async {
    await stopScan();
    state = BleCarState.connecting;
    error = null;
    notifyListeners();
    try {
      debugPrint('BLE connect: ${target.remoteId} ${target.platformName}');
      await target.connect(timeout: const Duration(seconds: 12));
      device = target;
      _connSub?.cancel();
      _connSub = target.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected &&
            state == BleCarState.connected) {
          state = BleCarState.idle;
          _writeCharacteristic = null;
          notifyListeners();
        }
      });

      var services = await target.discoverServices();
      if (services.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        services = await target.discoverServices();
      }
      if (services.isEmpty) {
        throw StateError('藍牙服務列表為空');
      }
      if (kDebugMode) {
        for (final s in services) {
          debugPrint('BLE service ${s.uuid}');
          for (final c in s.characteristics) {
            debugPrint('  char ${c.uuid} write=${c.properties.write} '
                'writeNoResp=${c.properties.writeWithoutResponse} '
                'notify=${c.properties.notify}');
          }
        }
      }

      BluetoothCharacteristic? writeChar;
      for (final s in services) {
        if (s.uuid == serviceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid == writeUuid) writeChar = c;
          }
        }
      }
      if (writeChar == null) {
        await target.disconnect();
        _setError('找不到 FFE2 寫入特徵，請確認連接的是 BT04-A');
        return false;
      }
      _writeCharacteristic = writeChar;
      _lastCommand = null;
      state = BleCarState.connected;
      notifyListeners();
      await send(CarCommand.stop, force: true);
      return true;
    } catch (e) {
      _setError('連線失敗：$e');
      try {
        await target.disconnect();
      } catch (_) {}
      return false;
    }
  }

  Future<void> send(CarCommand command, {bool force = false}) async {
    final ch = _writeCharacteristic;
    if (ch == null) {
      if (state == BleCarState.connected) {
        _setError('BT04-A 寫入特徵未就緒，請重新連接');
      }
      return;
    }
    if (!force && _lastCommand == command) return;
    final payload = Uint8List.fromList(command.payload.codeUnits);
    try {
      await ch.write(payload, withoutResponse: true);
      _lastCommand = command;
    } catch (e) {
      // Some modules require a write-with-response request.
      try {
        await ch.write(payload, withoutResponse: false);
        _lastCommand = command;
      } catch (e2) {
        _setError('寫入失敗：$e2');
      }
    }
  }

  /// Checked movement helper enforcing local LiDAR obstacle stop & slope slow-down!
  Future<String?> guardedPulse(
    CarCommand command, {
    Duration baseDuration = const Duration(milliseconds: 420),
    double? frontM,
    double? rearM,
    double safetyStopM = 1.0,
    double speedFactor = 1.0,
    bool bypassRadarCheck = false,
  }) async {
    if (!isConnected) {
      return '藍牙未連接外接底盤（$wantedLabel）';
    }
    if (!command.isMovement) {
      await send(CarCommand.stop, force: true);
      return null;
    }
    if (speedFactor <= 0.0) {
      await emergencyStop();
      return '偵測到危險傾角或跌倒風險，已自動鎖定移動';
    }
    if (!bypassRadarCheck) {
      if (command == CarCommand.forward &&
          frontM != null &&
          frontM < safetyStopM) {
        await send(CarCommand.stop, force: true);
        return '前方 ${frontM.toStringAsFixed(2)} 米有障礙物（少於安全距離 ${safetyStopM.toStringAsFixed(1)} 米），已自動攔截前進';
      }
      if (command == CarCommand.backward &&
          rearM != null &&
          rearM < safetyStopM) {
        await send(CarCommand.stop, force: true);
        return '後方 ${rearM.toStringAsFixed(2)} 米有障礙物（少於安全距離 ${safetyStopM.toStringAsFixed(1)} 米），已自動攔截後退';
      }
    }
    final scaledMs =
        (baseDuration.inMilliseconds * speedFactor.clamp(0.35, 1.0)).round();
    await pulse(command, duration: Duration(milliseconds: scaledMs));
    return null;
  }

  String get wantedLabel => deviceName == '—' ? 'BT04-A' : deviceName;

  /// Send a movement command, hold it, then always stop.
  Future<void> pulse(CarCommand command,
      {Duration duration = const Duration(milliseconds: 200)}) async {
    if (!command.isMovement) {
      await send(CarCommand.stop, force: true);
      return;
    }
    await send(command, force: true);
    await Future<void>.delayed(duration);
    await send(CarCommand.stop, force: true);
  }

  Future<void> emergencyStop() async {
    if (_writeCharacteristic == null) return;
    await send(CarCommand.stop, force: true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await send(CarCommand.stopSafety, force: true);
  }

  Future<void> disconnect() async {
    try {
      if (_writeCharacteristic != null) {
        await send(CarCommand.stop, force: true);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await send(CarCommand.stopSafety, force: true);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    } catch (_) {}
    try {
      await device?.disconnect();
    } catch (_) {}
    _writeCharacteristic = null;
    device = null;
    _lastCommand = null;
    state = BleCarState.idle;
    notifyListeners();
  }

  String _wantedName(String? nameFilter) {
    final n = (nameFilter ?? 'BT04').trim().toUpperCase();
    return n.isEmpty ? 'BT04' : n;
  }

  bool _matches(ScanResult r, String wanted) {
    final n1 = r.device.platformName.toUpperCase();
    final n2 = r.device.advName.toUpperCase();
    final nameHit = (n1.isNotEmpty && n1.contains(wanted)) ||
        (n2.isNotEmpty && n2.contains(wanted));
    final serviceHit =
        r.advertisementData.serviceUuids.any((g) => g == serviceUuid);
    return nameHit || serviceHit;
  }

  void _applyResults(List<ScanResult> results, String wanted) {
    scanResults
      ..clear()
      ..addAll(results.where((r) => _matches(r, wanted)));
    notifyListeners();
  }

  void _setError(String message) {
    error = message;
    state = BleCarState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
