import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/settings/settings_page.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';
import 'package:gdzs_calc/shared/repositories/exit_warning_settings_repository.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';

void main() {
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
}

class _MemorySettingsRepository extends ExitWarningSettingsRepository {
  ExitWarningSettings value = const ExitWarningSettings();

  @override
  Future<ExitWarningSettings> load() async => value;

  @override
  Future<void> save(ExitWarningSettings settings) async => value = settings;
}

class _SettingsGateway implements NotificationGateway {
  @override
  Future<bool> canScheduleExactAlarms() async => false;
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelForSession(int sessionId) async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> notificationsEnabled() async => true;
  @override
  Future<bool> requestPermission() async => true;
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
  }) async {}
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
