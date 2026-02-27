import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/meetup_model.dart';
import '../models/user_model.dart' as app_models;
import '../services/firestore_service.dart';
import 'meetup_chat_screen.dart';
import 'user_profile_screen.dart';
import 'meetup_comments_sheet.dart';
import 'share_content_sheet.dart';

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
        final isPending =
            currentUserId != null &&
            meetup.pendingParticipantIds.contains(currentUserId);
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
              // Host Delete Option
              if (currentUserId == meetup.host.id)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Meetup?'),
                          content: const Text(
                            'This will permanently remove the meetup and its chat.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        try {
                          await firestoreService.deleteMeetup(meetupId);
                          if (context.mounted) {
                            Navigator.pop(context); // Go back
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Meetup deleted successfully'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete meetup: $e'),
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete Meetup',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              StreamBuilder<app_models.User?>(
                stream: firestoreService.getUserStream(
                  firestoreService.currentUserId ?? '',
                ),
                builder: (context, userSnap) {
                  final isScrapped = meetup.scrappedBy.contains(
                    firestoreService.currentUserId,
                  );
                  return IconButton(
                    icon: Icon(
                      isScrapped ? Icons.bookmark : Icons.bookmark_border,
                      color: isScrapped ? Colors.teal : Colors.black,
                    ),
                    onPressed: () =>
                        firestoreService.toggleScrapMeetup(meetupId),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.black),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ShareContentSheet(
                      itemId: meetup.id,
                      itemType: 'meetup',
                      itemTitle: meetup.title,
                      itemDescription: meetup.description,
                    ),
                  );
                },
              ),
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
                        // Image
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: NetworkImage(meetup.imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          meetup.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Host
                        // Host (Live Data)
                        StreamBuilder<app_models.User?>(
                          stream: firestoreService.getUserStream(
                            meetup.host.id,
                          ),
                          builder: (context, hostSnap) {
                            final host = hostSnap.data ?? meetup.host;
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        UserProfileScreen(userId: host.id),
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: host.avatarUrl.isNotEmpty
                                        ? NetworkImage(host.avatarUrl)
                                        : null,
                                    child: host.avatarUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hosted by ${host.name}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Stats Row (Participants, Likes, Comments)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                '${meetup.participantIds.length}/${meetup.maxParticipants}',
                                'Going',
                                Colors.blue,
                              ),
                              Container(
                                height: 30,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              _buildStatItem(
                                '${meetup.likes}',
                                'Likes',
                                Colors.black87,
                              ),
                              Container(
                                height: 30,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              _buildStatItem(
                                '${meetup.comments}',
                                'Comments',
                                Colors.black87,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Info Section
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildInfoRow(
                          Icons.calendar_today,
                          'Date & Time',
                          dateFormat.format(meetup.dateTime),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          Icons.location_on,
                          'Location',
                          meetup.location,
                        ),

                        const SizedBox(height: 32),

                        // Description
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'About this Meetup',
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
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),

                        if (isJoined) ...[
                          const SizedBox(height: 32),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Participants',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: meetup.participantIds.length,
                              itemBuilder: (context, index) {
                                final participantId =
                                    meetup.participantIds[index];
                                final isHost = participantId == meetup.host.id;

                                return FutureBuilder<app_models.User?>(
                                  future: firestoreService.getUserById(
                                    participantId,
                                  ),
                                  builder: (context, userSnap) {
                                    final user = userSnap.data;
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
                                      child: Container(
                                        width: 70,
                                        margin: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: Column(
                                          children: [
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor:
                                                      Colors.grey[300],
                                                  backgroundImage:
                                                      user != null &&
                                                          user
                                                              .avatarUrl
                                                              .isNotEmpty
                                                      ? NetworkImage(
                                                          user.avatarUrl,
                                                        )
                                                      : null,
                                                  child:
                                                      user == null ||
                                                          user.avatarUrl.isEmpty
                                                      ? const Icon(
                                                          Icons.person,
                                                          color: Colors.white,
                                                          size: 30,
                                                        )
                                                      : null,
                                                ),
                                                if (isHost)
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Colors.amber,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      child: const Icon(
                                                        Icons.star,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                    ),
                                                  ),
                                                if (currentUserId ==
                                                        meetup.host.id &&
                                                    meetup.requiresApproval &&
                                                    !isHost)
                                                  Positioned(
                                                    top: -4,
                                                    right: -4,
                                                    child: GestureDetector(
                                                      onTap: () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            title: const Text(
                                                              '강퇴하기',
                                                            ),
                                                            content: const Text(
                                                              '이 참가자를 강퇴하시겠습니까?\n(채팅에서도 내보내집니다)',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                      false,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      '취소',
                                                                    ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                      true,
                                                                    ),
                                                                child: const Text(
                                                                  '강퇴',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirm == true) {
                                                          try {
                                                            await firestoreService
                                                                .kickMeetupParticipant(
                                                                  meetupId,
                                                                  participantId,
                                                                );
                                                            if (context
                                                                .mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    '사용자를 강퇴했습니다.',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            debugPrint(
                                                              '강퇴 실패: $e',
                                                            );
                                                          }
                                                        }
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              2,
                                                            ),
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Colors.red,
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                color: Colors
                                                                    .white,
                                                                width: 2,
                                                              ),
                                                            ),
                                                        child: const Icon(
                                                          Icons.close,
                                                          color: Colors.white,
                                                          size: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              user?.name ?? 'Loading',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isHost
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
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
                        ],

                        if (currentUserId == meetup.host.id &&
                            meetup.pendingParticipantIds.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Pending Requests (참여 요청)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: meetup.pendingParticipantIds.length,
                              itemBuilder: (context, index) {
                                final pendingId =
                                    meetup.pendingParticipantIds[index];

                                return FutureBuilder<app_models.User?>(
                                  future: firestoreService.getUserById(
                                    pendingId,
                                  ),
                                  builder: (context, userSnap) {
                                    final user = userSnap.data;
                                    if (user == null) {
                                      return const SizedBox.shrink();
                                    }

                                    return Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.grey[300],
                                            backgroundImage:
                                                user.avatarUrl.isNotEmpty
                                                ? NetworkImage(user.avatarUrl)
                                                : null,
                                            child: user.avatarUrl.isEmpty
                                                ? const Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                    size: 20,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            user.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              InkWell(
                                                onTap: () => firestoreService
                                                    .acceptMeetupParticipant(
                                                      meetupId,
                                                      pendingId,
                                                    ),
                                                child: const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 24,
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => firestoreService
                                                    .declineMeetupParticipant(
                                                      meetupId,
                                                      pendingId,
                                                    ),
                                                child: const Icon(
                                                  Icons.cancel,
                                                  color: Colors.red,
                                                  size: 24,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      // Like Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: IconButton(
                          icon: Icon(
                            meetup.likedBy.contains(currentUserId)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: meetup.likedBy.contains(currentUserId)
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                          onPressed: () =>
                              firestoreService.toggleLikeMeetup(meetupId),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Comment Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey[600],
                          ),
                          onPressed: () =>
                              _showCommentsModal(context, meetupId),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Join/Leave Button
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (isFull && !isJoined && !isPending)
                                ? null
                                : () async {
                                    final action = isJoined
                                        ? 'Leave'
                                        : (isPending
                                              ? 'Cancel Request to Join'
                                              : 'Join');
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('$action Meetup?'),
                                        content: const Text(
                                          'Are you sure you want to continue?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text(
                                              'Yes',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm != true || !context.mounted) {
                                      return;
                                    }

                                    try {
                                      if (isJoined || isPending) {
                                        if (isJoined) {
                                          await firestoreService.leaveMeetup(
                                            meetupId,
                                          );
                                        } else {
                                          // Cancel Request (Decline self essentially)
                                          await firestoreService
                                              .declineMeetupParticipant(
                                                meetupId,
                                                currentUserId,
                                              );
                                        }
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isJoined
                                                    ? 'You left the meetup.'
                                                    : 'Join request cancelled.',
                                              ),
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        // The modified joinMeetup triggers Exceptions if cooldown active
                                        final success = await firestoreService
                                            .joinMeetup(meetupId);
                                        if (context.mounted && success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Successfully joined!',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        String errorMessage = e.toString();
                                        if (errorMessage.contains(
                                          '1 hour later',
                                        )) {
                                          errorMessage =
                                              'Try join this group 1 hour later.';
                                        } else if (errorMessage.startsWith(
                                          'Exception: ',
                                        )) {
                                          errorMessage = errorMessage
                                              .replaceFirst('Exception: ', '');
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(errorMessage),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isJoined
                                  ? Colors.redAccent
                                  : (isPending
                                        ? Colors.orange
                                        : (isFull
                                              ? Colors.grey[300]
                                              : Colors.blue)),
                              foregroundColor:
                                  (isFull && !isJoined && !isPending)
                                  ? Colors.grey[600]
                                  : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isJoined
                                  ? 'Leave'
                                  : (isPending
                                        ? 'Cancel Request'
                                        : (isFull ? 'Closed' : 'Join Now')),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCommentsModal(BuildContext context, String meetupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MeetupCommentsSheet(meetupId: meetupId),
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
