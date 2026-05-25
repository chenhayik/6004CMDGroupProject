class AuthResult {
  final bool isSuccess;
  final String? errorMessage;

  const AuthResult.success()
      : isSuccess = true,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage) : isSuccess = false;
}
