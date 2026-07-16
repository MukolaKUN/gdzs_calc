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
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE units(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            city TEXT NOT NULL
          )
        ''');
        await createTeamSessionTables(db);

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
        if (oldVersion < 4) {
          await createTeamSessionTables(db);
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

  static Future<void> createTeamSessionTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE team_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unitId INTEGER NOT NULL,
        unitNameSnapshot TEXT NOT NULL,
        apparatusId INTEGER NOT NULL,
        apparatusNameSnapshot TEXT NOT NULL,
        apparatusWorkingPressure INTEGER NOT NULL,
        apparatusCylinderVolume REAL NOT NULL,
        apparatusCylindersCount INTEGER NOT NULL,
        apparatusReservePressure INTEGER NOT NULL,
        leaderFirefighterId INTEGER NOT NULL,
        workLoad TEXT NOT NULL,
        stage TEXT NOT NULL,
        inclusionTime TEXT NOT NULL,
        arrivalTime TEXT,
        initialPlannedExitTime TEXT,
        currentPlannedExitTime TEXT,
        travelPressure INTEGER,
        exitPressure INTEGER,
        workingPressure INTEGER,
        workingTimeMinutes INTEGER,
        controllingFirefighterId INTEGER,
        exitStartedAt TEXT,
        completedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE team_session_members(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        firefighterId INTEGER NOT NULL,
        firefighterNameSnapshot TEXT NOT NULL,
        watchNumberSnapshot INTEGER,
        isLeader INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL,
        startPressure INTEGER NOT NULL,
        arrivalPressure INTEGER,
        FOREIGN KEY(sessionId) REFERENCES team_sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE team_pressure_checks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        checkedAt TEXT NOT NULL,
        controllingFirefighterId INTEGER NOT NULL,
        remainingWorkMinutes INTEGER NOT NULL,
        plannedExitTimeAfterCheck TEXT NOT NULL,
        emergencyMode INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(sessionId) REFERENCES team_sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE team_pressure_check_members(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pressureCheckId INTEGER NOT NULL,
        firefighterId INTEGER NOT NULL,
        estimatedPressure INTEGER NOT NULL,
        actualPressure INTEGER NOT NULL,
        FOREIGN KEY(pressureCheckId) REFERENCES team_pressure_checks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE team_session_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        eventTime TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY(sessionId) REFERENCES team_sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE team_emergencies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        reason TEXT NOT NULL,
        startedAt TEXT NOT NULL,
        stageAtStart TEXT NOT NULL,
        communicationAvailable INTEGER NOT NULL,
        lastContactAt TEXT,
        note TEXT,
        resolvedAt TEXT,
        FOREIGN KEY(sessionId) REFERENCES team_sessions(id) ON DELETE CASCADE
      )
    ''');
  }
}
