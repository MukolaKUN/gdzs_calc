import 'package:flutter/material.dart';
import '../features/home/home_page.dart';
import '../shared/theme/app_theme.dart';
import 'app_services.dart';

class GdzsApp extends StatelessWidget {
  const GdzsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppServices.navigatorKey,
      title: 'ГДЗС Калькулятор',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.darkTheme,

      home: const HomePage(),
    );
  }
}
