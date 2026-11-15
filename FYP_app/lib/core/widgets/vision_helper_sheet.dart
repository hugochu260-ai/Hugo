import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/ai/ai_agent_service.dart';
import '../../services/camera_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../theme/app_theme.dart';
import 'camera_preview_box.dart';

/// Standalone AI Product Feature:
/// 1) Reads medicine bags, clinic slips, menus, or room obstacles aloud.
/// 2) 1-Tap "Snap Pill Bag -> Auto-Create Medication Alarm" via DeepSeek-Flash!
class VisionHelperSheet extends StatefulWidget {
  const VisionHelperSheet({super.key});

  @override
  State<VisionHelperSheet> createState() => _VisionHelperSheetState();
}

class _VisionHelperSheetState extends State<VisionHelperSheet> {
  late final CameraService _camera;
  bool _ready = false;
  bool _analyzing = false;
  String? _resultText;

  @override
  void initState() {
    super.initState();
    _camera = context.read<CameraService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBackCamera());
  }

  Future<void> _initBackCamera() async {
    final ok = await _camera.use(
      CameraLensDirection.back,
      preset: ResolutionPreset.medium,
    );
    if (mounted) setState(() => _ready = ok);
  }

  Future<void> _captureAndAsk(String prompt, {bool autoAddMed = false}) async {
    if (_analyzing) return;
    setState(() => _analyzing = true);
    final ai = context.read<AiAgentService>();
    final tts = context.read<TtsReaderService>();
    final s = context.read<SettingsStore>().strings;
    try {
      final bytes = await _camera.takeJpeg();
      if (bytes == null) {
        setState(() => _resultText = s.tr(
          '未能擷取畫面，請確認已授權相機權限。',
          '未能获取画面，请确认已授权相机权限。',
          'Could not capture photo. Please check camera permission.',
        ));
        return;
      }
      final String reply;
      if (autoAddMed) {
        reply = await ai.extractMedicationFromPhoto(bytes);
      } else {
        reply = await ai.analyzeImageWithVision(bytes, userPrompt: prompt);
      }
      if (!mounted) return;
      setState(() => _resultText = reply);
      unawaited(tts.speak(reply, force: true));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  void dispose() {
    unawaited(_camera.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = context.watch<SettingsStore>().strings;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.document_scanner_rounded, color: p.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.tr('AI 拍藥袋自動設鬧鐘／睇路況', 'AI 拍药袋自动设闹钟／看路况', 'AI Pill-Bag Alarm & Scene Reader'),
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: p.text),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _ready
                    ? CameraPreviewBox(camera: _camera)
                    : Container(
                        color: Colors.black87,
                        alignment: Alignment.center,
                        child: Text(
                          _camera.error ??
                              s.tr('正在啟動後置鏡頭…', '正在启动后置镜头…', 'Starting camera...'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _analyzing
                      ? null
                      : () => _captureAndAsk('', autoAddMed: true),
                  icon: const Icon(Icons.alarm_add_rounded),
                  label: Text(s.tr('拍藥袋自動幫我設食藥提醒', '拍药袋自动设吃药提醒', 'Snap Pill Bag -> Auto Set Alarm')),
                ),
                FilledButton.tonalIcon(
                  onPressed: _analyzing
                      ? null
                      : () => _captureAndAsk(
                            s.tr(
                              '請幫我讀出呢張相上面嘅文字、藥名、覆診日期或者重點注意事項。',
                              '请帮我读出这张照片上的文字、药名、复诊日期或重点注意事项。',
                              'Please read aloud the text, medicine details, or appointment info in this photo.',
                            ),
                          ),
                  icon: const Icon(Icons.record_voice_over_rounded),
                  label: Text(s.tr('影相讀字（覆診紙／信件）', '拍照读字（复诊单／信件）', 'Read Text Aloud')),
                ),
                OutlinedButton.icon(
                  onPressed: _analyzing
                      ? null
                      : () => _captureAndAsk(
                            s.tr(
                              '請幫我睇下前面環境有咩物品、路牌或者障礙物，行過去安唔安全？',
                              '请帮我看一下前方环境有什么物品、路牌或障碍物，走过去安全吗？',
                              'Describe what is in front of me and whether there are any obstacles.',
                            ),
                          ),
                  icon: const Icon(Icons.visibility_rounded),
                  label: Text(s.tr('睇前面路況／障礙物', '看前方路况／障碍物', 'Check Obstacles Ahead')),
                ),
              ],
            ),
            if (_analyzing) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(
                s.tr('AI 正在分析畫面並準備語音朗讀…', 'AI 正在分析画面并准备语音朗读…', 'AI is analyzing the image...'),
                style: TextStyle(color: p.primary, fontWeight: FontWeight.w700),
              ),
            ] else if (_resultText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.outline),
                ),
                child: Text(
                  _resultText!,
                  style: TextStyle(fontSize: 15.5, height: 1.45, color: p.text),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
