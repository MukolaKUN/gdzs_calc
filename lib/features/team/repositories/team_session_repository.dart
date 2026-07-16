import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/models/stored_team_session.dart';
import 'package:gdzs_calc/shared/database/database_service.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/models/unit.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';
import 'package:sqflite/sqflite.dart';

class TeamSessionRecord {
  final int id;
  final ActiveTeamSession session;
  final int? watchNumber;
  const TeamSessionRecord({
    required this.id,
    required this.session,
    this.watchNumber,
  });
}

class TeamSessionRepository {
  final Database? database;
  const TeamSessionRepository({this.database});

  Future<Database> get _database async => database ?? DatabaseService.database;

  Future<int> createAdvancingSession({
    required Unit unit,
    required Apparatus apparatus,
    required ActiveTeamSession session,
  }) async {
    final db = await _database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'team_sessions',
        columns: ['id'],
        where: "stage IN ('advancing','working','exiting')",
        limit: 1,
      );
      if (existing.isNotEmpty) throw StateError('Уже є активна ланка.');
      final now = DateTime.now();
      final id = await txn.insert('team_sessions', {
        'unitId': unit.id!,
        'unitNameSnapshot': unit.name,
        'apparatusId': apparatus.id!,
        'apparatusNameSnapshot': apparatus.name,
        'apparatusWorkingPressure': apparatus.workingPressure,
        'apparatusCylinderVolume': apparatus.cylinderVolume,
        'apparatusCylindersCount': apparatus.cylindersCount,
        'apparatusReservePressure': apparatus.reservePressure,
        'leaderFirefighterId': session.leaderId,
        'workLoad': workLoadToStorage(session.workLoad),
        'stage': activeTeamStageToStorage(ActiveTeamStage.advancing),
        'inclusionTime': session.inclusionTime.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      for (
        var position = 0;
        position < session.participants.length;
        position++
      ) {
        final member = session.participants[position];
        await txn.insert('team_session_members', {
          'sessionId': id,
          'firefighterId': member.id!,
          'firefighterNameSnapshot': member.fullName,
          'watchNumberSnapshot': member.watchNumber,
          'isLeader': member.id == session.leaderId ? 1 : 0,
          'position': position,
          'startPressure': session.startPressuresByFirefighterId[member.id]!,
        });
      }
      final event = session.events.first;
      await _insertEvent(txn, id, event);
      return id;
    });
  }

  Future<TeamSessionRecord?> getActiveSession() async {
    final db = await _database;
    final rows = await db.query(
      'team_sessions',
      columns: ['id'],
      where: "stage IN ('advancing','working','exiting')",
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : getById(rows.first['id'] as int);
  }

  Future<TeamSessionRecord?> getById(int id) async {
    final db = await _database;
    final sessionRows = await db.query(
      'team_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (sessionRows.isEmpty) return null;
    final stored = StoredTeamSession.fromMap(sessionRows.single);
    final memberRows = await db.query(
      'team_session_members',
      where: 'sessionId = ?',
      whereArgs: [id],
      orderBy: 'position',
    );
    final members = memberRows
        .map(
          (row) => StoredTeamSessionMember(
            firefighterId: row['firefighterId'] as int,
            name: row['firefighterNameSnapshot'] as String,
            watchNumber: row['watchNumberSnapshot'] as int?,
            isLeader: row['isLeader'] == 1,
            position: row['position'] as int,
            startPressure: row['startPressure'] as int,
            arrivalPressure: row['arrivalPressure'] as int?,
          ),
        )
        .toList();
    final eventRows = await db.query(
      'team_session_events',
      where: 'sessionId = ?',
      whereArgs: [id],
      orderBy: 'eventTime, id',
    );
    final events = eventRows
        .map(
          (row) => ActiveTeamEvent(
            time: DateTime.parse(row['eventTime'] as String),
            title: row['title'] as String,
            description: row['description'] as String,
          ),
        )
        .toList();
    final checkRows = await db.query(
      'team_pressure_checks',
      where: 'sessionId = ?',
      whereArgs: [id],
      orderBy: 'checkedAt, id',
    );
    final checks = <PressureCheck>[];
    for (final row in checkRows) {
      final values = await db.query(
        'team_pressure_check_members',
        where: 'pressureCheckId = ?',
        whereArgs: [row['id']],
      );
      checks.add(
        PressureCheck(
          checkedAt: DateTime.parse(row['checkedAt'] as String),
          pressuresByFirefighterId: {
            for (final value in values)
              value['firefighterId'] as int: value['actualPressure'] as int,
          },
        ),
      );
    }
    final emergencyRows = await db.query(
      'team_emergencies',
      where: 'sessionId = ? AND resolvedAt IS NULL',
      whereArgs: [id],
      orderBy: 'startedAt DESC',
      limit: 1,
    );
    TeamEmergency? emergency;
    if (emergencyRows.isNotEmpty) {
      final row = emergencyRows.single;
      emergency = TeamEmergency(
        reason: emergencyReasonFromStorage(row['reason'] as String),
        startedAt: DateTime.parse(row['startedAt'] as String),
        stageAtStart: activeTeamStageFromStorage(row['stageAtStart'] as String),
        communicationAvailable: row['communicationAvailable'] == 1,
        lastContactAt: row['lastContactAt'] == null
            ? null
            : DateTime.parse(row['lastContactAt'] as String),
        note: row['note'] as String?,
      );
    }
    final participants = members
        .map(
          (member) => Firefighter(
            id: member.firefighterId,
            fullName: member.name,
            watch: member.watchNumber?.toString() ?? '',
          ),
        )
        .toList();
    final session = ActiveTeamSession.restored(
      unitName: stored.unitNameSnapshot,
      apparatusName: stored.apparatusNameSnapshot,
      participants: participants,
      leaderId: stored.leaderFirefighterId,
      startPressuresByFirefighterId: {
        for (final member in members)
          member.firefighterId: member.startPressure,
      },
      inclusionTime: stored.inclusionTime,
      workLoad: stored.workLoad,
      cylinderVolume: stored.apparatusCylinderVolume,
      cylindersCount: stored.apparatusCylindersCount,
      reservePressure: stored.apparatusReservePressure,
      stage: stored.stage,
      arrivalTime: stored.arrivalTime,
      arrivalPressuresByFirefighterId: {
        for (final member in members)
          if (member.arrivalPressure != null)
            member.firefighterId: member.arrivalPressure!,
      },
      initialPlannedExitTime: stored.initialPlannedExitTime,
      currentPlannedExitTime: stored.currentPlannedExitTime,
      exitStartedAt: stored.exitStartedAt,
      completedAt: stored.completedAt,
      travelPressure: stored.travelPressure,
      exitPressure: stored.exitPressure,
      workingPressure: stored.workingPressure,
      workingTimeMinutes: stored.workingTimeMinutes,
      controllingFirefighterId: stored.controllingFirefighterId,
      pressureChecks: checks,
      events: events,
      activeEmergency: emergency,
    );
    return TeamSessionRecord(
      id: id,
      session: session,
      watchNumber: members.isEmpty ? null : members.first.watchNumber,
    );
  }

  Future<void> confirmArrival({
    required int sessionId,
    required DateTime arrivalTime,
    required Map<int, int> pressures,
    required CompressedAirCalculationResult calculation,
    required int controllingFirefighterId,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'team_sessions',
        {
          'stage': 'working',
          'arrivalTime': arrivalTime.toIso8601String(),
          'initialPlannedExitTime': calculation.exitTime.toIso8601String(),
          'currentPlannedExitTime': calculation.exitTime.toIso8601String(),
          'travelPressure': calculation.travelPressure,
          'exitPressure': calculation.exitPressure,
          'workingPressure': calculation.workingPressure,
          'workingTimeMinutes': calculation.workingTimeMinutes,
          'controllingFirefighterId': controllingFirefighterId,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      for (final entry in pressures.entries) {
        await txn.update(
          'team_session_members',
          {'arrivalPressure': entry.value},
          where: 'sessionId = ? AND firefighterId = ?',
          whereArgs: [sessionId, entry.key],
        );
      }
      await _insertEvent(
        txn,
        sessionId,
        ActiveTeamEvent(
          time: arrivalTime,
          title: 'Ланка прибула до місця роботи',
        ),
      );
    });
  }

  Future<void> addPressureCheck({
    required int sessionId,
    required DateTime checkedAt,
    required Map<int, int> estimated,
    required Map<int, int> actual,
    required bool emergencyMode,
  }) async {
    final record = await getById(sessionId);
    if (record == null) throw StateError('Сесію не знайдено.');
    final session = record.session;
    final check = PressureCheck(
      checkedAt: checkedAt,
      pressuresByFirefighterId: actual,
    );
    final advancingEmergency =
        emergencyMode && session.stage == ActiveTeamStage.advancing;
    if (advancingEmergency) {
      // Before arrival there is no planned exit time yet.
    } else if (emergencyMode) {
      session.addEmergencyPressureCheck(check);
    } else {
      session.addPressureCheck(check);
    }
    final controllingId = advancingEmergency
        ? actual.entries.reduce((a, b) => a.value <= b.value ? a : b).key
        : session.controllingFirefighterId!;
    final remainingMinutes = advancingEmergency
        ? 0
        : session.currentRemainingWorkMinutes;
    final plannedExit = advancingEmergency
        ? checkedAt
        : session.currentPlannedExitTime!;
    final db = await _database;
    await db.transaction((txn) async {
      final checkId = await txn.insert('team_pressure_checks', {
        'sessionId': sessionId,
        'checkedAt': checkedAt.toIso8601String(),
        'controllingFirefighterId': controllingId,
        'remainingWorkMinutes': remainingMinutes,
        'plannedExitTimeAfterCheck': plannedExit.toIso8601String(),
        'emergencyMode': emergencyMode ? 1 : 0,
      });
      for (final entry in actual.entries) {
        await txn.insert('team_pressure_check_members', {
          'pressureCheckId': checkId,
          'firefighterId': entry.key,
          'estimatedPressure': estimated[entry.key]!,
          'actualPressure': entry.value,
        });
      }
      await txn.update(
        'team_sessions',
        {
          'controllingFirefighterId': controllingId,
          if (!advancingEmergency) 'workingTimeMinutes': remainingMinutes,
          if (!advancingEmergency)
            'currentPlannedExitTime': plannedExit.toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      if (emergencyMode) {
        await txn.update(
          'team_emergencies',
          {'lastContactAt': checkedAt.toIso8601String()},
          where: 'sessionId = ? AND resolvedAt IS NULL',
          whereArgs: [sessionId],
        );
      }
      await _insertEvent(
        txn,
        sessionId,
        ActiveTeamEvent(
          time: checkedAt,
          title: emergencyMode
              ? 'Проведено контроль тиску в аварійному режимі'
              : 'Проведено контроль тиску',
        ),
      );
    });
  }

  Future<void> startExit(int sessionId, DateTime at) => _transition(sessionId, {
    'stage': 'exiting',
    'exitStartedAt': at.toIso8601String(),
  }, ActiveTeamEvent(time: at, title: 'Ланка розпочала вихід із НДС'));

  Future<void> completeSession(
    int sessionId,
    DateTime at, {
    required bool fromEmergency,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'team_sessions',
        {
          'stage': 'completed',
          'completedAt': at.toIso8601String(),
          'updatedAt': at.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await txn.update(
        'team_emergencies',
        {'resolvedAt': at.toIso8601String()},
        where: 'sessionId = ? AND resolvedAt IS NULL',
        whereArgs: [sessionId],
      );
      await _insertEvent(
        txn,
        sessionId,
        ActiveTeamEvent(time: at, title: 'Ланка вийшла на свіже повітря'),
      );
      if (fromEmergency) {
        await _insertEvent(
          txn,
          sessionId,
          ActiveTeamEvent(
            time: at,
            title: 'Аварійний режим завершено виходом ланки',
          ),
        );
      }
    });
  }

  Future<void> startEmergency(
    int sessionId,
    TeamEmergency emergency,
    String description,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('team_emergencies', {
        'sessionId': sessionId,
        'reason': emergencyReasonToStorage(emergency.reason),
        'startedAt': emergency.startedAt.toIso8601String(),
        'stageAtStart': activeTeamStageToStorage(emergency.stageAtStart),
        'communicationAvailable': emergency.communicationAvailable ? 1 : 0,
        'lastContactAt': emergency.lastContactAt?.toIso8601String(),
        'note': emergency.note,
      });
      await _insertEvent(
        txn,
        sessionId,
        ActiveTeamEvent(
          time: emergency.startedAt,
          title: 'Увімкнено аварійний режим',
          description: description,
        ),
      );
    });
  }

  Future<void> restoreCommunication(int sessionId, DateTime at) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'team_emergencies',
        {'communicationAvailable': 1, 'lastContactAt': at.toIso8601String()},
        where: 'sessionId = ? AND resolvedAt IS NULL',
        whereArgs: [sessionId],
      );
      await _insertEvent(
        txn,
        sessionId,
        ActiveTeamEvent(time: at, title: 'Зв’язок із ланкою відновлено'),
      );
    });
  }

  Future<void> resolveEmergency(
    int sessionId,
    DateTime at,
    String description,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'team_emergencies',
        {'resolvedAt': at.toIso8601String()},
        where: 'sessionId = ? AND resolvedAt IS NULL',
        whereArgs: [sessionId],
      );
      await _insertEvent(
        txn,
        sessionId,
        ActiveTeamEvent(
          time: at,
          title: 'Аварійний режим завершено',
          description: description,
        ),
      );
    });
  }

  Future<void> addEmergencyAction(
    int sessionId,
    DateTime at,
    String title,
  ) async {
    final db = await _database;
    await _insertEvent(db, sessionId, ActiveTeamEvent(time: at, title: title));
  }

  Future<void> deleteSession(int sessionId) async {
    final db = await _database;
    await db.delete('team_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<void> _transition(
    int id,
    Map<String, Object?> values,
    ActiveTeamEvent event,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'team_sessions',
        {...values, 'updatedAt': event.time.toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _insertEvent(txn, id, event);
    });
  }

  static Future<void> _insertEvent(
    DatabaseExecutor db,
    int sessionId,
    ActiveTeamEvent event,
  ) {
    return db.insert('team_session_events', {
      'sessionId': sessionId,
      'eventTime': event.time.toIso8601String(),
      'title': event.title,
      'description': event.description,
    });
  }
}
