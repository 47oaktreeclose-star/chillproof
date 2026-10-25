import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'temperature.dart';

/// Local SQLite storage. All records stay on the device.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'chillproof.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE units (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            position INTEGER NOT NULL DEFAULT 0,
            archived INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            taken_at INTEGER NOT NULL,
            checked_by TEXT NOT NULL DEFAULT ''
          )''');
        await db.execute('''
          CREATE TABLE readings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
            unit_id INTEGER NOT NULL,
            unit_name TEXT NOT NULL,
            unit_type TEXT NOT NULL,
            temp_c REAL NOT NULL,
            status TEXT NOT NULL,
            action TEXT NOT NULL DEFAULT ''
          )''');
        await db.execute('CREATE INDEX idx_sessions_taken ON sessions(taken_at)');
        await db.execute('CREATE INDEX idx_readings_session ON readings(session_id)');
      },
    );
  }

  // ---- Units ----

  Future<List<StorageUnit>> activeUnits() async {
    final rows = await (await db).query('units',
        where: 'archived = 0', orderBy: "CASE type WHEN 'fridge' THEN 0 ELSE 1 END, position, id");
    return rows.map(StorageUnit.fromRow).toList();
  }

  Future<int> insertUnit(StorageUnit u) async => (await db).insert('units', u.toRow());

  Future<void> renameUnit(int id, String name) async =>
      (await db).update('units', {'name': name}, where: 'id = ?', whereArgs: [id]);

  /// Units are archived rather than deleted so old records keep their names.
  Future<void> archiveUnit(int id) async =>
      (await db).update('units', {'archived': 1}, where: 'id = ?', whereArgs: [id]);

  // ---- Sessions ----

  Future<int> saveSession(CheckSession s) async {
    final d = await db;
    return d.transaction((txn) async {
      final id = await txn.insert('sessions', {
        'taken_at': s.takenAt.millisecondsSinceEpoch,
        'checked_by': s.checkedBy,
      });
      for (final r in s.readings) {
        await txn.insert('readings', r.toRow(id));
      }
      return id;
    });
  }

  Future<List<CheckSession>> sessions({DateTime? from, DateTime? to, int? limit}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('taken_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('taken_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await d.query('sessions',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'taken_at DESC',
        limit: limit);
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'] as int).toList();
    final readingRows = await d.query('readings',
        where: 'session_id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
        orderBy: "CASE unit_type WHEN 'fridge' THEN 0 ELSE 1 END, id");
    final byId = <int, List<Reading>>{};
    for (final r in readingRows) {
      byId.putIfAbsent(r['session_id'] as int, () => []).add(Reading.fromRow(r));
    }
    return rows
        .map((r) => CheckSession(
              id: r['id'] as int,
              takenAt: DateTime.fromMillisecondsSinceEpoch(r['taken_at'] as int),
              checkedBy: (r['checked_by'] as String?) ?? '',
              readings: byId[r['id'] as int] ?? const [],
            ))
        .toList();
  }

  Future<int> countSessionsBetween(DateTime from, DateTime to) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) AS c FROM sessions WHERE taken_at >= ? AND taken_at < ?',
        [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<Map<int, double>> lastReadingByUnit() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT r.unit_id AS unit_id, r.temp_c AS temp_c FROM readings r
      JOIN sessions s ON s.id = r.session_id
      WHERE s.taken_at = (
        SELECT MAX(s2.taken_at) FROM readings r2 JOIN sessions s2 ON s2.id = r2.session_id
        WHERE r2.unit_id = r.unit_id)''');
    return {for (final r in rows) r['unit_id'] as int: (r['temp_c'] as num).toDouble()};
  }

  Future<void> wipe() async {
    final d = await db;
    await d.delete('readings');
    await d.delete('sessions');
    await d.delete('units');
  }
}

/// Helper to name units by default, e.g. "Fridge 1", "Freezer 2".
String defaultUnitName(UnitType t, int n) => '${t.label} $n';
