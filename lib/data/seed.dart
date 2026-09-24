import 'package:uuid/uuid.dart';

import '../domain/calc.dart';
import '../domain/models.dart';
import 'database.dart';

const _uuid = Uuid();

String _id(String prefix) => '$prefix-${_uuid.v4().substring(0, 8)}';

List<WorkoutTemplate> defaultTemplates() {
  return [
    WorkoutTemplate(
      id: 'tpl-push',
      name: 'Push Day',
      exercises: const [
        TemplateExercise(id: 'tex-push-1', name: 'Жим лёжа', targetSets: 4),
        TemplateExercise(id: 'tex-push-2', name: 'Жим стоя', targetSets: 3),
        TemplateExercise(id: 'tex-push-3', name: 'Разгибания на блоке', targetSets: 3),
        TemplateExercise(id: 'tex-push-4', name: 'Махи в стороны', targetSets: 3),
      ],
    ),
    WorkoutTemplate(
      id: 'tpl-legs',
      name: 'Legs',
      exercises: const [
        TemplateExercise(id: 'tex-legs-1', name: 'Присед', targetSets: 4),
        TemplateExercise(id: 'tex-legs-2', name: 'Румынская тяга', targetSets: 3),
        TemplateExercise(id: 'tex-legs-3', name: 'Жим ногами', targetSets: 3),
        TemplateExercise(id: 'tex-legs-4', name: 'Подъёмы на носки', targetSets: 4),
      ],
    ),
    WorkoutTemplate(
      id: 'tpl-back',
      name: 'Back',
      exercises: const [
        TemplateExercise(id: 'tex-back-1', name: 'Становая тяга', targetSets: 4),
        TemplateExercise(id: 'tex-back-2', name: 'Тяга штанги', targetSets: 4),
        TemplateExercise(id: 'tex-back-3', name: 'Подтягивания', targetSets: 3),
        TemplateExercise(id: 'tex-back-4', name: 'Тяга к лицу', targetSets: 3),
      ],
    ),
  ];
}

