// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings, unnecessary_brace_in_string_interps, unused_local_variable, unnecessary_non_null_assertion

import 'dart:io';

void main() async {
  final file = File(
    'c:/Users/user/OneDrive/Desktop/TEMAN FLUTTER TRIAL/teman_flutter_app_code/lib/services/firestore_service.dart',
  );
  final content = await file.readAsString();

  final lines = content.split('\n');

  // Extract imports
  final imports = <String>[];
  var i = 0;
  for (; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('import ')) {
      imports.add(line);
    } else if (line.contains('class FirestoreService')) {
      break;
    }
  }

  // Extract the top level variables for Mixins to use
  final variables = '''
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? get currentUserId => _auth.currentUser?.uid;
''';

  // Find categories
  final mixinNames = <String>[];
  final categoryPattern = RegExp(
    r'// ===================== (.*?) =====================',
  );

  String? currentCategory;
  List<String> currentCategoryLines = [];

  final outDir = Directory(
    'c:/Users/user/OneDrive/Desktop/TEMAN FLUTTER TRIAL/teman_flutter_app_code/lib/services/mixins',
  );
  outDir.createSync(recursive: true);

  final categoryToFileName = {
    'USER': 'user_service',
    'MEETUPS': 'meetup_service',
    'MEETUP LIKES & COMMENTS': 'meetup_service', // Merge these
    'POSTS': 'post_service',
    'COMMENTS': 'post_service', // Merge comments into post_service
    'JOBS': 'job_service',
    'MARKETPLACE': 'marketplace_service',
    'QNA': 'qna_service',
    'CONVERSATIONS': 'chat_service',
    'NOTIFICATIONS': 'notification_service',
    'REPORTS': 'report_service',
    'VOTING & POLLS': 'post_service', // example
    'RESET DATA': 'dev_service',
    'SEARCH': 'search_service',
  };

  Map<String, List<String>> fileContents = {};

  for (var line in lines) {
    var match = categoryPattern.firstMatch(line);
    if (match != null) {
      currentCategory = match.group(1)!.trim();
      continue;
    }

    if (currentCategory != null) {
      // Find which file it belongs to
      String fileName = 'misc_service';
      for (final kv in categoryToFileName.entries) {
        if (currentCategory!.startsWith(kv.key)) {
          fileName = kv.value;
          break;
        }
      }

      fileContents.putIfAbsent(fileName, () => []);
      if (line.trim() != '}' ||
          currentCategoryLines.length < lines.length - 10) {
        // Avoid pulling the last brace
        fileContents[fileName]!.add(line);
      }
    }
  }

  // Clean up the trailing brace from the last category
  if (fileContents.isNotEmpty) {
    final lastKey = fileContents.keys.last;
    final lst = fileContents[lastKey]!;
    if (lst.isNotEmpty && lst.last.trim() == '}') {
      lst.removeLast();
    }
    // Might need to remove one more empty line or brace
    while (lst.isNotEmpty &&
        (lst.last.trim() == '}' || lst.last.trim() == '')) {
      lst.removeLast();
    }
  }

  // Write mixin files
  for (final entry in fileContents.entries) {
    final fileName = entry.key;
    final lines = entry.value;

    // Create mixin name: user_service -> UserService
    final mixinName = fileName
        .split('_')
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join('');
    mixinNames.add(mixinName);

    final mixinContent =
        '''
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/meetup_model.dart';
import '../../models/user_model.dart' as app_models;
import '../../models/post_model.dart';
import '../../models/question_model.dart';
import '../../models/answer_model.dart';
import '../../models/message_model.dart';
import '../../models/job_model.dart';
import '../../models/marketplace_model.dart';
import '../../models/conversation_model.dart';
import '../../models/notification_model.dart';
import '../../models/comment_model.dart';
import '../../constants/app_constants.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

// Since mixins might call methods from each other (e.g. UserService calling sendNotification),
// they need a common base interface. But for simplicity and to avoid cyclic dependencies, 
// Dart allows calling unresolved methods if typed as dynamic or if we just bundle them properly.
// Wait, actually, in Flutter, if a mixin calls another mixin's method, you can use `on` or just not 
// care if there's no static analyzer error? No, Dart statically checks.
// Since we are moving fast, we can declare `var _db` inline. Actually, `FirestoreService` will have them.
// Let's make the mixins independent. If they need to call each other, we can use an abstract base or late fields.
// For now, let's just create them. We will fix unresolved calls manually.

mixin \$mixinName on ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseFirestore.instance.app == null ? FirebaseAuth.instance : FirebaseAuth.instance; // dummy

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

''' +
        lines.join('\n') +
        '''
}
''';

    final outPath = '${outDir.path}/${fileName}.dart';
    File(outPath).createSync(recursive: true);
    await File(outPath).writeAsString(mixinContent);
    print('Created $outPath');
  }

  // Write the new firestore_service.dart
  final newServiceImports = fileContents.keys
      .map((k) => "import 'mixins/${k}.dart';")
      .join('\n');
  final mixinsList = mixinNames.join(', ');

  final newFirestoreService =
      '''
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
$newServiceImports

class FirestoreService extends ChangeNotifier with $mixinsList {
  // All functionality has been split into mixins for better maintainability
}
  ''';

  await File(
    'c:/Users/user/OneDrive/Desktop/TEMAN FLUTTER TRIAL/teman_flutter_app_code/lib/services/firestore_service_new.dart',
  ).writeAsString(newFirestoreService);
  print('Reconstructed FirestoreService in firestore_service_new.dart');
}
