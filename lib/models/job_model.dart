class Job {
  final String id;
  final String title;
  final String companyName;
  final String location;
  final String salary;
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
    required this.description,
    required this.requirements,
    required this.contactInfo,
    required this.authorId,
    required this.postedDate,
    this.deadline,
    this.isActive = true,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      companyName: json['companyName'] ?? '',
      location: json['location'] ?? '',
      salary: json['salary'] ?? '',
      description: json['description'] ?? '',
      requirements: List<String>.from(json['requirements'] ?? []),
      contactInfo: json['contactInfo'] ?? '',
      authorId: json['authorId']?.toString() ?? '',
      postedDate: json['postedDate'] != null
          ? DateTime.parse(json['postedDate'])
          : DateTime.now(),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'companyName': companyName,
      'location': location,
      'salary': salary,
      'description': description,
      'requirements': requirements,
      'contactInfo': contactInfo,
      'authorId': authorId,
      'postedDate': postedDate.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'isActive': isActive,
    };
  }
}
