import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../settings_store.dart';

/// Multi-language TTS Read-Aloud service supporting Cantonese (zh-HK),
/// Mandarin (zh-CN), and English (en-US) with acoustic anti-echo hooks.
class TtsReaderService extends ChangeNotifier {
  TtsReaderService({required this.settings}) {
    settings.addListener(_onSettingsChanged);
    _init();
  }

  final SettingsStore settings;
  final FlutterTts _tts = FlutterTts();

  bool ready = false;
  bool speaking = false;
  String? lastSpoken;
  String _appliedLocale = '';

  VoidCallback? onSpeakStart;
  VoidCallback? onSpeakComplete;

  void _onSettingsChanged() {
    final target = settings.strings.ttsLocale;
    if (_appliedLocale != target && ready) {
      _appliedLocale = target;
      _tts.setLanguage(target);
    }
  }

  Future<void> _init() async {
    try {
      _appliedLocale = settings.strings.ttsLocale;
      await _tts.setLanguage(_appliedLocale);
      await _tts.setSpeechRate(settings.ttsRate);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() {
        speaking = true;
        onSpeakStart?.call();
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        speaking = false;
        onSpeakComplete?.call();
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        speaking = false;
        onSpeakComplete?.call();
        notifyListeners();
      });
      _tts.setErrorHandler((_) {
        speaking = false;
        onSpeakComplete?.call();
        notifyListeners();
      });
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  Future<void> speak(String text, {bool force = false}) async {
    final clean = text
        .replaceAll(RegExp(r'[*#`_~>]'), '')
        .replaceAll('https://', '')
        .replaceAll('wss://', '')
        .trim();
    if (clean.isEmpty) return;
    if (!force && !settings.ttsAutoRead) return;
    if (!ready) await _init();
    if (!ready) return;

    try {
      final targetLocale = settings.strings.ttsLocale;
      if (_appliedLocale != targetLocale) {
        _appliedLocale = targetLocale;
        await _tts.setLanguage(targetLocale);
      }
      await _tts.setSpeechRate(settings.ttsRate);
      await _tts.stop();
      lastSpoken = clean;
      speaking = true;
      onSpeakStart?.call();
      notifyListeners();
      // Brief pre-speak buffer so any active STT mic closes cleanly before audio plays
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await _tts.speak(clean);
    } catch (_) {
      speaking = false;
      onSpeakComplete?.call();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speaking = false;
    onSpeakComplete?.call();
    notifyListeners();
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    _tts.stop();
    super.dispose();
  }
}
