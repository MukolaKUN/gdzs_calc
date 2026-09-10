import 'dart:convert';
import 'dart:typed_data';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../services/backup_file_service.dart';
import '../services/database_backup_service.dart';

class BackupRepository {
  final DatabaseBackupService databaseService;
  final BackupFileService fileService;
  final Future<String> Function() appVersion;
  final Future<void> Function() cancelReminders;
  final Future<void> Function() synchronizeReminders;
  final DateTime Function() now;

  BackupRepository({
    required this.databaseService,
    required this.fileService,
    Future<String> Function()? appVersion,
    required this.cancelReminders,
    required this.synchronizeReminders,
    DateTime Function()? now,
  }) : appVersion =
           appVersion ??
           (() async => (await PackageInfo.fromPlatform()).version),
       now = now ?? DateTime.now;

  Future<String> exportAndShare() async {
    final backup = await databaseService.export(
      appVersion: await appVersion(),
      createdAt: now(),
    );
    final name = _fileName('GDZS_backup');
    final path = await fileService.writeTemporary(
      name,
      Uint8List.fromList(utf8.encode(backup.encode())),
    );
    await fileService.share(path);
    await databaseService.database.insert('app_settings', {
      'settingKey': 'backup_last_manual_export',
      'settingValue': now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return path;
  }

  Future<DateTime?> lastManualExport() async {
    final rows = await databaseService.database.query(
      'app_settings',
      where: 'settingKey = ?',
      whereArgs: ['backup_last_manual_export'],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : DateTime.tryParse(rows.single['settingValue'] as String);
  }

  Future<bool> hasActiveSession() async {
    final rows = await databaseService.database.query(
      'team_sessions',
      columns: ['id'],
      where: "stage IN ('advancing','working','exiting')",
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<SelectedBackupFile?> pickBackup() => fileService.pickBackup();

  Future<ValidatedBackup> validate(SelectedBackupFile file) =>
      databaseService.validate(file.bytes, fileName: file.name);

  Future<void> restore(ValidatedBackup selected) async {
    // Revalidation immediately before any destructive work.
    final encoded = Uint8List.fromList(utf8.encode(selected.backup.encode()));
    final validated = await databaseService.validate(
      encoded,
      fileName: selected.preview.fileName,
    );
    final current = await databaseService.export(
      appVersion: await appVersion(),
      createdAt: now(),
    );
    final preRestoreName = _fileName('GDZS_before_restore');
    await fileService.writeInternal(
      preRestoreName,
      Uint8List.fromList(utf8.encode(current.encode())),
    );
    await cancelReminders();
    try {
      await databaseService.restore(validated.backup);
    } catch (_) {
      await synchronizeReminders();
      rethrow;
    }
    await synchronizeReminders();
  }

  String _fileName(String prefix) {
    final value = now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${prefix}_${value.year}-${two(value.month)}-${two(value.day)}_${two(value.hour)}-${two(value.minute)}.gdzsbackup';
  }
}
