import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meetup_model.dart';

class MeetupCard extends StatelessWidget {
  final Meetup meetup;
  final VoidCallback onTap;

  const MeetupCard({super.key, required this.meetup, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isFull = meetup.participantIds.length >= meetup.maxParticipants;
    final int currentParticipants = meetup.participantIds.length;
    final int maxParticipants = meetup.maxParticipants;
    final double progress = maxParticipants > 0
        ? (currentParticipants / maxParticipants).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Image/Status Area (optional, can be just padding if no image)
            // For now, let's stick to a clean card layout without a massive banner image
            // unless we have one, but we'll add the "Recruitment Status" badge at the top.
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Category & Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          meetup.category.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isFull
                              ? Colors.grey[200]
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isFull ? 'CLOSED' : 'RECRUITING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isFull
                                ? Colors.grey[500]
                                : Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    meetup.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1F36),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Date & Location
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM d, h:mm a').format(meetup.dateTime),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meetup.location,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Progress Bar Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Participants',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13),
                              children: [
                                TextSpan(
                                  text: '$currentParticipants',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1F36),
                                  ),
                                ),
                                TextSpan(
                                  text: '/$maxParticipants',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[100],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isFull
                                ? Colors.grey[400]!
                                : const Color(0xFFFF5A5F),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Host Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: meetup.host.avatarUrl.isNotEmpty
                            ? NetworkImage(meetup.host.avatarUrl)
                            : null,
                        backgroundColor: Colors.grey[200],
                        child: meetup.host.avatarUrl.isEmpty
                            ? Text(
                                meetup.host.name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hosted by ${meetup.host.name}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
