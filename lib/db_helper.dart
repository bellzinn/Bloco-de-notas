import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Future<Database> database() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'notes.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT)',
        );
      },
      version: 1,
    );
  }

  static Future<void> insertNote(String text) async {
    final db = await DBHelper.database();
    await db.insert('notes', {'text': text},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await DBHelper.database();
    return db.query('notes');
  }

  static Future<void> deleteNote(int id) async {
    final db = await DBHelper.database();
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
