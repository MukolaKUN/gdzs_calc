import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/repositories/exit_warning_settings_repository.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';
import 'package:gdzs_calc/shared/services/local_notification_gateway.dart';
import 'package:gdzs_calc/shared/services/pressure_control_reminder_service.dart';

class AppServices {
  AppServices._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final settingsRepository = const ExitWarningSettingsRepository();
  static late final TeamSessionRepository teamRepository;
  static late final LocalNotificationGateway notificationGateway;
  static late final ExitWarningService exitWarningService;
  static late final PressureControlReminderService
  pressureControlReminderService;
  static bool isInitialized = false;

  static Future<void> initialize() async {
    if (isInitialized) return;
    notificationGateway = LocalNotificationGateway(onPayload: _openPayload);
    exitWarningService = ExitWarningService(notificationGateway);
    pressureControlReminderService = PressureControlReminderService(
      notificationGateway,
    );
    teamRepository = TeamSessionRepository(
      onSessionDeleted: _cancelSessionNotifications,
      onSessionCompleted: _cancelSessionNotifications,
    );
    await notificationGateway.initialize();
    isInitialized = true;
    await synchronizeActiveSession();
  }

  static Future<void> synchronizeActiveSession() async {
    if (!isInitialized) return;
    final record = await teamRepository.getActiveSession();
    if (record == null) {
      await pressureControlReminderService.cancelAll();
      return;
    }
    final settings = await settingsRepository.load();
    await exitWarningService.synchronize(
      sessionId: record.id,
      stage: record.session.stage,
      plannedExitTime: record.session.currentPlannedExitTime,
      settings: settings,
    );
    await pressureControlReminderService.synchronize(
      sessionId: record.id,
      inclusionTime: record.session.inclusionTime,
      stage: record.session.stage,
      notificationsEnabled:
          settings.systemNotifications && settings.pressureControlReminders,
      communicationAvailable:
          record.session.activeEmergency?.communicationAvailable ?? true,
      sound: settings.sound,
      vibration: settings.vibration,
    );
  }

  static Future<void> _cancelSessionNotifications(int sessionId) async {
    await exitWarningService.cancelForSession(sessionId);
    await pressureControlReminderService.cancelForSession(sessionId);
  }

  static void _openPayload(String payload) {
    final sessionId = int.tryParse(
      payload.startsWith('pressureControlReminder:')
          ? payload.substring('pressureControlReminder:'.length)
          : payload,
    );
    if (sessionId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final record = await teamRepository.getById(sessionId);
      if (record == null || record.session.stage == ActiveTeamStage.completed) {
        return;
      }
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) =>
              ActiveTeamPage(sessionId: sessionId, repository: teamRepository),
        ),
      );
    });
  }
}
