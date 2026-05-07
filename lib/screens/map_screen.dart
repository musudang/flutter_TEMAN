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
  bool _panelOpen = false;
  Timer? _locationPingTimer;
  StreamSubscription<List<app_models.User>>? _friendsSubscription;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _locationPingTimer?.cancel();
    _friendsSubscription?.cancel();
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

        _startFriendsStream();
        setState(() => _isLoading = false);

        // Continuously ping location every 15 seconds to keep "online" status fresh
        _locationPingTimer = Timer.periodic(
          const Duration(seconds: 15),
          (_) => _pingLocation(),
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

  /// Periodically update own location to keep the timestamp fresh.
  Future<void> _pingLocation() async {
    if (!mounted || _currentPosition == null || !_locationSharingEnabled) return;

    try {
      // Get fresh position
      final newPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      _currentPosition = newPosition;

      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.updateUserLocation(
        newPosition.latitude,
        newPosition.longitude,
      );
    } catch (e) {
      debugPrint('Location ping error: $e');
    }
  }

  /// Subscribe to real-time nearby friends stream.
  void _startFriendsStream() {
    _friendsSubscription?.cancel();

    if (!_locationSharingEnabled || _currentPosition == null) {
      setState(() => _nearbyFriends = []);
      return;
    }

    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    _friendsSubscription = firestoreService
        .getNearbyFriendsStream(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          radiusInMeters: 1000,
        )
        .listen(
          (friends) {
            if (mounted) {
              setState(() => _nearbyFriends = friends);
            }
          },
          onError: (e) {
            debugPrint('Friends stream error: $e');
          },
        );
  }

  Future<void> _toggleLocationSharing() async {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    final newValue = !_locationSharingEnabled;

    // Immediately update UI
    setState(() {
      _locationSharingEnabled = newValue;
      // Instantly clear nearby friends when turning off
      if (!newValue) {
        _nearbyFriends = [];
      }
    });

    // Cancel existing stream subscription
    _friendsSubscription?.cancel();
    _friendsSubscription = null;

    await firestoreService.toggleLocationSharing(newValue);

    if (newValue && _currentPosition != null) {
      // Re-upload location with fresh timestamp
      await firestoreService.updateUserLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      // Re-start listening for nearby friends
      _startFriendsStream();
    }
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

    final panelHeight = MediaQuery.of(context).size.height * 0.45;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
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
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: myLatLng,
                    radius: 1000,
                    useRadiusInMeter: true,
                    color: Colors.red.withValues(alpha: 0.08),
                    borderColor: Colors.red.withValues(alpha: 0.8),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
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

          // Top-right location toggle chip
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _locationSharingEnabled
                        ? Icons.location_on
                        : Icons.location_off,
                    color: _locationSharingEnabled ? Colors.teal : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _locationSharingEnabled ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          _locationSharingEnabled ? Colors.teal : Colors.grey,
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: Switch(
                      value: _locationSharingEnabled,
                      onChanged: (_) => _toggleLocationSharing(),
                      activeTrackColor: Colors.teal.withValues(alpha: 0.5),
                      activeThumbColor: Colors.teal,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom sliding panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _panelOpen ? 0 : -panelHeight,
            height: panelHeight + 48, // 48 for the handle
            child: Column(
              children: [
                // Pull handle / toggle button
                GestureDetector(
                  onTap: () => setState(() => _panelOpen = !_panelOpen),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // Drag handle bar
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people,
                                color: Colors.teal, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Nearby Friends (${_nearbyFriends.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _panelOpen
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Panel body
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: !_locationSharingEnabled
                        ? const Center(
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
                          )
                        : _nearbyFriends.isEmpty
                            ? const Center(
                                child: Text(
                                  'No friends found within 1km.',
                                  style: TextStyle(color: Colors.grey),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
