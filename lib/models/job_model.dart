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
}
