import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/camera_preview_box.dart';
import '../../core/widgets/gaze_overlay.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/sos_emergency_dialog.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/car_command.dart';
import '../../services/ble_car_service.dart';
import '../../services/camera_service.dart';
import '../../services/eye/gaze_controller.dart';
import '../../services/medication/medication_service.dart';
import '../../services/radar/radar_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../../services/tilt/tilt_monitor_service.dart';

class EyePage extends StatefulWidget {
  const EyePage({super.key, this.initialTab = 0});

  /// 0 = AAC board, 1 = gaze calibration, 2 = medication reminders.
  final int initialTab;

  @override
  State<EyePage> createState() => _EyePageState();
}

class _EyePageState extends State<EyePage> {
  // 0 = 眼控＋觸控大字溝通板 (AAC), 1 = 眼控校準與輪椅控制, 2 = 按時食藥提醒設定
  late int _tab;
  late final GazeController _gaze;
  late final CameraService _camera;
  final TextEditingController _profileNameCtrl =
      TextEditingController(text: '預設用家');
  String? _flashingId;

  static const List<_AacItem> _aacPhrases = [
    _AacItem(
      'aac_water',
      '我想飲水',
      '我想喝水',
      'I want water',
      '唔該，我想飲少少溫水。',
      '麻烦你，我想喝一点温水。',
      'Excuse me, I would like some warm water please.',
      Icons.local_drink_rounded,
    ),
    _AacItem(
      'aac_kitchen',
      '想去廚房',
      '想去厨房',
      'Go to Kitchen',
      '唔該幫手，我想去廚房呀。',
      '麻烦帮帮忙，我想去厨房。',
      'Excuse me, please help me go to the kitchen.',
      Icons.kitchen_rounded,
    ),
    _AacItem(
      'aac_toilet',
      '想去洗手間',
      '想去洗手间',
      'Washroom',
      '唔該，我需要去洗手間。',
      '麻烦你，我需要去洗手间。',
      'Excuse me, I need to use the washroom.',
      Icons.wc_rounded,
    ),
    _AacItem(
      'aac_unwell',
      '我唔舒服',
      '我不舒服',
      'Feeling Unwell',
      '我而家覺得有啲唔舒服，唔該過來睇睇我。',
      '我现在觉得有点不舒服，麻烦过来看看我。',
      'I am feeling unwell right now, please check on me.',
      Icons.healing_rounded,
    ),
    _AacItem(
      'aac_turn',
      '幫我轉身／調姿',
      '帮我翻身／调姿',
      'Adjust Posture',
      '唔該幫我調整一下坐姿或者轉一轉身。',
      '麻烦帮我调整一下坐姿或者翻个身。',
      'Please help me adjust my sitting posture.',
      Icons.airline_seat_recline_normal_rounded,
    ),
    _AacItem(
      'aac_hungry',
      '我肚餓啦',
      '我肚子饿了',
      'I am Hungry',
      '我有啲肚餓，請問有冇嘢食呀？',
      '我有点肚子饿，请问有吃的吗？',
      'I am feeling hungry, could I have something to eat?',
      Icons.restaurant_rounded,
    ),
    _AacItem(
      'aac_temp',
      '太凍／太熱',
      '太冷／太热',
      'Too Cold / Hot',
      '我覺得室溫有啲唔啱，唔該幫我加減衫或調校冷氣。',
      '我觉得室温不太合适，麻烦帮我加减衣服或调一下空调。',
      'The room temperature feels uncomfortable, please help adjust it.',
      Icons.thermostat_rounded,
    ),
    _AacItem(
      'aac_sos',
      '緊急呼叫 SOS',
      '紧急呼叫 SOS',
      'Emergency SOS',
      '__SOS__',
      '__SOS__',
      '__SOS__',
      Icons.emergency_rounded,
    ),
  ];

