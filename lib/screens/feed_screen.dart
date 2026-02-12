import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';
import '../models/meetup_model.dart';
import '../models/question_model.dart';
import 'create_post_screen.dart';
import 'conversation_list_screen.dart';
import 'search_screen.dart';
import 'meetup_detail_screen.dart';
import '../widgets/meetup_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Teman Korea',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Color(0xFF1A1F36), // Darker text
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF1A1F36),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'All',
                    isSelected: _selectedFilter == 'All',
                    color: const Color(0xFFFF5A5F),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Meetups',
                    label: 'Meetups',
                    icon: Icons.people_outline,
                    isSelected: _selectedFilter == 'Meetups',
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Q&A',
                    label: 'Q&A',
                    icon: Icons.help_outline,
                    isSelected: _selectedFilter == 'Q&A',
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Events',
                    label: 'Events',
                    icon: Icons.calendar_today_outlined,
                    isSelected: _selectedFilter == 'Events',
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),

          // Dynamic Feed
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: firestoreService.getFeed(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? [];

                // Filter items based on selection
                final filteredItems = items.where((item) {
                  if (_selectedFilter == 'All') return true;
                  if (_selectedFilter == 'Meetups' && item is Meetup)
                    return true;
                  if (_selectedFilter == 'Q&A' && item is Question) return true;
                  // TODO: Handle Events specific filtering if/when Events model exists
                  return false;
                }).toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.feed_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No posts yet',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    if (item is Post) {
                      return _buildPostItem(item);
                    } else if (item is Meetup) {
                      return MeetupCard(
                        meetup: item,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MeetupDetailScreen(meetupId: item.id),
                            ),
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'post_fab', // Unique tag
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildFilterChip(
    String value, {
    String? label,
    IconData? icon,
    required bool isSelected,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label ?? value,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostItem(Post post) {
    // Determine category based on content (mock logic for visual alignment)
    String category = 'Jobs & Market';
    Color categoryColor = const Color(0xFFE8F5E9);
    Color categoryTextColor = const Color(0xFF2E7D32);

    if (post.content.toLowerCase().contains('festival') ||
        post.content.toLowerCase().contains('event')) {
      category = 'Events';
      categoryColor = const Color(0xFFFFF3E0);
      categoryTextColor = const Color(0xFFEF6C00);
    } else if (post.content.toLowerCase().contains('?')) {
      category = 'Q&A';
      categoryColor = const Color(0xFFE3F2FD);
      categoryTextColor = const Color(0xFF1565C0);
    }

    // Relative Time
    final now = DateTime.now();
    final difference = now.difference(post.timestamp);
    String timeAgo = '';
    if (difference.inDays > 0) {
      timeAgo = '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      timeAgo = '${difference.inMinutes}m ago';
    } else {
      timeAgo = 'Just now';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.teal[50],
                child: Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Colors.teal[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: categoryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeAgo,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            // Extract a "Title" from the first line or few words for bold styling if desired,
            // but for now just showing content.
            // Reference has a bold title line.
            _getPostTitle(post.content),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInteractionButton(Icons.favorite_border, '${post.likes}'),
              const SizedBox(width: 16),
              _buildInteractionButton(
                Icons.chat_bubble_outline,
                '${post.comments}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPostTitle(String content) {
    // Simple heuristic: First sentence or first 40 chars
    int dotIndex = content.indexOf('.');
    if (dotIndex != -1 && dotIndex < 50) {
      return content.substring(0, dotIndex).trim();
    }
    return content.length > 40 ? '${content.substring(0, 40)}...' : content;
  }

  Widget _buildInteractionButton(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
