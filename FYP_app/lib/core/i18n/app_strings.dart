/// Multi-language localization dictionary for Smart Companion ("智行友伴").
/// Supports:
/// - 'zh_HK': 繁體中文（廣東話）
/// - 'zh_CN': 简体中文（普通话）
/// - 'en_US': English
class AppStrings {
  const AppStrings(this.lang);

  final String lang;

  bool get isCantonese => lang == 'zh_HK';
  bool get isMandarin => lang == 'zh_CN';
  bool get isEnglish => lang == 'en_US';

  String get ttsLocale {
    switch (lang) {
      case 'zh_CN':
        return 'zh-CN';
      case 'en_US':
        return 'en-US';
      default:
        return 'zh-HK';
    }
  }

  String get sttLocale {
    switch (lang) {
      case 'zh_CN':
        return 'zh_CN';
      case 'en_US':
        return 'en_US';
      default:
        return 'zh_HK';
    }
  }

  String get languageShortLabel {
    switch (lang) {
      case 'zh_CN':
        return '普通话';
      case 'en_US':
        return 'EN';
      default:
        return '粵語';
    }
  }

  String tr(String hk, String cn, String en) {
    switch (lang) {
      case 'zh_CN':
        return cn;
      case 'en_US':
        return en;
      default:
        return hk;
    }
  }

  String get appTitle => tr('智行友伴', '智行友伴', 'Smart Companion');
  String get navHome => tr('首頁', '首页', 'Home');
  String get navEyeAac => tr('溝通', '沟通', 'Talk');
  String get navBusMobility => tr('出行', '出行', 'Go');
  String get navAiAssistant => tr('AI 助手', 'AI 助手', 'AI Helper');
  String get navDevLab => tr('工程測試', '工程测试', 'Dev Lab');

  String get settingsTooltip => tr('用戶與語言設定', '用户与语言设置', 'User & Language Settings');
  String get readAloudTooltip => tr('語音朗讀本頁', '语音朗读本页', 'Read Screen Aloud');
  String get stopReadTooltip => tr('停止朗讀', '停止朗读', 'Stop Reading');
  String get voiceBtnLabel => tr('呼叫語音助手', '呼叫语音助手', 'Voice Assistant');
  String get sosBtnLabel => tr('緊急求助 SOS', '紧急求助 SOS', 'Emergency SOS');
  String get sosPillLabel => tr('緊急 SOS', '紧急 SOS', 'SOS');
  String get visionBtnLabel => tr('AI 拍藥袋／睇環境', 'AI 拍药袋／看环境', 'AI Vision Helper');

  String wakeBadge(String name, bool listening, bool enabled) {
    if (!enabled) {
      return tr('語音喚醒已關閉', '语音唤醒已关闭', 'Wake Word Off');
    }
    if (listening) {
      return tr(
        '待命中：叫「$name」即應',
        '待命中：喊“$name”即应',
        'Ready: Say "$name"',
      );
    }
    return tr(
      '助手名稱：「$name」',
      '助手名称：“$name”',
      'Assistant: "$name"',
    );
  }

  String homeGreeting(String assistantName) => tr(
        '你好！需要「$assistantName」幫手嗎？',
        '你好！需要“$assistantName”帮忙吗？',
        'Hello! How can "$assistantName" help today?',
      );

  String homeSubtitle(String assistantName) => tr(
        '獨立日常輔助產品（無需輪椅亦可使用）：隨時叫「$assistantName」講「我去廚房」、「飲水」、查巴士路線、拍藥袋識字，或連接輪椅自動導航。',
        '独立日常辅助产品（无需轮椅亦可使用）：随时喊“$assistantName”说“我去厨房”、“喝水”、查公交路线、拍药袋识字，或连接轮椅自动导航。',
        'Standalone daily assistive companion (works with or without a wheelchair): say "$assistantName" for kitchen/room help, bus routes, medicine label reading, or safe navigation.',
      );
}
