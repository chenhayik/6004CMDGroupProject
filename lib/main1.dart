// import 'package:flutter/material.dart';
//
// void main() {
//   runApp(const MyNavApp());
// }
//
// class MyNavApp extends StatelessWidget {
//   const MyNavApp({super.key});
//
//
//   @override
//   // Widget build(BuildContext context) {
//     return MaterialApp(
//         debugShowCheckedModeBanner: false,
//         title: 'Flutter Demo',
//         theme: ThemeData(
//
//           colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         ),
//         home: const FirstScreen(),
//         initialRoute: '/homepage',
//         routes:{
//           '/homepage':(context)=> const FirstScreen(),
//           '/secondpage':(context) => const SecondScreen(),
//         }
//     );
//   }
// }
//
// class FirstScreen extends StatelessWidget {
//   const FirstScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//             automaticallyImplyLeading: false,
//             title: const Text('First Page')
//         ),
//
//         body: Column(
//           children: [
//             Center(
//                 child: ElevatedButton(
//                     child: const Text('Go to Second Page'),
//                     onPressed: (){
//                       Navigator.pushNamed(context, '/secondpage');
//                     }
//                 )
//             )
//           ],
//         )
//
//     );
//   }
// }
//
// class SecondScreen extends StatelessWidget {
//   const SecondScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//             automaticallyImplyLeading: false,
//             title: const Text('Second Page')
//         ),
//
//         body: Column(
//           children: [
//             Center(
//                 child: ElevatedButton(
//                   child: const Text('Go To First Page'),
//                   onPressed: (){
//                     Navigator.pop(context);
//                   },
//                 )
//             )
//           ],
//         )
//     );
//   }
// }
//
//
//
//
//
