import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/radar_plot.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/radar_models.dart';
import '../../services/radar/radar_service.dart';
import '../../services/settings_store.dart';

class RadarPage extends StatefulWidget {
  const RadarPage({super.key});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> {
  double rangeM = 5.0;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final radar = context.read<RadarService>();
    final settings = context.read<SettingsStore>();
    setState(() => _busy = true);
    try {
      if (radar.isConnected) {
        await radar.stop();
      } else {
        await radar.start(
          mode: settings.radarMode,
          wsUrl: settings.radarWsUrl,
          angleOffsetDeg: settings.radarAngleOffset,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radar = context.watch<RadarService>();
    final settings = context.watch<SettingsStore>();
    final split = Responsive.useSplitPane(context);

    final plotCard = SectionCard(
      title: '360° 激光雷達障礙物監看（支援雙指縮放）',
      subtitle: '目前顯示範圍：${rangeM.toStringAsFixed(1)} 米（可用兩指放大縮小 1–30m）',
      trailing: StatusChip(
        label: radar.isLive
            ? '即時更新 ${radar.status.hz.toStringAsFixed(1)}Hz'
            : radar.isConnected
                ? '無新掃描'
                : '未連接',
        color: radar.isLive
            ? p.success
            : radar.isConnected
                ? p.warning
                : p.danger,
        icon: Icons.radar,
        compact: true,
      ),
      child: Column(
        children: [
          SizedBox(
            height: split ? 400 : 300,
            child: RadarPlot(
              scan: radar.latest,
              rangeM: rangeM,
              onRangeChanged: (next) => setState(() => rangeM = next),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final preset in const [3.0, 5.0, 10.0, 20.0])
                ChoiceChip(
                  label: Text('${preset.toInt()}m'),
                  selected: (rangeM - preset).abs() < 0.25,
                  onSelected: (_) => setState(() => rangeM = preset),
                ),
            ],
          ),
        ],
      ),
    );

    final infoCol = Column(
      children: [
        SectionCard(
          title: '雷達連線與真實狀態',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '來源模式：${settings.radarMode.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _toggle,
                    icon: Icon(
                      radar.isConnected
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                    ),
                    label: Text(radar.isConnected ? '斷開雷達' : '連接雷達'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _kv(p, '連線狀態', _stateText(radar)),
              _kv(p, '有效點雲數量', radar.isLive ? '${radar.latest?.points.length ?? 0} 點' : '—（未連線）'),
              _kv(p, '安裝角度補償', '${settings.radarAngleOffset.round()}°'),
              if (radar.status.error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.danger),
                  ),
                  child: Text(
                    '連線錯誤：${radar.status.error}',
                    style: TextStyle(color: p.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: '前後防撞安全距離',
          subtitle: '少於 ${settings.safetyStopM.toStringAsFixed(1)} 米時會自動攔截前進／後退',
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: '前方最近障礙',
                  value: radar.isLive ? _fmt(radar.frontM) : '未連線',
                  unit: radar.isLive && radar.frontM != null ? 'm' : null,
                  color: _distColor(p, radar.isLive ? radar.frontM : null, settings.safetyStopM),
                  icon: Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: '後方最近障礙',
                  value: radar.isLive ? _fmt(radar.rearM) : '未連線',
                  unit: radar.isLive && radar.rearM != null ? 'm' : null,
                  color: _distColor(p, radar.isLive ? radar.rearM : null, settings.safetyStopM),
                  icon: Icons.arrow_downward,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return split
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: plotCard),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: infoCol),
            ],
          )
        : Column(
            children: [
              plotCard,
              const SizedBox(height: 12),
              infoCol,
            ],
          );
  }

  String _stateText(RadarService r) {
    if (r.isLive) return '正常接收掃描數據';
    if (r.isConnected) return 'WebSocket 已開但超過 2 秒無新數據';
    if (r.status.state == RadarConnectionState.error) return '連線失敗';
    if (r.status.state == RadarConnectionState.connecting) return '正在連接…';
    return '未連接';
  }

  String _fmt(double? v) => v == null ? '空曠' : v.toStringAsFixed(2);

  Color _distColor(AppPalette p, double? v, double stopM) {
    if (v == null) return p.muted;
    if (v < stopM) return p.danger;
    if (v < stopM + 0.8) return p.warning;
    return p.success;
  }

  Widget _kv(AppPalette p, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(k, style: TextStyle(color: p.muted, fontSize: 13.5)),
            const Spacer(),
            Flexible(
              child: Text(
                v,
                textAlign: TextAlign.end,
                style: TextStyle(color: p.text, fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
