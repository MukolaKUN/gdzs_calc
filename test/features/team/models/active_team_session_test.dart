import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  group('ActiveTeamSession', () {
    test('creates an active in-memory session with all calculation data', () {
      final session = _createSession();

      expect(session.teamName, 'Ланка 1 ДПРЧ');
      expect(session.unitName, '1 ДПРЧ');
      expect(session.apparatusName, 'Drager PSS 4000');
      expect(session.participants, hasLength(3));
      expect(session.leaderId, 1);
      expect(session.startPressuresByFirefighterId, {1: 300, 2: 295, 3: 290});
      expect(session.arrivalPressuresByFirefighterId, {1: 265, 2: 260, 3: 250});
      expect(session.inclusionTime, DateTime(2026, 7, 12, 10));
      expect(session.arrivalTime, DateTime(2026, 7, 12, 10, 6));
      expect(session.plannedExitTime, DateTime(2026, 7, 12, 10, 30));
      expect(session.exitPressure, 90);
      expect(session.workingTimeMinutes, 24);
      expect(session.workLoad, WorkLoad.medium);
      expect(session.cylinderVolume, 6);
      expect(session.cylindersCount, 1);
      expect(session.status, ActiveTeamStatus.active);
      expect(session.pressureChecks, isEmpty);
      expect(session.events, isEmpty);
    });

    test(
      'uses arrival pressures until a newer pressure check is available',
      () {
        final session = _createSession();

        expect(session.latestPressureCheck, isNull);
        expect(session.latestPressureCheckedAt, session.arrivalTime);
        expect(session.latestPressuresByFirefighterId, {
          1: 265,
          2: 260,
          3: 250,
        });
        expect(session.latestPressureForFirefighter(2), 260);

        final newerCheck = PressureCheck(
          checkedAt: DateTime(2026, 7, 12, 10, 20),
          pressuresByFirefighterId: const {1: 210, 2: 205, 3: 200},
        );
        session.addPressureCheck(newerCheck);
        session.addPressureCheck(
          PressureCheck(
            checkedAt: DateTime(2026, 7, 12, 10, 12),
            pressuresByFirefighterId: const {1: 240, 2: 235, 3: 230},
          ),
        );

        expect(session.latestPressureCheck, same(newerCheck));
        expect(session.latestPressureCheckedAt, newerCheck.checkedAt);
        expect(session.latestPressuresByFirefighterId, {
          1: 210,
          2: 205,
          3: 200,
        });
        expect(session.latestPressureForFirefighter(3), 200);
      },
    );

    test('calculates the minimum from latest confirmed pressures', () {
      final session = _createSession();

      expect(session.minimumActualPressure, 250);

      session.addPressureCheck(
        PressureCheck(
          checkedAt: DateTime(2026, 7, 12, 10, 15),
          pressuresByFirefighterId: const {1: 220, 2: 215, 3: 205},
        ),
      );

      expect(session.minimumActualPressure, 205);
    });

    test('moves active to exiting to completed and records timed events', () {
      final session = _createSession();
      final exitStartedAt = DateTime(2026, 7, 12, 10, 28);
      final completedAt = DateTime(2026, 7, 12, 10, 36);

      session.startExiting(at: exitStartedAt);

      expect(session.status, ActiveTeamStatus.exiting);
      expect(session.exitStartedAt, exitStartedAt);
      expect(session.events, hasLength(1));
      expect(session.events.single.time, exitStartedAt);
      expect(session.events.single.title, 'Ланка розпочала вихід');

      session.complete(at: completedAt);

      expect(session.status, ActiveTeamStatus.completed);
      expect(session.completedAt, completedAt);
      expect(session.events, hasLength(2));
      expect(session.events.last.time, completedAt);
      expect(session.events.last.title, 'Ланка вийшла на свіже повітря');
      expect(session.totalDuration, const Duration(minutes: 36));
    });

    test('rejects status transitions that skip or repeat a state', () {
      final session = _createSession();

      expect(
        () => session.complete(at: DateTime(2026, 7, 12, 10, 30)),
        throwsStateError,
      );

      session.startExiting(at: DateTime(2026, 7, 12, 10, 30));

      expect(
        () => session.startExiting(at: DateTime(2026, 7, 12, 10, 31)),
        throwsStateError,
      );
    });

    test('remaining duration never becomes negative', () {
      final session = _createSession();

      expect(
        session.remainingUntilPlannedExit(DateTime(2026, 7, 12, 10, 25)),
        const Duration(minutes: 5),
      );
      expect(
        session.remainingUntilPlannedExit(DateTime(2026, 7, 12, 10, 30)),
        Duration.zero,
      );
      expect(
        session.remainingUntilPlannedExit(DateTime(2026, 7, 12, 10, 40)),
        Duration.zero,
      );
    });

    test('distinguishes approaching and reached exit pressure', () {
      final session = _createSession();

      expect(session.hasExitPressureWarning, isFalse);
      expect(session.hasApproachingExitPressureWarning, isFalse);

      session.addPressureCheck(
        PressureCheck(
          checkedAt: DateTime(2026, 7, 12, 10, 20),
          pressuresByFirefighterId: const {1: 105, 2: 100, 3: 95},
        ),
      );

      expect(session.minimumActualPressure, 95);
      expect(session.hasExitPressureWarning, isFalse);
      expect(session.hasApproachingExitPressureWarning, isTrue);

      session.addPressureCheck(
        PressureCheck(
          checkedAt: DateTime(2026, 7, 12, 10, 25),
          pressuresByFirefighterId: const {1: 100, 2: 95, 3: 90},
        ),
      );

      expect(session.minimumActualPressure, 90);
      expect(session.hasExitPressureWarning, isTrue);
      expect(session.hasApproachingExitPressureWarning, isFalse);
    });
  });
}

ActiveTeamSession _createSession() {
  return ActiveTeamSession(
    unitName: '1 ДПРЧ',
    apparatusName: 'Drager PSS 4000',
    participants: const [
      Firefighter(id: 1, fullName: 'Андрій Бойко', watch: '1'),
      Firefighter(id: 2, fullName: 'Олег Коваль', watch: '1'),
      Firefighter(id: 3, fullName: 'Максим Лисенко', watch: '1'),
    ],
    leaderId: 1,
    startPressuresByFirefighterId: const {1: 300, 2: 295, 3: 290},
    arrivalPressuresByFirefighterId: const {1: 265, 2: 260, 3: 250},
    inclusionTime: DateTime(2026, 7, 12, 10),
    arrivalTime: DateTime(2026, 7, 12, 10, 6),
    plannedExitTime: DateTime(2026, 7, 12, 10, 30),
    exitPressure: 90,
    workingTimeMinutes: 24,
    workLoad: WorkLoad.medium,
    cylinderVolume: 6,
    cylindersCount: 1,
  );
}
