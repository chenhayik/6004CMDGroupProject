import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/login_viewmodel.dart';

// ── Shared palette ──
const Color _kGreen = Color(0xFF22C55E);
const Color _kGreenDark = Color(0xFF15803D);
const Color _kBorder = Color(0xFFE2E8F0);
const Color _kLabel = Color(0xFF334155);
const Color _kTitle = Color(0xFF0F172A);
const Color _kIcon = Color(0xFF94A3B8);

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: const _LoginContent(),
    );
  }
}

class _LoginContent extends StatelessWidget {
  const _LoginContent();

  // Form key stays in View — it's a UI concern
  static final _formKey = GlobalKey<FormState>();

  // ── Brand wordmark ──
  Widget _buildBrand() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.monitor_heart_rounded, color: _kGreen, size: 26),
        SizedBox(width: 6),
        Text(
          'NutriFit',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _kGreen,
          ),
        ),
      ],
    );
  }

  // ── Reusable label wrapper ──
  Widget _buildLabeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kLabel,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  // ── Reusable input decoration ──
  InputDecoration _sharedDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kBorder, width: 1.5),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFB0B8C4)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      enabledBorder: outlineBorder,
      focusedBorder: outlineBorder.copyWith(
        borderSide: const BorderSide(color: _kGreen, width: 2),
      ),
      errorBorder: outlineBorder.copyWith(
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: outlineBorder.copyWith(
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  // ── Name field (register only) ──
  Widget _buildNameField(LoginViewModel vm) {
    return _buildLabeledField(
      'Name',
      TextFormField(
        controller: vm.nameController,
        keyboardType: TextInputType.name,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        decoration: _sharedDecoration(
          hintText: 'Alex Doe',
          prefixIcon: const Icon(Icons.person_outline, color: _kIcon),
        ),
        validator: vm.validateName,
      ),
    );
  }

  // ── Email field ──
  Widget _buildEmailField(LoginViewModel vm) {
    return _buildLabeledField(
      'Email',
      TextFormField(
        controller: vm.emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.email],
        decoration: _sharedDecoration(
          hintText: 'alex@example.com',
          prefixIcon: const Icon(Icons.mail_outline, color: _kIcon),
        ),
        validator: vm.validateEmail,
      ),
    );
  }

  // ── Password field ──
  Widget _buildPasswordField(LoginViewModel vm) {
    return _buildLabeledField(
      'Password',
      TextFormField(
        controller: vm.passwordController,
        obscureText: vm.obscurePassword,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction:
            vm.isLogin ? TextInputAction.done : TextInputAction.next,
        autofillHints: [
          vm.isLogin ? AutofillHints.password : AutofillHints.newPassword,
        ],
        decoration: _sharedDecoration(
          hintText: vm.isLogin ? 'Your password' : 'At least 8 characters',
          prefixIcon: const Icon(Icons.lock_outline, color: _kIcon),
          suffixIcon: IconButton(
            icon: Icon(
              vm.obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _kIcon,
            ),
            onPressed: vm.togglePasswordVisibility,
          ),
        ),
        validator: vm.validatePassword,
      ),
    );
  }

  // ── Confirm password field (register only) ──
  Widget _buildConfirmPasswordField(LoginViewModel vm) {
    return _buildLabeledField(
      'Confirm Password',
      TextFormField(
        controller: vm.confirmPasswordController,
        obscureText: vm.obscureConfirmPassword,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.newPassword],
        decoration: _sharedDecoration(
          hintText: 'Re-enter your password',
          prefixIcon: const Icon(Icons.lock_reset_outlined, color: _kIcon),
          suffixIcon: IconButton(
            icon: Icon(
              vm.obscureConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _kIcon,
            ),
            onPressed: vm.toggleConfirmPasswordVisibility,
          ),
        ),
        validator: vm.validateConfirmPassword,
      ),
    );
  }

  // ── Error message ──
  Widget _buildErrorMessage(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Forgot password (login only) ──
  Widget _buildForgotPassword(BuildContext context, LoginViewModel vm) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: vm.isLoading
            ? null
            : () async {
                final result = await vm.sendPasswordReset();
                if (result.isSuccess && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'If an account exists for that email, '
                        'a reset link has been sent.',
                      ),
                    ),
                  );
                }
              },
        style: TextButton.styleFrom(foregroundColor: _kGreen),
        child: const Text('Forgot password?'),
      ),
    );
  }

  // ── Submit button (gradient pill, matches mockup) ──
  Widget _buildSubmitButton(BuildContext context, LoginViewModel vm) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGreen, _kGreenDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: vm.isLoading
              ? null
              : () async {
                  FocusScope.of(context).unfocus();
                  if (_formKey.currentState!.validate()) {
                    final result = await vm.submit();
                    if (!vm.isLogin && result.isSuccess && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Account created! You're all set."),
                        ),
                      );
                    }
                  }
                },
          child: Center(
            child: vm.isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vm.isLogin ? 'Login' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── "or" divider ──
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: Colors.black38, fontSize: 13)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  // ── Continue with Google ──
  Widget _buildGoogleButton(BuildContext context, LoginViewModel vm) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _kTitle,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: vm.isLoading
            ? null
            : () async {
                FocusScope.of(context).unfocus();
                await vm.signInWithGoogle();
                // On success the auth stream advances the app automatically;
                // errors are surfaced via vm.errorMessage.
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" mark
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4285F4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              vm.isLogin ? 'Continue with Google' : 'Sign up with Google',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Toggle Login / Register ──
  Widget _buildToggleButton(LoginViewModel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          vm.isLogin ? "Don't have an account?" : 'Already have an account?',
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
        TextButton(
          onPressed: vm.isLoading ? null : vm.toggleMode,
          style: TextButton.styleFrom(foregroundColor: _kGreen),
          child: Text(
            vm.isLogin ? 'Register' : 'Log In',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AutofillGroup(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildBrand(),
                  const SizedBox(height: 20),
                  Text(
                    vm.isLogin ? 'Login' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: _kTitle,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    vm.isLogin
                        ? 'Login to the community and continue tracking '
                            'your progress.'
                        : 'Join the community and start tracking your '
                            'progress today.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!vm.isLogin) ...[
                    _buildNameField(vm),
                    const SizedBox(height: 18),
                  ],
                  _buildEmailField(vm),
                  const SizedBox(height: 18),
                  _buildPasswordField(vm),
                  if (!vm.isLogin) ...[
                    const SizedBox(height: 18),
                    _buildConfirmPasswordField(vm),
                  ],
                  if (vm.isLogin) _buildForgotPassword(context, vm),
                  _buildErrorMessage(vm.errorMessage),
                  SizedBox(height: vm.isLogin ? 20 : 28),
                  _buildSubmitButton(context, vm),
                  const SizedBox(height: 18),
                  _buildDivider(),
                  const SizedBox(height: 18),
                  _buildGoogleButton(context, vm),
                  const SizedBox(height: 12),
                  _buildToggleButton(vm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
