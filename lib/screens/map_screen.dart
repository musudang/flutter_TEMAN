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
  /// People who pass the BILATERAL `mapFriends` gate AND are currently
  /// present + sharing — these get pins on the map.
  List<app_models.User> _nearbyFriends = [];
  /// Strangers (NOT mutual followers) within 1 km. Rendered only as a
  /// list in the Nearby tab — no pins, no precise position on the map.
  List<app_models.User> _nearbyUsers = [];
  /// Every mutual follower regardless of distance / location-sharing /
  /// `mapFriends` opt-in. Drives the Friends tab so the user can
  /// check / uncheck individuals.
  List<app_models.User> _mutualFollowers = [];
  /// My own `mapFriends` array. Mirrors what's in Firestore on `users/{me}`.
  Set<String> _myMapFriendIds = <String>{};
  bool _locationSharingEnabled = true;
  bool _hideFromFriends = false;
  bool _panelOpen = false;
  Timer? _refreshTimer;
  final MapController _mapController = MapController();
  bool _safetyDialogShownThisSession = false;
  int _panelTabIndex = 0; // 0 = Nearby, 1 = Friends

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
        _myMapFriendIds = currentUser.mapFriends.toSet();
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

    // Heartbeat: re-publish my own location every refresh tick so other
    // users see me as "online / present". If sharing is OFF we skip — we
    // don't want to leak a fresh timestamp while hidden.
    if (_locationSharingEnabled) {
      // Best-effort: don't block the rest of the refresh on this write.
      // Re-fetch a current GPS reading if possible so the heartbeat reflects
      // the user's actual location (not just the initial fix).
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _currentPosition = pos;
        await firestoreService.updateUserLocation(pos.latitude, pos.longitude);
      } catch (_) {
        // If GPS fails, still refresh the timestamp via the last known fix
        // so we don't disappear from friends' maps purely due to a transient
        // GPS error.
        await firestoreService.updateUserLocation(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
    }

    // Refresh three lists in parallel. `getMutualFollowerUsers` is
    // independent of distance/location so it doesn't need to wait for a
    // GPS fix; we fire it alongside for one round-trip.
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
      firestoreService.getMutualFollowerUsers(),
    ]);

    // Also re-pull my own mapFriends array since I may have toggled
    // someone from the Friends tab. Cheap single-doc read.
    final me = await firestoreService.getCurrentUser();

    if (mounted) {
      setState(() {
        _nearbyFriends = results[0];
        _nearbyUsers = results[1];
        _mutualFollowers = results[2];
        if (me != null) {
          _myMapFriendIds = me.mapFriends.toSet();
        }
      });
    }
  }

  Future<void> _toggleMapFriend(app_models.User other) async {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    // Optimistic flip
    setState(() {
      if (_myMapFriendIds.contains(other.id)) {
        _myMapFriendIds.remove(other.id);
      } else {
        _myMapFriendIds.add(other.id);
      }
    });
    try {
      await firestoreService.toggleMapFriend(other.id);
    } catch (e) {
      // Roll back optimistic update on failure
      if (mounted) {
        setState(() {
          if (_myMapFriendIds.contains(other.id)) {
            _myMapFriendIds.remove(other.id);
          } else {
            _myMapFriendIds.add(other.id);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update map friend: $e')),
        );
      }
    }
    // Pull fresh nearby/friends after the toggle so the map pin appears
    // or disappears immediately when bilateral becomes (un)satisfied.
    await _refreshData();
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.teal, size: 26),
            SizedBox(width: 10),
            Text('Map Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _helpRow(Icons.location_on, Colors.teal, 'Location Sharing (Green)',
                'When ON, your location is visible to nearby users and friends within 1km.'),
            const SizedBox(height: 16),
            _helpRow(Icons.visibility_off, Colors.red, 'Hide from Friends (Red)',
                'When ON, even your mutual friends cannot see your location on the map.'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Always turn OFF location sharing when you are not using this feature to protect your privacy and save battery.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _helpRow(IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  bool _isFriend(String userId) {
    return _nearbyFriends.any((u) => u.id == userId);
  }

  Widget _buildNearbyTab() {
    final nearbyOnly = _nearbyUsers.where((u) => !_isFriend(u.id)).toList();
    if (nearbyOnly.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_off, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('No nearby people found.\nTry again later!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: nearbyOnly.length,
      itemBuilder: (context, index) {
        final user = nearbyOnly[index];
        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                child: user.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            'Nearby${user.universityId.isNotEmpty ? ' · ${user.universityId}' : user.nationality.isNotEmpty ? ' · ${user.nationality}' : ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.orange),
          onTap: () => _openUserProfile(user),
        );
      },
    );
  }

  Widget _buildFriendsTab() {
    // Split mutual followers into two sections, mirroring Instagram's
    // close-friends UI:
    //   • Map Friends — mutuals I've checked in. Filled checkbox.
    //   • Mutual Followers — the rest. Empty checkbox.
    // Tapping any row toggles my side of the bilateral pair.
    final mapFriends =
        _mutualFollowers.where((u) => _myMapFriendIds.contains(u.id)).toList();
    final others =
        _mutualFollowers.where((u) => !_myMapFriendIds.contains(u.id)).toList();

    if (_mutualFollowers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No mutual followers yet.\nFollow someone who follows you back!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (mapFriends.isNotEmpty) ...[
          _sectionHeader(
            'Map Friends',
            'Both of you have to check each other. Then you appear on each other\'s map.',
          ),
          ...mapFriends.map((u) => _mapFriendRow(u, checked: true)),
        ],
        if (others.isNotEmpty) ...[
          _sectionHeader(
            'Mutual Followers',
            'Tap to add them to Map Friends (one-sided — they have to add you too).',
          ),
          ...others.map((u) => _mapFriendRow(u, checked: false)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _mapFriendRow(app_models.User user, {required bool checked}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
        child: user.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        user.universityId.isNotEmpty
            ? user.universityId
            : (user.nationality.isNotEmpty ? user.nationality : 'Mutual'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline,
                size: 18, color: Colors.teal),
            tooltip: 'Message',
            onPressed: () => _openChatWithUser(user),
          ),
          GestureDetector(
            onTap: () => _toggleMapFriend(user),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: checked ? Colors.teal : Colors.transparent,
                border: Border.all(
                  color: checked ? Colors.teal : Colors.grey.shade400,
                  width: 1.6,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
      onTap: () => _openUserProfile(user),
    );
  }

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
                userAgentPackageName: 'com.teman.community',
              ),
              // 1km radius circle — always visible
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
                  // Only mutual friends show precise location on the map
                  ..._nearbyFriends
                      .where((u) => u.latitude != null && u.longitude != null)
                      .map((u) {
                        final userColor = Colors.teal;
                        return Marker(
                          point: LatLng(u.latitude!, u.longitude!),
                          width: 60,
                          height: 60,
                          child: GestureDetector(
                            onTap: () => _openChatWithUser(u),
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
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // ── Top bar: Toggle buttons ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                const Spacer(),
                // Help button
                GestureDetector(
                  onTap: _showHelpDialog,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.help_outline, color: Colors.teal, size: 20),
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
                            const Icon(
                              Icons.map,
                              color: Colors.teal,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Friends (${_mutualFollowers.length}) · Nearby (${_nearbyUsers.length})',
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
                // Tab bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _panelTabIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _panelTabIndex == 0
                                  ? Colors.orange.withValues(alpha: 0.12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.explore, size: 16,
                                    color: _panelTabIndex == 0 ? Colors.orange : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Nearby (${_nearbyUsers.where((u) => !_isFriend(u.id)).length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _panelTabIndex == 0 ? Colors.orange.shade800 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _panelTabIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _panelTabIndex == 1
                                  ? Colors.teal.withValues(alpha: 0.12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people, size: 16,
                                    color: _panelTabIndex == 1 ? Colors.teal : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Friends (${_mutualFollowers.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _panelTabIndex == 1 ? Colors.teal.shade800 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Panel list content
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: _panelTabIndex == 0
                        ? _buildNearbyTab()
                        : _buildFriendsTab(),
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

}
