import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/meetup_model.dart';
import '../models/user_model.dart' as app_models;
import '../services/firestore_service.dart';
import 'meetup_chat_screen.dart';
import 'user_profile_screen.dart';

class MeetupDetailScreen extends StatelessWidget {
  final String meetupId;

  const MeetupDetailScreen({super.key, required this.meetupId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return StreamBuilder<Meetup>(
      stream: firestoreService.getMeetup(meetupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Meetup not found')),
          );
        }

        final meetup = snapshot.data!;
        final currentUserId = firestoreService.currentUserId;
        final isJoined =
            currentUserId != null &&
            meetup.participantIds.contains(currentUserId);
        final isFull = meetup.participantIds.length >= meetup.maxParticipants;
        final dateFormat = DateFormat('EEE, MMM d @ h:mm a');

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Meetup Details'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
            actions: [
              if (isJoined)
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.blue,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MeetupChatScreen(
                          meetupId: meetupId,
                          meetupTitle: meetup.title,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Category Icon/Label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            meetup.category.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          meetup.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem(
                              '${meetup.participantIds.length}/${meetup.maxParticipants}',
                              'Joined',
                              isFull ? Colors.redAccent : Colors.teal,
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.grey[300],
                              margin: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                            ),
                            _buildStatItem('2', 'Likes', Colors.black87),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.grey[300],
                              margin: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                            ),
                            _buildStatItem('0', 'Comments', Colors.black87),
                          ],
                        ),
                        const SizedBox(height: 32),
                        const Divider(height: 1),
                        const SizedBox(height: 32),
                        // Info Rows
                        _buildInfoRow(
                          Icons.calendar_today_outlined,
                          'Date & Time',
                          dateFormat.format(meetup.dateTime),
                        ),
                        const SizedBox(height: 24),
                        _buildInfoRow(
                          Icons.location_on_outlined,
                          'Location',
                          meetup.location,
                        ),
                        const SizedBox(height: 24),
                        _buildInfoRow(
                          Icons.person_outline,
                          'Host',
                          meetup.host.name,
                        ),
                        const SizedBox(height: 40),
                        // About Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: const Text(
                            'About this meetup',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            meetup.description,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Participants Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: const Text(
                            'Participants',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 72,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: meetup.participantIds.length,
                            itemBuilder: (context, index) {
                              final participantId =
                                  meetup.participantIds[index];
                              return FutureBuilder<app_models.User?>(
                                future: firestoreService.getUserById(
                                  participantId,
                                ),
                                builder: (context, userSnap) {
                                  final pUser = userSnap.data;
                                  final name = pUser?.name ?? '';
                                  final avatar = pUser?.avatarUrl ?? '';

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              UserProfileScreen(
                                                userId: participantId,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: Colors.teal[50],
                                            backgroundImage: avatar.isNotEmpty
                                                ? NetworkImage(avatar)
                                                : null,
                                            child: avatar.isEmpty
                                                ? Text(
                                                    name.isNotEmpty
                                                        ? name[0].toUpperCase()
                                                        : '?',
                                                    style: TextStyle(
                                                      color: Colors.teal[700],
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            width: 50,
                                            child: Text(
                                              name.isNotEmpty ? name : '...',
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom Button
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isFull && !isJoined
                          ? null
                          : () async {
                              if (isJoined) {
                                await firestoreService.leaveMeetup(meetupId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('You left the meetup.'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              } else {
                                final success = await firestoreService
                                    .joinMeetup(meetupId);
                                if (context.mounted && success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Successfully joined!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isJoined
                            ? Colors.redAccent
                            : (isFull ? Colors.grey[300] : Colors.blue),
                        foregroundColor: isFull && !isJoined
                            ? Colors.grey[600]
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isJoined
                            ? 'Leave Meetup'
                            : (isFull ? 'Recruitment Closed' : 'Join Now'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.teal, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
