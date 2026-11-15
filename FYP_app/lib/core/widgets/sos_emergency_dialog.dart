import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/ai/ai_agent_service.dart';
import '../../services/drive/auto_drive_controller.dart';
import '../../services/location_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../theme/app_theme.dart';

class SosEmergencyDialog extends StatefulWidget {
  const SosEmergencyDialog({super.key});

  @override
  State<SosEmergencyDialog> createState() => _SosEmergencyDialogState();
}

class _SosEmergencyDialogState extends State<SosEmergencyDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final str = context.read<SettingsStore>().strings;
      unawaited(context
          .read<AutoDriveController>()
          .emergencyStopAll(reason: 'SOS 緊急求助'));
      unawaited(context.read<LocationService>().fetchCurrentLocation());
      unawaited(context.read<TtsReaderService>().speak(
            str.tr(
              '已啟動緊急求助！請旁人協助或聯絡照顧者。',
              '已启动紧急求助！请旁人协助或联络照顾者。',
              'Emergency SOS activated! Please assist or contact the caregiver.',
            ),
            force: true,
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    final str = settings.strings;
    final loc = context.watch<LocationService>();
    final pos = loc.current;
    final posText = pos != null
        ? '${pos.lat.toStringAsFixed(5)}, ${pos.lon.toStringAsFixed(5)}'
        : (loc.loading
            ? str.tr('正在取得 GPS 座標…', '正在获取 GPS 坐标…', 'Getting GPS...')
            : (loc.error ?? str.tr('暫無 GPS 座標', '暂无 GPS 坐标', 'GPS unavailable')));

    return AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: p.danger, width: 2.5),
      ),
      title: Row(
        children: [
          Icon(Icons.emergency_rounded, color: p.danger, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              str.tr('緊急求助（SOS）', '紧急求助（SOS）', 'Emergency SOS'),
              style: TextStyle(
                color: p.danger,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              str.tr(
                '如需現場路人或醫護協助，可按下方大聲播報求救語音，或複製目前定位傳送畀照顧者。',
                '如需现场路人或医护协助，可按下方大声播报求救语音，或复制当前定位发送给照顾者。',
                'Tap below to broadcast a loud emergency call for nearby help, or copy your GPS link to send to your caregiver.',
              ),
              style: TextStyle(fontSize: 15, height: 1.45, color: p.text),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${str.tr('緊急聯絡人', '紧急联系人', 'Contact')}：${settings.caregiverName}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16, color: p.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    settings.caregiverPhone.isNotEmpty
                        ? '${str.tr('聯絡電話', '联系电话', 'Phone')}：${settings.caregiverPhone}'
                        : str.tr('聯絡電話：尚未於設定填寫', '联系电话：尚未填写', 'Phone: Not set yet'),
                    style: TextStyle(fontSize: 15, color: p.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'GPS：$posText',
                    style: TextStyle(fontSize: 13.5, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: p.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: () {
                context.read<TtsReaderService>().speak(
                      str.tr(
                        '緊急求助！呢位用家身體不適或遇到困難，請現場人士幫忙協助，或者聯絡照顧者 ${settings.caregiverName}！',
                        '紧急求助！这位用户身体不适或遇到困难，请现场人士帮忙协助，或联系照顾者 ${settings.caregiverName}！',
                        'Emergency! This person needs immediate assistance. Please help or contact caregiver ${settings.caregiverName}!',
                      ),
                      force: true,
                    );
              },
              icon: const Icon(Icons.campaign_rounded, size: 24),
              label: Text(str.tr('大聲播放現場呼救語音', '大声播放现场呼救语音', 'Broadcast Loud SOS Voice')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                final msg =
                    '[SOS] GPS: $posText https://maps.google.com/?q=${pos?.lat ?? ''},${pos?.lon ?? ''}';
                Clipboard.setData(ClipboardData(text: msg));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(str.tr(
                      '已複製求救訊息與 Google Maps 定位連結',
                      '已复制求救信息与定位链接',
                      'Copied SOS message and Google Maps GPS link',
                    )),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(str.tr('複製求救訊息及地圖定位', '复制求救信息及地图定位', 'Copy SOS & GPS Link')),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () {
            context.read<AiAgentService>().sosActive = false;
            Navigator.of(context).pop();
          },
          child: Text(str.tr('解除警報並返回', '解除警报并返回', 'Dismiss SOS')),
        ),
      ],
    );
  }
}
