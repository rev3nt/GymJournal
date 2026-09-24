import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/calc.dart';
import '../domain/models.dart';

final templatesProvider = StreamProvider<List<WorkoutTemplate>>((ref) {
  return ref.watch(databaseProvider).watchTemplates();
});

final activeWorkoutProvider = StreamProvider<WorkoutSession?>((ref) {
  return ref.watch(databaseProvider).watchActiveWorkout();
});

final historyProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(databaseProvider).watchHistory();
});

final exerciseNamesProvider = FutureProvider<List<String>>((ref) async {
  // Re-fetch when templates/history/active change
  ref.watch(templatesProvider);
  ref.watch(historyProvider);
  ref.watch(activeWorkoutProvider);
  return ref.watch(databaseProvider).allExerciseNames();
});

/// Top-level stats slider: workouts (tonnage) vs exercises (working weight).
enum StatsSection { workouts, exercises }

class UiSession {
  const UiSession({
    this.tabIndex = 0,
    this.activeExerciseId,
    this.pendingLegType = SetType.normal,
    this.savedReps,
    this.viewingPastId,
    this.statsSection = StatsSection.workouts,
    this.statsWorkoutCard = 0,
    this.statsExerciseCard = 0,
    this.statsExercise,
    this.weight = 60,
    this.reps = 8,
  });

  final int tabIndex;
  final String? activeExerciseId;
  final SetType pendingLegType;
  final int? savedReps;
  final String? viewingPastId;
  final StatsSection statsSection;
  final int statsWorkoutCard;
  final int statsExerciseCard;
  final String? statsExercise;
  final double weight;
  final int reps;

  UiSession copyWith({
    int? tabIndex,
    String? activeExerciseId,
    bool clearActiveExercise = false,
    SetType? pendingLegType,
    int? savedReps,
    bool clearSavedReps = false,
    String? viewingPastId,
    bool clearViewingPast = false,
    StatsSection? statsSection,
    int? statsWorkoutCard,
    int? statsExerciseCard,
    String? statsExercise,
    double? weight,
    int? reps,
  }) {
    return UiSession(
      tabIndex: tabIndex ?? this.tabIndex,
      activeExerciseId:
          clearActiveExercise ? null : (activeExerciseId ?? this.activeExerciseId),
      pendingLegType: pendingLegType ?? this.pendingLegType,
      savedReps: clearSavedReps ? null : (savedReps ?? this.savedReps),
      viewingPastId: clearViewingPast ? null : (viewingPastId ?? this.viewingPastId),
      statsSection: statsSection ?? this.statsSection,
      statsWorkoutCard: statsWorkoutCard ?? this.statsWorkoutCard,
      statsExerciseCard: statsExerciseCard ?? this.statsExerciseCard,
      statsExercise: statsExercise ?? this.statsExercise,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
    );
  }
}

class AppController extends Notifier<UiSession> {
  @override
  UiSession build() => const UiSession();

  AppDatabase get _db => ref.read(databaseProvider);

  void setTab(int index) {
    state = state.copyWith(tabIndex: index, clearViewingPast: index != 1);
  }

  static const workoutCardCount = 3;
  static const exerciseCardCount = 3;

  void setStatsSection(StatsSection section) {
    state = state.copyWith(statsSection: section);
  }

  void setStatsWorkoutCard(int index) =>
      state = state.copyWith(statsWorkoutCard: index.clamp(0, workoutCardCount - 1));

  void setStatsExerciseCard(int index) =>
      state = state.copyWith(statsExerciseCard: index.clamp(0, exerciseCardCount - 1));

  void setStatsExercise(String name) => state = state.copyWith(statsExercise: name);

  void setWeight(double w) => state = state.copyWith(weight: w);

  void setReps(int r) => state = state.copyWith(reps: r);

  void setActiveExercise(String id, {required bool applyPrefill, List<Approach>? past}) {
    final changed = state.activeExerciseId != id;
    state = state.copyWith(
      activeExerciseId: id,
      pendingLegType: SetType.normal,
      clearSavedReps: true,
    );
    if (changed && applyPrefill && past != null) {
      _applyPastPrefill(past, currentSetsLen: 0);
    }
  }

