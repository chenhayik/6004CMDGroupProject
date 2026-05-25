import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/login_viewmodel.dart';

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

  // ── Email field ──
  Widget _buildEmailField(LoginViewModel vm) {
    return TextFormField(
      controller: vm.emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.email),
      ),
      validator: vm.validateEmail,   // logic lives in ViewModel
    );
  }

  // ── Password field ──
  Widget _buildPasswordField(LoginViewModel vm) {
    return TextFormField(
      controller: vm.passwordController,
      obscureText: vm.obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            vm.obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: vm.togglePasswordVisibility,   // ViewModel method
        ),
      ),
      validator: vm.validatePassword,
    );
  }

  // ── Error message ──
  Widget _buildErrorMessage(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Text(
        'Oops: $errorMessage',
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Submit button ──
  Widget _buildSubmitButton(BuildContext context, LoginViewModel vm) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: vm.isLoading
            ? null                          // disable while loading
            : () async {
          if (_formKey.currentState!.validate()) {
            final result = await vm.submit();
            if (!result.isSuccess && context.mounted) {
              // error is already stored in vm.errorMessage
              // and displayed by _buildErrorMessage
              debugPrint('Auth failed: ${result.errorMessage}');
            }
          }
        },
        child: vm.isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Text(vm.isLogin ? 'Login' : 'Register'),
      ),
    );
  }

  // ── Toggle Login / Register ──
  Widget _buildToggleButton(LoginViewModel vm) {
    return TextButton(
      onPressed: vm.toggleMode,
      child: Text(
        vm.isLogin
            ? "Don't have an account? Register"
            : 'Already have an account? Login',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.isLogin ? 'Login' : 'Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildEmailField(vm),
              const SizedBox(height: 16),
              _buildPasswordField(vm),
              _buildErrorMessage(vm.errorMessage),
              const SizedBox(height: 24),
              _buildSubmitButton(context, vm),
              _buildToggleButton(vm),
            ],
          ),
        ),
      ),
    );
  }
}