import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/app_strings.dart';

/// Persistent app settings covering multi-language UI/voice, custom assistant
/// wake-word name, DeepSeek-Flash AI configuration, smart scene-aware tilt mode,
/// elderly daily toolkit (hydration, anti-lost card), and optional wheelchair hardware.
class SettingsStore extends ChangeNotifier {
  static const _kServerUrl = 'server_url';
  static const _kApiKey = 'api_key';
  static const _kBleName = 'ble_name';
  static const _kAiEndpoint = 'ai_endpoint';
  static const _kAiModel = 'ai_model';
  static const _kAiKey = 'ai_key';
  static const _kInstruction = 'instruction';
  static const _kAutoRestart = 'auto_restart';
  static const _kRadarMode = 'radar_mode';
  static const _kRadarWsUrl = 'radar_ws_url';
  static const _kCameraWsUrl = 'camera_ws_url';
  static const _kCameraLowLatency = 'camera_low_latency';
  static const _kRadarAngleOffset = 'radar_angle_offset';
  static const _kFps = 'drive_fps';

  // Accessibility, Language, Custom Wake Name, Smart Tilt & Elderly Hub keys
  static const _kAppLanguage = 'app_language'; // zh_HK | zh_CN | en_US
  static const _kAssistantName = 'assistant_name';
  static const _kAssistantCorner = 'assistant_corner';
  static const _kAssistantImage = 'assistant_image_path';
  static const _kCustomWakeWords = 'custom_wake_words';
  static const _kTiltMode = 'tilt_mode'; // auto | handheld | mounted
  static const _kFontScale = 'font_scale';
  static const _kLightMode = 'light_mode';
  static const _kDeveloperMode = 'developer_mode';
  static const _kWakeWordEnabled = 'wake_word_enabled';
  static const _kTtsAutoRead = 'tts_auto_read';
  static const _kTtsRate = 'tts_rate';
  static const _kCaregiverName = 'caregiver_name';
  static const _kCaregiverPhone = 'caregiver_phone';
  static const _kHomeAddress = 'elder_home_address';
  static const _kMedicalNote = 'elder_medical_note';
  static const _kWaterCups = 'elder_water_cups';
  static const _kWaterDate = 'elder_water_date';
  static const _kEyeClickMode = 'eye_click_mode'; // dwell | blink
  static const _kEyeDwellMs = 'eye_dwell_ms';
  static const _kEyeSensitivity = 'eye_sensitivity';
  static const _kEyeGazeOnAac = 'eye_gaze_on_aac';
  static const _kSafetyStopM = 'safety_stop_m';
  static const _kSlopeSlowdown = 'slope_slowdown';
  static const _kMigratedV3 = 'settings_migrated_v3_deepseek_flash';

  static const String defaultDeepSeekEndpoint =
      'https://api.deepseek.com/chat/completions';
  static const String defaultDeepSeekModel = 'deepseek-flash';
  static const String defaultDeepSeekKey = '';

  SharedPreferences? _prefs;

  String serverUrl = 'https://fyp.pikachumike.win';
  String apiKey = '';
  String bleName = 'BT04';
  String aiEndpoint = defaultDeepSeekEndpoint;
  String aiModel = defaultDeepSeekModel;
  String aiKey = defaultDeepSeekKey;
  String instruction = '前往客廳';
  bool autoRestart = false;
  String radarMode = 'ws';
  String radarWsUrl = 'wss://radar.pikachumike.win/lidar';
  String cameraWsUrl = 'wss://radar.pikachumike.win/camera';
  bool cameraLowLatency = true;
  double radarAngleOffset = 0;
  double driveFps = 4.0;

  // Language, Custom Wake Name, Smart Tilt & Elderly Toolkit defaults
  String appLanguage = 'zh_HK'; // zh_HK, zh_CN, en_US
  String assistantName = '阿智';
  /// Resting corner of the draggable assistant avatar.
  String assistantCorner = 'bottomRight';
  /// Absolute path of a user-chosen portrait. Empty means the drawn default.
  String assistantImagePath = '';
  String customWakeWords = '喂助手,輪椅助手';
  String tiltMode = 'auto'; // 'auto' (handheld until car connects), 'handheld', 'mounted'
  double fontScale = 1.10;
  bool lightMode = true;
  bool developerMode = false;
  bool wakeWordEnabled = true;
  bool ttsAutoRead = true;
  double ttsRate = 0.46;
  String caregiverName = '屋企人／照顧者';
  String caregiverPhone = '';
  String homeAddress = '';
  String medicalNote = '';
  static const int dailyWaterGoal = 6;
  int waterCupsToday = 0;
  String _waterDateKey = '';

