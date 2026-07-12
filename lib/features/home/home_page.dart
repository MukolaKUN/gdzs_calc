import 'package:flutter/material.dart';
import '../create_crew/create_crew_page.dart';
import '../settings/settings_page.dart';

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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              SizedBox(
                height: 70,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                       builder: (_) => const CreateCrewPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.groups),
                  label: const Text(
                    'СТВОРИТИ ЛАНКУ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: const Text('Довідник'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Історія'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Налаштування'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}