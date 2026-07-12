import 'package:gdzs_calc/shared/database/database_service.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';

class ApparatusRepository {
  Future<List<Apparatus>> getAll() async {
    final db = await DatabaseService.database;

    final result = await db.query(
      'apparatus',
      orderBy: 'name',
    );

    return result.map((e) => Apparatus.fromMap(e)).toList();
  }

  Future<void> insert(Apparatus apparatus) async {
    final db = await DatabaseService.database;

    await db.insert(
      'apparatus',
      apparatus.toMap(),
    );
  }

  Future<void> update(Apparatus apparatus) async {
    final db = await DatabaseService.database;

    await db.update(
      'apparatus',
      apparatus.toMap(),
      where: 'id = ?',
      whereArgs: [apparatus.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseService.database;

    await db.delete(
      'apparatus',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}