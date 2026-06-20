import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

const Color _kGreen = Color(0xFF22C55E);
const Color _kTitle = Color(0xFF0F172A);

/// Shown when a signed-in user hasn't verified their email yet. Blocks access
/// to the rest of the app until verification completes. [onVerified] should
/// rebuild the auth gate so it can advance the user.
class VerifyEmailView extends StatefulWidget {
  final VoidCallback onVerified;
  const VerifyEmailView({super.key, required this.onVerified});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  final AuthService _authService = AuthService();

  bool _sending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _pollTimer;

  String get _email => FirebaseAuth.instance.currentUser?.email ?? 'your email';

  @override
  void initState() {
    super.initState();
    // Send the first verification email automatically when this screen appears.
    _sendEmail();
    // Quietly poll so the screen advances on its own once the user verifies.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkVerified(silent: true),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (_sending || _resendCooldown > 0) return;
    setState(() => _sending = true);
    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _resendCooldown = 60;
      });
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _resendCooldown--);
        if (_resendCooldown <= 0) t.cancel();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  Future<void> _checkVerified({bool silent = false}) async {
    final verified = await _authService.refreshEmailVerified();
    if (!mounted) return;
    if (verified) {
      _pollTimer?.cancel();
      widget.onVerified();
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not verified yet — check your inbox.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: _kGreen, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _kTitle,
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                      fontSize: 15, color: Colors.black54, height: 1.4),
                  children: [
                    const TextSpan(text: 'We sent a verification link to '),
                    TextSpan(
                      text: _email,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const TextSpan(
                      text: '. Open it, then come back — this screen will '
                          'continue automatically.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => _checkVerified(),
                  child: const Text(
                    "I've verified",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTitle,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: (_sending || _resendCooldown > 0) ? null : _sendEmail,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend email (${_resendCooldown}s)'
                        : 'Resend email',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _authService.signOut(),
                style: TextButton.styleFrom(foregroundColor: Colors.black54),
                child: const Text('Use a different account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
