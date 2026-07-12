import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

enum ActiveTeamStatus { active, exiting, completed }

class PressureCheck {
  final DateTime checkedAt;
  final Map<int, int> pressuresByFirefighterId;

  PressureCheck({
    required this.checkedAt,
    required Map<int, int> pressuresByFirefighterId,
  }) : pressuresByFirefighterId = Map.unmodifiable(
         Map<int, int>.of(pressuresByFirefighterId),
       );
}

class ActiveTeamEvent {
  final DateTime time;
  final String title;
  final String description;

  const ActiveTeamEvent({
    required this.time,
    required this.title,
    required this.description,
  });
}

class ActiveTeamSession {
  final String unitName;
  final String apparatusName;
  final List<Firefighter> participants;
  final int leaderId;
  final Map<int, int> startPressuresByFirefighterId;
  final Map<int, int> arrivalPressuresByFirefighterId;
  final DateTime inclusionTime;
  final DateTime arrivalTime;
  final DateTime plannedExitTime;
  final int exitPressure;
  final int workingTimeMinutes;
  final WorkLoad workLoad;
  final double cylinderVolume;
  final int cylindersCount;

  ActiveTeamStatus _status;
  DateTime? _exitStartedAt;
  DateTime? _completedAt;
  final List<PressureCheck> _pressureChecks;
  final List<ActiveTeamEvent> _events;

  ActiveTeamSession({
    required this.unitName,
    required this.apparatusName,
    required List<Firefighter> participants,
    required this.leaderId,
    required Map<int, int> startPressuresByFirefighterId,
    required Map<int, int> arrivalPressuresByFirefighterId,
    required this.inclusionTime,
    required this.arrivalTime,
    required this.plannedExitTime,
    required this.exitPressure,
    required this.workingTimeMinutes,
    required this.workLoad,
    required this.cylinderVolume,
    required this.cylindersCount,
    ActiveTeamStatus status = ActiveTeamStatus.active,
    DateTime? exitStartedAt,
    DateTime? completedAt,
    List<PressureCheck> pressureChecks = const [],
    List<ActiveTeamEvent> events = const [],
  }) : participants = List.unmodifiable(List<Firefighter>.of(participants)),
       startPressuresByFirefighterId = Map.unmodifiable(
         Map<int, int>.of(startPressuresByFirefighterId),
       ),
       arrivalPressuresByFirefighterId = Map.unmodifiable(
         Map<int, int>.of(arrivalPressuresByFirefighterId),
       ),
       // Keep public constructor names while storing transition state privately.
       // ignore: prefer_initializing_formals
       _status = status,
       // ignore: prefer_initializing_formals
       _exitStartedAt = exitStartedAt,
       // ignore: prefer_initializing_formals
       _completedAt = completedAt,
       _pressureChecks = List<PressureCheck>.of(pressureChecks),
       _events = List<ActiveTeamEvent>.of(events);

  String get teamName => 'Ланка $unitName';

  ActiveTeamStatus get status => _status;

  DateTime? get exitStartedAt => _exitStartedAt;

  DateTime? get completedAt => _completedAt;

  List<PressureCheck> get pressureChecks => List.unmodifiable(_pressureChecks);

  List<ActiveTeamEvent> get events => List.unmodifiable(_events);

  PressureCheck? get latestPressureCheck {
    if (_pressureChecks.isEmpty) return null;

    var latest = _pressureChecks.first;
    for (final check in _pressureChecks.skip(1)) {
      if (check.checkedAt.isAfter(latest.checkedAt)) {
        latest = check;
      }
    }
    return latest;
  }

  Map<int, int> get latestPressuresByFirefighterId {
    final pressures = Map<int, int>.of(arrivalPressuresByFirefighterId);
    final checks = List<PressureCheck>.of(_pressureChecks)
      ..sort((first, second) => first.checkedAt.compareTo(second.checkedAt));

    for (final check in checks) {
      pressures.addAll(check.pressuresByFirefighterId);
    }

    return Map.unmodifiable(pressures);
  }

  int? latestPressureForFirefighter(int firefighterId) {
    return latestPressuresByFirefighterId[firefighterId];
  }

  int get minimumActualPressure {
    final pressures = latestPressuresByFirefighterId.values;
    if (pressures.isEmpty) return 0;

    var minimum = pressures.first;
    for (final pressure in pressures.skip(1)) {
      if (pressure < minimum) {
        minimum = pressure;
      }
    }
    return minimum;
  }

  DateTime get latestPressureCheckedAt {
    return latestPressureCheck?.checkedAt ?? arrivalTime;
  }

  Duration remainingUntilPlannedExit(DateTime now) {
    final remaining = plannedExitTime.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration? get totalDuration {
    final completedAt = _completedAt;
    if (completedAt == null) return null;

    final duration = completedAt.difference(inclusionTime);
    return duration.isNegative ? Duration.zero : duration;
  }

  bool get hasExitPressureWarning => minimumActualPressure <= exitPressure;

  bool get hasApproachingExitPressureWarning {
    final difference = minimumActualPressure - exitPressure;
    return difference > 0 && difference <= 10;
  }

  void addPressureCheck(PressureCheck pressureCheck) {
    _pressureChecks.add(pressureCheck);
  }

  void addEvent(ActiveTeamEvent event) {
    _events.add(event);
  }

  void startExiting({required DateTime at}) {
    if (_status != ActiveTeamStatus.active) {
      throw StateError('Почати вихід можна лише для активної ланки.');
    }

    _status = ActiveTeamStatus.exiting;
    _exitStartedAt = at;
    _events.add(
      ActiveTeamEvent(
        time: at,
        title: 'Ланка розпочала вихід',
        description: 'Зафіксовано початок виходу ланки.',
      ),
    );
  }

  void complete({required DateTime at}) {
    if (_status != ActiveTeamStatus.exiting) {
      throw StateError('Завершити роботу можна лише після початку виходу.');
    }

    _status = ActiveTeamStatus.completed;
    _completedAt = at;
    _events.add(
      ActiveTeamEvent(
        time: at,
        title: 'Ланка вийшла на свіже повітря',
        description: 'Зафіксовано завершення роботи ланки.',
      ),
    );
  }
}
