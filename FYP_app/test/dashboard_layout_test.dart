import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyp_app/features/dashboard/dashboard_page.dart';
import 'package:fyp_app/services/ai/ai_agent_service.dart';
import 'package:fyp_app/services/ble_car_service.dart';
import 'package:fyp_app/services/drive/auto_drive_controller.dart';
import 'package:fyp_app/services/drive/jetson_control_service.dart';
import 'package:fyp_app/services/location_service.dart';
import 'package:fyp_app/services/medication/medication_service.dart';
import 'package:fyp_app/services/radar/radar_service.dart';
import 'package:fyp_app/services/settings_store.dart';
import 'package:fyp_app/services/speech/tts_reader_service.dart';
import 'package:fyp_app/services/tilt/tilt_monitor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home leads with the next dose and keeps other tools collapsed',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.load();
    final tts = TtsReaderService(settings: settings);
    final med = MedicationService(tts: tts, settings: settings);
    await med.load();
    final ble = BleCarService();
    final radar = RadarService();
    final location = LocationService();
    final tilt = TiltMonitorService();
    final control = JetsonControlService(settings: settings);
    final auto = AutoDriveController(
      settings: settings,
      radar: radar,
      ble: ble,
      control: control,
      tilt: tilt,
    );
    final ai = AiAgentService(
      settings: settings,
      ble: ble,
      radar: radar,
      autoDrive: auto,
      location: location,
      medication: med,
      tilt: tilt,
    );
    addTearDown(() {
      med.dispose();
      ai.dispose();
      auto.dispose();
      control.dispose();
      tilt.dispose();
      radar.dispose();
      tts.dispose();
      settings.dispose();
    });

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: tts),
          ChangeNotifierProvider.value(value: med),
          ChangeNotifierProvider.value(value: ble),
          ChangeNotifierProvider.value(value: radar),
          ChangeNotifierProvider.value(value: control),
          ChangeNotifierProvider.value(value: auto),
          ChangeNotifierProvider.value(value: ai),
          ChangeNotifierProvider.value(value: tilt),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DashboardPage(
              onNavigate: (_) {},
              onOpenMedications: () {},
              onOpenVoiceAssistant: () {},
              onOpenVisionHelper: () {},
              onOpenMagnifier: () {},
              onOpenAntiLostCard: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('下一劑藥'), findsOneWidget);
    expect(find.text('未完成'), findsOneWidget);
    expect(find.text('飲水未夠'), findsOneWidget);
    expect(find.text('其他功能'), findsOneWidget);
    expect(find.text('拍藥袋／睇環境'), findsNothing);
    expect(find.text('AI 拍藥袋自動設鬧鐘'), findsNothing);

    await tester.tap(find.text('其他功能'));
    await tester.pumpAndSettle();

    expect(find.text('拍藥袋／睇環境'), findsOneWidget);
    expect(find.text('眼控溝通板'), findsOneWidget);

    final doseTop = tester.getTopLeft(find.text('下一劑藥')).dy;
    final toolsTop = tester.getTopLeft(find.text('其他功能')).dy;
    expect(doseTop, lessThan(toolsTop));
  });
}
