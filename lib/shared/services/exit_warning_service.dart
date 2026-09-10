import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';

enum ExitWarningLevel { normal, fiveMinutes, twoMinutes, oneMinute, exitNow }

class ExitWarningMessage {
  final String title;
  final String body;
  const ExitWarningMessage(this.title, this.body);
}

abstract interface class NotificationGateway {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> notificationsEnabled();
  Future<bool> canScheduleExactAlarms();
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
  });
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
    required bool sound,
    required bool vibration,
    NotificationChannelKind channel = NotificationChannelKind.exitWarning,
  });
  Future<void> cancel(int id);
  Future<void> cancelForSession(int sessionId);
  Future<void> cancelByPayloadPrefix(String prefix);
  Future<List<PendingNotificationInfo>> pendingNotifications();
}

enum NotificationChannelKind { exitWarning, pressureControlReminder }

class PendingNotificationInfo {
  final int id;
  final String? payload;
  const PendingNotificationInfo({required this.id, this.payload});
}

class ExitWarningService {
  final NotificationGateway gateway;
  const ExitWarningService(this.gateway);

  static const _offsets = {
    ExitWarningLevel.fiveMinutes: Duration(minutes: 5),
    ExitWarningLevel.twoMinutes: Duration(minutes: 2),
    ExitWarningLevel.oneMinute: Duration(minutes: 1),
    ExitWarningLevel.exitNow: Duration.zero,
  };

  static int notificationId(int sessionId, ExitWarningLevel level) =>
      sessionId * 10 + level.index;

  static ExitWarningMessage message(ExitWarningLevel level) => switch (level) {
    ExitWarningLevel.normal => const ExitWarningMessage('', ''),
    ExitWarningLevel.fiveMinutes => const ExitWarningMessage(
      'До виходу з НДС — 5 хвилин',
      'Перевірте зв’язок і готовність ланки до виходу.',
    ),
    ExitWarningLevel.twoMinutes => const ExitWarningMessage(
      'До виходу з НДС — 2 хвилини',
      'Підготуйте команду на початок виходу.',
    ),
    ExitWarningLevel.oneMinute => const ExitWarningMessage(
      'До виходу з НДС — 1 хвилина',
      'Ланка повинна бути готова розпочати вихід.',
    ),
    ExitWarningLevel.exitNow => const ExitWarningMessage(
      'Час починати вихід із НДС',
      'Настав розрахунковий час початку виходу ланки.',
    ),
  };

  static ExitWarningLevel levelFor(Duration remaining) {
    if (remaining <= Duration.zero) return ExitWarningLevel.exitNow;
    if (remaining <= const Duration(minutes: 1)) {
      return ExitWarningLevel.oneMinute;
    }
    if (remaining <= const Duration(minutes: 2)) {
      return ExitWarningLevel.twoMinutes;
    }
    if (remaining <= const Duration(minutes: 5)) {
      return ExitWarningLevel.fiveMinutes;
    }
    return ExitWarningLevel.normal;
  }

  Future<bool> synchronize({
    required int sessionId,
    required ActiveTeamStage stage,
    required DateTime? plannedExitTime,
    required ExitWarningSettings settings,
    DateTime? now,
  }) async {
    await gateway.cancelForSession(sessionId);
    if (!settings.systemNotifications ||
        stage != ActiveTeamStage.working ||
        plannedExitTime == null) {
      return await gateway.canScheduleExactAlarms();
    }
    final current = now ?? DateTime.now();
    final exact = await gateway.canScheduleExactAlarms();
    for (final entry in _offsets.entries) {
      if (!_enabled(entry.key, settings)) continue;
      final at = plannedExitTime.subtract(entry.value);
      final warning = message(entry.key);
      if (entry.key == ExitWarningLevel.exitNow && !at.isAfter(current)) {
        await gateway.showNow(
          id: notificationId(sessionId, entry.key),
          title: warning.title,
          body: warning.body,
          payload: '$sessionId',
          sound: settings.sound,
          vibration: settings.vibration,
        );
      } else if (at.isAfter(current)) {
        await gateway.schedule(
          id: notificationId(sessionId, entry.key),
          at: at,
          title: warning.title,
          body: warning.body,
          payload: '$sessionId',
          sound: settings.sound,
          vibration: settings.vibration,
          exact: exact,
        );
      }
    }
    return exact;
  }

  bool _enabled(ExitWarningLevel level, ExitWarningSettings settings) =>
      switch (level) {
        ExitWarningLevel.normal => false,
        ExitWarningLevel.fiveMinutes => settings.fiveMinutes,
        ExitWarningLevel.twoMinutes => settings.twoMinutes,
        ExitWarningLevel.oneMinute => settings.oneMinute,
        ExitWarningLevel.exitNow => true,
      };

  Future<void> cancelForSession(int sessionId) =>
      gateway.cancelForSession(sessionId);

  Future<void> cancelAll() async {
    final pending = await gateway.pendingNotifications();
    for (final item in pending) {
      if (!(item.payload ?? '').startsWith('pressureControlReminder:')) {
        await gateway.cancel(item.id);
      }
    }
  }
}
