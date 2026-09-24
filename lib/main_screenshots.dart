import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import 'data/database.dart';
import 'data/seed.dart';
import 'domain/models.dart';
import 'main.dart';
import 'providers/app_providers.dart';
import 'theme/app_theme.dart';
import 'ui/shell.dart';

/// Desktop entry used only to dump real UI PNGs into docs/screenshots.
/// Uses an in-memory DB so the user's real Lift Log data is never touched.
///
///   flutter run -d windows -t lib/main_screenshots.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');

  final db = AppDatabase(NativeDatabase.memory());
  await db.ensureSeeded();
  await seedDatabase(db);

  // Showcase active workout with a couple of logged sets.
  await db.replaceActiveWorkout(
    WorkoutSession(
      id: AppDatabase.newId('wo'),
      name: 'Push Day',
      startedAt: DateTime.now().subtract(const Duration(minutes: 32)),
      exercises: [
        WorkoutExercise(
          id: AppDatabase.newId('ex'),
          name: 'Жим лёжа',
          targetSets: 4,
          sets: [
            Approach(
              id: AppDatabase.newId('set'),
              at: DateTime.now(),
              legs: [
                SetLeg(id: AppDatabase.newId('leg'), weight: 80, reps: 8, at: DateTime.now()),
              ],
            ),
            Approach(
              id: AppDatabase.newId('set'),
              at: DateTime.now(),
              legs: [
                SetLeg(id: AppDatabase.newId('leg'), weight: 80, reps: 7, at: DateTime.now()),
                SetLeg(
                  id: AppDatabase.newId('leg'),
                  weight: 60,
                  reps: 6,
                  type: SetType.drop,
                  at: DateTime.now(),
                ),
              ],
            ),
          ],
        ),
        WorkoutExercise(
          id: AppDatabase.newId('ex'),
          name: 'Жим стоя',
          targetSets: 3,
        ),
        WorkoutExercise(
          id: AppDatabase.newId('ex'),
          name: 'Разгибания на блоке',
          targetSets: 3,
        ),
      ],
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const _ScreenshotApp(),
    ),
  );
}

class _ScreenshotApp extends ConsumerStatefulWidget {
  const _ScreenshotApp();

  @override
  ConsumerState<_ScreenshotApp> createState() => _ScreenshotAppState();
}

class _ScreenshotAppState extends ConsumerState<_ScreenshotApp> {
  final _key = GlobalKey();
  var _done = false;
  var _status = 'Готовлю скриншоты…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_done) return;
    final outDir = Directory(p.join(Directory.current.path, 'docs', 'screenshots'));
    await outDir.create(recursive: true);
    final controller = ref.read(appControllerProvider.notifier);

    Future<void> shot(String name) async {
      setState(() => _status = 'Сохраняю $name');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(p.join(outDir.path, name));
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    }

    // Active workout first (DB already has active session)
    controller.setTab(1);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
    await shot('02-active-workout.png');

    // Templates
    controller.setTab(0);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
    await shot('01-templates.png');

    // History list (no active)
    await ref.read(databaseProvider).cancelActiveWorkout();
    controller.setTab(1);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
    await shot('03-history.png');

    // Stats workouts
    controller.setTab(2);
    controller.setStatsSection(StatsSection.workouts);
    controller.setStatsWorkout(null);
    controller.setStatsWorkoutCard(0);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() {});
    await shot('04-stats-workouts.png');

    // Stats exercise working weight
    controller.setStatsSection(StatsSection.exercises);
    controller.setStatsExercise('Жим лёжа');
    controller.setStatsExerciseCard(0);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() {});
    await shot('05-stats-working-weight.png');

    if (!mounted) return;
    setState(() {
      _done = true;
      _status = 'Готово — файлы в docs/screenshots. Можно закрыть окно.';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Phone-like frame on desktop for README screenshots.
    const phone = Size(390, 844);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0E0E0E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: phone.width,
                height: phone.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: phone,
                    textScaler: TextScaler.noScaling,
                    padding: EdgeInsets.only(top: 12),
                  ),
                  child: RepaintBoundary(
                    key: _key,
                    child: const ColoredBox(
                      color: AppColors.bg,
                      child: AppShell(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(_status, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
