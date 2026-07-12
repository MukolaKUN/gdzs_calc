import 'package:gdzs_calc/shared/database/database_service.dart';
import 'package:gdzs_calc/shared/models/unit.dart';

class UnitRepository {
  Future<List<Unit>> getAll() async {
    final db = await DatabaseService.database;

    final result = await db.query(
      'units',
      orderBy: 'name',
    );

    return result.map((e) => Unit.fromMap(e)).toList();
  }

  Future<void> insert(Unit unit) async {
    final db = await DatabaseService.database;

    await db.insert(
      'units',
      unit.toMap(),
    );
  }

  Future<void> update(Unit unit) async {
  final db = await DatabaseService.database;

  await db.update(
    'units',
    unit.toMap(),
    where: 'id = ?',
    whereArgs: [unit.id],
  );
}

  Future<void> delete(int id) async {
    final db = await DatabaseService.database;

    await db.delete(
      'units',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}