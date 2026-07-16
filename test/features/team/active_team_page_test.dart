import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_check_sheet.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  testWidgets('advancing, working, exiting and completed have distinct UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = _session();
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveTeamPage(
          sessionId: 1,
          repository: _MemoryRepository(session),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ланка прямує до місця роботи'), findsOneWidget);
    expect(find.text('Час прямування'), findsOneWidget);

    await tester.ensureVisible(find.text('Підтвердити прибуття'));
    await tester.pump();
    await tester.tap(find.text('Підтвердити прибуття'));
    await tester.pumpAndSettle();
    expect(find.text('Контроль тиску'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.tap(find.text('Підтвердити замір'));
    await tester.pumpAndSettle();
    expect(session.stage, ActiveTeamStage.working);
    expect(find.text('До початку виходу з НДС'), findsOneWidget);

    await tester.ensureVisible(find.text('Розпочати вихід із НДС'));
    await tester.pump();
    await tester.tap(find.text('Розпочати вихід із НДС'));
    await tester.pumpAndSettle();
    expect(find.text('Підтвердити початок виходу?'), findsOneWidget);
    await tester.tap(find.text('Розпочати вихід'));
    await tester.pumpAndSettle();

    expect(session.stage, ActiveTeamStage.exiting);
    expect(find.text('Ланка виходить із НДС'), findsOneWidget);
    expect(find.text('До початку виходу з НДС'), findsNothing);
    await tester.ensureVisible(find.text('Ланка вийшла на свіже повітря'));
    await tester.pump();
    await tester.tap(find.text('Ланка вийшла на свіже повітря'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Підтвердити вихід'));
    await tester.pumpAndSettle();

    expect(session.stage, ActiveTeamStage.completed);
    expect(find.text('Роботу ланки завершено'), findsOneWidget);
    expect(find.text('Дані ланки збережено'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final stage in [
    ActiveTeamStage.advancing,
    ActiveTeamStage.working,
    ActiveTeamStage.exiting,
  ]) {
    testWidgets('emergency button is available on ${stage.name}', (
      tester,
    ) async {
      _setLargeView(tester);
      final session = _sessionAt(stage);
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveTeamPage(
            sessionId: 1,
            repository: _MemoryRepository(session),
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Надзвичайна ситуація'));
      expect(find.text('Надзвичайна ситуація'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('lost communication shows estimates and blocks pressure sheet', (
    tester,
  ) async {
    _setLargeView(tester);
    final session = _session();
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveTeamPage(
          sessionId: 1,
          repository: _MemoryRepository(session),
        ),
      ),
    );
    await tester.pump();
    await _activateLostCommunication(tester);

    expect(find.text('АВАРІЙНИЙ РЕЖИМ'), findsOneWidget);
    expect(
      find.text(
        'Зв’язок із ланкою відсутній. Значення тиску є лише розрахунковими',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Розрахунковий тиск'), findsNWidgets(2));
    expect(find.text('Провести контроль тиску'), findsNothing);
    expect(find.byType(PressureCheckSheet), findsNothing);
    expect(session.pressureChecks, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('restored communication immediately allows actual control', (
    tester,
  ) async {
    _setLargeView(tester);
    final session = _session();
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveTeamPage(
          sessionId: 1,
          repository: _MemoryRepository(session),
        ),
      ),
    );
    await tester.pump();
    await _activateLostCommunication(tester);

    await tester.ensureVisible(find.text('Зв’язок відновлено'));
    await tester.tap(find.text('Зв’язок відновлено'));
    await tester.pumpAndSettle();
    expect(find.byType(PressureCheckSheet), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.ensureVisible(find.text('Підтвердити замір'));
    await tester.tap(find.text('Підтвердити замір'));
    await tester.pumpAndSettle();

    expect(session.pressureChecks, hasLength(1));
    expect(session.activeEmergency!.communicationAvailable, isTrue);
    expect(find.text('Провести контроль тиску'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resolving emergency returns to ordinary exiting UI', (
    tester,
  ) async {
    _setLargeView(tester);
    final session = _sessionAt(ActiveTeamStage.exiting);
    session.startEmergency(
      reason: EmergencyReason.mayday,
      at: DateTime.now(),
      communicationAvailable: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveTeamPage(
          sessionId: 1,
          repository: _MemoryRepository(session),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Надзвичайну ситуацію усунено'));
    await tester.tap(find.text('Надзвичайну ситуацію усунено'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Підтвердити'));
    await tester.pumpAndSettle();

    expect(session.stage, ActiveTeamStage.exiting);
    expect(session.hasActiveEmergency, isFalse);
    expect(find.text('Ланка виходить із НДС'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fresh-air button completes team and emergency', (tester) async {
    _setLargeView(tester);
    final session = _session();
    session.startEmergency(
      reason: EmergencyReason.communicationLost,
      at: DateTime.now(),
      communicationAvailable: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveTeamPage(
          sessionId: 1,
          repository: _MemoryRepository(session),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Ланка вийшла на свіже повітря'));
    await tester.tap(find.text('Ланка вийшла на свіже повітря'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Підтвердити вихід'));
    await tester.pumpAndSettle();

    expect(session.stage, ActiveTeamStage.completed);
    expect(session.hasActiveEmergency, isFalse);
    expect(find.text('Роботу ланки завершено'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _setLargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _activateLostCommunication(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Надзвичайна ситуація'));
  await tester.tap(find.text('Надзвичайна ситуація'));
  await tester.pumpAndSettle();
  expect(find.text('Зафіксувати надзвичайну ситуацію'), findsOneWidget);
  await tester.tap(find.text('Далі'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Увімкнути'));
  await tester.pumpAndSettle();
}

ActiveTeamSession _session() {
  final inclusion = DateTime.now().subtract(const Duration(minutes: 5));
  return ActiveTeamSession.advancing(
    unitName: 'ДПРЧ-1',
    apparatusName: 'Drager',
    participants: const [
      Firefighter(id: 1, fullName: 'Перший', watch: '1'),
      Firefighter(id: 2, fullName: 'Другий', watch: '1'),
    ],
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

ActiveTeamSession _sessionAt(ActiveTeamStage stage) {
  final session = _session();
  if (stage == ActiveTeamStage.advancing) return session;
  final arrival = DateTime.now().subtract(const Duration(minutes: 3));
  final ids = session.participants.map((member) => member.id!).toList();
  final pressures = const {1: 270, 2: 265};
  session.confirmArrival(
    arrivalTime: arrival,
    arrivalPressures: pressures,
    calculation: GdzsCalculator.calculateCompressedAir(
      startPressures: [
        for (final id in ids) session.startPressuresByFirefighterId[id]!,
      ],
      arrivalPressures: [for (final id in ids) pressures[id]!],
      inclusionTime: session.inclusionTime,
      arrivalTime: arrival,
      cylinderVolume: session.cylinderVolume,
      cylindersCount: session.cylindersCount,
      reservePressure: session.reservePressure,
      workLoad: session.workLoad,
    ),
  );
  if (stage == ActiveTeamStage.exiting) {
    session.startExit(at: DateTime.now().subtract(const Duration(minutes: 1)));
  }
  return session;
}

class _MemoryRepository extends TeamSessionRepository {
  final ActiveTeamSession value;
  _MemoryRepository(this.value);

  @override
  Future<TeamSessionRecord?> getById(int id) async =>
      TeamSessionRecord(id: id, session: value, watchNumber: 1);

  @override
  Future<void> confirmArrival({
    required int sessionId,
    required DateTime arrivalTime,
    required Map<int, int> pressures,
    required CompressedAirCalculationResult calculation,
    required int controllingFirefighterId,
  }) async {
    value.confirmArrival(
      arrivalTime: arrivalTime,
      arrivalPressures: pressures,
      calculation: calculation,
    );
  }

  @override
  Future<void> addPressureCheck({
    required int sessionId,
    required DateTime checkedAt,
    required Map<int, int> estimated,
    required Map<int, int> actual,
    required bool emergencyMode,
  }) async {
    final check = PressureCheck(
      checkedAt: checkedAt,
      pressuresByFirefighterId: actual,
    );
    if (emergencyMode) {
      value.addEmergencyPressureCheck(check);
    } else {
      value.addPressureCheck(check);
    }
  }

  @override
  Future<void> startExit(int sessionId, DateTime at) async {
    value.startExit(at: at);
  }

  @override
  Future<void> completeSession(
    int sessionId,
    DateTime at, {
    required bool fromEmergency,
  }) async {
    if (fromEmergency) {
      value.completeFromEmergency(at: at);
    } else {
      value.complete(at: at);
    }
  }

  @override
  Future<void> startEmergency(
    int sessionId,
    TeamEmergency emergency,
    String description,
  ) async {
    value.startEmergency(
      reason: emergency.reason,
      at: emergency.startedAt,
      communicationAvailable: emergency.communicationAvailable,
      note: emergency.note,
    );
  }

  @override
  Future<void> restoreCommunication(int sessionId, DateTime at) async {
    value.restoreEmergencyCommunication(at: at);
  }

  @override
  Future<void> resolveEmergency(
    int sessionId,
    DateTime at,
    String description,
  ) async {
    value.resolveEmergency(at: at);
  }

  @override
  Future<void> addEmergencyAction(
    int sessionId,
    DateTime at,
    String title,
  ) async {
    value.recordEmergencyAction(at: at, title: title);
  }
}
