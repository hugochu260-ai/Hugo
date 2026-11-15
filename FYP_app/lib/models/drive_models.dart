/// Parsed `/v1/drive` response.
class DriveDecision {
  const DriveDecision({
    required this.rc,
    required this.command,
    required this.stop,
    required this.visible,
    this.reason,
    this.latencyMs,
    this.lidarConnected = false,
    this.frontM,
    this.rearM,
    this.frontBlocked = false,
    this.rearBlocked = false,
    this.blockedReason,
    this.distanceTravelledM,
    this.distanceTargetM,
    this.distanceRemainingM,
    this.goalReached = false,
  });

  factory DriveDecision.fromJson(Map<String, dynamic> json) {
    double? d(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    bool b(String key, [bool fallback = false]) {
      final v = json[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      return fallback;
    }

    return DriveDecision(
      rc: (json['rc'] as num?)?.toInt() ?? 0,
      command: (json['command'] as String?) ?? 'stop',
      stop: b('stop'),
      visible: b('visible'),
      reason: json['reason'] as String?,
      latencyMs: d('latency_ms'),
      lidarConnected: b('lidar_connected'),
      frontM: d('front_m'),
      rearM: d('rear_m'),
      frontBlocked: b('front_blocked'),
      rearBlocked: b('rear_blocked'),
      blockedReason: json['blocked_reason'] as String?,
      distanceTravelledM: d('distance_travelled_m'),
      distanceTargetM: d('distance_target_m'),
      distanceRemainingM: d('distance_remaining_m'),
      goalReached: b('goal_reached'),
    );
  }

  final int rc;
  final String command;
  final bool stop;
  final bool visible;
  final String? reason;
  final double? latencyMs;
  final bool lidarConnected;
  final double? frontM;
  final double? rearM;
  final bool frontBlocked;
  final bool rearBlocked;
  final String? blockedReason;
  final double? distanceTravelledM;
  final double? distanceTargetM;
  final double? distanceRemainingM;
  final bool goalReached;

  bool get isOk => rc == 0;
}

/// Settings used by the auto-drive loop.
class DriveConfig {
  const DriveConfig({
    this.serverUrl = 'http://192.168.99.186:8000',
    this.apiKey = 'lightnav123',
    this.instruction = 'follow the person in the red shirt',
    this.autoRestart = true,
    this.fps = 2.0,
  });

  final String serverUrl;
  final String apiKey;
  final String instruction;
  final bool autoRestart;
  final double fps;

  DriveConfig copyWith({
    String? serverUrl,
    String? apiKey,
    String? instruction,
    bool? autoRestart,
    double? fps,
  }) =>
      DriveConfig(
        serverUrl: serverUrl ?? this.serverUrl,
        apiKey: apiKey ?? this.apiKey,
        instruction: instruction ?? this.instruction,
        autoRestart: autoRestart ?? this.autoRestart,
        fps: fps ?? this.fps,
      );
}
