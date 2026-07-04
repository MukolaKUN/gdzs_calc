import 'package:flutter/material.dart';
import '../features/home/home_page.dart';

class GdzsApp extends StatelessWidget {
  const GdzsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ГДЗС Калькулятор',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
      ),
      home: const HomePage(),
    );
  }
}