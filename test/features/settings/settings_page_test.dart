import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/settings/settings_page.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';
import 'package:gdzs_calc/shared/repositories/exit_warning_settings_repository.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';

void main() {
  testWidgets('backup section and actions fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          warningSettingsRepository: _MemorySettingsRepository(),
          notificationGateway: _SettingsGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Резервне копіювання'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Резервне копіювання'), findsOneWidget);
    expect(find.text('Створити резервну копію'), findsOneWidget);
    expect(find.text('Відновити з файла'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warning switches persist after page restart', (tester) async {
    final repository = _MemorySettingsRepository();
    final gateway = _SettingsGateway();

    Future<void> pumpPage() async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            warningSettingsRepository: repository,
            notificationGateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpPage();
    var sound = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Звук'),
    );
    expect(sound.value, isTrue);
    sound.onChanged!(false);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpPage();
    sound = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Звук'),
    );
    expect(sound.value, isFalse);
    expect(find.text('Попередження про вихід'), findsOneWidget);
  });

  testWidgets('test notification uses pressure reminder channel', (
    tester,
  ) async {
    final gateway = _SettingsGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          warningSettingsRepository: _MemorySettingsRepository(),
          notificationGateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перевірити сповіщення'));
    await tester.pumpAndSettle();
    expect(gateway.shownTitle, 'Тестове сповіщення GDZS');
    expect(gateway.shownBody, 'Системні сповіщення працюють');
    expect(
      gateway.shownChannel,
      NotificationChannelKind.pressureControlReminder,
    );
    expect(find.text('Тестове сповіщення надіслано'), findsOneWidget);
  });

  testWidgets('test notification reports no success without permission', (
    tester,
  ) async {
    final gateway = _SettingsGateway(enabled: false, permissionGranted: false);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          warningSettingsRepository: _MemorySettingsRepository(),
          notificationGateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Сповіщення заборонені в налаштуваннях Android'),
      findsOneWidget,
    );
    await tester.tap(find.text('Перевірити сповіщення'));
    await tester.pumpAndSettle();
    expect(gateway.shownTitle, isNull);
    expect(find.text('Тестове сповіщення надіслано'), findsNothing);
  });
}

class _MemorySettingsRepository extends ExitWarningSettingsRepository {
  ExitWarningSettings value = const ExitWarningSettings();

  @override
  Future<ExitWarningSettings> load() async => value;

  @override
  Future<void> save(ExitWarningSettings settings) async => value = settings;
}

class _SettingsGateway implements NotificationGateway {
  bool enabled;
  final bool permissionGranted;
  String? shownTitle;
  String? shownBody;
  NotificationChannelKind? shownChannel;
  _SettingsGateway({this.enabled = true, this.permissionGranted = true});
  @override
  Future<bool> canScheduleExactAlarms() async => false;
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
  Future<bool> requestPermission() async {
    enabled = permissionGranted;
    return permissionGranted;
  }

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
  }) async {
    shownTitle = title;
    shownBody = body;
    shownChannel = channel;
  }

  @override
  Future<List<PendingNotificationInfo>> pendingNotifications() async => [];
}
