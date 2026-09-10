import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/history/history_formatters.dart';
import 'package:gdzs_calc/features/history/team_history_details_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/theme/app_colors.dart';
import 'package:gdzs_calc/shared/utils/firefighter_watch_groups.dart';

enum HistoryPeriod { all, today, sevenDays, thirtyDays }

enum HistoryEmergencyFilter { all, withEmergency, withoutEmergency }

class HistoryPage extends StatefulWidget {
  final TeamSessionRepository? repository;
  final DateTime Function()? now;

  const HistoryPage({super.key, this.repository, this.now});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final TeamSessionRepository _repository;
  List<ActiveTeamSession> _sessions = const [];
  HistoryPeriod _period = HistoryPeriod.all;
  HistoryEmergencyFilter _emergencyFilter = HistoryEmergencyFilter.all;
  int _watch = allWatchesValue;
  bool _loading = true;
  bool _failed = false;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  List<int> get _watchOptions {
    final numbers = <int>{};
    var hasUnspecified = false;
    for (final session in _sessions) {
      for (final member in session.participants) {
        final number = member.watchNumber;
        number == null ? hasUnspecified = true : numbers.add(number);
      }
    }
    final sorted = numbers.toList()..sort();
    return [
      allWatchesValue,
      ...sorted,
      if (hasUnspecified) unspecifiedWatchValue,
    ];
  }

  List<ActiveTeamSession> get _visibleSessions => _sessions.where((session) {
    if (session.stage != ActiveTeamStage.completed) return false;
    final completedAt = session.completedAt;
    if (completedAt == null) return false;
    final now = _now;
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));
    final periodMatches = switch (_period) {
      HistoryPeriod.all => true,
      HistoryPeriod.today =>
        !completedAt.isBefore(startOfToday) &&
            completedAt.isBefore(startOfTomorrow),
      HistoryPeriod.sevenDays =>
        !completedAt.isBefore(startOfToday.subtract(const Duration(days: 6))) &&
            completedAt.isBefore(startOfTomorrow),
      HistoryPeriod.thirtyDays =>
        !completedAt.isBefore(
              startOfToday.subtract(const Duration(days: 29)),
            ) &&
            completedAt.isBefore(startOfTomorrow),
    };
    final watchMatches =
        _watch == allWatchesValue ||
        session.participants.any(
          (member) => (member.watchNumber ?? unspecifiedWatchValue) == _watch,
        );
    final emergencyMatches = switch (_emergencyFilter) {
      HistoryEmergencyFilter.all => true,
      HistoryEmergencyFilter.withEmergency => session.hadEmergency,
      HistoryEmergencyFilter.withoutEmergency => !session.hadEmergency,
    };
    return periodMatches && watchMatches && emergencyMatches;
  }).toList();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const TeamSessionRepository();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _failed = false);
    try {
      final sessions = await _repository.getCompletedSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        if (!_watchOptions.contains(_watch)) _watch = allWatchesValue;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _openDetails(ActiveTeamSession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamHistoryDetailsPage(
          sessionId: session.databaseId!,
          repository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Історія ланок')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? _ErrorState(onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _filters(),
                  const SizedBox(height: 16),
                  if (_visibleSessions.isEmpty)
                    const _EmptyState()
                  else
                    for (final session in _visibleSessions) ...[
                      _HistoryCard(
                        session: session,
                        onTap: () => _openDetails(session),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _filters() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          DropdownButtonFormField<HistoryPeriod>(
            key: const Key('history-period-filter'),
            initialValue: _period,
            decoration: const InputDecoration(labelText: 'Період'),
            items: const [
              DropdownMenuItem(value: HistoryPeriod.all, child: Text('Усі')),
              DropdownMenuItem(
                value: HistoryPeriod.today,
                child: Text('Сьогодні'),
              ),
              DropdownMenuItem(
                value: HistoryPeriod.sevenDays,
                child: Text('7 днів'),
              ),
              DropdownMenuItem(
                value: HistoryPeriod.thirtyDays,
                child: Text('30 днів'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _period = value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: const Key('history-watch-filter'),
            initialValue: _watch,
            decoration: const InputDecoration(labelText: 'Караул'),
            items: [
              for (final watch in _watchOptions)
                DropdownMenuItem(
                  value: watch,
                  child: Text(
                    watch == unspecifiedWatchValue
                        ? 'Без караулу'
                        : watchValueLabel(watch),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _watch = value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<HistoryEmergencyFilter>(
            key: const Key('history-emergency-filter'),
            initialValue: _emergencyFilter,
            decoration: const InputDecoration(labelText: 'Аварійність'),
            items: const [
              DropdownMenuItem(
                value: HistoryEmergencyFilter.all,
                child: Text('Усі'),
              ),
              DropdownMenuItem(
                value: HistoryEmergencyFilter.withEmergency,
                child: Text('З надзвичайною ситуацією'),
              ),
              DropdownMenuItem(
                value: HistoryEmergencyFilter.withoutEmergency,
                child: Text('Без надзвичайної ситуації'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _emergencyFilter = value);
            },
          ),
        ],
      ),
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  final ActiveTeamSession session;
  final VoidCallback onTap;
  const _HistoryCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final completedAt = session.completedAt!;
    return Card(
      key: ValueKey('history-session-${session.databaseId}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      historyDate(completedAt),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              Text(
                '${session.unitName} · ${teamWatchLabel(session.participants)}',
              ),
              Text('Апарат: ${session.apparatusName}'),
              Text('Учасників: ${session.participants.length}'),
              Text('Включення: ${historyTime(session.inclusionTime)}'),
              Text('Вихід: ${historyTime(completedAt)}'),
              Text('У ЗІЗОД: ${historyDuration(session.totalDuration)}'),
              if (session.hadEmergency) ...[
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'Була надзвичайна ситуація',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 56),
    child: Column(
      children: [
        Icon(Icons.history, size: 52),
        SizedBox(height: 12),
        Text('Історія поки порожня'),
        SizedBox(height: 6),
        Text(
          'Завершені ланки з’являться тут після виходу на свіже повітря',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Не вдалося завантажити історію'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Повторити')),
      ],
    ),
  );
}
