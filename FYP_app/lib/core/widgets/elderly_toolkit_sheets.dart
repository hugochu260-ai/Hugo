import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/ai/ai_agent_service.dart';
import '../../services/camera_service.dart';
import '../../services/location_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../theme/app_theme.dart';
import 'camera_preview_box.dart';

/// 1. Anti-Lost "Safe Return & Medical ID" Card for Elderly & Disabled Users:
/// Displays home address, caregiver phone, medical notes, and live GPS in giant
/// high-contrast text, with 1-tap loud voice broadcast for passersby!
class AntiLostMedicalSheet extends StatefulWidget {
  const AntiLostMedicalSheet({super.key});

  @override
  State<AntiLostMedicalSheet> createState() => _AntiLostMedicalSheetState();
}

class _AntiLostMedicalSheetState extends State<AntiLostMedicalSheet> {
  late final TextEditingController _addrCtrl;
  late final TextEditingController _medNoteCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsStore>();
    _addrCtrl = TextEditingController(text: s.homeAddress);
    _medNoteCtrl = TextEditingController(text: s.medicalNote);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(context.read<LocationService>().fetchCurrentLocation());
    });
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _medNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    final str = settings.strings;
    final loc = context.watch<LocationService>();
    final tts = context.read<TtsReaderService>();
    final pos = loc.current;
    final posStr = pos != null
        ? '${pos.lat.toStringAsFixed(5)}, ${pos.lon.toStringAsFixed(5)}'
        : (loc.loading
            ? str.tr('正在讀取 GPS 位置…', '正在读取 GPS 位置…', 'Fetching GPS...')
            : str.tr('請開啟定位權限', '请开启定位权限', 'Enable GPS permission'));

    final addrDisplay = settings.homeAddress.trim().isEmpty
        ? str.tr('（請按右上角編輯填寫住址／屋苑）', '（请按右上角编辑填写住址）', '(Tap Edit to add home district/address)')
        : settings.homeAddress;
    final noteDisplay = settings.medicalNote.trim().isEmpty
        ? str.tr('（可填寫藥物敏感、長期病患或行動需要）', '（可填写药物过敏或行动需求）', '(Tap Edit to add allergies or medical notes)')
        : settings.medicalNote;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 14,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.badge_rounded, color: p.primary, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    str.tr('防走失「平安回家卡」與醫療備忘', '防走失“平安回家卡”与医疗备忘', 'Safe-Return & Medical ID Card'),
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: p.text),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    if (_editing) {
                      await settings.updateHomeAddress(_addrCtrl.text);
                      await settings.updateMedicalNote(_medNoteCtrl.text);
                    }
                    setState(() => _editing = !_editing);
                  },
                  icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
                  label: Text(_editing
                      ? str.tr('儲存', '保存', 'Save')
                      : str.tr('編輯資料', '编辑', 'Edit')),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_editing) ...[
              TextField(
                controller: _addrCtrl,
                decoration: InputDecoration(
                  labelText: str.tr('居住地區／屋苑地址', '居住地区／小区地址', 'Home District / Address'),
                  hintText: str.tr('例如：沙田第一城 / 觀塘翠屏邨', '例如：沙田第一城', 'e.g. City One Shatin'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _medNoteCtrl,
                decoration: InputDecoration(
                  labelText: str.tr('重要醫療／照顧備註', '重要医疗／照顾备注', 'Medical / Care Notes'),
                  hintText: str.tr('例如：高血壓、對盤尼西林敏感、行動不便', '例如：高血压、行动不便', 'e.g. Hypertension, mobility assistance needed'),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.primary, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${str.tr('緊急聯絡人', '紧急联系人', 'Emergency Contact')}：${settings.caregiverName}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: p.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${str.tr('家人電話', '家人电话', 'Phone')}：${settings.caregiverPhone.isEmpty ? str.tr('請於右上角設定頁填寫電話', '请于设置页填写电话', 'Set phone in Settings') : settings.caregiverPhone}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: p.danger),
                    ),
                    const Divider(height: 20),
                    Text(
                      '${str.tr('回家地區／住址', '回家地址', 'Home Address')}：$addrDisplay',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${str.tr('健康備註', '健康备注', 'Medical Note')}：$noteDisplay',
                      style: TextStyle(fontSize: 15.5, color: p.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GPS：$posStr',
                      style: TextStyle(fontSize: 13.5, color: p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: () {
                  final msg = str.tr(
                    '唔該幫幫手！我迷咗路或者需要協助，請幫我打電話聯絡我屋企人 ${settings.caregiverName}，電話係 ${settings.caregiverPhone.isEmpty ? '寫喺畫面上' : settings.caregiverPhone}，萬分感激！',
                    '麻烦帮帮忙！我迷路或需要协助，请帮我打电话联系我的家人 ${settings.caregiverName}，非常感谢！',
                    'Excuse me, please help me! Could you please contact my family member ${settings.caregiverName} shown on this screen? Thank you!',
                  );
                  tts.speak(msg, force: true);
                },
                icon: const Icon(Icons.campaign_rounded, size: 24),
                label: Text(str.tr('大聲播放「請路人幫我聯絡家人」', '大声播放“请路人帮我联系家人”', 'Speak Aloud to Ask Passerby for Help')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  final link = pos != null
                      ? 'https://maps.google.com/?q=${pos.lat},${pos.lon}'
                      : posStr;
                  final shareTxt = str.tr(
                    '【平安定位分享】我而家喺呢個位置：$link （住址備忘：${settings.homeAddress}）',
                    '【平安定位分享】我现在在这个位置：$link',
                    '[Location Share] Here is my current GPS location: $link',
                  );
                  Clipboard.setData(ClipboardData(text: shareTxt));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(str.tr('已複製定位訊息，可直接貼上 WhatsApp 傳畀屋企人！', '已复制定位信息！', 'Copied GPS link to clipboard!'))),
                  );
                },
                icon: const Icon(Icons.share_location_rounded),
                label: Text(str.tr('複製目前定位傳 WhatsApp 畀屋企人', '复制当前定位发给家人', 'Copy GPS Link for Family')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 2. Elderly Reading Magnifier (1x–4x Zoom) + Night Flashlight + AI Read-Aloud:
/// Helps seniors read tiny text on medicine bottles, newspapers, or food labels,
/// and works as a safe bedside torch at night!
class MagnifierTorchSheet extends StatefulWidget {
  const MagnifierTorchSheet({super.key});

  @override
  State<MagnifierTorchSheet> createState() => _MagnifierTorchSheetState();
}

class _MagnifierTorchSheetState extends State<MagnifierTorchSheet> {
  late final CameraService _camera;
  bool _ready = false;
  bool _torchOn = false;
  bool _readingAi = false;
  double _zoom = 2.0;
  double _maxZoom = 4.0;
  String? _aiText;

  @override
  void initState() {
    super.initState();
    _camera = context.read<CameraService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final ok = await _camera.use(
      CameraLensDirection.back,
      preset: ResolutionPreset.high,
    );
    if (!mounted) return;
    final ctrl = _camera.controller;
    if (ok && ctrl != null) {
      try {
        final maxZ = await ctrl.getMaxZoomLevel();
        _maxZoom = maxZ.clamp(1.0, 6.0);
        _zoom = 2.0.clamp(1.0, _maxZoom);
        await ctrl.setZoomLevel(_zoom);
      } catch (_) {}
    }
    if (mounted) setState(() => _ready = ok);
  }

  Future<void> _toggleTorch() async {
    final ctrl = _camera.controller;
    if (ctrl == null) return;
    try {
      final next = !_torchOn;
      await ctrl.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = next);
    } catch (_) {}
  }

  Future<void> _setZoom(double z) async {
    setState(() => _zoom = z);
    try {
      await _camera.controller?.setZoomLevel(z);
    } catch (_) {}
  }

  Future<void> _readZoomedTextWithAi() async {
    if (_readingAi) return;
    setState(() => _readingAi = true);
    final ai = context.read<AiAgentService>();
    final tts = context.read<TtsReaderService>();
    final str = context.read<SettingsStore>().strings;
    try {
      final bytes = await _camera.takeJpeg();
      if (bytes == null) return;
      final res = await ai.analyzeImageWithVision(
        bytes,
        userPrompt: str.tr(
          '請幫長者清晰讀出呢張放大畫面入面嘅細字內容同重點。',
          '请帮长者清晰读出这张放大画面里的细字内容和重点。',
          'Please clearly read aloud the fine print shown in this magnified view.',
        ),
      );
      if (!mounted) return;
      setState(() => _aiText = res);
      unawaited(tts.speak(res, force: true));
    } finally {
      if (mounted) setState(() => _readingAi = false);
    }
  }

  @override
  void dispose() {
    try {
      _camera.controller?.setFlashMode(FlashMode.off);
    } catch (_) {}
    unawaited(_camera.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final str = context.watch<SettingsStore>().strings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.zoom_in_rounded, color: p.primary, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    str.tr('大字放大鏡 ＋ 照明電筒', '大字放大镜 ＋ 照明手电筒', 'Magnifier & Torch Light'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: p.text),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _ready ? _toggleTorch : null,
                  icon: Icon(_torchOn ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded),
                  label: Text(_torchOn
                      ? str.tr('關燈', '关灯', 'Light Off')
                      : str.tr('開照明燈', '开照明灯', 'Torch On')),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 270,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _ready
                    ? CameraPreviewBox(camera: _camera)
                    : Container(
                        color: Colors.black87,
                        alignment: Alignment.center,
                        child: Text(
                          str.tr('正在啟動高清放大鏡頭…', '正在启动放大镜头…', 'Starting magnifier...'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${str.tr('放大倍數', '放大倍数', 'Zoom')} ${_zoom.toStringAsFixed(1)}x',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Expanded(
                  child: Slider(
                    value: _zoom.clamp(1.0, _maxZoom),
                    min: 1.0,
                    max: _maxZoom,
                    onChanged: _ready ? _setZoom : null,
                  ),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: (_ready && !_readingAi) ? _readZoomedTextWithAi : null,
              icon: const Icon(Icons.volume_up_rounded),
              label: Text(_readingAi
                  ? str.tr('AI 正在辨識細字…', 'AI 正在识别细字…', 'Reading text...')
                  : str.tr('太細睇唔清？撳呢度等 AI 讀出嚟', '字太小看不清？按这里让 AI 读出来', 'Too small? Tap to Have AI Read It Aloud')),
            ),
            if (_aiText != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.outline),
                ),
                child: Text(_aiText!, style: TextStyle(fontSize: 15, color: p.text)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
