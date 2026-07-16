import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/history/history_page.dart';
import 'package:gdzs_calc/features/history/team_history_details_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  final now = DateTime(2026, 7, 16, 15);

  testWidgets('empty history shows the required empty state', (tester) async {
    await _pumpHistory(tester, _HistoryRepository([]), now);
    expect(find.text('Історія поки порожня'), findsOneWidget);
    expect(
      find.text('Завершені ланки з’являться тут після виходу на свіже повітря'),
      findsOneWidget,
    );
  });

  testWidgets('completed session is shown in history', (tester) async {
    await _pumpHistory(tester, _HistoryRepository([_session(1, now)]), now);
    expect(find.byKey(const ValueKey('history-session-1')), findsOneWidget);
    expect(find.text('ДПРЧ-1 · 1-й караул'), findsOneWidget);
  });

  testWidgets('active session is not shown in normal history', (tester) async {
    final active = _session(1, now, stage: ActiveTeamStage.working);
    await _pumpHistory(tester, _HistoryRepository([active]), now);
    expect(find.byKey(const ValueKey('history-session-1')), findsNothing);
  });

  testWidgets('emergency session has a badge', (tester) async {
    await _pumpHistory(
      tester,
      _HistoryRepository([_session(1, now, emergency: true)]),
      now,
    );
    expect(find.text('Була надзвичайна ситуація'), findsOneWidget);
  });

  testWidgets('today filter hides older sessions', (tester) async {
    await _pumpHistory(
      tester,
      _HistoryRepository([
        _session(1, now),
        _session(2, now.subtract(const Duration(days: 1))),
      ]),
      now,
    );
    _changeFilter<HistoryPeriod>(
      tester,
      const Key('history-period-filter'),
      HistoryPeriod.today,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('history-session-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-session-2')), findsNothing);
  });

  testWidgets('seven day filter uses the inclusive seven-day window', (
    tester,
  ) async {
    await _pumpHistory(
      tester,
      _HistoryRepository([
        _session(1, now.subtract(const Duration(days: 6))),
        _session(2, now.subtract(const Duration(days: 7))),
      ]),
      now,
    );
    _changeFilter<HistoryPeriod>(
      tester,
      const Key('history-period-filter'),
      HistoryPeriod.sevenDays,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('history-session-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-session-2')), findsNothing);
  });

  testWidgets('watch filter shows matching snapshots only', (tester) async {
    await _pumpHistory(
      tester,
      _HistoryRepository([
        _session(1, now, watch: '1'),
        _session(2, now, watch: '3'),
      ]),
      now,
    );
    _changeFilter<int>(tester, const Key('history-watch-filter'), 3);
    await tester.pump();
    expect(find.byKey(const ValueKey('history-session-1')), findsNothing);
    expect(find.byKey(const ValueKey('history-session-2')), findsOneWidget);
  });

  testWidgets('emergency filter separates emergency sessions', (tester) async {
    await _pumpHistory(
      tester,
      _HistoryRepository([_session(1, now, emergency: true), _session(2, now)]),
      now,
    );
    _changeFilter<HistoryEmergencyFilter>(
      tester,
      const Key('history-emergency-filter'),
      HistoryEmergencyFilter.withEmergency,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('history-session-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-session-2')), findsNothing);
  });

  testWidgets('tapping a card opens details', (tester) async {
    final session = _session(1, now);
    await _pumpHistory(tester, _HistoryRepository([session]), now);
    await tester.tap(find.byKey(const ValueKey('history-session-1')));
    await tester.pumpAndSettle();
    expect(find.text('Деталі ланки'), findsOneWidget);
    expect(find.text('Завершено'), findsOneWidget);
  });

  testWidgets('details show participants and time points', (tester) async {
    await _pumpDetails(tester, _session(1, now));
    expect(find.text('Snapshot Іваненко'), findsWidgets);
    expect(find.text('Включення в ЗІЗОД'), findsOneWidget);
    expect(find.text('Вихід на свіже повітря'), findsOneWidget);
    expect(find.text('Командир'), findsWidgets);
  });

  testWidgets('details show estimated and actual pressure checks', (
    tester,
  ) async {
    await _pumpDetails(tester, _session(1, now, withCheck: true));
    await _expand(tester, 'Контроль тиску');
    expect(find.text('Розрахунковий тиск'), findsNWidgets(2));
    expect(find.text('250 бар'), findsOneWidget);
    expect(find.text('245 бар'), findsWidgets);
    expect(find.text('Вища витрата: -5 бар'), findsOneWidget);
  });

  testWidgets('details show resolved emergency information', (tester) async {
    await _pumpDetails(tester, _session(1, now, emergency: true));
    await _expand(tester, 'Надзвичайні ситуації');
    expect(find.text('Сигнал MAYDAY'), findsOneWidget);
    expect(find.text('Перевірочна примітка'), findsOneWidget);
    expect(find.text('8 хв'), findsOneWidget);
  });

  testWidgets('missing nullable values are shown as not recorded', (
    tester,
  ) async {
    await _pumpDetails(tester, _session(1, now, missingTimes: true));
    expect(find.text('Не зафіксовано'), findsWidgets);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('loading errors show retry buttons', (tester) async {
    final repository = _HistoryRepository(
      [],
      failList: true,
      failDetails: true,
    );
    await _pumpHistory(tester, repository, now);
    expect(find.text('Не вдалося завантажити історію'), findsOneWidget);
    expect(find.text('Повторити'), findsOneWidget);

    await _pumpDetails(tester, _session(1, now), repository: repository);
    expect(find.text('Не вдалося завантажити дані ланки'), findsOneWidget);
    expect(find.text('Повторити'), findsOneWidget);
  });

  testWidgets('history and details produce no Flutter exceptions', (
    tester,
  ) async {
    final session = _session(1, now, emergency: true, withCheck: true);
    await _pumpHistory(tester, _HistoryRepository([session]), now);
    await tester.tap(find.byKey(const ValueKey('history-session-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void _changeFilter<T>(WidgetTester tester, Key key, T value) {
  final field = tester.widget<DropdownButtonFormField<T>>(find.byKey(key));
  field.onChanged!(value);
}

Future<void> _expand(WidgetTester tester, String title) async {
  final finder = find.text(title);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpHistory(
  WidgetTester tester,
  TeamSessionRepository repository,
  DateTime now,
) async {
  _largeView(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: HistoryPage(repository: repository, now: () => now),
    ),
  );
  await tester.pump();
}

Future<void> _pumpDetails(
  WidgetTester tester,
  ActiveTeamSession session, {
  TeamSessionRepository? repository,
}) async {
  _largeView(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: TeamHistoryDetailsPage(
        sessionId: session.databaseId!,
        repository: repository ?? _HistoryRepository([session]),
      ),
    ),
  );
  await tester.pump();
}

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ActiveTeamSession _session(
  int id,
  DateTime completedAt, {
  String watch = '1',
  ActiveTeamStage stage = ActiveTeamStage.completed,
  bool emergency = false,
  bool withCheck = false,
  bool missingTimes = false,
}) {
  final inclusion = completedAt.subtract(const Duration(minutes: 42));
  final arrival = missingTimes
      ? null
      : inclusion.add(const Duration(minutes: 7));
  final exit = missingTimes
      ? null
      : completedAt.subtract(const Duration(minutes: 9));
  final emergencies = emergency
      ? [
          TeamEmergency(
            reason: EmergencyReason.mayday,
            startedAt: completedAt.subtract(const Duration(minutes: 18)),
            stageAtStart: ActiveTeamStage.working,
            communicationAvailable: true,
            lastContactAt: completedAt.subtract(const Duration(minutes: 11)),
            note: 'Перевірочна примітка',
            resolvedAt: completedAt.subtract(const Duration(minutes: 10)),
          ),
        ]
      : <TeamEmergency>[];
  final checkAt = completedAt.subtract(const Duration(minutes: 20));
  return ActiveTeamSession.restored(
    databaseId: id,
    unitName: 'ДПРЧ-$id',
    apparatusName: 'Snapshot Drager',
    participants: [
      Firefighter(id: 11, fullName: 'Snapshot Іваненко', watch: watch),
      Firefighter(id: 12, fullName: 'Snapshot Петренко', watch: watch),
    ],
    leaderId: 11,
    startPressuresByFirefighterId: const {11: 300, 12: 295},
    inclusionTime: inclusion,
    workLoad: WorkLoad.medium,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
    stage: stage,
    arrivalTime: arrival,
    arrivalPressuresByFirefighterId: missingTimes
        ? const {}
        : const {11: 270, 12: 268},
    initialPlannedExitTime: arrival?.add(const Duration(minutes: 30)),
    currentPlannedExitTime: arrival?.add(const Duration(minutes: 28)),
    exitStartedAt: exit,
    completedAt: completedAt,
    travelPressure: missingTimes ? null : 30,
    exitPressure: missingTimes ? null : 80,
    workingPressure: missingTimes ? null : 190,
    workingTimeMinutes: missingTimes ? null : 28,
    controllingFirefighterId: missingTimes ? null : 11,
    pressureChecks: withCheck
        ? [
            PressureCheck(
              checkedAt: checkAt,
              pressuresByFirefighterId: const {11: 245, 12: 244},
            ),
          ]
        : const [],
    pressureCheckDetails: withCheck
        ? [
            PressureCheckDetails(
              checkedAt: checkAt,
              controllingFirefighterId: 11,
              remainingWorkMinutes: 12,
              plannedExitTimeAfterCheck: checkAt.add(
                const Duration(minutes: 12),
              ),
              emergencyMode: emergency,
              estimatedPressuresByFirefighterId: const {11: 250, 12: 247},
              actualPressuresByFirefighterId: const {11: 245, 12: 247},
            ),
          ]
        : const [],
    events: [
      ActiveTeamEvent(time: inclusion, title: 'Включення'),
      ActiveTeamEvent(time: completedAt, title: 'Завершення'),
    ],
    emergencies: emergencies,
  );
}

class _HistoryRepository extends TeamSessionRepository {
  final List<ActiveTeamSession> sessions;
  final bool failList;
  final bool failDetails;

  _HistoryRepository(
    this.sessions, {
    this.failList = false,
    this.failDetails = false,
  });

  @override
  Future<List<ActiveTeamSession>> getCompletedSessions() async {
    if (failList) throw StateError('test failure');
    return sessions;
  }

  @override
  Future<TeamSessionRecord?> getById(int id) async {
    if (failDetails) throw StateError('test failure');
    final session = sessions.where((item) => item.databaseId == id).firstOrNull;
    return session == null ? null : TeamSessionRecord(id: id, session: session);
  }
}
