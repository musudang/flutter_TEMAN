import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user_model.dart' as app_models;

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Current User Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get Current User (Firebase User)
  User? get currentUser => _auth.currentUser;

  // Sign Up
  Future<String?> signUp({
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
      // 1. Create User in Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) return "Sign up failed: Unknown error";

      // 2. Create User Document in Firestore
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

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign In
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Sign In with Google
  Future<String?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return "Google sign in cancelled";

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: null,
        idToken: googleAuth.idToken,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);
      final User? user = result.user;

      if (user != null) {
        // Check if user document exists
        final doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          final String name = user.displayName ?? 'Google User';
          // Create user doc for the first time
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

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign In with Apple
  Future<String?> signInWithApple() async {
    try {
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);
      final User? user = result.user;

      if (user != null) {
        // Check if user document exists
        final doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          String name = 'Apple User';
          if (appleCredential.givenName != null ||
              appleCredential.familyName != null) {
            name =
                '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                    .trim();
          } else if (user.displayName != null &&
              user.displayName!.isNotEmpty) {
            name = user.displayName!;
          }

          // Create user doc for the first time
          await _db.collection('users').doc(user.uid).set({
            'id': user.uid,
            'name': name,
            'avatarUrl':
                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random',
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

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Send Password Reset Email
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}