List<WorkoutSession> buildDemoHistory(List<WorkoutTemplate> templates) {
  const dayMs = Duration(days: 1);
  final now = DateTime.now();
  final schedule = [
    (daysAgo: 1, tpl: 2, tonBias: 1.1, showcase: true),
    (daysAgo: 3, tpl: 0, tonBias: 1.05, showcase: false),
    (daysAgo: 5, tpl: 1, tonBias: 1.02, showcase: false),
    (daysAgo: 7, tpl: 2, tonBias: 1.04, showcase: false),
    (daysAgo: 9, tpl: 0, tonBias: 0.98, showcase: false),
    (daysAgo: 11, tpl: 1, tonBias: 0.96, showcase: false),
    (daysAgo: 14, tpl: 2, tonBias: 0.94, showcase: false),
    (daysAgo: 16, tpl: 0, tonBias: 0.9, showcase: false),
    (daysAgo: 18, tpl: 1, tonBias: 0.88, showcase: false),
    (daysAgo: 21, tpl: 2, tonBias: 0.86, showcase: false),
    (daysAgo: 23, tpl: 0, tonBias: 0.84, showcase: false),
    (daysAgo: 26, tpl: 1, tonBias: 0.82, showcase: false),
    (daysAgo: 28, tpl: 2, tonBias: 0.8, showcase: false),
  ];
  const bases = {
    'Жим лёжа': 80.0,
    'Жим стоя': 45.0,
    'Разгибания на блоке': 30.0,
    'Махи в стороны': 12.0,
    'Присед': 100.0,
    'Румынская тяга': 90.0,
    'Жим ногами': 140.0,
    'Подъёмы на носки': 80.0,
    'Становая тяга': 120.0,
    'Тяга штанги': 70.0,
    'Подтягивания': 0.0,
    'Тяга к лицу': 25.0,
  };

  final history = <WorkoutSession>[];
  for (var wi = 0; wi < schedule.length; wi++) {
    final slot = schedule[wi];
    final tpl = templates[slot.tpl];
    final finishedAt = now.subtract(dayMs * slot.daysAgo).subtract(Duration(minutes: (wi % 4) * 45));
    final startedAt = finishedAt.subtract(const Duration(minutes: 55));
    final exercises = <WorkoutExercise>[];

    for (var ei = 0; ei < tpl.exercises.length; ei++) {
      final ename = tpl.exercises[ei].name;
      final base = bases[ename] ?? 40.0;
      final w = (base * (0.92 + wi * 0.012) / 2.5).round() * 2.5;
      final legsMain = [
        SetLeg(id: 'leg-d$wi-$ei-a', weight: w, reps: 8, type: SetType.normal, at: finishedAt),
        SetLeg(id: 'leg-d$wi-$ei-b', weight: w, reps: 7, type: SetType.normal, at: finishedAt),
        SetLeg(
          id: 'leg-d$wi-$ei-c',
          weight: (w - 2.5).clamp(0, 9999).toDouble(),
          reps: 6,
          type: SetType.normal,
          at: finishedAt,
        ),
      ];
      final sets = <Approach>[
        Approach(id: 'set-d$wi-$ei-1', at: finishedAt, legs: [legsMain[0]]),
        Approach(id: 'set-d$wi-$ei-2', at: finishedAt, legs: [legsMain[1]]),
        Approach(
          id: 'set-d$wi-$ei-3',
          at: finishedAt,
          legs: ei == 0
              ? [
                  legsMain[2],
                  SetLeg(
                    id: 'leg-d$wi-$ei-drop',
                    weight: (w - 15).clamp(0, 9999).toDouble(),
                    reps: 8,
                    type: SetType.drop,
                    at: finishedAt,
                  ),
                ]
              : [legsMain[2]],
        ),
      ];

      if (ei == 1 && wi % 3 == 0) {
        sets[1] = sets[1].copyWith(legs: [
          ...sets[1].legs,
          SetLeg(
            id: 'leg-d$wi-$ei-myo',
            weight: (w - 10).clamp(0, 9999).toDouble(),
            reps: 5,
            type: SetType.myo,
            at: finishedAt,
          ),
        ]);
      }

      if (slot.showcase) {
        if (ei == 0) {
          sets[0] = sets[0].copyWith(legs: [
            ...sets[0].legs,
            SetLeg(
              id: 'leg-d$wi-$ei-d1',
              weight: (w - 12.5).clamp(0, 9999).toDouble(),
              reps: 6,
              type: SetType.drop,
              at: finishedAt,
            ),
            SetLeg(
              id: 'leg-d$wi-$ei-d2',
              weight: (w - 25).clamp(0, 9999).toDouble(),
              reps: 8,
              type: SetType.drop,
              at: finishedAt,
            ),
          ]);
          sets.add(Approach(
            id: 'set-d$wi-$ei-4',
            at: finishedAt,
            legs: [
              SetLeg(
                id: 'leg-d$wi-$ei-c0',
                weight: (w - 5).clamp(0, 9999).toDouble(),
                reps: 5,
                type: SetType.cheat,
                at: finishedAt,
              ),
              SetLeg(
                id: 'leg-d$wi-$ei-c1',
                weight: (w - 20).clamp(0, 9999).toDouble(),
                reps: 6,
                type: SetType.drop,
                at: finishedAt,
              ),
            ],
          ));
        }
        if (ei == 1) {
          sets[1] = sets[1].copyWith(legs: [
            ...sets[1].legs,
            SetLeg(
              id: 'leg-d$wi-$ei-drop2',
              weight: (w - 15).clamp(0, 9999).toDouble(),
              reps: 8,
              type: SetType.drop,
              at: finishedAt,
            ),
          ]);
          sets[2] = sets[2].copyWith(legs: [
            ...sets[2].legs,
            SetLeg(
              id: 'leg-d$wi-$ei-myo2',
              weight: (w - 7.5).clamp(0, 9999).toDouble(),
              reps: 4,
              type: SetType.myo,
              at: finishedAt,
            ),
          ]);
        }
        if (ei == 2) {
          sets[0] = Approach(id: sets[0].id, at: finishedAt, legs: [
            SetLeg(id: 'leg-d$wi-$ei-bw', weight: 0, reps: 10, type: SetType.normal, at: finishedAt),
            SetLeg(id: 'leg-d$wi-$ei-myo', weight: 0, reps: 4, type: SetType.myo, at: finishedAt),
          ]);
          sets[1] = Approach(id: sets[1].id, at: finishedAt, legs: [
            SetLeg(id: 'leg-d$wi-$ei-bw2', weight: 0, reps: 8, type: SetType.normal, at: finishedAt),
            SetLeg(id: 'leg-d$wi-$ei-cheat', weight: 0, reps: 3, type: SetType.cheat, at: finishedAt),
          ]);
        }
        if (ei == 3) {
          sets[0] = sets[0].copyWith(legs: [
            ...sets[0].legs,
            SetLeg(
              id: 'leg-d$wi-$ei-d1',
              weight: (w - 5).clamp(0, 9999).toDouble(),
              reps: 12,
              type: SetType.drop,
              at: finishedAt,
            ),
            SetLeg(
              id: 'leg-d$wi-$ei-d2',
              weight: (w - 10).clamp(0, 9999).toDouble(),
              reps: 15,
              type: SetType.drop,
              at: finishedAt,
            ),
          ]);
          sets[2] = sets[2].copyWith(legs: [
            ...sets[2].legs,
            SetLeg(
              id: 'leg-d$wi-$ei-myo3',
              weight: (w - 2.5).clamp(0, 9999).toDouble(),
              reps: 8,
              type: SetType.myo,
              at: finishedAt,
            ),
          ]);
        }
      }

      final volume = sets.fold(0.0, (s, set) => s + approachVolume(set));
      final best1rm = sets.fold(0.0, (m, set) {
        final v = approachBest1rm(set);
        return m > v ? m : v;
      });
      exercises.add(WorkoutExercise(
        id: _id('ex'),
        name: ename,
        targetSets: tpl.exercises[ei].targetSets,
        sets: sets,
        volume: volume,
        best1rm: best1rm,
      ));
    }

    final tonnage =
        exercises.fold(0.0, (s, ex) => s + ex.volume) * slot.tonBias;
    history.add(WorkoutSession(
      id: 'wo-demo-$wi',
      name: tpl.name,
      startedAt: startedAt,
      finishedAt: finishedAt,
      tonnage: tonnage.roundToDouble(),
      exercises: exercises,
    ));
  }

  history.sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));
  return history;
}

Future<void> seedDatabase(AppDatabase db) async {
  final templates = defaultTemplates();
  for (final tpl in templates) {
    await db.upsertTemplate(tpl);
  }
  final history = buildDemoHistory(templates);
  for (final session in history) {
    await db.insertFinishedWorkout(session);
  }
}
