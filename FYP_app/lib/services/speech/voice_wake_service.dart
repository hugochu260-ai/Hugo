import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../settings_store.dart';
import 'tts_reader_service.dart';

/// Rock-solid Hands-Free Wake-Word & Centralized Microphone Coordinator (v3.5):
/// - CRITICAL FIX: `SpeechToText.initialize()` is called AT MOST ONCE per app
///   session! Foreground sheets multiplex status/error callbacks through this
///   coordinator instead of re-initializing and breaking Android's SpeechRecognizer.
/// - Homophone Fuzzy Matching: Recognizes Cantonese/Mandarin homophones when
///   family renames the assistant (e.g. "小寶" matches "小保/少寶/小報", "阿智" matches "阿字/阿志/呀智").
class VoiceWakeService extends ChangeNotifier {
  VoiceWakeService({
    required this.settings,
    required this.tts,
  }) {
    tts.onSpeakStart = _pauseForTts;
    tts.onSpeakComplete = _resumeAfterTts;
    settings.addListener(_onSettingsChanged);
  }

  final SettingsStore settings;
  final TtsReaderService tts;
  final SpeechToText _stt = SpeechToText();

  static const List<String> _emergencyPhrases = [
    '救命',
    '緊急求救',
    '幫幫手',
    '救命呀',
    '紧急求救',
    '帮帮手',
    'help me',
    'emergency',
  ];

  // Common Cantonese & Mandarin STT homophone normalization groups
  static const Map<String, String> _homophoneMap = {
    '阿': 'a', '呀': 'a', '亞': 'a', '吖': 'a', '啊': 'a',
    '小': 'siu', '少': 'siu', '曉': 'siu', '筱': 'siu',
    '寶': 'bou', '保': 'bou', '報': 'bou', '補': 'bou', '煲': 'bou', '宝': 'bou',
    '智': 'zi', '字': 'zi', '志': 'zi', '至': 'zi', '知': 'zi', '芝': 'zi', '子': 'zi',
    '明': 'ming', '鳴': 'ming', '名': 'ming', '銘': 'ming',
    '強': 'keung', '强': 'keung',
    '孫': 'syun', '酸': 'syun', '宣': 'syun', '孙': 'syun',
    '乖': 'gwaai',
    '仔': 'zai', '崽': 'zai',
    '女': 'neoi', '囡': 'neoi',
    '陳': 'can', '塵': 'can', '陈': 'can',
    '喂': 'wai', '威': 'wai', '位': 'wai', '慧': 'wai',
    '助': 'zo', '座': 'zo',
    '手': 'sau', '首': 'sau', '守': 'sau',
  };

  bool initialized = false;
  bool _initializing = false;
  bool passiveListening = false;
  bool activeDialogOpen = false;
  bool exclusiveMicLocked = false;
  bool suspendedByPage = false;
  String partialHeard = '';
  String? error;
  Timer? _restartTimer;
  Timer? _settingsDebounce;
  bool _disposed = false;
  String _lastLang = '';
  String _lastAssistantName = '';

  void Function(String)? _foregroundStatusListener;
  void Function(dynamic)? _foregroundErrorListener;
  void Function(String initialCommand)? onWakeTriggered;

  static String _toPhonetic(String s) {
    final clean = s.toLowerCase().replaceAll(RegExp(r'[\s，,。！!？?、\-_]'), '');
    final buf = StringBuffer();
    for (final rune in clean.runes) {
      final ch = String.fromCharCode(rune);
      final mapped = _homophoneMap[ch];
      if (mapped != null) {
        buf.write('#$mapped#');
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  List<String> get activeWakePhrases {
    final name = settings.assistantName.trim();
    final set = <String>{};
    if (name.isNotEmpty) {
      set.add('喂$name');
      set.add('你好$name');
      set.add('哈囉$name');
      set.add('hey $name'.toLowerCase());
      set.add('hi $name'.toLowerCase());
      set.add(name);
    }
    for (final raw in settings.customWakeWords.split(RegExp(r'[,，、;\n]'))) {
      final w = raw.trim();
      if (w.isNotEmpty) set.add(w);
    }
    set.addAll(const [
      '喂助手',
      '你好助手',
      '輪椅助手',
      '智行助手',
      '智能助手',
      '小助手',
      '语音助手',
      'hey assistant',
      'assistant',
    ]);
    set.addAll(_emergencyPhrases);
    final list = set.toList()..sort((a, b) => b.length.compareTo(a.length));
    return list;
  }

  void _onSettingsChanged() {
    if (_disposed) return;
    _settingsDebounce?.cancel();
    _settingsDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_disposed) return;
      final langChanged = _lastLang != settings.appLanguage;
      final nameChanged = _lastAssistantName != settings.assistantName;
      _lastLang = settings.appLanguage;
      _lastAssistantName = settings.assistantName;

      if (!settings.wakeWordEnabled) {
        if (passiveListening) unawaited(stopPassiveWake());
        return;
      }
      if (activeDialogOpen || exclusiveMicLocked || suspendedByPage) {
        notifyListeners();
        return;
      }
      if (langChanged && passiveListening) {
        unawaited(stopPassiveWake().then((_) => _scheduleRestart(delayMs: 350)));
      } else if (!passiveListening || !_stt.isListening || nameChanged) {
        if (!passiveListening || !_stt.isListening) {
          unawaited(startPassiveWake());
        } else {
          notifyListeners();
        }
      }
    });
  }

