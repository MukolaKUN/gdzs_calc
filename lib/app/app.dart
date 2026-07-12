import 'package:flutter/material.dart';
import '../features/home/home_page.dart';
import '../shared/theme/app_theme.dart';

class GdzsApp extends StatelessWidget {
  const GdzsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ГДЗС Калькулятор',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      home: const HomePage(),
    );
  }
}
