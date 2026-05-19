import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/phone_verification_dialog.dart';
import '../screens/phone_auth_screen.dart';

/// Checks whether the current user has a verified phone number.
/// If not, shows the JIT [PhoneVerificationDialog].
///
/// Returns `true` if the user is already verified or just completed
/// verification. Returns `false` if the user declined or cancelled.
///
/// Usage:
/// ```dart
/// if (!await checkPhoneVerification(context)) return;
/// // proceed with the protected action
/// ```
Future<bool> checkPhoneVerification(
  BuildContext context, {
  String? title,
  String? description,
}) async {
  debugPrint('[VERIFY_DEBUG] checkPhoneVerification called');
  try {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    debugPrint('[VERIFY_DEBUG] currentUser uid=${firebaseUser?.uid}');
    final providers = firebaseUser?.providerData.map((p) => p.providerId).toList();
    debugPrint('[VERIFY_DEBUG] providers=$providers');
    final hasPhoneProvider = firebaseUser?.providerData
        .any((info) => info.providerId == 'phone') ?? false;

    debugPrint('[VERIFY_DEBUG] hasPhoneProvider=$hasPhoneProvider');
    if (hasPhoneProvider) {
      return true;
    }
  } catch (e) {
    debugPrint('[VERIFY_DEBUG] error checking provider: $e');
  }

  if (!context.mounted) {
    debugPrint('[VERIFY_DEBUG] context not mounted, returning false');
    return false;
  }

  debugPrint('[VERIFY_DEBUG] showing PhoneVerificationDialog...');
  final shouldVerify = await PhoneVerificationDialog.show(
    context,
    title: title ?? 'Phone Verification Required',
    description: description,
  );

  if (shouldVerify != true || !context.mounted) return false;

  // Navigate to PhoneAuthScreen in "link" mode
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const PhoneAuthScreen(linkMode: true),
    ),
  );

  if (result == true) {
    // Force-refresh the ID token so Firestore security rules see the
    // updated phone_number claim immediately. Without this the stale
    // token still has phone_number=null and writes guarded by
    // isPhoneVerified() get permission-denied.
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      debugPrint('[VERIFY_DEBUG] ID token force-refreshed after phone link');
    } catch (e) {
      debugPrint('[VERIFY_DEBUG] token refresh error (non-fatal): $e');
    }
    return true;
  }

  return false;
}
