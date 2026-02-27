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
    // ignore: avoid_print
    print("Fixed firestore_service.dart");
  } else {
    // ignore: avoid_print
    print("No matches found.");
  }
}
