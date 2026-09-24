import 'models.dart';

double approachVolume(Approach approach) {
  return approach.legs.fold(0.0, (s, leg) => s + leg.weight * leg.reps);
}

double epley1rm(double weight, int reps) {
  if (reps <= 0) return 0;
  if (reps == 1) return weight;
  return weight * (1 + reps / 30);
}

double approachBest1rm(Approach approach) {
  return approach.legs.fold(
    0.0,
    (m, leg) => m > epley1rm(leg.weight, leg.reps)
        ? m
        : epley1rm(leg.weight, leg.reps),
  );
}

double sessionTonnage(WorkoutSession session) {
  return session.exercises.fold(
    0.0,
    (sum, ex) => sum + ex.sets.fold(0.0, (s, set) => s + approachVolume(set)),
  );
}

WorkoutExercise withAggregates(WorkoutExercise ex) {
  final volume = ex.sets.fold(0.0, (s, set) => s + approachVolume(set));
  final best1rm =
      ex.sets.fold(0.0, (m, set) => m > approachBest1rm(set) ? m : approachBest1rm(set));
  return ex.copyWith(volume: volume, best1rm: best1rm);
}

/// Working weight for an exercise in one finished session.
///
/// Takes all [SetType.normal] legs for the exercise and picks the weight that
/// appears most often (majority). Ties: prefer the higher weight; if still
/// tied, prefer the most recently logged weight.
double? workingWeightForExercise(WorkoutExercise ex) {
  final normals = <SetLeg>[
    for (final approach in ex.sets)
      for (final leg in approach.legs)
        if (leg.type == SetType.normal) leg,
  ];
  if (normals.isEmpty) return null;

  final counts = <double, int>{};
  final latestAt = <double, DateTime>{};
  for (final leg in normals) {
    counts[leg.weight] = (counts[leg.weight] ?? 0) + 1;
    final prev = latestAt[leg.weight];
    if (prev == null || leg.at.isAfter(prev)) {
      latestAt[leg.weight] = leg.at;
    }
  }

  final ranked = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      final byWeight = b.compareTo(a);
      if (byWeight != 0) return byWeight;
      return latestAt[b]!.compareTo(latestAt[a]!);
    });
  return ranked.first;
}
