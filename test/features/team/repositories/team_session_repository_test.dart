import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/models/stored_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/database/database_service.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/models/unit.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('stored session and enum values round-trip as stable text', () {
    final time = DateTime(2026, 7, 16, 10);
    final stored = StoredTeamSession(
      id: 1,
      unitId: 2,
      unitNameSnapshot: 'ДПРЧ-1',
      apparatusId: 3,
      apparatusNameSnapshot: 'Drager',
      apparatusWorkingPressure: 300,
      apparatusCylinderVolume: 6.8,
      apparatusCylindersCount: 1,
      apparatusReservePressure: 50,
      leaderFirefighterId: 10,
      workLoad: WorkLoad.medium,
      stage: ActiveTeamStage.advancing,
      inclusionTime: time,
      createdAt: time,
      updatedAt: time,
    );
    final restored = StoredTeamSession.fromMap(stored.toMap());
    expect(restored.stage, ActiveTeamStage.advancing);
    expect(restored.workLoad, WorkLoad.medium);
    expect(restored.inclusionTime, time);
    expect(activeTeamStageToStorage(ActiveTeamStage.exiting), 'exiting');
    expect(emergencyReasonToStorage(EmergencyReason.mayday), 'mayday');
    expect(
      emergencyReasonFromStorage('communicationLost'),
      EmergencyReason.communicationLost,
    );
  });

  test('v4 table migration preserves directory records', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute(
      'CREATE TABLE units(id INTEGER PRIMARY KEY, name TEXT, city TEXT)',
    );
    await db.execute(
      'CREATE TABLE apparatus(id INTEGER PRIMARY KEY, name TEXT)',
    );
    await db.execute(
      "CREATE TABLE firefighters(id INTEGER PRIMARY KEY, fullName TEXT, watch TEXT NOT NULL DEFAULT '')",
    );
    await db.insert('units', {'id': 1, 'name': 'ДПРЧ-1', 'city': 'Київ'});
    await db.insert('apparatus', {'id': 1, 'name': 'Drager'});
    await db.insert('firefighters', {
      'id': 1,
      'fullName': 'Іваненко',
      'watch': '2',
    });

    await DatabaseService.createTeamSessionTables(db);

    expect(await db.query('units'), hasLength(1));
    expect((await db.query('firefighters')).single['watch'], '2');
    expect(
      await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'team_sessions'",
      ),
      hasLength(1),
    );
  });

  group('TeamSessionRepository', () {
    late Database db;
    late TeamSessionRepository repository;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys = ON');
      await DatabaseService.createTeamSessionTables(db);
      repository = TeamSessionRepository(database: db);
    });
    tearDown(() => db.close());

    test('persists and restores complete active-session lifecycle', () async {
      final session = _advancing();
      final id = await repository.createAdvancingSession(
        unit: const Unit(id: 1, name: 'ДПРЧ-1', city: 'Київ'),
        apparatus: _apparatus,
        session: session,
      );
      final advancing = await repository.getActiveSession();
      expect(advancing!.id, id);
      expect(advancing.session.stage, ActiveTeamStage.advancing);
      expect(advancing.session.participants.map((e) => e.watchNumber), [
        1,
        2,
        3,
      ]);
      expect(advancing.watchLabel, 'Змішаний склад');

      final arrival = session.inclusionTime.add(const Duration(minutes: 5));
      const actualArrival = {1: 270, 2: 265, 3: 268};
      final calculation = GdzsCalculator.calculateCompressedAir(
        startPressures: const [300, 295, 298],
        arrivalPressures: const [270, 265, 268],
        inclusionTime: session.inclusionTime,
        arrivalTime: arrival,
        cylinderVolume: 6.8,
        cylindersCount: 1,
        reservePressure: 50,
        workLoad: WorkLoad.medium,
      );
      await repository.confirmArrival(
        sessionId: id,
        arrivalTime: arrival,
        pressures: actualArrival,
        calculation: calculation,
        controllingFirefighterId: 2,
      );
      var restored = (await repository.getById(id))!.session;
      expect(restored.stage, ActiveTeamStage.working);
      expect(restored.arrivalPressuresByFirefighterId, actualArrival);

      final checkedAt = arrival.add(const Duration(minutes: 4));
      const estimated = {1: 250, 2: 245, 3: 248};
      const actual = {1: 248, 2: 240, 3: 247};
      await repository.addPressureCheck(
        sessionId: id,
        checkedAt: checkedAt,
        estimated: estimated,
        actual: actual,
        emergencyMode: false,
      );
      final pressureRows = await db.query('team_pressure_check_members');
      expect(pressureRows.first['estimatedPressure'], 250);
      expect(pressureRows.first['actualPressure'], 248);
      restored = (await repository.getById(id))!.session;
      expect(restored.latestPressuresByFirefighterId, actual);
      expect(restored.estimatedPressuresAt(checkedAt)[2], 240);

      await repository.startExit(id, checkedAt.add(const Duration(minutes: 1)));
      expect(
        (await repository.getById(id))!.session.stage,
        ActiveTeamStage.exiting,
      );

      final emergencyAt = checkedAt.add(const Duration(minutes: 2));
      await repository.startEmergency(
        id,
        TeamEmergency(
          reason: EmergencyReason.communicationLost,
          startedAt: emergencyAt,
          stageAtStart: ActiveTeamStage.exiting,
          communicationAvailable: false,
          lastContactAt: null,
        ),
        'Втрачено зв’язок',
      );
      restored = (await repository.getById(id))!.session;
      expect(restored.stage, ActiveTeamStage.exiting);
      expect(restored.activeEmergency!.communicationAvailable, isFalse);

      await repository.restoreCommunication(
        id,
        emergencyAt.add(const Duration(minutes: 1)),
      );
      restored = (await repository.getById(id))!.session;
      expect(restored.activeEmergency!.communicationAvailable, isTrue);
      await repository.resolveEmergency(
        id,
        emergencyAt.add(const Duration(minutes: 2)),
        'Усунено',
      );
      restored = (await repository.getById(id))!.session;
      expect(restored.stage, ActiveTeamStage.exiting);
      expect(restored.hasActiveEmergency, isFalse);

      await repository.completeSession(
        id,
        emergencyAt.add(const Duration(minutes: 3)),
        fromEmergency: false,
      );
      expect(await repository.getActiveSession(), isNull);
      expect(
        (await repository.getById(id))!.session.stage,
        ActiveTeamStage.completed,
      );
      final events = (await repository.getById(id))!.session.events;
      expect(
        events.map((e) => e.time).toList(),
        orderedEquals([...events.map((e) => e.time)]..sort()),
      );
    });

    test('rejects a second active session', () async {
      final session = _advancing();
      await repository.createAdvancingSession(
        unit: const Unit(id: 1, name: 'A', city: 'B'),
        apparatus: _apparatus,
        session: session,
      );
      expect(
        () => repository.createAdvancingSession(
          unit: const Unit(id: 1, name: 'A', city: 'B'),
          apparatus: _apparatus,
          session: _advancing(),
        ),
        throwsStateError,
      );
    });

    group('completed history', () {
      late int newestId;
      late int oldestId;

      setUp(() async {
        oldestId = await _insertSession(
          db,
          stage: 'completed',
          unitName: 'Старий snapshot підрозділу',
          apparatusName: 'Старий snapshot апарата',
          inclusion: DateTime(2026, 7, 10, 8),
          completed: DateTime(2026, 7, 10, 9),
        );
        newestId = await _insertSession(
          db,
          stage: 'completed',
          unitName: 'Snapshot ДПРЧ-9',
          apparatusName: 'Snapshot Drager PSS',
          inclusion: DateTime(2026, 7, 16, 10),
          completed: DateTime(2026, 7, 16, 10, 42),
        );
        for (final stage in ['advancing', 'working', 'exiting']) {
          await _insertSession(
            db,
            stage: stage,
            unitName: stage,
            apparatusName: 'active',
            inclusion: DateTime(2026, 7, 16, 11),
          );
        }
        await db.insert('team_session_members', {
          'sessionId': newestId,
          'firefighterId': 11,
          'firefighterNameSnapshot': 'Snapshot Іваненко',
          'watchNumberSnapshot': 3,
          'isLeader': 1,
          'position': 0,
          'startPressure': 300,
          'arrivalPressure': 270,
        });
        await db.insert('team_session_members', {
          'sessionId': newestId,
          'firefighterId': 12,
          'firefighterNameSnapshot': 'Snapshot Петренко',
          'watchNumberSnapshot': 1,
          'isLeader': 0,
          'position': 1,
          'startPressure': 295,
          'arrivalPressure': 268,
        });
        final laterCheck = await db.insert('team_pressure_checks', {
          'sessionId': newestId,
          'checkedAt': DateTime(2026, 7, 16, 10, 25).toIso8601String(),
          'controllingFirefighterId': 11,
          'remainingWorkMinutes': 12,
          'plannedExitTimeAfterCheck': DateTime(
            2026,
            7,
            16,
            10,
            37,
          ).toIso8601String(),
          'emergencyMode': 0,
        });
        final earlierCheck = await db.insert('team_pressure_checks', {
          'sessionId': newestId,
          'checkedAt': DateTime(2026, 7, 16, 10, 20).toIso8601String(),
          'controllingFirefighterId': 12,
          'remainingWorkMinutes': 17,
          'plannedExitTimeAfterCheck': DateTime(
            2026,
            7,
            16,
            10,
            37,
          ).toIso8601String(),
          'emergencyMode': 1,
        });
        await db.insert('team_pressure_check_members', {
          'pressureCheckId': earlierCheck,
          'firefighterId': 11,
          'estimatedPressure': 251,
          'actualPressure': 246,
        });
        await db.insert('team_pressure_check_members', {
          'pressureCheckId': laterCheck,
          'firefighterId': 11,
          'estimatedPressure': 240,
          'actualPressure': 243,
        });
        await db.insert('team_emergencies', {
          'sessionId': newestId,
          'reason': 'mayday',
          'startedAt': DateTime(2026, 7, 16, 10, 22).toIso8601String(),
          'stageAtStart': 'working',
          'communicationAvailable': 1,
          'lastContactAt': DateTime(2026, 7, 16, 10, 24).toIso8601String(),
          'note': 'Snapshot note',
          'resolvedAt': DateTime(2026, 7, 16, 10, 30).toIso8601String(),
        });
        for (final event in [
          (DateTime(2026, 7, 16, 10, 30), 'Пізня подія'),
          (DateTime(2026, 7, 16, 10, 5), 'Рання подія'),
        ]) {
          await db.insert('team_session_events', {
            'sessionId': newestId,
            'eventTime': event.$1.toIso8601String(),
            'title': event.$2,
            'description': '',
          });
        }
      });

      test('getCompletedSessions returns completed sessions only', () async {
        final sessions = await repository.getCompletedSessions();
        expect(sessions, hasLength(2));
        expect(
          sessions.every((item) => item.stage == ActiveTeamStage.completed),
          isTrue,
        );
      });

      test('advancing, working and exiting are excluded', () async {
        final sessions = await repository.getCompletedSessions();
        expect(
          sessions.map((item) => item.unitName),
          isNot(contains('advancing')),
        );
        expect(
          sessions.map((item) => item.unitName),
          isNot(contains('working')),
        );
        expect(
          sessions.map((item) => item.unitName),
          isNot(contains('exiting')),
        );
      });

      test('completed sessions are sorted newest first', () async {
        final sessions = await repository.getCompletedSessions();
        expect(sessions.map((item) => item.databaseId), [newestId, oldestId]);
      });

      test('unit snapshot is restored without directory lookup', () async {
        final session = (await repository.getById(newestId))!.session;
        expect(session.unitName, 'Snapshot ДПРЧ-9');
      });

      test('apparatus snapshot is restored', () async {
        final session = (await repository.getById(newestId))!.session;
        expect(session.apparatusName, 'Snapshot Drager PSS');
      });

      test('member name and watch snapshots are restored', () async {
        final session = (await repository.getById(newestId))!.session;
        expect(session.participants.first.fullName, 'Snapshot Іваненко');
        expect(session.participants.first.watchNumber, 3);
      });

      test('pressure checks are restored chronologically', () async {
        final session = (await repository.getById(newestId))!.session;
        expect(
          session.pressureCheckDetails.map((item) => item.checkedAt.minute),
          [20, 25],
        );
      });

      test('estimated and actual pressures remain distinct', () async {
        final check = (await repository.getById(
          newestId,
        ))!.session.pressureCheckDetails.first;
        expect(check.estimatedPressuresByFirefighterId[11], 251);
        expect(check.actualPressuresByFirefighterId[11], 246);
      });

      test('resolved emergencies are restored with resolvedAt', () async {
        final emergency = (await repository.getById(
          newestId,
        ))!.session.emergencies.single;
        expect(emergency.reason, EmergencyReason.mayday);
        expect(emergency.resolvedAt, DateTime(2026, 7, 16, 10, 30));
      });

      test('events are restored chronologically', () async {
        final events = (await repository.getById(newestId))!.session.events;
        expect(events.map((item) => item.title), [
          'Рання подія',
          'Пізня подія',
        ]);
      });
    });
  });
}

