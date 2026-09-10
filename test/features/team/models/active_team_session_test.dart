import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  group('ActiveTeamSession stages', () {
    test(
      'starts advancing with real inclusion time and unknown arrival data',
      () {
        final inclusion = DateTime(2026, 7, 16, 10);
        final session = _advancing(inclusion);

        expect(session.stage, ActiveTeamStage.advancing);
        expect(session.inclusionTime, inclusion);
        expect(session.arrivalTime, isNull);
        expect(session.initialPlannedExitTime, isNull);
        expect(session.currentPlannedExitTime, isNull);
      },
    );

    test('advancing duration is measured from inclusion time', () {
      final inclusion = DateTime(2026, 7, 16, 10);
      final session = _advancing(inclusion);

      expect(
        session.advancingDurationAt(inclusion.add(const Duration(seconds: 95))),
        const Duration(seconds: 95),
      );
    });

    test('advancing pressure estimate decreases with elapsed time', () {
      final inclusion = DateTime(2026, 7, 16, 10);
      final session = _advancing(inclusion);

      final initial = session.estimatedAdvancingPressuresAt(inclusion)[1]!;
      final later = session.estimatedAdvancingPressuresAt(
        inclusion.add(const Duration(minutes: 5)),
      )[1]!;
      expect(later, lessThan(initial));
    });

    test('confirmArrival stores actual values and calculation', () {
      final inclusion = DateTime(2026, 7, 16, 10);
      final arrival = inclusion.add(const Duration(minutes: 5));
      final session = _advancing(inclusion);
      final calculation = _calculation(inclusion, arrival);

      session.confirmArrival(
        arrivalTime: arrival,
        arrivalPressures: const {1: 270, 2: 265},
        calculation: calculation,
      );

      expect(session.stage, ActiveTeamStage.working);
      expect(session.arrivalTime, arrival);
      expect(session.arrivalPressuresByFirefighterId, {1: 270, 2: 265});
      expect(session.exitPressure, calculation.exitPressure);
      expect(session.workingTimeMinutes, calculation.workingTimeMinutes);
      expect(session.currentPlannedExitTime, calculation.exitTime);
      expect(session.controllingFirefighterId, 2);
    });

    test('working transitions to exiting and exiting to completed', () {
      final session = _working();
      final exitAt = DateTime(2026, 7, 16, 10, 20);
      final completedAt = DateTime(2026, 7, 16, 10, 25);

      session.startExit(at: exitAt);
      expect(session.stage, ActiveTeamStage.exiting);
      expect(session.exitStartedAt, exitAt);

      session.complete(at: completedAt);
      expect(session.stage, ActiveTeamStage.completed);
      expect(session.completedAt, completedAt);
      expect(session.totalDuration, const Duration(minutes: 25));
    });

    test('advancing cannot jump to exiting or completed', () {
      final session = _advancing(DateTime(2026, 7, 16, 10));
      expect(
        () => session.startExit(at: DateTime(2026, 7, 16, 10, 1)),
        throwsStateError,
      );
      expect(
        () => session.complete(at: DateTime(2026, 7, 16, 10, 2)),
        throwsStateError,
      );
    });

    test('pressure check uses last actual pressure and updates countdown', () {
      final session = _working();
      final checkedAt = DateTime(2026, 7, 16, 10, 10);
      final before = session.currentPlannedExitTime;

      session.addPressureCheck(
        PressureCheck(
          checkedAt: checkedAt,
          pressuresByFirefighterId: const {1: 210, 2: 200},
        ),
      );

      expect(session.latestPressuresByFirefighterId, {1: 210, 2: 200});
      expect(session.controllingFirefighterId, 2);
      expect(session.currentPlannedExitTime, isNot(before));
      expect(
        session.estimatedPressuresAt(
          checkedAt.add(const Duration(minutes: 2)),
        )[2],
        lessThan(200),
      );
    });
  });

  group('ActiveTeamSession emergency mode', () {
    test('can start on advancing without changing the stage', () {
      final session = _advancing(DateTime(2026, 7, 16, 10));
      session.startEmergency(
        reason: EmergencyReason.communicationLost,
        at: DateTime(2026, 7, 16, 10, 1),
        communicationAvailable: true,
      );

      expect(session.stage, ActiveTeamStage.advancing);
      expect(session.hasActiveEmergency, isTrue);
      expect(session.activeEmergency!.communicationAvailable, isFalse);
    });

    test('can start on working and resolve to the same stage', () {
      final session = _working();
      final startedAt = DateTime(2026, 7, 16, 10, 10);
      session.startEmergency(
        reason: EmergencyReason.mayday,
        at: startedAt,
        communicationAvailable: true,
      );
      expect(session.stage, ActiveTeamStage.working);

      session.resolveEmergency(at: startedAt.add(const Duration(minutes: 3)));
      expect(session.stage, ActiveTeamStage.working);
      expect(session.hasActiveEmergency, isFalse);
    });

    test('can start on exiting and never returns to working', () {
      final session = _working();
      session.startExit(at: DateTime(2026, 7, 16, 10, 10));
      session.startEmergency(
        reason: EmergencyReason.collapseOrBlockedRoute,
        at: DateTime(2026, 7, 16, 10, 11),
        communicationAvailable: true,
      );
      expect(session.activeEmergency!.stageAtStart, ActiveTeamStage.exiting);

      session.resolveEmergency(at: DateTime(2026, 7, 16, 10, 12));
      expect(session.stage, ActiveTeamStage.exiting);
    });

    test('restoring communication updates last contact and event log', () {
      final session = _advancing(DateTime(2026, 7, 16, 10));
      session.startEmergency(
        reason: EmergencyReason.communicationLost,
        at: DateTime(2026, 7, 16, 10, 1),
        communicationAvailable: false,
      );
      final restoredAt = DateTime(2026, 7, 16, 10, 2);
      session.restoreEmergencyCommunication(at: restoredAt);

      expect(session.activeEmergency!.communicationAvailable, isTrue);
      expect(session.activeEmergency!.lastContactAt, restoredAt);
      expect(
        session.events.map((event) => event.title),
        contains('Зв’язок із ланкою відновлено'),
      );
    });

    test('emergency pressure control records actual values and contact', () {
      final session = _working();
      session.startEmergency(
        reason: EmergencyReason.firefighterInjury,
        at: DateTime(2026, 7, 16, 10, 8),
        communicationAvailable: true,
      );
      final checkedAt = DateTime(2026, 7, 16, 10, 9);
      session.addEmergencyPressureCheck(
        PressureCheck(
          checkedAt: checkedAt,
          pressuresByFirefighterId: const {1: 230, 2: 220},
        ),
      );

      expect(session.latestPressuresByFirefighterId, {1: 230, 2: 220});
      expect(session.activeEmergency!.lastContactAt, checkedAt);
      expect(
        session.events.map((event) => event.title),
        contains('Проведено контроль тиску в аварійному режимі'),
      );
    });

    test('actual pressure control is rejected while communication is lost', () {
      final session = _working();
      session.startEmergency(
        reason: EmergencyReason.communicationLost,
        at: DateTime(2026, 7, 16, 10, 8),
        communicationAvailable: false,
      );

      expect(
        () => session.addEmergencyPressureCheck(
          PressureCheck(
            checkedAt: DateTime(2026, 7, 16, 10, 9),
            pressuresByFirefighterId: const {1: 230, 2: 220},
          ),
        ),
        throwsStateError,
      );
      expect(session.pressureChecks, isEmpty);
    });

    test('completion resolves emergency and writes both events', () {
      final session = _working();
      session.startEmergency(
        reason: EmergencyReason.disorientation,
        at: DateTime(2026, 7, 16, 10, 8),
        communicationAvailable: true,
      );
      session.completeFromEmergency(at: DateTime(2026, 7, 16, 10, 12));

      expect(session.stage, ActiveTeamStage.completed);
      expect(session.hasActiveEmergency, isFalse);
      expect(
        session.events.map((event) => event.title),
        containsAll([
          'Ланка вийшла на свіже повітря',
          'Аварійний режим завершено виходом ланки',
        ]),
      );
    });

    test('emergency activation event contains operational details', () {
      final session = _working();
      session.startEmergency(
        reason: EmergencyReason.breathingApparatusFailure,
        at: DateTime(2026, 7, 16, 10, 8),
        communicationAvailable: true,
        note: 'Другий номер',
      );

      final event = session.events.last;
      expect(event.title, 'Увімкнено аварійний режим');
      expect(event.description, contains('Етап: робота'));
      expect(event.description, contains('Зв’язок із ланкою наявний'));
      expect(event.description, contains('Другий номер'));
    });
  });
}

