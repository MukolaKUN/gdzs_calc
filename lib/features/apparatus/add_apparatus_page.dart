import 'package:flutter/material.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/repositories/apparatus_repository.dart';

class AddApparatusPage extends StatefulWidget {
  final Apparatus? apparatus;

  const AddApparatusPage({super.key, this.apparatus});

  @override
  State<AddApparatusPage> createState() => _AddApparatusPageState();
}

class _AddApparatusPageState extends State<AddApparatusPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ApparatusRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _workingPressureController;
  late final TextEditingController _cylinderVolumeController;
  late final TextEditingController _cylindersCountController;
  late final TextEditingController _reservePressureController;

  bool get _isEditing => widget.apparatus != null;

  @override
  void initState() {
    super.initState();
    final apparatus = widget.apparatus;
    _nameController = TextEditingController(text: apparatus?.name ?? '');
    _workingPressureController = TextEditingController(
      text: apparatus?.workingPressure.toString() ?? '',
    );
    _cylinderVolumeController = TextEditingController(
      text: apparatus?.cylinderVolume.toString() ?? '',
    );
    _cylindersCountController = TextEditingController(
      text: apparatus?.cylindersCount.toString() ?? '',
    );
    _reservePressureController = TextEditingController(
      text: apparatus?.reservePressure.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _workingPressureController.dispose();
    _cylinderVolumeController.dispose();
    _cylindersCountController.dispose();
    _reservePressureController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final apparatus = Apparatus(
      id: widget.apparatus?.id,
      name: _nameController.text.trim(),
      workingPressure: int.parse(_workingPressureController.text.trim()),
      cylinderVolume: double.parse(
        _cylinderVolumeController.text.trim().replaceAll(',', '.'),
      ),
      cylindersCount: int.parse(_cylindersCountController.text.trim()),
      reservePressure: int.parse(_reservePressureController.text.trim()),
    );

    if (_isEditing) {
      await _repository.update(apparatus);
    } else {
      await _repository.insert(apparatus);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редагувати апарат' : 'Новий апарат'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Назва апарата'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Вкажіть назву апарата';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _workingPressureController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Робочий тиск, бар'),
              validator: (value) {
                final pressure = int.tryParse(value?.trim() ?? '');
                if (pressure == null || pressure <= 0) {
                  return 'Робочий тиск має бути більшим за 0';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _cylinderVolumeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Об’єм одного балона, л',
              ),
              validator: (value) {
                final volume = double.tryParse(
                  (value ?? '').trim().replaceAll(',', '.'),
                );
                if (volume == null || volume <= 0) {
                  return 'Об’єм балона має бути більшим за 0';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _cylindersCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Кількість балонів'),
              validator: (value) {
                final count = int.tryParse(value?.trim() ?? '');
                if (count == null || count <= 0) {
                  return 'Кількість балонів має бути більшою за 0';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _reservePressureController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Резервний тиск, бар',
              ),
              validator: (value) {
                final reservePressure = int.tryParse(value?.trim() ?? '');
                final workingPressure = int.tryParse(
                  _workingPressureController.text.trim(),
                );
                if (reservePressure == null || reservePressure < 0) {
                  return 'Резервний тиск не може бути від’ємним';
                }
                if (workingPressure != null &&
                    reservePressure >= workingPressure) {
                  return 'Резервний тиск має бути меншим за робочий';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Зберегти')),
          ],
        ),
      ),
    );
  }
}
