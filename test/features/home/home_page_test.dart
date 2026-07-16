import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/home/home_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  testWidgets('shows restored active session and blocks second team', (
    tester,
  ) async {
    final repository = _HomeRepository(_session());
    await tester.pumpWidget(
      MaterialApp(home: HomePage(repository: repository)),
    );
    await tester.pump();

    expect(find.text('Активна ланка'), findsOneWidget);
    expect(find.text('Відкрити активну ланку'), findsOneWidget);
    await tester.tap(find.text('СТВОРИТИ ЛАНКУ'));
    await tester.pumpAndSettle();
    expect(find.text('Уже є активна ланка'), findsOneWidget);
    expect(repository.createCalls, 0);
  });
}

class _HomeRepository extends TeamSessionRepository {
  final ActiveTeamSession session;
  int createCalls = 0;
  _HomeRepository(this.session);

  @override
  Future<TeamSessionRecord?> getActiveSession() async =>
      TeamSessionRecord(id: 7, session: session, watchNumber: 1);
}

ActiveTeamSession _session() {
  final time = DateTime(2026, 7, 16, 10);
  return ActiveTeamSession.advancing(
    unitName: 'ДПРЧ-1',
    apparatusName: 'Drager',
    participants: const [
      Firefighter(id: 1, fullName: 'А', watch: '1'),
      Firefighter(id: 2, fullName: 'Б', watch: '1'),
    ],
    leaderId: 1,
    startPressuresByFirefighterId: const {1: 300, 2: 295},
    inclusionTime: time,
    workLoad: WorkLoad.medium,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
    events: [ActiveTeamEvent(time: time, title: 'Ланка увімкнулася в ЗІЗОД')],
  );
}
