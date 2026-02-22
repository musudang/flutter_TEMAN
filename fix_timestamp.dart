import 'dart:io';

void main() async {
  final file = File('lib/services/firestore_service.dart');
  String content = await file.readAsString();

  final regex = RegExp(r"\((data\['[^']+'])\s+as\s+Timestamp\)\.toDate\(\)");
  final newContent = content.replaceAllMapped(regex, (match) {
    return "(${match.group(1)} as Timestamp?)?.toDate() ?? DateTime.now()";
  });

  if (content != newContent) {
    await file.writeAsString(newContent);
    print("Fixed firestore_service.dart");
  } else {
    print("No matches found.");
  }
}
