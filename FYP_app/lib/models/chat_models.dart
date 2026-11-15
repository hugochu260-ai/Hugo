enum ChatRole { user, agent, system }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    DateTime? at,
    this.isError = false,
  }) : at = at ?? DateTime.now();

  final ChatRole role;
  final String text;
  final DateTime at;
  final bool isError;

  bool get isUser => role == ChatRole.user;
}
