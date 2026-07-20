import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';
import 'package:gdzs_calc/shared/services/pressure_control_reminder_service.dart';

void main() {
  final inclusion = DateTime(2026, 7, 20, 15, 10);

  test('next reminder follows absolute ten-minute boundaries', () {
    expect(_next(inclusion, inclusion), DateTime(2026, 7, 20, 15, 20));
    expect(
      _next(inclusion, DateTime(2026, 7, 20, 15, 19, 59)),
      DateTime(2026, 7, 20, 15, 20),
    );
    expect(
      _next(inclusion, DateTime(2026, 7, 20, 15, 20)),
      DateTime(2026, 7, 20, 15, 30),
    );
    expect(
      _next(inclusion, DateTime(2026, 7, 20, 15, 27)),
      DateTime(2026, 7, 20, 15, 30),
    );
    expect(
      _next(inclusion, DateTime(2026, 7, 20, 15, 41)),
      DateTime(2026, 7, 20, 15, 50),
    );
  });

  test('completed interval helper handles exact boundaries', () {
    int count(Duration elapsed) =>
        PressureControlReminderService.completedTenMinuteIntervals(
          inclusionTime: inclusion,
          now: inclusion.add(elapsed),
        );
    expect(count(const Duration(minutes: 9, seconds: 59)), 0);
    expect(count(const Duration(minutes: 10)), 1);
    expect(count(const Duration(minutes: 19, seconds: 59)), 1);
    expect(count(const Duration(minutes: 20)), 2);
    expect(count(const Duration(minutes: 41)), 4);
  });

  for (final stage in [
    ActiveTeamStage.advancing,
    ActiveTeamStage.working,
    ActiveTeamStage.exiting,
  ]) {
    test('${stage.name} schedules reminders', () async {
      final gateway = _Gateway();
      await PressureControlReminderService(
        gateway,
        now: () => inclusion,
      ).synchronize(
        sessionId: 7,
        inclusionTime: inclusion,
        stage: stage,
        notificationsEnabled: true,
      );
      expect(gateway.pending, isNotEmpty);
      expect(
        gateway.pending.values.first.at,
        inclusion.add(const Duration(minutes: 10)),
      );
      expect(gateway.pending.values.first.title, 'Час провести контроль тиску');
      expect(
        gateway.pending.values.first.body,
        'Минуло ще 10 хвилин роботи ланки в ЗІЗОД. Перевірте зв’язок і зафіксуйте фактичний тиск.',
      );
      expect(gateway.pending.values.first.payload, 'pressureControlReminder:7');
      expect(
        gateway.pending.values.first.channel,
        NotificationChannelKind.pressureControlReminder,
      );
    });
  }

  test('completed and disabled settings cancel reminders', () async {
    final gateway = _Gateway();
    final service = PressureControlReminderService(
      gateway,
      now: () => inclusion,
    );
    await service.synchronize(
      sessionId: 7,
      inclusionTime: inclusion,
      stage: ActiveTeamStage.working,
      notificationsEnabled: true,
    );
    await service.synchronize(
      sessionId: 7,
      inclusionTime: inclusion,
      stage: ActiveTeamStage.completed,
      notificationsEnabled: true,
    );
    expect(gateway.pending, isEmpty);
  });

  test('manual pressure-check time does not change the next boundary', () {
    final before = _next(inclusion, inclusion.add(const Duration(minutes: 13)));
    final afterCheck = _next(
      inclusion,
      inclusion.add(const Duration(minutes: 13, seconds: 1)),
    );
    expect(before, DateTime(2026, 7, 20, 15, 30));
    expect(afterCheck, before);
  });

  test('repeated synchronization replaces rather than duplicates', () async {
    final gateway = _Gateway();
    final service = PressureControlReminderService(
      gateway,
      now: () => inclusion,
    );
    await service.synchronize(
      sessionId: 7,
      inclusionTime: inclusion,
      stage: ActiveTeamStage.working,
      notificationsEnabled: true,
    );
    final count = gateway.pending.length;
    await service.synchronize(
      sessionId: 7,
      inclusionTime: inclusion,
      stage: ActiveTeamStage.working,
      notificationsEnabled: true,
    );
    expect(gateway.pending, hasLength(count));
  });

  test('ids do not conflict with exit warnings', () {
    expect(
      PressureControlReminderService.notificationId(7, 1),
      isNot(ExitWarningService.notificationId(7, ExitWarningLevel.exitNow)),
    );
  });

  test('permission refusal does not throw or schedule', () async {
    final gateway = _Gateway(enabled: false);
    await expectLater(
      PressureControlReminderService(gateway).synchronize(
        sessionId: 7,
        inclusionTime: inclusion,
        stage: ActiveTeamStage.working,
        notificationsEnabled: true,
      ),
      completes,
    );
    expect(gateway.pending, isEmpty);
  });

  test('cancelAll removes reminders when there is no active session', () async {
    final gateway = _Gateway();
    final service = PressureControlReminderService(
      gateway,
      now: () => inclusion,
    );
    await service.synchronize(
      sessionId: 7,
      inclusionTime: inclusion,
      stage: ActiveTeamStage.working,
      notificationsEnabled: true,
    );
    await service.cancelAll();
    expect(gateway.pending, isEmpty);
  });
}

DateTime _next(DateTime inclusion, DateTime now) =>
    PressureControlReminderService.nextReminderTime(
      inclusionTime: inclusion,
      now: now,
    );

class _Item {
  final DateTime at;
  final String title;
  final String body;
  final String payload;
  final NotificationChannelKind channel;
  const _Item(this.at, this.title, this.body, this.payload, this.channel);
}

class _Gateway implements NotificationGateway {
  final bool enabled;
  final Map<int, _Item> pending = {};
  _Gateway({this.enabled = true});
  @override
  Future<bool> canScheduleExactAlarms() async => true;
  @override
  Future<void> cancel(int id) async => pending.remove(id);
  @override
  Future<void> cancelByPayloadPrefix(String prefix) async => pending.clear();
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
  }) async {
    pending[id] = _Item(at, title, body, payload, channel);
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
    required bool sound,
    required bool vibration,
  }) async {}
}
