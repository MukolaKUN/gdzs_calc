import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/repositories/exit_warning_settings_repository.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';
import 'package:gdzs_calc/shared/services/haptic_gateway.dart';

void main() {
  final base = DateTime(2026, 7, 16, 10);

  for (final scenario in [
    (const Duration(minutes: 6), ExitWarningLevel.normal, null),
    (
      const Duration(minutes: 5),
      ExitWarningLevel.fiveMinutes,
      'Підготуйте ланку до виходу',
    ),
    (
      const Duration(minutes: 2),
      ExitWarningLevel.twoMinutes,
      'Наближається час виходу',
    ),
    (
      const Duration(minutes: 1),
      ExitWarningLevel.oneMinute,
      'До виходу менше хвилини',
    ),
    (
      Duration.zero,
      ExitWarningLevel.exitNow,
      'Настав час початку виходу з НДС',
    ),
  ]) {
    testWidgets('${scenario.$2.name} has the expected visual timer state', (
      tester,
    ) async {
      await _pumpWarningPage(
        tester,
        _workingSession(base.add(scenario.$1)),
        now: () => base,
      );
      expect(
        find.byKey(Key('exit-warning-${scenario.$2.name}')),
        findsOneWidget,
      );
      if (scenario.$3 != null) expect(find.text(scenario.$3!), findsOneWidget);
      if (scenario.$2 == ExitWarningLevel.exitNow) {
        expect(find.text('00:00'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pressure control updates timer and warning level', (
    tester,
  ) async {
    var now = DateTime.now();
    final session = _workingSession(now.add(const Duration(minutes: 10)));
    await _pumpWarningPage(tester, session, now: () => now);
    expect(find.byKey(const Key('exit-warning-normal')), findsOneWidget);
    await tester.ensureVisible(find.text('Контроль тиску'));
    await tester.tap(find.text('Контроль тиску'));
    await tester.pumpAndSettle();
    for (final field in find.byType(TextFormField).evaluate()) {
      await tester.enterText(find.byWidget(field.widget), '50');
    }
    await tester.tap(find.text('Підтвердити замір'));
    await tester.pumpAndSettle();
    expect(session.currentRemainingWorkMinutes, 0);
    now = session.currentPlannedExitTime!.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('exit-warning-exitNow')), findsOneWidget);
  });

  testWidgets('haptic threshold is not repeated every second', (tester) async {
    final haptic = _FakeHaptic();
    await _pumpWarningPage(
      tester,
      _workingSession(base.add(const Duration(minutes: 2))),
      now: () => base,
      haptic: haptic,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(haptic.heavyCount, 1);
  });

  testWidgets('exiting stage does not show exit warning countdown', (
    tester,
  ) async {
    await _pumpWarningPage(tester, _exitingSession(base), now: () => base);
    expect(find.text('До початку виходу з НДС'), findsNothing);
    expect(find.text('Ланка виходить із НДС'), findsOneWidget);
  });

  testWidgets('denied notification permission keeps visual UI working', (
    tester,
  ) async {
    final gateway = _FakeNotificationGateway(enabled: false);
    await _pumpWarningPage(
      tester,
      _workingSession(base.add(const Duration(minutes: 5))),
      now: () => base,
      gateway: gateway,
    );
    expect(find.text('Системні сповіщення вимкнені'), findsOneWidget);
    expect(find.text('Підготуйте ланку до виходу'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpWarningPage(
  WidgetTester tester,
  ActiveTeamSession session, {
  required DateTime Function() now,
  _FakeHaptic? haptic,
  _FakeNotificationGateway? gateway,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final notifications = gateway ?? _FakeNotificationGateway();
  await tester.pumpWidget(
    MaterialApp(
      home: ActiveTeamPage(
        sessionId: 1,
        repository: _WarningRepository(session),
        exitWarningService: ExitWarningService(notifications),
        notificationGateway: notifications,
        warningSettingsRepository: _FakeSettingsRepository(),
        hapticGateway: haptic ?? _FakeHaptic(),
        now: now,
      ),
    ),
  );
  await tester.pump();
}

ActiveTeamSession _workingSession(DateTime plannedExit) {
  final arrival = plannedExit.subtract(const Duration(minutes: 20));
  return ActiveTeamSession.restored(
    unitName: 'ДПРЧ-1',
    apparatusName: 'Drager',
    participants: const [
      Firefighter(id: 1, fullName: 'Перший', watch: '1'),
      Firefighter(id: 2, fullName: 'Другий', watch: '1'),
    ],
    leaderId: 1,
    startPressuresByFirefighterId: const {1: 300, 2: 295},
    inclusionTime: arrival.subtract(const Duration(minutes: 5)),
    workLoad: WorkLoad.medium,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
    stage: ActiveTeamStage.working,
    arrivalTime: arrival,
    arrivalPressuresByFirefighterId: const {1: 270, 2: 265},
    initialPlannedExitTime: plannedExit,
    currentPlannedExitTime: plannedExit,
    exitStartedAt: null,
    completedAt: null,
    travelPressure: 30,
    exitPressure: 80,
    workingPressure: 185,
    workingTimeMinutes: 20,
    controllingFirefighterId: 2,
    pressureChecks: const [],
    events: const [],
  );
}

ActiveTeamSession _exitingSession(DateTime now) {
  final session = _workingSession(now.add(const Duration(minutes: 2)));
  session.startExit(at: now.subtract(const Duration(minutes: 1)));
  return session;
}

class _WarningRepository extends TeamSessionRepository {
  final ActiveTeamSession session;
  _WarningRepository(this.session);

  @override
  Future<TeamSessionRecord?> getById(int id) async =>
      TeamSessionRecord(id: id, session: session);

  @override
  Future<void> addPressureCheck({
    required int sessionId,
    required DateTime checkedAt,
    required Map<int, int> estimated,
    required Map<int, int> actual,
    required bool emergencyMode,
  }) async {
    session.addPressureCheck(
      PressureCheck(checkedAt: checkedAt, pressuresByFirefighterId: actual),
    );
  }
}

class _FakeSettingsRepository extends ExitWarningSettingsRepository {
  ExitWarningSettings value = const ExitWarningSettings(
    permissionPrompted: true,
    pressureControlReminders: false,
  );

  @override
  Future<ExitWarningSettings> load() async => value;

  @override
  Future<void> save(ExitWarningSettings settings) async => value = settings;
}

class _FakeHaptic implements HapticGateway {
  int mediumCount = 0;
  int heavyCount = 0;
  @override
  Future<void> heavyImpact() async => heavyCount++;
  @override
  Future<void> mediumImpact() async => mediumCount++;
}

class _FakeNotificationGateway implements NotificationGateway {
  final bool enabled;
  _FakeNotificationGateway({this.enabled = true});
  @override
  Future<bool> canScheduleExactAlarms() async => true;
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelByPayloadPrefix(String prefix) async {}
  @override
  Future<void> cancelForSession(int sessionId) async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> notificationsEnabled() async => enabled;
  @override
  Future<bool> requestPermission() async => enabled;
  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required bool sound,
    required bool vibration,
    required bool exact,
    NotificationChannelKind channel = NotificationChannelKind.exitWarning,
  }) async {}
  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
    required bool sound,
    required bool vibration,
    NotificationChannelKind channel = NotificationChannelKind.exitWarning,
  }) async {}
  @override
  Future<List<PendingNotificationInfo>> pendingNotifications() async => [];
}
