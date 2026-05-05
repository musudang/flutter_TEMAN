import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class PlatformMapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;

  const PlatformMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<PlatformMapWidget> createState() => _PlatformMapWidgetState();
}

class _PlatformMapWidgetState extends State<PlatformMapWidget> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'kakao-map-${DateTime.now().millisecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'kakao_map.html?lat=${widget.latitude}&lng=${widget.longitude}'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
