import 'package:gdzs_calc/shared/database/database_service.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';
import 'package:sqflite/sqflite.dart';

class ExitWarningSettingsRepository {
  final Database? database;
  const ExitWarningSettingsRepository({this.database});

  Future<Database> get _database async => database ?? DatabaseService.database;

  Future<ExitWarningSettings> load() async {
    final db = await _database;
    final rows = await db.query(
      'app_settings',
      where: 'settingKey LIKE ?',
      whereArgs: ['exit_warning_%'],
    );
    final values = {
      for (final row in rows)
        row['settingKey'] as String: row['settingValue'] as String,
    };
    bool flag(String key) => values[key] == null || values[key] == '1';
    return ExitWarningSettings(
      systemNotifications: flag('exit_warning_system'),
      sound: flag('exit_warning_sound'),
      vibration: flag('exit_warning_vibration'),
      fiveMinutes: flag('exit_warning_five_minutes'),
      twoMinutes: flag('exit_warning_two_minutes'),
      oneMinute: flag('exit_warning_one_minute'),
      permissionPrompted: values['exit_warning_permission_prompted'] == '1',
      pressureControlReminders: flag('exit_warning_pressure_control'),
    );
  }

  Future<void> save(ExitWarningSettings settings) async {
    final db = await _database;
    await db.transaction((txn) async {
      final values = <String, bool>{
        'exit_warning_system': settings.systemNotifications,
        'exit_warning_sound': settings.sound,
        'exit_warning_vibration': settings.vibration,
        'exit_warning_five_minutes': settings.fiveMinutes,
        'exit_warning_two_minutes': settings.twoMinutes,
        'exit_warning_one_minute': settings.oneMinute,
        'exit_warning_permission_prompted': settings.permissionPrompted,
        'exit_warning_pressure_control': settings.pressureControlReminders,
      };
      for (final entry in values.entries) {
        await txn.insert('app_settings', {
          'settingKey': entry.key,
          'settingValue': entry.value ? '1' : '0',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
