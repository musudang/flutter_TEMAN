class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
  });
}

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? errorCode;

  /// Set to true when the account has been soft-deleted but is still within
  /// the 14-day grace period and can be recovered by the user.
  final bool isDeletedAccount;

  /// Metadata for deleted accounts (only populated when [isDeletedAccount] is true).
  final DateTime? deletedAt;
  final DateTime? scheduledPermanentDeleteAt;
  final String? deletedUid;
  final String? deletedEmail;
  final String? deletedPassword;

  const AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.errorCode,
    this.isDeletedAccount = false,
    this.deletedAt,
    this.scheduledPermanentDeleteAt,
    this.deletedUid,
    this.deletedEmail,
    this.deletedPassword,
  });

  factory AuthResult.success() {
    return const AuthResult._(isSuccess: true);
  }

  factory AuthResult.failure(String message, [String? code]) {
    return AuthResult._(
      isSuccess: false,
      errorMessage: message,
      errorCode: code,
    );
  }

  /// Returned when a deleted account logs in during the 14-day grace period.
  factory AuthResult.deletedAccount({
    required DateTime deletedAt,
    required DateTime scheduledPermanentDeleteAt,
    required String uid,
    required String email,
    required String password,
  }) {
    return AuthResult._(
      isSuccess: false,
      isDeletedAccount: true,
      deletedAt: deletedAt,
      scheduledPermanentDeleteAt: scheduledPermanentDeleteAt,
      deletedUid: uid,
      deletedEmail: email,
      deletedPassword: password,
    );
  }
}
