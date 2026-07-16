import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

String activeTeamStageToStorage(ActiveTeamStage value) => value.name;
ActiveTeamStage activeTeamStageFromStorage(String value) =>
    ActiveTeamStage.values.byName(value);
String emergencyReasonToStorage(EmergencyReason value) => value.name;
EmergencyReason emergencyReasonFromStorage(String value) =>
    EmergencyReason.values.byName(value);
String workLoadToStorage(WorkLoad value) => value.name;
WorkLoad workLoadFromStorage(String value) => WorkLoad.values.byName(value);

class StoredTeamSession {
  final int? id;
  final int unitId;
  final String unitNameSnapshot;
  final int apparatusId;
  final String apparatusNameSnapshot;
  final int apparatusWorkingPressure;
  final double apparatusCylinderVolume;
  final int apparatusCylindersCount;
  final int apparatusReservePressure;
  final int leaderFirefighterId;
  final WorkLoad workLoad;
  final ActiveTeamStage stage;
  final DateTime inclusionTime;
  final DateTime? arrivalTime;
  final DateTime? initialPlannedExitTime;
  final DateTime? currentPlannedExitTime;
  final int? travelPressure;
  final int? exitPressure;
  final int? workingPressure;
  final int? workingTimeMinutes;
  final int? controllingFirefighterId;
  final DateTime? exitStartedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StoredTeamSession({
    this.id,
    required this.unitId,
    required this.unitNameSnapshot,
    required this.apparatusId,
    required this.apparatusNameSnapshot,
    required this.apparatusWorkingPressure,
    required this.apparatusCylinderVolume,
    required this.apparatusCylindersCount,
    required this.apparatusReservePressure,
    required this.leaderFirefighterId,
    required this.workLoad,
    required this.stage,
    required this.inclusionTime,
    this.arrivalTime,
    this.initialPlannedExitTime,
    this.currentPlannedExitTime,
    this.travelPressure,
    this.exitPressure,
    this.workingPressure,
    this.workingTimeMinutes,
    this.controllingFirefighterId,
    this.exitStartedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'unitId': unitId,
    'unitNameSnapshot': unitNameSnapshot,
    'apparatusId': apparatusId,
    'apparatusNameSnapshot': apparatusNameSnapshot,
    'apparatusWorkingPressure': apparatusWorkingPressure,
    'apparatusCylinderVolume': apparatusCylinderVolume,
    'apparatusCylindersCount': apparatusCylindersCount,
    'apparatusReservePressure': apparatusReservePressure,
    'leaderFirefighterId': leaderFirefighterId,
    'workLoad': workLoadToStorage(workLoad),
    'stage': activeTeamStageToStorage(stage),
    'inclusionTime': inclusionTime.toIso8601String(),
    'arrivalTime': arrivalTime?.toIso8601String(),
    'initialPlannedExitTime': initialPlannedExitTime?.toIso8601String(),
    'currentPlannedExitTime': currentPlannedExitTime?.toIso8601String(),
    'travelPressure': travelPressure,
    'exitPressure': exitPressure,
    'workingPressure': workingPressure,
    'workingTimeMinutes': workingTimeMinutes,
    'controllingFirefighterId': controllingFirefighterId,
    'exitStartedAt': exitStartedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StoredTeamSession.fromMap(Map<String, Object?> map) {
    DateTime? optional(String key) =>
        map[key] == null ? null : DateTime.parse(map[key]! as String);
    return StoredTeamSession(
      id: map['id'] as int?,
      unitId: map['unitId'] as int,
      unitNameSnapshot: map['unitNameSnapshot'] as String,
      apparatusId: map['apparatusId'] as int,
      apparatusNameSnapshot: map['apparatusNameSnapshot'] as String,
      apparatusWorkingPressure: map['apparatusWorkingPressure'] as int,
      apparatusCylinderVolume: (map['apparatusCylinderVolume'] as num)
          .toDouble(),
      apparatusCylindersCount: map['apparatusCylindersCount'] as int,
      apparatusReservePressure: map['apparatusReservePressure'] as int,
      leaderFirefighterId: map['leaderFirefighterId'] as int,
      workLoad: workLoadFromStorage(map['workLoad'] as String),
      stage: activeTeamStageFromStorage(map['stage'] as String),
      inclusionTime: DateTime.parse(map['inclusionTime'] as String),
      arrivalTime: optional('arrivalTime'),
      initialPlannedExitTime: optional('initialPlannedExitTime'),
      currentPlannedExitTime: optional('currentPlannedExitTime'),
      travelPressure: map['travelPressure'] as int?,
      exitPressure: map['exitPressure'] as int?,
      workingPressure: map['workingPressure'] as int?,
      workingTimeMinutes: map['workingTimeMinutes'] as int?,
      controllingFirefighterId: map['controllingFirefighterId'] as int?,
      exitStartedAt: optional('exitStartedAt'),
      completedAt: optional('completedAt'),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class StoredTeamSessionMember {
  final int firefighterId;
  final String name;
  final int? watchNumber;
  final bool isLeader;
  final int position;
  final int startPressure;
  final int? arrivalPressure;
  const StoredTeamSessionMember({
    required this.firefighterId,
    required this.name,
    this.watchNumber,
    required this.isLeader,
    required this.position,
    required this.startPressure,
    this.arrivalPressure,
  });
}

class StoredPressureCheck {
  final int id;
  final DateTime checkedAt;
  final int controllingFirefighterId;
  final int remainingWorkMinutes;
  final DateTime plannedExitTimeAfterCheck;
  final bool emergencyMode;
  final List<StoredPressureCheckMember> members;
  const StoredPressureCheck({
    required this.id,
    required this.checkedAt,
    required this.controllingFirefighterId,
    required this.remainingWorkMinutes,
    required this.plannedExitTimeAfterCheck,
    required this.emergencyMode,
    required this.members,
  });
}

class StoredPressureCheckMember {
  final int firefighterId;
  final int estimatedPressure;
  final int actualPressure;
  const StoredPressureCheckMember({
    required this.firefighterId,
    required this.estimatedPressure,
    required this.actualPressure,
  });
}

class StoredTeamEvent {
  final DateTime time;
  final String title;
  final String description;
  const StoredTeamEvent({
    required this.time,
    required this.title,
    required this.description,
  });
}

class StoredTeamEmergency {
  final int? id;
  final EmergencyReason reason;
  final DateTime startedAt;
  final ActiveTeamStage stageAtStart;
  final bool communicationAvailable;
  final DateTime? lastContactAt;
  final String? note;
  final DateTime? resolvedAt;
  const StoredTeamEmergency({
    this.id,
    required this.reason,
    required this.startedAt,
    required this.stageAtStart,
    required this.communicationAvailable,
    this.lastContactAt,
    this.note,
    this.resolvedAt,
  });
}
