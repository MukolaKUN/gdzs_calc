import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../models/backup_preview.dart';
import '../models/gdzs_backup.dart';
import 'backup_checksum_service.dart';
import 'backup_table_registry.dart';

class BackupValidationException implements Exception {
  final String message;
  const BackupValidationException(this.message);
  @override
  String toString() => message;
}

class ValidatedBackup {
  final GdzsBackup backup;
  final BackupPreview preview;
  const ValidatedBackup(this.backup, this.preview);
}

class DatabaseBackupService {
  final Database database;
  final BackupChecksumService checksumService;
  const DatabaseBackupService(
    this.database, {
    this.checksumService = const BackupChecksumService(),
  });

  Future<GdzsBackup> export({
    required String appVersion,
    DateTime? createdAt,
  }) => database.transaction((txn) async {
    final payload = <String, List<Map<String, Object?>>>{};
    for (final table in backupTables) {
      payload[table.name] = await txn.query(
        table.name,
        orderBy: table.primaryKey,
      );
    }
    return GdzsBackup(
      databaseSchemaVersion: await txn.getVersion(),
      createdAtUtc: (createdAt ?? DateTime.now()).toUtc(),
      appVersion: appVersion,
      recordCounts: {for (final e in payload.entries) e.key: e.value.length},
      payload: payload,
      checksum: checksumService.forPayload(payload),
    );
  }, exclusive: true);

