import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/apparatus/apparatus_page.dart';
import 'package:gdzs_calc/features/firefighters/firefighters_page.dart';
import '../units/units_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Налаштування")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.business),
              title: Text("Підрозділ"),
              subtitle: Text("Назва та основні дані"),
              trailing: Icon(Icons.chevron_right),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnitsPage()),
                );
              },
            ),
          ),

          SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: Icon(Icons.air),
              title: Text("Апарати"),
              subtitle: Text("Типи апаратів та балонів"),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ApparatusPage()),
                );
              },
            ),
          ),

          SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: Icon(Icons.groups),
              title: Text("Газодимозахисники"),
              subtitle: Text("Особовий склад"),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FirefightersPage()),
                );
              },
            ),
          ),

          SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("Про застосунок"),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }
}
