import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/history/history_page.dart';
import 'package:gdzs_calc/features/settings/settings_page.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/new_team_page.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/features/team/providers/active_team_session_provider.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  final TeamSessionRepository? repository;
  const HomePage({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    final repository = this.repository;
    if (repository == null) return const _HomePageContent();
    return ChangeNotifierProvider(
      create: (_) => ActiveTeamSessionProvider(repository)..load(),
      child: const _HomePageContent(),
    );
  }
}

class _HomePageContent extends StatefulWidget {
  const _HomePageContent();

  @override
  State<_HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<_HomePageContent> {
  late final TeamSessionRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ActiveTeamSessionProvider>().repository;
  }

  Future<void> _reload() async {
    try {
      await context.read<ActiveTeamSessionProvider>().refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не вдалося перевірити активну ланку.')),
        );
      }
    }
  }

  Future<void> _openActive() async {
    final active = context.read<ActiveTeamSessionProvider>().active;
    if (active == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ActiveTeamPage(sessionId: active.id, repository: _repository),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _createTeam() async {
    await _reload();
    if (!mounted) return;
    if (context.read<ActiveTeamSessionProvider>().active != null) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Уже є активна ланка'),
          content: const Text(
            'Спочатку завершіть поточну ланку або відкрийте її для продовження',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Відкрити активну ланку'),
            ),
          ],
        ),
      );
      if (open == true && mounted) await _openActive();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewTeamPage(teamSessionRepository: _repository),
      ),
    );
    if (mounted) await _reload();
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final active = context.watch<ActiveTeamSessionProvider>().active;
    final session = active?.session;
    final confirmed = session == null
        ? const <int>[]
        : (session.latestPressuresByFirefighterId.isEmpty
              ? session.startPressuresByFirefighterId.values.toList()
              : session.latestPressuresByFirefighterId.values.toList());
    final minimum = confirmed.isEmpty
        ? 0
        : confirmed.reduce((a, b) => a < b ? a : b);
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚒 ГДЗС Калькулятор'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (session != null) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Активна ланка',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('Етап: ${session.stage.label}'),
                      Text('Підрозділ: ${session.unitName}'),
                      Text('Караул: ${active!.watchLabel}'),
                      Text('Увімкнення: ${_clock(session.inclusionTime)}'),
                      Text('Мінімальний підтверджений тиск: $minimum бар'),
                      Text(
                        'Аварійний режим: ${session.hasActiveEmergency ? 'так' : 'ні'}',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openActive,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Відкрити активну ланку'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              height: 70,
              child: FilledButton.icon(
                onPressed: _createTeam,
                icon: const Icon(Icons.groups),
                label: const Text(
                  'СТВОРИТИ ЛАНКУ',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Card(
              child: ListTile(
                leading: Icon(Icons.menu_book),
                title: Text('Довідник'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Історія'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistoryPage(repository: _repository),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Налаштування'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final restored = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                  if (!context.mounted) return;
                  await _reload();
                  if (!context.mounted) return;
                  if (restored == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Дані успішно відновлено')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
