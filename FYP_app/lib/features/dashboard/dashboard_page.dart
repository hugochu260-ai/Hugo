import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sos_emergency_dialog.dart';
import '../../services/ai/ai_agent_service.dart';
import '../../services/ble_car_service.dart';
import '../../services/drive/auto_drive_controller.dart';
import '../../services/medication/medication_service.dart';
import '../../services/radar/radar_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../../services/tilt/tilt_analyzer.dart';
import '../../services/tilt/tilt_monitor_service.dart';

/// Home is two notices, then everything else tucked away.
/// The next dose owns the top of the screen. Unfinished items sit under it.
/// Daily tools stay in one collapsed list so they do not compete with either.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.onNavigate,
    required this.onOpenMedications,
    required this.onOpenVoiceAssistant,
    required this.onOpenVisionHelper,
    required this.onOpenMagnifier,
    required this.onOpenAntiLostCard,
    required this.onOpenSettings,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenMedications;
  final VoidCallback onOpenVoiceAssistant;
  final VoidCallback onOpenVisionHelper;
  final VoidCallback onOpenMagnifier;
  final VoidCallback onOpenAntiLostCard;
  final VoidCallback onOpenSettings;

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
    final overdue = med.unfinishedMeds;
    final waterGoal = SettingsStore.dailyWaterGoal;
    final waterShort = settings.waterCupsToday < waterGoal;
    final pendingText = ai.pendingConfirmationDescription;
    final unfinishedCount = overdue.length +
        (waterShort ? 1 : 0) +
        (pendingText != null ? 1 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tilt.isEmergency) ...[
                Text(
                  tilt.status == TiltStatus.fallDetected
                      ? s.tr(
                          '偵測到跌倒撞擊',
                          '侦测到跌倒撞击',
                          'Fall impact detected',
                        )
                      : s.tr(
                          '輪椅傾斜過大',
                          '轮椅倾斜过大',
                          'Wheelchair tilt is too steep',
                        ),
                  style: TextStyle(
                    color: p.danger,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 28),
              ],
              _NextDose(
                palette: p,
                strings: s,
                lang: lang,
                next: next,
                enabled: med.items.where((e) => e.enabled).toList(),
                now: now,
                onTaken: next == null ? null : () => med.markTaken(next.id),
                onSnooze: next == null ? null : () => med.snooze10Min(next.id),
                onManage: onOpenMedications,
                onRead: () {
                  final speech = next == null
                      ? med.summaryForSpeech(lang)
                      : s.tr(
                          '下一劑藥 ${next.timeLabel}，${next.localizedTitle(lang)}。${next.localizedNote(lang)}',
                          '下一剂药 ${next.timeLabel}，${next.localizedTitle(lang)}。${next.localizedNote(lang)}',
                          'Next dose ${next.timeLabel}, ${next.localizedTitle(lang)}. ${next.localizedNote(lang)}',
                        );
                  tts.speak(speech, force: true);
                },
              ),
              const SizedBox(height: 40),
              _SectionLabel(
                s.tr('未完成', '未完成', 'Unfinished'),
                trailing: unfinishedCount == 0
                    ? null
                    : Text(
                        '$unfinishedCount',
                        style: TextStyle(
                          color: p.secondary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              if (unfinishedCount == 0)
                Text(
                  s.tr(
                    '今日沒有未完成事項',
                    '今天没有未完成事项',
                    'Nothing left unfinished today',
                  ),
                  style: TextStyle(
                    color: p.muted,
                    fontSize: 18,
                    height: 1.4,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pendingText != null)
                      _TaskRow(
                        title: pendingText,
                        detail: s.tr('等你確認', '等你确认', 'Waiting for you'),
                        actions: [
                          TextButton(
                            onPressed: () => ai.cancelPendingAction(),
                            child: Text(s.tr('取消', '取消', 'Cancel')),
                          ),
                          FilledButton(
                            onPressed: () async {
                              final msg = await ai.confirmPendingAction();
                              tts.speak(msg, force: true);
                            },
                            child: Text(s.tr('確認', '确认', 'Confirm')),
                          ),
                        ],
                      ),
                    for (final item in overdue)
                      _TaskRow(
                        title: item.localizedTitle(lang),
                        detail: s.tr(
                          '${item.timeLabel} 未服',
                          '${item.timeLabel} 未服',
                          '${item.timeLabel} not taken',
                        ),
                        actions: [
                          FilledButton.tonal(
                            onPressed: () => med.markTaken(item.id),
                            child: Text(s.tr('已服藥', '已服药', 'Taken')),
                          ),
                        ],
                      ),
                    if (waterShort)
                      _TaskRow(
                        title: s.tr('飲水未夠', '喝水未够', 'Water still short'),
                        detail:
                            '${settings.waterCupsToday} / $waterGoal',
                        actions: [
                          IconButton(
                            tooltip: s.tr('飲咗一杯', '喝了一杯', 'Add one cup'),
                            onPressed: () async {
                              await settings.addWaterCup(1);
                              tts.speak(
                                s.tr(
                                  '今日已經飲咗 ${settings.waterCupsToday} 杯。',
                                  '今天已经喝了 ${settings.waterCupsToday} 杯。',
                                  'You have had ${settings.waterCupsToday} cups today.',
                                ),
                              );
                            },
                            icon: Icon(Icons.add_rounded, color: p.primary),
                          ),
                        ],
                      ),
                  ],
                ),
              const SizedBox(height: 48),
              _OtherTools(
                onCallAssistant: onOpenVoiceAssistant,
                onVision: onOpenVisionHelper,
                onMagnifier: onOpenMagnifier,
                onAntiLost: onOpenAntiLostCard,
                onEye: () => onNavigate(1),
                onBus: () => onNavigate(2),
                onSettings: onOpenSettings,
              ),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const SosEmergencyDialog(),
                    );
                  },
                  icon: Icon(Icons.emergency_rounded, color: p.danger, size: 20),
                  label: Text(s.sosBtnLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: p.danger,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextDose extends StatelessWidget {
  const _NextDose({
    required this.palette,
    required this.strings,
    required this.lang,
    required this.next,
    required this.enabled,
    required this.now,
    required this.onTaken,
    required this.onSnooze,
    required this.onManage,
    required this.onRead,
  });

  final AppPalette palette;
  final AppStrings strings;
  final String lang;
  final MedicationReminder? next;
  final List<MedicationReminder> enabled;
  final DateTime now;
  final VoidCallback? onTaken;
  final VoidCallback? onSnooze;
  final VoidCallback onManage;
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
    final String? support;
    final String? stateLabel;
    if (next != null) {
      headline = next!.timeLabel;
      support = next!.localizedTitle(lang);
      stateLabel = switch (timing!) {
        _DoseTiming.upcoming => s.tr('未到時間', '未到时间', 'Not yet'),
        _DoseTiming.dueNow => s.tr('已到時間', '已到时间', 'Due now'),
        _DoseTiming.overdue => s.tr('已過時', '已过时', 'Overdue'),
        _DoseTiming.snoozed => s.tr('稍後再提醒', '稍后再提醒', 'Snoozed'),
      };
    } else if (enabled.isEmpty) {
      headline = s.tr('未有提醒', '未有提醒', 'No reminder');
      support = null;
      stateLabel = null;
    } else {
      headline = s.tr('已全部服用', '已全部服用', 'All taken');
      final first = enabled.first;
      support = s.tr(
        '聽日 ${first.timeLabel}  ${first.localizedTitle(lang)}',
        '明天 ${first.timeLabel}  ${first.localizedTitle(lang)}',
        'Tomorrow ${first.timeLabel}  ${first.localizedTitle(lang)}',
      );
      stateLabel = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.tr('下一劑藥', '下一剂药', 'Next dose'),
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            IconButton(
              tooltip: s.tr('朗讀', '朗读', 'Read aloud'),
              onPressed: onRead,
              icon: Icon(Icons.volume_up_rounded, color: palette.primary),
            ),
            TextButton(
              onPressed: onManage,
              child: Text(s.tr('管理', '管理', 'Manage')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          headline,
          style: TextStyle(
            color: next == null ? palette.text : timeColor,
            fontSize: next == null ? 36 : 56,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: next == null ? 0 : -1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (support != null) ...[
          const SizedBox(height: 12),
          Text(
            support,
            style: TextStyle(
              color: palette.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
        if (next != null && next!.localizedNote(lang).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            next!.localizedNote(lang),
            style: TextStyle(color: palette.muted, fontSize: 16, height: 1.4),
          ),
        ],
        if (stateLabel != null) ...[
          const SizedBox(height: 10),
          Text(
            stateLabel,
            style: TextStyle(
              color: timeColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        if (next != null) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(148, 52),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: onTaken,
                child: Text(s.tr('已服藥', '已服药', 'Taken')),
              ),
              TextButton(
                onPressed: onSnooze,
                child: Text(s.tr('稍後 10 分鐘', '稍后 10 分钟', 'Snooze 10 min')),
              ),
            ],
          ),
        ],
      ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: p.muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.title,
    required this.detail,
    required this.actions,
  });

  final String title;
  final String detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(color: p.muted, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ...actions,
        ],
      ),
    );
  }
}

class _OtherTools extends StatelessWidget {
  const _OtherTools({
    required this.onCallAssistant,
    required this.onVision,
    required this.onMagnifier,
    required this.onAntiLost,
    required this.onEye,
    required this.onBus,
    required this.onSettings,
  });

  final VoidCallback onCallAssistant;
  final VoidCallback onVision;
  final VoidCallback onMagnifier;
  final VoidCallback onAntiLost;
  final VoidCallback onEye;
  final VoidCallback onBus;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    final s = settings.strings;
    final ble = context.watch<BleCarService>();
    final radar = context.watch<RadarService>();
    final auto = context.watch<AutoDriveController>();
    final linked = ble.isConnected || auto.controlConnected;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: p.muted,
        collapsedIconColor: p.muted,
        title: Text(
          s.tr('其他功能', '其他功能', 'Other tools'),
          style: TextStyle(
            color: p.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          s.tr(
            '拍藥袋、放大鏡、眼控、巴士',
            '拍药袋、放大镜、眼控、公交',
            'Medicine photo, magnifier, eye board, bus',
          ),
          style: TextStyle(color: p.muted, fontSize: 13),
        ),
        children: [
          _ToolTile(
            icon: Icons.record_voice_over_rounded,
            label: s.tr(
              '呼叫「${settings.assistantName}」',
              '呼叫“${settings.assistantName}”',
              'Call "${settings.assistantName}"',
            ),
            onTap: onCallAssistant,
          ),
          _ToolTile(
            icon: Icons.document_scanner_outlined,
            label: s.tr('拍藥袋／睇環境', '拍药袋／看环境', 'Medicine photo'),
            onTap: onVision,
          ),
          _ToolTile(
            icon: Icons.zoom_in_rounded,
            label: s.tr('放大鏡與電筒', '放大镜与手电筒', 'Magnifier and torch'),
            onTap: onMagnifier,
          ),
          _ToolTile(
            icon: Icons.badge_outlined,
            label: s.tr('平安回家卡', '平安回家卡', 'Safe-return card'),
            onTap: onAntiLost,
          ),
          _ToolTile(
            icon: Icons.remove_red_eye_outlined,
            label: s.tr('眼控溝通板', '眼控沟通板', 'Eye communication board'),
            onTap: onEye,
          ),
          _ToolTile(
            icon: Icons.directions_bus_outlined,
            label: s.tr('巴士與醫院路線', '公交与医院路线', 'Bus and hospital routes'),
            onTap: onBus,
          ),
          _ToolTile(
            icon: Icons.settings_outlined,
            label: s.tr('語言與設定', '语言与设置', 'Language and settings'),
            onTap: onSettings,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text(
              linked
                  ? s.tr(
                      '輪椅已連接${radar.isLive ? " · 雷達運作中" : ""}',
                      '轮椅已连接${radar.isLive ? " · 雷达运行中" : ""}',
                      'Wheelchair linked${radar.isLive ? " · radar live" : ""}',
                    )
                  : s.tr(
                      '獨立使用，未連輪椅',
                      '独立使用，未连轮椅',
                      'Standalone, wheelchair not linked',
                    ),
              style: TextStyle(color: p.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 28,
      leading: Icon(icon, color: p.primary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: p.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: p.muted),
      onTap: onTap,
    );
  }
}
