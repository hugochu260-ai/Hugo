enum BlinkState { eyesOpen, blinking, triggered, cooldown }

class BlinkResult {
  const BlinkResult({
    required this.state,
    required this.eyesClosed,
    required this.triggered,
    required this.progress,
  });

  final BlinkState state;
  final bool eyesClosed;
  final bool triggered;
  final double progress;
}

/// Blink-to-click state machine (1000 ms dwell, 1200 ms cooldown).
class BlinkDwellDetector {
  BlinkDwellDetector({
    this.blinkOnThreshold = 0.5,
    this.blinkOffThreshold = 0.35,
    this.dwellMs = 1000,
    this.cooldownMs = 1200,
    this.smoothingAlpha = 0.3,
    this.requireBothEyes = false,
  });

  double blinkOnThreshold;
  double blinkOffThreshold;
  final int dwellMs;
  final int cooldownMs;
  final double smoothingAlpha;
  final bool requireBothEyes;

  BlinkState _state = BlinkState.eyesOpen;
  double _left = 0;
  double _right = 0;
  bool _hasSample = false;
  int? _closedSince;
  int? _cooldownSince;

  double get smoothedLeft => _left;
  double get smoothedRight => _right;
  BlinkState get state => _state;

  /// Recompute thresholds from the user's open-eye blendshape baseline.
  void personalize(double openBaseline) {
    blinkOnThreshold = (openBaseline + 0.15).clamp(0.5, 0.85).toDouble();
    blinkOffThreshold =
        (blinkOnThreshold - 0.15).clamp(0.3, 0.9).toDouble();
  }

  BlinkResult onSample(int nowMs, double rawLeft, double rawRight) {
    if (!_hasSample) {
      _left = rawLeft;
      _right = rawRight;
      _hasSample = true;
    } else {
      _left += smoothingAlpha * (rawLeft - _left);
      _right += smoothingAlpha * (rawRight - _right);
    }

    final leftClosed = _left > blinkOnThreshold;
    final rightClosed = _right > blinkOnThreshold;
    final leftOpen = _left < blinkOffThreshold;
    final rightOpen = _right < blinkOffThreshold;
    final closed = requireBothEyes
        ? (leftClosed && rightClosed)
        : (leftClosed || rightClosed);
    final open = requireBothEyes
        ? (leftOpen && rightOpen)
        : (leftOpen || rightOpen);

    var triggered = false;
    switch (_state) {
      case BlinkState.eyesOpen:
        if (closed) {
          _state = BlinkState.blinking;
          _closedSince = nowMs;
        }
        break;
      case BlinkState.blinking:
        if (open) {
          _state = BlinkState.eyesOpen;
          _closedSince = null;
        } else if (_closedSince != null &&
            nowMs - _closedSince! >= dwellMs) {
          _state = BlinkState.triggered;
          triggered = true;
        }
        break;
      case BlinkState.triggered:
        _state = BlinkState.cooldown;
        _cooldownSince = nowMs;
        break;
      case BlinkState.cooldown:
        if (open &&
            _cooldownSince != null &&
            nowMs - _cooldownSince! >= cooldownMs) {
          _state = BlinkState.eyesOpen;
          _closedSince = null;
          _cooldownSince = null;
        }
        break;
    }

    final progress = _state == BlinkState.blinking && _closedSince != null
        ? ((nowMs - _closedSince!) / dwellMs).clamp(0.0, 1.0)
        : 0.0;

    return BlinkResult(
      state: _state,
      eyesClosed: closed,
      triggered: triggered,
      progress: progress,
    );
  }

  void reset() {
    _state = BlinkState.eyesOpen;
    _hasSample = false;
    _closedSince = null;
    _cooldownSince = null;
    _left = 0;
    _right = 0;
  }
}