Future<int> _insertSession(
  Database db, {
  required String stage,
  required String unitName,
  required String apparatusName,
  required DateTime inclusion,
  DateTime? completed,
}) => db.insert('team_sessions', {
  'unitId': 999,
  'unitNameSnapshot': unitName,
  'apparatusId': 999,
  'apparatusNameSnapshot': apparatusName,
  'apparatusWorkingPressure': 300,
  'apparatusCylinderVolume': 6.8,
  'apparatusCylindersCount': 1,
  'apparatusReservePressure': 50,
  'leaderFirefighterId': 11,
  'workLoad': 'medium',
  'stage': stage,
  'inclusionTime': inclusion.toIso8601String(),
  'arrivalTime': inclusion.add(const Duration(minutes: 5)).toIso8601String(),
  'initialPlannedExitTime': inclusion
      .add(const Duration(minutes: 35))
      .toIso8601String(),
  'currentPlannedExitTime': inclusion
      .add(const Duration(minutes: 37))
      .toIso8601String(),
  'travelPressure': 30,
  'exitPressure': 80,
  'workingPressure': 190,
  'workingTimeMinutes': 30,
  'controllingFirefighterId': 11,
  'exitStartedAt': completed
      ?.subtract(const Duration(minutes: 10))
      .toIso8601String(),
  'completedAt': completed?.toIso8601String(),
  'createdAt': inclusion.toIso8601String(),
  'updatedAt': (completed ?? inclusion).toIso8601String(),
});

const _apparatus = Apparatus(
  id: 1,
  name: 'Drager',
  workingPressure: 300,
  cylinderVolume: 6.8,
  cylindersCount: 1,
  reservePressure: 50,
);

ActiveTeamSession _advancing() {
  final time = DateTime(2026, 7, 16, 10);
  return ActiveTeamSession.advancing(
    unitName: 'ДПРЧ-1',
    apparatusName: 'Drager',
    participants: const [
      Firefighter(id: 1, fullName: 'А', watch: '1'),
      Firefighter(id: 2, fullName: 'Б', watch: '2'),
      Firefighter(id: 3, fullName: 'В', watch: '3'),
    ],
    leaderId: 1,
    startPressuresByFirefighterId: const {1: 300, 2: 295, 3: 298},
    inclusionTime: time,
    workLoad: WorkLoad.medium,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
    events: [ActiveTeamEvent(time: time, title: 'Ланка увімкнулася в ЗІЗОД')],
  );
}
