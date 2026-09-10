import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/settings/backup/repositories/backup_repository.dart';
import 'package:gdzs_calc/features/settings/backup/services/backup_file_service.dart';
import 'package:gdzs_calc/features/settings/backup/services/database_backup_service.dart';
import 'package:gdzs_calc/shared/database/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test('pre-restore backup failure prevents cancellation and import', () async {
    final db = await _database();
    addTearDown(db.close);
    final files = _Files(failInternal: true);
    var cancels = 0;
    final repository = BackupRepository(
      databaseService: DatabaseBackupService(db),
      fileService: files,
      appVersion: () async => '1',
      cancelReminders: () async => cancels++,
      synchronizeReminders: () async {},
    );
    final backup = await repository.databaseService.export(appVersion: '1');
    final validated = await repository.databaseService.validate(
      Uint8List.fromList(utf8.encode(backup.encode())),
      fileName: 'x.gdzsbackup',
    );
    expect(
      () => repository.restore(validated),
      throwsA(isA<FileSystemException>()),
    );
    expect(cancels, 0);
  });

  test(
    'successful restore creates internal backup then resynchronizes',
    () async {
      final db = await _database();
      addTearDown(db.close);
      final files = _Files();
      var cancels = 0;
      var synchronizes = 0;
      final repository = BackupRepository(
        databaseService: DatabaseBackupService(db),
        fileService: files,
        appVersion: () async => '1',
        cancelReminders: () async => cancels++,
        synchronizeReminders: () async => synchronizes++,
      );
      final backup = await repository.databaseService.export(appVersion: '1');
      final validated = await repository.databaseService.validate(
        Uint8List.fromList(utf8.encode(backup.encode())),
        fileName: 'x.gdzsbackup',
      );
      await repository.restore(validated);
      expect(files.internalNames.single, startsWith('GDZS_before_restore_'));
      expect(cancels, 1);
      expect(synchronizes, 1);
    },
  );
}

class _Files implements BackupFileService {
  final bool failInternal;
  final internalNames = <String>[];
  _Files({this.failInternal = false});
  @override
  Future<SelectedBackupFile?> pickBackup() async => null;
  @override
  Future<void> share(String path) async {}
  @override
  Future<String> writeInternal(String name, Uint8List bytes) async {
    if (failInternal) throw const FileSystemException('disk full');
    internalNames.add(name);
    return name;
  }

  @override
  Future<String> writeTemporary(String name, Uint8List bytes) async => name;
}

Future<Database> _database() => databaseFactoryFfi.openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(
    version: DatabaseService.schemaVersion,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
    onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE units(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,city TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE apparatus(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,workingPressure INTEGER NOT NULL,cylinderVolume REAL NOT NULL,cylindersCount INTEGER NOT NULL,reservePressure INTEGER NOT NULL)',
      );
      await db.execute(
        "CREATE TABLE firefighters(id INTEGER PRIMARY KEY AUTOINCREMENT,fullName TEXT NOT NULL,watch TEXT NOT NULL DEFAULT '')",
      );
      await DatabaseService.createTeamSessionTables(db);
      await DatabaseService.createAppSettingsTable(db);
    },
  ),
);
