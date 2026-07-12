import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/firefighters/add_firefighter_page.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/repositories/firefighter_repository.dart';

class FirefightersPage extends StatefulWidget {
  const FirefightersPage({super.key});

  @override
  State<FirefightersPage> createState() => _FirefightersPageState();
}

class _FirefightersPageState extends State<FirefightersPage> {
  final _repository = FirefighterRepository();
  List<Firefighter> _firefighters = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFirefighters();
  }

  Future<void> _loadFirefighters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firefighters = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _firefighters = firefighters;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не вдалося завантажити список газодимозахисників.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditor([Firefighter? firefighter]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFirefighterPage(firefighter: firefighter),
      ),
    );
    if (!mounted || saved != true) return;

    await _loadFirefighters();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          firefighter == null
              ? 'Газодимозахисника додано.'
              : 'Дані газодимозахисника оновлено.',
        ),
      ),
    );
  }

  Future<void> _delete(Firefighter firefighter) async {
    final id = firefighter.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити газодимозахисника?'),
        content: Text('Ви дійсно хочете видалити ${firefighter.fullName}?'),
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
    if (confirmed != true) return;

    try {
      await _repository.delete(id);
      if (!mounted) return;
      await _loadFirefighters();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Газодимозахисника видалено.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося видалити газодимозахисника.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Газодимозахисники')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditor,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadFirefighters,
                      child: const Text('Повторити'),
                    ),
                  ],
                ),
              ),
            )
          : _firefighters.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('У довіднику ще немає газодимозахисників.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _openEditor,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Додати газодимозахисника'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFirefighters,
              child: ListView.builder(
                itemCount: _firefighters.length,
                itemBuilder: (context, index) {
                  final firefighter = _firefighters[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(firefighter.fullName),
                      subtitle: Text(firefighter.watch),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditor(firefighter);
                          } else if (value == 'delete') {
                            _delete(firefighter);
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
            ),
    );
  }
}
