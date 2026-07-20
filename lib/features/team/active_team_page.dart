import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gdzs_calc/app/app_services.dart';
import 'package:gdzs_calc/features/settings/settings_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_check_sheet.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/repositories/exit_warning_settings_repository.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';
import 'package:gdzs_calc/shared/services/haptic_gateway.dart';
import 'package:gdzs_calc/shared/services/pressure_control_reminder_service.dart';
import 'package:gdzs_calc/shared/widgets/app_button.dart';

class ActiveTeamPage extends StatefulWidget {
  final int sessionId;
  final TeamSessionRepository? repository;
  final ExitWarningService? exitWarningService;
  final ExitWarningSettingsRepository? warningSettingsRepository;
  final NotificationGateway? notificationGateway;
  final HapticGateway? hapticGateway;
  final PressureControlReminderService? pressureControlReminderService;
  final DateTime Function()? now;

  const ActiveTeamPage({
    super.key,
    required this.sessionId,
    this.repository,
    this.exitWarningService,
    this.warningSettingsRepository,
    this.notificationGateway,
    this.hapticGateway,
    this.pressureControlReminderService,
    this.now,
  });

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
  late final ExitWarningService? _exitWarningService;
  late final ExitWarningSettingsRepository? _warningSettingsRepository;
  late final NotificationGateway? _notificationGateway;
  late final HapticGateway _hapticGateway;
  late final PressureControlReminderService? _pressureReminderService;
  ExitWarningSettings _warningSettings = const ExitWarningSettings();
  final Set<ExitWarningLevel> _firedHapticLevels = {};
  final List<Timer> _hapticTimers = [];
  bool _notificationsEnabled = false;
  bool _exactWarningsAvailable = false;
  bool _permissionDialogPending = false;
  bool _reminderInitialized = false;
  int _lastReminderInterval = 0;
  int? _visibleReminderInterval;

