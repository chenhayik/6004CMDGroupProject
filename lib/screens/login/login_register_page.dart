import 'package:flutter/material.dart';
import 'package:form_validator/form_validator.dart';
import  'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_application_group/screens/login/auth.dart';

void main() {
  // 1. Wrapped with MaterialApp so the app can initialize properly
  runApp(const MaterialApp(
    home: LoginPage(),
  ));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLogin = true;
  String? errorMessage ='';
  bool _obscurePassword = true;

  Future<void> signinWithEmailAndPassword() async{
    try {
      await Auth().signInWithEmailAndPassword(email: _emailController.text, password: _passwordController.text);
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage=e.message;
      });
    }
  }

  Future<void> createUserWithEmailAndPassword() async{
    try {
      await Auth().createUserWithEmailAndPassword(email: _emailController.text, password: _passwordController.text);
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage=e.message;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }



  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.email),
      ),
      validator: ValidationBuilder()
          .email('Invalid email format')
          .maxLength(50)
          .build(),
    );
  }

  Widget _buildPasswordField(){
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off: Icons.visibility,
          ),
          onPressed: (){
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),

      ),
      validator: ValidationBuilder()
          .minLength(6, 'Password is too short')
          .maxLength(20).build(),
    );
  }
  Widget _errorMessage() {
    // If there's no error, return an empty box so it doesn't take up space
    if (errorMessage == null || errorMessage == '') {
      return const SizedBox();
    }

    // If there is an error, show it in red text
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Text(
        'Oops: $errorMessage', // Removed the rogue ')'
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _submitButton() {
    return ElevatedButton(
      onPressed: () {
        // 1. Run your validation check first
        if (_formKey.currentState!.validate()) {
          // 2. If valid, decide whether to log in or register
          if (isLogin) {
            signinWithEmailAndPassword();
          } else {
            createUserWithEmailAndPassword();
          }
        } else {
          debugPrint("Form validation failed. Stopping submit execution.");
        }
      },
      child: Text(isLogin ? 'Login' : 'Register'),
    );
  }

  Widget _loginOrRegisterButton(){
    return TextButton(
      onPressed: () {
        setState(() {
          isLogin = !isLogin;
        });
      },
      child: Text(isLogin ? 'Register':'Login'),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              _buildEmailField(),
              const SizedBox(height: 16,),
              _buildPasswordField(),
              _errorMessage(),
              const SizedBox(height: 24),
              _submitButton(),
              _loginOrRegisterButton(),


            ],
          ),
        ),
      ),
    );


  }
}