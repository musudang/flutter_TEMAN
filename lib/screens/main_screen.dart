import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../providers/feed_state_provider.dart';
import 'feed_screen.dart';
import 'conversation_list_screen.dart';

import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'university_feed_screen.dart';
import 'map_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final feedState = Provider.of<FeedStateProvider>(context);

    final screens = <Widget>[
      Consumer<FeedStateProvider>(
        builder: (context, feedState, child) {
          if (feedState.selectedUniversity != null) {
            return UniversityFeedScreen(university: feedState.selectedUniversity!);
          }
          return const FeedScreen();
        },
      ), // 0 = Home (Dynamic Feed)
      const ConversationListScreen(), // 1 = Messages
      MapScreen(isVisible: _selectedIndex == 2), // 2 = Map

      const NotificationsScreen(), // 3 = Notifications
      const ProfileScreen(), // 4 = Profile
    ];

    return PopScope(
      canPop: _selectedIndex != 0 || feedState.selectedUniversity == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex == 0 && feedState.selectedUniversity != null) {
          feedState.setUniversity(null);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: screens),
        bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: StreamBuilder<int>(
                stream: firestoreService.getTotalUnreadMessageCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.chat_bubble_outline),
                  );
                },
              ),
              activeIcon: StreamBuilder<int>(
                stream: firestoreService.getTotalUnreadMessageCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.chat_bubble),
                  );
                },
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map',
            ),
            // Notification tab with real-time badge
            BottomNavigationBarItem(
              icon: StreamBuilder<int>(
                stream: firestoreService.getUnreadNotificationCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(fontSize: 10),
                    ),
                    child: const Icon(Icons.notifications_outlined),
                  );
                },
              ),
              activeIcon: StreamBuilder<int>(
                stream: firestoreService.getUnreadNotificationCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(fontSize: 10),
                    ),
                    child: const Icon(Icons.notifications),
                  );
                },
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: _onItemTapped,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          ),
        ),
      ),
    );
  }
}
