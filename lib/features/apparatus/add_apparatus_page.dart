import 'package:flutter/material.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/repositories/apparatus_repository.dart';

class AddApparatusPage extends StatefulWidget {
  const AddApparatusPage({super.key});

  @override
  State<AddApparatusPage> createState() => _AddApparatusPageState();
}

class _AddApparatusPageState extends State<AddApparatusPage> {
  final _nameController = TextEditingController();
  final _pressureController = TextEditingController();
  final _volumeController = TextEditingController();

  final _repository = ApparatusRepository();

  Future<void> _save() async {
    if (_nameController.text.isEmpty ||
        _pressureController.text.isEmpty ||
        _volumeController.text.isEmpty) {
      return;
    }

    final apparatus = Apparatus(
      name: _nameController.text,
      pressure: int.parse(_pressureController.text),
      volume: double.parse(_volumeController.text),
    );

    await _repository.insert(apparatus);

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Новий апарат"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Назва",
              ),
            ),
            TextField(
              controller: _pressureController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Робочий тиск",
              ),
            ),
            TextField(
              controller: _volumeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Об'єм балона",
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _save,
              child: const Text("Зберегти"),
            )
          ],
        ),
      ),
    );
  }
}