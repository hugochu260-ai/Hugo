import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings_store.dart';
import '../speech/tts_reader_service.dart';

class MedicationReminder {
  MedicationReminder({
    required this.id,
    required this.title,
    required this.note,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.lastTakenDate,
    this.snoozedUntilMs,
  });

  factory MedicationReminder.fromJson(Map<String, dynamic> j) =>
      MedicationReminder(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        note: '${j['note'] ?? ''}',
        hour: (j['hour'] as num?)?.toInt() ?? 8,
        minute: (j['minute'] as num?)?.toInt() ?? 0,
        enabled: j['enabled'] as bool? ?? true,
        lastTakenDate: j['lastTakenDate'] as String?,
        snoozedUntilMs: (j['snoozedUntilMs'] as num?)?.toInt(),
      );

  final String id;
  final String title;
  final String note;
  final int hour;
  final int minute;
  final bool enabled;
  final String? lastTakenDate;
  final int? snoozedUntilMs;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  bool isTakenToday(DateTime now) => lastTakenDate == _dateKey(now);

  /// True once today's clock reaches this reminder's hour and minute.
  bool isPastScheduledTime(DateTime now) {
    final due = DateTime(now.year, now.month, now.day, hour, minute);
    return !now.isBefore(due);
  }

  bool isSnoozed(DateTime now) =>
      snoozedUntilMs != null && now.millisecondsSinceEpoch < snoozedUntilMs!;

  /// Dynamically translates built-in default reminder titles across Cantonese,
  /// Mandarin, and English while preserving user-typed custom names verbatim!
  String localizedTitle(String lang) {
    if (id == 'med_morning' || title == '早上藥物／血壓藥') {
      if (lang == 'en_US') return 'Morning Medicine / Blood Pressure';
      if (lang == 'zh_CN') return '早上药物／血压药';
      return '早上藥物／血壓藥';
    }
    if (id == 'med_noon' || title == '午間喂藥／補充水份') {
      if (lang == 'en_US') return 'Noon Medicine & Warm Water';
      if (lang == 'zh_CN') return '午间喂药／补充水分';
      return '午間喂藥／補充水份';
    }
    if (id == 'med_night' || title == '晚間常規藥物') {
      if (lang == 'en_US') return 'Evening Regular Medicine';
      if (lang == 'zh_CN') return '晚间常规药物';
      return '晚間常規藥物';
    }
    return title;
  }

  String localizedNote(String lang) {
    if (id == 'med_morning' || note == '飯後 1 粒 · 溫水送服') {
      if (lang == 'en_US') return '1 tablet after meal with warm water';
      if (lang == 'zh_CN') return '饭后 1 粒 · 温水送服';
      return '飯後 1 粒 · 溫水送服';
    }
    if (id == 'med_noon' || note == '午餐後服用 · 飲半杯溫水') {
      if (lang == 'en_US') return 'Take after lunch · drink half cup of water';
      if (lang == 'zh_CN') return '午餐后服用 · 喝半杯温水';
      return '午餐後服用 · 飲半杯溫水';
    }
    if (id == 'med_night' || note == '睡前 1 小時服用') {
      if (lang == 'en_US') return 'Take 1 hour before bedtime';
      if (lang == 'zh_CN') return '睡前 1 小时服用';
      return '睡前 1 小時服用';
    }
    if (note == '飯後溫水送服' || note == '請準時服用') {
      if (lang == 'en_US') return 'Take on time with warm water';
      if (lang == 'zh_CN') return '饭后温水送服';
    }
    return note;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'lastTakenDate': lastTakenDate,
        'snoozedUntilMs': snoozedUntilMs,
      };

  MedicationReminder copyWith({
    String? title,
    String? note,
    int? hour,
    int? minute,
    bool? enabled,
    String? lastTakenDate,
    int? snoozedUntilMs,
    bool clearSnooze = false,
  }) =>
      MedicationReminder(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
        lastTakenDate: lastTakenDate ?? this.lastTakenDate,
        snoozedUntilMs:
            clearSnooze ? null : (snoozedUntilMs ?? this.snoozedUntilMs),
      );

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Multi-language Medication / Feeding / Clinic Reminder Service.
class MedicationService extends ChangeNotifier {
  MedicationService({required this.tts, this.settings});

  static const _kStorageKey = 'medication_reminders_v1';

  final TtsReaderService tts;
  final SettingsStore? settings;
  SharedPreferences? _prefs;
  Timer? _clock;

  final List<MedicationReminder> items = [];
  MedicationReminder? activeDueReminder;
  String? _lastAnnouncedKey;