  ActiveTeamSession get session => _loadedSession!;
  DateTime get _currentTime => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const TeamSessionRepository();
    _exitWarningService =
        widget.exitWarningService ??
        (AppServices.isInitialized ? AppServices.exitWarningService : null);
    _warningSettingsRepository =
        widget.warningSettingsRepository ??
        (AppServices.isInitialized ? AppServices.settingsRepository : null);
    _notificationGateway =
        widget.notificationGateway ??
        widget.exitWarningService?.gateway ??
        (AppServices.isInitialized ? AppServices.notificationGateway : null);
    _hapticGateway = widget.hapticGateway ?? const SystemHapticGateway();
    _pressureReminderService =
        widget.pressureControlReminderService ??
        (AppServices.isInitialized
            ? AppServices.pressureControlReminderService
            : _notificationGateway == null
            ? null
            : PressureControlReminderService(_notificationGateway));
    _now = _currentTime;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = _currentTime);
      _processHapticThreshold();
      _processPressureReminderBoundary();
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
        _now = _currentTime;
      });
      if (record != null) await _synchronizeExitWarnings();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Не вдалося завантажити активну ланку.');
    }
  }

  Future<void> _synchronizeExitWarnings() async {
    final settings =
        await _warningSettingsRepository?.load() ??
        const ExitWarningSettings(permissionPrompted: true);
    final gateway = _notificationGateway;
    var notificationsEnabled = false;
    var exact = false;
    if (gateway != null) {
      notificationsEnabled = await gateway.notificationsEnabled();
      exact = await gateway.canScheduleExactAlarms();
    }
    if (_exitWarningService != null) {
      exact = await _exitWarningService.synchronize(
        sessionId: widget.sessionId,
        stage: session.stage,
        plannedExitTime: session.currentPlannedExitTime,
        settings: settings,
        now: _currentTime,
      );
    }
    await _pressureReminderService?.synchronize(
      sessionId: widget.sessionId,
      inclusionTime: session.inclusionTime,
      stage: session.stage,
      notificationsEnabled:
          settings.systemNotifications && settings.pressureControlReminders,
      communicationAvailable:
          session.activeEmergency?.communicationAvailable ?? true,
      sound: settings.sound,
      vibration: settings.vibration,
    );
    if (!mounted) return;
    setState(() {
      _warningSettings = settings;
      _notificationsEnabled = notificationsEnabled;
      _exactWarningsAvailable = exact;
    });
    _initializePressureReminderTracking();
    _processHapticThreshold();
    _processPressureReminderBoundary();
    await _offerNotificationPermissionIfNeeded();
  }

  Future<void> _offerNotificationPermissionIfNeeded() async {
    final gateway = _notificationGateway;
    if (gateway == null ||
        !_warningSettings.systemNotifications ||
        _warningSettings.permissionPrompted ||
        session.stage == ActiveTeamStage.completed ||
        _permissionDialogPending) {
      return;
    }
    if (_notificationsEnabled) {
      final settings = _warningSettings.copyWith(permissionPrompted: true);
      await _warningSettingsRepository?.save(settings);
      if (mounted) setState(() => _warningSettings = settings);
      return;
    }
    _permissionDialogPending = true;
    final allow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Дозволити попередження про час виходу?'),
        content: const Text(
          'Застосунок зможе попередити про наближення часу виходу, навіть коли екран згорнуто',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Не зараз'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Дозволити'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final granted = allow == true ? await gateway.requestPermission() : false;
    final settings = _warningSettings.copyWith(permissionPrompted: true);
    await _warningSettingsRepository?.save(settings);
    if (!mounted) return;
    setState(() {
      _warningSettings = settings;
      _notificationsEnabled = granted;
      _permissionDialogPending = false;
    });
    if (granted) await _synchronizeExitWarnings();
  }

  void _processHapticThreshold() {
    if (!mounted ||
        _loadedSession == null ||
        session.stage != ActiveTeamStage.working ||
        !_warningSettings.vibration) {
      return;
    }
    final level = ExitWarningService.levelFor(
      session.remainingUntilPlannedExit(_now),
    );
    if (level == ExitWarningLevel.normal || !_firedHapticLevels.add(level)) {
      return;
    }
    _performHaptic(level);
  }

  void _processPressureReminderBoundary() {
    if (!mounted || _loadedSession == null || !_reminderInitialized) return;
    if (session.stage == ActiveTeamStage.completed ||
        !_warningSettings.pressureControlReminders) {
      if (_visibleReminderInterval != null) {
        setState(() => _visibleReminderInterval = null);
      }
      return;
    }
    final completed =
        PressureControlReminderService.completedTenMinuteIntervals(
          inclusionTime: session.inclusionTime,
          now: _now,
        );
    if (completed <= _lastReminderInterval) return;
    _lastReminderInterval = completed;
    setState(() => _visibleReminderInterval = completed);
    unawaited(_hapticGateway.heavyImpact());
  }

  void _initializePressureReminderTracking() {
    if (_reminderInitialized) return;
    final completed =
        PressureControlReminderService.completedTenMinuteIntervals(
          inclusionTime: session.inclusionTime,
          now: _now,
        );
    final elapsed = _now.difference(session.inclusionTime);
    _lastReminderInterval =
        elapsed.inSeconds > 0 &&
            elapsed.inSeconds %
                    PressureControlReminderService.interval.inSeconds ==
                0
        ? completed - 1
        : completed;
    _reminderInitialized = true;
  }

  void _performHaptic(ExitWarningLevel level) {
    if (!mounted) return;
    if (level == ExitWarningLevel.fiveMinutes) {
      unawaited(_hapticGateway.mediumImpact());
      return;
    }
    final count = switch (level) {
      ExitWarningLevel.oneMinute => 2,
      ExitWarningLevel.exitNow => 3,
      _ => 1,
    };
    unawaited(_hapticGateway.heavyImpact());
    for (var index = 1; index < count; index++) {
      late final Timer timer;
      timer = Timer(Duration(milliseconds: 180 * index), () {
        _hapticTimers.remove(timer);
        if (mounted) unawaited(_hapticGateway.heavyImpact());
      });
      _hapticTimers.add(timer);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    for (final timer in _hapticTimers) {
      timer.cancel();
    }
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

  Iterable<Firefighter> get _regularMembers =>
      session.participants.where((member) => member.id != session.leaderId);

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

  Future<void> _checkPressureFromReminder() async {
    if (session.hasActiveEmergency &&
        session.activeEmergency?.communicationAvailable == true) {
      await _emergencyPressureCheck();
      return;
    }
    if (session.stage == ActiveTeamStage.advancing) {
      final checkedAt = _currentTime;
      final estimated = session.estimatedAdvancingPressuresAt(checkedAt);
      final result = await _openPressureSheet(
        estimates: estimated,
        maximums: session.startPressuresByFirefighterId,
      );
      if (!mounted || result == null) return;
      await _repository.addPressureCheck(
        sessionId: widget.sessionId,
        checkedAt: checkedAt,
        estimated: estimated,
        actual: result,
        emergencyMode: false,
      );
      if (mounted) await _loadSession();
      return;
    }
    await _checkPressure();
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
    await _pressureReminderService?.cancelForSession(widget.sessionId);
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
    await _pressureReminderService?.cancelForSession(widget.sessionId);
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

  Widget _pressureReminderStatus() {
    final remaining = PressureControlReminderService.timeUntilNextReminder(
      inclusionTime: session.inclusionTime,
      now: _now,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Наступний контроль через: ${_duration(remaining)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _pressureReminderBanner() {
    final intervalNumber = _visibleReminderInterval;
    if (intervalNumber == null ||
        !_warningSettings.pressureControlReminders ||
        session.stage == ActiveTeamStage.completed) {
      return const SizedBox.shrink();
    }
    final communicationAvailable =
        session.activeEmergency?.communicationAvailable ?? true;
    return Card(
      key: const Key('pressure-control-reminder-banner'),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Час провести контроль тиску',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Закрити',
                  onPressed: () =>
                      setState(() => _visibleReminderInterval = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'Контроль №$intervalNumber: минуло ${intervalNumber * 10} хвилин від включення в ЗІЗОД.',
            ),
            const SizedBox(height: 8),
            if (communicationAvailable)
              FilledButton(
                onPressed: _checkPressureFromReminder,
                child: const Text('Провести контроль'),
              )
            else
              const Text(
                'Зв’язок із ланкою відсутній',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

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

  Widget _exitTimerCard() {
    final remaining = session.remainingUntilPlannedExit(_now);
    final level = ExitWarningService.levelFor(remaining);
    final color = switch (level) {
      ExitWarningLevel.normal => Theme.of(context).colorScheme.primaryContainer,
      ExitWarningLevel.fiveMinutes => const Color(0xFF5C4714),
      ExitWarningLevel.twoMinutes => const Color(0xFF7A3F12),
      ExitWarningLevel.oneMinute => const Color(0xFF711F24),
      ExitWarningLevel.exitNow => const Color(0xFF8D151D),
    };
    final warningText = switch (level) {
      ExitWarningLevel.normal => null,
      ExitWarningLevel.fiveMinutes => 'Підготуйте ланку до виходу',
      ExitWarningLevel.twoMinutes => 'Наближається час виходу',
      ExitWarningLevel.oneMinute => 'До виходу менше хвилини',
      ExitWarningLevel.exitNow => 'Настав час початку виходу з НДС',
    };
    return Card(
      key: Key('exit-warning-${level.name}'),
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'До початку виходу з НДС',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Text(
              _duration(remaining),
              key: const Key('До початку виходу з НДС'),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (warningText != null) ...[
              const SizedBox(height: 8),
              Text(
                warningText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 8),
            Text('Поточний час: ${_clock(_now)}'),
          ],
        ),
      ),
    );
  }

  Widget _warningStatus() {
    final (
      icon,
      text,
    ) = !_warningSettings.systemNotifications || !_notificationsEnabled
        ? (Icons.notifications_off_outlined, 'Системні сповіщення вимкнені')
        : !_exactWarningsAvailable
        ? (Icons.schedule, 'Точні фонові попередження недоступні')
        : (Icons.notifications_active_outlined, 'Попередження активні');
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(text)),
          ],
        ),
      ),
    );
  }

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
          ..._regularMembers.map(
            (member) =>
                Text(member.fullName, key: Key('team-member-${member.id}')),
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
          key: Key('pressure-member-$id'),
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
        _exitTimerCard(),
        _warningStatus(),
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
            'Склад: ${_regularMembers.map((member) => member.fullName).join(', ')}',
            key: const Key('emergency-team-members'),
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (session.stage != ActiveTeamStage.completed) ...[
                _pressureReminderStatus(),
                _pressureReminderBanner(),
              ],
              body,
            ],
          ),
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
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<EmergencyReason>(
                  initialValue: _reason,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Причина',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                  selectedItemBuilder: (context) => [
                    for (final reason in EmergencyReason.values)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          reason.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  items: [
                    for (final reason in EmergencyReason.values)
                      DropdownMenuItem(
                        value: reason,
                        child: Text(
                          reason.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
