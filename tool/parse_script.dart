import 'dart:io';

void main() async {
  final file = File('c:/Users/user/OneDrive/Desktop/TEMAN FLUTTER TRIAL/teman_flutter_app_code/lib/services/firestore_service.dart');
  final content = await file.readAsString();
  
  final regex = RegExp(r'// ===================== (.*?) =====================');
  final matches = regex.allMatches(content);
  
  for (final match in matches) {
    print('Category: ${match.group(1)}');
  }
}
