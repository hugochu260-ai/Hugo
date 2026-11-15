import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';

import '../../services/camera/jetson_video_service.dart';

/// Low-latency H.264/MPEG-TS view fed by [JetsonVideoService].
class JetsonVideoView extends StatefulWidget {
  const JetsonVideoView({super.key, required this.service});

  final JetsonVideoService service;

  @override
  State<JetsonVideoView> createState() => _JetsonVideoViewState();
}

class _JetsonVideoViewState extends State<JetsonVideoView> {
  VlcPlayerController? _controller;
  String? _url;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureController());
  }

  void _onServiceChanged() {
    _ensureController();
  }

  void _ensureController() {
    final url = widget.service.localUrl;
    if (!mounted || url == null || url == _url) return;
    _url = url;
    final old = _controller;
    if (old != null) unawaited(old.dispose());
    final controller = VlcPlayerController.network(
      url,
      hwAcc: HwAcc.full,
      autoInitialize: true,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(50),
          VlcAdvancedOptions.liveCaching(50),
          VlcAdvancedOptions.clockSynchronization(0),
          VlcAdvancedOptions.clockJitter(0),
        ]),
        video: VlcVideoOptions([
          VlcVideoOptions.dropLateFrames(true),
          VlcVideoOptions.skipFrames(true),
        ]),
        http: VlcHttpOptions([
          VlcHttpOptions.httpReconnect(true),
        ]),
        extras: const ['--no-audio'],
      ),
    );
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: VlcPlayer(
        controller: controller,
        aspectRatio: 16 / 9,
        placeholder: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
