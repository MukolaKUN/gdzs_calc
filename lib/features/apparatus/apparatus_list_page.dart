import 'package:flutter/material.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/repositories/apparatus_repository.dart';

import 'add_apparatus_page.dart';

class ApparatusListPage extends StatefulWidget {
  const ApparatusListPage({super.key});

  @override
  State<ApparatusListPage> createState() => _ApparatusListPageState();
}

class _ApparatusListPageState extends State<ApparatusListPage> {
  final _repository = ApparatusRepository();

  List<Apparatus> _apparatus = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repository.getAll();
    if (!mounted) return;

    setState(() {
      _apparatus = data;
    });
  }

  Future<void> _delete(Apparatus apparatus) async {
    final id = apparatus.id;
    if (id == null) return;

    await _repository.delete(id);
    await _load();
  }

  Future<void> _openEditor([Apparatus? apparatus]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddApparatusPage(apparatus: apparatus),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Апарати'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditor,
        child: const Icon(Icons.add),
      ),
      body: _apparatus.isEmpty
          ? const Center(
              child: Text('Немає апаратів'),
            )
          : ListView.builder(
              itemCount: _apparatus.length,
              itemBuilder: (context, index) {
                final item = _apparatus[index];

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.air),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.workingPressure} бар • '
                      '${item.cylinderVolume} л × ${item.cylindersCount} • '
                      'резерв ${item.reservePressure} бар',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditor(item);
                        } else if (value == 'delete') {
                          _delete(item);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Редагувати'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Видалити'),
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