  Future<ValidatedBackup> validate(
    Uint8List bytes, {
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const BackupValidationException('Файл пошкоджений або неповний');
    }
    late Map<String, dynamic> root;
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) throw const FormatException();
      root = value;
    } catch (_) {
      throw const BackupValidationException('Файл пошкоджений або неповний');
    }
    if (root['format'] != GdzsBackup.formatName) {
      throw const BackupValidationException(
        'Це не резервна копія GDZS Calculator',
      );
    }
    if (root['formatVersion'] != GdzsBackup.currentFormatVersion) {
      throw const BackupValidationException(
        'Версія резервної копії не підтримується',
      );
    }
    final schema = root['databaseSchemaVersion'];
    if (schema is! int) {
      throw const BackupValidationException('Файл пошкоджений або неповний');
    }
    final currentSchema = await database.getVersion();
    if (schema > currentSchema) {
      throw const BackupValidationException(
        'Ця резервна копія створена новішою версією застосунку. Оновіть GDZS Calculator',
      );
    }
    if (schema != currentSchema) {
      throw const BackupValidationException(
        'Версія резервної копії не підтримується',
      );
    }
    final rawPayload = root['payload'];
    final rawCounts = root['recordCounts'];
    if (rawPayload is! Map<String, dynamic> ||
        rawCounts is! Map<String, dynamic>) {
      throw const BackupValidationException('Файл пошкоджений або неповний');
    }
    if (rawPayload.keys.any((name) => !backupTableByName.containsKey(name)) ||
        backupTables.any((table) => !rawPayload.containsKey(table.name))) {
      throw const BackupValidationException('Файл пошкоджений або неповний');
    }
    final payload = <String, List<Map<String, Object?>>>{};
    for (final table in backupTables) {
      final rows = rawPayload[table.name];
      if (rows is! List) {
        throw const BackupValidationException('Файл пошкоджений або неповний');
      }
      final decodedRows = <Map<String, Object?>>[];
      final schemaRows = await database.rawQuery(
        'PRAGMA table_info(${table.name})',
      );
      final columns = {
        for (final c in schemaRows)
          c['name'] as String: (c['type'] as String).toUpperCase(),
      };
      final notNullColumns = {
        for (final c in schemaRows)
          if (c['notnull'] == 1) c['name'] as String,
      };
      for (final rawRow in rows) {
        if (rawRow is! Map) {
          throw const BackupValidationException(
            'Файл пошкоджений або неповний',
          );
        }
        final row = <String, Object?>{};
        for (final entry in rawRow.entries) {
          final key = entry.key;
          if (key is! String || !columns.containsKey(key)) {
            throw const BackupValidationException(
              'Файл пошкоджений або неповний',
            );
          }
          final value = GdzsBackup.decodeValue(entry.value);
          if (value == null && notNullColumns.contains(key)) {
            throw const BackupValidationException(
              'Файл пошкоджений або неповний',
            );
          }
          if (!_validSqliteValue(value, columns[key]!)) {
            throw const BackupValidationException(
              'Файл пошкоджений або неповний',
            );
          }
          row[key] = value;
        }
        if (!row.keys.toSet().containsAll(table.requiredColumns)) {
          throw const BackupValidationException(
            'Файл пошкоджений або неповний',
          );
        }
        decodedRows.add(row);
      }
      if (rawCounts[table.name] is! int ||
          rawCounts[table.name] != decodedRows.length) {
        throw const BackupValidationException('Файл пошкоджений або неповний');
      }
      payload[table.name] = decodedRows;
    }
    if (rawCounts.keys
        .toSet()
        .difference(backupTableByName.keys.toSet())
        .isNotEmpty) {
      throw const BackupValidationException('Файл пошкоджений або неповний');
    }
    final expected = checksumService.forPayload(payload);
    if (root['checksum'] != expected) {
      throw const BackupValidationException(
        'Контрольна сума файла не збігається',
      );
    }
    _validateForeignKeys(payload);
    final created = DateTime.tryParse(root['createdAtUtc'] as String? ?? '');
    final appVersion = root['appVersion'];
    if (created == null || appVersion is! String) {
      throw const BackupValidationException('Файл пошкоджений або неповний');
    }
    final backup = GdzsBackup(
      databaseSchemaVersion: schema,
      createdAtUtc: created.toUtc(),
      appVersion: appVersion,
      recordCounts: {
        for (final t in backupTables) t.name: rawCounts[t.name] as int,
      },
      payload: payload,
      checksum: expected,
    );
    final sessions = payload['team_sessions']!;
    final active = sessions.any(
      (r) => const {'advancing', 'working', 'exiting'}.contains(r['stage']),
    );
    final completed = sessions.where((r) => r['stage'] == 'completed').length;
    return ValidatedBackup(
      backup,
      BackupPreview(
        fileName: fileName,
        createdAtUtc: created.toUtc(),
        appVersion: appVersion,
        databaseSchemaVersion: schema,
        recordCounts: backup.recordCounts,
        hasActiveSession: active,
        completedSessions: completed,
      ),
    );
  }

  Future<void> restore(GdzsBackup backup) => database.transaction((txn) async {
    for (final table in backupTables.reversed) {
      await txn.delete(table.name);
    }
    for (final table in backupTables) {
      for (final row in backup.payload[table.name]!) {
        await txn.insert(
          table.name,
          row,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    }
    final violations = await txn.rawQuery('PRAGMA foreign_key_check');
    if (violations.isNotEmpty) throw StateError('foreign_key_check failed');
    for (final table in backupTables) {
      final count =
          Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM ${table.name}'),
          ) ??
          -1;
      if (count != backup.recordCounts[table.name]) {
        throw StateError('record count mismatch');
      }
    }
  }, exclusive: true);

  bool _validSqliteValue(Object? value, String type) {
    if (value == null) return true;
    if (value is Uint8List) return type.contains('BLOB');
    if (type.contains('INT')) return value is int;
    if (type.contains('REAL') ||
        type.contains('FLOA') ||
        type.contains('DOUB')) {
      return value is num;
    }
    if (type.contains('TEXT')) return value is String;
    return value is int || value is double || value is String;
  }

  void _validateForeignKeys(Map<String, List<Map<String, Object?>>> payload) {
    for (final table in backupTables) {
      for (final fk in table.foreignKeys.entries) {
        final parent = backupTableByName[fk.value]!;
        final ids = payload[parent.name]!
            .map((r) => r[parent.primaryKey])
            .toSet();
        if (payload[table.name]!.any((r) => !ids.contains(r[fk.key]))) {
          throw const BackupValidationException(
            'Файл пошкоджений або неповний',
          );
        }
      }
    }
  }
}
