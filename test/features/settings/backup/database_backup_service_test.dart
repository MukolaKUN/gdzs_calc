import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/settings/backup/services/database_backup_service.dart';
import 'package:gdzs_calc/features/settings/backup/models/gdzs_backup.dart';
import 'package:gdzs_calc/shared/database/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late DatabaseBackupService service;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseService.schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: _createSchema,
      ),
    );
    service = DatabaseBackupService(db);
  });
  tearDown(() => db.close());

  test('empty database exports and validates all application tables', () async {
    final backup = await service.export(appVersion: '1.0.0');
    expect(backup.payload.length, 10);
    expect(backup.recordCounts.values.every((count) => count == 0), isTrue);
    final valid = await service.validate(
      Uint8List.fromList(utf8.encode(backup.encode())),
      fileName: 'empty.gdzsbackup',
    );
    expect(valid.preview.totalRecords, 0);
  });

  test(
    'full unicode database round-trips with ids, null and newlines',
    () async {
      await _seed(db);
      final backup = await service.export(appVersion: '1.0.0');
      final valid = await service.validate(
        Uint8List.fromList(utf8.encode(backup.encode())),
        fileName: 'full.gdzsbackup',
      );
      expect(valid.preview.firefighters, 1);
      expect(valid.preview.hasActiveSession, isTrue);
      expect(valid.preview.pressureChecks, 1);
      expect(valid.preview.emergencies, 1);
      expect(
        backup.payload['firefighters']!.single['fullName'],
        'Кловак Богдан Ігорович',
      );
      expect(backup.payload['team_emergencies']!.single['note'], isNull);
      expect(
        backup.payload['team_session_events']!.single['description'],
        contains('\n'),
      );

      for (final table in backup.payload.keys.toList().reversed) {
        await db.delete(table);
      }
      await service.restore(valid.backup);
      expect((await db.query('firefighters')).single['id'], 7);
      expect(
        (await db.query('team_session_events')).single['description'],
        'Довга примітка\nДругий рядок',
      );
      expect((await db.rawQuery('PRAGMA foreign_key_check')), isEmpty);
      final next = await db.insert('firefighters', {
        'fullName': 'Новий',
        'watch': '2',
      });
      expect(next, greaterThan(7));
    },
  );

  test('checksum detects a one-character payload change', () async {
    await _seed(db);
    final backup = await service.export(appVersion: '1.0.0');
    final changed = backup.encode().replaceFirst('Кловак', 'Кловах');
    expect(
      () => service.validate(
        Uint8List.fromList(utf8.encode(changed)),
        fileName: 'bad.gdzsbackup',
      ),
      throwsA(
        isA<BackupValidationException>().having(
          (e) => e.message,
          'message',
          contains('Контрольна сума'),
        ),
      ),
    );
  });

  test(
    'rejects malformed json, wrong format and unsupported versions',
    () async {
      expect(
        () => service.validate(
          Uint8List.fromList(utf8.encode('{')),
          fileName: 'x',
        ),
        throwsA(isA<BackupValidationException>()),
      );
      final backup = await service.export(appVersion: '1');
      Future<void> rejects(Map<String, dynamic> json) async => expect(
        () => service.validate(
          Uint8List.fromList(utf8.encode(jsonEncode(json))),
          fileName: 'x',
        ),
        throwsA(isA<BackupValidationException>()),
      );
      await rejects({...backup.toJson(), 'format': 'other'});
      await rejects({...backup.toJson(), 'formatVersion': 99});
      await rejects({
        ...backup.toJson(),
        'databaseSchemaVersion': DatabaseService.schemaVersion + 1,
      });
    },
  );

  test('rejects unknown or missing tables and incorrect counts', () async {
    final backup = await service.export(appVersion: '1');
    final unknown = Map<String, dynamic>.from(backup.toJson());
    unknown['payload'] = {...unknown['payload'] as Map, 'sqlite_master': []};
    expect(
      () => service.validate(
        Uint8List.fromList(utf8.encode(jsonEncode(unknown))),
        fileName: 'x',
      ),
      throwsA(isA<BackupValidationException>()),
    );
    final missing = Map<String, dynamic>.from(backup.toJson());
    missing['payload'] = Map<String, dynamic>.from(missing['payload'] as Map)
      ..remove('units');
    expect(
      () => service.validate(
        Uint8List.fromList(utf8.encode(jsonEncode(missing))),
        fileName: 'x',
      ),
      throwsA(isA<BackupValidationException>()),
    );
    final count = Map<String, dynamic>.from(backup.toJson());
    count['recordCounts'] = {...count['recordCounts'] as Map, 'units': 3};
    expect(
      () => service.validate(
        Uint8List.fromList(utf8.encode(jsonEncode(count))),
        fileName: 'x',
      ),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('restore insertion failure rolls back all original data', () async {
    await _seed(db);
    final backup = await service.export(appVersion: '1');
    final brokenPayload = {
      for (final e in backup.payload.entries)
        e.key: [for (final r in e.value) Map<String, Object?>.from(r)],
    };
    brokenPayload['team_session_members']!.add(
      Map<String, Object?>.from(brokenPayload['team_session_members']!.single),
    );
    final broken = GdzsBackup(
      databaseSchemaVersion: backup.databaseSchemaVersion,
      createdAtUtc: backup.createdAtUtc,
      appVersion: backup.appVersion,
      recordCounts: {...backup.recordCounts, 'team_session_members': 2},
      payload: brokenPayload,
      checksum: backup.checksum,
    );
    expect(() => service.restore(broken), throwsA(anything));
    expect(
      (await db.query('firefighters')).single['fullName'],
      'Кловак Богдан Ігорович',
    );
    expect(await db.query('team_session_members'), hasLength(1));
  });
}

Future<void> _createSchema(Database db, int version) async {
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
}

Future<void> _seed(Database db) async {
  await db.insert('units', {'id': 3, 'name': 'ДПРЧ-1', 'city': 'Київ'});
  await db.insert('apparatus', {
    'id': 4,
    'name': 'Dräger',
    'workingPressure': 300,
    'cylinderVolume': 6.8,
    'cylindersCount': 1,
    'reservePressure': 50,
  });
  await db.insert('firefighters', {
    'id': 7,
    'fullName': 'Кловак Богдан Ігорович',
    'watch': '1',
  });
  final now = DateTime(2026, 7, 20, 15, 10).toIso8601String();
  await db.insert('team_sessions', {
    'id': 10,
    'unitId': 3,
    'unitNameSnapshot': 'ДПРЧ-1',
    'apparatusId': 4,
    'apparatusNameSnapshot': 'Dräger',
    'apparatusWorkingPressure': 300,
    'apparatusCylinderVolume': 6.8,
    'apparatusCylindersCount': 1,
    'apparatusReservePressure': 50,
    'leaderFirefighterId': 7,
    'workLoad': 'medium',
    'stage': 'working',
    'inclusionTime': now,
    'createdAt': now,
    'updatedAt': now,
  });
  await db.insert('team_session_members', {
    'id': 11,
    'sessionId': 10,
    'firefighterId': 7,
    'firefighterNameSnapshot': 'Кловак Богдан Ігорович',
    'watchNumberSnapshot': 1,
    'isLeader': 1,
    'position': 0,
    'startPressure': 290,
  });
  await db.insert('team_pressure_checks', {
    'id': 12,
    'sessionId': 10,
    'checkedAt': now,
    'controllingFirefighterId': 7,
    'remainingWorkMinutes': 20,
    'plannedExitTimeAfterCheck': now,
    'emergencyMode': 0,
  });
  await db.insert('team_pressure_check_members', {
    'id': 13,
    'pressureCheckId': 12,
    'firefighterId': 7,
    'estimatedPressure': 250,
    'actualPressure': 245,
  });
  await db.insert('team_session_events', {
    'id': 14,
    'sessionId': 10,
    'eventTime': now,
    'title': 'Подія',
    'description': 'Довга примітка\nДругий рядок',
  });
  await db.insert('team_emergencies', {
    'id': 15,
    'sessionId': 10,
    'reason': 'injury',
    'startedAt': now,
    'stageAtStart': 'working',
    'communicationAvailable': 1,
    'note': null,
  });
  await db.insert('app_settings', {
    'settingKey': 'exit_warning_sound',
    'settingValue': '0',
  });
}
