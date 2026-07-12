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

    setState(() {
      _apparatus = data;
    });
  }

  Future<void> _delete(Apparatus apparatus) async {
    await _repository.delete(apparatus.id!);

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Апарати"),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddApparatusPage(),
            ),
          );

          _load();
        },
      ),
      body: _apparatus.isEmpty
          ? const Center(
              child: Text("Немає апаратів"),
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
                        "${item.pressure} бар | ${item.volume} л"),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                      onPressed: () => _delete(item),
                    ),
                  ),
                );
              },
            ),
    );
  }
}