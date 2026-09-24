enum SetType {
  normal,
  drop,
  myo,
  cheat;

  String get label => switch (this) {
        SetType.normal => 'Обычный',
        SetType.drop => 'Дроп',
        SetType.myo => 'Миорепы',
        SetType.cheat => 'Читинг',
      };

  static SetType fromName(String? name) {
    return SetType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SetType.normal,
    );
  }
}

class TemplateExercise {
  const TemplateExercise({
    required this.id,
    required this.name,
    this.targetSets = 4,
  });

  final String id;
  final String name;
  final int targetSets;

  TemplateExercise copyWith({String? id, String? name, int? targetSets}) {
    return TemplateExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      targetSets: targetSets ?? this.targetSets,
    );
  }
}

class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.exercises,
  });

  final String id;
  final String name;
  final List<TemplateExercise> exercises;

  int get targetSetsSum =>
      exercises.fold(0, (s, e) => s + e.targetSets);
}

class SetLeg {
  const SetLeg({
    required this.id,
    required this.weight,
    required this.reps,
    this.type = SetType.normal,
    required this.at,
  });

  final String id;
  final double weight;
  final int reps;
  final SetType type;
  final DateTime at;

  SetLeg copyWith({
    String? id,
    double? weight,
    int? reps,
    SetType? type,
    DateTime? at,
  }) {
    return SetLeg(
      id: id ?? this.id,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      type: type ?? this.type,
      at: at ?? this.at,
    );
  }
}

class Approach {
  const Approach({
    required this.id,
    required this.at,
    required this.legs,
  });

  final String id;
  final DateTime at;
  final List<SetLeg> legs;

  Approach copyWith({String? id, DateTime? at, List<SetLeg>? legs}) {
    return Approach(
      id: id ?? this.id,
      at: at ?? this.at,
      legs: legs ?? this.legs,
    );
  }
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    this.targetSets = 4,
    this.sets = const [],
    this.volume = 0,
    this.best1rm = 0,
  });

  final String id;
  final String name;
  final int targetSets;
  final List<Approach> sets;
  final double volume;
  final double best1rm;

  WorkoutExercise copyWith({
    String? id,
    String? name,
    int? targetSets,
    List<Approach>? sets,
    double? volume,
    double? best1rm,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      targetSets: targetSets ?? this.targetSets,
      sets: sets ?? this.sets,
      volume: volume ?? this.volume,
      best1rm: best1rm ?? this.best1rm,
    );
  }
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.name,
    required this.startedAt,
    this.finishedAt,
    this.tonnage = 0,
    this.exercises = const [],
  });

  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final double tonnage;
  final List<WorkoutExercise> exercises;

  bool get isFinished => finishedAt != null;

  WorkoutSession copyWith({
    String? id,
    String? name,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    double? tonnage,
    List<WorkoutExercise>? exercises,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      tonnage: tonnage ?? this.tonnage,
      exercises: exercises ?? this.exercises,
    );
  }
}
