import 'package:flutter/foundation.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';

class PressureControlReminderService {
  final NotificationGateway gateway;
  final DateTime Function() now;

  PressureControlReminderService(this.gateway, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  static const interval = Duration(minutes: 10);
  static const _scheduledIntervals = 48;
  static const _idBase = 100000000;
  static const _idsPerSession = 64;

  static int notificationId(int sessionId, int intervalNumber) =>
      _idBase + sessionId * _idsPerSession + intervalNumber % _idsPerSession;

  static int completedTenMinuteIntervals({
    required DateTime inclusionTime,
    required DateTime now,
  }) {
    final elapsed = now.difference(inclusionTime);
    if (elapsed.isNegative) return 0;
    return elapsed.inSeconds ~/ interval.inSeconds;
  }

  static DateTime nextReminderTime({
    required DateTime inclusionTime,
    required DateTime now,
  }) {
    final completed = completedTenMinuteIntervals(
      inclusionTime: inclusionTime,
      now: now,
    );
    return inclusionTime.add(interval * (completed + 1));
  }

  static Duration timeUntilNextReminder({
    required DateTime inclusionTime,
    required DateTime now,
  }) =>
      nextReminderTime(inclusionTime: inclusionTime, now: now).difference(now);

  Future<void> synchronize({
    required int sessionId,
    required DateTime inclusionTime,
    required ActiveTeamStage stage,
    required bool notificationsEnabled,
    bool communicationAvailable = true,
    bool sound = true,
    bool vibration = true,
  }) async {
    await cancelForSession(sessionId);
    if (!notificationsEnabled || stage == ActiveTeamStage.completed) return;
    try {
      if (!await gateway.notificationsEnabled()) return;
      final current = now();
      final exact = await gateway.canScheduleExactAlarms();
      final firstNumber =
          completedTenMinuteIntervals(
            inclusionTime: inclusionTime,
            now: current,
          ) +
          1;
      final scheduledBoundaries = <int, DateTime>{};
      for (var offset = 0; offset < _scheduledIntervals; offset++) {
        final number = firstNumber + offset;
        final at = inclusionTime.add(interval * number);
        final id = notificationId(sessionId, number);
        await gateway.schedule(
          id: id,
          at: at,
          title: 'Час провести контроль тиску',
          body: communicationAvailable
              ? 'Минуло ще 10 хвилин роботи ланки в ЗІЗОД. Перевірте зв’язок і зафіксуйте фактичний тиск.'
              : 'Минуло ще 10 хвилин. Спробуйте відновити зв’язок із ланкою та контролюйте розрахунковий тиск.',
          payload: 'pressureControlReminder:$sessionId',
          sound: sound,
          vibration: vibration,
          exact: exact,
          channel: NotificationChannelKind.pressureControlReminder,
        );
        scheduledBoundaries[id] = at;
      }
      if (kDebugMode) {
        final pending = (await gateway.pendingNotifications())
            .where(
              (item) => item.payload == 'pressureControlReminder:$sessionId',
            )
            .toList();
        debugPrint(
          'Pressure reminders: sessionId=$sessionId '
          'notificationsEnabled=true exactAvailable=$exact '
          'pendingCount=${pending.length}',
        );
        for (final item in pending.take(1)) {
          debugPrint(
            'Pressure reminder pending: sessionId=$sessionId id=${item.id} '
            'boundary=${scheduledBoundaries[item.id]?.toIso8601String()} '
            'payload=${item.payload}',
          );
        }
      }
    } catch (_) {
      // Відмова дозволу або платформна помилка не повинна зупиняти роботу.
    }
  }

  Future<void> cancelForSession(int sessionId) async {
    for (var number = 0; number < _idsPerSession; number++) {
      await gateway.cancel(notificationId(sessionId, number));
    }
  }

  Future<void> cancelAll() =>
      gateway.cancelByPayloadPrefix('pressureControlReminder:');
}