  // Normalized 4x2 grid for AAC Gaze Board (Tab 0)
  static List<GazeRegion> _buildAacGazeRegions() {
    final regions = <GazeRegion>[];
    for (var i = 0; i < _aacPhrases.length; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      final left = col == 0 ? 0.03 : 0.52;
      final right = col == 0 ? 0.48 : 0.97;
      final top = 0.04 + row * 0.235;
      final bottom = top + 0.215;
      regions.add(GazeRegion(
        id: _aacPhrases[i].id,
        rect: Rect.fromLTRB(left, top, right, bottom),
        label: _aacPhrases[i].titleHk,
      ));
    }
    return regions;
  }

  // Normalized screen rectangles inside the eye-camera wheelchair control canvas (Tab 1)
  static const List<_GazePadSpec> _gazeCanvasButtons = [
    _GazePadSpec('g_aac_water', '飲水', Icons.local_drink_rounded,
        Rect.fromLTRB(0.03, 0.12, 0.32, 0.37)),
    _GazePadSpec('g_forward', '前進', Icons.keyboard_arrow_up_rounded,
        Rect.fromLTRB(0.35, 0.10, 0.65, 0.36),
        cmd: CarCommand.forward),
    _GazePadSpec('g_aac_help', '去廚房／幫手', Icons.campaign_rounded,
        Rect.fromLTRB(0.68, 0.12, 0.97, 0.37)),
    _GazePadSpec('g_left', '左轉', Icons.keyboard_arrow_left_rounded,
        Rect.fromLTRB(0.03, 0.40, 0.32, 0.65),
        cmd: CarCommand.left),
    _GazePadSpec('g_stop', '停止', Icons.stop_circle_outlined,
        Rect.fromLTRB(0.35, 0.40, 0.65, 0.65),
        cmd: CarCommand.stop, isDanger: true),
    _GazePadSpec('g_right', '右轉', Icons.keyboard_arrow_right_rounded,
        Rect.fromLTRB(0.68, 0.40, 0.97, 0.65),
        cmd: CarCommand.right),
    _GazePadSpec('g_recenter', '視線歸零', Icons.my_location_rounded,
        Rect.fromLTRB(0.03, 0.69, 0.32, 0.94)),
    _GazePadSpec('g_backward', '後退', Icons.keyboard_arrow_down_rounded,
        Rect.fromLTRB(0.35, 0.69, 0.65, 0.95),
        cmd: CarCommand.backward),
    _GazePadSpec('g_sos', 'SOS 求救', Icons.emergency_rounded,
        Rect.fromLTRB(0.68, 0.69, 0.97, 0.94),
        isDanger: true),
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
    _gaze = context.read<GazeController>();
    _camera = context.read<CameraService>();
    if (_gaze.activeProfile != null) {
      _profileNameCtrl.text = _gaze.activeProfile!.name;
    }
    _syncRegionsForTab(_tab);
    _gaze.onTrigger = _onGazeTriggered;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_gaze.start());
    });
  }

  void _syncRegionsForTab(int tab) {
    final settings = context.read<SettingsStore>();
    if (tab == 0 && settings.eyeGazeOnAac) {
      _gaze.setRegions(_buildAacGazeRegions());
    } else if (tab == 1) {
      _gaze.setRegions(
        _gazeCanvasButtons
            .map((b) => GazeRegion(id: b.id, rect: b.rect, label: b.label))
            .toList(),
      );
    } else {
      _gaze.setRegions(const []);
    }
  }

  @override
  void dispose() {
    _gaze.onTrigger = null;
    unawaited(_gaze.stop());
    unawaited(_camera.release());
    _profileNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _onGazeTriggered(String id) async {
    if (_gaze.calibrationState == GazeCalibrationState.settling ||
        _gaze.calibrationState == GazeCalibrationState.collecting ||
        _gaze.calibrationState == GazeCalibrationState.fitting) {
      return;
    }
    setState(() => _flashingId = id);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted && _flashingId == id) setState(() => _flashingId = null);
    });

    final tts = context.read<TtsReaderService>();
    final settings = context.read<SettingsStore>();

    // Check if an AAC phrase on Tab 0 was triggered by gaze or touch
    final aac = _aacPhrases.where((e) => e.id == id).firstOrNull;
    if (aac != null) {
      final speech = aac.speechFor(settings.appLanguage);
      if (speech == '__SOS__') {
        if (!mounted) return;
        showDialog<void>(
            context: context, builder: (_) => const SosEmergencyDialog());
      } else {
        await tts.speak(speech, force: true);
      }
      return;
    }

    if (id == 'g_aac_water') {
      await tts.speak(
        settings.strings.tr('唔該，我想飲少少溫水！', '麻烦你，我想喝点温水！', 'Water please!'),
        force: true,
      );
      return;
    }
    if (id == 'g_aac_help') {
      await tts.speak(
        settings.strings.tr(
          '${settings.caregiverName}唔該過來幫一幫手，我想去廚房或者移動位置！',
          '${settings.caregiverName}麻烦过来帮帮忙！',
          '${settings.caregiverName}, please come assist me!',
        ),
        force: true,
      );
      return;
    }
    if (id == 'g_recenter') {
      _gaze.recenterNow();
      await tts.speak(
        settings.strings.tr('視線中心已歸零修正', '视线中心已归零', 'Gaze re-centered'),
        force: true,
      );
      return;
    }
    if (id == 'g_sos') {
      if (!mounted) return;
      showDialog<void>(
          context: context, builder: (_) => const SosEmergencyDialog());
      return;
    }

    final spec = _gazeCanvasButtons.where((e) => e.id == id).firstOrNull;
    if (spec?.cmd != null) {
      final ble = context.read<BleCarService>();
      final radar = context.read<RadarService>();
      final tilt = context.read<TiltMonitorService>();
      final err = await ble.guardedPulse(
        spec!.cmd!,
        baseDuration: const Duration(milliseconds: 500),
        frontM: radar.isLive ? radar.frontM : null,
        rearM: radar.isLive ? radar.rearM : null,
        safetyStopM: settings.safetyStopM,
        speedFactor:
            settings.slopeSlowdown ? tilt.recommendedSpeedFactor : 1.0,
      );
      if (err != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        unawaited(tts.speak(err, force: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsObj = context.watch<SettingsStore>();
    final s = settingsObj.strings;
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
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.record_voice_over_rounded),
                    label: Text(s.tr('眼控＋大字溝通板', '眼控＋大字沟通板', 'Eye & AAC Board')),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.remove_red_eye_rounded),
                    label: Text(s.tr('眼控校準與控車', '眼控校准与控车', 'Calibrate & Drive')),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: const Icon(Icons.medication_rounded),
                    label: Text(s.tr('食藥提醒', '吃药提醒', 'Medications')),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (sel) {
                  setState(() => _tab = sel.first);
                  _syncRegionsForTab(sel.first);
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 12),
              if (_tab != 2) _buildTopEyeQuickBar(context),
              if (_tab != 2) const SizedBox(height: 12),
              if (_tab == 0)
                _buildGazeEnabledAacBoard(context)
              else if (_tab == 1)
                _buildEyeCanvasAndProfiles(context)
              else
                _buildMedicationSettings(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact top bar showing live camera face status + 1-tap Quick 5-Point Calibrate
  /// + 1-tap Center Drift Zeroing right above both AAC & Control tabs!
  Widget _buildTopEyeQuickBar(BuildContext context) {
    final p = AppPalette.of(context);
    final gaze = context.watch<GazeController>();
    final settings = context.watch<SettingsStore>();
    final s = settings.strings;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.outline),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusChip(
            label: gaze.faceDetected
                ? gaze.faceHint
                : s.tr('未對準人臉（請望向前鏡頭）', '未对准人脸（请看向镜头）', 'Align face to front camera'),
            color: gaze.faceDetected ? p.success : p.warning,
            icon: Icons.face_retouching_natural,
            compact: true,
          ),
          FilledButton.tonalIcon(
            onPressed: gaze.running
                ? () {
                    setState(() => _tab = 1);
                    _syncRegionsForTab(1);
                    gaze.startCalibration(
                      profileName: _profileNameCtrl.text,
                      quick5Point: true,
                    );
                  }
                : null,
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: Text(s.tr('快速 5 點校準 (8秒)', '快速 5 点校准', 'Quick 5-Pt Calibrate')),
          ),
          OutlinedButton.icon(
            onPressed: gaze.running ? gaze.recenterNow : null,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: Text(s.tr('望中間一鍵歸零', '看中间一键归零', 'Re-Center Gaze')),
          ),
        ],
      ),
    );
  }

  Widget _buildGazeEnabledAacBoard(BuildContext context) {
    final p = AppPalette.of(context);
    final gaze = context.watch<GazeController>();
    final settings = context.watch<SettingsStore>();
    final s = settings.strings;

    return SectionCard(
      title: s.tr(
        '大字＋免觸控眼動溝通板（凝視或輕觸即大聲朗讀）',
        '大字＋免触控眼动沟通板（凝视或轻触即大声朗读）',
        'Touch & Eye-Gaze AAC Communication Board',
      ),
      subtitle: s.tr(
        '支援 1€ 防抖濾波與磁吸定位：用眼睛望住大格約 ${(settings.eyeDwellMs / 1000).toStringAsFixed(1)} 秒（或直接用手撳）即刻發聲呼叫',
        '支持 1€ 防抖滤波与磁吸定位：用眼睛注视大格约 ${(settings.eyeDwellMs / 1000).toStringAsFixed(1)} 秒（或用手按）即可发声呼叫',
        'Hold your gaze on any large tile for ${(settings.eyeDwellMs / 1000).toStringAsFixed(1)}s (or tap) to speak aloud',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.tr('眼控開關', '眼控开关', 'Eye Gaze'), style: TextStyle(fontSize: 13, color: p.muted)),
          Switch(
            value: settings.eyeGazeOnAac,
            onChanged: (v) async {
              await settings.updateEyeGazeOnAac(v);
              if (mounted) _syncRegionsForTab(_tab);
            },
          ),
        ],
      ),
      child: SizedBox(
        height: 460,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final regions = _buildAacGazeRegions();
            return Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < _aacPhrases.length; i++)
                  Positioned.fromRect(
                    rect: Rect.fromLTRB(
                      regions[i].rect.left * size.width,
                      regions[i].rect.top * size.height,
                      regions[i].rect.right * size.width,
                      regions[i].rect.bottom * size.height,
                    ),
                    child: _buildAacGazeTile(
                      context,
                      _aacPhrases[i],
                      hovered: settings.eyeGazeOnAac &&
                          gaze.hoveredId == _aacPhrases[i].id,
                      flashing: _flashingId == _aacPhrases[i].id,
                    ),
                  ),
                if (settings.eyeGazeOnAac && gaze.faceDetected)
                  GazeOverlay(
                    gaze: gaze.gaze,
                    progress: gaze.selectionProgress,
                    eyesClosed: gaze.eyesClosed,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAacGazeTile(
    BuildContext context,
    _AacItem item, {
    required bool hovered,
    required bool flashing,
  }) {
    final p = AppPalette.of(context);
    final lang = context.watch<SettingsStore>().appLanguage;
    final isSos = item.speechHk == '__SOS__';
    final accent = isSos ? p.danger : p.primary;

    return Material(
      color: flashing
          ? accent.withValues(alpha: 0.35)
          : hovered
              ? accent.withValues(alpha: 0.22)
              : (isSos ? p.danger.withValues(alpha: 0.12) : p.surfaceHigh),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _onGazeTriggered(item.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (hovered || flashing || isSos) ? accent : p.outline,
              width: hovered ? 3.0 : (isSos ? 2.0 : 1.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 34, color: accent),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  item.titleFor(lang),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isSos ? p.danger : p.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEyeCanvasAndProfiles(BuildContext context) {
    final p = AppPalette.of(context);
    final gaze = context.watch<GazeController>();
    final camera = context.watch<CameraService>();
    final settings = context.watch<SettingsStore>();
    final s = settings.strings;
    final split = Responsive.useSplitPane(context);

    final isCalibrating =
        gaze.calibrationState == GazeCalibrationState.settling ||
            gaze.calibrationState == GazeCalibrationState.collecting;

    final canvasBox = AspectRatio(
      aspectRatio: split ? 4 / 3 : 3 / 3.3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.flip(
                  flipX: true,
                  child: CameraPreviewBox(camera: camera),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: isCalibrating ? 0.62 : 0.36,
                    ),
                  ),
                ),
                if (!isCalibrating)
                  for (final b in _gazeCanvasButtons)
                    Positioned.fromRect(
                      rect: Rect.fromLTRB(
                        b.rect.left * size.width,
                        b.rect.top * size.height,
                        b.rect.right * size.width,
                        b.rect.bottom * size.height,
                      ),
                      child: _GazeTile(
                        spec: b,
                        hovered: gaze.hoveredId == b.id,
                        flashing: _flashingId == b.id,
                        onTap: () => _onGazeTriggered(b.id),
                      ),
                    ),
                GazeOverlay(
                  gaze: gaze.gaze,
                  progress: gaze.selectionProgress,
                  calibrationTarget: gaze.calibrationTarget,
                  calibrationProgress: gaze.calibrationProgress,
                  eyesClosed: gaze.eyesClosed,
                ),
                Positioned(
                  top: 8,
                  left: 10,
                  right: 10,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusChip(
                        label: gaze.faceDetected ? '人臉與瞳孔鎖定中' : '請將臉對準前鏡頭',
                        color: gaze.faceDetected ? p.success : p.danger,
                        icon: Icons.face_retouching_natural,
                        compact: true,
                      ),
                      StatusChip(
                        label: gaze.activeProfile != null
                            ? '檔案：${gaze.activeProfile!.name}'
                            : '預校準即時模式（建議跑 5 點校準）',
                        color:
                            gaze.activeProfile != null ? p.primary : p.secondary,
                        icon: Icons.verified_user_outlined,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    final settingsCol = SectionCard(
      title: s.tr('眼控靈敏度與個人校準檔案', '眼控灵敏度与个人校准档案', 'Eye Tracking Calibration & Sensitivity'),
      subtitle: s.tr(
        '全新 12 維頭部傾斜補償＋1€ 濾波＋磁吸防抖，大幅提升上下左右準確度',
        '全新 12 维头部倾斜补偿＋1€ 滤波＋磁吸防抖，大幅提升上下左右准确度',
        '12D head-roll compensation + 1€ adaptive filter + magnetic target snap',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'dwell',
                icon: const Icon(Icons.timelapse_rounded),
                label: Text(s.tr('注視停留即撳', '注视停留点击', 'Gaze Dwell')),
              ),
              ButtonSegment(
                value: 'blink',
                icon: const Icon(Icons.visibility_off_outlined),
                label: Text(s.tr('閉眼 1 秒點擊', '闭眼 1 秒点击', 'Blink Click')),
              ),
            ],
            selected: {settings.eyeClickMode},
            onSelectionChanged: (sel) => settings.updateEyeClickMode(sel.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(s.tr('游標靈敏度：', '游标灵敏度：', 'Sensitivity: '),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Expanded(
                child: Slider(
                  value: settings.eyeSensitivity,
                  min: 0.75,
                  max: 1.85,
                  divisions: 22,
                  label: '${(settings.eyeSensitivity * 100).round()}%',
                  onChanged: (v) => settings.updateEyeSensitivity(v),
                ),
              ),
              Text('${(settings.eyeSensitivity * 100).round()}%'),
            ],
          ),
          Row(
            children: [
              Text(s.tr('停留觸發秒數：', '停留触发秒数：', 'Dwell Time: '),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Expanded(
                child: Slider(
                  value: settings.eyeDwellMs.toDouble(),
                  min: 650,
                  max: 1800,
                  divisions: 23,
                  label: '${(settings.eyeDwellMs / 1000).toStringAsFixed(2)}s',
                  onChanged: (v) => settings.updateEyeDwellMs(v.round()),
                ),
              ),
              Text('${(settings.eyeDwellMs / 1000).toStringAsFixed(1)}s'),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _profileNameCtrl,
            decoration: InputDecoration(
              labelText: s.tr('用家檔案名稱（如：陳伯伯）', '用户档案名称', 'Profile Name'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          if (isCalibrating)
            FilledButton.tonalIcon(
              onPressed: gaze.cancelCalibration,
              icon: const Icon(Icons.close),
              label: Text(
                  '取消校準（${gaze.calibrationIndex + 1}/${gaze.activeCalibrationTargets.length}）'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: gaze.running
                      ? () => gaze.startCalibration(
                            profileName: _profileNameCtrl.text,
                            quick5Point: true,
                          )
                      : null,
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(s.tr('快速 5 點校準（推薦）', '快速 5 点校准（推荐）', 'Quick 5-Point')),
                ),
                OutlinedButton.icon(
                  onPressed: gaze.running
                      ? () => gaze.startCalibration(
                            profileName: _profileNameCtrl.text,
                            quick5Point: false,
                          )
                      : null,
                  icon: const Icon(Icons.grid_on_rounded),
                  label: Text(s.tr('精準 9 點校準', '精准 9 点校准', '9-Point Precision')),
                ),
                OutlinedButton.icon(
                  onPressed: gaze.running ? gaze.recenterNow : null,
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(s.tr('一鍵視線歸零', '一键视线归零', 'Center Zero')),
                ),
              ],
            ),
          if (gaze.calibrationMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              gaze.calibrationMessage!,
              style: TextStyle(
                color: gaze.calibrationState == GazeCalibrationState.failed
                    ? p.danger
                    : p.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (gaze.profiles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              s.tr('已儲存嘅面部眼控檔案：', '已保存的面部眼控档案：', 'Saved Profiles:'),
              style: TextStyle(color: p.muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final prof in gaze.profiles)
                  InputChip(
                    selected: gaze.activeProfile?.id == prof.id,
                    label: Text(prof.name),
                    onSelected: (_) {
                      _profileNameCtrl.text = prof.name;
                      gaze.selectProfile(prof.id);
                    },
                    onDeleted: () => gaze.deleteProfile(prof.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return split
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: canvasBox),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: settingsCol),
            ],
          )
        : Column(
            children: [
              canvasBox,
              const SizedBox(height: 14),
              settingsCol,
            ],
          );
  }

  Widget _buildMedicationSettings(BuildContext context) {
    final p = AppPalette.of(context);
    final med = context.watch<MedicationService>();
    final st = context.watch<SettingsStore>();
    final s = st.strings;
    final lang = st.appLanguage;

    return SectionCard(
      title: s.tr('按時食藥／喂藥及日程提醒設定', '按时吃药／喂药及日程提醒设置', 'Medication & Care Schedule'),
      subtitle: s.tr('到時間會彈出醒目橫幅並以語音自動播報', '到时间会弹出醒目横幅并以语音自动播报', 'Automatic banner & spoken reminder on time'),
      trailing: FilledButton.icon(
        onPressed: () => _showAddMedDialog(context),
        icon: const Icon(Icons.add_alarm_rounded),
        label: Text(s.tr('新增時間', '新增时间', 'Add Time')),
      ),
      child: Column(
        children: [
          if (med.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                s.tr('尚未設定提醒，請按右上角「新增時間」。', '尚未设置提醒，请按右上角“新增时间”。', 'No reminders yet. Tap "Add Time".'),
                style: TextStyle(color: p.muted),
              ),
            ),
          for (final item in med.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.outline),
                ),
                child: Row(
                  children: [
                    Switch(
                      value: item.enabled,
                      onChanged: (v) => med.toggleEnabled(item.id, v),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.timeLabel,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: item.enabled ? p.primary : p.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.localizedTitle(lang),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: p.text,
                            ),
                          ),
                          if (item.localizedNote(lang).isNotEmpty)
                            Text(item.localizedNote(lang),
                                style:
                                    TextStyle(fontSize: 13.5, color: p.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '試播提醒',
                      onPressed: () => med.triggerTestReminder(item),
                      icon: Icon(Icons.volume_up_rounded, color: p.secondary),
                    ),
                    IconButton(
                      tooltip: '刪除',
                      onPressed: () => med.remove(item.id),
                      icon: Icon(Icons.delete_outline, color: p.danger),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddMedDialog(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: '飯後溫水送服');
    TimeOfDay picked = const TimeOfDay(hour: 9, minute: 0);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('新增按時食藥／日程提醒'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: picked,
                    );
                    if (t != null) setModalState(() => picked = t);
                  },
                  icon: const Icon(Icons.access_time_rounded),
                  label: Text(
                    '提醒時間：${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '藥物或事項名稱',
                    hintText: '例如：血壓藥、糖尿藥、物理治療覆診',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: '份量或備註',
                    hintText: '例如：飯後 1 粒',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim().isEmpty
                    ? '按時食藥提醒'
                    : titleCtrl.text.trim();
                context.read<MedicationService>().addOrUpdate(
                      MedicationReminder(
                        id: 'med_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        note: noteCtrl.text.trim(),
                        hour: picked.hour,
                        minute: picked.minute,
                        enabled: true,
                      ),
                    );
                Navigator.pop(ctx);
              },
              child: const Text('儲存提醒'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AacItem {
  const _AacItem(
    this.id,
    this.titleHk,
    this.titleCn,
    this.titleEn,
    this.speechHk,
    this.speechCn,
    this.speechEn,
    this.icon,
  );
  final String id;
  final String titleHk;
  final String titleCn;
  final String titleEn;
  final String speechHk;
  final String speechCn;
  final String speechEn;
  final IconData icon;

  String titleFor(String lang) {
    switch (lang) {
      case 'zh_CN':
        return titleCn;
      case 'en_US':
        return titleEn;
      default:
        return titleHk;
    }
  }

  String speechFor(String lang) {
    switch (lang) {
      case 'zh_CN':
        return speechCn;
      case 'en_US':
        return speechEn;
      default:
        return speechHk;
    }
  }
}

class _GazePadSpec {
  const _GazePadSpec(
    this.id,
    this.label,
    this.icon,
    this.rect, {
    this.cmd,
    this.isDanger = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final Rect rect;
  final CarCommand? cmd;
  final bool isDanger;
}

class _GazeTile extends StatelessWidget {
  const _GazeTile({
    required this.spec,
    required this.hovered,
    required this.flashing,
    required this.onTap,
  });

  final _GazePadSpec spec;
  final bool hovered;
  final bool flashing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent =
        spec.isDanger ? const Color(0xFFFF5252) : const Color(0xFF38BDF8);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: flashing
              ? accent.withValues(alpha: 0.65)
              : hovered
                  ? accent.withValues(alpha: 0.38)
                  : Colors.black.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (hovered || flashing)
                ? accent
                : Colors.white.withValues(alpha: 0.35),
            width: hovered ? 2.8 : 1.3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(spec.icon, color: Colors.white, size: 28),
            const SizedBox(height: 3),
            Text(
              spec.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
