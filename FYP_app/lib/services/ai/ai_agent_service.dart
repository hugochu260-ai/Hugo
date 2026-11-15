import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/car_command.dart';
import '../../models/chat_models.dart';
import '../ble_car_service.dart';
import '../drive/auto_drive_controller.dart';
import '../location_service.dart';
import '../medication/medication_service.dart';
import '../radar/radar_service.dart';
import '../settings_store.dart';
import '../tilt/tilt_monitor_service.dart';
import 'transport_tools.dart';

class _ToolResult {
  const _ToolResult(this.message);
  final String message;
}

class PendingStepMove {
  const PendingStepMove({required this.command, required this.durationMs});
  final CarCommand command;
  final int durationMs;
}

/// Smart Companion AI Service powered by DeepSeek-Flash (`deepseek-flash`):
/// - Automatically syncs welcome greeting & persona whenever `assistantName`
///   or `appLanguage` changes in Settings!
/// - Understands ultra-short / elliptical speech ("我去廚房", "我廚房", "廁所", "口渴").
/// - Supports AI Pill-Bag Photo -> Automatic Medication Reminder extraction!
class AiAgentService extends ChangeNotifier {
  AiAgentService({
    required this.settings,
    required this.ble,
    required this.radar,
    required this.autoDrive,
    required this.location,
    required this.medication,
    required this.tilt,
  }) {
    _lastSyncedName = settings.assistantName;
    _lastSyncedLang = settings.appLanguage;
    messages.add(ChatMessage(
      role: ChatRole.agent,
      text: _welcomeText(),
    ));
    settings.addListener(_onSettingsUpdated);
  }

  final SettingsStore settings;
  final BleCarService ble;
  final RadarService radar;
  final AutoDriveController autoDrive;
  final LocationService location;
  final MedicationService medication;
  final TiltMonitorService tilt;
  final TransportTools transport = TransportTools();

  final List<ChatMessage> messages = [];
  final List<Map<String, String>> _history = [];
  bool busy = false;
  String? error;
  bool sosActive = false;
  String _lastSyncedName = '';
  String _lastSyncedLang = '';

  PendingStepMove? pendingStepMove;
  String? pendingCaregiverCall;

  VoidCallback? onSosTriggered;
  Future<void> Function(String loudSpeech)? onCaregiverBroadcast;

  /// Dynamically updates the welcome bubble whenever the user renames the
  /// assistant (e.g. "阿智" -> "小寶") or switches UI language!
  void _onSettingsUpdated() {
    if (_lastSyncedName != settings.assistantName ||
        _lastSyncedLang != settings.appLanguage) {
      _lastSyncedName = settings.assistantName;
      _lastSyncedLang = settings.appLanguage;
      if (messages.isNotEmpty && !messages.first.isUser) {
        messages[0] = ChatMessage(role: ChatRole.agent, text: _welcomeText());
      }
      notifyListeners();
    }
  }

  String _welcomeText() {
    final name = settings.assistantName;
    return settings.strings.tr(
      '你好！我係「$name」（你嘅 AI 智行友伴）。無論有冇連住輪椅，你都可以直接同我講「我去廚房」、「我口渴」、「附近巴士」、「去瑪麗醫院搭咩車」，或者拍藥袋等我自動幫你校鬧鐘食藥！',
      '你好！我是“$name”（你的 AI 智行友伴）。无论是否连接轮椅，你都可以直接对我说“我去厨房”、“我口渴”、“附近公交”、“去玛丽医院坐什么车”，或拍药袋让我自动帮你设吃药闹钟！',
      'Hi! I am "$name", your AI Smart Companion. With or without a wheelchair, just tell me "go to kitchen", "I am thirsty", "nearby bus", "route to Queen Mary Hospital", or snap a medicine bag to auto-set reminders!',
    );
  }

  bool get isHardwareLinked => ble.isConnected || autoDrive.controlConnected;

  bool get hasPendingConfirmation =>
      autoDrive.pendingInstruction != null ||
      pendingStepMove != null ||
      pendingCaregiverCall != null;

  String? get pendingConfirmationDescription {
    final tr = settings.strings.tr;
    if (autoDrive.pendingInstruction != null) {
      return tr(
        '自動導航前往：「${autoDrive.pendingInstruction}」',
        '自动导航前往：“${autoDrive.pendingInstruction}”',
        'Navigate to: "${autoDrive.pendingInstruction}"',
      );
    }
    if (pendingStepMove != null) {
      return tr(
        '執行輪椅移動：「${pendingStepMove!.command.label}」',
        '执行轮椅移动：“${pendingStepMove!.command.label}”',
        'Move wheelchair: "${pendingStepMove!.command.label}"',
      );
    }
    if (pendingCaregiverCall != null) {
      return tr(
        '大聲呼叫照顧者協助：「$pendingCaregiverCall」',
        '大声呼叫照顾者协助：“$pendingCaregiverCall”',
        'Call caregiver aloud: "$pendingCaregiverCall"',
      );
    }
    return null;
  }

