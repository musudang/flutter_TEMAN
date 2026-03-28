import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user_model.dart' as app_models;
import '../models/auth_result.dart'; // import the new AuthResult and AuthUser

class AuthService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final google_sign_in.GoogleSignIn _googleSignIn = google_sign_in.GoogleSignIn(
    clientId: kIsWeb
        ? '1065473302917-8vfsrl7a5den48k1b3pk26jhk6l3t1rm.apps.googleusercontent.com'
        : null,
  );

  // Convert Firebase User to our unified AuthUser
  AuthUser? _toAuthUser(firebase_auth.User? firebaseUser) {
    if (firebaseUser == null) return null;
    return AuthUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      photoURL: firebaseUser.photoURL,
    );
  }

  // Current User Stream (Abstracted away from Firebase)
  Stream<AuthUser?> get authStateChanges {
    return _auth.authStateChanges().map(_toAuthUser);
  }

  // Get Current User
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  // Sign Up
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
    required String nickname,
    required String nationality,
    int? age,
    String phoneNumber = '',
    String personalInfo = '',
    List<String> interests = const [],
  }) async {
    try {
      // 1. Create User in backend
      final firebase_auth.UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebase_auth.User? user = result.user;
      if (user == null) return AuthResult.failure("Sign up failed: Unknown error");

      // 2. Create User Document Database (Firestore implementation for now)
      final newUser = app_models.User(
        id: user.uid,
        name: name,
        avatarUrl:
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random',
        nickname: nickname,
        phoneNumber: phoneNumber,
        nationality: nationality,
        age: age,
        personalInfo: personalInfo,
        interests: interests,
      );

      await _db.collection('users').doc(user.uid).set({
        'id': newUser.id,
        'name': newUser.name,
        'nickname': newUser.nickname,
        'phoneNumber': newUser.phoneNumber,
        'avatarUrl': newUser.avatarUrl,
        'nationality': newUser.nationality,
        'email': email,
        'bio': '',
        'role': 'user',
        'age': age,
        'personalInfo': personalInfo,
        'interests': interests,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return AuthResult.success();
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Unknown auth error', e.code);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // Sign In
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return AuthResult.success();
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Unknown auth error', e.code);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    // Google 계정 연결도 끊어서 다음 로그인 시 계정 선택 팝업이 뜨도록 함
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Google로 로그인하지 않은 경우 무시
    }
  }

  // Sign In with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      final google_sign_in.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return AuthResult.failure('Google sign in cancelled');

      final google_sign_in.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final firebase_auth.AuthCredential credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final firebase_auth.UserCredential result = await _auth.signInWithCredential(credential);
      final firebase_auth.User? user = result.user;

      if (user != null) {
        // Sync user document with initial info if it doesn't exist
        final doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          final String name = user.displayName ?? 'Google User';
          await _db.collection('users').doc(user.uid).set({
            'id': user.uid,
            'name': name,
            'avatarUrl': user.photoURL ??
                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random',
            'nationality': 'Other 🌏',
            'email': user.email,
            'bio': '',
            'role': 'user',
            'age': null,
            'personalInfo': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return AuthResult.success();
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Unknown auth error', e.code);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // Sign In with Apple
  Future<AuthResult> signInWithApple() async {
    try {
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final firebase_auth.OAuthProvider oAuthProvider = firebase_auth.OAuthProvider('apple.com');
      final firebase_auth.AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final firebase_auth.UserCredential result = await _auth.signInWithCredential(credential);
      final firebase_auth.User? user = result.user;

      if (user != null) {
        // Check if user document exists
        final doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          String name = 'Apple User';
          if (appleCredential.givenName != null || appleCredential.familyName != null) {
            name = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
          } else if (user.displayName != null && user.displayName!.isNotEmpty) {
            name = user.displayName!;
          }

          await _db.collection('users').doc(user.uid).set({
            'id': user.uid,
            'name': name,
            'avatarUrl': 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random',
            'nationality': 'Other 🌏',
            'email': user.email ?? appleCredential.email ?? '',
            'bio': '',
            'role': 'user',
            'age': null,
            'personalInfo': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return AuthResult.success();
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Unknown auth error', e.code);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // Send Password Reset Email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success();
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Unknown auth error', e.code);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }
}
