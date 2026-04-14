import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/algolia_service.dart';
// Models are not explicitly needed in this file anymore
import 'meetup_detail_screen.dart';
import 'job_detail_screen.dart';
import 'marketplace_detail_screen.dart';
import 'post_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // Algolia search results
  List<Map<String, dynamic>> _algoliaPostResults = [];
  List<Map<String, dynamic>> _algoliaMeetupResults = [];
  List<Map<String, dynamic>> _algoliaQnAResults = [];
  List<Map<String, dynamic>> _algoliaJobResults = [];
  List<Map<String, dynamic>> _algoliaMarketplaceResults = [];
  
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _searchController.addListener(() {
      final newQuery = _searchController.text.trim();
      if (newQuery != _query) {
        setState(() {
          _query = newQuery;
        });
        _performAlgoliaSearch(newQuery);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performAlgoliaSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _algoliaPostResults = [];
        _algoliaMeetupResults = [];
        _algoliaQnAResults = [];
        _algoliaJobResults = [];
        _algoliaMarketplaceResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await Future.wait([
        AlgoliaService.searchIndex('posts', query),
        AlgoliaService.searchIndex('meetups', query),
        AlgoliaService.searchIndex('questions', query), // Collection is questions
        AlgoliaService.searchIndex('jobs', query),
        AlgoliaService.searchIndex('marketplace', query),
      ]);

      if (mounted && _query == query) {
        setState(() {
          _algoliaPostResults = results[0];
          _algoliaMeetupResults = results[1];
          _algoliaQnAResults = results[2];
          _algoliaJobResults = results[3];
          _algoliaMarketplaceResults = results[4];
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted && _query == query) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Meetups'),
            Tab(text: 'Q&A'),
            Tab(text: 'Jobs'),
            Tab(text: 'Market'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllResults(firestoreService),
          _buildMeetupResults(firestoreService),
          _buildQnAResults(firestoreService),
          _buildJobResults(firestoreService),
          _buildMarketplaceResults(firestoreService),
          _buildEventResults(firestoreService), // Events are just posts with category='events'

        ],
      ),
    );
  }

  Widget _buildAllResults(FirestoreService service) {
    if (_query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search posts, meetups, jobs & more',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        _sectionHeader('Community Posts', Icons.article_outlined, Colors.teal),
        SizedBox(height: 250, child: _buildAlgoliaPostResults()),
        _sectionHeader('Meetups', Icons.people_outline, Colors.orange),
        SizedBox(height: 200, child: _buildMeetupResults(service)),
        _sectionHeader('Q&A', Icons.help_outline, Colors.blue),
        SizedBox(height: 200, child: _buildQnAResults(service)),
        _sectionHeader('Jobs', Icons.work_outline, Colors.green),
        SizedBox(height: 200, child: _buildJobResults(service)),
        _sectionHeader('Marketplace', Icons.storefront_outlined, Colors.orange),
        SizedBox(height: 200, child: _buildMarketplaceResults(service)),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
        ],
      ),
    );
  }

  /// Algolia-powered post search results
  Widget _buildAlgoliaPostResults() {
    if (_query.isEmpty) {
      return const Center(child: Text('Enter a search term'));
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_algoliaPostResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            const Text('No posts found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _algoliaPostResults.length,
      separatorBuilder: (context, i) => Divider(
        height: 1,
        color: Colors.grey[200],
        indent: 72,
      ),
      itemBuilder: (context, index) {
        final hit = _algoliaPostResults[index];
        final title = hit['title'] ?? '';
        final content = hit['content'] ?? '';
        final category = hit['category'] ?? 'general';
        final objectId = hit['objectID'] ?? '';
        final isAnonymous = hit['isAnonymous'] == true;
        final authorName = isAnonymous
            ? 'Anonymous'
            : (hit['authorName'] ?? 'Unknown');

        // Category styling
        Color catColor;
        String catLabel;
        switch (category) {
          case 'qna':
            catColor = Colors.blue;
            catLabel = 'Q&A';
            break;
          case 'events':
            catColor = Colors.orange;
            catLabel = 'Events';
            break;
          case 'general':
          default:
            catColor = Colors.teal;
            catLabel = 'General';
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                isAnonymous ? '?' : (authorName.isNotEmpty ? authorName[0].toUpperCase() : '?'),
                style: TextStyle(
                  color: catColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          title: Text(
            title.isNotEmpty ? title : content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      catLabel,
                      style: TextStyle(
                        color: catColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    authorName,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () {
            if (objectId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(postId: objectId),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildMeetupResults(FirestoreService service) {
    if (_query.isEmpty) {
      return const Center(child: Text('Enter a search term'));
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_algoliaMeetupResults.isEmpty) {
      return const Center(child: Text('No meetups found'));
    }
    return ListView.builder(
      itemCount: _algoliaMeetupResults.length,
      itemBuilder: (context, index) {
        final hit = _algoliaMeetupResults[index];
        final title = hit['title'] ?? '';
        final location = hit['location'] ?? '';
        final objectId = hit['objectID'] ?? '';

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.people, color: Colors.teal[700], size: 20),
          ),
          title: Text(title.isNotEmpty ? title : 'Untitled Meetup'),
          subtitle: Text(location),
          onTap: () {
            if (objectId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MeetupDetailScreen(meetupId: objectId),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildQnAResults(FirestoreService service) {
    if (_query.isEmpty) {
      return const Center(child: Text('Enter a search term'));
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_algoliaQnAResults.isEmpty) {
      return const Center(child: Text('No questions found'));
    }
    return ListView.builder(
      itemCount: _algoliaQnAResults.length,
      itemBuilder: (context, index) {
        final hit = _algoliaQnAResults[index];
        final title = hit['title'] ?? '';
        final content = hit['content'] ?? '';

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.help_outline,
              color: Colors.blue[700],
              size: 20,
            ),
          ),
          title: Text(title.isNotEmpty ? title : 'Untitled Question'),
          subtitle: Text(content, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }

  Widget _buildJobResults(FirestoreService service) {
    if (_query.isEmpty) {
      return const Center(child: Text('Enter a search term'));
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_algoliaJobResults.isEmpty) {
      return const Center(child: Text('No jobs found'));
    }
    return ListView.builder(
      itemCount: _algoliaJobResults.length,
      itemBuilder: (context, index) {
        final hit = _algoliaJobResults[index];
        final title = hit['title'] ?? '';
        final location = hit['location'] ?? '';
        final objectId = hit['objectID'] ?? '';

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.work_outline,
              color: Colors.green[700],
              size: 20,
            ),
          ),
          title: Text(title.isNotEmpty ? title : 'Untitled Job'),
          subtitle: Text(location),
          onTap: () async {
            if (objectId.isNotEmpty) {
              final job = await service.getJobById(objectId);
              if (job != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobDetailScreen(job: job),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildMarketplaceResults(FirestoreService service) {
    if (_query.isEmpty) {
      return const Center(child: Text('Enter a search term'));
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_algoliaMarketplaceResults.isEmpty) {
      return const Center(child: Text('No items found'));
    }
    return ListView.builder(
      itemCount: _algoliaMarketplaceResults.length,
      itemBuilder: (context, index) {
        final hit = _algoliaMarketplaceResults[index];
        final title = hit['title'] ?? '';
        final price = hit['price']?.toString() ?? '0';
        final objectId = hit['objectID'] ?? '';

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.storefront,
              color: Colors.orange[700],
              size: 20,
            ),
          ),
          title: Text(title.isNotEmpty ? title : 'Untitled Item'),
          subtitle: Text('$price KRW'),
          onTap: () async {
            if (objectId.isNotEmpty) {
              final item = await service.getMarketplaceItemById(objectId);
              if (item != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MarketplaceDetailScreen(item: item),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildEventResults(FirestoreService service) {
    if (_query.isEmpty) {
      return const Center(child: Text('Enter a search term'));
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final events = _algoliaPostResults.where((hit) => hit['category'] == 'events').toList();

    if (events.isEmpty) {
      return const Center(child: Text('No events found'));
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final hit = events[index];
        final title = hit['title'] ?? '';
        final location = hit['location'] ?? 'No location';
        final objectId = hit['objectID'] ?? '';

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.event, color: Colors.purple[700], size: 20),
          ),
          title: Text(title.isNotEmpty ? title : 'Event'),
          subtitle: Text(location),
          onTap: () {
            if (objectId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(postId: objectId),
                ),
              );
            }
          },
        );
      },
    );
  }
}
