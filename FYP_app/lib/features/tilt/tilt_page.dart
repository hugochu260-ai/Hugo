import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../services/settings_store.dart';
import '../../services/tilt/tilt_analyzer.dart';
import '../../services/tilt/tilt_math.dart';
import '../../services/tilt/tilt_monitor_service.dart';

/// Displays global posture protection, distinguishing Handheld Daily Mode
/// (no false tilt alarms when holding phone!) from Wheelchair-Mounted Mode
/// (slope auto-slowdown + lateral rollover & impact guard).
class TiltPage extends StatelessWidget {
  const TiltPage({super.key});

  static String _modeLabel(TiltMonitorService tilt, SettingsStore settings) {
    if (settings.tiltMode == 'off') {
      return '靜音關閉';
    }
    if (!tilt.isMountedProtectionActive) {
      return '手持日常防跌模式（攞起手機睇嘢唔會亂響，只測劇烈跌倒撞擊）';
    }
    return tilt.isTouchAdjustingNow
        ? '車載支架模式（偵測到手指觸控調校中，暫停靜態警報）'
        : '車載支架保護模式（支援打直望 mon 或平放，上落斜自動減速）';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tilt = context.watch<TiltMonitorService>();
    final settings = context.watch<SettingsStore>();
    final split = Responsive.useSplitPane(context);
    final statusColor = _statusColor(p, tilt.status);

    final gaugeCard = SectionCard(
      title: '全天候斜坡減速與防跌翻監測',
      subtitle: '目前模式：${_modeLabel(tilt, settings)}',
      trailing: StatusChip(
        label: _shortStatus(tilt.status, tilt.isMountedProtectionActive),
        color: statusColor,
        icon: Icons.shield_outlined,
        compact: true,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              _statusDescription(
                tilt.status,
                tilt.recommendedSpeedFactor,
                tilt.isMountedProtectionActive,
              ),
              style: TextStyle(
                color: statusColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: _BubbleGauge(
              reading: tilt.reading,
              color: statusColor,
              palette: p,
              size: split ? 210 : 185,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: '前方較低（落斜）',
                  value: _deg(tilt.reading?.frontLower),
                  color: tilt.status == TiltStatus.slopeDown ? p.secondary : p.text,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: '後方較低（上斜）',
                  value: _deg(tilt.reading?.backLower),
                  color: tilt.status == TiltStatus.slopeUp ? p.secondary : p.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: '左方側傾',
                  value: _deg(tilt.reading?.leftLower),
                  color: (tilt.reading?.leftLower ?? 0) >= 8.5 ? p.danger : p.text,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: '右方側傾',
                  value: _deg(tilt.reading?.rightLower),
                  color: (tilt.reading?.rightLower ?? 0) >= 8.5 ? p.danger : p.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final configCol = Column(
      children: [
        SectionCard(
          title: '手持／車載支架模式與全角度歸零',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '推薦揀「智能自動」：未連車時當手持使用唔會亂響；連上藍牙車／導航後自動鎖定支架角度（打直望 mon 或平放皆可）。如想喺書枱單獨測試斜度儀表，可揀「強制車載支架」。',
                style: TextStyle(color: p.muted, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'auto', label: Text('智能自動')),
                  ButtonSegment(value: 'handheld', label: Text('純手持防跌')),
                  ButtonSegment(value: 'mounted', label: Text('強制車載支架')),
                ],
                selected: {
                  const {'auto', 'handheld', 'mounted'}.contains(settings.tiltMode)
                      ? settings.tiltMode
                      : 'auto'
                },
                onSelectionChanged: (sel) async {
                  await settings.updateTiltMode(sel.first);
                  if (sel.first == 'mounted') {
                    tilt.calibrate();
                  }
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: tilt.canCalibrate
                    ? () {
                        final out = tilt.calibrate();
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              out == CalibrationOutcome.success
                                  ? '已將目前擺放角度（打直望 mon 或平放）鎖定為 0° 基準！'
                                  : '請避免大幅左右側歪並確保感測器有數據',
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('將目前支架角度設為 0° 基準'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '上下斜坡自動減速保護',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('偵測到 6°–15.5° 平穩斜坡時自動將車速降至 48%–58%，唔會誤響跌倒警報'),
                value: settings.slopeSlowdown,
                onChanged: (v) => settings.updateSlopeSlowdown(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: '斜坡 vs 跌倒判別指標（即時數據）',
          child: Column(
            children: [
              _kv(p, '建議車速比例', '${(tilt.recommendedSpeedFactor * 100).round()}%'),
              _kv(p, '即時角速度（陀螺儀）', '${tilt.gyroDegPerSec.toStringAsFixed(1)} °/s'),
              _kv(p, '線性衝擊加速度', '${tilt.impactG.toStringAsFixed(2)} G'),
              _kv(p, '感測器來源', tilt.sensorName.isEmpty ? '未就緒' : tilt.sensorName),
              _kv(p, '斜坡慢行區間', '前後傾 6°–15.5° 且左右傾少於 8.5°'),
              _kv(p, '翻側／跌倒報警條件', '支架側傾 ≥ 12.5° 或手持劇烈跌落撞擊 ≥ 1.85G'),
            ],
          ),
        ),
      ],
    );

    return split
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: gaugeCard),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: configCol),
            ],
          )
        : Column(
            children: [
              gaugeCard,
              const SizedBox(height: 12),
              configCol,
            ],
          );
  }

  static String _deg(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}°';

  static Widget _kv(AppPalette p, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(k, style: TextStyle(color: p.muted, fontSize: 13.5))),
            Text(v,
                style: TextStyle(
                    color: p.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  static String _shortStatus(TiltStatus s, bool mountedActive) {
    if (!mountedActive) return '手持防跌中';
    switch (s) {
      case TiltStatus.monitoring:
        return '支架正常';
      case TiltStatus.slopeUp:
        return '上斜慢行';
      case TiltStatus.slopeDown:
        return '落斜慢行';
      case TiltStatus.warning:
        return '側傾預警';
      case TiltStatus.danger:
        return '翻側危險';
      case TiltStatus.fallDetected:
        return '跌倒撞擊警報';
      case TiltStatus.uncalibrated:
        return '自動鎖定中';
      case TiltStatus.unsupported:
        return '感測器不支援';
      default:
        return '準備中';
    }
  }

  static String _statusDescription(
      TiltStatus s, double speed, bool mountedActive) {
    if (!mountedActive) {
      return '目前為「手持日常模式」：隨意拿起或打直手機睇嘢都唔會誤響警報，只會偵測真實跌倒撞擊！';
    }
    final pct = (speed * 100).round();
    switch (s) {
      case TiltStatus.monitoring:
        return '車載支架穩定（正常速度 100%），全天候防翻側保護運作中。';
      case TiltStatus.slopeUp:
        return '偵測到正在上斜坡：已自動切換至柔和推進模式（速度 $pct%），不會觸發誤鳴警報。';
      case TiltStatus.slopeDown:
        return '偵測到正在落斜坡：已自動減慢車速至 $pct% 防止溜前，請保持穩定。';
      case TiltStatus.warning:
        return '注意：側傾或坡度偏大，已自動減速至 $pct%，請小心慢駛。';
      case TiltStatus.danger:
        return '危險警報！側傾角度超過安全上限，已自動鎖定煞停！';
      case TiltStatus.fallDetected:
        return '緊急警報！偵測到突發失衡撞擊，已緊急煞停並彈出求助！';
      case TiltStatus.uncalibrated:
        return '請將手機放定於支架上約 1 秒（或撳下方歸零掣），系統即自動鎖定目前角度。';
      case TiltStatus.unsupported:
        return '此裝置未能讀取姿態感測器。';
      default:
        return '正在讀取陀螺儀與重力姿態感測器…';
    }
  }

  static Color _statusColor(AppPalette p, TiltStatus s) {
    switch (s) {
      case TiltStatus.monitoring:
        return p.success;
      case TiltStatus.slopeUp:
      case TiltStatus.slopeDown:
        return p.primary;
      case TiltStatus.warning:
      case TiltStatus.uncalibrated:
        return p.warning;
      case TiltStatus.danger:
      case TiltStatus.fallDetected:
      case TiltStatus.unsupported:
        return p.danger;
      default:
        return p.muted;
    }
  }
}

class _BubbleGauge extends StatelessWidget {
  const _BubbleGauge({
    required this.reading,
    required this.color,
    required this.palette,
    required this.size,
  });

  final TiltGeometry? reading;
  final Color color;
  final AppPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final angle =
        reading == null ? '--' : '${reading!.total.toStringAsFixed(1)}°';
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BubblePainter(
                  reading: reading, color: color, palette: palette),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                angle,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '相對支架傾角',
                style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.reading,
    required this.color,
    required this.palette,
  });

  final TiltGeometry? reading;
  final Color color;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = palette.outline;
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius * 0.55, ring..strokeWidth = 1);

    final maxOffset = radius * 0.65;
    final lr = (reading?.leftRight ?? 0).clamp(-18.0, 18.0) / 18.0;
    final fb = (reading?.frontBack ?? 0).clamp(-18.0, 18.0) / 18.0;
    final pos = center + Offset(lr * maxOffset, -fb * maxOffset);

    canvas.drawCircle(
      pos,
      14,
      Paint()..color = color.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      pos,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.reading != reading || old.color != color;
}
