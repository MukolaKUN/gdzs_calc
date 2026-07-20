import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';

void main() {
  final now = DateTime(2026, 7, 16, 10);
  const settings = ExitWarningSettings();

  test('exit in 10 minutes schedules 5, 2, 1 and 0 warnings', () async {
    final gateway = _FakeGateway();
    await _sync(gateway, now, now.add(const Duration(minutes: 10)));
    expect(gateway.pending.values.map((item) => item.at), {
      now.add(const Duration(minutes: 5)),
      now.add(const Duration(minutes: 8)),
      now.add(const Duration(minutes: 9)),
      now.add(const Duration(minutes: 10)),
    });
  });

  test('exit in 3 minutes skips the 5 minute warning', () async {
    final gateway = _FakeGateway();
    await _sync(gateway, now, now.add(const Duration(minutes: 3)));
    expect(
      gateway.pending,
      isNot(
        contains(
          ExitWarningService.notificationId(7, ExitWarningLevel.fiveMinutes),
        ),
      ),
    );
    expect(gateway.pending, hasLength(3));
  });

  test('exit in 90 seconds schedules one minute and exitNow', () async {
    final gateway = _FakeGateway();
    await _sync(gateway, now, now.add(const Duration(seconds: 90)));
    expect(gateway.pending.keys, {
      ExitWarningService.notificationId(7, ExitWarningLevel.oneMinute),
      ExitWarningService.notificationId(7, ExitWarningLevel.exitNow),
    });
  });

  test('past warning moments are not scheduled', () async {
    final gateway = _FakeGateway();
    await _sync(gateway, now, now.subtract(const Duration(seconds: 1)));
    expect(gateway.pending, isEmpty);
    expect(gateway.shown, hasLength(1));
  });

  test('changing planned exit cancels old notifications', () async {
    final gateway = _FakeGateway();
    await _sync(gateway, now, now.add(const Duration(minutes: 10)));
    await _sync(gateway, now, now.add(const Duration(minutes: 4)));
    expect(gateway.cancelForSessionCalls, 2);
    expect(gateway.pending, hasLength(3));
    expect(
      gateway.pending.values.every(
        (item) => !item.at.isAfter(now.add(const Duration(minutes: 4))),
      ),
      isTrue,
    );
  });

  test('pressure-control resynchronization creates new moments', () async {
    final gateway = _FakeGateway();
    await _sync(gateway, now, now.add(const Duration(minutes: 10)));
    await _sync(gateway, now, now.add(const Duration(seconds: 90)));
    expect(gateway.pending.values.map((item) => item.at), {
      now.add(const Duration(seconds: 30)),
      now.add(const Duration(seconds: 90)),
    });
  });

  test('exiting cancels all warnings', () async {
    final gateway = _FakeGateway();
    await _sync(gateway, now, now.add(const Duration(minutes: 10)));
    await ExitWarningService(gateway).synchronize(
      sessionId: 7,
      stage: ActiveTeamStage.exiting,
      plannedExitTime: now.add(const Duration(minutes: 10)),
      settings: settings,
      now: now,
    );
    expect(gateway.pending, isEmpty);
  });

  test('completed cancels all warnings', () async {
    final gateway = _FakeGateway();
    await _sync(gateway, now, now.add(const Duration(minutes: 10)));
    await ExitWarningService(gateway).synchronize(
      sessionId: 7,
      stage: ActiveTeamStage.completed,
      plannedExitTime: now.add(const Duration(minutes: 10)),
      settings: settings,
      now: now,
    );
    expect(gateway.pending, isEmpty);
  });

  test('notification ids are stable per session and level', () {
    expect(
      ExitWarningService.notificationId(42, ExitWarningLevel.twoMinutes),
      ExitWarningService.notificationId(42, ExitWarningLevel.twoMinutes),
    );
    expect(
      ExitWarningService.notificationId(42, ExitWarningLevel.twoMinutes),
      isNot(ExitWarningService.notificationId(43, ExitWarningLevel.twoMinutes)),
    );
  });

  test('repeated synchronization replaces instead of duplicating', () async {
    final gateway = _FakeGateway();
    final exit = now.add(const Duration(minutes: 10));
    await _sync(gateway, now, exit);
    await _sync(gateway, now, exit);
    expect(gateway.pending, hasLength(4));
  });

  test('missing exact permission selects inexact fallback', () async {
    final gateway = _FakeGateway(exactAvailable: false);
    await _sync(gateway, now, now.add(const Duration(minutes: 10)));
    expect(gateway.pending.values.every((item) => !item.exact), isTrue);
  });

  test('notification permission refusal does not throw', () async {
    final gateway = _FakeGateway(permissionGranted: false);
    await expectLater(gateway.requestPermission(), completion(isFalse));
    await expectLater(
      _sync(gateway, now, now.add(const Duration(minutes: 10))),
      completes,
    );
  });
}

Future<void> _sync(_FakeGateway gateway, DateTime now, DateTime exit) =>
    ExitWarningService(gateway).synchronize(
      sessionId: 7,
      stage: ActiveTeamStage.working,
      plannedExitTime: exit,
      settings: const ExitWarningSettings(),
      now: now,
    );

class _Scheduled {
  final DateTime at;
  final bool exact;
  const _Scheduled(this.at, this.exact);
}

class _FakeGateway implements NotificationGateway {
  final bool exactAvailable;
  final bool permissionGranted;
  final Map<int, _Scheduled> pending = {};
  final List<int> shown = [];
  int cancelForSessionCalls = 0;

  _FakeGateway({this.exactAvailable = true, this.permissionGranted = true});

  @override
  Future<bool> canScheduleExactAlarms() async => exactAvailable;

  @override
  Future<void> cancel(int id) async => pending.remove(id);

  @override
  Future<void> cancelByPayloadPrefix(String prefix) async {}

  @override
  Future<void> cancelForSession(int sessionId) async {
    cancelForSessionCalls++;
    for (final level in ExitWarningLevel.values) {
      pending.remove(ExitWarningService.notificationId(sessionId, level));
    }
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> notificationsEnabled() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

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
  }) async {
    pending[id] = _Scheduled(at, exact);
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
    required bool sound,
    required bool vibration,
    NotificationChannelKind channel = NotificationChannelKind.exitWarning,
  }) async {
    shown.add(id);
  }

  @override
  Future<List<PendingNotificationInfo>> pendingNotifications() async => [];
}