  void setPendingLegType(SetType type) {
    if (type != SetType.normal) {
      if (state.pendingLegType == SetType.normal) {
        state = state.copyWith(pendingLegType: type, savedReps: state.reps, reps: 0);
        return;
      }
    } else if (state.pendingLegType != SetType.normal) {
      final restore = state.savedReps ?? 8;
      state = state.copyWith(
        pendingLegType: SetType.normal,
        reps: state.reps > 0 ? state.reps : restore,
        clearSavedReps: true,
      );
      return;
    }
    state = state.copyWith(pendingLegType: type);
  }

  Future<void> startWorkout({String? templateId, bool replace = false}) async {
    final active = await ref.read(activeWorkoutProvider.future);
    if (active != null &&
        active.exercises.any((e) => e.sets.isNotEmpty) &&
        !replace) {
      throw StateError('active_exists');
    }

    String name = 'Пустая тренировка';
    var exercises = [
      WorkoutExercise(
        id: AppDatabase.newId('ex'),
        name: 'Упражнение 1',
        targetSets: 4,
      ),
    ];

    if (templateId != null) {
      final templates = await _db.getTemplates();
      final tpl = templates.where((t) => t.id == templateId).firstOrNull;
      if (tpl != null) {
        name = tpl.name;
        exercises = tpl.exercises
            .map((tex) => WorkoutExercise(
                  id: AppDatabase.newId('ex'),
                  name: tex.name,
                  targetSets: tex.targetSets,
                ))
            .toList();
      }
    }

    final session = WorkoutSession(
      id: AppDatabase.newId('wo'),
      name: name,
      startedAt: DateTime.now(),
      exercises: exercises,
    );
    await _db.replaceActiveWorkout(session);
    state = state.copyWith(
      tabIndex: 1,
      activeExerciseId: exercises.first.id,
      pendingLegType: SetType.normal,
      clearSavedReps: true,
      clearViewingPast: true,
    );
    final past = await _db.lastPastSetsForExercise(exercises.first.name);
    _applyPastPrefill(past, currentSetsLen: 0);
  }

  void openPastWorkout(String id) {
    state = state.copyWith(
      viewingPastId: id,
      tabIndex: 1,
      clearActiveExercise: true,
    );
  }

  void closePastWorkout() {
    state = state.copyWith(clearViewingPast: true);
  }

  Future<void> deleteWorkout(String id) async {
    await _db.deleteWorkout(id);
    if (state.viewingPastId == id) {
      state = state.copyWith(clearViewingPast: true);
    }
  }

  Future<void> logSet(WorkoutSession active) async {
    if (state.weight < 0 || state.reps <= 0) {
      throw ArgumentError('invalid_inputs');
    }
    final exId = state.activeExerciseId ?? active.exercises.firstOrNull?.id;
    if (exId == null) return;
    final exIndex = active.exercises.indexWhere((e) => e.id == exId);
    if (exIndex < 0) return;
    final ex = active.exercises[exIndex];
    final type = state.pendingLegType;
    final now = DateTime.now();
    final leg = SetLeg(
      id: AppDatabase.newId('leg'),
      weight: state.weight,
      reps: state.reps,
      type: type,
      at: now,
    );

    late WorkoutExercise updatedEx;
    if (type == SetType.normal) {
      final set = Approach(id: AppDatabase.newId('set'), at: now, legs: [leg]);
      updatedEx = ex.copyWith(sets: [...ex.sets, set]);
    } else {
      if (ex.sets.isEmpty) throw StateError('need_normal_first');
      final last = ex.sets.last;
      final sets = [...ex.sets];
      sets[sets.length - 1] = last.copyWith(legs: [...last.legs, leg]);
      updatedEx = ex.copyWith(sets: sets);
    }

    final exercises = [...active.exercises];
    exercises[exIndex] = withAggregates(updatedEx);
    final next = active.copyWith(exercises: exercises, tonnage: sessionTonnage(active.copyWith(exercises: exercises)));
    await _db.saveActiveSession(next);

    final restoreReps = type != SetType.normal ? (state.savedReps ?? 8) : state.reps;
    state = state.copyWith(
      pendingLegType: SetType.normal,
      clearSavedReps: true,
      reps: restoreReps,
    );
    if (type == SetType.normal) {
      final past = await _db.lastPastSetsForExercise(updatedEx.name);
      _applyPastPrefill(past, currentSetsLen: updatedEx.sets.length);
    }
  }

