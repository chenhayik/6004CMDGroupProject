import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth_result.dart';
import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // ── Controllers ──
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ── State ──
  bool isLogin = true;           // true = Login mode, false = Register mode
  bool isLoading = false;
  bool obscurePassword = true;
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

  // ── Validators (called by View's Form) ──
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Invalid email format';
    if (value.length > 50) return 'Email is too long';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';

    // Only enforce strength rules during Registration
    if (!isLogin) {
      if (value.length < 6) return 'Password is too short (min 6 characters)';
      if (value.length > 20) return 'Password is too long (max 20 characters)';
    }

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
    }
  }

  // ── Register ──
  Future<AuthResult> register() async {
    _setLoading(true);
    try {
      await _authService.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      _setLoading(false);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      final message = _mapFirebaseError(e.code);
      _setError(message);
      return AuthResult.failure(message);
    }
  }

  // ── Submit — decides sign in or register based on mode ──
  Future<AuthResult> submit() async {
    return isLogin ? await signIn() : await register();
  }

  // ── Maps Firebase error codes to friendly messages ──
  String _mapFirebaseError(String code) {
    debugPrint('Firebase error code: $code'); // ← add this to see exact codes

    switch (code) {
    // ── NEW: Firebase v10+ combines wrong password
    //         and user-not-found into one code ──
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';

    // ── Keep these as fallback for older SDK versions ──
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';

      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';

      default:
        return 'Error: $code'; // ← shows exact code so you can debug
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
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}