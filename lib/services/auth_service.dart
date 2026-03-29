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

  // Check if the current user needs to complete onboarding
  // Returns true if the user's Firestore document is missing required fields
  Future<bool> isNewUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return true;
      final data = doc.data();
      if (data == null) return true;
      // A user is considered 'new' if they haven't completed onboarding
      final onboardingComplete = data['onboardingComplete'] as bool? ?? false;
      return !onboardingComplete;
    } catch (_) {
      return false;
    }
  }

  // Save onboarding data to Firestore and mark onboarding as complete
  Future<void> completeOnboarding({
    required String name,
    int? age,
    required String gender,
    String bio = '',
    String instagram = '',
    List<String> interests = const [],
    String? avatarUrl,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final updateData = {
      'name': name,
      'age': age,
      'gender': gender,
      'bio': bio,
      'instagramId': instagram,
      'interests': interests,
      'onboardingComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (avatarUrl != null) {
      updateData['avatarUrl'] = avatarUrl;
    }
    
    await _db.collection('users').doc(uid).set(
      updateData, 
      SetOptions(merge: true)
    );
  }


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

  // Sign In with Nickname
  Future<AuthResult> signInWithNickname({
    required String nickname,
    required String password,
  }) async {
    try {
      // 1. Firestore에서 닉네임으로 사용자 조회
      final query = await _db
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return AuthResult.failure('해당 닉네임의 사용자를 찾을 수 없습니다.');
      }

      final email = query.docs.first.data()['email'] as String?;
      if (email == null || email.isEmpty) {
        return AuthResult.failure('이 계정에 연결된 이메일이 없습니다.');
      }

      // 2. 이메일로 Firebase Auth 로그인
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return AuthResult.success();
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Unknown auth error', e.code);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // Change Password (requires reauthentication)
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult.failure('로그인이 필요합니다.');
      if (user.email == null) return AuthResult.failure('이메일 계정이 아닙니다.');

      // 1. 재인증
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. 비밀번호 업데이트
      await user.updatePassword(newPassword);
      return AuthResult.success();
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return AuthResult.failure('현재 비밀번호가 올바르지 않습니다.');
      }
      return AuthResult.failure(e.message ?? 'Unknown auth error', e.code);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // Check if current user uses email/password provider
  bool get isEmailPasswordUser {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
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

  // Phone Auth: Send OTP
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required VoidCallback onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
        try {
          final result = await _auth.signInWithCredential(credential);
          final user = result.user;
          if (user != null) {
            await _ensurePhoneUserDocument(user);
          }
          onAutoVerified();
        } catch (e) {
          onError(e.toString());
        }
      },
      verificationFailed: (firebase_auth.FirebaseAuthException e) {
        onError(e.message ?? 'Phone verification failed.');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  // Phone Auth: Verify OTP
  Future<AuthResult> signInWithPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user != null) {
        await _ensurePhoneUserDocument(user);
      }
      return AuthResult.success();
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Unknown auth error', e.code);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // Ensure a Firestore user document exists for phone auth users
  Future<void> _ensurePhoneUserDocument(firebase_auth.User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(user.uid).set({
        'id': user.uid,
        'name': user.displayName ?? 'TEMAN User',
        'nickname': '',
        'phoneNumber': user.phoneNumber ?? '',
        'avatarUrl': user.photoURL ??
            'https://ui-avatars.com/api/?name=TEMAN+User&background=1E56C8&color=fff',
        'nationality': 'Other 🌏',
        'email': user.email ?? '',
        'bio': '',
        'role': 'user',
        'age': null,
        'personalInfo': '',
        'interests': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
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
