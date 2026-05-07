import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart' as app_models;
import 'chat_screen.dart';
import 'user_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/map_safety_dialog.dart';

enum MapMode { friends, discover }

class MapScreen extends StatefulWidget {
  final bool isVisible;
  const MapScreen({super.key, this.isVisible = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Position? _currentPosition;
  List<app_models.User> _nearbyFriends = [];
  List<app_models.User> _nearbyUsers = [];
  bool _locationSharingEnabled = true;
  bool _hideFromFriends = false;
  bool _panelOpen = false;
  Timer? _refreshTimer;
  final MapController _mapController = MapController();
  bool _safetyDialogShownThisSession = false;
  MapMode _currentMode = MapMode.friends;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _checkAndShowSafetyDialog() async {
    if (_safetyDialogShownThisSession) return;
    _safetyDialogShownThisSession = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final hiddenDateStr = prefs.getString('map_safety_guide_hidden_date');
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    if (hiddenDateStr != todayStr) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MapSafetyDialog(),
      );
    }
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
        _hideFromFriends = currentUser.hideLocationFromFriends;
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

        await _refreshData();
        setState(() => _isLoading = false);

        _refreshTimer = Timer.periodic(
          const Duration(seconds: 30),
          (_) => _refreshData(),
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

  Future<void> _refreshData() async {
    if (!mounted || _currentPosition == null) return;

    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    // Refresh both lists in parallel
    final results = await Future.wait([
      firestoreService.getNearbyFriends(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      ),
      firestoreService.getNearbyUsers(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        radiusInMeters: 1000,
      ),
    ]);

    if (mounted) {
      setState(() {
        _nearbyFriends = results[0];
        _nearbyUsers = results[1];
      });
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

    await _refreshData();
  }

  Future<void> _toggleHideFromFriends() async {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    final newValue = !_hideFromFriends;
    setState(() => _hideFromFriends = newValue);

    await firestoreService.toggleHideLocationFromFriends(newValue);
    await _refreshData();
  }

  Future<void> _openChatWithUser(app_models.User user) async {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    final conversationId =
        await firestoreService.getOrCreateConversation(user.id);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            chatTitle: user.name,
            otherUserId: user.id,
            otherUserName: user.name,
            otherUserAvatar: user.avatarUrl,
          ),
        ),
      );
    }
  }

  void _openUserProfile(app_models.User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: user.id),
      ),
    );
  }

  Color _getColorForUser(String userId) {
    final colors = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.orange, Colors.deepOrange, Colors.brown, Colors.blueGrey,
    ];
    final hash = userId.hashCode;
    final index = hash.abs() % colors.length;
    return colors[index];
  }

  // ── Active user list based on current mode ──
  List<app_models.User> get _activeUsers =>
      _currentMode == MapMode.friends ? _nearbyFriends : _nearbyUsers;

  @override
  Widget build(BuildContext context) {
    // Show the safety dialog only when the Map tab is actually visible
    if (widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowSafetyDialog();
      });
    }

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

    // When location sharing is OFF, hide the map entirely
    if (!_locationSharingEnabled) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    size: 72,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Location Sharing is OFF',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your location is hidden from everyone.\nEnable location sharing to see your friends on the map.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _toggleLocationSharing,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Enable Location Sharing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final myLatLng = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    final panelHeight = MediaQuery.of(context).size.height * 0.45;
    final isFriendsMode = _currentMode == MapMode.friends;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──
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
              // 1km radius circle — show in Discover mode only
              if (!isFriendsMode)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: myLatLng,
                      radius: 1000,
                      useRadiusInMeter: true,
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderColor: Colors.orange.withValues(alpha: 0.6),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // My position marker
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
                  // User markers
                  ..._activeUsers
                      .where((u) => u.latitude != null && u.longitude != null)
                      .map((u) {
                        final userColor = _getColorForUser(u.id);
                        return Marker(
                          point: LatLng(u.latitude!, u.longitude!),
                          width: 60,
                          height: 60,
                          child: GestureDetector(
                            onTap: () => isFriendsMode
                                ? _openChatWithUser(u)
                                : _openUserProfile(u),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: userColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    u.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: userColor, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.white,
                                    backgroundImage: u.avatarUrl.isNotEmpty
                                        ? NetworkImage(u.avatarUrl)
                                        : null,
                                    child: u.avatarUrl.isEmpty
                                        ? Icon(Icons.person,
                                            color: userColor, size: 20)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                ],
              ),
            ],
          ),

          // ── Top bar: Mode tabs + Location toggle ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Mode toggle tabs
                Expanded(
                  child: Container(
                    height: 40,
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
                      children: [
                        _buildModeTab(
                          icon: Icons.people,
                          label: 'Friends',
                          mode: MapMode.friends,
                          color: Colors.teal,
                        ),
                        _buildModeTab(
                          icon: Icons.explore,
                          label: 'Discover',
                          mode: MapMode.discover,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Hide from friends toggle chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        _hideFromFriends
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: _hideFromFriends ? Colors.red : Colors.grey,
                        size: 16,
                      ),
                      SizedBox(
                        height: 28,
                        child: Switch(
                          value: _hideFromFriends,
                          onChanged: (_) => _toggleHideFromFriends(),
                          activeTrackColor:
                              Colors.red.withValues(alpha: 0.5),
                          activeThumbColor: Colors.red,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Location toggle chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        Icons.location_on,
                        color: Colors.teal,
                        size: 16,
                      ),
                      SizedBox(
                        height: 28,
                        child: Switch(
                          value: _locationSharingEnabled,
                          onChanged: (_) => _toggleLocationSharing(),
                          activeTrackColor:
                              Colors.teal.withValues(alpha: 0.5),
                          activeThumbColor: Colors.teal,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom sliding panel ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _panelOpen ? 0 : -panelHeight,
            height: panelHeight + 48,
            child: Column(
              children: [
                // Pull handle
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
                            Icon(
                              isFriendsMode ? Icons.people : Icons.explore,
                              color: isFriendsMode
                                  ? Colors.teal
                                  : Colors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isFriendsMode
                                  ? 'Mutual Friends (${_nearbyFriends.length})'
                                  : 'Nearby People (${_nearbyUsers.length})',
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
                    child: _activeUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isFriendsMode
                                      ? Icons.people_outline
                                      : Icons.explore_off,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isFriendsMode
                                      ? 'No friends are sharing their location right now.'
                                      : 'No one found within 1km.\nTry again later!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _activeUsers.length,
                            itemBuilder: (context, index) {
                              final user = _activeUsers[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      user.avatarUrl.isNotEmpty
                                          ? NetworkImage(user.avatarUrl)
                                          : null,
                                  child: user.avatarUrl.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  user.universityId.isNotEmpty
                                      ? user.universityId
                                      : user.nationality,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: isFriendsMode
                                    ? const Icon(
                                        Icons.chat_bubble_outline,
                                        size: 18,
                                        color: Colors.teal,
                                      )
                                    : const Icon(
                                        Icons.person_add_alt_1,
                                        size: 18,
                                        color: Colors.orange,
                                      ),
                                onTap: () => isFriendsMode
                                    ? _openChatWithUser(user)
                                    : _openUserProfile(user),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ── My Location FAB ──
          Positioned(
            bottom: _panelOpen ? panelHeight + 64 : 64,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'myLocation',
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: Colors.teal,
              elevation: 4,
              onPressed: () {
                _mapController.move(myLatLng, 14.0);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required IconData icon,
    required String label,
    required MapMode mode,
    required Color color,
  }) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentMode = mode;
            _panelOpen = false;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
