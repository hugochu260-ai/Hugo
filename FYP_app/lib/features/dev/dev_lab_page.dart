import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../radar/radar_page.dart';
import '../tilt/tilt_page.dart';

class DevLabPage extends StatefulWidget {
  const DevLabPage({super.key});

  @override
  State<DevLabPage> createState() => _DevLabPageState();
}

class _DevLabPageState extends State<DevLabPage> {
  int _subTab = 0;

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.pagePadding(context);
    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.radar),
                    label: Text('雷達點雲與雙指縮放'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.screen_rotation_alt),
                    label: Text('斜坡減速與防跌測試台'),
                  ),
                ],
                selected: {_subTab},
                onSelectionChanged: (s) => setState(() => _subTab = s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 14),
              if (_subTab == 0) const RadarPage() else const TiltPage(),
            ],
          ),
        ),
      ),
    );
  }
}
