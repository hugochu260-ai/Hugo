import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../services/ai/ai_agent_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../../services/speech/voice_wake_service.dart';
import '../theme/app_theme.dart';

/// Pop-up Voice Companion Sheet triggered when calling the custom assistant name
/// or tapping the microphone icon. Uses exclusive mic locking to prevent TTS echo!
class VoiceAssistantSheet extends StatefulWidget {
  const VoiceAssistantSheet({super.key, this.initialCommand = ''});

  final String initialCommand;

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> {
  final TextEditingController _controller = TextEditingController();
  SpeechToText? _stt;
  VoiceWakeService? _wake;
  bool _listening = false;
  bool _submitting = false;
  String _liveWords = '';

  @override
  void initState() {
    super.initState();
    _wake = context.read<VoiceWakeService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final tts = context.read<TtsReaderService>();
    final settings = context.read<SettingsStore>();
    if (widget.initialCommand.trim().isNotEmpty) {
      await _submit(widget.initialCommand.trim());
    } else {
      await tts.speak(
        settings.strings.tr(
          '${settings.assistantName}喺度，請問想去邊度定係有咩幫到你？',
          '${settings.assistantName}在呢，请问想去哪里或有什么帮到你？',
          '${settings.assistantName} here! How can I help you?',
        ),
        force: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (_submitting || !mounted) return;
    final wake = _wake;
    final settings = context.read<SettingsStore>();
    if (wake == null) return;

    final stt = await wake.acquireExclusiveMic(
      onStatus: (s) {
        if (!mounted) return;
        if (s == 'notListening' || s == 'done') {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (stt == null || !mounted) return;
    _stt = stt;

    setState(() {
      _listening = true;
      _liveWords = '';
    });

    await stt.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        localeId: settings.strings.sttLocale,
        listenFor: const Duration(seconds: 22),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted || _submitting) return;
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;

    // Anti-echo guard: ignore if mic caught the end of TTS playback
    final lastTts = context.read<TtsReaderService>().lastSpoken;
    if (lastTts != null && words.length >= 5 && lastTts.contains(words)) {
      return;
    }

    setState(() {
      _liveWords = words;
      _controller.text = words;
    });
    if (result.finalResult && words.isNotEmpty) {
      setState(() => _listening = false);
      unawaited(_submit(words));
    }
  }

  Future<void> _stopAndSend() async {
    try {
      await _stt?.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _listening = false);
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      await _submit(text);
    }
  }

  Future<void> _submit(String text) async {
    if (_submitting) return;
    _submitting = true;
    try {
      await _stt?.stop();
    } catch (_) {}

    final ai = context.read<AiAgentService>();
    final tts = context.read<TtsReaderService>();
    _controller.clear();
    if (mounted) {
      setState(() {
        _listening = false;
        _liveWords = '';
      });
    }

    await ai.send(text);
    _submitting = false;
    if (!mounted) return;

    final reply = ai.lastReply;
    if (reply != null) {
      await tts.speak(reply, force: true);
      // Wait 400ms after TTS finishes before reopening mic so speaker never echoes!
      if (mounted && ai.hasPendingConfirmation) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted) await _startListening();
      }
    }
  }

  @override
  void dispose() {
    try {
      _stt?.stop();
    } catch (_) {}
    final w = _wake;
    if (w != null) {
      unawaited(w.releaseExclusiveMic());
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    final s = settings.strings;
    final ai = context.watch<AiAgentService>();
    final latestReply = ai.lastReply ??
        s.tr(
          '你好！直接講「我去廚房」、「我口渴」、「附近巴士」或者任何需要！',
          '你好！直接说“我去厨房”、“我口渴”、“附近公交”或任何需要！',
          'Hello! Just say "Kitchen", "Thirsty", "Nearby bus", or anything you need!',
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: p.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.record_voice_over_rounded, color: p.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${settings.assistantName} · ${s.tr('AI 語音友伴', 'AI 语音友伴', 'AI Companion')}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                      Text(
                        _listening
                            ? s.tr('正在聆聽（${s.languageShortLabel}）… 講完自動回覆', '正在聆听… 说完自动回复', 'Listening... speak naturally')
                            : s.tr('撳下方咪掣即可開始講話', '按下方麦克风开始说话', 'Tap microphone below to speak'),
                        style: TextStyle(fontSize: 13, color: p.muted),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: settings.cycleLanguage,
                  icon: const Icon(Icons.language_rounded, size: 18),
                  label: Text(s.languageShortLabel),
                ),
                IconButton(
                  tooltip: s.tr('關閉', '关闭', 'Close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 26),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.outline),
              ),
              child: Text(
                ai.busy
                    ? s.tr('AI 正在思考處理中…', 'AI 正在思考处理中…', 'AI is thinking...')
                    : latestReply,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
            ),
            if (ai.hasPendingConfirmation) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.warning, width: 1.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${s.tr('請確認動作', '请确认动作', 'Confirm Action')}：${ai.pendingConfirmationDescription}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                              await _stt?.stop();
                              final msg = await ai.confirmPendingAction();
                              if (context.mounted) {
                                unawaited(context.read<TtsReaderService>().speak(msg, force: true));
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(s.tr('確認', '确认', 'Confirm')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.danger,
                              side: BorderSide(color: p.danger, width: 1.5),
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: () async {
                              await _stt?.stop();
                              final msg = ai.cancelPendingAction();
                              if (context.mounted) {
                                unawaited(context.read<TtsReaderService>().speak(msg, force: true));
                              }
                            },
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text(s.tr('取消', '取消', 'Cancel')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (_liveWords.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${s.tr('聽到', '听到', 'Heard')}：「$_liveWords」',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: p.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text(s.tr('我去廚房', '我去厨房', 'Go to Kitchen')),
                  onPressed: () => _submit(s.tr('我去廚房', '我去厨房', 'Go to kitchen')),
                ),
                ActionChip(
                  label: Text(s.tr('我想飲水', '我想喝水', 'I want water')),
                  onPressed: () => _submit(s.tr('我想飲水', '我想喝水', 'I want water')),
                ),
                ActionChip(
                  label: Text(s.tr('附近有咩巴士', '附近有什么公交', 'Nearby buses')),
                  onPressed: () => _submit(s.tr('附近有咩巴士', '附近有什么公交', 'Nearby buses')),
                ),
                ActionChip(
                  label: Text(s.tr('去瑪麗醫院搭咩車', '去玛丽医院坐什么车', 'Bus to Queen Mary Hospital')),
                  onPressed: () => _submit(s.tr('去瑪麗醫院搭咩車', '去玛丽医院坐什么车', 'Bus to Queen Mary Hospital')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _listening ? p.danger : p.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(124, 54),
                  ),
                  onPressed: _listening ? _stopAndSend : _startListening,
                  icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
                  label: Text(_listening
                      ? s.tr('講完發送', '说完发送', 'Done')
                      : s.tr('開始講嘢', '开始说话', 'Speak')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _submit(v.trim());
                    },
                    decoration: InputDecoration(
                      hintText: s.tr('或者輸入短句（如：廚房、飲水）…', '或输入短句（如：厨房、喝水）…', 'Or type (e.g. kitchen, water)...'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
