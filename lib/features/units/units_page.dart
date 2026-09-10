import 'package:flutter/material.dart';
import 'package:gdzs_calc/shared/models/unit.dart';
import 'package:gdzs_calc/shared/repositories/unit_repository.dart';
import '../settings/add_unit_page.dart';
import 'package:gdzs_calc/shared/widgets/app_snackbar.dart';

class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  final _repository = UnitRepository();

  List<Unit> _units = [];

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final data = await _repository.getAll();

    setState(() {
      _units = data;
    });
  }

  Future<void> _deleteUnit(Unit unit) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити підрозділ?'),
        content: Text('Ви дійсно хочете видалити "${unit.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );

    if (result != true) return;

    await _repository.delete(unit.id!);

    await _loadUnits();

    if (!mounted) return;

    AppSnackBar.success(context, 'Підрозділ видалено');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Підрозділи')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddUnitPage()),
          );

          if (!mounted) return;

          await _loadUnits();

          await _loadUnits();

          await _loadUnits();
        },
        child: const Icon(Icons.add),
      ),
      body: _units.isEmpty
          ? const Center(child: Text('Поки що немає жодного підрозділу'))
          : ListView.builder(
              itemCount: _units.length,
              itemBuilder: (context, index) {
                final unit = _units[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.business)),
                    title: Text(
                      unit.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(unit.city),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddUnitPage(unit: unit),
                              ),
                            ).then((_) {
                              _loadUnits();
                            });

                            break;

                          case 'delete':
                            _deleteUnit(unit);
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 10),
                              Text('Редагувати'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 10),
                              Text(
                                'Видалити',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