  /// Initializes SpeechToText ONLY ONCE across the entire app session!
  Future<bool> ensureInitialized() async {
    if (initialized) return true;
    if (_initializing) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return initialized;
    }
    _initializing = true;
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        error = '未授予麥克風權限';
        notifyListeners();
        return false;
      }
      initialized = await _stt.initialize(
        onStatus: _masterOnStatus,
        onError: _masterOnError,
      );
      return initialized;
    } catch (e) {
      error = '語音服務初始化失敗：$e';
      notifyListeners();
      return false;
    } finally {
      _initializing = false;
    }
  }

  void _masterOnStatus(String status) {
    if (_disposed) return;
    if (exclusiveMicLocked) {
      _foregroundStatusListener?.call(status);
      return;
    }
    if ((status == 'done' || status == 'notListening') &&
        settings.wakeWordEnabled &&
        !activeDialogOpen &&
        !suspendedByPage &&
        !tts.speaking) {
      passiveListening = false;
      notifyListeners();
      _scheduleRestart(delayMs: 450);
    }
  }

  void _masterOnError(dynamic err) {
    if (_disposed) return;
    if (exclusiveMicLocked) {
      _foregroundErrorListener?.call(err);
      return;
    }
    passiveListening = false;
    notifyListeners();
    _scheduleRestart(delayMs: 900);
  }

  /// Acquires exclusive microphone access WITHOUT re-calling `_stt.initialize`!
  Future<SpeechToText?> acquireExclusiveMic({
    required void Function(String) onStatus,
    required void Function(dynamic) onError,
  }) async {
    exclusiveMicLocked = true;
    _foregroundStatusListener = onStatus;
    _foregroundErrorListener = onError;
    _restartTimer?.cancel();
    await stopPassiveWake();
    if (tts.speaking) {
      await tts.stop();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    if (!await ensureInitialized()) {
      exclusiveMicLocked = false;
      _foregroundStatusListener = null;
      _foregroundErrorListener = null;
      return null;
    }
    return _stt;
  }

  Future<void> releaseExclusiveMic() async {
    _foregroundStatusListener = null;
    _foregroundErrorListener = null;
    exclusiveMicLocked = false;
    try {
      if (_stt.isListening) {
        await _stt.stop().timeout(const Duration(seconds: 2), onTimeout: () {});
      }
    } catch (_) {}
    if (!_disposed &&
        settings.wakeWordEnabled &&
        !activeDialogOpen &&
        !suspendedByPage &&
        !tts.speaking) {
      _scheduleRestart(delayMs: 550);
    }
  }

  /// Manual one-tap reset in Settings if user wants to force-refresh wake listening.
  Future<void> forceRestartWake() async {
    exclusiveMicLocked = false;
    activeDialogOpen = false;
    suspendedByPage = false;
    await stopPassiveWake();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await startPassiveWake();
  }

  Future<void> startPassiveWake() async {
    if (_disposed ||
        !settings.wakeWordEnabled ||
        activeDialogOpen ||
        exclusiveMicLocked ||
        suspendedByPage ||
        tts.speaking) {
      return;
    }
    if (!await ensureInitialized()) return;
    if (_stt.isListening) {
      passiveListening = true;
      notifyListeners();
      return;
    }

    try {
      passiveListening = true;
      _lastLang = settings.appLanguage;
      _lastAssistantName = settings.assistantName;
      error = null;
      notifyListeners();
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: settings.strings.sttLocale,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 6),
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (_) {
      passiveListening = false;
      notifyListeners();
      _scheduleRestart(delayMs: 800);
    }
  }

  Future<void> stopPassiveWake() async {
    _restartTimer?.cancel();
    _restartTimer = null;
    passiveListening = false;
    try {
      if (_stt.isListening) {
        await _stt.stop().timeout(const Duration(seconds: 2), onTimeout: () {});
      }
    } catch (_) {}
    notifyListeners();
  }

  void setSuspendedByPage(bool value) {
    if (suspendedByPage == value) return;
    suspendedByPage = value;
    if (value) {
      unawaited(stopPassiveWake());
    } else if (settings.wakeWordEnabled &&
        !activeDialogOpen &&
        !exclusiveMicLocked) {
      _scheduleRestart(delayMs: 450);
    }
  }

  void setDialogOpen(bool open) {
    activeDialogOpen = open;
    if (open) {
      unawaited(stopPassiveWake());
    } else if (settings.wakeWordEnabled &&
        !exclusiveMicLocked &&
        !suspendedByPage) {
      _scheduleRestart(delayMs: 550);
    }
  }

  void _pauseForTts() {
    _restartTimer?.cancel();
    if (passiveListening || (!exclusiveMicLocked && _stt.isListening)) {
      unawaited(stopPassiveWake());
    }
  }

  void _resumeAfterTts() {
    if (!_disposed &&
        settings.wakeWordEnabled &&
        !activeDialogOpen &&
        !exclusiveMicLocked &&
        !suspendedByPage) {
      _scheduleRestart(delayMs: 600);
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (_disposed || activeDialogOpen || exclusiveMicLocked || tts.speaking) {
      return;
    }
    final raw = result.recognizedWords.trim();
    if (raw.isEmpty) return;
    if (tts.lastSpoken != null &&
        raw.length >= 5 &&
        tts.lastSpoken!.contains(raw)) {
      return;
    }
    partialHeard = raw;
    notifyListeners();

    final normRaw = raw.toLowerCase().replaceAll(RegExp(r'[\s，,。！!？?、]'), '');
    final phonRaw = _toPhonetic(raw);

    for (final phrase in activeWakePhrases) {
      final pClean =
          phrase.toLowerCase().replaceAll(RegExp(r'[\s，,。！!？?、]'), '');
      if (pClean.isEmpty) continue;
      final pPhon = _toPhonetic(phrase);

      final exactMatch = normRaw.contains(pClean);
      final homophoneMatch = pPhon.isNotEmpty && phonRaw.contains(pPhon);

      if (exactMatch || homophoneMatch) {
        var after = '';
        final rawIdx = raw.toLowerCase().indexOf(phrase.toLowerCase());
        if (rawIdx >= 0) {
          after = raw
              .substring(rawIdx + phrase.length)
              .replaceFirst(RegExp(r'^[，,。！？!?\s]+'), '')
              .trim();
        } else if (raw.length > phrase.length) {
          // If matched via homophone (e.g. "小保 去廚房" for "小寶"), strip first N chars
          final stripped = raw.replaceAll(RegExp(r'^[喂你好哈囉呀\s]+'), '');
          if (stripped.length > settings.assistantName.length) {
            after = stripped
                .substring(settings.assistantName.length)
                .replaceFirst(RegExp(r'^[，,。！？!?\s]+'), '')
                .trim();
          }
        }
        final isEmergency = _emergencyPhrases.any(
            (e) => e.toLowerCase().replaceAll(' ', '') == pClean);
        final cmd = isEmergency ? '緊急求救' : after;
        unawaited(_triggerWake(cmd));
        return;
      }
    }
  }

  Future<void> _triggerWake(String trailingCommand) async {
    if (activeDialogOpen) return;
    activeDialogOpen = true;
    await stopPassiveWake();
    onWakeTriggered?.call(trailingCommand);
  }

  void _scheduleRestart({int delayMs = 800}) {
    if (_disposed ||
        !settings.wakeWordEnabled ||
        activeDialogOpen ||
        exclusiveMicLocked ||
        suspendedByPage) {
      return;
    }
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_disposed) unawaited(startPassiveWake());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    settings.removeListener(_onSettingsChanged);
    _settingsDebounce?.cancel();
    _restartTimer?.cancel();
    _stt.stop();
    super.dispose();
  }
}
