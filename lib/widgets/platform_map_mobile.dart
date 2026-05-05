import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

class PlatformMapWidget extends StatelessWidget {
  final double latitude;
  final double longitude;

  const PlatformMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return KakaoMap(
      onMapCreated: ((controller) {}),
      center: LatLng(latitude, longitude),
      markers: [
        Marker(
          markerId: 'my_location',
          latLng: LatLng(latitude, longitude),
        ),
      ],
    );
  }
}
