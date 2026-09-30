import 'package:flutter/material.dart';

void main() {
  runApp(const JoomlaPosterApp());
}

class JoomlaPosterApp extends StatelessWidget {
  const JoomlaPosterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joomla Poster',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const Scaffold(body: Center(child: Text('Joomla Poster'))),
    );
  }
}
