import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/mock_data_service.dart';

class MeetupDetailScreen extends StatelessWidget {
  final String meetupId;

  const MeetupDetailScreen({super.key, required this.meetupId});

  @override
  Widget build(BuildContext context) {
    // Consume the service
    final dataService = Provider.of<MockDataService>(context);
    // Find the specific meetup (or handle not found)
    final meetup = dataService.meetups.firstWhere(
      (m) => m.id == meetupId,
      orElse: () => throw Exception('Meetup not found'),
    );

    final isJoined = meetup.participantIds.contains(dataService.currentUser.id);
    final isFull = meetup.isFull;
    final dateFormat = DateFormat('EEEE, MMM d @ h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetup Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(meetup.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Chip(
                      label: Text(
                        meetup.category.name.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      backgroundColor: Colors.teal[50],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meetup.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        '${meetup.participantCount}/${meetup.maxParticipants}',
                        'Joined',
                        Colors.green,
                      ),
                      _buildStatItem('2', 'Likes', Colors.black), // Mock
                      _buildStatItem('0', 'Comments', Colors.black), // Mock
                    ],
                  ),
                  const Divider(height: 40),

                  // Info Section
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Date & Time',
                    dateFormat.format(meetup.dateTime),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.location_on, 'Location', meetup.location),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.person, 'Host', meetup.host.name),

                  const SizedBox(height: 30),
                  const Text(
                    'About this meetup',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meetup.description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              if (isJoined) {
                dataService.leaveMeetup(meetupId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You left the meetup.')),
                );
              } else if (!isFull) {
                final success = dataService.joinMeetup(meetupId);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully joined!')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isJoined
                  ? Colors.redAccent
                  : (isFull ? Colors.grey : Colors.teal),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isJoined ? 'Leave Meetup' : (isFull ? 'Full' : 'Join Meetup'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
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
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.teal, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
