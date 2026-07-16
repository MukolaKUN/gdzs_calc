import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

enum ActiveTeamStage { advancing, working, exiting, completed }

class PressureCheck {
  final DateTime checkedAt;
  final Map<int, int> pressuresByFirefighterId;

  PressureCheck({
    required this.checkedAt,
    required Map<int, int> pressuresByFirefighterId,
  }) : pressuresByFirefighterId = Map.unmodifiable(pressuresByFirefighterId);
}

class ActiveTeamEvent {
  final DateTime time;
  final String title;
  final String description;

  const ActiveTeamEvent({
    required this.time,
    required this.title,
    this.description = '',
  });
}

class ActiveTeamSession {
  final String unitName;
  final String apparatusName;
  final List<Firefighter> participants;
  final int leaderId;
  final Map<int, int> startPressuresByFirefighterId;
  final DateTime inclusionTime;
  final WorkLoad workLoad;
  final double cylinderVolume;
  final int cylindersCount;
  final int reservePressure;

  ActiveTeamStage _stage;
  DateTime? _arrivalTime;
  Map<int, int> _arrivalPressuresByFirefighterId;
  DateTime? _initialPlannedExitTime;
  DateTime? _updatedPlannedExitTime;
  DateTime? _exitStartedAt;
  DateTime? _completedAt;
  int? _travelPressure;
  int? _exitPressure;
  int? _workingPressure;
  int? _workingTimeMinutes;
  int? _controllingFirefighterId;
  int _currentRemainingWorkMinutes;
  final List<PressureCheck> _pressureChecks;
  final List<ActiveTeamEvent> _events;

  ActiveTeamSession.advancing({
    required this.unitName,
    required this.apparatusName,
    required List<Firefighter> participants,
    required this.leaderId,
    required Map<int, int> startPressuresByFirefighterId,
    required this.inclusionTime,
    required this.workLoad,
    required this.cylinderVolume,
    required this.cylindersCount,
    required this.reservePressure,
    List<ActiveTeamEvent> events = const [],
  }) : participants = List.unmodifiable(participants),
       startPressuresByFirefighterId = Map.unmodifiable(
         startPressuresByFirefighterId,
       ),
       _stage = ActiveTeamStage.advancing,
       _arrivalTime = null,
       _arrivalPressuresByFirefighterId = const {},
       _initialPlannedExitTime = null,
       _updatedPlannedExitTime = null,
       _exitStartedAt = null,
       _completedAt = null,
       _travelPressure = null,
       _exitPressure = null,
       _workingPressure = null,
       _workingTimeMinutes = null,
       _controllingFirefighterId = null,
       _currentRemainingWorkMinutes = 0,
       _pressureChecks = [],
       _events = List.of(events);

  String get teamName => 'Ланка $unitName';
  ActiveTeamStage get stage => _stage;
  DateTime? get arrivalTime => _arrivalTime;
  DateTime? get initialPlannedExitTime => _initialPlannedExitTime;
  DateTime? get currentPlannedExitTime =>
      _updatedPlannedExitTime ?? _initialPlannedExitTime;
  DateTime? get exitStartedAt => _exitStartedAt;
  DateTime? get completedAt => _completedAt;
  int? get travelPressure => _travelPressure;
  int? get exitPressure => _exitPressure;
  int? get workingPressure => _workingPressure;
  int? get workingTimeMinutes => _workingTimeMinutes;
  int get currentRemainingWorkMinutes => _currentRemainingWorkMinutes;
  int? get controllingFirefighterId => _controllingFirefighterId;
  Map<int, int> get arrivalPressuresByFirefighterId =>
      Map.unmodifiable(_arrivalPressuresByFirefighterId);
  List<PressureCheck> get pressureChecks => List.unmodifiable(_pressureChecks);
  List<ActiveTeamEvent> get events => List.unmodifiable(_events);

  Duration advancingDurationAt(DateTime now) {
    final duration = now.difference(inclusionTime);
    return duration.isNegative ? Duration.zero : duration;
  }

  Map<int, int> estimatedAdvancingPressuresAt(DateTime now) {
    return Map.unmodifiable({
      for (final entry in startPressuresByFirefighterId.entries)
        entry.key: GdzsCalculator.calculateEstimatedPressureAfterElapsed(
          basePressure: entry.value,
          elapsed: now.difference(inclusionTime),
          cylinderVolume: cylinderVolume,
          cylindersCount: cylindersCount,
          workLoad: workLoad,
        ),
    });
  }

