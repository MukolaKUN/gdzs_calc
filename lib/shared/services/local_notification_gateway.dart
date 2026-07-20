import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationGateway implements NotificationGateway {
  static const channelId = 'gdzs_exit_warnings';
  static const channelName = 'Попередження про вихід із НДС';
  static const pressureChannelId = 'gdzs_pressure_control_reminders';
  static const pressureChannelName = 'Нагадування про контроль тиску';
  static const pressureChannelDescription =
      'Нагадування постовому про періодичний контроль тиску ланки ГДЗС';

  final FlutterLocalNotificationsPlugin _plugin;
  final ValueChanged<String>? onPayload;

  LocalNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    this.onPayload,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onPayload?.call(payload);
      },
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'Нагадування про наближення розрахункового часу виходу',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          pressureChannelId,
          pressureChannelName,
          description: pressureChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null) {
      onPayload?.call(launchPayload);
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _android?.requestNotificationsPermission() ?? true;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> notificationsEnabled() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _android?.areNotificationsEnabled() ?? true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) return true;
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails _details({
    required bool sound,
    required bool vibration,
    NotificationChannelKind channel = NotificationChannelKind.exitWarning,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      channel == NotificationChannelKind.pressureControlReminder
          ? pressureChannelId
          : channelId,
      channel == NotificationChannelKind.pressureControlReminder
          ? pressureChannelName
          : channelName,
      channelDescription:
          channel == NotificationChannelKind.pressureControlReminder
          ? pressureChannelDescription
          : 'Нагадування про наближення розрахункового часу виходу',
      importance: Importance.max,
      priority: Priority.max,
      playSound: sound,
      enableVibration: vibration,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: sound,
    ),
  );

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
    final scheduledDate = tz.TZDateTime.from(at.toUtc(), tz.UTC);
    Future<void> perform(bool useExact) => _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _details(
        sound: sound,
        vibration: vibration,
        channel: channel,
      ),
      androidScheduleMode: useExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
    try {
      await perform(exact);
    } catch (_) {
      if (!exact) rethrow;
      await perform(false);
    }
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
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: _details(
      sound: sound,
      vibration: vibration,
      channel: channel,
    ),
    payload: payload,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelByPayloadPrefix(String prefix) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith(prefix) == true) {
        await cancel(notification.id);
      }
    }
  }

  @override
  Future<List<PendingNotificationInfo>> pendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    return [
      for (final notification in pending)
        PendingNotificationInfo(
          id: notification.id,
          payload: notification.payload,
        ),
    ];
  }

  @override
  Future<void> cancelForSession(int sessionId) async {
    for (final level in ExitWarningLevel.values) {
      if (level == ExitWarningLevel.normal) continue;
      await cancel(ExitWarningService.notificationId(sessionId, level));
    }
  }
}
