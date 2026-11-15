import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/ai/ai_agent_service.dart';
import 'services/ble_car_service.dart';
import 'services/camera/jetson_camera_service.dart';
import 'services/camera/jetson_video_service.dart';
import 'services/camera_service.dart';
import 'services/drive/auto_drive_controller.dart';
import 'services/drive/jetson_control_service.dart';
import 'services/eye/face_mesh_engine.dart';
import 'services/eye/gaze_controller.dart';
import 'services/location_service.dart';
import 'services/medication/medication_service.dart';
import 'services/radar/radar_service.dart';
import 'services/settings_store.dart';
import 'services/speech/tts_reader_service.dart';
import 'services/speech/voice_wake_service.dart';
import 'services/tilt/tilt_monitor_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FYP_ERROR: ${details.exceptionAsString()}');
      debugPrint('FYP_STACK: ${details.stack}');
      FlutterError.presentError(details);
    };
  }

  final settings = SettingsStore();
  await settings.load();

  final tts = TtsReaderService(settings: settings);
  final wake = VoiceWakeService(settings: settings, tts: tts);
  final medication = MedicationService(tts: tts, settings: settings);
  await medication.load();

  final location = LocationService();
  final ble = BleCarService();
  final radar = RadarService();
  final camera = CameraService();
  final jetsonCamera = JetsonCameraService(settings: settings);
  final jetsonVideo = JetsonVideoService(settings: settings);
  final gaze = GazeController(
    camera: camera,
    engine: FaceMeshEngine(),
    settings: settings,
  );
  await gaze.loadSavedProfiles();

  final tilt = TiltMonitorService();
  final jetsonControl = JetsonControlService(settings: settings);
  final autoDrive = AutoDriveController(
    settings: settings,
    radar: radar,
    ble: ble,
    control: jetsonControl,
    tilt: tilt,
  );
  final ai = AiAgentService(
    settings: settings,
    ble: ble,
    radar: radar,
    autoDrive: autoDrive,
    location: location,
    medication: medication,
    tilt: tilt,
  );

  // Sync smart tilt mode whenever settings or hardware link changes
  void syncTiltMode() {
    tilt.syncContext(
      mode: settings.tiltMode,
      isHardwareLinked: ble.isConnected || autoDrive.controlConnected,
    );
  }

  settings.addListener(syncTiltMode);
  ble.addListener(syncTiltMode);
  autoDrive.addListener(syncTiltMode);
  syncTiltMode();

  ai.onCaregiverBroadcast = (String loudMessage) async {
    await tts.speak(loudMessage, force: true);
  };

  tilt.onSpeedFactorChanged = (factor, onSlope) {
    if (settings.slopeSlowdown) {
      jetsonControl.updateSpeedFactor(factor, onSlope: onSlope);
    }
  };
  tilt.onEmergencyDanger = (status, fallImpact) {
    unawaited(autoDrive.emergencyStopAll(
      reason: fallImpact ? '偵測到跌倒撞擊，緊急煞停' : '偵測到危險傾角，緊急煞停',
    ));
    ai.sosActive = true;
    ai.onSosTriggered?.call();
    final str = settings.strings;
    unawaited(tts.speak(
      fallImpact
          ? str.tr(
              '警告！偵測到劇烈跌落撞擊，已經自動啟動緊急求助！',
              '警告！侦测到剧烈跌落撞击，已自动启动紧急求助！',
              'Warning! Severe fall impact detected. Emergency alert activated!',
            )
          : str.tr(
              '警告！輪椅傾斜角度過大，已經自動減速停車！',
              '警告！轮椅倾斜角度过大，已自动减速停车！',
              'Warning! Excessive wheelchair tilt detected. Stopping safely!',
            ),
      force: true,
    ));
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: tts),
        ChangeNotifierProvider.value(value: wake),
        ChangeNotifierProvider.value(value: medication),
        ChangeNotifierProvider.value(value: location),
        ChangeNotifierProvider.value(value: ble),
        ChangeNotifierProvider.value(value: radar),
        ChangeNotifierProvider.value(value: camera),
        ChangeNotifierProvider.value(value: jetsonCamera),
        ChangeNotifierProvider.value(value: jetsonVideo),
        ChangeNotifierProvider.value(value: jetsonControl),
        ChangeNotifierProvider.value(value: gaze),
        ChangeNotifierProvider.value(value: autoDrive),
        ChangeNotifierProvider.value(value: ai),
        ChangeNotifierProvider.value(value: tilt),
      ],
      child: const FypApp(),
    ),
  );

  unawaited(tilt.start());
  unawaited(jetsonControl.start());
}
