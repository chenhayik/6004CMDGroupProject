import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import for Firebase


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  // 1. Define the actual sign out logic here
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // 2. Helper Function: Creates the top App Bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Home'),
      centerTitle: true,
    );
  }

  // 3. Helper Function: Creates the Sign Out Button
  Widget _buildSignOutButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        // Trigger the sign out function when clicked
        await signOut();
        debugPrint("User successfully signed out!");
      },
      icon: const Icon(Icons.logout),
      label: const Text(
        'Sign Out',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // 4. Update the Body to hold BOTH the text and the button
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Welcome to your Empty Homepage!',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 40), // Adds space between text and button

          _buildSignOutButton(), // Call the button here!
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }
}