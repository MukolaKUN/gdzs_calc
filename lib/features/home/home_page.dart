import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/settings/settings_page.dart';
import 'package:gdzs_calc/features/team/new_team_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚒 ГДЗС Калькулятор'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),
            SizedBox(
              height: 70,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewTeamPage()),
                ),
                icon: const Icon(Icons.groups),
                label: const Text(
                  'СТВОРИТИ ЛАНКУ',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Card(
              child: ListTile(
                leading: Icon(Icons.menu_book),
                title: Text('Довідник'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.history),
                title: Text('Історія'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Налаштування'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
