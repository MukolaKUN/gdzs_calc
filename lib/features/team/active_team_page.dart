import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_check_sheet.dart';

class ActiveTeamPage extends StatefulWidget {
  final ActiveTeamSession session;

  const ActiveTeamPage({super.key, required this.session});

  @override
  State<ActiveTeamPage> createState() => _ActiveTeamPageState();
}

class _ActiveTeamPageState extends State<ActiveTeamPage> {
  Timer? _timer;
  late DateTime _now;
  bool _allowPop = false;
  bool _isLeaveDialogOpen = false;

  ActiveTeamSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    if (_session.status != ActiveTeamStatus.completed) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatClock(DateTime value, {bool includeSeconds = false}) {
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    final seconds = value.second.toString().padLeft(2, '0');
    return includeSeconds ? '$hours:$minutes:$seconds' : '$hours:$minutes';
  }

  String _formatCountdown(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 1 << 31);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes.clamp(0, 1 << 31);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes хв';
    return '$hours год ${minutes.toString().padLeft(2, '0')} хв';
  }

  String get _statusLabel {
    return switch (_session.status) {
      ActiveTeamStatus.active => 'Працює',
      ActiveTeamStatus.exiting => 'Виходить',
      ActiveTeamStatus.completed => 'Завершено',
    };
  }

  Color _statusColor(BuildContext context) {
    return switch (_session.status) {
      ActiveTeamStatus.active => Colors.green,
      ActiveTeamStatus.exiting => Colors.orange,
      ActiveTeamStatus.completed => Theme.of(context).colorScheme.outline,
    };
  }

  String get _leaderName {
    for (final participant in _session.participants) {
      if (participant.id == _session.leaderId) return participant.fullName;
    }
    return 'Не визначено';
  }

  Future<void> _confirmLeaveActiveTeam() async {
    if (_isLeaveDialogOpen || _session.status == ActiveTeamStatus.completed) {
      return;
    }

    _isLeaveDialogOpen = true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ланка ще працює. Вийти з екрана?'),
        content: const Text(
          'Вихід не завершує роботу ланки, але дані зберігаються лише в '
          'пам’яті цього екрана.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Залишитися'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Вийти'),
          ),
        ],
      ),
    );
    _isLeaveDialogOpen = false;

    if (shouldLeave != true || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _showPressureCheck() async {
    final openedAt = DateTime.now();
    final result = await showModalBottomSheet<Map<int, int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PressureCheckSheet(session: _session, openedAt: openedAt),
    );

    if (!mounted || result == null) return;

    final checkedAt = DateTime.now();
    _session.addPressureCheck(
      PressureCheck(checkedAt: checkedAt, pressuresByFirefighterId: result),
    );
    _session.addEvent(
      ActiveTeamEvent(
        time: checkedAt,
        title: 'Проведено контроль тиску',
        description:
            'Мінімальний підтверджений тиск: '
            '${result.values.reduce((a, b) => a < b ? a : b)} бар.',
      ),
    );
    setState(() => _now = checkedAt);
  }

  void _startExiting() {
    final now = DateTime.now();
    _session.startExiting(at: now);
    setState(() => _now = now);
  }

  Future<void> _completeSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Підтвердити вихід ланки?'),
        content: const Text(
          'Після підтвердження роботу активної ланки буде завершено.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ланка вийшла'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final now = DateTime.now();
    _session.complete(at: now);
    _timer?.cancel();
    setState(() => _now = now);
  }

  Widget _buildCountdown(BuildContext context) {
    final reachedExitTime = !_now.isBefore(_session.plannedExitTime);
    final remaining = _session.remainingUntilPlannedExit(_now);

    if (reachedExitTime) {
      return Card(
        key: const Key('planned-exit-time-warning'),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Настав розрахунковий час початку виходу',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '00:00',
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('До початку виходу'),
            const SizedBox(height: 8),
            Text(
              _formatCountdown(remaining),
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildPressureWarning(BuildContext context) {
    if (_session.hasExitPressureWarning) {
      return Card(
        key: const Key('exit-pressure-warning'),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Досягнуто тиску виходу. Ланка повинна розпочати вихід',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (_session.hasApproachingExitPressureWarning) {
      return Card(
        key: const Key('approaching-exit-pressure-warning'),
        color: Colors.orange.shade100,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Тиск наближається до тиску виходу',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return null;
  }

  Widget _buildEvents(BuildContext context) {
    final events = _session.events.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Журнал подій', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('Подій ще немає')
        else
          ...events.map(
            (event) => Card(
              child: ListTile(
                leading: Text(_formatClock(event.time, includeSeconds: true)),
                title: Text(event.title),
                subtitle: Text(event.description),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompletedSummary(BuildContext context) {
    final completedAt = _session.completedAt!;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Роботу ланки завершено',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Фактичний час виходу: ${_formatClock(completedAt)}'),
            Text(
              'Загальний час перебування в ЗІЗОД: '
              '${_formatDuration(_session.totalDuration!)}',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pressureWarning = _buildPressureWarning(context);
    final canPop = _allowPop || _session.status == ActiveTeamStatus.completed;

    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeaveActiveTeam();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_session.teamName)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _session.teamName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Chip(
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: _statusColor(context),
                    ),
                    label: Text(_statusLabel),
                  ),
                ],
              ),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Дані цієї ланки зберігаються лише до закриття застосунку',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Підрозділ: ${_session.unitName}'),
                      Text('Апарат: ${_session.apparatusName}'),
                      Text('Командир: $_leaderName'),
                      Text(
                        'Поточний час: '
                        '${_formatClock(_now, includeSeconds: true)}',
                      ),
                      Text(
                        'Запланований початок виходу: '
                        '${_formatClock(_session.plannedExitTime)}',
                      ),
                    ],
                  ),
                ),
              ),
              if (_session.status != ActiveTeamStatus.completed)
                _buildCountdown(context)
              else
                _buildCompletedSummary(context),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Тиск виходу',
                          value: '${_session.exitPressure} бар',
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: 'Мінімальний фактичний тиск',
                          value: '${_session.minimumActualPressure} бар',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ?pressureWarning,
              Text(
                'Склад ланки',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ..._session.participants.map(
                (participant) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(participant.fullName),
                  subtitle: participant.id == _session.leaderId
                      ? const Text('Командир ланки')
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              if (_session.status == ActiveTeamStatus.active) ...[
                FilledButton.icon(
                  onPressed: _showPressureCheck,
                  icon: const Icon(Icons.speed),
                  label: const Text('Контроль тиску'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _startExiting,
                  child: const Text('Розпочати вихід'),
                ),
              ] else if (_session.status == ActiveTeamStatus.exiting) ...[
                FilledButton.icon(
                  onPressed: _showPressureCheck,
                  icon: const Icon(Icons.speed),
                  label: const Text('Контроль тиску'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _completeSession,
                  child: const Text('Ланка вийшла'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('На головну'),
                ),
              ],
              const SizedBox(height: 24),
              _buildEvents(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
