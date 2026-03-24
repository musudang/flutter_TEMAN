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
      return _getKoreanErrorMessage(e);
    } catch (e) {
      return '알 수 없는 오류가 발생했습니다.';
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
      return _getKoreanErrorMessage(e);
    } catch (e) {
      return '알 수 없는 오류가 발생했습니다.';
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
      final googleUser = await GoogleSignIn.instance.authenticate();

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
      return _getKoreanErrorMessage(e);
    } catch (e) {
      return '알 수 없는 오류가 발생했습니다.';
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
      return _getKoreanErrorMessage(e);
    } catch (e) {
      return '알 수 없는 오류가 발생했습니다.';
    }
  }

  // Send Password Reset Email
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _getKoreanErrorMessage(e);
    } catch (e) {
      return '알 수 없는 오류가 발생했습니다.';
    }
  }

  String _getKoreanErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '가입되지 않은 이메일이거나 사용자 정보가 없습니다.';
      case 'wrong-password':
        return '비밀번호가 틀렸습니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'user-disabled':
        return '정지된 계정입니다. 관리자에게 문의하세요.';
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다.';
      case 'weak-password':
        return '비밀번호는 6자리 이상이어야 합니다.';
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'operation-not-allowed':
        return '이 로그인 방식이 비활성화되어 있습니다.';
      case 'too-many-requests':
        return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
      default:
        return '로그인 오류가 발생했습니다: ${e.message}';
    }
  }
}
