import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_check_sheet.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';
import 'package:gdzs_calc/shared/widgets/app_button.dart';

class ActiveTeamPage extends StatefulWidget {
  final ActiveTeamSession session;

  const ActiveTeamPage({super.key, required this.session});

  @override
  State<ActiveTeamPage> createState() => _ActiveTeamPageState();
}

class _ActiveTeamPageState extends State<ActiveTeamPage> {
  late DateTime _now;
  late final Timer _timer;
  bool _allowPop = false;

  ActiveTeamSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';

  String _duration(Duration value) {
    final seconds = value.inSeconds.clamp(0, 1 << 31);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    final tail =
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
    return hours == 0 ? tail : '${hours.toString().padLeft(2, '0')}:$tail';
  }

  String get _leaderName => session.participants
      .firstWhere((member) => member.id == session.leaderId)
      .fullName;

  String get _workLoadLabel =>
      session.workLoad == WorkLoad.heavy ? 'Важкі' : 'Середні';

  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Скасувати'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<Map<int, int>?> _openPressureSheet({
    required Map<int, int> estimates,
    required Map<int, int> maximums,
  }) {
    return showModalBottomSheet<Map<int, int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PressureCheckSheet(
        participants: session.participants,
        leaderId: session.leaderId,
        maximumPressuresByFirefighterId: maximums,
        estimatedPressuresByFirefighterId: estimates,
      ),
    );
  }

  Future<void> _confirmArrival() async {
    final arrivalTime = DateTime.now();
    final estimates = session.estimatedAdvancingPressuresAt(arrivalTime);
    final result = await _openPressureSheet(
      estimates: estimates,
      maximums: session.startPressuresByFirefighterId,
    );
    if (!mounted || result == null) return;

    final orderedIds = session.participants
        .map((member) => member.id!)
        .toList();
    final calculation = GdzsCalculator.calculateCompressedAir(
      startPressures: [
        for (final id in orderedIds) session.startPressuresByFirefighterId[id]!,
      ],
      arrivalPressures: [for (final id in orderedIds) result[id]!],
      inclusionTime: session.inclusionTime,
      arrivalTime: arrivalTime,
      cylinderVolume: session.cylinderVolume,
      cylindersCount: session.cylindersCount,
      reservePressure: session.reservePressure,
      workLoad: session.workLoad,
    );
    session.confirmArrival(
      arrivalTime: arrivalTime,
      arrivalPressures: result,
      calculation: calculation,
    );
    setState(() => _now = DateTime.now());
  }

  Future<void> _checkPressure() async {
    final checkedAt = DateTime.now();
    final result = await _openPressureSheet(
      estimates: session.estimatedPressuresAt(checkedAt),
      maximums: session.latestPressuresByFirefighterId,
    );
    if (!mounted || result == null) return;
    session.addPressureCheck(
      PressureCheck(checkedAt: checkedAt, pressuresByFirefighterId: result),
    );
    setState(() => _now = DateTime.now());
  }

  Future<void> _startExit() async {
    final confirmed = await _confirm(
      title: 'Підтвердити початок виходу?',
      text: 'Буде зафіксовано час початку виходу ланки із НДС.',
      action: 'Розпочати вихід',
    );
    if (!mounted || !confirmed) return;
    session.startExit(at: DateTime.now());
    setState(() => _now = DateTime.now());
  }

  Future<void> _complete() async {
    final confirmed = await _confirm(
      title: 'Підтвердити вихід ланки?',
      text: 'Ланка вийшла з НДС на свіже повітря.',
      action: 'Підтвердити вихід',
    );
    if (!mounted || !confirmed) return;
    session.complete(at: DateTime.now());
    setState(() => _now = DateTime.now());
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
  );

  Widget _timerCard(String label, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Text(
            value,
            key: Key(label),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Text('Поточний час: ${_clock(_now)}'),
        ],
      ),
    ),
  );

  Widget _teamInfo() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Підрозділ: ${session.unitName}'),
          Text('Апарат: ${session.apparatusName}'),
          Text('Умови роботи: $_workLoadLabel'),
          Text('Командир: $_leaderName'),
          const Divider(),
          ...session.participants.map(
            (member) => Text(
              '${member.fullName}${member.id == session.leaderId ? ' — командир' : ''}',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pressureList(
    Map<int, int> pressures, {
    bool showStart = false,
  }) => Card(
    child: Column(
      children: session.participants.map((member) {
        final id = member.id!;
        return ListTile(
          leading: const Icon(Icons.speed),
          title: Text(member.fullName),
          subtitle: showStart
              ? Text(
                  'Початковий тиск: ${session.startPressuresByFirefighterId[id]} бар',
                )
              : null,
          trailing: Text(
            '${pressures[id]} бар',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    ),
  );

  Widget _warnings() {
    if (!session.hasExitPressureWarning &&
        !session.hasApproachingExitPressureWarning) {
      return const SizedBox.shrink();
    }
    final critical = session.hasExitPressureWarning;
    return Card(
      color: critical
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          critical
              ? 'Досягнуто тиску виходу'
              : 'Тиск наближається до тиску виходу',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _events() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Журнал подій', style: Theme.of(context).textTheme.titleLarge),
      ...session.events.reversed
          .take(5)
          .map(
            (event) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(_clock(event.time)),
              title: Text(event.title),
            ),
          ),
    ],
  );

  Widget _advancing() {
    final pressures = session.estimatedAdvancingPressuresAt(_now);
    final minimum = pressures.values.reduce((a, b) => a < b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Ланка прямує до місця роботи'),
        _timerCard(
          'Час прямування',
          _duration(session.advancingDurationAt(_now)),
        ),
        Text('Увімкнення в ЗІЗОД: ${_clock(session.inclusionTime)}'),
        const SizedBox(height: 12),
        _teamInfo(),
        const SizedBox(height: 12),
        Text(
          'Розрахунковий тиск',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        _pressureList(pressures, showStart: true),
        Text('Мінімальний розрахунковий тиск: $minimum бар'),
        const SizedBox(height: 20),
        AppButton(
          text: 'Підтвердити прибуття',
          onPressed: _confirmArrival,
          icon: Icons.location_on,
        ),
        const SizedBox(height: 6),
        const Text(
          'Зафіксувати тиск і розпочати роботу ланки',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _working() {
    final controlling = session.participants
        .firstWhere((member) => member.id == session.controllingFirefighterId)
        .fullName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Ланка працює в НДС'),
        _timerCard(
          'До початку виходу з НДС',
          _duration(session.remainingUntilPlannedExit(_now)),
        ),
        _teamInfo(),
        _pressureList(session.latestPressuresByFirefighterId),
        Text(
          'Мінімальний підтверджений тиск: ${session.minimumActualPressure} бар',
        ),
        Text('Тиск виходу: ${session.exitPressure} бар'),
        Text('Залишок роботи: ${session.currentRemainingWorkMinutes} хв'),
        Text('Визначальний газодимозахисник: $controlling'),
        _warnings(),
        const SizedBox(height: 16),
        AppButton(
          text: 'Контроль тиску',
          onPressed: _checkPressure,
          icon: Icons.speed,
          variant: AppButtonVariant.info,
        ),
        const SizedBox(height: 12),
        AppButton(
          text: 'Розпочати вихід із НДС',
          onPressed: _startExit,
          icon: Icons.logout,
          variant: AppButtonVariant.warning,
        ),
        const SizedBox(height: 20),
        _events(),
      ],
    );
  }

  Widget _exiting() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Ланка виходить із НДС'),
      Text('Поточний час: ${_clock(_now)}'),
      Text('Вихід розпочато о ${_clock(session.exitStartedAt!)}'),
      const SizedBox(height: 12),
      _teamInfo(),
      _pressureList(session.latestPressuresByFirefighterId),
      Text(
        'Мінімальний підтверджений тиск: ${session.minimumActualPressure} бар',
      ),
      Text('Тиск виходу: ${session.exitPressure} бар'),
      Text('Резервний тиск: ${session.reservePressure} бар'),
      _warnings(),
      const SizedBox(height: 16),
      AppButton(
        text: 'Контроль тиску',
        onPressed: _checkPressure,
        icon: Icons.speed,
        variant: AppButtonVariant.info,
      ),
      const SizedBox(height: 12),
      AppButton(
        text: 'Ланка вийшла на свіже повітря',
        onPressed: _complete,
        icon: Icons.task_alt,
      ),
      const SizedBox(height: 20),
      _events(),
    ],
  );

  Widget _completed() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Роботу ланки завершено'),
      Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Увімкнення: ${_clock(session.inclusionTime)}'),
              Text('Прибуття: ${_clock(session.arrivalTime!)}'),
              Text('Початок виходу: ${_clock(session.exitStartedAt!)}'),
              Text('Свіже повітря: ${_clock(session.completedAt!)}'),
              Text(
                'Загальний час у ЗІЗОД: ${_duration(session.totalDuration!)}',
              ),
            ],
          ),
        ),
      ),
      _pressureList(session.latestPressuresByFirefighterId),
      _events(),
      const SizedBox(height: 16),
      const Text(
        'Дані ланки зберігаються лише до закриття застосунку',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      AppButton(
        text: 'Завершити та повернутися на головну',
        onPressed: () {
          setState(() => _allowPop = true);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        icon: Icons.home,
      ),
    ],
  );

  Future<void> _guardBack() async {
    final leave = await _confirm(
      title: 'Ланка ще працює. Вийти з екрана?',
      text: 'Дані цієї активної ланки буде втрачено.',
      action: 'Вийти',
    );
    if (!mounted || !leave) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (session.stage) {
      ActiveTeamStage.advancing => _advancing(),
      ActiveTeamStage.working => _working(),
      ActiveTeamStage.exiting => _exiting(),
      ActiveTeamStage.completed => _completed(),
    };
    return PopScope<void>(
      canPop: _allowPop || session.stage == ActiveTeamStage.completed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _guardBack();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(session.teamName)),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [body]),
        ),
      ),
    );
  }
}
