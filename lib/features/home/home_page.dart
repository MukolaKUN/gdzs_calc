import 'package:flutter/material.dart';
import 'package:gdzs_calc/app/app_services.dart';
import 'package:gdzs_calc/features/history/history_page.dart';
import 'package:gdzs_calc/features/settings/settings_page.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/new_team_page.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';

class HomePage extends StatefulWidget {
  final TeamSessionRepository? repository;
  const HomePage({super.key, this.repository});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TeamSessionRepository _repository;
  TeamSessionRecord? _active;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (AppServices.isInitialized
            ? AppServices.teamRepository
            : const TeamSessionRepository());
    _reload();
  }

  Future<void> _reload() async {
    try {
      final active = await _repository.getActiveSession();
      if (mounted) setState(() => _active = active);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не вдалося перевірити активну ланку.')),
        );
      }
    }
  }

  Future<void> _openActive() async {
    final active = _active;
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
    if (_active != null) {
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
    final active = _active;
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
