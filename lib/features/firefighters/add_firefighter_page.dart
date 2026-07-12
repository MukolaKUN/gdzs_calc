import 'package:flutter/material.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/repositories/firefighter_repository.dart';

class AddFirefighterPage extends StatefulWidget {
  final Firefighter? firefighter;

  const AddFirefighterPage({super.key, this.firefighter});

  @override
  State<AddFirefighterPage> createState() => _AddFirefighterPageState();
}

class _AddFirefighterPageState extends State<AddFirefighterPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = FirefighterRepository();
  late final TextEditingController _fullNameController;
  late final TextEditingController _watchController;
  bool _isSaving = false;

  bool get _isEditing => widget.firefighter != null;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.firefighter?.fullName ?? '',
    );
    _watchController = TextEditingController(text: widget.firefighter?.watch ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _watchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    final firefighter = Firefighter(
      id: widget.firefighter?.id,
      fullName: _fullNameController.text.trim(),
      watch: _watchController.text.trim(),
    );

    try {
      if (_isEditing) {
        await _repository.update(firefighter);
      } else {
        await _repository.insert(firefighter);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося зберегти газодимозахисника.')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Редагувати газодимозахисника' : 'Новий газодимозахисник',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _fullNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'ПІБ газодимозахисника'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Вкажіть ПІБ газодимозахисника';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _watchController,
              decoration: const InputDecoration(labelText: 'Караул / зміна'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Вкажіть караул або зміну';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'Збереження…' : 'Зберегти'),
            ),
          ],
        ),
      ),
    );
  }
}
