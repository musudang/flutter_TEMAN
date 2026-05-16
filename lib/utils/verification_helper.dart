import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../widgets/phone_verification_dialog.dart';
import '../screens/phone_auth_screen.dart';
import 'package:provider/provider.dart';

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
  final firestoreService =
      Provider.of<FirestoreService>(context, listen: false);
  final currentUser = await firestoreService.getCurrentUser();

  // Already verified — let them through immediately.
  if (currentUser != null && currentUser.isPhoneVerified) {
    return true;
  }

  if (!context.mounted) return false;

  // Show the JIT dialog
  final shouldVerify = await PhoneVerificationDialog.show(
    context,
    title: title,
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

  // result == true means verification completed successfully
  return result == true;
}
