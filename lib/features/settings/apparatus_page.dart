import 'package:flutter/material.dart';
import 'add_apparatus_page.dart';

class ApparatusPage extends StatelessWidget {
  const ApparatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Апарати'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddApparatusPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: const Center(
        child: Text(
          'Ще не додано жодного апарата',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}