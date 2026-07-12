import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(databasePath, 'gdzs.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE units(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            city TEXT NOT NULL
          )
        ''');

        await _createApparatusTable(db);

        await db.execute('''
          CREATE TABLE firefighters(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fullName TEXT NOT NULL,
            watch TEXT NOT NULL DEFAULT ''
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final columns = await db.rawQuery('PRAGMA table_info(apparatus)');
          const expectedColumns = {
            'id',
            'name',
            'workingPressure',
            'cylinderVolume',
            'cylindersCount',
            'reservePressure',
          };
          final existingColumns = columns
              .map((column) => column['name'] as String)
              .toSet();

          if (!existingColumns.containsAll(expectedColumns) ||
              existingColumns.length != expectedColumns.length) {
            await db.execute('DROP TABLE IF EXISTS apparatus');
            await _createApparatusTable(db);
          }
        }

        if (oldVersion < 3) {
          final columns = await db.rawQuery('PRAGMA table_info(firefighters)');
          final hasWatchColumn = columns.any(
            (column) => column['name'] == 'watch',
          );

          if (!hasWatchColumn) {
            await db.execute(
              "ALTER TABLE firefighters ADD COLUMN watch TEXT NOT NULL DEFAULT ''",
            );
          }
        }
      },
    );
  }

  static Future<void> _createApparatusTable(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE apparatus(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        workingPressure INTEGER NOT NULL,
        cylinderVolume REAL NOT NULL,
        cylindersCount INTEGER NOT NULL,
        reservePressure INTEGER NOT NULL
      )
    ''');
  }
}