  String eyeClickMode = 'dwell';
  int eyeDwellMs = 1000;
  double eyeSensitivity = 1.20;
  bool eyeGazeOnAac = true;
  double safetyStopM = 1.0;
  bool slopeSlowdown = true;

  SharedPreferences? get prefs => _prefs;
  AppStrings get strings => AppStrings(appLanguage);

  static String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get normalizedAiEndpoint {
    var u = aiEndpoint.trim();
    if (u.isEmpty) return defaultDeepSeekEndpoint;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/chat/completions')) {
      u = '$u/chat/completions';
    }
    return u;
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;

    serverUrl = p.getString(_kServerUrl) ?? serverUrl;
    apiKey = p.getString(_kApiKey) ?? apiKey;
    bleName = p.getString(_kBleName) ?? bleName;
    aiEndpoint = p.getString(_kAiEndpoint) ?? aiEndpoint;
    aiModel = p.getString(_kAiModel) ?? aiModel;
    aiKey = p.getString(_kAiKey) ?? aiKey;
    instruction = p.getString(_kInstruction) ?? instruction;
    autoRestart = p.getBool(_kAutoRestart) ?? autoRestart;
    radarMode = p.getString(_kRadarMode) ?? radarMode;
    radarWsUrl = p.getString(_kRadarWsUrl) ?? radarWsUrl;
    cameraWsUrl = p.getString(_kCameraWsUrl) ?? cameraWsUrl;
    cameraLowLatency = p.getBool(_kCameraLowLatency) ?? cameraLowLatency;
    radarAngleOffset = p.getDouble(_kRadarAngleOffset) ?? radarAngleOffset;
    driveFps = p.getDouble(_kFps) ?? driveFps;

    appLanguage = p.getString(_kAppLanguage) ?? appLanguage;
    assistantName = p.getString(_kAssistantName) ?? assistantName;
    if (assistantName.trim().isEmpty) assistantName = '阿智';
    assistantCorner = p.getString(_kAssistantCorner) ?? assistantCorner;
    if (!const {'topLeft', 'topRight', 'bottomLeft', 'bottomRight'}
        .contains(assistantCorner)) {
      assistantCorner = 'bottomRight';
    }
    assistantImagePath = p.getString(_kAssistantImage) ?? '';
    customWakeWords = p.getString(_kCustomWakeWords) ?? customWakeWords;
    tiltMode = p.getString(_kTiltMode) ?? tiltMode;
    fontScale = (p.getDouble(_kFontScale) ?? fontScale).clamp(0.85, 1.50);
    lightMode = p.getBool(_kLightMode) ?? lightMode;
    developerMode = p.getBool(_kDeveloperMode) ?? developerMode;
    wakeWordEnabled = p.getBool(_kWakeWordEnabled) ?? wakeWordEnabled;
    ttsAutoRead = p.getBool(_kTtsAutoRead) ?? ttsAutoRead;
    ttsRate = (p.getDouble(_kTtsRate) ?? ttsRate).clamp(0.30, 0.75);
    caregiverName = p.getString(_kCaregiverName) ?? caregiverName;
    caregiverPhone = p.getString(_kCaregiverPhone) ?? caregiverPhone;
    homeAddress = p.getString(_kHomeAddress) ?? homeAddress;
    medicalNote = p.getString(_kMedicalNote) ?? medicalNote;

    final today = _todayStr();
    _waterDateKey = p.getString(_kWaterDate) ?? '';
    if (_waterDateKey == today) {
      waterCupsToday = p.getInt(_kWaterCups) ?? 0;
    } else {
      _waterDateKey = today;
      waterCupsToday = 0;
    }

    eyeClickMode = p.getString(_kEyeClickMode) ?? eyeClickMode;
    eyeDwellMs = (p.getInt(_kEyeDwellMs) ?? eyeDwellMs).clamp(600, 2000);
    eyeSensitivity =
        (p.getDouble(_kEyeSensitivity) ?? eyeSensitivity).clamp(0.75, 1.85);
    eyeGazeOnAac = p.getBool(_kEyeGazeOnAac) ?? eyeGazeOnAac;
    safetyStopM = (p.getDouble(_kSafetyStopM) ?? safetyStopM).clamp(0.4, 2.5);
    slopeSlowdown = p.getBool(_kSlopeSlowdown) ?? slopeSlowdown;

