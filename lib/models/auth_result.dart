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

  const AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.errorCode,
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
}