  Future<void> deleteSet(WorkoutSession active, String exerciseId, String setId) async {
    final exIndex = active.exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex < 0) return;
    final ex = active.exercises[exIndex];
    final updatedEx = withAggregates(ex.copyWith(sets: ex.sets.where((s) => s.id != setId).toList()));
    final exercises = [...active.exercises];
    exercises[exIndex] = updatedEx;
    final next = active.copyWith(
      exercises: exercises,
      tonnage: sessionTonnage(active.copyWith(exercises: exercises)),
    );
    await _db.saveActiveSession(next);
  }

  Future<void> updateApproach(
    WorkoutSession active,
    String exerciseId,
    Approach updated,
  ) async {
    final exIndex = active.exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex < 0) return;
    final ex = active.exercises[exIndex];
    final sets = ex.sets.map((s) => s.id == updated.id ? updated : s).toList();
    if (updated.legs.isEmpty) {
      await deleteSet(active, exerciseId, updated.id);
      return;
    }
    final updatedEx = withAggregates(ex.copyWith(sets: sets));
    final exercises = [...active.exercises];
    exercises[exIndex] = updatedEx;
    final next = active.copyWith(
      exercises: exercises,
      tonnage: sessionTonnage(active.copyWith(exercises: exercises)),
    );
    await _db.saveActiveSession(next);
  }

  Future<void> renameExercise(
    WorkoutSession active,
    String exerciseId,
    String name,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final exIndex = active.exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex < 0) return;
    final exercises = [...active.exercises];
    exercises[exIndex] = exercises[exIndex].copyWith(name: trimmed);
    await _db.saveActiveSession(active.copyWith(exercises: exercises));
  }

  Future<void> addExercise(WorkoutSession active, String name) async {
    final ex = WorkoutExercise(
      id: AppDatabase.newId('ex'),
      name: name.trim(),
      targetSets: 4,
    );
    final next = active.copyWith(exercises: [...active.exercises, ex]);
    await _db.saveActiveSession(next);
    state = state.copyWith(activeExerciseId: ex.id, pendingLegType: SetType.normal, clearSavedReps: true);
  }

  Future<void> finishWorkout(WorkoutSession active) async {
    final hasSets = active.exercises.any((e) => e.sets.isNotEmpty);
    if (!hasSets) {
      await _db.cancelActiveWorkout();
      state = state.copyWith(tabIndex: 0, clearActiveExercise: true);
      return;
    }
    await _db.finishWorkout(active);
    state = state.copyWith(tabIndex: 2, clearActiveExercise: true, clearViewingPast: true);
  }

  Future<void> saveTemplate(WorkoutTemplate tpl) => _db.upsertTemplate(tpl);

  Future<void> deleteTemplate(String id) => _db.deleteTemplate(id);

  Future<void> duplicateTemplate(WorkoutTemplate tpl) async {
    final templates = await _db.getTemplates();
    final idx = templates.indexWhere((t) => t.id == tpl.id);
    final copy = WorkoutTemplate(
      id: AppDatabase.newId('tpl'),
      name: '${tpl.name} · копия',
      exercises: tpl.exercises
          .map((e) => TemplateExercise(
                id: AppDatabase.newId('tex'),
                name: e.name,
                targetSets: e.targetSets,
              ))
          .toList(),
    );
    if (idx >= 0) {
      await _db.insertTemplateAt(copy, afterIndex: idx);
    } else {
      await _db.upsertTemplate(copy);
    }
  }

  Future<void> clearAllData() async {
    await _db.clearAllData();
    state = UiSession(tabIndex: state.tabIndex);
  }

  Future<String> exportBackupJson() => _db.exportBackupJson();

  Future<void> importBackupJson(String raw) async {
    await _db.importBackupJson(raw);
    state = UiSession(tabIndex: state.tabIndex);
  }

  void _applyPastPrefill(List<Approach> past, {required int currentSetsLen}) {
    if (state.pendingLegType != SetType.normal) return;
    if (currentSetsLen >= past.length) return;
    final next = past[currentSetsLen];
    if (next.legs.isEmpty) return;
    final main = next.legs.firstWhere(
      (l) => l.type == SetType.normal,
      orElse: () => next.legs.first,
    );
    state = state.copyWith(weight: main.weight, reps: main.reps);
  }
}

final appControllerProvider = NotifierProvider<AppController, UiSession>(AppController.new);