  String get _lang => settings?.appLanguage ?? tts.settings.appLanguage;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    final raw = p.getString(_kStorageKey);
    items.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        items.addAll(list.map(MedicationReminder.fromJson));
      } catch (_) {}
    }
    if (items.isEmpty) {
      items.addAll([
        MedicationReminder(
          id: 'med_morning',
          title: '早上藥物／血壓藥',
          note: '飯後 1 粒 · 溫水送服',
          hour: 8,
          minute: 30,
          enabled: true,
        ),
        MedicationReminder(
          id: 'med_noon',
          title: '午間喂藥／補充水份',
          note: '午餐後服用 · 飲半杯溫水',
          hour: 13,
          minute: 0,
          enabled: true,
        ),
        MedicationReminder(
          id: 'med_night',
          title: '晚間常規藥物',
          note: '睡前 1 小時服用',
          hour: 20,
          minute: 30,
          enabled: true,
        ),
      ]);
      await _persist();
    }
    _sort();
    _startClock();
    notifyListeners();
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) => _checkDue());
  }

  void _checkDue() {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    for (final item in items) {
      if (!item.enabled || item.isTakenToday(now)) continue;
      if (item.snoozedUntilMs != null) {
        if (nowMs >= item.snoozedUntilMs! &&
            nowMs - item.snoozedUntilMs! < 120000) {
          _triggerAlert(item, now);
          return;
        }
        continue;
      }
      if (item.hour == now.hour && item.minute == now.minute) {
        _triggerAlert(item, now);
        return;
      }
    }
  }

  String _alertSpeech(MedicationReminder item) {
    final l = _lang;
    final t = item.localizedTitle(l);
    final n = item.localizedNote(l);
    if (l == 'en_US') {
      return 'Gentle reminder: It is ${item.timeLabel}, time for $t. $n';
    }
    if (l == 'zh_CN') {
      return '温馨提醒：现在是 ${item.timeLabel}，到时间“$t”啦。$n';
    }
    return '溫馨提醒：而家係 ${item.timeLabel}，到時間「$t」啦。$n';
  }

  void _triggerAlert(MedicationReminder item, DateTime now) {
    final announceKey =
        '${item.id}_${now.year}_${now.month}_${now.day}_${now.hour}_${now.minute}';
    if (_lastAnnouncedKey == announceKey) return;
    _lastAnnouncedKey = announceKey;
    activeDueReminder = item;
    notifyListeners();
    unawaited(tts.speak(_alertSpeech(item), force: true));
  }

  void triggerTestReminder(MedicationReminder item) {
    activeDueReminder = item;
    notifyListeners();
    unawaited(tts.speak(_alertSpeech(item), force: true));
  }

  Future<void> markTaken(String id) async {
    final now = DateTime.now();
    final today = MedicationReminder._dateKey(now);
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(lastTakenDate: today, clearSnooze: true);
    if (activeDueReminder?.id == id) {
      activeDueReminder = null;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> snooze10Min(String id) async {
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final until =
        DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch;
    items[idx] = items[idx].copyWith(snoozedUntilMs: until);
    if (activeDueReminder?.id == id) {
      activeDueReminder = null;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> addOrUpdate(MedicationReminder reminder) async {
    final idx = items.indexWhere((e) => e.id == reminder.id);
    if (idx >= 0) {
      items[idx] = reminder;
    } else {
      items.add(reminder);
    }
    _sort();
    await _persist();
    notifyListeners();
  }

  Future<void> toggleEnabled(String id, bool enabled) async {
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(enabled: enabled);
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    items.removeWhere((e) => e.id == id);
    if (activeDueReminder?.id == id) activeDueReminder = null;
    await _persist();
    notifyListeners();
  }

  List<MedicationReminder> get _pendingToday {
    final now = DateTime.now();
    return items.where((e) => e.enabled && !e.isTakenToday(now)).toList();
  }

  /// Earliest enabled reminder that has not been marked taken today.
  MedicationReminder? get nextPending {
    final pending = _pendingToday;
    if (pending.isEmpty) return null;
    return pending.first;
  }

  /// Overdue doses other than [nextPending], so the home page can list them
  /// once without repeating the dose already shown in large type.
  List<MedicationReminder> get unfinishedMeds {
    final now = DateTime.now();
    final nextId = nextPending?.id;
    return _pendingToday.where((e) {
      if (e.id == nextId) return false;
      if (e.isSnoozed(now)) return false;
      return e.isPastScheduledTime(now);
    }).toList();
  }

  String summaryForSpeech([String? langOverride]) {
    final l = langOverride ?? _lang;
    final enabledItems = items.where((e) => e.enabled).toList();
    if (enabledItems.isEmpty) {
      if (l == 'en_US') return 'No medication reminders scheduled yet.';
      if (l == 'zh_CN') return '目前尚未设置按时吃药提醒。';
      return '目前未設定按時食藥或日程提醒。';
    }
    final now = DateTime.now();
    final pending = enabledItems.where((e) => !e.isTakenToday(now)).toList();
    if (pending.isEmpty) {
      if (l == 'en_US') return 'All medication reminders for today are completed!';
      if (l == 'zh_CN') return '今天所有按时吃药提醒都已经完成啦！';
      return '今日所有按時食藥提醒都已經完成啦。';
    }
    final next = pending.first;
    final nextTitle = next.localizedTitle(l);
    if (l == 'en_US') {
      return '${pending.length} reminder(s) left today · Next: ${next.timeLabel} "$nextTitle"';
    }
    if (l == 'zh_CN') {
      return '今日还有 ${pending.length} 项提醒，下一项是 ${next.timeLabel} 的“$nextTitle”。';
    }
    return '今日仲有 ${pending.length} 項提醒，下一項係 ${next.timeLabel} 嘅「$nextTitle」。';
  }

  void _sort() {
    items.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      _kStorageKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }
}
