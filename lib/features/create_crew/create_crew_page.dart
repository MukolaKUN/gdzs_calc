import 'package:flutter/material.dart';

class CreateCrewPage extends StatelessWidget {
  const CreateCrewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Створення ланки'),
      ),
      body: const Center(
        child: Text(
          'Тут буде створення ланки',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}