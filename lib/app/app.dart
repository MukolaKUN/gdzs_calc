import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/home/home_page.dart';
import '../features/team/providers/active_team_session_provider.dart';
import '../shared/theme/app_theme.dart';
import 'app_services.dart';

class GdzsApp extends StatelessWidget {
  const GdzsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActiveTeamSessionProvider(AppServices.teamRepository)
        ..load(),
      child: MaterialApp(
        navigatorKey: AppServices.navigatorKey,
        title: 'ГДЗС Калькулятор',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomePage(),
      ),
    );
  }
}
