import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hold_button.dart';
import '../../core/widgets/jetson_camera_view.dart';
import '../../core/widgets/jetson_video_view.dart';
import '../../core/widgets/radar_mini_map.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/car_command.dart';
import '../../services/ai/ai_agent_service.dart';
import '../../services/ble_car_service.dart';
import '../../services/camera/jetson_camera_service.dart';
import '../../services/camera/jetson_video_service.dart';
import '../../services/drive/auto_drive_controller.dart';
import '../../services/drive/jetson_control_service.dart';
import '../../services/location_service.dart';
import '../../services/radar/radar_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../../services/tilt/tilt_monitor_service.dart';

class DrivePage extends StatefulWidget {
  const DrivePage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  // 0 = 無障礙巴士與路線規劃 (standalone!), 1 = 輪椅／測試車導航
  int _section = 0;

  // Bus planner state
  final TextEditingController _originCtrl = TextEditingController(text: '目前位置');
  final TextEditingController _destCtrl = TextEditingController();
  final TextEditingController _routeNoCtrl = TextEditingController();
  bool _busLoading = false;
  String? _busResult;

  // Wheelchair / Test-car navigation state
  late final TextEditingController _instructionCtrl;
  late final AutoDriveController _auto;
  late final JetsonCameraService _jetsonCam;
  late final JetsonVideoService _jetsonVideo;
  late final JetsonControlService _control;
  bool _lowLatency = true;
  bool _radarTried = false;
  bool _ignoreRadarDev = false;
  bool _manualModeDev = false;

  static const List<String> _quickIndoorGoals = [
    '客廳',
    '飯廳',
    '睡房',
    '洗手間門口',
    '大門入口',
  ];

