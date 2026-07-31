import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    return openDatabase(
      p.join(base, 'kiem_dem_phieu_bau_android.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE elections(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL DEFAULT '', organization TEXT NOT NULL DEFAULT '',
          total_ballots INTEGER NOT NULL DEFAULT 0,
          select_count INTEGER NOT NULL DEFAULT 0,
          exclude_count INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE candidates(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          election_id INTEGER NOT NULL, seq INTEGER NOT NULL,
          name TEXT NOT NULL, note TEXT NOT NULL DEFAULT ''
        )''');
        await db.execute('''CREATE TABLE ballots(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          election_id INTEGER NOT NULL, ballot_no INTEGER NOT NULL,
          excluded_json TEXT NOT NULL DEFAULT '[]',
          is_valid INTEGER NOT NULL DEFAULT 1,
          invalid_reason TEXT NOT NULL DEFAULT '',
          edited INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE ballot_edits(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ballot_id INTEGER NOT NULL, before_json TEXT NOT NULL,
          after_json TEXT NOT NULL, edited_at TEXT NOT NULL
        )''');
      },
    );
  }

  String now() => DateTime.now().toIso8601String();

  Future<List<Map<String, Object?>>> elections() async {
    final db = await database;
    return db.query('elections', orderBy: 'updated_at DESC');
  }

  Future<int> createElection() async {
    final db = await database;
    final t = now();
    return db.insert('elections', {'name': '', 'organization': '', 'total_ballots': 0, 'select_count': 0, 'exclude_count': 0, 'created_at': t, 'updated_at': t});
  }

  Future<void> updateElection(int id, Map<String, Object?> data) async {
    final db = await database;
    data['updated_at'] = now();
    await db.update('elections', data, where: 'id=?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> candidates(int electionId) async {
    final db = await database;
    return db.query('candidates', where: 'election_id=?', whereArgs: [electionId], orderBy: 'seq ASC');
  }

  Future<void> addCandidate(int electionId, String name, String note) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM candidates WHERE election_id=?', [electionId])) ?? 0;
    await db.insert('candidates', {'election_id': electionId, 'seq': count + 1, 'name': name.trim(), 'note': note.trim()});
  }

  Future<void> updateCandidate(int id, String name, String note) async {
    final db = await database;
    await db.update('candidates', {'name': name.trim(), 'note': note.trim()}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteCandidate(int id) async {
    final db = await database;
    await db.delete('candidates', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> ballots(int electionId) async {
    final db = await database;
    return db.query('ballots', where: 'election_id=?', whereArgs: [electionId], orderBy: 'ballot_no ASC');
  }

  Future<int> addBallot(int electionId, List<int> excluded, bool valid, String reason) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ballots WHERE election_id=?', [electionId])) ?? 0;
    final t = now();
    return db.insert('ballots', {'election_id': electionId, 'ballot_no': count + 1, 'excluded_json': jsonEncode(excluded), 'is_valid': valid ? 1 : 0, 'invalid_reason': reason, 'edited': 0, 'created_at': t, 'updated_at': t});
  }

  Future<void> editBallot(Map<String, Object?> oldBallot, List<int> excluded, bool valid, String reason) async {
    final db = await database;
    final id = oldBallot['id'] as int;
    final after = {...oldBallot, 'excluded_json': jsonEncode(excluded), 'is_valid': valid ? 1 : 0, 'invalid_reason': reason, 'edited': 1, 'updated_at': now()};
    await db.transaction((txn) async {
      await txn.insert('ballot_edits', {'ballot_id': id, 'before_json': jsonEncode(oldBallot), 'after_json': jsonEncode(after), 'edited_at': now()});
      await txn.update('ballots', {'excluded_json': jsonEncode(excluded), 'is_valid': valid ? 1 : 0, 'invalid_reason': reason, 'edited': 1, 'updated_at': now()}, where: 'id=?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, Object?>>> edits(int ballotId) async {
    final db = await database;
    return db.query('ballot_edits', where: 'ballot_id=?', whereArgs: [ballotId], orderBy: 'edited_at DESC');
  }

  Future<Map<String, dynamic>> exportElection(int electionId) async {
    final db = await database;
    final e = (await db.query('elections', where: 'id=?', whereArgs: [electionId])).first;
    final cs = await candidates(electionId);
    final bs = await ballots(electionId);
    final ids = bs.map((x) => x['id'] as int).toList();
    final allEdits = <Map<String, Object?>>[];
    for (final id in ids) { allEdits.addAll(await edits(id)); }
    return {'format': 'NSBAU-ANDROID-1', 'exported_at': now(), 'election': e, 'candidates': cs, 'ballots': bs, 'ballot_edits': allEdits};
  }

  Future<int> importElection(Map<String, dynamic> data) async {
    final db = await database;
    return db.transaction((txn) async {
      final e = Map<String, Object?>.from(data['election'] as Map);
      e.remove('id');
      e['created_at'] = now(); e['updated_at'] = now();
      final newId = await txn.insert('elections', e);
      final candidateIdMap = <int, int>{};
      for (final raw in (data['candidates'] as List? ?? [])) {
        final c = Map<String, Object?>.from(raw as Map); final old = c['id'] as int?; c.remove('id'); c['election_id'] = newId;
        final nid = await txn.insert('candidates', c); if (old != null) candidateIdMap[old] = nid;
      }
      final ballotMap = <int, int>{};
      for (final raw in (data['ballots'] as List? ?? [])) {
        final b = Map<String, Object?>.from(raw as Map); final old = b['id'] as int?; b.remove('id'); b['election_id'] = newId;
        final nid = await txn.insert('ballots', b); if (old != null) ballotMap[old] = nid;
      }
      for (final raw in (data['ballot_edits'] as List? ?? [])) {
        final x = Map<String, Object?>.from(raw as Map); x.remove('id'); final old = x['ballot_id'] as int?; x['ballot_id'] = ballotMap[old] ?? 0; await txn.insert('ballot_edits', x);
      }
      return newId;
    });
  }
}
