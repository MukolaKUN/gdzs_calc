import 'package:flutter/material.dart';

class NewTeamPage extends StatefulWidget {
  const NewTeamPage({super.key});

  @override
  State<NewTeamPage> createState() => _NewTeamPageState();
}

class _NewTeamPageState extends State<NewTeamPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Нова ланка"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          const Text(
            "Підрозділ",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Card(
            child: ListTile(
              leading: Icon(Icons.business),
              title: Text("Оберіть підрозділ"),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Тип апарата",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Card(
            child: ListTile(
              leading: Icon(Icons.air),
              title: Text("Оберіть апарат"),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Газодимозахисники",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add),
            label: const Text("Додати газодимозахисника"),
          ),

          const SizedBox(height: 40),

          SizedBox(
            height: 55,
            child: FilledButton(
              onPressed: null,
              child: const Text(
                "РОЗРАХУВАТИ",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}