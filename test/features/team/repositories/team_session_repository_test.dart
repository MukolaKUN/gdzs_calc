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
        2,
        2,
        2,
      ]);

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
  });
}

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
      Firefighter(id: 1, fullName: 'А', watch: '2'),
      Firefighter(id: 2, fullName: 'Б', watch: '2'),
      Firefighter(id: 3, fullName: 'В', watch: '2'),
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
