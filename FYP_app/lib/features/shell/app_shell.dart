import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/elderly_toolkit_sheets.dart';
import '../../core/widgets/sos_emergency_dialog.dart';
import '../../core/widgets/vision_helper_sheet.dart';
import '../../core/widgets/voice_assistant_sheet.dart';
import '../../services/ai/ai_agent_service.dart';
import '../../services/ble_car_service.dart';
import '../../services/drive/auto_drive_controller.dart';
import '../../services/medication/medication_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../../services/speech/voice_wake_service.dart';
import '../../services/tilt/tilt_monitor_service.dart';
import '../agent/agent_page.dart';
import '../dashboard/dashboard_page.dart';
import '../dev/dev_lab_page.dart';
import '../drive/drive_page.dart';
import '../eye/eye_page.dart';
import '../settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _eyeInitialTab = 0;
  bool _sosDialogOpen = false;

  @override
  void initState() {
    super.initState();
    final wake = context.read<VoiceWakeService>();
    final ai = context.read<AiAgentService>();

    wake.onWakeTriggered = (String trailingCmd) {
      if (!mounted) return;
      _openVoiceAssistant(initialCommand: trailingCmd);
    };
    ai.onSosTriggered = () {
      if (!mounted || _sosDialogOpen) return;
      _sosDialogOpen = true;
      showDialog<void>(
        context: context,
        builder: (_) => const SosEmergencyDialog(),
      ).whenComplete(() => _sosDialogOpen = false);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(wake.startPassiveWake());
    });
  }

  Future<void> _openVoiceAssistant({String initialCommand = ''}) async {
    final wake = context.read<VoiceWakeService>();
    wake.setDialogOpen(true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VoiceAssistantSheet(initialCommand: initialCommand),
    );
    wake.setDialogOpen(false);
  }

  Future<void> _openVisionHelper() async {
    final wake = context.read<VoiceWakeService>();
    wake.setSuspendedByPage(true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const VisionHelperSheet(),
    );
    if (mounted) wake.setSuspendedByPage(_index == 1);
  }

  Future<void> _openMagnifier() async {
    final wake = context.read<VoiceWakeService>();
    wake.setSuspendedByPage(true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const MagnifierTorchSheet(),
    );
    if (mounted) wake.setSuspendedByPage(_index == 1);
  }

  Future<void> _openAntiLostCard() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AntiLostMedicalSheet(),
    );
  }

  Future<void> _openTopSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsPage(embedded: false),
      ),
    );
    // Ensure passive wake resumes cleanly when returning from Settings
    if (mounted && _index != 1) {
      unawaited(context.read<VoiceWakeService>().startPassiveWake());
    }
  }

  void _go(int idx, bool devMode, {int eyeTab = 0}) {
    final maxIdx = devMode ? 4 : 3;
    final clamped = idx.clamp(0, maxIdx);
    setState(() {
      _index = clamped;
      if (clamped == 1) _eyeInitialTab = eyeTab.clamp(0, 2);
    });
    context.read<VoiceWakeService>().setSuspendedByPage(clamped == 1);
  }

  void _readCurrentScreenSummary() {
    final tts = context.read<TtsReaderService>();
    if (tts.speaking) {
      tts.stop();
      return;
    }
    final settings = context.read<SettingsStore>();
    final s = settings.strings;
    final med = context.read<MedicationService>();
    final ai = context.read<AiAgentService>();

    String summary;
    switch (_index) {
      case 0:
        final lang = settings.appLanguage;
        final next = med.nextPending;
        final dose = next == null
            ? (med.items.any((e) => e.enabled)
                ? s.tr(
                    '今日藥物已經全部服用。',
                    '今天药物已经全部服用。',
                    'Today\'s medicines are all taken.',
                  )
                : s.tr('未有用藥提醒。', '未有用药提醒。', 'No medication reminders.'))
            : s.tr(
                '下一劑藥 ${next.timeLabel}，${next.localizedTitle(lang)}。',
                '下一剂药 ${next.timeLabel}，${next.localizedTitle(lang)}。',
                'Next dose ${next.timeLabel}, ${next.localizedTitle(lang)}.',
              );
        final openCount = med.unfinishedMeds.length +
            (settings.waterCupsToday < SettingsStore.dailyWaterGoal ? 1 : 0) +
            (ai.hasPendingConfirmation ? 1 : 0);
        final open = openCount == 0
            ? s.tr('沒有未完成事項。', '没有未完成事项。', 'Nothing left unfinished.')
            : s.tr(
                '未完成 $openCount 項。',
                '未完成 $openCount 项。',
                '$openCount unfinished item${openCount == 1 ? '' : 's'}.',
              );
        summary = s.tr(
          '智行友伴首頁。$dose$open',
          '智行友伴首页。$dose$open',
          'Smart Companion home. $dose $open',
        );
        break;
      case 1:
        summary = s.tr(
          '呢度係眼控同大字溝通板頁。用眼睛望住大格或者用手輕觸，就會大聲讀出你嘅需要。',
          '这里是眼控与大字沟通板页。注视大格或轻触即可大声读出你的需求。',
          'Eye-gaze and touch AAC communication board. Hold your gaze or tap any tile to speak aloud.',
        );
        break;
      case 2:
        summary = s.tr(
          '呢度係無障礙巴士同路線規劃頁。',
          '这里是无障碍公交与路线规划页。',
          'Accessible bus stops and point-to-point hospital route planner.',
        );
        break;
      default:
        summary = ai.lastReply ??
            s.tr(
              '呢度係「${settings.assistantName}」AI 對話頁。',
              '这里是“${settings.assistantName}”AI 对话页。',
              '${settings.assistantName} AI Assistant chat.',
            );
    }
    tts.speak(summary, force: true);
  }

  Widget _buildActivePage(bool devMode) {
    final safeIdx = (!devMode && _index > 3) ? 0 : _index;
    switch (safeIdx) {
      case 0:
        return DashboardPage(
          key: const ValueKey('home'),
          onNavigate: (i) => _go(i, devMode),
          onOpenMedications: () => _go(1, devMode, eyeTab: 2),
          onOpenVoiceAssistant: () => _openVoiceAssistant(),
          onOpenVisionHelper: _openVisionHelper,
          onOpenMagnifier: _openMagnifier,
          onOpenAntiLostCard: _openAntiLostCard,
          onOpenSettings: _openTopSettingsPage,
        );
      case 1:
        return EyePage(
          key: ValueKey('care_eye_$_eyeInitialTab'),
          initialTab: _eyeInitialTab,
        );
      case 2:
        return DrivePage(
          key: const ValueKey('mobility_bus'),
          onNavigate: (i) => _go(i, devMode),
        );
      case 3:
        return AgentPage(
          key: const ValueKey('assistant_settings'),
          onOpenVisionHelper: _openVisionHelper,
        );
      case 4:
        return const DevLabPage(key: ValueKey('dev_lab'));
      default:
        return DashboardPage(
          key: const ValueKey('home'),
          onNavigate: (i) => _go(i, devMode),
          onOpenMedications: () => _go(1, devMode, eyeTab: 2),
          onOpenVoiceAssistant: () => _openVoiceAssistant(),
          onOpenVisionHelper: _openVisionHelper,
          onOpenMagnifier: _openMagnifier,
          onOpenAntiLostCard: _openAntiLostCard,
          onOpenSettings: _openTopSettingsPage,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    final s = settings.strings;
    final med = context.watch<MedicationService>();
    final tts = context.watch<TtsReaderService>();
    final ble = context.watch<BleCarService>();
    final auto = context.watch<AutoDriveController>();
    final tilt = context.read<TiltMonitorService>();

    // Keep smart tilt context synced with hardware connection & user mode!
    tilt.syncContext(
      mode: settings.tiltMode,
      isHardwareLinked: ble.isConnected || auto.controlConnected,
    );

    final dev = settings.developerMode;
    final safeIdx = (!dev && _index > 3) ? 0 : _index;

    final appBar = AppBar(
      title: Row(
        children: [
          Icon(Icons.accessible_forward_rounded, color: p.primary, size: 25),
          const SizedBox(width: 8),
          Flexible(
            child: Text(s.appTitle, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: s.tr('切換語言', '切换语言', 'Switch Language'),
          onSelected: settings.updateAppLanguage,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'zh_HK', child: Text('繁體中文（廣東話）')),
            PopupMenuItem(value: 'zh_CN', child: Text('简体中文（普通话）')),
            PopupMenuItem(value: 'en_US', child: Text('English')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language_rounded, size: 17, color: p.primary),
                  const SizedBox(width: 4),
                  Text(
                    s.languageShortLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: p.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: tts.speaking ? s.stopReadTooltip : s.readAloudTooltip,
          onPressed: _readCurrentScreenSummary,
          icon: Icon(
            tts.speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
            color: tts.speaking ? p.danger : p.primary,
          ),
        ),
        IconButton(
          tooltip: s.voiceBtnLabel,
          onPressed: () => _openVoiceAssistant(),
          icon: Icon(Icons.mic_rounded, color: p.primary),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            tooltip: s.settingsTooltip,
            onPressed: _openTopSettingsPage,
            icon: Icon(Icons.settings_rounded, color: p.text),
          ),
        ),
      ],
    );

    final dueMed = med.activeDueReminder;
    final lang = settings.appLanguage;
    final bodyColumn = Column(
      children: [
        if (dueMed != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: p.secondary,
            child: Row(
              children: [
                const Icon(Icons.medication_liquid_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${s.tr('到鐘提醒', '到点提醒', 'Reminder')} (${dueMed.timeLabel}): ${dueMed.localizedTitle(lang)} · ${dueMed.localizedNote(lang)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: () => med.markTaken(dueMed.id),
                  child: Text(s.tr('已服藥', '已服药', 'Taken')),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => med.snooze10Min(dueMed.id),
                  child: Text(
                    s.tr('稍後', '稍后', 'Snooze'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: _buildActivePage(dev)),
      ],
    );

    // Notice Tab 4 dynamically displays the user's custom assistantName!
    final aiTabLabel = settings.assistantName.trim().isEmpty
        ? s.navAiAssistant
        : '${settings.assistantName} AI';

    final navItems = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, s.navHome),
      (Icons.record_voice_over_outlined, Icons.record_voice_over_rounded, s.navEyeAac),
      (Icons.directions_bus_outlined, Icons.directions_bus_rounded, s.navBusMobility),
      (Icons.smart_toy_outlined, Icons.smart_toy_rounded, aiTabLabel),
      if (dev) (Icons.science_outlined, Icons.science_rounded, s.navDevLab),
    ];

    final scaffold = Responsive.isTablet(context)
        ? Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: safeIdx,
                  onDestinationSelected: (i) => _go(i, dev),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in navItems)
                      NavigationRailDestination(
                        icon: Icon(item.$1),
                        selectedIcon: Icon(item.$2),
                        label: Text(item.$3),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: bodyColumn),
              ],
            ),
          )
        : Scaffold(
            appBar: appBar,
            body: bodyColumn,
            bottomNavigationBar: NavigationBar(
              selectedIndex: safeIdx,
              onDestinationSelected: (i) => _go(i, dev),
              destinations: [
                for (final item in navItems)
                  NavigationDestination(
                    icon: Icon(item.$1),
                    selectedIcon: Icon(item.$2),
                    label: item.$3,
                  ),
              ],
            ),
          );

    // Global touch detector: when user holds/taps screen, suppress false tilt alarms!
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => tilt.recordUserTouch(),
      onPointerMove: (_) => tilt.recordUserTouch(),
      child: scaffold,
    );
  }
}
