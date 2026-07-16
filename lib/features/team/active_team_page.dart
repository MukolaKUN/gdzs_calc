import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_check_sheet.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';
import 'package:gdzs_calc/shared/widgets/app_button.dart';

class ActiveTeamPage extends StatefulWidget {
  final int sessionId;
  final TeamSessionRepository? repository;

  const ActiveTeamPage({super.key, required this.sessionId, this.repository});

  @override
  State<ActiveTeamPage> createState() => _ActiveTeamPageState();
}

class _ActiveTeamPageState extends State<ActiveTeamPage> {
  late DateTime _now;
  late final Timer _timer;
  bool _allowPop = false;
  bool _isEmergencyActionPending = false;
  ActiveTeamSession? _loadedSession;
  String? _loadError;
  late final TeamSessionRepository _repository;

  ActiveTeamSession get session => _loadedSession!;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const TeamSessionRepository();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final record = await _repository.getById(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _loadedSession = record?.session;
        _loadError = record == null ? 'Активну ланку не знайдено.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Не вдалося завантажити активну ланку.');
    }
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
    await _repository.confirmArrival(
      sessionId: widget.sessionId,
      arrivalTime: arrivalTime,
      pressures: result,
      calculation: calculation,
      controllingFirefighterId:
          session.participants[calculation.controllingMemberIndex].id!,
    );
    if (mounted) await _loadSession();
  }

  Future<void> _checkPressure() async {
    final checkedAt = DateTime.now();
    final result = await _openPressureSheet(
      estimates: session.estimatedPressuresAt(checkedAt),
      maximums: session.latestPressuresByFirefighterId,
    );
    if (!mounted || result == null) return;
    await _repository.addPressureCheck(
      sessionId: widget.sessionId,
      checkedAt: checkedAt,
      estimated: session.estimatedPressuresAt(checkedAt),
      actual: result,
      emergencyMode: false,
    );
    if (mounted) await _loadSession();
  }

  Future<void> _startExit() async {
    final confirmed = await _confirm(
      title: 'Підтвердити початок виходу?',
      text: 'Буде зафіксовано час початку виходу ланки із НДС.',
      action: 'Розпочати вихід',
    );
    if (!mounted || !confirmed) return;
    await _repository.startExit(widget.sessionId, DateTime.now());
    if (mounted) await _loadSession();
  }

  Future<void> _complete() async {
    final confirmed = await _confirm(
      title: 'Підтвердити вихід ланки?',
      text: 'Ланка вийшла з НДС на свіже повітря.',
      action: 'Підтвердити вихід',
    );
    if (!mounted || !confirmed) return;
    await _repository.completeSession(
      widget.sessionId,
      DateTime.now(),
      fromEmergency: false,
    );
    if (mounted) await _loadSession();
  }

  Future<void> _startEmergency() async {
    if (_isEmergencyActionPending || session.hasActiveEmergency) return;
    setState(() => _isEmergencyActionPending = true);
    final input = await showDialog<_EmergencyInput>(
      context: context,
      builder: (_) => const _EmergencyFormDialog(),
    );
    if (!mounted || input == null) {
      if (mounted) setState(() => _isEmergencyActionPending = false);
      return;
    }
    final confirmed = await _confirm(
      title: 'Підтвердити аварійний режим?',
      text: 'Буде увімкнено аварійний режим та зафіксовано час події.',
      action: 'Увімкнути',
    );
    if (!mounted) return;
    if (confirmed) {
      final at = DateTime.now();
      final communicationAvailable =
          input.reason == EmergencyReason.communicationLost
          ? false
          : input.communicationAvailable;
      final emergency = TeamEmergency(
        reason: input.reason,
        startedAt: at,
        stageAtStart: session.stage,
        communicationAvailable: communicationAvailable,
        lastContactAt: communicationAvailable ? at : null,
        note: input.note,
      );
      await _repository.startEmergency(
        widget.sessionId,
        emergency,
        'Причина: ${input.reason.label}.\n'
        'Етап: ${session.stage.label}.\n'
        'Зв’язок із ланкою '
        '${communicationAvailable ? 'наявний' : 'відсутній'}.'
        '${input.note == null ? '' : '\nПримітка: ${input.note}'}',
      );
      if (mounted) await _loadSession();
    }
    setState(() {
      _isEmergencyActionPending = false;
      _now = DateTime.now();
    });
  }

  Future<void> _emergencyPressureCheck() async {
    final emergency = session.activeEmergency;
    if (emergency == null || !emergency.communicationAvailable) return;
    final checkedAt = DateTime.now();
    final snapshots = session.emergencyPressureSnapshotsAt(checkedAt);
    final result = await _openPressureSheet(
      estimates: {
        for (final entry in snapshots.entries)
          entry.key: entry.value.estimatedPressure,
      },
      maximums: {
        for (final entry in snapshots.entries)
          entry.key: entry.value.confirmedPressure,
      },
    );
    if (!mounted || result == null) return;
    await _repository.addPressureCheck(
      sessionId: widget.sessionId,
      checkedAt: checkedAt,
      estimated: {
        for (final entry in snapshots.entries)
          entry.key: entry.value.estimatedPressure,
      },
      actual: result,
      emergencyMode: true,
    );
    if (mounted) await _loadSession();
  }

  Future<void> _restoreCommunication() async {
    await _repository.restoreCommunication(widget.sessionId, DateTime.now());
    if (!mounted) return;
    await _loadSession();
    await _emergencyPressureCheck();
  }

  Future<void> _recordEmergencyAction() async {
    const actions = [
      'Резервну ланку направлено',
      'Встановлено зв’язок',
      'Шлях виходу заблоковано',
      'Розпочато деблокування',
      'Ланка продовжує вихід',
      'Інша дія',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Зафіксувати дію')),
            for (final action in actions)
              ListTile(
                title: Text(action),
                onTap: () => Navigator.pop(sheetContext, action),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    var title = selected;
    if (selected == 'Інша дія') {
      final controller = TextEditingController();
      final note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Інша дія'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Опис дії'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Зберегти'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (!mounted || note == null || note.isEmpty) return;
      title = note;
    }
    await _repository.addEmergencyAction(
      widget.sessionId,
      DateTime.now(),
      title,
    );
    if (mounted) await _loadSession();
  }

  Future<void> _resolveEmergency() async {
    final confirmed = await _confirm(
      title: 'Надзвичайну ситуацію усунено?',
      text: 'Аварійний режим буде завершено без зміни основного етапу.',
      action: 'Підтвердити',
    );
    if (!mounted || !confirmed) return;
    final emergency = session.activeEmergency!;
    final at = DateTime.now();
    final duration = at.difference(emergency.startedAt);
    await _repository.resolveEmergency(
      widget.sessionId,
      at,
      'Причина: ${emergency.reason.label}. '
      'Тривалість: ${duration.inMinutes} хв ${duration.inSeconds % 60} с.',
    );
    if (mounted) await _loadSession();
  }

  Future<void> _completeFromEmergency() async {
    final confirmed = await _confirm(
      title: 'Підтвердити вихід ланки?',
      text: 'Ланка вийшла з НДС на свіже повітря.',
      action: 'Підтвердити вихід',
    );
    if (!mounted || !confirmed) return;
    await _repository.completeSession(
      widget.sessionId,
      DateTime.now(),
      fromEmergency: true,
    );
    if (mounted) await _loadSession();
  }

  Widget _emergencyButton() => AppButton(
    text: 'Надзвичайна ситуація',
    onPressed: _isEmergencyActionPending ? null : _startEmergency,
    icon: Icons.warning_amber_rounded,
    variant: AppButtonVariant.error,
  );

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
            '${pressures[id] ?? session.startPressuresByFirefighterId[id]} бар',
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
              subtitle: event.description.isEmpty
                  ? null
                  : Text(event.description),
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
        const SizedBox(height: 12),
        _emergencyButton(),
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
        const SizedBox(height: 12),
        _emergencyButton(),
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
      const SizedBox(height: 12),
      _emergencyButton(),
      const SizedBox(height: 20),
      _events(),
    ],
  );

  Widget _emergencyLayout() {
    final emergency = session.activeEmergency!;
    final snapshots = session.emergencyPressureSnapshotsAt(_now);
    final lastContact = emergency.lastContactAt;
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'АВАРІЙНИЙ РЕЖИМ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF501B20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emergency.reason.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Ситуацію зафіксовано о ${_clock(emergency.startedAt)}'),
                  Text('Поточний час: ${_clock(_now)}'),
                  Text('Основний етап: ${session.stage.label}'),
                  Text(
                    'Зв’язок: ${emergency.communicationAvailable ? 'наявний' : 'відсутній'}',
                  ),
                  Text(
                    'Останній зв’язок: '
                    '${lastContact == null ? 'не зафіксовано' : _clock(lastContact)}',
                  ),
                  if (emergency.note != null)
                    Text('Примітка: ${emergency.note}'),
                ],
              ),
            ),
          ),
          Text('Командир: $_leaderName'),
          Text('Апарат: ${session.apparatusName}'),
          Text(
            'Склад: ${session.participants.map((member) => member.fullName).join(', ')}',
          ),
          const SizedBox(height: 14),
          if (!emergency.communicationAvailable)
            Card(
              color: const Color(0xFF7A1820),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Зв’язок із ланкою відсутній. Значення тиску є лише розрахунковими',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Контроль і прогноз тиску',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          ...session.participants.map((member) {
            final snapshot = snapshots[member.id]!;
            return Card(
              color: const Color(0xFF302629),
              child: ListTile(
                title: Text(
                  member.fullName,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Останній підтверджений тиск: '
                  '${snapshot.confirmedPressure} бар о '
                  '${_clock(snapshot.confirmedAt)}\n'
                  'Розрахунковий тиск: ${snapshot.estimatedPressure} бар',
                  style: const TextStyle(color: Color(0xFFB8D4E8)),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          if (emergency.communicationAvailable)
            AppButton(
              text: 'Провести контроль тиску',
              onPressed: _emergencyPressureCheck,
              icon: Icons.speed,
              variant: AppButtonVariant.info,
            )
          else
            AppButton(
              text: 'Зв’язок відновлено',
              onPressed: _restoreCommunication,
              icon: Icons.wifi,
              variant: AppButtonVariant.success,
            ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Зафіксувати дію',
            onPressed: _recordEmergencyAction,
            icon: Icons.edit_note,
            variant: AppButtonVariant.secondary,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Надзвичайну ситуацію усунено',
            onPressed: _resolveEmergency,
            icon: Icons.warning_amber_rounded,
            variant: AppButtonVariant.warning,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Ланка вийшла на свіже повітря',
            onPressed: _completeFromEmergency,
            icon: Icons.task_alt,
            variant: AppButtonVariant.success,
          ),
          const SizedBox(height: 20),
          _events(),
        ],
      ),
    );
  }

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
              Text(
                'Прибуття: '
                '${session.arrivalTime == null ? 'не зафіксовано' : _clock(session.arrivalTime!)}',
              ),
              Text(
                'Початок виходу: '
                '${session.exitStartedAt == null ? 'не зафіксовано' : _clock(session.exitStartedAt!)}',
              ),
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
      const Text('Дані ланки збережено', textAlign: TextAlign.center),
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
      title: session.hasActiveEmergency
          ? 'Аварійний режим активний. Вийти з екрана?'
          : 'Ланка ще працює. Вийти з екрана?',
      text: session.hasActiveEmergency
          ? 'Вихід з екрана не змінить етап і не завершить аварію.'
          : 'Дані цієї активної ланки буде втрачено.',
      action: 'Вийти',
    );
    if (!mounted || !leave) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadedSession == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Активна ланка')),
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!),
                    FilledButton(
                      onPressed: _loadSession,
                      child: const Text('Повторити'),
                    ),
                  ],
                ),
        ),
      );
    }
    final body = session.hasActiveEmergency
        ? _emergencyLayout()
        : switch (session.stage) {
            ActiveTeamStage.advancing => _advancing(),
            ActiveTeamStage.working => _working(),
            ActiveTeamStage.exiting => _exiting(),
            ActiveTeamStage.completed => _completed(),
          };
    final emergency = session.hasActiveEmergency;
    return PopScope<void>(
      canPop: _allowPop || session.stage == ActiveTeamStage.completed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _guardBack();
      },
      child: Scaffold(
        backgroundColor: emergency ? const Color(0xFF211416) : null,
        appBar: AppBar(
          title: Text(session.teamName),
          backgroundColor: emergency ? const Color(0xFF6D151D) : null,
          foregroundColor: emergency ? Colors.white : null,
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [body]),
        ),
      ),
    );
  }
}