  void confirmArrival({
    required DateTime arrivalTime,
    required Map<int, int> arrivalPressures,
    required CompressedAirCalculationResult calculation,
  }) {
    if (_stage != ActiveTeamStage.advancing) {
      throw StateError('Прибуття можна підтвердити лише під час прямування.');
    }
    if (arrivalTime.isBefore(inclusionTime)) {
      throw ArgumentError('Час прибуття не може передувати включенню.');
    }

    _arrivalTime = arrivalTime;
    _arrivalPressuresByFirefighterId = Map.unmodifiable(arrivalPressures);
    _travelPressure = calculation.travelPressure;
    _exitPressure = calculation.exitPressure;
    _workingPressure = calculation.workingPressure;
    _workingTimeMinutes = calculation.workingTimeMinutes;
    _currentRemainingWorkMinutes = calculation.workingTimeMinutes;
    _initialPlannedExitTime = calculation.exitTime;
    _controllingFirefighterId =
        participants[calculation.controllingMemberIndex].id;
    _stage = ActiveTeamStage.working;
    _events.add(
      ActiveTeamEvent(
        time: arrivalTime,
        title: 'Ланка прибула до місця роботи',
      ),
    );
  }

  PressureCheck? get latestPressureCheck =>
      _pressureChecks.isEmpty ? null : _pressureChecks.last;

  Map<int, int> get latestPressuresByFirefighterId {
    final result = Map<int, int>.of(_arrivalPressuresByFirefighterId);
    for (final check in _pressureChecks) {
      result.addAll(check.pressuresByFirefighterId);
    }
    return Map.unmodifiable(result);
  }

  int get minimumActualPressure {
    final values = latestPressuresByFirefighterId.values;
    return values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b);
  }

  DateTime? get latestPressureCheckedAt =>
      latestPressureCheck?.checkedAt ?? _arrivalTime;

  Map<int, int> estimatedPressuresAt(DateTime now) {
    if (_arrivalTime == null) return estimatedAdvancingPressuresAt(now);
    final estimates = <int, int>{};
    for (final participant in participants) {
      final id = participant.id;
      if (id == null) continue;
      var basePressure = _arrivalPressuresByFirefighterId[id]!;
      var baseTime = _arrivalTime!;
      for (final check in _pressureChecks) {
        final value = check.pressuresByFirefighterId[id];
        if (value != null) {
          basePressure = value;
          baseTime = check.checkedAt;
        }
      }
      estimates[id] = GdzsCalculator.calculateEstimatedPressureAfterElapsed(
        basePressure: basePressure,
        elapsed: now.difference(baseTime),
        cylinderVolume: cylinderVolume,
        cylindersCount: cylindersCount,
        workLoad: workLoad,
      );
    }
    return Map.unmodifiable(estimates);
  }

  void addPressureCheck(PressureCheck check) {
    if (_stage != ActiveTeamStage.working &&
        _stage != ActiveTeamStage.exiting) {
      throw StateError('Контроль тиску недоступний на цьому етапі.');
    }
    _pressureChecks.add(check);
    int? controllingId;
    int? shortest;
    int? lowestPressure;
    for (final entry in check.pressuresByFirefighterId.entries) {
      final remaining = GdzsCalculator.calculateRemainingWorkTimeMinutes(
        currentPressure: entry.value,
        exitPressure: _exitPressure!,
        cylinderVolume: cylinderVolume,
        cylindersCount: cylindersCount,
        workLoad: workLoad,
      );
      if (shortest == null ||
          remaining < shortest ||
          (remaining == shortest && entry.value < lowestPressure!)) {
        controllingId = entry.key;
        shortest = remaining;
        lowestPressure = entry.value;
      }
    }
    _controllingFirefighterId = controllingId;
    _currentRemainingWorkMinutes = shortest ?? 0;
    _updatedPlannedExitTime = check.checkedAt.add(
      Duration(minutes: _currentRemainingWorkMinutes),
    );
  }

  Duration remainingUntilPlannedExit(DateTime now) {
    final planned = currentPlannedExitTime;
    if (planned == null) return Duration.zero;
    final result = planned.difference(now);
    return result.isNegative ? Duration.zero : result;
  }

  bool get hasExitPressureWarning =>
      _exitPressure != null && minimumActualPressure <= _exitPressure!;
  bool get hasApproachingExitPressureWarning =>
      _exitPressure != null &&
      minimumActualPressure > _exitPressure! &&
      minimumActualPressure - _exitPressure! <= 10;

  void startExit({required DateTime at}) {
    if (_stage != ActiveTeamStage.working) {
      throw StateError('Почати вихід можна лише з етапу роботи.');
    }
    _stage = ActiveTeamStage.exiting;
    _exitStartedAt = at;
    _events.add(
      ActiveTeamEvent(time: at, title: 'Ланка розпочала вихід із НДС'),
    );
  }

  void complete({required DateTime at}) {
    if (_stage != ActiveTeamStage.exiting) {
      throw StateError('Завершити роботу можна лише після початку виходу.');
    }
    _stage = ActiveTeamStage.completed;
    _completedAt = at;
    _events.add(
      ActiveTeamEvent(time: at, title: 'Ланка вийшла на свіже повітря'),
    );
  }

  Duration? get totalDuration => _completedAt?.difference(inclusionTime);
}