  String? get lastReply {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].isUser) return messages[i].text;
    }
    return null;
  }

  Future<String> confirmPendingAction() async {
    final tr = settings.strings.tr;
    if (autoDrive.pendingInstruction != null) {
      final dest = autoDrive.pendingInstruction!;
      final ok = await autoDrive.confirmAndStart();
      final msg = ok
          ? tr(
              '好，已確認！開始自動導航前往「$dest」，遇到障礙物或斜坡會自動減速及煞停。',
              '好，已确认！开始自动导航前往“$dest”，遇到障碍物或斜坡会自动减速及刹停。',
              'Confirmed! Navigating to "$dest" with automatic obstacle & slope protection.',
            )
          : tr(
              '目前未連上輪椅導航通道（${autoDrive.error ?? autoDrive.statusMessage}）。需要我改為大聲呼叫${settings.caregiverName}扶你去「$dest」嗎？',
              '目前未连上轮椅导航通道（${autoDrive.error ?? autoDrive.statusMessage}）。需要我改为大声呼叫${settings.caregiverName}扶你去“$dest”吗？',
              'Wheelchair link is offline. Would you like me to call ${settings.caregiverName} aloud instead?',
            );
      if (!ok) {
        pendingCaregiverCall = '${settings.caregiverName}唔該幫手！用家想去$dest呀！';
      }
      messages.add(ChatMessage(role: ChatRole.agent, text: msg, isError: !ok));
      notifyListeners();
      return msg;
    }

    if (pendingStepMove != null) {
      final move = pendingStepMove!;
      pendingStepMove = null;
      final blockErr = await ble.guardedPulse(
        move.command,
        baseDuration: Duration(milliseconds: move.durationMs),
        frontM: radar.isLive ? radar.frontM : null,
        rearM: radar.isLive ? radar.rearM : null,
        safetyStopM: settings.safetyStopM,
        speedFactor: settings.slopeSlowdown ? tilt.recommendedSpeedFactor : 1.0,
      );
      final msg = blockErr ??
          tr(
            '已確認並執行「${move.command.label}」。',
            '已确认并执行“${move.command.label}”。',
            'Confirmed and executed "${move.command.label}".',
          );
      messages.add(ChatMessage(
        role: ChatRole.agent,
        text: msg,
        isError: blockErr != null,
      ));
      notifyListeners();
      return msg;
    }

    if (pendingCaregiverCall != null) {
      final callMsg = pendingCaregiverCall!;
      pendingCaregiverCall = null;
      await onCaregiverBroadcast?.call(callMsg);
      final msg = tr(
        '已經幫你大聲廣播呼叫照顧者：「$callMsg」',
        '已经帮你大声广播呼叫照顾者：“$callMsg”',
        'Broadcasted caregiver call: "$callMsg"',
      );
      messages.add(ChatMessage(role: ChatRole.agent, text: msg));
      notifyListeners();
      return msg;
    }

    return tr('目前冇待確認嘅指令。', '目前没有待确认的指令。', 'No pending action to confirm.');
  }

  String cancelPendingAction() {
    autoDrive.cancelConfirmation();
    pendingStepMove = null;
    pendingCaregiverCall = null;
    final msg = settings.strings.tr(
      '好，已經取消指令。有需要隨時再叫「${settings.assistantName}」！',
      '好，已经取消指令。有需要随时再喊“${settings.assistantName}”！',
      'Cancelled! Call "${settings.assistantName}" anytime you need help.',
    );
    messages.add(ChatMessage(role: ChatRole.agent, text: msg));
    notifyListeners();
    return msg;
  }

  Future<void> send(String text) async {
    final input = text.trim();
    if (input.isEmpty || busy) return;

    final prev = lastReply;
    if (prev != null && input.length >= 6 && prev.contains(input)) {
      return;
    }

    busy = true;
    error = null;
    messages.add(ChatMessage(role: ChatRole.user, text: input));
    notifyListeners();

    try {
      if (_isImmediateStopIntent(input)) {
        await autoDrive.emergencyStopAll(reason: '語音緊急停止');
        pendingStepMove = null;
        pendingCaregiverCall = null;
        final reply = settings.strings.tr(
          '已經即刻停止所有移動！',
          '已经立即停止所有移动！',
          'Stopped all movement immediately!',
        );
        _recordExchange(input, reply);
        messages.add(ChatMessage(role: ChatRole.agent, text: reply));
        return;
      }

      if (hasPendingConfirmation) {
        if (_isConfirmYes(input)) {
          final reply = await confirmPendingAction();
          _recordExchange(input, reply);
          return;
        }
        if (_isConfirmNo(input)) {
          final reply = cancelPendingAction();
          _recordExchange(input, reply);
          return;
        }
      }

      String reply;
      if (settings.aiKey.trim().isEmpty) {
        reply = await _smartLocalNlu(input);
      } else {
        try {
          reply = await _runDeepSeekAgent(input);
        } catch (apiErr) {
          error = '$apiErr';
          reply = await _smartLocalNlu(input);
        }
      }

      if (reply.trim() == input) {
        reply = await _smartLocalNlu(input);
      }

      _recordExchange(input, reply);
      messages.add(ChatMessage(role: ChatRole.agent, text: reply));
    } catch (e) {
      error = '$e';
      messages.add(ChatMessage(
        role: ChatRole.agent,
        text: settings.strings.tr(
          '唔好意思，連線暫時有少少問題（$e），你可以再講一次或者直接撳大字掣。',
          '不好意思，网络暂时有点问题（$e），你可以再说一次或直接按大字按钮。',
          'Sorry, connection issue ($e). Please try again or tap a quick card.',
        ),
        isError: true,
      ));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _recordExchange(String userText, String assistantText) {
    _history.add({'role': 'user', 'content': userText});
    _history.add({'role': 'assistant', 'content': assistantText});
    if (_history.length > 16) {
      _history.removeRange(0, _history.length - 16);
    }
  }

  /// Snap Pill Bag -> Automatically parse medicine name, dosage & times and add
  /// directly into `MedicationService`!
  Future<String> extractMedicationFromPhoto(Uint8List jpegBytes) async {
    busy = true;
    error = null;
    final s = settings.strings;
    messages.add(ChatMessage(
      role: ChatRole.user,
      text: s.tr('📷 拍藥袋自動設食藥提醒', '📷 拍药袋自动设吃药提醒', '📷 Snap pill bag to auto-set reminder'),
    ));
    notifyListeners();

    try {
      final b64 = base64Encode(jpegBytes);
      final uri = Uri.parse(settings.normalizedAiEndpoint);
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer ${settings.aiKey.trim()}',
            },
            body: jsonEncode({
              'model': settings.aiModel.trim().isEmpty
                  ? SettingsStore.defaultDeepSeekModel
                  : settings.aiModel.trim(),
              'messages': [
                {
                  'role': 'system',
                  'content':
                      '你是藥袋識別助手。請讀取圖片中嘅藥物名稱、服法及建議時間，只輸出一個 JSON object：'
                      '{"found":true,"title":"藥名","note":"每次幾粒及飯前飯後","hours":[9,21],"spoken":"用親切口語向長者解釋藥名同埋已經幫佢設定好幾點鐘提醒"}。'
                      '如果圖片唔係藥袋或睇唔清，輸出 {"found":false,"spoken":"親切提示再影清楚少少"}。${_languageInstruction()}',
                },
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': '請識別藥袋並提取時間設定提醒'},
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'data:image/jpeg;base64,$b64'},
                    },
                  ],
                },
              ],
              'temperature': 0.1,
              'max_tokens': 500,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 35));

      final bodyStr = utf8.decode(res.bodyBytes);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('HTTP ${res.statusCode}');
      }
      final data = jsonDecode(bodyStr) as Map<String, dynamic>;
      final raw = (((data['choices'] as List?)?.firstOrNull as Map?)?['message']
                  ?['content'] as String? ??
              '')
          .trim();

      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final parsed =
            jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
        final found = parsed['found'] == true;
        final spoken = (parsed['spoken'] as String?)?.trim() ?? '';
        if (found) {
          final title = (parsed['title'] as String?)?.trim() ?? '藥物提醒';
          final note = (parsed['note'] as String?)?.trim() ?? '請準時服用';
          final hours = ((parsed['hours'] as List?) ?? const [9])
              .map((e) => (e as num).toInt().clamp(0, 23))
              .toList();
          for (final h in hours) {
            await medication.addOrUpdate(MedicationReminder(
              id: 'med_${DateTime.now().millisecondsSinceEpoch}_$h',
              title: title,
              note: note,
              hour: h,
              minute: 0,
              enabled: true,
            ));
          }
          final reply = spoken.isNotEmpty
              ? spoken
              : s.tr(
                  '已識別「$title」（$note），並自動幫你加好每日提醒鬧鐘！',
                  '已识别“$title”（$note），并自动帮你设好每日提醒闹钟！',
                  'Added daily reminder(s) for "$title" ($note)!',
                );
          messages.add(ChatMessage(role: ChatRole.agent, text: reply));
          return reply;
        } else if (spoken.isNotEmpty) {
          messages.add(ChatMessage(role: ChatRole.agent, text: spoken));
          return spoken;
        }
      }
      return await analyzeImageWithVision(jpegBytes);
    } catch (_) {
      return await analyzeImageWithVision(jpegBytes);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String> analyzeImageWithVision(
    Uint8List jpegBytes, {
    String? userPrompt,
  }) async {
    busy = true;
    error = null;
    final ask = (userPrompt == null || userPrompt.trim().isEmpty)
        ? settings.strings.tr(
            '請幫我睇下呢張相入面係咩（藥袋、覆診紙或面前環境），清楚讀出重點。',
            '请帮我看一下这张照片里是什么（药袋、复诊单或前方环境），清楚读出重点。',
            'Please read and explain what is in this photo clearly.',
          )
        : userPrompt.trim();
    messages.add(ChatMessage(role: ChatRole.user, text: '📷 $ask'));
    notifyListeners();

    try {
      if (settings.aiKey.trim().isEmpty) {
        throw StateError('Missing DeepSeek API Key');
      }
      final b64 = base64Encode(jpegBytes);
      final uri = Uri.parse(settings.normalizedAiEndpoint);
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer ${settings.aiKey.trim()}',
            },
            body: jsonEncode({
              'model': settings.aiModel.trim().isEmpty
                  ? SettingsStore.defaultDeepSeekModel
                  : settings.aiModel.trim(),
              'messages': [
                {
                  'role': 'system',
                  'content':
                      '你是「${settings.assistantName}」無障礙視覺輔助助手。${_languageInstruction()} 請用簡潔溫暖口語直接講出圖片重點，唔好用 Markdown 符號。',
                },
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': ask},
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'data:image/jpeg;base64,$b64'},
                    },
                  ],
                },
              ],
              'temperature': 0.2,
              'max_tokens': 500,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 35));

      final bodyStr = utf8.decode(res.bodyBytes);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('HTTP ${res.statusCode}: $bodyStr');
      }
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      final content = (choices != null && choices.isNotEmpty)
          ? ((choices.first as Map)['message']?['content'] as String? ?? '')
              .trim()
          : '';
      final finalReply = content.isNotEmpty
          ? content
          : settings.strings.tr(
              '未能辨識清楚上面嘅字，唔該靠近少少再影一次。',
              '没能看清上面的字，请靠近一点再拍一次。',
              'Text was blurry. Please move closer and try again.',
            );
      messages.add(ChatMessage(role: ChatRole.agent, text: finalReply));
      return finalReply;
    } catch (e) {
      final errReply = settings.strings.tr(
        '相片識別暫時未能完成（$e）。',
        '照片识别暂时未能完成（$e）。',
        'Photo analysis could not complete ($e).',
      );
      messages.add(ChatMessage(role: ChatRole.agent, text: errReply, isError: true));
      return errReply;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String> testAiConnection() async {
    final uri = Uri.parse(settings.normalizedAiEndpoint);
    final model = settings.aiModel.trim().isEmpty
        ? SettingsStore.defaultDeepSeekModel
        : settings.aiModel.trim();
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer ${settings.aiKey.trim()}',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': '請用一句話講：我是${settings.assistantName}，連線成功！'},
            ],
            'max_tokens': 60,
            'temperature': 0.1,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final bodyStr = utf8.decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('HTTP ${res.statusCode}: $bodyStr');
    }
    final data = jsonDecode(bodyStr) as Map<String, dynamic>;
    final msg = ((data['choices'] as List?)?.firstOrNull as Map?)?['message']
            ?['content'] ??
        'OK';
    return '連線成功 ($model)：$msg';
  }

  bool _isImmediateStopIntent(String s) {
    final clean = s.replaceAll(' ', '');
    return clean == '停' ||
        clean == '停車' ||
        clean == '停止' ||
        clean == '緊急停止' ||
        clean == '即刻停' ||
        clean == '停低' ||
        clean.toLowerCase() == 'stop';
  }

  bool _isConfirmYes(String s) {
    final c = s.replaceAll(RegExp(r'[，,。！!？?\s]'), '').toLowerCase();
    return const {
      '確認', '確認出發', '確定', '确认', '出發', '出发',
      '好', '好呀', '好啊', '係', '係呀', '是', '可以',
      '行啦', '去啦', '叫啦', '幫我叫', 'ok', 'okay', 'yes', 'confirm', 'go',
    }.contains(c);
  }

  bool _isConfirmNo(String s) {
    final c = s.replaceAll(RegExp(r'[，,。！!？?\s]'), '').toLowerCase();
    return c.contains('取消') ||
        c.contains('唔好') ||
        c.contains('唔係') ||
        c.contains('唔使') ||
        c.contains('不要') ||
        c.contains('不用') ||
        c == 'no' ||
        c == 'cancel';
  }

  String _languageInstruction() {
    switch (settings.appLanguage) {
      case 'zh_CN':
        return '必須使用親切自然嘅【简体中文（普通话口语）】回答用家。';
      case 'en_US':
        return 'MUST reply in warm, concise, natural 【English】.';
      default:
        return '必須使用親切、地道、簡潔易明嘅【香港廣東話口語（繁體中文）】回答用家。';
    }
  }

  Future<String> _runDeepSeekAgent(String userInput) async {
    final systemPrompt = '''
你是「${settings.assistantName}」，專為長者、行動不便人士及漸凍症患者設計嘅全能 AI 貼身友伴（智行友伴 Smart Companion）。
${_languageInstruction()}

【理解簡短／省略主語嘅說話，絕對禁止照讀或重讀用家原話】
- 用家講「我去廚房」、「我廚房」、「廚房」、「廁所」、「客廳」、「睡房」 -> 呼叫 go_to_place(place="...")。
- 用家講「水」、「口渴」、「飲水」、「肚餓」、「凍」、「熱」、「幫我轉身」 -> 呼叫 call_caregiver(...) 幫佢大聲叫照顧者！
- 用家講「我左邊手痛」、「頭暈」、「唔舒服」 -> 絕對唔係左轉！請關懷並呼叫 call_caregiver 或 trigger_sos。
- 用家講「字太細」、「轉英文」、「講普通話」、「以後叫你小寶」 -> 呼叫 update_preference 修改設定！

只輸出一個合法 JSON object（不要加 ```json）：
{"action":"tool","name":"go_to_place","args":{"place":"廚房"}}
{"action":"tool","name":"request_step_move","args":{"command":"forward","duration_ms":450}}
{"action":"tool","name":"stop_movement","args":{}}
{"action":"tool","name":"call_caregiver","args":{"message":"${settings.caregiverName}唔該幫手！用家想飲溫水呀！","reply":"明白，我即刻幫你大聲叫${settings.caregiverName}斟水畀你！"}}
{"action":"tool","name":"get_nearby_bus","args":{}}
{"action":"tool","name":"plan_bus_route","args":{"origin":"","destination":"瑪麗醫院"}}
{"action":"tool","name":"get_bus_eta","args":{"route":"1A","operator":"九巴","direction":"","stop":""}}
{"action":"tool","name":"get_weather","args":{"place":"香港","date":"current"}}
{"action":"tool","name":"add_reminder","args":{"title":"血壓藥","hour":14,"minute":0,"note":"飯後1粒"}}
{"action":"tool","name":"update_preference","args":{"font_scale":1.3,"language":"zh_HK","assistant_name":"小寶"}}
{"action":"tool","name":"trigger_sos","args":{"reason":"用家需要緊急支援"}}
{"action":"answer","text":"親切自然嘅回覆（1-3句內）"}

目前狀態：${_statusText()}（助手現名：${settings.assistantName}；照顧者：${settings.caregiverName}）
''';

    final chatMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      for (final h
          in _history.skip(_history.length > 8 ? _history.length - 8 : 0))
        {'role': h['role'], 'content': h['content']},
      {'role': 'user', 'content': userInput},
    ];

    final rawContent = await _postDeepSeek(chatMessages, jsonMode: true);
    final action = _parseAction(rawContent);
    if (action == null) return rawContent;

    final type = action['action'];
    if (type == 'answer') {
      final text = (action['text'] as String?)?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    if (type == 'ask') {
      final q = (action['question'] as String?)?.trim();
      if (q != null && q.isNotEmpty) return q;
    }
    if (type == 'tool') {
      final name = action['name'] as String? ?? '';
      final args = (action['args'] as Map?)?.cast<String, dynamic>() ?? {};
      final result = await _runTool(name, args);
      return result.message;
    }
    return rawContent;
  }

  Future<String> _postDeepSeek(
    List<Map<String, dynamic>> chatMessages, {
    required bool jsonMode,
  }) async {
    final uri = Uri.parse(settings.normalizedAiEndpoint);
    final model = settings.aiModel.trim().isEmpty
        ? SettingsStore.defaultDeepSeekModel
        : settings.aiModel.trim();

    final payload = <String, dynamic>{
      'model': model,
      'messages': chatMessages,
      'temperature': 0.2,
      'max_tokens': 600,
      'stream': false,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    var res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer ${settings.aiKey.trim()}',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode == 400 && jsonMode) {
      payload.remove('response_format');
      res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer ${settings.aiKey.trim()}',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));
    }

    final bodyStr = utf8.decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('HTTP ${res.statusCode}');
    }
    final json = jsonDecode(bodyStr) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) throw StateError('Empty choices');
    final msgObj = (choices.first as Map)['message'] as Map?;
    final content = (msgObj?['content'] as String? ?? '').trim();
    if (content.isEmpty) throw StateError('Empty message');
    return content;
  }

  Map<String, dynamic>? _parseAction(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      text = text.replaceFirst(RegExp(r'```$'), '').trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final json = jsonDecode(text.substring(start, end + 1));
      if (json is Map<String, dynamic> && json['action'] is String) {
        return json;
      }
    } catch (_) {}
    return null;
  }

  Future<_ToolResult> _runTool(String name, Map<String, dynamic> args) async {
    final tr = settings.strings.tr;
    switch (name) {
      case 'go_to_place':
      case 'request_navigation':
        final dest =
            ((args['place'] ?? args['destination']) as String?)?.trim() ?? '';
        if (dest.isEmpty) {
          return _ToolResult(tr(
            '請問你想去邊個位置？（例如：廚房、客廳、睡房、洗手間）',
            '请问你想去哪个位置？（例如：厨房、客厅、卧室、洗手间）',
            'Where would you like to go? (e.g. Kitchen, Living Room, Washroom)',
          ));
        }
        if (isHardwareLinked) {
          pendingCaregiverCall = null;
          autoDrive.requestConfirmation(dest);
          return _ToolResult(tr(
            '明白，你想去「$dest」！請講「確認」或者撳綠色確認掣開始自動導航；講「取消」就唔會郁。',
            '明白，你想去“$dest”！请说“确认”或按绿色确认键开始自动导航；说“取消”则不会移动。',
            'Got it, heading to "$dest"! Say "Confirm" or tap the green button to start navigation.',
          ));
        } else {
          autoDrive.cancelConfirmation();
          pendingCaregiverCall =
              '${settings.caregiverName}唔該幫手！用家而家想去$dest呀！';
          notifyListeners();
          return _ToolResult(tr(
            '明白你想去「$dest」！目前係獨立輔助模式（未連輪椅），請講「確認」或撳綠色掣，我即刻大聲呼叫${settings.caregiverName}過來扶你去「$dest」！',
            '明白你想去“$dest”！当前为独立辅助模式（未连轮椅），请说“确认”或按绿色按钮，我立刻大声呼叫${settings.caregiverName}过来扶你去“$dest”！',
            'Got it, you want to go to "$dest"! Say "Confirm" or tap the green button and I will call ${settings.caregiverName} aloud to assist you!',
          ));
        }

      case 'call_caregiver':
        final loudMsg = (args['message'] as String?)?.trim() ??
            '${settings.caregiverName}唔該過來幫一幫手！';
        final replyMsg = (args['reply'] as String?)?.trim() ??
            tr(
              '已經即刻幫你大聲呼叫：「$loudMsg」',
              '已经立刻帮你大声呼叫：“$loudMsg”',
              'Calling caregiver aloud: "$loudMsg"',
            );
        await onCaregiverBroadcast?.call(loudMsg);
        return _ToolResult(replyMsg);

      case 'request_step_move':
        final cmd = CarCommand.fromApi(args['command'] as String?);
        if (cmd == null || !cmd.isMovement) {
          return _ToolResult(
              tr('未能識別移動方向。', '未能识别移动方向。', 'Direction not recognized.'));
        }
        final ms =
            ((args['duration_ms'] as num?)?.toInt() ?? 450).clamp(150, 1200);
        pendingStepMove = PendingStepMove(command: cmd, durationMs: ms);
        notifyListeners();
        return _ToolResult(tr(
          '準備執行「${cmd.label}」。請講「確認」或撳綠色確認掣開始。',
          '准备执行“${cmd.label}”。请说“确认”或按绿色确认键开始。',
          'Ready to "${cmd.label}". Say "Confirm" or tap the green button.',
        ));

      case 'stop_movement':
        await autoDrive.emergencyStopAll(reason: 'AI 語音停止');
        pendingStepMove = null;
        pendingCaregiverCall = null;
        return _ToolResult(
            tr('已立即停止所有移動。', '已立即停止所有移动。', 'Stopped all movement.'));

      case 'get_nearby_bus':
        final pos = location.current ?? await location.fetchCurrentLocation();
        if (pos == null) {
          return _ToolResult(tr(
            '暫時攞唔到 GPS 位置（${location.error ?? '請開啟定位權限'}）。你可以直接講想由邊度去邊度！',
            '暂时获取不到 GPS 位置。你可以直接说想从哪里去哪里！',
            'GPS unavailable. Tell me your origin and destination to plan a bus route!',
          ));
        }
        return _ToolResult(
          await transport.nearbyStopsEta(lat: pos.lat, lon: pos.lon),
        );

      case 'plan_bus_route':
        final orig = (args['origin'] as String?)?.trim();
        final dest = (args['destination'] as String?)?.trim() ?? '';
        GeoPoint? pos = location.current;
        if ((orig == null || orig.isEmpty) && pos == null) {
          pos = await location.fetchCurrentLocation();
        }
        return _ToolResult(
          await transport.planPointToPoint(
            originText: orig,
            destinationText: dest,
            userLat: pos?.lat,
            userLon: pos?.lon,
          ),
        );

      case 'get_bus_eta':
        final route = (args['route'] as String?)?.trim() ?? '';
        if (route.isEmpty) {
          return _ToolResult(tr(
            '請話我知巴士號碼或目的地。',
            '请告诉我公交号码或目的地。',
            'Please tell me the bus route number or destination.',
          ));
        }
        final pos = location.current;
        return _ToolResult(await transport.busEta(
          route: route,
          operator: (args['operator'] as String?)?.trim(),
          direction: (args['direction'] as String?)?.trim(),
          stop: (args['stop'] as String?)?.trim(),
          userLat: pos?.lat,
          userLon: pos?.lon,
        ));

      case 'get_weather':
        final date = (args['date'] as String?)?.trim();
        final place = (args['place'] as String?)?.trim();
        return _ToolResult(await transport.weather(date: date, place: place));

      case 'add_reminder':
        final title = (args['title'] as String?)?.trim() ?? '按時食藥';
        final hour = ((args['hour'] as num?)?.toInt() ?? 9).clamp(0, 23);
        final minute = ((args['minute'] as num?)?.toInt() ?? 0).clamp(0, 59);
        final note = (args['note'] as String?)?.trim() ?? '請準時服用';
        final item = MedicationReminder(
          id: 'med_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          note: note,
          hour: hour,
          minute: minute,
          enabled: true,
        );
        await medication.addOrUpdate(item);
        return _ToolResult(tr(
          '已經幫你設定好每日 ${item.timeLabel} 提醒：「$title」（$note）。',
          '已经帮你设好每天 ${item.timeLabel} 提醒：“$title”（$note）。',
          'Daily reminder set for ${item.timeLabel}: "$title" ($note).',
        ));

      case 'update_preference':
        final changes = <String>[];
        if (args['font_scale'] is num) {
          final fs = (args['font_scale'] as num).toDouble().clamp(0.85, 1.50);
          await settings.updateFontScale(fs);
          changes.add('${(fs * 100).round()}%');
        }
        if (args['language'] is String) {
          final lang = (args['language'] as String).trim();
          await settings.updateAppLanguage(lang);
          changes.add(lang);
        }
        if (args['assistant_name'] is String) {
          final newName = (args['assistant_name'] as String).trim();
          if (newName.isNotEmpty) {
            await settings.updateAssistantName(newName);
            changes.add('「$newName」');
          }
        }
        if (args['light_mode'] is bool) {
          await settings.updateLightMode(args['light_mode'] as bool);
        }
        return _ToolResult(tr(
          '好呀！已經幫你更新設定：${changes.join('、')}。',
          '好呀！已经帮你更新设置：${changes.join('、')}。',
          'Updated settings: ${changes.join(', ')}.',
        ));

      case 'trigger_sos':
        sosActive = true;
        await autoDrive.emergencyStopAll(reason: 'SOS 緊急求助');
        onSosTriggered?.call();
        notifyListeners();
        return _ToolResult(tr(
          '已啟動緊急求救警報並彈出求助面板！',
          '已启动紧急求救警报并弹出求助面板！',
          'Emergency SOS activated!',
        ));

      default:
        return _ToolResult(_statusText());
    }
  }

  Future<String> _smartLocalNlu(String input) async {
    final s = input.trim();
    final low = s.toLowerCase();

    if (s.contains('救命') ||
        s.contains('求救') ||
        low.contains('sos') ||
        s.contains('跌親') ||
        s.contains('跌倒') ||
        s.contains('好痛') ||
        s.contains('頭暈')) {
      return (await _runTool('trigger_sos', {'reason': s})).message;
    }

    final renameMatch = RegExp(
      r'(?:改名叫|叫做|以後叫你|以后叫你|call you\s+)([^\s，,。！!？?]{1,8})',
      caseSensitive: false,
    ).firstMatch(s);
    if (renameMatch != null) {
      return (await _runTool('update_preference', {
        'assistant_name': renameMatch.group(1)!.trim(),
      }))
          .message;
    }

    if (s.contains('字太細') ||
        s.contains('放大字') ||
        s.contains('大字啲') ||
        s.contains('字太小') ||
        low.contains('bigger font')) {
      final next = (settings.fontScale + 0.15).clamp(0.85, 1.50);
      return (await _runTool('update_preference', {'font_scale': next})).message;
    }
    if (s.contains('講英文') || low.contains('english')) {
      return (await _runTool('update_preference', {'language': 'en_US'})).message;
    }
    if (s.contains('普通話') || s.contains('普通话') || low.contains('mandarin')) {
      return (await _runTool('update_preference', {'language': 'zh_CN'})).message;
    }
    if (s.contains('廣東話') || s.contains('粵語') || low.contains('cantonese')) {
      return (await _runTool('update_preference', {'language': 'zh_HK'})).message;
    }

    if (s.contains('飲水') ||
        s.contains('喝水') ||
        s.contains('口渴') ||
        s == '水' ||
        low.contains('thirsty') ||
        low == 'water') {
      return (await _runTool('call_caregiver', {
        'message': '${settings.caregiverName}唔該幫手，用家想飲少少溫水呀！',
      }))
          .message;
    }
    if (s.contains('肚餓') ||
        s.contains('肚子餓') ||
        s.contains('食飯') ||
        s.contains('吃飯') ||
        low.contains('hungry')) {
      return (await _runTool('call_caregiver', {
        'message': '${settings.caregiverName}唔該幫手，用家有啲肚餓想食嘢！',
      }))
          .message;
    }
    if (s.contains('唔舒服') || s.contains('不舒服') || low.contains('unwell')) {
      return (await _runTool('call_caregiver', {
        'message': '${settings.caregiverName}唔該快啲過來睇下，用家覺得有啲唔舒服！',
      }))
          .message;
    }

    const indoorRooms = <String, String>{
      '廚房': '廚房', '厨房': '廚房', 'kitchen': 'Kitchen',
      '洗手間': '洗手間', '洗手间': '洗手間', '廁所': '洗手間', '厕所': '洗手間',
      'toilet': 'Washroom', 'washroom': 'Washroom', 'bathroom': 'Washroom',
      '客廳': '客廳', '客厅': '客廳', '大廳': '客廳', 'living room': 'Living Room',
      '飯廳': '飯廳', '餐廳': '飯廳',
      '睡房': '睡房', '卧室': '睡房', '房': '睡房', 'bedroom': 'Bedroom',
      '門口': '大門口', '大門': '大門口',
    };
    for (final entry in indoorRooms.entries) {
      if (low.contains(entry.key)) {
        return (await _runTool('go_to_place', {'place': entry.value})).message;
      }
    }

    if (s.contains('醫院') || s.contains('医院') || low.contains('hospital')) {
      final cleaned = s
          .replaceAll(RegExp(r'^(我想去|我要去|點去|去|帶我去|搭咩車去)'), '')
          .replaceAll(RegExp(r'(搭咩車|點去|路線)$'), '')
          .trim();
      return (await _runTool('plan_bus_route', {
        'destination': cleaned.isEmpty ? s : cleaned,
      }))
          .message;
    }

    if (s.contains('食藥') ||
        s.contains('喂藥') ||
        s.contains('吃藥') ||
        s.contains('吃药') ||
        s.contains('提醒') ||
        low.contains('medicine') ||
        low.contains('medication')) {
      return medication.summaryForSpeech(settings.appLanguage);
    }

    if (s.contains('附近巴士') ||
        s.contains('最近巴士') ||
        s.contains('附近車站') ||
        s.contains('附近公交') ||
        low.contains('nearby bus')) {
      return (await _runTool('get_nearby_bus', {})).message;
    }

    final generalGo = RegExp(
            r'(?:我?想去|我?要去|帶我去|带我去|前往|自動導航去|我去|去)([^，,。？?\s]{2,14})')
        .firstMatch(s);
    if (generalGo != null && !s.contains('天氣') && !s.contains('巴士')) {
      return (await _runTool('go_to_place', {'place': generalGo.group(1)!.trim()}))
          .message;
    }

    if (s.contains('天氣') || s.contains('天气') || low.contains('weather')) {
      try {
        return await transport.weather(place: input);
      } catch (e) {
        return 'Weather error: $e';
      }
    }

    return settings.strings.tr(
      '${settings.assistantName}喺度！你可以講「我去廚房」、「我想飲水」、「附近巴士」或者拍藥袋等我幫你睇！',
      '${settings.assistantName}在呢！你可以说“我去厨房”、“我想喝水”、“附近公交”或拍药袋让我帮你看！',
      '${settings.assistantName} is here! Try saying "go to kitchen", "I want water", "nearby bus", or snap a medicine bag!',
    );
  }

  String _statusText() {
    final bleText = ble.isConnected ? '底盤藍牙已連接' : '獨立手機輔助模式（未連輪椅）';
    final navText = autoDrive.controlConnected
        ? (autoDrive.running ? '自動導航運行中' : '車載導航待機')
        : '車載導航未連線';
    final radarText = radar.isLive
        ? '雷達正常（前 ${_fmt(radar.frontM)} m）'
        : '雷達未連接';
    final tiltText = tilt.isEmergency
        ? '姿態警報'
        : tilt.isOnSlope
            ? '處於斜坡慢行保護'
            : (tilt.isMountedProtectionActive ? '車載支架監測中' : '手持日常防跌模式');
    return '$bleText；$navText；$radarText；$tiltText';
  }

  String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  @override
  void dispose() {
    settings.removeListener(_onSettingsUpdated);
    super.dispose();
  }
}
