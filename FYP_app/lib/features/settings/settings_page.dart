import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/assistant_image.dart';
import '../../core/widgets/assistant_portrait.dart';
import '../../core/widgets/section_card.dart';
import '../../services/ai/ai_agent_service.dart';
import '../../services/settings_store.dart';
import '../../services/speech/tts_reader_service.dart';
import '../../services/speech/voice_wake_service.dart';
import '../../services/tilt/tilt_monitor_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsStore s;
  late final TextEditingController assistantNameCtrl;
  late final TextEditingController customWakeCtrl;
  late final TextEditingController caregiverName;
  late final TextEditingController caregiverPhone;
  late final TextEditingController aiEndpoint;
  late final TextEditingController aiModel;
  late final TextEditingController aiKey;
  late final TextEditingController server;
  late final TextEditingController apiKey;
  late final TextEditingController bleName;
  late final TextEditingController instruction;
  late final TextEditingController wsUrl;
  late final TextEditingController cameraWsUrl;

  bool _testingVln = false;
  String? _vlnTestResult;
  bool _testingAi = false;
  String? _aiTestResult;
  bool _showAiKey = false;

  @override
  void initState() {
    super.initState();
    s = context.read<SettingsStore>();
    assistantNameCtrl = TextEditingController(text: s.assistantName);
    customWakeCtrl = TextEditingController(text: s.customWakeWords);
    caregiverName = TextEditingController(text: s.caregiverName);
    caregiverPhone = TextEditingController(text: s.caregiverPhone);
    aiEndpoint = TextEditingController(text: s.aiEndpoint);
    aiModel = TextEditingController(text: s.aiModel);
    aiKey = TextEditingController(text: s.aiKey);
    server = TextEditingController(text: s.serverUrl);
    apiKey = TextEditingController(text: s.apiKey);
    bleName = TextEditingController(text: s.bleName);
    instruction = TextEditingController(text: s.instruction);
    wsUrl = TextEditingController(text: s.radarWsUrl);
    cameraWsUrl = TextEditingController(text: s.cameraWsUrl);
  }

  @override
  void dispose() {
    for (final c in [
      assistantNameCtrl,
      customWakeCtrl,
      caregiverName,
      caregiverPhone,
      aiEndpoint,
      aiModel,
      aiKey,
      server,
      apiKey,
      bleName,
      instruction,
      wsUrl,
      cameraWsUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAllFields() async {
    await s.updateAssistantName(assistantNameCtrl.text);
    await s.updateCustomWakeWords(customWakeCtrl.text);
    await s.updateCaregiverName(caregiverName.text);
    await s.updateCaregiverPhone(caregiverPhone.text);
    await s.updateAiEndpoint(aiEndpoint.text);
    await s.updateAiModel(aiModel.text);
    await s.updateAiKey(aiKey.text);
    await s.updateServerUrl(server.text);
    await s.updateApiKey(apiKey.text);
    await s.updateBleName(bleName.text);
    await s.updateInstruction(instruction.text);
    await s.updateRadarWsUrl(wsUrl.text);
    await s.updateCameraWsUrl(cameraWsUrl.text);
    if (!mounted) return;
    await context.read<VoiceWakeService>().forceRestartWake();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.strings.tr(
            '已儲存並更新！而家可以直接叫「${s.assistantName}」喚醒助手（同音字亦識聽）！',
            '已保存并更新！现在可以直接喊“${s.assistantName}”唤醒助手！',
            'Saved! You can now call "${s.assistantName}" hands-free!',
          ),
        ),
      ),
    );
  }

  Future<void> _testDeepSeekAi() async {
    await _saveAllFields();
    setState(() {
      _testingAi = true;
      _aiTestResult = null;
    });
    try {
      final res = await context.read<AiAgentService>().testAiConnection();
      setState(() => _aiTestResult = res);
    } catch (e) {
      setState(() => _aiTestResult = 'DeepSeek 測試失敗：$e');
    } finally {
      if (mounted) setState(() => _testingAi = false);
    }
  }

  Future<void> _testVlnServer() async {
    setState(() {
      _testingVln = true;
      _vlnTestResult = null;
    });
    try {
      var url = server.text.trim();
      if (!url.startsWith('http')) url = 'https://$url';
      while (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      final res = await http
          .get(Uri.parse('$url/healthz'))
          .timeout(const Duration(seconds: 8));
      setState(() => _vlnTestResult = 'HTTP ${res.statusCode}：${res.body}');
    } catch (e) {
      setState(() => _vlnTestResult = '連線失敗：$e');
    } finally {
      if (mounted) setState(() => _testingVln = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    final str = settings.strings;
    final tts = context.read<TtsReaderService>();
    final wake = context.watch<VoiceWakeService>();
    final tilt = context.read<TiltMonitorService>();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Language Switcher & Custom Wake-Word / Assistant Name (with Live Mic Test!)
        SectionCard(
          title: str.tr(
            '語言切換與自訂語音助手名字（支援同音字識別）',
            '语言切换与自定义语音助手名字（支持同音字识别）',
            'Language & Custom Assistant Wake Name',
          ),
          subtitle: str.tr(
            '改名後撳「確認改名」即同步更新底部導航、對話歡迎詞及語音待命（叫「小寶／小保」都識應！）',
            '改名后按“确认改名”即同步更新底部导航、欢迎词及语音待命',
            'Tap "Apply Name" after editing to sync tabs, chat greeting & hands-free wake word',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'zh_HK',
                    icon: Icon(Icons.translate_rounded),
                    label: Text('廣東話'),
                  ),
                  ButtonSegment(
                    value: 'zh_CN',
                    icon: Icon(Icons.language_rounded),
                    label: Text('普通话'),
                  ),
                  ButtonSegment(
                    value: 'en_US',
                    icon: Icon(Icons.public_rounded),
                    label: Text('English'),
                  ),
                ],
                selected: {settings.appLanguage},
                onSelectionChanged: (sel) =>
                    settings.updateAppLanguage(sel.first),
                showSelectedIcon: false,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: assistantNameCtrl,
                      onSubmitted: (_) => _saveAllFields(),
                      decoration: InputDecoration(
                        labelText: str.tr(
                          '語音助手稱呼（例如：小寶、阿智、乖孫）',
                          '语音助手称呼（例如：小宝、阿智、乖孙）',
                          'Assistant Name (e.g. XiaoBao, Buddy)',
                        ),
                        prefixIcon: const Icon(Icons.record_voice_over_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saveAllFields,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(str.tr('確認改名', '确认改名', 'Apply Name')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in const [
                    '小寶',
                    '阿智',
                    '小明',
                    '乖孫',
                    '阿強',
                    'Buddy'
                  ])
                    ActionChip(
                      label: Text(str.tr('改叫「$preset」', '改叫“$preset”', 'Use "$preset"')),
                      onPressed: () async {
                        assistantNameCtrl.text = preset;
                        await settings.updateAssistantName(preset);
                        if (context.mounted) {
                          await context
                              .read<VoiceWakeService>()
                              .forceRestartWake();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.outline),
                      ),
                      child: AssistantPortrait(
                        imagePath: settings.assistantImagePath,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          str.tr(
                            '阿智頭像',
                            '阿智头像',
                            'Assistant portrait',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          str.tr(
                            '點一下浮動頭像會打開對話。長按頭像，或按下面的按鈕，就可以換成自己的相片。',
                            '点一下浮动头像会打开对话。长按头像，或按下面的按钮，就可以换成自己的照片。',
                            'Tap the floating portrait to talk. Long-press it, or use the button, to choose a photo.',
                          ),
                          style: TextStyle(color: p.muted, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => changeAssistantImage(context),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(str.tr('更換頭像', '更换头像', 'Change photo')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Live Wake Word Status & Diagnostics Box!
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.outline),
                ),
                child: Row(
                  children: [
                    Icon(
                      wake.passiveListening
                          ? Icons.hearing_rounded
                          : Icons.mic_off_rounded,
                      color: wake.passiveListening ? p.success : p.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wake.passiveListening
                                ? str.tr(
                                    '語音待命運作中：試下直接叫一聲「${settings.assistantName}」！',
                                    '语音待命运行中：试着直接喊一声“${settings.assistantName}”！',
                                    'Listening! Try saying "${settings.assistantName}" out loud now!',
                                  )
                                : str.tr('語音待命暫停中，請按右邊重啟', '语音待命暂停中', 'Wake word paused'),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: p.text,
                            ),
                          ),
                          if (wake.partialHeard.isNotEmpty)
                            Text(
                              '${str.tr('剛聽到', '刚听到', 'Last heard')}：「${wake.partialHeard}」',
                              style: TextStyle(fontSize: 13, color: p.primary),
                            ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: wake.forceRestartWake,
                      child: Text(str.tr('重啟監聽', '重启监听', 'Restart Mic')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(str.tr(
                  '開啟語音待命（叫「${settings.assistantName}」即彈出）',
                  '开启语音待命（喊“${settings.assistantName}”即弹出）',
                  'Hands-Free Wake Word ("${settings.assistantName}")',
                )),
                value: settings.wakeWordEnabled,
                onChanged: (v) => settings.updateWakeWordEnabled(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Smart Scene-Aware Tilt & Fall Mode (Solves handheld vs car-mount!)
        SectionCard(
          title: str.tr(
            '智能傾斜與防跌模式（解決「攞起手機睇嘢誤響」問題）',
            '智能倾斜与防跌模式（解决“拿起手机看屏幕误响”问题）',
            'Smart Handheld vs. Wheelchair-Mount Tilt Mode',
          ),
          subtitle: str.tr(
            '推薦用「智能自動感應」：平時攞喺手睇 mon 絕唔會亂響（只測真跌落地下）；連上輪椅／模型車時先自動鎖定支架角度做斜坡減速同防翻車！',
            '推荐用“智能自动感应”：平时拿在手里看屏幕绝不乱响；连上轮椅／模型车时自动锁定支架角度！',
            'Auto mode stays silent when holding your phone in hand, and auto-locks mount angle when connected to a wheelchair/car!',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'auto',
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(str.tr('智能自動感應', '智能自动感应', 'Smart Auto')),
                  ),
                  ButtonSegment(
                    value: 'handheld',
                    icon: const Icon(Icons.smartphone_rounded),
                    label: Text(str.tr('純手持防跌', '纯手持防跌', 'Handheld Only')),
                  ),
                  ButtonSegment(
                    value: 'mounted',
                    icon: const Icon(Icons.accessible_forward_rounded),
                    label: Text(str.tr('強制車載支架', '强制车载支架', 'Car Mount Test')),
                  ),
                ],
                selected: {settings.tiltMode},
                onSelectionChanged: (sel) async {
                  await settings.updateTiltMode(sel.first);
                  if (sel.first == 'mounted') {
                    tilt.calibrate();
                  }
                },
                showSelectedIcon: false,
              ),
              if (settings.tiltMode == 'mounted') ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    tilt.calibrate();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(str.tr(
                          '已將目前擺放角度（打直望 mon 或平放皆可）鎖定為 0° 基準！',
                          '已将当前摆放角度锁定为 0° 基准！',
                          'Locked current phone mount angle as 0° baseline!',
                        )),
                      ),
                    );
                  },
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(str.tr(
                    '將目前支架角度（打直或平放）設為 0° 基準',
                    '将当前支架角度（竖放或平放）设为 0° 基准',
                    'Set Current Mount Angle as 0° Baseline',
                  )),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Font Scale, Theme & Voice Readout
        SectionCard(
          title: str.tr(
              '字體大小、主題與朗讀語速', '字体大小、主题与朗读语速', 'Font Size, Theme & Speech Speed'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_size_rounded),
                  const SizedBox(width: 8),
                  Text(
                    '${str.tr('字體縮放比例', '字体缩放比例', 'Font Scale')}：${(settings.fontScale * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Slider(
                value: settings.fontScale,
                min: 0.85,
                max: 1.50,
                divisions: 13,
                label: '${(settings.fontScale * 100).round()}%',
                onChanged: (v) => settings.updateFontScale(v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(str.tr('暖白高對比日間護眼主題', '暖白高对比日间主题',
                    'High-Contrast Daylight Theme')),
                value: settings.lightMode,
                onChanged: (v) => settings.updateLightMode(v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(str.tr(
                    '自動語音朗讀助手回覆', '自动语音朗读助手回复', 'Auto-Speak AI Replies')),
                value: settings.ttsAutoRead,
                onChanged: (v) => settings.updateTtsAutoRead(v),
              ),
              Row(
                children: [
                  Text(str.tr('語速：', '语速：', 'Rate: ')),
                  Expanded(
                    child: Slider(
                      value: settings.ttsRate,
                      min: 0.32,
                      max: 0.65,
                      divisions: 11,
                      onChanged: (v) => settings.updateTtsRate(v),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => tts.speak(
                      str.tr(
                        '你好，我係${settings.assistantName}，呢個係廣東話朗讀測試。',
                        '你好，我是${settings.assistantName}，这是普通话朗读测试。',
                        'Hello, I am ${settings.assistantName}. This is a voice test.',
                      ),
                      force: true,
                    ),
                    child: Text(str.tr('試聽', '试听', 'Test')),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. DeepSeek-Flash AI Configuration Card
        SectionCard(
          title: 'DeepSeek AI 設定（預設 deepseek-flash）',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: aiEndpoint,
                decoration: const InputDecoration(labelText: 'AI Endpoint'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: aiModel,
                decoration:
                    const InputDecoration(labelText: 'AI Model (deepseek-flash)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: aiKey,
                obscureText: !_showAiKey,
                decoration: InputDecoration(
                  labelText: 'DeepSeek API Key',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showAiKey ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showAiKey = !_showAiKey),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _testingAi ? null : _testDeepSeekAi,
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(_testingAi
                        ? str.tr('測試連線中…', '测试连线中…', 'Testing...')
                        : str.tr('一鍵測試 DeepSeek-Flash', '一键测试 DeepSeek-Flash', 'Test DeepSeek-Flash')),
                  ),
                  TextButton(
                    onPressed: () {
                      aiEndpoint.text = SettingsStore.defaultDeepSeekEndpoint;
                      aiModel.text = SettingsStore.defaultDeepSeekModel;
                      aiKey.text = SettingsStore.defaultDeepSeekKey;
                      _saveAllFields();
                    },
                    child: Text(str.tr('還原預設 Key', '还原默认 Key', 'Restore Default Key')),
                  ),
                ],
              ),
              if (_aiTestResult != null) ...[
                const SizedBox(height: 8),
                Text(
                  _aiTestResult!,
                  style: TextStyle(
                    color: _aiTestResult!.contains('失敗') ? p.danger : p.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Caregiver Emergency Contact
        SectionCard(
          title: str.tr(
              '照顧者與緊急求助（SOS）設定', '照顾者与紧急求助（SOS）设置', 'Caregiver & SOS Contact'),
          child: Column(
            children: [
              TextField(
                controller: caregiverName,
                decoration: InputDecoration(
                  labelText:
                      str.tr('照顧者／親戚稱呼', '照顾者／亲属称呼', 'Caregiver Name'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: caregiverPhone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: str.tr('緊急聯絡電話', '紧急联系电话', 'Emergency Phone'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 6. Optional Wheelchair / Model Car Developer Mode
        SectionCard(
          title: str.tr('外接輪椅模組與工程測試模式', '外接轮椅模块与工程测试模式',
              'Wheelchair Hardware & Dev Mode'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  str.tr('啟用「工程測試模式」', '启用“工程测试模式”', 'Enable Developer Mode'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                value: settings.developerMode,
                onChanged: (v) => settings.updateDeveloperMode(v),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(str.tr('外接車載 VLN、雷達與藍牙連線參數', '外接车载 VLN、雷达与蓝牙参数', 'VLN, LiDAR & BLE Endpoints')),
                children: [
                  const SizedBox(height: 8),
                  TextField(
                    controller: server,
                    decoration: const InputDecoration(labelText: 'VLN Server URL'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: apiKey,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'VLN X-API-Key'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _testingVln ? null : _testVlnServer,
                        icon: const Icon(Icons.wifi_tethering),
                        label: Text(_testingVln ? 'Testing...' : 'Test /healthz'),
                      ),
                      const SizedBox(width: 10),
                      if (_vlnTestResult != null)
                        Expanded(
                          child: Text(
                            _vlnTestResult!,
                            style: TextStyle(color: p.muted, fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: wsUrl,
                    decoration: const InputDecoration(labelText: 'LiDAR WebSocket URL'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cameraWsUrl,
                    decoration: const InputDecoration(labelText: 'Camera WebSocket URL'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bleName,
                    decoration: const InputDecoration(labelText: 'BLE Device Name (BT04)'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saveAllFields,
                icon: const Icon(Icons.save_rounded),
                label: Text(str.tr('儲存所有設定', '保存所有设置', 'Save All Settings')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            str.tr('用戶、語言與助手設定', '用户、语言与助手设置', 'User & Assistant Settings')),
        actions: [
          TextButton.icon(
            onPressed: _saveAllFields,
            icon: const Icon(Icons.check_rounded),
            label: Text(str.tr('儲存', '保存', 'Save')),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: Responsive.pagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: content,
          ),
        ),
      ),
    );
  }
}
