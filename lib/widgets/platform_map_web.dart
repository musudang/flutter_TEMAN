// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html; // ignore: deprecated_member_use
import 'dart:js' as js; // ignore: deprecated_member_use
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
        final div = html.DivElement()
          ..id = 'kakao-map-container-$viewId'
          ..style.width = '100%'
          ..style.height = '100%';

        // Wait for div to be in DOM, then init map
        Future.delayed(const Duration(milliseconds: 500), () {
          _initKakaoMap(div.id);
        });

        return div;
      },
    );
  }

  void _initKakaoMap(String containerId) {
    try {
      final lat = widget.latitude;
      final lng = widget.longitude;

      js.context.callMethod('eval', ['''
        (function() {
          var retryCount = 0;
          function tryInit() {
            retryCount++;
            var container = document.getElementById('$containerId');
            if (!container) {
              if (retryCount < 20) setTimeout(tryInit, 500);
              return;
            }
            // Check if kakao.maps.LatLng exists (autoload=true means full API loaded)
            if (typeof kakao === 'undefined' || typeof kakao.maps === 'undefined' || typeof kakao.maps.LatLng === 'undefined') {
              console.log('Kakao Maps API not ready (attempt ' + retryCount + ')');
              if (retryCount < 20) setTimeout(tryInit, 500);
              return;
            }

            console.log('Kakao Maps API ready, creating map...');
            var center = new kakao.maps.LatLng($lat, $lng);
            var map = new kakao.maps.Map(container, {
              center: center,
              level: 6
            });

            // Red dot marker
            var dot = document.createElement('div');
            dot.style.cssText = 'width:20px;height:20px;background:#FF4444;border:3px solid white;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3);';
            new kakao.maps.CustomOverlay({
              position: center,
              content: dot,
              yAnchor: 0.5,
              xAnchor: 0.5,
              map: map
            });

            // 3km radius circle
            new kakao.maps.Circle({
              center: center,
              radius: 3000,
              strokeWeight: 2,
              strokeColor: '#FF4444',
              strokeOpacity: 0.8,
              strokeStyle: 'solid',
              fillColor: '#FF4444',
              fillOpacity: 0.08,
              map: map
            });

            console.log('Kakao Map created successfully!');
          }
          tryInit();
        })();
      ''']);
    } catch (e) {
      debugPrint('Error initializing Kakao Map: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
