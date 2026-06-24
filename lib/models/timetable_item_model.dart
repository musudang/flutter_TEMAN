class TimetableItem {
  final String id;
  final String name;
  final String location;
  final String notes;
  final List<int> daysOfWeek; // 1 = Mon, 2 = Tue, 3 = Wed, 4 = Thu, 5 = Fri, 6 = Sat, 7 = Sun
  final String startTime; // "HH:mm" (24h format, e.g. "09:00")
  final String endTime; // "HH:mm" (24h format, e.g. "10:15")
  final String colorHex; // Hex color string, e.g. "#3F51B5"

  TimetableItem({
    required this.id,
    required this.name,
    required this.location,
    this.notes = '',
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    this.colorHex = '#3F51B5',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'notes': notes,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'colorHex': colorHex,
    };
  }

  factory TimetableItem.fromMap(Map<String, dynamic> map, String id) {
    List<int> parsedDays = [];
    if (map['daysOfWeek'] != null) {
      parsedDays = List<int>.from(map['daysOfWeek']);
    } else if (map['dayOfWeek'] != null) {
      parsedDays = [map['dayOfWeek'] as int];
    } else {
      parsedDays = [1];
    }

    return TimetableItem(
      id: map['id'] ?? id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      notes: map['notes'] ?? '',
      daysOfWeek: parsedDays,
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '10:00',
      colorHex: map['colorHex'] ?? '#3F51B5',
    );
  }
}
