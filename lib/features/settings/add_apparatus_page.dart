import 'package:flutter/material.dart';

class AddApparatusPage extends StatefulWidget {
  const AddApparatusPage({super.key});

  @override
  State<AddApparatusPage> createState() => _AddApparatusPageState();
}

class _AddApparatusPageState extends State<AddApparatusPage> {
  final _nameController = TextEditingController();

  int _selectedPressure = 300;

  final List<double> _volumes = [6.0, 6.8, 7.0, 9.0];
  final Set<double> _selectedVolumes = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addCustomVolume() async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Новий об\'єм балона'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Наприклад 7.2',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );

                Navigator.pop(context, value);
              },
              child: const Text('Додати'),
            ),
          ],
        );
      },
    );

    if (result != null && !_volumes.contains(result)) {
      setState(() {
        _volumes.add(result);
        _volumes.sort();
        _selectedVolumes.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Додати апарат'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Назва апарата',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              value: _selectedPressure,
              decoration: const InputDecoration(
                labelText: 'Робочий тиск',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 200,
                  child: Text('200 бар'),
                ),
                DropdownMenuItem(
                  value: 300,
                  child: Text('300 бар'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPressure = value;
                  });
                }
              },
            ),

            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Об'єми балонів",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._volumes.map(
                  (volume) => FilterChip(
                    label: Text('$volume л'),
                    selected: _selectedVolumes.contains(volume),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedVolumes.add(volume);
                        } else {
                          _selectedVolumes.remove(volume);
                        }
                      });
                    },
                  ),
                ),

                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('Інший'),
                  onPressed: _addCustomVolume,
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: () {},
                child: const Text(
                  'Зберегти',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}