import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth_result.dart';
import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // ── Controllers ──
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // ── State ──
  bool isLogin = true;           // true = Login mode, false = Register mode
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  String? errorMessage;

  // ── Toggle between Login and Register ──
  void toggleMode() {
    isLogin = !isLogin;
    errorMessage = null;         // clear error when switching modes
    notifyListeners();
  }

  // ── Toggle password visibility ──
  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword = !obscureConfirmPassword;
    notifyListeners();
  }

  // ── Validators (called by View's Form) ──
  String? validateName(String? value) {
    if (isLogin) return null; // not shown during login
    if (value == null || value.trim().isEmpty) return 'Please enter your name';
    if (value.trim().length < 2) return 'Name is too short';
    if (value.trim().length > 50) return 'Name is too long';
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your email';
    final email = value.trim();
    final emailRegex = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) return 'Invalid email format';
    if (email.length > 254) return 'Email is too long';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';

    // Only enforce strength rules during Registration.
    // (Existing accounts may have older/weaker passwords.)
    if (!isLogin) {
      if (value.length < 8) {
        return 'Password must be at least 8 characters';
      }
      if (value.length > 64) {
        return 'Password is too long (max 64 characters)';
      }
      if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
        return 'Password must contain at least one letter';
      }
      if (!RegExp(r'\d').hasMatch(value)) {
        return 'Password must contain at least one number';
      }
    }

    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (isLogin) return null; // not shown during login
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ── Sign In ──
  Future<AuthResult> signIn() async {
    _setLoading(true);
    try {
      await _authService.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      _setLoading(false);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      final message = _mapFirebaseError(e.code);
      _setError(message);
      return AuthResult.failure(message);
    } catch (e) {
      debugPrint('signIn non-Firebase error: $e');
      const message = 'Something went wrong. Please try again.';
      _setError(message);
      return const AuthResult.failure(message);
    }
  }

  // ── Register ──
  Future<AuthResult> register() async {
    _setLoading(true);
    try {
      await _authService.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
        displayName: nameController.text.trim(),
      );
      // Best-effort verification email — no longer required to use the app,
      // so a failure here must not fail an otherwise-successful registration.
      try {
        await _authService.sendEmailVerification();
      } catch (e) {
        debugPrint('sendEmailVerification failed (non-fatal): $e');
      }
      _setLoading(false);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      final message = _mapFirebaseError(e.code);
      _setError(message);
      return AuthResult.failure(message);
    } catch (e) {
      debugPrint('register non-Firebase error: $e');
      const message = 'Something went wrong. Please try again.';
      _setError(message);
      return const AuthResult.failure(message);
    }
  }

  // ── Submit — decides sign in or register based on mode ──
  Future<AuthResult> submit() async {
    return isLogin ? await signIn() : await register();
  }

  // ── Google Sign-In / Registration ──
  // One flow handles both: Firebase creates the account on first sign-in.
  Future<AuthResult> signInWithGoogle() async {
    _setLoading(true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // User dismissed the Google account picker — not an error.
        isLoading = false;
        notifyListeners();
        return const AuthResult.failure('cancelled');
      }
      _setLoading(false);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      final message = _mapFirebaseError(e.code);
      _setError(message);
      return AuthResult.failure(message);
    } catch (e) {
      debugPrint('signInWithGoogle error: $e');
      const message = 'Google sign-in failed. Please try again.';
      _setError(message);
      return const AuthResult.failure(message);
    }
  }

  // ── Forgot password — sends a reset link ──
  Future<AuthResult> sendPasswordReset() async {
    final emailError = validateEmail(emailController.text);
    if (emailError != null) {
      _setError('Enter your email above first, then tap "Forgot password".');
      return const AuthResult.failure('invalid-email');
    }
    _setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      _setLoading(false);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      // Map but stay generic so we don't reveal whether the email exists.
      _mapFirebaseError(e.code);
      _setLoading(false);
      // Always report success to avoid account-enumeration via this endpoint.
      return const AuthResult.success();
    } catch (_) {
      _setLoading(false);
      return const AuthResult.success();
    }
  }

  // ── Maps Firebase error codes to friendly, non-revealing messages ──
  String _mapFirebaseError(String code) {
    debugPrint('FirebaseAuthException code: $code'); // diagnostic
    switch (code) {
    // Firebase v10+ combines wrong-password and user-not-found into one
    // code on sign-in, which also avoids leaking whether an account exists.
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password. Please try again.';

      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Email sign-in is currently unavailable.';

      case 'configuration-not-found':
      case 'api-key-not-valid':
        return 'Auth is not configured for this app. '
            'Enable Email/Password in the Firebase console.';

      default:
      // Surface the raw code while diagnosing the sign-in failure.
      // TODO: revert to a generic message once auth is confirmed working.
        return 'Sign-in error: $code';
    }
  }

  // ── Private helpers ──
  void _setLoading(bool value) {
    isLoading = value;
    errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    isLoading = false;
    errorMessage = message;
    notifyListeners();
  }

  // ── Cleanup ──
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
