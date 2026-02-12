import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/meetup_model.dart';
import '../models/job_model.dart';
import '../models/marketplace_model.dart';
import '../models/post_model.dart';
import 'meetup_detail_screen.dart';
import 'job_detail_screen.dart';
import 'marketplace_detail_screen.dart';
// import 'post_detail_screen.dart'; // Assuming we might have this or Feed covers it

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Community'),
            Tab(text: 'Meetups'),
            Tab(text: 'Jobs'),
            Tab(text: 'Market'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostResults(firestoreService),
          _buildMeetupResults(firestoreService),
          _buildJobResults(firestoreService),
          _buildMarketplaceResults(firestoreService),
        ],
      ),
    );
  }

  Widget _buildPostResults(FirestoreService service) {
    if (_query.isEmpty) return const Center(child: Text('Enter a search term'));
    return StreamBuilder<List<Post>>(
      stream: service.searchPosts(_query),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty)
          return const Center(child: Text('No posts found'));
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final post = snapshot.data![index];
            return ListTile(
              title: Text(post.title),
              subtitle: Text(
                post.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMeetupResults(FirestoreService service) {
    if (_query.isEmpty) return const Center(child: Text('Enter a search term'));
    return StreamBuilder<List<Meetup>>(
      stream: service.searchMeetups(_query),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty)
          return const Center(child: Text('No meetups found'));
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final meetup = snapshot.data![index];
            return ListTile(
              title: Text(meetup.title),
              subtitle: Text(meetup.location),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MeetupDetailScreen(meetupId: meetup.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildJobResults(FirestoreService service) {
    if (_query.isEmpty) return const Center(child: Text('Enter a search term'));
    return StreamBuilder<List<Job>>(
      stream: service.searchJobs(_query),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty)
          return const Center(child: Text('No jobs found'));
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final job = snapshot.data![index];
            return ListTile(
              title: Text(job.title),
              subtitle: Text(job.companyName),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMarketplaceResults(FirestoreService service) {
    if (_query.isEmpty) return const Center(child: Text('Enter a search term'));
    return StreamBuilder<List<MarketplaceItem>>(
      stream: service.searchMarketplace(_query),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty)
          return const Center(child: Text('No items found'));
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final item = snapshot.data![index];
            return ListTile(
              title: Text(item.title),
              subtitle: Text('${item.price} KRW'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MarketplaceDetailScreen(item: item),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
