import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id;
  final String title;
  final String companyName;
  final String location;
  final String salary;
  final String jobType; // Full-time, Part-time, etc.
  final String description;
  final List<String> requirements;
  final String contactInfo;
  final String authorId;
  final DateTime postedDate;
  final DateTime? deadline;
  final bool isActive;

  Job({
    required this.id,
    required this.title,
    required this.companyName,
    required this.location,
    required this.salary,
    this.jobType = 'Full-time',
    required this.description,
    required this.requirements,
    required this.contactInfo,
    required this.authorId,
    required this.postedDate,
    this.deadline,
    this.isActive = true,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      title: data['title'] ?? '',
      companyName: data['companyName'] ?? '',
      location: data['location'] ?? '',
      salary: data['salary'] ?? '',
      jobType: data['jobType'] ?? 'Full-time',
      description: data['description'] ?? '',
      requirements: List<String>.from(data['requirements'] ?? []),
      contactInfo: data['contactInfo'] ?? '',
      authorId: data['authorId'] ?? '',
      postedDate:
          (data['postedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deadline: data['deadline'] != null
          ? (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now()
          : null,
      isActive: data['isActive'] ?? true,
    );
  }
}
