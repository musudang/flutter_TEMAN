import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/job_model.dart';
import '../models/user_model.dart' as app_models;
import 'create_job_screen.dart';
import 'job_detail_screen.dart';
import 'package:intl/intl.dart';

class JobsScreen extends StatefulWidget {
  final bool embedded;
  const JobsScreen({super.key, this.embedded = false});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  String _selectedJobType = 'All';
  final List<String> _jobTypes = [
    'All',
    'Full-time',
    'Part-time',
    'Internship',
    'Freelance',
    'Contract',
    'Others',
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Jobs & Info'),
              automaticallyImplyLeading: false,
            ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _jobTypes.map((type) {
                  final isSelected = _selectedJobType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedJobType = type;
                          });
                        }
                      },
                      selectedColor: Colors.teal,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<app_models.User?>(
              stream: firestoreService.currentUserId != null
                  ? firestoreService.getUserStream(firestoreService.currentUserId!)
                  : null,
              builder: (context, userSnap) {
                final hiddenUsers = <String>[
                  ...(userSnap.data?.blockedUsers ?? []),
                  ...(userSnap.data?.blockedBy ?? []),
                ];
                return StreamBuilder<List<Job>>(
                  stream: firestoreService.getJobs(
                    hiddenUsers: hiddenUsers,
                    jobType: _selectedJobType,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.work_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No jobs in this category yet.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    final jobs = snapshot.data!;
                    return ListView.builder(
                      itemCount: jobs.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.business, color: Colors.teal),
                            ),
                            title: Text(
                              job.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      job.companyName,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        job.jobType,
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      job.location,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.attach_money,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      job.salary,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Text(
                              DateFormat('MMM d').format(job.postedDate),
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => JobDetailScreen(job: job),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton(
              heroTag: 'job_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateJobScreen(),
                  ),
                );
              },
              backgroundColor: Colors.teal,
              child: const Icon(Icons.add),
            ),
    );
  }
}
