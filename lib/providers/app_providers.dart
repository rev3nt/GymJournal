import 'dart:convert';

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

const kActiveUiDraftMetaKey = 'active_ui_draft';
const kGuideSeenMetaKey = 'guide_seen';

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
    this.statsWorkout,
    this.weight = 60,
    this.reps = 8,
    this.exerciseDrafts = const {},
    this.resumeBannerShown = false,
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
  /// Selected finished-workout name for the workouts stats section (`null` = all).
  final String? statsWorkout;
  final double weight;
  final int reps;
  final Map<String, ExerciseInputDraft> exerciseDrafts;
  final bool resumeBannerShown;

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
    String? statsWorkout,
    bool clearStatsWorkout = false,
    double? weight,
    int? reps,
    Map<String, ExerciseInputDraft>? exerciseDrafts,
    bool clearExerciseDrafts = false,
    bool? resumeBannerShown,
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
      statsWorkout: clearStatsWorkout ? null : (statsWorkout ?? this.statsWorkout),
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      exerciseDrafts: clearExerciseDrafts
          ? const {}
          : (exerciseDrafts ?? this.exerciseDrafts),
      resumeBannerShown: resumeBannerShown ?? this.resumeBannerShown,
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

  void setStatsWorkout(String? name) {
    if (name == null || name.isEmpty) {
      state = state.copyWith(clearStatsWorkout: true);
    } else {
      state = state.copyWith(statsWorkout: name);
    }
  }

  void setWeight(double w) => state = state.copyWith(weight: w);

  void setReps(int r) => state = state.copyWith(reps: r);

  void markResumeBannerShown() {
    state = state.copyWith(resumeBannerShown: true);
  }

  /// Persist current weight/reps into the per-exercise draft map for [exerciseId].
  Map<String, ExerciseInputDraft> _draftsWithCurrent(String? exerciseId) {
    final drafts = Map<String, ExerciseInputDraft>.from(state.exerciseDrafts);
    if (exerciseId != null) {
      drafts[exerciseId] = ExerciseInputDraft(weight: state.weight, reps: state.reps);
    }
    return drafts;
  }

  void setActiveExercise(
    String id, {
    required bool applyPrefill,
    List<Approach>? past,
    int currentSetsLen = 0,
  }) {
    final prevId = state.activeExerciseId;
    final changed = prevId != id;
    final drafts = _draftsWithCurrent(changed ? prevId : null);

    double weight = state.weight;
    int reps = state.reps;
    var usedDraft = false;

    if (changed) {
      final draft = drafts[id];
      if (draft != null) {
        weight = draft.weight;
        reps = draft.reps;
        usedDraft = true;
      } else {
        weight = 60;
        reps = 8;
      }
    }

    state = state.copyWith(
      activeExerciseId: id,
      pendingLegType: SetType.normal,
      clearSavedReps: true,
      exerciseDrafts: drafts,
      weight: weight,
      reps: reps,
    );

    if (changed && !usedDraft && applyPrefill && past != null) {
      _applyPastPrefill(past, currentSetsLen: currentSetsLen);
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
                  volumeMultiplier: tex.volumeMultiplier,
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
    await _db.deleteMeta(kActiveUiDraftMetaKey);
    state = state.copyWith(
      tabIndex: 1,
      activeExerciseId: exercises.first.id,
      pendingLegType: SetType.normal,
      clearSavedReps: true,
      clearViewingPast: true,
      clearExerciseDrafts: true,
      weight: 60,
      reps: 8,
    );
    final past = await _db.lastPastSetsForExercise(exercises.first.name);
    _applyPastPrefill(past, currentSetsLen: 0);
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
    final next = active.copyWith(
      exercises: exercises,
      tonnage: sessionTonnage(active.copyWith(exercises: exercises)),
    );
    await _db.saveActiveSession(next);

    final drafts = _draftsWithCurrent(exId);
    final restoreReps = type != SetType.normal ? (state.savedReps ?? 8) : state.reps;
    state = state.copyWith(
      pendingLegType: SetType.normal,
      clearSavedReps: true,
      reps: restoreReps,
      exerciseDrafts: drafts,
    );
    if (type == SetType.normal) {
      final past = await _db.lastPastSetsForExercise(updatedEx.name);
      _applyPastPrefill(past, currentSetsLen: updatedEx.sets.length);
      // Refresh draft with post-prefill values.
      state = state.copyWith(
        exerciseDrafts: _draftsWithCurrent(exId),
      );
    }
  }

  Future<void> deleteSet(
    WorkoutSession active,
    String exerciseId,
    String setId,
  ) async {
    final exIndex = active.exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex < 0) return;
    final exercises = [...active.exercises];
    final ex = exercises[exIndex];
    final sets = ex.sets.where((s) => s.id != setId).toList();
    exercises[exIndex] = withAggregates(ex.copyWith(sets: sets));
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

  Future<void> setExerciseVolumeMultiplier(
    WorkoutSession active,
    String exerciseId,
    int multiplier,
  ) async {
    final exIndex = active.exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex < 0) return;
    final exercises = [...active.exercises];
    final ex = exercises[exIndex];
    final updated = withAggregates(
      ex.copyWith(volumeMultiplier: multiplier.clamp(1, 2)),
    );
    exercises[exIndex] = updated;
    final next = active.copyWith(
      exercises: exercises,
      tonnage: sessionTonnage(active.copyWith(exercises: exercises)),
    );
    await _db.saveActiveSession(next);
  }

  Future<void> addExercise(WorkoutSession active, String name) async {
    final ex = WorkoutExercise(
      id: AppDatabase.newId('ex'),
      name: name.trim(),
      targetSets: 4,
    );
    final next = active.copyWith(exercises: [...active.exercises, ex]);
    await _db.saveActiveSession(next);
    setActiveExercise(ex.id, applyPrefill: false);
  }

  Future<void> finishWorkout(WorkoutSession active) async {
    final hasSets = active.exercises.any((e) => e.sets.isNotEmpty);
    if (!hasSets) {
      await _db.cancelActiveWorkout();
      await _db.deleteMeta(kActiveUiDraftMetaKey);
      state = state.copyWith(
        tabIndex: 0,
        clearActiveExercise: true,
        clearExerciseDrafts: true,
      );
      return;
    }
    await _db.finishWorkout(active);
    await _db.deleteMeta(kActiveUiDraftMetaKey);
    state = state.copyWith(
      tabIndex: 2,
      clearActiveExercise: true,
      clearViewingPast: true,
      clearExerciseDrafts: true,
    );
  }

  Future<void> saveTemplate(WorkoutTemplate tpl) => _db.upsertTemplate(tpl);

  Future<void> deleteTemplate(String id) => _db.deleteTemplate(id);

  /// Removes scenario-guide demo template/workouts. Safe for user data.
  Future<void> cleanupGuideDemo({List<String> extraWorkoutIds = const []}) async {
    const demoName = 'Демо · гайд';
    const demoTplId = 'tpl-guide-demo';

    final active = await ref.read(activeWorkoutProvider.future);
    if (active != null &&
        (active.name == demoName ||
            active.id.startsWith('wo-guide') ||
            extraWorkoutIds.contains(active.id))) {
      await _db.cancelActiveWorkout();
      await _db.deleteMeta(kActiveUiDraftMetaKey);
    }

    final all = await _db.getAllWorkouts();
    final toDelete = <String>{
      ...extraWorkoutIds,
      for (final w in all)
        if (w.name == demoName) w.id,
    };
    for (final id in toDelete) {
      await _db.deleteWorkout(id);
    }
    await _db.deleteTemplate(demoTplId);

    state = state.copyWith(
      clearActiveExercise: true,
      clearExerciseDrafts: true,
      clearViewingPast: true,
    );
  }

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
                volumeMultiplier: e.volumeMultiplier,
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

  /// Save UI draft (weight/reps map + active exercise) into AppMeta.
  Future<void> persistUiDraft() async {
    final activeId = state.activeExerciseId;
    final drafts = _draftsWithCurrent(activeId);
    final payload = <String, dynamic>{
      'activeExerciseId': activeId,
      'pendingLegType': state.pendingLegType.name,
      'weight': state.weight,
      'reps': state.reps,
      'savedReps': state.savedReps,
      'drafts': {
        for (final e in drafts.entries) e.key: e.value.toJson(),
      },
    };
    await _db.setMeta(kActiveUiDraftMetaKey, jsonEncode(payload));
    // Keep in-memory drafts warm too.
    state = state.copyWith(exerciseDrafts: drafts);
  }

  /// Restore UI draft from AppMeta after process death / cold start.
  Future<void> restoreUiDraft() async {
    final raw = await _db.getMeta(kActiveUiDraftMetaKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final draftsRaw = map['drafts'];
      final drafts = <String, ExerciseInputDraft>{};
      if (draftsRaw is Map) {
        for (final e in draftsRaw.entries) {
          final draft = ExerciseInputDraft.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          );
          if (draft != null) drafts[e.key as String] = draft;
        }
      }
      final pending = SetType.fromName(map['pendingLegType'] as String?);
      final weight = (map['weight'] as num?)?.toDouble() ?? state.weight;
      final reps = (map['reps'] as num?)?.toInt() ?? state.reps;
      final saved = map['savedReps'];
      final savedReps = saved is int ? saved : (saved is num ? saved.toInt() : null);
      state = state.copyWith(
        activeExerciseId: map['activeExerciseId'] as String?,
        pendingLegType: pending,
        weight: weight,
        reps: reps,
        savedReps: savedReps,
        exerciseDrafts: drafts,
      );
    } catch (_) {
      // Corrupt draft — ignore.
    }
  }

  Future<bool> isGuideSeen() async {
    final v = await _db.getMeta(kGuideSeenMetaKey);
    return v == '1';
  }

  Future<void> markGuideSeen() => _db.setMeta(kGuideSeenMetaKey, '1');

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
