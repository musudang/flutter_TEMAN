import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/meetup_model.dart';
import '../services/mock_data_service.dart';
import 'meetup_detail_screen.dart';
import 'create_meetup_screen.dart';

class MeetupListScreen extends StatelessWidget {
  const MeetupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('만남의 장 (Meetups)'), // "Meeting Place"
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateMeetupScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<MockDataService>(
        builder: (context, dataService, child) {
          final meetups = dataService.meetups;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: meetups.length,
            itemBuilder: (context, index) {
              final meetup = meetups[index];
              return _buildMeetupCard(context, meetup);
            },
          );
        },
      ),
    );
  }

  Widget _buildMeetupCard(BuildContext context, Meetup meetup) {
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MeetupDetailScreen(meetupId: meetup.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Placeholder
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                image: DecorationImage(
                  image: NetworkImage(meetup.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(
                          meetup.category.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.teal,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      Text(
                        dateFormat.format(meetup.dateTime),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meetup.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        meetup.location,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${meetup.participantCount}/${meetup.maxParticipants} Joined',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
