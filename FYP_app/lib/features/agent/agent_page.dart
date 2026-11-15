import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_models.dart';
import '../../services/ai/ai_agent_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../../services/speech/voice_wake_service.dart';
import '../settings/settings_page.dart';

class AgentPage extends StatefulWidget {
  const AgentPage({super.key, this.onOpenVisionHelper});

  final VoidCallback? onOpenVisionHelper;

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> {
  int _subTab = 0; // 0 = AI 對話助手, 1 = 用戶與語言設定
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  SpeechToText? _stt;
  VoiceWakeService? _wake;

  bool _listening = false;
  String _prefixBeforeListen = '';

  @override
  void initState() {
    super.initState();
    _wake = context.read<VoiceWakeService>();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    final ai = context.read<AiAgentService>();
    final tts = context.read<TtsReaderService>();
    if (_listening) {
      try {
        await _stt?.stop();
      } catch (_) {}
      await _wake?.releaseExclusiveMic();
      if (mounted) setState(() => _listening = false);
    }
    if (text.isEmpty) return;
    _input.clear();
    _prefixBeforeListen = '';
    await ai.send(text);
    if (!mounted) return;
    final reply = ai.lastReply;
    if (reply != null) unawaited(tts.speak(reply));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      try {
        await _stt?.stop();
      } catch (_) {}
      await _wake?.releaseExclusiveMic();
      setState(() => _listening = false);
      if (_input.text.trim().isNotEmpty) {
        await _send(_input.text.trim());
      }
      return;
    }

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
    _prefixBeforeListen = _input.text.trim();
    setState(() => _listening = true);

    await stt.listen(
      onResult: (SpeechRecognitionResult res) {
        if (!mounted) return;
        final w = res.recognizedWords.trim();
        if (w.isEmpty) return;
        setState(() {
          _input.text =
              _prefixBeforeListen.isEmpty ? w : '$_prefixBeforeListen $w';
        });
        // Auto-submit cleanly once user pauses speaking!
        if (res.finalResult && _input.text.trim().isNotEmpty) {
          setState(() => _listening = false);
          unawaited(_wake?.releaseExclusiveMic());
          unawaited(_send(_input.text.trim()));
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: settings.strings.sttLocale,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
      ),
    );
  }

  @override
  void dispose() {
    try {
      _stt?.stop();
    } catch (_) {}
    final w = _wake;
    if (w != null) unawaited(w.releaseExclusiveMic());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    final s = settings.strings;
    final ai = context.watch<AiAgentService>();
    final tts = context.read<TtsReaderService>();
    final padding = Responsive.pagePadding(context);

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: Text('${settings.assistantName} · ${s.tr('AI 對話', 'AI 对话', 'AI Chat')}'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.settings_accessibility_rounded),
                    label: Text(s.tr('語言／助手改名／設定', '语言／助手改名／设置', 'Settings')),
                  ),
                ],
                selected: {_subTab},
                onSelectionChanged: (sel) => setState(() => _subTab = sel.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 12),
              if (_subTab == 1)
                const Expanded(
                  child: SingleChildScrollView(
                    child: SettingsPage(embedded: true),
                  ),
                )
              else ...[
                if (ai.hasPendingConfirmation)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: p.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.warning, width: 1.8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${s.tr('請確認', '请确认', 'Confirm')}：${ai.pendingConfirmationDescription}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: p.text),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: p.success,
                              foregroundColor: Colors.white),
                          onPressed: () async {
                            final msg = await ai.confirmPendingAction();
                            tts.speak(msg, force: true);
                          },
                          child: Text(s.tr('確認', '确认', 'Confirm')),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            final msg = ai.cancelPendingAction();
                            tts.speak(msg, force: true);
                          },
                          child: Text(s.tr('取消', '取消', 'Cancel')),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    itemCount: ai.messages.length,
                    itemBuilder: (context, idx) {
                      final m = ai.messages[ai.messages.length - 1 - idx];
                      // Only read ASSISTANT replies aloud on tap — never parrot user bubbles!
                      return _ChatBubble(
                        message: m,
                        onRead: m.isUser
                            ? null
                            : () => tts.speak(m.text, force: true),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (widget.onOpenVisionHelper != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.camera_alt_rounded, size: 17),
                            label: Text(s.tr('拍藥袋／睇環境', '拍药袋／看环境', 'Snap Photo')),
                            onPressed: widget.onOpenVisionHelper,
                          ),
                        ),
                      for (final q in [
                        s.tr('我去廚房', '我去厨房', 'Go to kitchen'),
                        s.tr('我想飲水', '我想喝水', 'I want water'),
                        s.tr('附近有咩巴士', '附近有什么公交', 'Nearby buses'),
                        s.tr('去伊利沙伯醫院搭咩車', '去伊利沙伯医院坐什么车', 'Bus to QE Hospital'),
                        s.tr('香港天氣', '香港天气', 'HK weather'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(q),
                            onPressed: () => _send(q),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _toggleMic,
                      icon: Icon(
                        _listening ? Icons.stop_circle : Icons.mic_rounded,
                        color: _listening ? p.danger : p.primary,
                      ),
                      label: Text(_listening
                          ? s.tr('講完發送', '说完发送', 'Send')
                          : s.tr('撳住講嘢', '语音输入', 'Speak')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: s.tr(
                            '直接講或輸入（如：我去廚房、我口渴、附近巴士）…',
                            '直接说或输入（如：我去厨房、我口渴、附近公交）…',
                            'Say or type (e.g. kitchen, thirsty, nearby bus)...',
                          ),
                          suffixIcon: _input.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() {
                                    _input.clear();
                                    _prefixBeforeListen = '';
                                  }),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: ai.busy ? null : () => _send(),
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.onRead});

  final ChatMessage message;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final user = message.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onRead,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: user ? p.primary.withValues(alpha: 0.16) : p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: user ? p.primary.withValues(alpha: 0.45) : p.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.45,
                    color: message.isError ? p.danger : p.text,
                  ),
                ),
              ),
              if (!user && onRead != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.volume_up_outlined, size: 18, color: p.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
