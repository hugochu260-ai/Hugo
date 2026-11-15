import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sos_emergency_dialog.dart';
import '../../services/ai/ai_agent_service.dart';
import '../../services/medication/medication_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../../services/tilt/tilt_analyzer.dart';
import '../../services/tilt/tilt_monitor_service.dart';

/// Home matches the phone preview: greeting, one reminder card, four shortcuts.
/// The next dose owns the card. Later doses and water sit inside it.
/// SOS is a small corner pill, not a daily action button.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.onNavigate,
    required this.onOpenMedications,
    required this.onOpenVisionHelper,
    required this.onOpenAntiLostCard,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenMedications;
  final VoidCallback onOpenVisionHelper;
  final VoidCallback onOpenAntiLostCard;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    final s = settings.strings;
    final lang = settings.appLanguage;
    final med = context.watch<MedicationService>();
    final tilt = context.watch<TiltMonitorService>();
    final ai = context.watch<AiAgentService>();
    final tts = context.read<TtsReaderService>();
    final now = DateTime.now();
    final next = med.nextPending;
    final enabled = med.items.where((e) => e.enabled).toList();
    final later = enabled
        .where((e) => e.id != next?.id && !e.isTakenToday(now))
        .toList();
    final pendingText = ai.pendingConfirmationDescription;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 108),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tilt.isEmergency) ...[
                Text(
                  tilt.status == TiltStatus.fallDetected
                      ? s.tr('偵測到跌倒撞擊', '侦测到跌倒撞击', 'Fall impact detected')
                      : s.tr('輪椅傾斜過大', '轮椅倾斜过大', 'Wheelchair tilt is too steep'),
                  style: TextStyle(
                    color: p.danger,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.tr('你好', '你好', 'Hello'),
                          style: TextStyle(
                            color: p.text,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _homeDate(now, s),
                          style: TextStyle(color: p.muted, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  _SosPill(label: s.sosPillLabel),
                ],
              ),
              if (pendingText != null) ...[
                const SizedBox(height: 16),
                _PendingRow(
                  title: pendingText,
                  onCancel: () => ai.cancelPendingAction(),
                  onConfirm: () async {
                    final msg = await ai.confirmPendingAction();
                    tts.speak(msg, force: true);
                  },
                ),
              ],
              const SizedBox(height: 16),
              _ReminderCard(
                palette: p,
                strings: s,
                lang: lang,
                next: next,
                enabled: enabled,
                later: later,
                now: now,
                waterCups: settings.waterCupsToday,
                waterGoal: SettingsStore.dailyWaterGoal,
                onTaken: next == null ? null : () => med.markTaken(next.id),
                onSnooze: next == null ? null : () => med.snooze10Min(next.id),
                onManage: onOpenMedications,
                onAddWater: () async {
                  await settings.addWaterCup(1);
                  tts.speak(
                    s.tr(
                      '今日已經飲咗 ${settings.waterCupsToday} 杯。',
                      '今天已经喝了 ${settings.waterCupsToday} 杯。',
                      'You have had ${settings.waterCupsToday} cups today.',
                    ),
                  );
                },
                onRead: () {
                  final speech = next == null
                      ? med.summaryForSpeech(lang)
                      : s.tr(
                          '下一項提醒 ${next.timeLabel}，${next.localizedTitle(lang)}。${next.localizedNote(lang)}',
                          '下一项提醒 ${next.timeLabel}，${next.localizedTitle(lang)}。${next.localizedNote(lang)}',
                          'Next reminder ${next.timeLabel}, ${next.localizedTitle(lang)}. ${next.localizedNote(lang)}',
                        );
                  tts.speak(speech, force: true);
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                talk: s.tr('溝通', '沟通', 'Talk'),
                travel: s.tr('出行', '出行', 'Go'),
                photo: s.tr('拍藥袋', '拍药袋', 'Photo'),
                card: s.tr('醫療卡', '医疗卡', 'Med card'),
                onTalk: () => onNavigate(1),
                onTravel: () => onNavigate(2),
                onPhoto: onOpenVisionHelper,
                onCard: onOpenAntiLostCard,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _homeDate(DateTime now, AppStrings s) {
  const hk = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  const en = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final weekday = s.isEnglish ? en[now.weekday - 1] : hk[now.weekday - 1];
  if (s.isEnglish) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[now.month - 1]} ${now.day}, $weekday';
  }
  return '${now.month}月${now.day}日 $weekday';
}

class _SosPill extends StatelessWidget {
  const _SosPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: p.danger,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        shape: const StadiumBorder(),
      ),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (_) => const SosEmergencyDialog(),
        );
      },
      child: Text(label),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.palette,
    required this.strings,
    required this.lang,
    required this.next,
    required this.enabled,
    required this.later,
    required this.now,
    required this.waterCups,
    required this.waterGoal,
    required this.onTaken,
    required this.onSnooze,
    required this.onManage,
    required this.onAddWater,
    required this.onRead,
  });

  final AppPalette palette;
  final AppStrings strings;
  final String lang;
  final MedicationReminder? next;
  final List<MedicationReminder> enabled;
  final List<MedicationReminder> later;
  final DateTime now;
  final int waterCups;
  final int waterGoal;
  final VoidCallback? onTaken;
  final VoidCallback? onSnooze;
  final VoidCallback onManage;
  final VoidCallback onAddWater;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final timing = next == null ? null : _doseTiming(next!, now);
    final timeColor = switch (timing) {
      _DoseTiming.overdue => palette.danger,
      _DoseTiming.dueNow || _DoseTiming.snoozed => palette.secondary,
      _ => palette.primary,
    };
    final String headline;
    final String? title;
    final String? note;
    if (next != null) {
      headline = next!.timeLabel;
      title = next!.localizedTitle(lang);
      note = next!.localizedNote(lang);
    } else if (enabled.isEmpty) {
      headline = s.tr('未有提醒', '未有提醒', 'No reminder');
      title = null;
      note = null;
    } else {
      final first = enabled.first;
      headline = s.tr('已全部服用', '已全部服用', 'All taken');
      title = s.tr(
        '聽日 ${first.timeLabel}  ${first.localizedTitle(lang)}',
        '明天 ${first.timeLabel}  ${first.localizedTitle(lang)}',
        'Tomorrow ${first.timeLabel}  ${first.localizedTitle(lang)}',
      );
      note = null;
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.tr('下一項提醒', '下一项提醒', 'Next reminder'),
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: s.tr('朗讀', '朗读', 'Read aloud'),
                visualDensity: VisualDensity.compact,
                onPressed: onRead,
                icon: Icon(Icons.volume_up_rounded, color: palette.primary, size: 22),
              ),
              TextButton(
                onPressed: onManage,
                child: Text(s.tr('管理', '管理', 'Manage')),
              ),
            ],
          ),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: next == null ? palette.text : timeColor,
              fontSize: next == null ? 32 : 56,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: next == null ? 0 : -1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted, fontSize: 15, height: 1.35),
            ),
          ],
          if (timing == _DoseTiming.overdue ||
              timing == _DoseTiming.dueNow ||
              timing == _DoseTiming.snoozed) ...[
            const SizedBox(height: 6),
            Text(
              switch (timing!) {
                _DoseTiming.dueNow => s.tr('已到時間', '已到时间', 'Due now'),
                _DoseTiming.overdue => s.tr('已過時', '已过时', 'Overdue'),
                _DoseTiming.snoozed => s.tr('稍後再提醒', '稍后再提醒', 'Snoozed'),
                _ => '',
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                color: timeColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              onPressed: onTaken,
              child: Text(s.tr('已服藥', '已服药', 'Taken')),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onSnooze,
                child: Text(s.tr('稍後 10 分鐘', '稍后 10 分钟', 'Snooze 10 min')),
              ),
            ),
          ],
          if (later.isNotEmpty) ...[
            const SizedBox(height: 4),
            Divider(color: palette.outline, height: 1),
            const SizedBox(height: 8),
            for (final item in later)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        item.timeLabel,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.localizedTitle(lang),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Divider(color: palette.outline, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.tr(
                    '今日飲水 $waterCups/$waterGoal 杯',
                    '今日饮水 $waterCups/$waterGoal 杯',
                    'Water today $waterCups/$waterGoal',
                  ),
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: onAddWater,
                child: Text(s.tr('+ 飲多一杯', '+ 再喝一杯', '+ One cup')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.talk,
    required this.travel,
    required this.photo,
    required this.card,
    required this.onTalk,
    required this.onTravel,
    required this.onPhoto,
    required this.onCard,
  });

  final String talk;
  final String travel;
  final String photo;
  final String card;
  final VoidCallback onTalk;
  final VoidCallback onTravel;
  final VoidCallback onPhoto;
  final VoidCallback onCard;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          _Shortcut(icon: Icons.forum_outlined, label: talk, onTap: onTalk),
          _Shortcut(icon: Icons.place_outlined, label: travel, onTap: onTravel),
          _Shortcut(icon: Icons.document_scanner_outlined, label: photo, onTap: onPhoto),
          _Shortcut(icon: Icons.medical_information_outlined, label: card, onTap: onCard),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: p.primary, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.title,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = context.watch<SettingsStore>().strings;
    return _Panel(
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: p.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(onPressed: onCancel, child: Text(s.tr('取消', '取消', 'Cancel'))),
          FilledButton(onPressed: onConfirm, child: Text(s.tr('確認', '确认', 'Confirm'))),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.outline.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: child,
      ),
    );
  }
}

enum _DoseTiming { upcoming, dueNow, overdue, snoozed }

_DoseTiming _doseTiming(MedicationReminder item, DateTime now) {
  if (item.isSnoozed(now)) return _DoseTiming.snoozed;
  if (!item.isPastScheduledTime(now)) return _DoseTiming.upcoming;
  final due = DateTime(now.year, now.month, now.day, item.hour, item.minute);
  if (now.difference(due).inMinutes >= 1) return _DoseTiming.overdue;
  return _DoseTiming.dueNow;
}
