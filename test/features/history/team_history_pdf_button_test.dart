import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/history/team_history_details_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  testWidgets('completed session has PDF button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TeamHistoryDetailsPage(
          sessionId: 1,
          repository: _FakeRepository(_session(completed: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('create-pdf-report'));
    for (var i = 0; i < 8 && button.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
    }
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('unfinished session has no PDF button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TeamHistoryDetailsPage(
          sessionId: 1,
          repository: _FakeRepository(_session(completed: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-pdf-report')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository extends TeamSessionRepository {
  final ActiveTeamSession value;
  const _FakeRepository(this.value);
  @override
  Future<TeamSessionRecord?> getById(int id) async =>
      TeamSessionRecord(id: id, session: value);
}

ActiveTeamSession _session({required bool completed}) {
  final start = DateTime(2026, 7, 20, 10);
  return ActiveTeamSession.restored(
    databaseId: 1,
    unitName: 'ДПРЧ-1',
    apparatusName: 'АЦ',
    participants: const [
      Firefighter(id: 1, fullName: 'Іваненко Іван', watch: '1'),
    ],
    leaderId: 1,
    startPressuresByFirefighterId: const {1: 300},
    inclusionTime: start,
    workLoad: WorkLoad.medium,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
    stage: completed ? ActiveTeamStage.completed : ActiveTeamStage.advancing,
    arrivalTime: completed ? start.add(const Duration(minutes: 5)) : null,
    arrivalPressuresByFirefighterId: completed ? const {1: 280} : const {},
    initialPlannedExitTime: null,
    currentPlannedExitTime: null,
    exitStartedAt: null,
    completedAt: completed ? start.add(const Duration(minutes: 20)) : null,
    travelPressure: null,
    exitPressure: null,
    workingPressure: null,
    workingTimeMinutes: null,
    controllingFirefighterId: null,
    pressureChecks: const [],
    events: const [],
  );
}
