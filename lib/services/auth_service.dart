import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
    required String nationality,
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
        nationality: nationality,
      );

      await _db.collection('users').doc(user.uid).set({
        'id': newUser.id,
        'name': newUser.name,
        'avatarUrl': newUser.avatarUrl,
        'nationality': newUser.nationality,
        'email': email,
        'bio': '',
        'role': 'user',
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
}
