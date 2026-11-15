import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/radar/radar_service.dart';
import 'radar_plot.dart';

class RadarMiniMap extends StatefulWidget {
  const RadarMiniMap({
    super.key,
    required this.radar,
    this.rangeM = 5,
    this.height = 156,
    this.onTap,
  });

  final RadarService radar;
  final double rangeM;
  final double height;
  final VoidCallback? onTap;

  @override
  State<RadarMiniMap> createState() => _RadarMiniMapState();
}

class _RadarMiniMapState extends State<RadarMiniMap> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radar = widget.radar;
    return SizedBox(
      height: _collapsed ? null : widget.height,
      width: double.infinity,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.outline),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
          child: Column(
            mainAxisSize: _collapsed ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.radar, size: 15, color: p.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      radar.isLive
                          ? '防撞雷達 ${widget.rangeM.toStringAsFixed(0)}m'
                          : radar.isConnected
                              ? '雷達無新資料'
                              : '雷達未連接',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _collapsed = !_collapsed),
                    tooltip: _collapsed ? '展開雷達' : '收起雷達',
                    icon: Icon(
                      _collapsed
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      size: 20,
                      color: p.muted,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              if (!_collapsed) ...[
                if (radar.isLive)
                  Text(
                    '前 ${_fmt(radar.frontM)}m · 後 ${_fmt(radar.rearM)}m',
                    style: TextStyle(
                      color: p.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 2),
                Expanded(
                  child: RadarPlot(
                    scan: radar.latest,
                    rangeM: widget.rangeM,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);
}
