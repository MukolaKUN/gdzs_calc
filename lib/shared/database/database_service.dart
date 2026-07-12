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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE units(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            city TEXT NOT NULL
          )
        ''');

        await db.execute('''
         CREATE TABLE apparatus(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    workingPressure INTEGER NOT NULL,
    cylinderVolume REAL NOT NULL,
    cylindersCount INTEGER NOT NULL,
    reservePressure INTEGER NOT NULL
)
        ''');

        await db.execute('''
          CREATE TABLE firefighters(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fullName TEXT NOT NULL
)
        ''');
      },
    );
  }
}