import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final int age;
  final String biologicalSex;
  final double height;
  final double weight;
  final String activityLevel;
  final String goal;


  UserProfile({
    required this.uid,
    required this.age,
    required this.biologicalSex,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.goal,
  });

  Map<String, dynamic> toMap() {
    return {
      'age': age,
      'biologicalSex': biologicalSex,
      'height': height,
      'weight': weight,
      'activityLevel': activityLevel,
      'goal': goal,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}