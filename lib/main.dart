import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.initialize();
  runApp(const GdzsApp());
}