  static const List<String> _quickOutingDests = [
    '威爾斯親王醫院',
    '瑪麗醫院',
    '伊利沙伯醫院',
    '屯門醫院',
    '沙田',
    '旺角',
    '銅鑼灣',
    '觀塘',
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsStore>();
    _auto = context.read<AutoDriveController>();
    _jetsonCam = context.read<JetsonCameraService>();
    _jetsonVideo = context.read<JetsonVideoService>();
    _control = context.read<JetsonControlService>();
    _lowLatency = settings.cameraLowLatency;
    _instructionCtrl = TextEditingController(text: settings.instruction);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStreamsIfNeeded());
  }

  Future<void> _initStreamsIfNeeded() async {
    if (_section != 1) return;
    if (_lowLatency) {
      unawaited(_jetsonCam.start());
      unawaited(_control.setCameraMode('jpeg'));
    } else {
      unawaited(_jetsonVideo.start());
      unawaited(_control.setCameraMode('h264'));
    }
    final radar = context.read<RadarService>();
    final settings = context.read<SettingsStore>();
    if (!_radarTried && !radar.isConnected) {
      _radarTried = true;
      try {
        await radar.start(
          mode: settings.radarMode,
          wsUrl: settings.radarWsUrl,
          angleOffsetDeg: settings.radarAngleOffset,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    if (_auto.running) {
      unawaited(_auto.stop(reason: '離開導航畫面'));
    }
    unawaited(_jetsonCam.stop());
    unawaited(_jetsonVideo.stop());
    _originCtrl.dispose();
    _destCtrl.dispose();
    _routeNoCtrl.dispose();
    _instructionCtrl.dispose();
    super.dispose();
  }

  Future<void> _findNearbyBus() async {
    setState(() => _busLoading = true);
    final loc = context.read<LocationService>();
    final ai = context.read<AiAgentService>();
    final tts = context.read<TtsReaderService>();
    try {
      final pos = await loc.fetchCurrentLocation();
      if (pos == null) {
        setState(() {
          _busResult = '未能取得 GPS 定位：${loc.error ?? '請開啟手機定位權限'}。\n'
              '你仍然可以用下方「出發前路線規劃」直接輸入起點地區（例如：大埔）同目的地！';
        });
      } else {
        final res = await ai.transport.nearbyStopsEta(lat: pos.lat, lon: pos.lon);
        setState(() => _busResult = res);
        unawaited(tts.speak(res));
      }
    } catch (e) {
      setState(() => _busResult = '查詢附近巴士失敗：$e');
    } finally {
      if (mounted) setState(() => _busLoading = false);
    }
  }

  Future<void> _planPointToPoint() async {
    final dest = _destCtrl.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先點選或輸入你想去嘅目的地')),
      );
      return;
    }
    setState(() => _busLoading = true);
    final loc = context.read<LocationService>();
    final ai = context.read<AiAgentService>();
    final tts = context.read<TtsReaderService>();
    try {
      final orig = _originCtrl.text.trim();
      var pos = loc.current;
      if ((orig.isEmpty || orig == '目前位置') && pos == null) {
        pos = await loc.fetchCurrentLocation();
      }
      final res = await ai.transport.planPointToPoint(
        originText: orig,
        destinationText: dest,
        userLat: pos?.lat,
        userLon: pos?.lon,
      );
      setState(() => _busResult = res);
      unawaited(tts.speak(res));
    } catch (e) {
      setState(() => _busResult = '路線規劃失敗：$e');
    } finally {
      if (mounted) setState(() => _busLoading = false);
    }
  }

  Future<void> _checkSingleRoute() async {
    final r = _routeNoCtrl.text.trim();
    if (r.isEmpty) return;
    setState(() => _busLoading = true);
    final loc = context.read<LocationService>();
    final ai = context.read<AiAgentService>();
    final tts = context.read<TtsReaderService>();
    try {
      final pos = loc.current ?? await loc.fetchCurrentLocation();
      final res = await ai.transport.busEta(
        route: r,
        userLat: pos?.lat,
        userLon: pos?.lon,
      );
      setState(() => _busResult = res);
      unawaited(tts.speak(res));
    } catch (e) {
      setState(() => _busResult = '路線查詢失敗：$e');
    } finally {
      if (mounted) setState(() => _busLoading = false);
    }
  }

  Future<void> _setCameraMode(bool lowLatency) async {
    if (lowLatency == _lowLatency) return;
    final settings = context.read<SettingsStore>();
    setState(() => _lowLatency = lowLatency);
    await settings.updateCameraLowLatency(lowLatency);
    if (lowLatency) {
      await _jetsonVideo.stop();
      await _control.setCameraMode('jpeg');
      await _jetsonCam.start();
    } else {
      await _jetsonCam.stop();
      await _control.setCameraMode('h264');
      await _jetsonVideo.start();
    }
  }

  Future<void> _manualStart(CarCommand cmd) async {
    final ble = context.read<BleCarService>();
    final radar = context.read<RadarService>();
    final settings = context.read<SettingsStore>();
    final tilt = context.read<TiltMonitorService>();
    if (!ble.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('藍牙未連接底盤（BT04-A）')),
      );
      return;
    }
    if (!_ignoreRadarDev) {
      if (cmd == CarCommand.forward &&
          radar.isLive &&
          radar.frontM != null &&
          radar.frontM! < settings.safetyStopM) {
        await ble.send(CarCommand.stop, force: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('前方 ${radar.frontM!.toStringAsFixed(2)}m 有障礙物，已自動攔截前進')),
          );
        }
        return;
      }
      if (cmd == CarCommand.backward &&
          radar.isLive &&
          radar.rearM != null &&
          radar.rearM! < settings.safetyStopM) {
        await ble.send(CarCommand.stop, force: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('後方 ${radar.rearM!.toStringAsFixed(2)}m 有障礙物，已自動攔截後退')),
          );
        }
        return;
      }
    }
    // On slopes, pulse smoothly instead of continuous full-speed drive
    if (settings.slopeSlowdown && tilt.isOnSlope) {
      await ble.guardedPulse(
        cmd,
        baseDuration: const Duration(milliseconds: 360),
        speedFactor: tilt.recommendedSpeedFactor,
        bypassRadarCheck: _ignoreRadarDev,
      );
      return;
    }
    await ble.send(cmd, force: true);
  }

  Future<void> _manualEnd() async {
    await context.read<BleCarService>().send(CarCommand.stop, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.pagePadding(context);
    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.directions_bus_rounded),
                    label: Text('巴士到站與路線規劃'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.assistant_navigation),
                    label: Text('室內／輪椅自動導航'),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (s) {
                  setState(() => _section = s.first);
                  if (_section == 1) unawaited(_initStreamsIfNeeded());
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              if (_section == 0)
                _buildBusPlanner(context)
              else
                _buildNavigationSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusPlanner(BuildContext context) {
    final p = AppPalette.of(context);
    final tts = context.read<TtsReaderService>();
    final split = Responsive.useSplitPane(context);

    final searchPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: '1. 身邊最近無障礙巴士站（GPS 一鍵查詢）',
          subtitle: '自動根據目前位置搵出附近巴士站及即將到站班次，唔使背站名',
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: p.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: _busLoading ? null : _findNearbyBus,
            icon: _busLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.my_location_rounded),
            label: const Text('搜尋我附近嘅巴士站同到站時間'),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '2. 出發前點對點路線規劃（起點 → 目的地）',
          subtitle: '輸入或揀選想去嘅醫院／地區，自動搵直達低地台巴士、上落車站同下班車時間',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _originCtrl,
                      decoration: InputDecoration(
                        labelText: '出發起點',
                        hintText: '目前位置 / 大埔 / 荃灣',
                        suffixIcon: IconButton(
                          tooltip: '設為目前 GPS 位置',
                          onPressed: () => setState(() => _originCtrl.text = '目前位置'),
                          icon: const Icon(Icons.gps_fixed, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _destCtrl,
                      decoration: const InputDecoration(
                        labelText: '目的地',
                        hintText: '例如：威爾斯親王醫院',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('常用醫院及地區快捷鍵：', style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _quickOutingDests)
                    ActionChip(
                      label: Text(d),
                      onPressed: () {
                        setState(() => _destCtrl.text = d);
                        unawaited(_planPointToPoint());
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _busLoading ? null : _planPointToPoint,
                icon: const Icon(Icons.alt_route_rounded),
                label: const Text('搜尋直達巴士路線'),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _routeNoCtrl,
                      decoration: const InputDecoration(
                        labelText: '已知路線號碼（選填）',
                        hintText: '例如：1A、5B、73X',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _busLoading ? null : _checkSingleRoute,
                    child: const Text('查此線'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final resultCard = SectionCard(
      title: '查詢結果（支援廣東話朗讀）',
      onReadAloud: _busResult == null
          ? null
          : () => tts.speak(_busResult!, force: true),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.outline),
        ),
        child: Text(
          _busResult ?? '請點選上方「搜尋我附近嘅巴士站」或者揀選目的地，結果會清晰顯示喺呢度並可自動讀出。',
          style: TextStyle(
            fontSize: 15.5,
            height: 1.55,
            color: _busResult == null ? p.muted : p.text,
            fontWeight: _busResult == null ? FontWeight.w500 : FontWeight.w600,
          ),
        ),
      ),
    );

    return split
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: searchPanel),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: resultCard),
            ],
          )
        : Column(
            children: [
              searchPanel,
              const SizedBox(height: 14),
              resultCard,
            ],
          );
  }

  Widget _buildNavigationSection(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    final ble = context.watch<BleCarService>();
    final radar = context.watch<RadarService>();
    final auto = context.watch<AutoDriveController>();
    final tilt = context.watch<TiltMonitorService>();
    final jetsonCam = context.watch<JetsonCameraService>();
    final jetsonVideo = context.watch<JetsonVideoService>();
    final tts = context.read<TtsReaderService>();
    final split = Responsive.useSplitPane(context);

    final cameraBox = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tilt.isOnSlope)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.secondary),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_down_rounded, color: p.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '斜坡保護運作中：已自動將移動速度調慢至 ${(tilt.recommendedSpeedFactor * 100).round()}%（不會誤觸發跌倒警報）',
                    style: TextStyle(color: p.text, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _lowLatency
                    ? JetsonCameraView(stream: jetsonCam)
                    : JetsonVideoView(service: jetsonVideo),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusChip(
                        label: auto.controlConnected ? '車載控制：在線' : '車載控制：未連線',
                        color: auto.controlConnected ? p.success : p.danger,
                        icon: Icons.link,
                        compact: true,
                      ),
                      StatusChip(
                        label: radar.isLive ? '雷達防撞：正常' : '雷達：未連接',
                        color: radar.isLive ? p.success : p.warning,
                        icon: Icons.radar,
                        compact: true,
                      ),
                      if (settings.developerMode)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(_lowLatency ? '低延遲 JPEG' : 'H.264 串流'),
                          onPressed: () => _setCameraMode(!_lowLatency),
                        ),
                    ],
                  ),
                ),
                if (settings.developerMode)
                  Positioned(
                    top: 48,
                    right: 10,
                    width: split ? 210 : 150,
                    child: RadarMiniMap(
                      radar: radar,
                      rangeM: 5,
                      height: split ? 175 : 130,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: '前方障礙距離',
                value: auto.frontM != null ? auto.frontM!.toStringAsFixed(2) : '未連線',
                unit: auto.frontM != null ? 'm' : null,
                color: p.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: p.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(64),
                ),
                onPressed: () {
                  auto.emergencyStopAll(reason: '使用者按下緊急停止');
                  tts.speak('已緊急停止！', force: true);
                },
                icon: const Icon(Icons.pan_tool_rounded, size: 24),
                label: const Text('緊急停止'),
              ),
            ),
          ],
        ),
      ],
    );

    final controlPanel = SectionCard(
      title: _manualModeDev ? '工程測試：手動底盤控制' : '目的地導航（出發前二次確認）',
      subtitle: _manualModeDev
          ? '供模型車測試使用；已接入本地雷達防撞與斜坡自動減速'
          : '點選或輸入想去嘅位置，確認無誤後系統先會平順啟動 VLN 導航',
      trailing: settings.developerMode
          ? TextButton.icon(
              onPressed: () => setState(() => _manualModeDev = !_manualModeDev),
              icon: Icon(_manualModeDev ? Icons.auto_awesome : Icons.gamepad_outlined),
              label: Text(_manualModeDev ? '切回導航' : '手動測試'),
            )
          : null,
      child: _manualModeDev
          ? _buildDevManualPad(context, p, ble)
          : _buildGoalNavControls(context, p, auto, settings, tts),
    );

    return split
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: cameraBox),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: controlPanel),
            ],
          )
        : Column(
            children: [
              cameraBox,
              const SizedBox(height: 14),
              controlPanel,
            ],
          );
  }

  Widget _buildGoalNavControls(
    BuildContext context,
    AppPalette p,
    AutoDriveController auto,
    SettingsStore settings,
    TtsReaderService tts,
  ) {
    final realDec = auto.lastDecision;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (auto.pendingInstruction != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: p.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.warning, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '請確認目的地：「${auto.pendingInstruction}」',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.text),
                ),
                const SizedBox(height: 6),
                Text(
                  '確認後輪椅／測試車將開始前往該位置，途中可隨時按紅色「緊急停止」。',
                  style: TextStyle(fontSize: 13.5, color: p.muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: p.success,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () async {
                          final ok = await auto.confirmAndStart();
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(auto.error ?? '啟動失敗')),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('確認出發'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: auto.cancelConfirmation,
                        child: const Text('取消'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final place in _quickIndoorGoals)
              ActionChip(
                avatar: const Icon(Icons.place_outlined, size: 18),
                label: Text(place),
                onPressed: auto.running
                    ? null
                    : () {
                        _instructionCtrl.text = '前往$place';
                        auto.requestConfirmation('前往$place', ignoreRadar: _ignoreRadarDev);
                        tts.speak('準備前往$place，請撳綠色確認出發掣，或者取消。', force: true);
                      },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _instructionCtrl,
          enabled: !auto.running,
          decoration: const InputDecoration(
            labelText: '目的地或導航指令',
            hintText: '例如：前往客廳 / follow the person in the red shirt',
          ),
        ),
        const SizedBox(height: 12),
        if (auto.running)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: p.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: () => auto.stop(reason: '使用者停止導航'),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('停止自動導航'),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: p.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: auto.starting
                ? null
                : () {
                    final target = _instructionCtrl.text.trim();
                    if (target.isEmpty) return;
                    settings.updateInstruction(target);
                    auto.requestConfirmation(target, ignoreRadar: _ignoreRadarDev);
                    tts.speak('準備執行「$target」，請確認出發。', force: true);
                  },
            icon: const Icon(Icons.directions_run_rounded),
            label: const Text('準備出發（進入二次確認）'),
          ),
        if (settings.developerMode) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('工程測試：略過雷達防撞（僅限架空模型車測試）'),
            value: _ignoreRadarDev,
            onChanged: auto.running ? null : (v) => setState(() => _ignoreRadarDev = v),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          '目前狀態：${auto.statusMessage}',
          style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
        ),
        if (auto.error != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.danger),
            ),
            child: Text(
              auto.error!,
              style: TextStyle(color: p.danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        if (realDec != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'VLN 真實決策',
                  value: realDec.command,
                  color: p.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'VLN 推論延遲',
                  value: realDec.latencyMs?.toStringAsFixed(0) ?? '—',
                  unit: realDec.latencyMs != null ? 'ms' : null,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDevManualPad(BuildContext context, AppPalette p, BleCarService ble) {
    if (!ble.isConnected) {
      return Column(
        children: [
          Text(
            ble.error ?? '尚未連接 BT04-A 藍牙底盤',
            textAlign: TextAlign.center,
            style: TextStyle(color: ble.error != null ? p.danger : p.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: ble.isBusy
                ? null
                : () async {
                    final s = context.read<SettingsStore>();
                    await ble.connectFirst(nameFilter: s.bleName);
                  },
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(ble.isBusy ? '掃描連接中…' : '掃描並連接 BT04-A'),
          ),
        ],
      );
    }
    return Column(
      children: [
        HoldButton(
          icon: Icons.keyboard_arrow_up,
          label: '前進',
          onStart: () => _manualStart(CarCommand.forward),
          onEnd: _manualEnd,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HoldButton(
              icon: Icons.keyboard_arrow_left,
              label: '左轉',
              onStart: () => _manualStart(CarCommand.left),
              onEnd: _manualEnd,
            ),
            const SizedBox(width: 8),
            HoldButton(
              icon: Icons.stop_circle_outlined,
              label: '停止',
              color: p.danger,
              onStart: _manualEnd,
              onEnd: () {},
            ),
            const SizedBox(width: 8),
            HoldButton(
              icon: Icons.keyboard_arrow_right,
              label: '右轉',
              onStart: () => _manualStart(CarCommand.right),
              onEnd: _manualEnd,
            ),
          ],
        ),
        const SizedBox(height: 8),
        HoldButton(
          icon: Icons.keyboard_arrow_down,
          label: '後退',
          onStart: () => _manualStart(CarCommand.backward),
          onEnd: _manualEnd,
        ),
      ],
    );
  }
}
