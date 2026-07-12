import 'package:gdzs_calc/shared/database/database_service.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';

class FirefighterRepository {
  Future<List<Firefighter>> getAll() async {
    final db = await DatabaseService.database;

    final result = await db.query('firefighters', orderBy: 'watch, fullName');

    return result.map((e) => Firefighter.fromMap(e)).toList();
  }

  Future<void> insert(Firefighter firefighter) async {
    final db = await DatabaseService.database;

    await db.insert('firefighters', firefighter.toMap());
  }

  Future<void> update(Firefighter firefighter) async {
    final db = await DatabaseService.database;

    await db.update(
      'firefighters',
      firefighter.toMap(),
      where: 'id = ?',
      whereArgs: [firefighter.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseService.database;

    await db.delete('firefighters', where: 'id = ?', whereArgs: [id]);
  }
}