const _members = [
  Firefighter(id: 1, fullName: 'Перший', watch: '1'),
  Firefighter(id: 2, fullName: 'Другий', watch: '1'),
];

ActiveTeamSession _advancing(DateTime inclusion) {
  return ActiveTeamSession.advancing(
    unitName: 'ДПРЧ-1',
    apparatusName: 'Drager',
    participants: _members,
    leaderId: 1,
    startPressuresByFirefighterId: const {1: 300, 2: 295},
    inclusionTime: inclusion,
    workLoad: WorkLoad.medium,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
    events: [
      ActiveTeamEvent(time: inclusion, title: 'Ланка увімкнулася в ЗІЗОД'),
    ],
  );
}

CompressedAirCalculationResult _calculation(
  DateTime inclusion,
  DateTime arrival,
) {
  return GdzsCalculator.calculateCompressedAir(
    startPressures: const [300, 295],
    arrivalPressures: const [270, 265],
    inclusionTime: inclusion,
    arrivalTime: arrival,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
    workLoad: WorkLoad.medium,
  );
}

ActiveTeamSession _working() {
  final inclusion = DateTime(2026, 7, 16, 10);
  final arrival = inclusion.add(const Duration(minutes: 5));
  final session = _advancing(inclusion);
  session.confirmArrival(
    arrivalTime: arrival,
    arrivalPressures: const {1: 270, 2: 265},
    calculation: _calculation(inclusion, arrival),
  );
  return session;
}
