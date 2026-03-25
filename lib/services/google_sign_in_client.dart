import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Centralized Google Sign-In setup to ensure initialize() is called exactly once.
// The plugin (v7+) requires a single initialization before any authenticate() calls.
const String googleClientId =
    '337312382711-thg5gok1qnhn9f6k1q6ru1bcktrnamkv.apps.googleusercontent.com';

bool _initialized = false;

Future<void> ensureGoogleSignInInitialized() async {
  if (_initialized) return;
  try {
    if (kIsWeb) {
      // Web 플러그인은 serverClientId 전달을 지원하지 않는다.
      await GoogleSignIn.instance.initialize(
        clientId: googleClientId,
      );
    } else {
      await GoogleSignIn.instance.initialize(
        clientId: googleClientId,
        serverClientId: googleClientId,
      );
    }
  } catch (e, st) {
    debugPrint('GoogleSignIn init failed: $e\n$st');
    // Web throws StateError: "init() has already been called" if some other
    // part (or previous hot restart) already initialized the singleton.
    if (e.toString().contains('init() has already been called')) {
      _initialized = true;
      return;
    }
    rethrow;
  }
  _initialized = true;
}

GoogleSignIn get googleSignIn => GoogleSignIn.instance;
