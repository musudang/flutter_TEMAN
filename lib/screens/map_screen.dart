import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart' as app_models;
import 'chat_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Position? _currentPosition;
  List<app_models.User> _nearbyFriends = [];
  bool _locationSharingEnabled = true;
  Timer? _refreshTimer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      final currentUser = await firestoreService.getCurrentUser();
      if (currentUser != null) {
        _locationSharingEnabled = currentUser.locationSharingEnabled;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied.';
          _isLoading = false;
        });
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted && _currentPosition != null) {
        if (_locationSharingEnabled) {
          await firestoreService.updateUserLocation(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
        }

        await _refreshFriends();
        setState(() => _isLoading = false);

        _refreshTimer = Timer.periodic(
          const Duration(seconds: 30),
          (_) => _refreshFriends(),
        );
      }
    } catch (e) {
      debugPrint('Map init error: $e');
      setState(() {
        _errorMessage = 'Error initializing map: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFriends() async {
    if (!mounted || _currentPosition == null) return;

    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    final friends = await firestoreService.getNearbyFriends(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      radiusInMeters: 3000,
    );

    if (mounted) {
      setState(() => _nearbyFriends = friends);
    }
  }

  Future<void> _toggleLocationSharing() async {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    final newValue = !_locationSharingEnabled;
    setState(() => _locationSharingEnabled = newValue);

    await firestoreService.toggleLocationSharing(newValue);

    if (newValue && _currentPosition != null) {
      await firestoreService.updateUserLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

    await _refreshFriends();
  }

  Future<void> _openChatWithFriend(app_models.User friend) async {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    final conversationId =
        await firestoreService.getOrCreateConversation(friend.id);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            chatTitle: friend.name,
            otherUserId: friend.id,
            otherUserName: friend.name,
            otherUserAvatar: friend.avatarUrl,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  _initializeMap();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final myLatLng = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    return Scaffold(
      body: Stack(
        children: [
          // flutter_map — works on web, mobile, desktop
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: myLatLng,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.teman.app',
              ),
              // 3km radius circle
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: myLatLng,
                    radius: 3000,
                    useRadiusInMeter: true,
                    color: Colors.red.withValues(alpha: 0.08),
                    borderColor: Colors.red.withValues(alpha: 0.8),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              // Markers
              MarkerLayer(
                markers: [
                  // My location marker
                  Marker(
                    point: myLatLng,
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Friend markers
                  ..._nearbyFriends
                      .where((f) => f.latitude != null && f.longitude != null)
                      .map((f) => Marker(
                            point: LatLng(f.latitude!, f.longitude!),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => _openChatWithFriend(f),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.teal,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      f.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.location_pin,
                                      color: Colors.teal, size: 20),
                                ],
                              ),
                            ),
                          )),
                ],
              ),
            ],
          ),

          // Right-side friend list panel
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 250,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.only(
                        top: 48, left: 12, right: 8, bottom: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Location toggle
                        Row(
                          children: [
                            Icon(
                              _locationSharingEnabled
                                  ? Icons.location_on
                                  : Icons.location_off,
                              color: _locationSharingEnabled
                                  ? Colors.teal
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _locationSharingEnabled
                                    ? 'Location ON'
                                    : 'Location OFF',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _locationSharingEnabled
                                      ? Colors.teal
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            Switch(
                              value: _locationSharingEnabled,
                              onChanged: (_) => _toggleLocationSharing(),
                              activeTrackColor:
                                  Colors.teal.withValues(alpha: 0.5),
                              activeThumbColor: Colors.teal,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        if (!_locationSharingEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Your location is hidden from others',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Friends title
                        Row(
                          children: [
                            const Icon(Icons.people,
                                color: Colors.teal, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Nearby Friends (3km)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _locationSharingEnabled
                                      ? Colors.black87
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                padding: EdgeInsets.zero,
                                onPressed: _locationSharingEnabled
                                    ? _refreshFriends
                                    : null,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Friends list
                  Expanded(
                    child: !_locationSharingEnabled
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_off,
                                      size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'Enable location sharing\nto see nearby friends',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _nearbyFriends.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No friends found\nwithin 3km.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _nearbyFriends.length,
                                itemBuilder: (context, index) {
                                  final friend = _nearbyFriends[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          friend.avatarUrl.isNotEmpty
                                              ? NetworkImage(friend.avatarUrl)
                                              : null,
                                      child: friend.avatarUrl.isEmpty
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    title: Text(friend.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                      friend.universityId.isNotEmpty
                                          ? friend.universityId
                                          : friend.nationality,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18,
                                      color: Colors.teal,
                                    ),
                                    onTap: () => _openChatWithFriend(friend),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
