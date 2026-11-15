/// Commands understood by the BT04-A car controller.
enum CarCommand {
  forward('ONA', '前進'),
  backward('ONB', '後退'),
  left('ONC', '左轉'),
  right('OND', '右轉'),
  stop('ONF', '停止'),
  stopSafety('ONE', '停止（保險）');

  const CarCommand(this.payload, this.label);

  /// Three ASCII bytes written to FFE2.
  final String payload;

  /// Human readable label (Traditional Chinese).
  final String label;

  bool get isMovement =>
      this == CarCommand.forward ||
      this == CarCommand.backward ||
      this == CarCommand.left ||
      this == CarCommand.right;

  static CarCommand? fromApi(String? value) {
    switch (value) {
      case 'forward':
        return CarCommand.forward;
      case 'backward':
      case 'back':
        return CarCommand.backward;
      case 'left':
        return CarCommand.left;
      case 'right':
        return CarCommand.right;
      case 'stop':
        return CarCommand.stop;
      default:
        return null;
    }
  }
}
