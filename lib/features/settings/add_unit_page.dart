import 'package:flutter/material.dart';
import 'package:gdzs_calc/shared/models/unit.dart';
import 'package:gdzs_calc/shared/repositories/unit_repository.dart';
import 'package:gdzs_calc/shared/theme/app_sizes.dart';
import 'package:gdzs_calc/shared/widgets/app_button.dart';
import 'package:gdzs_calc/shared/widgets/app_snackbar.dart';

class AddUnitPage extends StatefulWidget {
  final Unit? unit;

  const AddUnitPage({super.key, this.unit});

  @override
  State<AddUnitPage> createState() => _AddUnitPageState();
}

class _AddUnitPageState extends State<AddUnitPage> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  final _repository = UnitRepository();

  bool get _isEditing => widget.unit != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      _nameController.text = widget.unit!.name;
      _cityController.text = widget.unit!.city;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _saveUnit() async {
    if (_nameController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      AppSnackBar.error(context, 'Заповніть усі поля');
      return;
    }

    final unit = Unit(
      id: widget.unit?.id,
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
    );

    if (_isEditing) {
      await _repository.update(unit);
    } else {
      await _repository.insert(unit);
    }

    if (!mounted) return;

    AppSnackBar.success(
      context,
      _isEditing ? 'Підрозділ оновлено' : 'Підрозділ успішно збережено',
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редагування підрозділу' : 'Новий підрозділ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Назва підрозділу',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Місто',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            AppButton(
              text: _isEditing ? 'Зберегти зміни' : 'Зберегти',
              onPressed: _saveUnit,
            ),
          ],
        ),
      ),
    );
  }
}