class _EmergencyInput {
  final EmergencyReason reason;
  final bool communicationAvailable;
  final String? note;

  const _EmergencyInput({
    required this.reason,
    required this.communicationAvailable,
    this.note,
  });
}

class _EmergencyFormDialog extends StatefulWidget {
  const _EmergencyFormDialog();

  @override
  State<_EmergencyFormDialog> createState() => _EmergencyFormDialogState();
}

class _EmergencyFormDialogState extends State<_EmergencyFormDialog> {
  final _noteController = TextEditingController();
  EmergencyReason _reason = EmergencyReason.communicationLost;
  bool _communicationAvailable = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Зафіксувати надзвичайну ситуацію'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<EmergencyReason>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Причина'),
              items: [
                for (final reason in EmergencyReason.values)
                  DropdownMenuItem(value: reason, child: Text(reason.label)),
              ],
              onChanged: (reason) {
                if (reason == null) return;
                setState(() {
                  _reason = reason;
                  if (reason == EmergencyReason.communicationLost) {
                    _communicationAvailable = false;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Примітка (необов’язково)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Зв’язок із ланкою наявний'),
              value: _communicationAvailable,
              onChanged: (value) {
                setState(() => _communicationAvailable = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _EmergencyInput(
              reason: _reason,
              communicationAvailable: _communicationAvailable,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ),
          ),
          child: const Text('Далі'),
        ),
      ],
    );
  }
}