    final migrated = p.getBool(_kMigratedV3) ?? false;
    if (!migrated) {
      if (aiKey.trim().isEmpty) {
        aiKey = defaultDeepSeekKey;
        await p.setString(_kAiKey, aiKey);
      }
      if (aiModel.trim().isEmpty ||
          aiModel.trim() == 'deepseek-chat' ||
          aiModel.trim() == 'deepseek-v4-flash') {
        aiModel = defaultDeepSeekModel;
        await p.setString(_kAiModel, aiModel);
      }
      if (aiEndpoint.trim().isEmpty) {
        aiEndpoint = defaultDeepSeekEndpoint;
        await p.setString(_kAiEndpoint, aiEndpoint);
      }
      await p.setBool(_kMigratedV3, true);
    }

    notifyListeners();
  }

  Future<void> _putString(String key, String value) async {
    await _prefs?.setString(key, value);
    notifyListeners();
  }

  Future<void> updateAppLanguage(String v) async {
    if (!const {'zh_HK', 'zh_CN', 'en_US'}.contains(v)) return;
    appLanguage = v;
    await _prefs?.setString(_kAppLanguage, v);
    notifyListeners();
  }

  Future<void> cycleLanguage() {
    const order = ['zh_HK', 'zh_CN', 'en_US'];
    final idx = order.indexOf(appLanguage);
    final next = order[(idx + 1) % order.length];
    return updateAppLanguage(next);
  }

  Future<void> updateAssistantCorner(String v) {
    if (!const {'topLeft', 'topRight', 'bottomLeft', 'bottomRight'}
        .contains(v)) {
      return Future.value();
    }
    if (assistantCorner == v) return Future.value();
    assistantCorner = v;
    return _putString(_kAssistantCorner, v);
  }

  Future<void> updateAssistantName(String v) {
    final clean = v.trim().isEmpty ? '阿智' : v.trim();
    if (assistantName == clean) return Future.value();
    assistantName = clean;
    return _putString(_kAssistantName, clean);
  }

  Future<void> updateAssistantImagePath(String v) {
    final clean = v.trim();
    if (assistantImagePath == clean) return Future.value();
    assistantImagePath = clean;
    return _putString(_kAssistantImage, clean);
  }

  Future<void> updateCustomWakeWords(String v) {
    final clean = v.trim();
    if (customWakeWords == clean) return Future.value();
    customWakeWords = clean;
    return _putString(_kCustomWakeWords, customWakeWords);
  }

  String get tiltUsageMode => tiltMode;
  Future<void> updateTiltUsageMode(String v) =>
      updateTiltMode(v == 'vehicle' ? 'mounted' : (v == 'off' ? 'handheld' : v));

  Future<void> updateTiltMode(String v) {
    if (!const {'auto', 'handheld', 'mounted'}.contains(v)) return Future.value();
    tiltMode = v;
    return _putString(_kTiltMode, v);
  }

  Future<void> addWaterCup(int delta) async {
    final today = _todayStr();
    if (_waterDateKey != today) {
      _waterDateKey = today;
      waterCupsToday = 0;
    }
    waterCupsToday = (waterCupsToday + delta).clamp(0, 16);
    await _prefs?.setString(_kWaterDate, _waterDateKey);
    await _prefs?.setInt(_kWaterCups, waterCupsToday);
    notifyListeners();
  }

  Future<void> updateHomeAddress(String v) =>
      _putString(_kHomeAddress, v.trim().also((s) => homeAddress = s));
  Future<void> updateMedicalNote(String v) =>
      _putString(_kMedicalNote, v.trim().also((s) => medicalNote = s));
  Future<void> updateServerUrl(String v) =>
      _putString(_kServerUrl, v.trim().also((s) => serverUrl = s));
  Future<void> updateApiKey(String v) =>
      _putString(_kApiKey, v.trim().also((s) => apiKey = s));
  Future<void> updateBleName(String v) =>
      _putString(_kBleName, v.trim().also((s) => bleName = s));
  Future<void> updateAiEndpoint(String v) =>
      _putString(_kAiEndpoint, v.trim().also((s) => aiEndpoint = s));
  Future<void> updateAiModel(String v) =>
      _putString(_kAiModel, v.trim().also((s) => aiModel = s));
  Future<void> updateAiKey(String v) =>
      _putString(_kAiKey, v.trim().also((s) => aiKey = s));
  Future<void> updateInstruction(String v) =>
      _putString(_kInstruction, v.trim().also((s) => instruction = s));
  Future<void> updateRadarMode(String v) =>
      _putString(_kRadarMode, v.also((s) => radarMode = s));
  Future<void> updateRadarWsUrl(String v) =>
      _putString(_kRadarWsUrl, v.trim().also((s) => radarWsUrl = s));
  Future<void> updateCameraWsUrl(String v) =>
      _putString(_kCameraWsUrl, v.trim().also((s) => cameraWsUrl = s));
  Future<void> updateCaregiverName(String v) =>
      _putString(_kCaregiverName, v.trim().also((s) => caregiverName = s));
  Future<void> updateCaregiverPhone(String v) =>
      _putString(_kCaregiverPhone, v.trim().also((s) => caregiverPhone = s));
  Future<void> updateEyeClickMode(String v) =>
      _putString(_kEyeClickMode, v.also((s) => eyeClickMode = s));

  Future<void> updateAutoRestart(bool v) async {
    autoRestart = v;
    await _prefs?.setBool(_kAutoRestart, v);
    notifyListeners();
  }

  Future<void> updateCameraLowLatency(bool v) async {
    cameraLowLatency = v;
    await _prefs?.setBool(_kCameraLowLatency, v);
    notifyListeners();
  }

  Future<void> updateRadarAngleOffset(double v) async {
    radarAngleOffset = v;
    await _prefs?.setDouble(_kRadarAngleOffset, v);
    notifyListeners();
  }

  Future<void> updateDriveFps(double v) async {
    driveFps = v.clamp(0.5, 10).toDouble();
    await _prefs?.setDouble(_kFps, driveFps);
    notifyListeners();
  }

  Future<void> updateFontScale(double v) async {
    fontScale = v.clamp(0.85, 1.50).toDouble();
    await _prefs?.setDouble(_kFontScale, fontScale);
    notifyListeners();
  }

  Future<void> updateLightMode(bool v) async {
    lightMode = v;
    await _prefs?.setBool(_kLightMode, v);
    notifyListeners();
  }

  Future<void> updateDeveloperMode(bool v) async {
    developerMode = v;
    await _prefs?.setBool(_kDeveloperMode, v);
    notifyListeners();
  }

  Future<void> updateWakeWordEnabled(bool v) async {
    wakeWordEnabled = v;
    await _prefs?.setBool(_kWakeWordEnabled, v);
    notifyListeners();
  }

  Future<void> updateTtsAutoRead(bool v) async {
    ttsAutoRead = v;
    await _prefs?.setBool(_kTtsAutoRead, v);
    notifyListeners();
  }

  Future<void> updateTtsRate(double v) async {
    ttsRate = v.clamp(0.30, 0.75).toDouble();
    await _prefs?.setDouble(_kTtsRate, ttsRate);
    notifyListeners();
  }

  Future<void> updateEyeDwellMs(int v) async {
    eyeDwellMs = v.clamp(600, 2000);
    await _prefs?.setInt(_kEyeDwellMs, eyeDwellMs);
    notifyListeners();
  }

  Future<void> updateEyeSensitivity(double v) async {
    eyeSensitivity = v.clamp(0.75, 1.85).toDouble();
    await _prefs?.setDouble(_kEyeSensitivity, eyeSensitivity);
    notifyListeners();
  }

  Future<void> updateEyeGazeOnAac(bool v) async {
    eyeGazeOnAac = v;
    await _prefs?.setBool(_kEyeGazeOnAac, v);
    notifyListeners();
  }

  Future<void> updateSafetyStopM(double v) async {
    safetyStopM = v.clamp(0.4, 2.5).toDouble();
    await _prefs?.setDouble(_kSafetyStopM, safetyStopM);
    notifyListeners();
  }

  Future<void> updateSlopeSlowdown(bool v) async {
    slopeSlowdown = v;
    await _prefs?.setBool(_kSlopeSlowdown, v);
    notifyListeners();
  }
}

extension _LetExt<T> on T {
  T also(void Function(T) block) {
    block(this);
    return this;
  }
}
