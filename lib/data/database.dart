import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/calc.dart';
import '../domain/models.dart';
import 'backup.dart';

part 'database.g.dart';

class Templates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TemplateExerciseRow')
class TemplateExercises extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text().references(Templates, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get targetSets => integer().withDefault(const Constant(4))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// finishedAt == null means active workout. At most one active at a time.
class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  RealColumn get tonnage => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('WorkoutExerciseRow')
class WorkoutExercises extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text().references(Workouts, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get targetSets => integer().withDefault(const Constant(4))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get volume => real().withDefault(const Constant(0))();
  RealColumn get best1rm => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Approaches extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseId =>
      text().references(WorkoutExercises, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get at => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Legs extends Table {
  TextColumn get id => text()();
  TextColumn get approachId => text().references(Approaches, #id, onDelete: KeyAction.cascade)();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  TextColumn get type => text().withDefault(const Constant('normal'))();
  DateTimeColumn get at => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Templates,
  TemplateExercises,
  Workouts,
  WorkoutExercises,
  Approaches,
  Legs,
  AppMeta,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('PRAGMA foreign_keys = ON');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'lift_log');
  }

  static const _uuid = Uuid();
  static String newId(String prefix) => '$prefix-${_uuid.v4().substring(0, 8)}';

  Future<void> ensureSeeded() async {
    final row = await (select(appMeta)..where((t) => t.key.equals('seeded'))).getSingleOrNull();
    if (row != null) return;
    // Fresh install starts empty — no demo workouts/templates.
    await into(appMeta).insert(AppMetaCompanion.insert(key: 'seeded', value: '1'));
  }

  /// Deletes templates, workouts, history and active session.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(legs).go();
      await delete(approaches).go();
      await delete(workoutExercises).go();
      await delete(workouts).go();
      await delete(templateExercises).go();
      await delete(templates).go();
    });
  }

  // ── Templates ──────────────────────────────────────────────

  Stream<List<WorkoutTemplate>> watchTemplates() {
    return (select(templates)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .asyncMap((rows) async {
      final result = <WorkoutTemplate>[];
      for (final row in rows) {
        final exs = await (select(templateExercises)
              ..where((t) => t.templateId.equals(row.id))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
        result.add(WorkoutTemplate(
          id: row.id,
          name: row.name,
          exercises: exs
              .map((e) => TemplateExercise(
                    id: e.id,
                    name: e.name,
                    targetSets: e.targetSets,
                  ))
              .toList(),
        ));
      }
      return result;
    });
  }

  Future<List<WorkoutTemplate>> getTemplates() async {
    final rows = await (select(templates)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
    final result = <WorkoutTemplate>[];
    for (final row in rows) {
      final exs = await (select(templateExercises)
            ..where((t) => t.templateId.equals(row.id))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      result.add(WorkoutTemplate(
        id: row.id,
        name: row.name,
        exercises: exs
            .map((e) => TemplateExercise(
                  id: e.id,
                  name: e.name,
                  targetSets: e.targetSets,
                ))
            .toList(),
      ));
    }
    return result;
  }

  Future<void> upsertTemplate(WorkoutTemplate tpl) async {
    await transaction(() async {
      final existing = await (select(templates)..where((t) => t.id.equals(tpl.id))).getSingleOrNull();
      if (existing == null) {
        final count = await (select(templates).get()).then((r) => r.length);
        await into(templates).insert(TemplatesCompanion.insert(
          id: tpl.id,
          name: tpl.name,
          sortOrder: Value(count),
        ));
      } else {
        await (update(templates)..where((t) => t.id.equals(tpl.id)))
            .write(TemplatesCompanion(name: Value(tpl.name)));
        await (delete(templateExercises)..where((t) => t.templateId.equals(tpl.id))).go();
      }
      for (var i = 0; i < tpl.exercises.length; i++) {
        final e = tpl.exercises[i];
        await into(templateExercises).insert(TemplateExercisesCompanion.insert(
          id: e.id,
          templateId: tpl.id,
          name: e.name,
          targetSets: Value(e.targetSets),
          sortOrder: Value(i),
        ));
      }
    });
  }

  Future<void> insertTemplateAt(WorkoutTemplate tpl, {required int afterIndex}) async {
    await transaction(() async {
      final all = await (select(templates)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      for (var i = 0; i < all.length; i++) {
        final order = i <= afterIndex ? i : i + 1;
        await (update(templates)..where((t) => t.id.equals(all[i].id)))
            .write(TemplatesCompanion(sortOrder: Value(order)));
      }
      await into(templates).insert(TemplatesCompanion.insert(
        id: tpl.id,
        name: tpl.name,
        sortOrder: Value(afterIndex + 1),
      ));
      for (var i = 0; i < tpl.exercises.length; i++) {
        final e = tpl.exercises[i];
        await into(templateExercises).insert(TemplateExercisesCompanion.insert(
          id: e.id,
          templateId: tpl.id,
          name: e.name,
          targetSets: Value(e.targetSets),
          sortOrder: Value(i),
        ));
      }
    });
  }

  Future<void> deleteTemplate(String id) async {
    await (delete(templates)..where((t) => t.id.equals(id))).go();
  }

  // ── Workouts ───────────────────────────────────────────────

  Future<WorkoutSession?> loadWorkoutTree(String workoutId) async {
    final w = await (select(workouts)..where((t) => t.id.equals(workoutId))).getSingleOrNull();
    if (w == null) return null;
    final exRows = await (select(workoutExercises)
          ..where((t) => t.workoutId.equals(workoutId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    final exercises = <WorkoutExercise>[];
    for (final ex in exRows) {
      final setRows = await (select(approaches)
            ..where((t) => t.exerciseId.equals(ex.id))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      final sets = <Approach>[];
      for (final s in setRows) {
        final legRows = await (select(legs)
              ..where((t) => t.approachId.equals(s.id))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
        sets.add(Approach(
          id: s.id,
          at: s.at,
          legs: legRows
              .map((l) => SetLeg(
                    id: l.id,
                    weight: l.weight,
                    reps: l.reps,
                    type: SetType.fromName(l.type),
                    at: l.at,
                  ))
              .toList(),
        ));
      }
      exercises.add(WorkoutExercise(
        id: ex.id,
        name: ex.name,
        targetSets: ex.targetSets,
        sets: sets,
        volume: ex.volume,
        best1rm: ex.best1rm,
      ));
    }
    return WorkoutSession(
      id: w.id,
      name: w.name,
      startedAt: w.startedAt,
      finishedAt: w.finishedAt,
      tonnage: w.tonnage,
      exercises: exercises,
    );
  }

  Stream<WorkoutSession?> watchActiveWorkout() {
    final q = select(workouts)..where((t) => t.finishedAt.isNull());
    return q.watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      return loadWorkoutTree(rows.first.id);
    });
  }

  Stream<List<WorkoutSession>> watchHistory({int limit = 50}) {
    final q = select(workouts)
      ..where((t) => t.finishedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.finishedAt)])
      ..limit(limit);
    return q.watch().asyncMap((rows) async {
      final list = <WorkoutSession>[];
      for (final row in rows) {
        final session = await loadWorkoutTree(row.id);
        if (session != null) list.add(session);
      }
      return list;
    });
  }

  Future<List<WorkoutSession>> getHistory() async {
    final rows = await (select(workouts)
          ..where((t) => t.finishedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.finishedAt)]))
        .get();
    final list = <WorkoutSession>[];
    for (final row in rows) {
      final session = await loadWorkoutTree(row.id);
      if (session != null) list.add(session);
    }
    return list;
  }

  Future<void> replaceActiveWorkout(WorkoutSession session) async {
    await transaction(() async {
      final active = await (select(workouts)..where((t) => t.finishedAt.isNull())).get();
      for (final a in active) {
        await (delete(workouts)..where((t) => t.id.equals(a.id))).go();
      }
      await _insertWorkoutTree(session);
    });
  }

  Future<void> _insertWorkoutTree(WorkoutSession session) async {
    await into(workouts).insert(WorkoutsCompanion.insert(
      id: session.id,
      name: session.name,
      startedAt: session.startedAt,
      finishedAt: Value(session.finishedAt),
      tonnage: Value(session.tonnage),
    ));
    for (var ei = 0; ei < session.exercises.length; ei++) {
      final ex = session.exercises[ei];
      await into(workoutExercises).insert(WorkoutExercisesCompanion.insert(
        id: ex.id,
        workoutId: session.id,
        name: ex.name,
        targetSets: Value(ex.targetSets),
        sortOrder: Value(ei),
        volume: Value(ex.volume),
        best1rm: Value(ex.best1rm),
      ));
      for (var si = 0; si < ex.sets.length; si++) {
        final set = ex.sets[si];
        await into(approaches).insert(ApproachesCompanion.insert(
          id: set.id,
          exerciseId: ex.id,
          at: set.at,
          sortOrder: Value(si),
        ));
        for (var li = 0; li < set.legs.length; li++) {
          final leg = set.legs[li];
          await into(legs).insert(LegsCompanion.insert(
            id: leg.id,
            approachId: set.id,
            weight: leg.weight,
            reps: leg.reps,
            type: Value(leg.type.name),
            at: leg.at,
            sortOrder: Value(li),
          ));
        }
      }
    }
  }

  Future<void> saveActiveSession(WorkoutSession session) async {
    await transaction(() async {
      await (delete(workouts)..where((t) => t.id.equals(session.id))).go();
      await _insertWorkoutTree(session.copyWith(clearFinishedAt: true, finishedAt: null));
    });
  }

  Future<void> finishWorkout(WorkoutSession session) async {
    final finished = DateTime.now();
    final exercises = session.exercises.map(withAggregates).toList();
    final ton = sessionTonnage(session.copyWith(exercises: exercises));
    final done = session.copyWith(
      finishedAt: finished,
      tonnage: ton,
      exercises: exercises,
    );
    await transaction(() async {
      await (delete(workouts)..where((t) => t.id.equals(session.id))).go();
      await _insertWorkoutTree(done);
    });
  }

  Future<void> cancelActiveWorkout() async {
    final active = await (select(workouts)..where((t) => t.finishedAt.isNull())).get();
    for (final a in active) {
      await (delete(workouts)..where((t) => t.id.equals(a.id))).go();
    }
  }

  Future<void> deleteWorkout(String id) async {
    await (delete(workouts)..where((t) => t.id.equals(id))).go();
  }

  Future<void> insertFinishedWorkout(WorkoutSession session) async {
    await _insertWorkoutTree(session);
  }

  Future<List<String>> allExerciseNames() async {
    final names = <String>{};
    final tex = await select(templateExercises).get();
    for (final e in tex) {
      if (e.name.trim().isNotEmpty) names.add(e.name.trim());
    }
    final wex = await select(workoutExercises).get();
    for (final e in wex) {
      if (e.name.trim().isNotEmpty) names.add(e.name.trim());
    }
    final list = names.toList()..sort();
    return list;
  }

  Future<List<Approach>> lastPastSetsForExercise(String name) async {
    final history = await getHistory();
    final recent = [...history]..sort((a, b) => (b.finishedAt ?? b.startedAt).compareTo(a.finishedAt ?? a.startedAt));
    for (final h in recent) {
      final found = h.exercises.where((e) => e.name == name);
      if (found.isNotEmpty && found.first.sets.isNotEmpty) {
        return found.first.sets;
      }
    }
    return const [];
  }

  // ── Backup ─────────────────────────────────────────────────

  Future<List<WorkoutSession>> getAllWorkouts() async {
    final rows = await (select(workouts)..orderBy([(t) => OrderingTerm.asc(t.startedAt)])).get();
    final list = <WorkoutSession>[];
    for (final row in rows) {
      final session = await loadWorkoutTree(row.id);
      if (session != null) list.add(session);
    }
    return list;
  }

  Future<String> exportBackupJson() async {
    const codec = BackupCodec();
    final data = BackupData(
      templates: await getTemplates(),
      workouts: await getAllWorkouts(),
      exportedAt: DateTime.now().toUtc(),
    );
    return codec.encode(data);
  }

  Future<void> importBackupJson(String raw) async {
    const codec = BackupCodec();
    final data = codec.decode(raw);
    await transaction(() async {
      await delete(legs).go();
      await delete(approaches).go();
      await delete(workoutExercises).go();
      await delete(workouts).go();
      await delete(templateExercises).go();
      await delete(templates).go();

      for (var i = 0; i < data.templates.length; i++) {
        final tpl = data.templates[i];
        await into(templates).insert(TemplatesCompanion.insert(
          id: tpl.id,
          name: tpl.name,
          sortOrder: Value(i),
        ));
        for (var ei = 0; ei < tpl.exercises.length; ei++) {
          final e = tpl.exercises[ei];
          await into(templateExercises).insert(TemplateExercisesCompanion.insert(
            id: e.id,
            templateId: tpl.id,
            name: e.name,
            targetSets: Value(e.targetSets),
            sortOrder: Value(ei),
          ));
        }
      }

      for (final session in data.workouts) {
        await _insertWorkoutTree(session);
      }

      await into(appMeta).insertOnConflictUpdate(
        AppMetaCompanion.insert(key: 'seeded', value: '1'),
      );
    });
  }
}

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in main()');
});

/// Debug helper — unused in release UI.
String encodeSessionDebug(WorkoutSession s) => jsonEncode({
      'id': s.id,
      'name': s.name,
      'exercises': s.exercises.length,
    });
