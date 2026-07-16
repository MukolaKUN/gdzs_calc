import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/shared/database/database_service.dart';
import 'package:gdzs_calc/shared/repositories/exit_warning_settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('exit warning settings persist in SQLite', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await DatabaseService.createAppSettingsTable(db);
    final repository = ExitWarningSettingsRepository(database: db);

    final defaults = await repository.load();
    expect(defaults.systemNotifications, isTrue);
    expect(defaults.sound, isTrue);
    await repository.save(
      defaults.copyWith(
        sound: false,
        twoMinutes: false,
        permissionPrompted: true,
      ),
    );
    final restored = await repository.load();
    expect(restored.sound, isFalse);
    expect(restored.twoMinutes, isFalse);
    expect(restored.permissionPrompted, isTrue);
  });
}
