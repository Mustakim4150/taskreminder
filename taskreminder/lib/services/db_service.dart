import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task_model.dart';

/// Thin wrapper around sqflite. The app is fully usable offline; the
/// [ApiService] layer syncs this local table with the backend opportunistically.
class DbService {
  DbService._internal();
  static final DbService instance = DbService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'taskreminder.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE tasks (
          id TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          language TEXT NOT NULL,
          scheduledAt TEXT NOT NULL,
          nightBeforeReminderSent INTEGER NOT NULL DEFAULT 0,
          dayOfReminderSent INTEGER NOT NULL DEFAULT 0,
          isCancelled INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL
        )
      '''),
    );
  }

  Future<void> insertTask(TaskModel task) async {
    final db = await database;
    await db.insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTask(TaskModel task) async {
    final db = await database;
    await db.update('tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TaskModel>> getActiveTasks() async {
    final db = await database;
    final rows = await db.query(
      'tasks',
      where: 'isCancelled = 0',
      orderBy: 'scheduledAt ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<List<TaskModel>> getAllTasks() async {
    final db = await database;
    final rows = await db.query('tasks', orderBy: 'scheduledAt ASC');
    return rows.map(TaskModel.fromMap).toList();
  }
}
