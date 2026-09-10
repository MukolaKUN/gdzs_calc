import 'dart:async';

import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';
import 'package:gdzs_calc/shared/services/haptic_gateway.dart';
import 'package:gdzs_calc/shared/services/pressure_control_reminder_service.dart';

/// Coordinates in-app haptics and the ten-minute pressure-control reminder.
class ActiveTeamAlertsController {
  ActiveTeamAlertsController(this._hapticGateway);

  final HapticGateway _hapticGateway;
  final Set<ExitWarningLevel> _firedHapticLevels = {};
  final List<Timer> _hapticTimers = [];
  bool _reminderInitialized = false;

  void initializePressureReminderTracking() => _reminderInitialized = true;

  void process({
    required ActiveTeamSession? session,
    required DateTime now,
    required ExitWarningSettings settings,
    required int? visibleReminderInterval,
    required int? dismissedReminderInterval,
    required bool isMounted,
    required void Function(int? interval) onVisibleReminderChanged,
  }) {
    if (!isMounted || session == null) return;
    _processHapticThreshold(session, now, settings);
    _processPressureReminderBoundary(
      session: session,
      now: now,
      settings: settings,
      visibleReminderInterval: visibleReminderInterval,
      dismissedReminderInterval: dismissedReminderInterval,
      onVisibleReminderChanged: onVisibleReminderChanged,
    );
  }

  void _processHapticThreshold(
    ActiveTeamSession session,
    DateTime now,
    ExitWarningSettings settings,
  ) {
    if (session.stage != ActiveTeamStage.working || !settings.vibration) return;
    final level = ExitWarningService.levelFor(
      session.remainingUntilPlannedExit(now),
    );
    if (level == ExitWarningLevel.normal || !_firedHapticLevels.add(level)) {
      return;
    }
    _performHaptic(level);
  }

  void _processPressureReminderBoundary({
    required ActiveTeamSession session,
    required DateTime now,
    required ExitWarningSettings settings,
    required int? visibleReminderInterval,
    required int? dismissedReminderInterval,
    required void Function(int? interval) onVisibleReminderChanged,
  }) {
    if (!_reminderInitialized) return;
    final completed =
        PressureControlReminderService.completedTenMinuteIntervals(
          inclusionTime: session.inclusionTime,
          now: now,
        );
    final boundary = session.inclusionTime.add(
      PressureControlReminderService.interval * completed,
    );
    final latestCheck = session.latestPressureCheck;
    final intervalHandled =
        latestCheck != null && !latestCheck.checkedAt.isBefore(boundary);
    final shouldShow =
        completed > 0 &&
        session.stage != ActiveTeamStage.completed &&
        settings.pressureControlReminders &&
        !intervalHandled &&
        dismissedReminderInterval != completed;
    if (!shouldShow) {
      if (visibleReminderInterval != null) onVisibleReminderChanged(null);
      return;
    }
    if (visibleReminderInterval == completed) return;
    onVisibleReminderChanged(completed);
    unawaited(_hapticGateway.heavyImpact());
  }

  void _performHaptic(ExitWarningLevel level) {
    if (level == ExitWarningLevel.fiveMinutes) {
      unawaited(_hapticGateway.mediumImpact());
      return;
    }
    final count = switch (level) {
      ExitWarningLevel.oneMinute => 2,
      ExitWarningLevel.exitNow => 3,
      _ => 1,
    };
    unawaited(_hapticGateway.heavyImpact());
    for (var index = 1; index < count; index++) {
      late final Timer timer;
      timer = Timer(Duration(milliseconds: 180 * index), () {
        _hapticTimers.remove(timer);
        unawaited(_hapticGateway.heavyImpact());
      });
      _hapticTimers.add(timer);
    }
  }

  void dispose() {
    for (final timer in _hapticTimers) {
      timer.cancel();
    }
    _hapticTimers.clear();
  }
}
