import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/calc.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(appControllerProvider);
    final historyAsync = ref.watch(historyProvider);
    final namesAsync = ref.watch(exerciseNamesProvider);

    return SafeArea(
      child: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('$e')),
        data: (history) {
          return namesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (e, _) => Center(child: Text('$e')),
            data: (names) {
              final exercise =
                  (ui.statsExercise != null && names.contains(ui.statsExercise))
                      ? ui.statsExercise!
                      : (names.isNotEmpty ? names.first : null);

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageTitle('Статистика'),
                    const SizedBox(height: 12),
                    _SectionToggle(
                      section: ui.statsSection,
                      onChanged: (s) =>
                          ref.read(appControllerProvider.notifier).setStatsSection(s),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ui.statsSection == StatsSection.workouts
                          ? _WorkoutsSlider(
                              history: history,
                              workoutName: ui.statsWorkout,
                            )
                          : _ExercisesSlider(
                              history: history,
                              names: names,
                              exercise: exercise,
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({required this.section, required this.onChanged});

  final StatsSection section;
  final ValueChanged<StatsSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _seg(
            label: 'Тренировки',
            on: section == StatsSection.workouts,
            onTap: () => onChanged(StatsSection.workouts),
          ),
          _seg(
            label: 'Упражнения',
            on: section == StatsSection.exercises,
            onTap: () => onChanged(StatsSection.exercises),
          ),
        ],
      ),
    );
  }

  Widget _seg({
    required String label,
    required bool on,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: on ? AppColors.fg.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: on ? AppColors.fg : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Workouts carousel (session tonnage) ──────────────────────────────────────

class _WorkoutsSlider extends ConsumerStatefulWidget {
  const _WorkoutsSlider({
    required this.history,
    required this.workoutName,
  });

  final List<WorkoutSession> history;
  final String? workoutName;

  @override
  ConsumerState<_WorkoutsSlider> createState() => _WorkoutsSliderState();
}

class _WorkoutsSliderState extends ConsumerState<_WorkoutsSlider> {
  late final PageController _pageController;
  bool _pageAnimating = false;

  static const _count = AppController.workoutCardCount;
  static const _allLabel = 'Все тренировки';

  List<String> get _workoutNames {
    final names = <String>{};
    for (final h in widget.history) {
      final n = h.name.trim();
      if (n.isNotEmpty) names.add(n);
    }
    final list = names.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: ref.read(appControllerProvider).statsWorkoutCard.clamp(0, _count - 1),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int i) async {
    if (!_pageController.hasClients) return;
    _pageAnimating = true;
    ref.read(appControllerProvider.notifier).setStatsWorkoutCard(i);
    await _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _pageAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(appControllerProvider).statsWorkoutCard;
    final names = _workoutNames;
    final selected = widget.workoutName;
    final validSelected = selected != null && names.contains(selected) ? selected : null;
    final filtered = validSelected == null
        ? widget.history
        : widget.history.where((h) => h.name == validSelected).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PickerTrigger(
          caption: 'ТРЕНИРОВКА',
          label: validSelected ?? _allLabel,
          enabled: names.isNotEmpty,
          onTap: () async {
            if (names.isEmpty) {
              showAppToast(context, 'Нет завершённых тренировок');
              return;
            }
            final options = [_allLabel, ...names];
            final initial = validSelected ?? _allLabel;
            final picked = await showStatsWheel(
              context,
              names: options,
              initial: initial,
              title: 'Тренировка',
            );
            if (!context.mounted || picked == null) return;
            ref.read(appControllerProvider.notifier).setStatsWorkout(
                  picked == _allLabel ? null : picked,
                );
          },
        ),
        const SizedBox(height: 12),
        _CardSegment(
          labels: const ['По тренировкам', '30 дней', 'Сводка'],
          index: index,
          onChanged: _goToPage,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PageView(
                  scrollDirection: Axis.vertical,
                  controller: _pageController,
                  physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
                  onPageChanged: (i) {
                    if (_pageAnimating) return;
                    ref.read(appControllerProvider.notifier).setStatsWorkoutCard(i);
                  },
                  children: [
                    _SessionTonnageCard(history: filtered),
                    _DailyTonnageCard(history: filtered),
                    _WorkoutSummaryCard(history: filtered),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatsDots(count: _count, index: index, onTap: _goToPage),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Exercises carousel (working weight) ──────────────────────────────────────

class _ExercisesSlider extends ConsumerStatefulWidget {
  const _ExercisesSlider({
    required this.history,
    required this.names,
    required this.exercise,
  });

  final List<WorkoutSession> history;
  final List<String> names;
  final String? exercise;

  @override
  ConsumerState<_ExercisesSlider> createState() => _ExercisesSliderState();
}

class _ExercisesSliderState extends ConsumerState<_ExercisesSlider> {
  late final PageController _pageController;
  bool _pageAnimating = false;

  static const _count = AppController.exerciseCardCount;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: ref.read(appControllerProvider).statsExerciseCard.clamp(0, _count - 1),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int i) async {
    if (!_pageController.hasClients) return;
    _pageAnimating = true;
    ref.read(appControllerProvider.notifier).setStatsExerciseCard(i);
    await _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _pageAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(appControllerProvider).statsExerciseCard;
    final exercise = widget.exercise;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PickerTrigger(
          caption: 'УПРАЖНЕНИЕ',
          label: exercise ?? 'Нет упражнений',
          enabled: widget.names.isNotEmpty,
          onTap: () async {
            if (widget.names.isEmpty) {
              showAppToast(context, 'Нет упражнений');
              return;
            }
            final picked = await showStatsWheel(
              context,
              names: widget.names,
              initial: exercise ?? widget.names.first,
              title: 'Упражнение',
            );
            if (!context.mounted) return;
            if (picked != null) {
              ref.read(appControllerProvider.notifier).setStatsExercise(picked);
            }
          },
        ),
        const SizedBox(height: 12),
        _CardSegment(
          labels: const ['Рабочий вес', '1ПМ', 'Сводка'],
          index: index,
          onChanged: _goToPage,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: exercise == null
              ? const _ChartShell(
                  title: 'Упражнения',
                  sub: '',
                  child: Center(
                    child: Text(
                      'Добавьте шаблон или завершите тренировку',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: PageView(
                        scrollDirection: Axis.vertical,
                        controller: _pageController,
                        physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
                        onPageChanged: (i) {
                          if (_pageAnimating) return;
                          ref.read(appControllerProvider.notifier).setStatsExerciseCard(i);
                        },
                        children: [
                          _WorkingWeightCard(history: widget.history, exercise: exercise),
                          _OrmCard(history: widget.history, exercise: exercise),
                          _ExerciseSummaryCard(history: widget.history, exercise: exercise),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatsDots(count: _count, index: index, onTap: _goToPage),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CardSegment extends StatelessWidget {
  const _CardSegment({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final on = i == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: on ? AppColors.fg.withValues(alpha: 0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.fg : AppColors.muted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PickerTrigger extends StatelessWidget {
  const _PickerTrigger({
    required this.caption,
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  final String caption;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radius),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: monoStyle(
                        fontSize: 11,
                        letterSpacing: 0.4,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsDots extends StatelessWidget {
  const _StatsDots({
    required this.count,
    required this.index,
    required this.onTap,
  });

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final on = i == index;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 7,
              height: on ? 16 : 7,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: on ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: on ? null : Border.all(color: AppColors.border),
              ),
            ),
          );
        }),
      ),
    );
  }
}

Future<String?> showStatsWheel(
  BuildContext context, {
  required List<String> names,
  required String initial,
  String title = 'Выбор',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    enableDrag: false,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _WheelSheet(
      names: List<String>.from(names),
      initial: initial,
      title: title,
    ),
  );
}

class _WheelSheet extends StatefulWidget {
  const _WheelSheet({
    required this.names,
    required this.initial,
    required this.title,
  });

  final List<String> names;
  final String initial;
  final String title;

  @override
  State<_WheelSheet> createState() => _WheelSheetState();
}

class _WheelSheetState extends State<_WheelSheet> {
  static const itemExtent = 40.0;
  late FixedExtentScrollController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.names.indexOf(widget.initial);
    if (_index < 0) _index = 0;
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _draft => widget.names[_index.clamp(0, widget.names.length - 1)];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: 340,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Отмена', style: TextStyle(color: AppColors.muted)),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: const Text(
                        'Готово',
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) => true,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IgnorePointer(
                        child: Container(
                          height: itemExtent,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.fg.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        controller: _controller,
                        itemExtent: itemExtent,
                        diameterRatio: 1.8,
                        perspective: 0.003,
                        squeeze: 1.0,
                        useMagnifier: false,
                        overAndUnderCenterOpacity: 0.45,
                        physics: const FixedExtentScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        onSelectedItemChanged: (i) => setState(() => _index = i),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: widget.names.length,
                          builder: (context, i) {
                            final on = i == _index;
                            return Center(
                              child: Text(
                                widget.names[i],
                                style: TextStyle(
                                  fontSize: on ? 20 : 18,
                                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                                  color: on ? AppColors.fg : AppColors.muted,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartShell extends StatelessWidget {
  const _ChartShell({
    required this.title,
    required this.sub,
    required this.child,
    this.kpis = const [],
  });

  final String title;
  final String sub;
  final Widget child;
  final List<(String, String)> kpis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              if (sub.isNotEmpty)
                Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
            ],
          ),
          if (kpis.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: kpis
                  .map(
                    (k) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.fg.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              k.$1,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              k.$2,
                              style: monoStyle(fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

String _fmt(num n) => NumberFormat.decimalPattern('ru').format(n.round());

String _fmtKg(num n) {
  if (n == n.roundToDouble()) return _fmt(n);
  return NumberFormat('#0.#', 'ru').format(n);
}

List<(DateTime, double)> _sessionTonnageSeries(List<WorkoutSession> history) {
  final points = <(DateTime, double)>[];
  for (final h in history) {
    if (h.finishedAt == null) continue;
    points.add((h.finishedAt!, h.tonnage));
  }
  return points;
}

List<(DateTime, double)> _workingWeightSeries(
  List<WorkoutSession> history,
  String exerciseName,
) {
  final points = <(DateTime, double)>[];
  for (final h in history) {
    if (h.finishedAt == null) continue;
    final ex = h.exercises.where((e) => e.name == exerciseName).firstOrNull;
    if (ex == null) continue;
    final ww = workingWeightForExercise(ex);
    if (ww == null) continue;
    points.add((h.finishedAt!, ww));
  }
  return points;
}

List<(DateTime, double)> _exerciseOrmSeries(
  List<WorkoutSession> history,
  String exerciseName,
) {
  final points = <(DateTime, double)>[];
  for (final h in history) {
    if (h.finishedAt == null) continue;
    final ex = h.exercises.where((e) => e.name == exerciseName).firstOrNull;
    if (ex == null || ex.best1rm <= 0) continue;
    points.add((h.finishedAt!, ex.best1rm));
  }
  return points;
}

class _SessionTonnageCard extends StatelessWidget {
  const _SessionTonnageCard({required this.history});
  final List<WorkoutSession> history;

  @override
  Widget build(BuildContext context) {
    final series = _sessionTonnageSeries(history);
    final last12 = series.length > 12 ? series.sublist(series.length - 12) : series;
    if (last12.isEmpty) {
      return const _ChartShell(
        title: 'Тоннаж тренировок',
        sub: 'кг',
        child: Center(
          child: Text(
            'Завершите тренировки — здесь появится тоннаж',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    final ys = last12.map((s) => s.$2).toList();
    final last = ys.last;
    final avg = ys.reduce((a, b) => a + b) / ys.length;
    final delta = ys.length > 1 ? last - ys.first : 0.0;
    return _ChartShell(
      title: 'Тоннаж тренировок',
      sub: 'по сессиям',
      kpis: [
        ('Последний', _fmt(last)),
        ('Средний', _fmt(avg)),
        ('Δ период', '${delta >= 0 ? '+' : ''}${_fmt(delta)}'),
      ],
      child: _LineChart(points: last12),
    );
  }
}

class _DailyTonnageCard extends StatelessWidget {
  const _DailyTonnageCard({required this.history});
  final List<WorkoutSession> history;

  @override
  Widget build(BuildContext context) {
    final days = _tonnageDays(history, 30);
    if (!days.any((d) => d.$2 > 0)) {
      return const _ChartShell(
        title: 'Тоннаж',
        sub: '30 дней',
        child: Center(
          child: Text(
            'Завершите тренировки — здесь появится тоннаж',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    final total = days.fold(0.0, (s, d) => s + d.$2);
    final activeDays = days.where((d) => d.$2 > 0).length;
    final peak = days.map((d) => d.$2).reduce((a, b) => a > b ? a : b);
    return _ChartShell(
      title: 'Тоннаж',
      sub: 'последние 30 дней',
      kpis: [
        ('Сумма', _fmt(total)),
        ('Дней', '$activeDays'),
        ('Пик/день', _fmt(peak)),
      ],
      child: _BarChart(days: days),
    );
  }
}

class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard({required this.history});
  final List<WorkoutSession> history;

  @override
  Widget build(BuildContext context) {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final recent =
        history.where((h) => h.finishedAt != null && h.finishedAt!.isAfter(since)).toList();
    final totalTon = recent.fold(0.0, (s, h) => s + h.tonnage);
    final avgTon = recent.isEmpty ? 0.0 : totalTon / recent.length;
    final best = [...recent]..sort((a, b) => b.tonnage.compareTo(a.tonnage));
    final fmtDate = DateFormat('d MMM', 'ru');

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
            Text(value, style: monoStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return _ChartShell(
      title: 'Сводка · тренировки',
      sub: '30 дней',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          row('Тренировок', '${recent.length}'),
          row('Суммарный тоннаж', '${_fmt(totalTon)} кг'),
          row('Средний тоннаж', '${_fmt(avgTon)} кг'),
          row(
            'Лучший день',
            best.isEmpty
                ? '—'
                : '${_fmt(best.first.tonnage)} · ${fmtDate.format(best.first.finishedAt!)}',
          ),
        ],
      ),
    );
  }
}

class _WorkingWeightCard extends StatelessWidget {
  const _WorkingWeightCard({required this.history, required this.exercise});
  final List<WorkoutSession> history;
  final String exercise;

  @override
  Widget build(BuildContext context) {
    final series = _workingWeightSeries(history, exercise);
    final last12 = series.length > 12 ? series.sublist(series.length - 12) : series;
    if (last12.isEmpty) {
      return _ChartShell(
        title: 'Рабочий вес',
        sub: 'кг',
        child: Center(
          child: Text(
            'Пока нет обычных подходов по «$exercise»',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    final ys = last12.map((s) => s.$2).toList();
    final last = ys.last;
    final peak = ys.reduce((a, b) => a > b ? a : b);
    final delta = ys.length > 1 ? last - ys.first : 0.0;
    return _ChartShell(
      title: 'Рабочий вес',
      sub: 'мода · кг',
      kpis: [
        ('Сейчас', _fmtKg(last)),
        ('Пик', _fmtKg(peak)),
        ('Δ период', '${delta >= 0 ? '+' : ''}${_fmtKg(delta)}'),
      ],
      child: _LineChart(points: last12, padZero: false, precise: true),
    );
  }
}

class _OrmCard extends StatelessWidget {
  const _OrmCard({required this.history, required this.exercise});
  final List<WorkoutSession> history;
  final String exercise;

  @override
  Widget build(BuildContext context) {
    final series = _exerciseOrmSeries(history, exercise);
    final last12 = series.length > 12 ? series.sublist(series.length - 12) : series;
    if (last12.isEmpty) {
      return const _ChartShell(
        title: 'Оценка 1ПМ',
        sub: 'Epley',
        child: Center(
          child: Text('Недостаточно данных для 1ПМ', style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    final ys = last12.map((s) => s.$2).toList();
    return _ChartShell(
      title: 'Оценка 1ПМ',
      sub: 'Epley · кг',
      kpis: [
        ('Сейчас', _fmt(ys.last)),
        ('Пик', _fmt(ys.reduce((a, b) => a > b ? a : b))),
        ('Средняя', _fmt(ys.reduce((a, b) => a + b) / ys.length)),
      ],
      child: _LineChart(points: last12, padZero: false, precise: true),
    );
  }
}

class _ExerciseSummaryCard extends StatelessWidget {
  const _ExerciseSummaryCard({required this.history, required this.exercise});
  final List<WorkoutSession> history;
  final String exercise;

  @override
  Widget build(BuildContext context) {
    final ww = _workingWeightSeries(history, exercise);
    final orm = _exerciseOrmSeries(history, exercise);
    final fmtDate = DateFormat('d MMM', 'ru');

    final bestWw = ww.isEmpty ? null : ww.map((s) => s.$2).reduce((a, b) => a > b ? a : b);
    final lastWw = ww.isEmpty ? null : ww.last;
    final bestOrm = orm.isEmpty ? null : orm.map((s) => s.$2).reduce((a, b) => a > b ? a : b);
    final sessions = ww.length;

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
            Text(value, style: monoStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return _ChartShell(
      title: 'Сводка · $exercise',
      sub: '',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          row('Сессий с упражнением', '$sessions'),
          row(
            'Текущий рабочий вес',
            lastWw == null
                ? '—'
                : '${_fmtKg(lastWw.$2)} кг · ${fmtDate.format(lastWw.$1)}',
          ),
          row('Лучший рабочий вес', bestWw == null ? '—' : '${_fmtKg(bestWw)} кг'),
          row('Лучший 1ПМ', bestOrm == null ? '—' : '${_fmt(bestOrm)} кг'),
        ],
      ),
    );
  }
}

List<(DateTime, double)> _tonnageDays(List<WorkoutSession> history, int windowDays) {
  final start = DateTime.now();
  final day0 = DateTime(start.year, start.month, start.day);
  return List.generate(windowDays, (i) {
    final dayStart = day0.subtract(Duration(days: windowDays - 1 - i));
    final dayEnd = dayStart.add(const Duration(days: 1));
    final ton = history
        .where((h) =>
            h.finishedAt != null &&
            !h.finishedAt!.isBefore(dayStart) &&
            h.finishedAt!.isBefore(dayEnd))
        .fold(0.0, (s, h) => s + h.tonnage);
    return (dayStart, ton);
  });
}

class _LineChart extends StatefulWidget {
  const _LineChart({
    required this.points,
    this.padZero = true,
    this.precise = false,
  });

  final List<(DateTime, double)> points;
  final bool padZero;
  /// When true, show one decimal for weights (working weight); else round.
  final bool precise;

  @override
  State<_LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<_LineChart> {
  int? _selected;

  String _valueLabel(double v) =>
      widget.precise ? '${_fmtKg(v)} кг' : '${_fmt(v)} кг';

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final ys = points.map((p) => p.$2);
    final rawMax = ys.reduce((a, b) => a > b ? a : b);
    final rawMin = widget.padZero ? 0.0 : ys.reduce((a, b) => a < b ? a : b);
    final span = (rawMax - rawMin).abs();
    final pad = span <= 0 ? (rawMax == 0 ? 1.0 : rawMax * 0.08) : span * 0.12;
    final minY = widget.padZero ? 0.0 : (rawMin - pad).clamp(0.0, double.infinity);
    final maxY = rawMax + pad;
    final fmt = DateFormat('d MMM', 'ru');
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY <= minY ? minY + 1 : maxY,
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchSpotThreshold: 28,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      const FlLine(color: AppColors.accent, strokeWidth: 1.2),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, idx) => FlDotCirclePainter(
                          radius: 7,
                          color: AppColors.accent,
                          strokeWidth: 3,
                          strokeColor: AppColors.bg,
                        ),
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  maxContentWidth: 200,
                  tooltipBorderRadius: BorderRadius.circular(12),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  tooltipBorder: const BorderSide(color: AppColors.border),
                  getTooltipColor: (_) => AppColors.surface,
                  getTooltipItems: (spots) {
                    return spots.map((s) {
                      final i = s.x.round().clamp(0, points.length - 1);
                      final p = points[i];
                      return LineTooltipItem(
                        '${fmt.format(p.$1)}\n${_valueLabel(p.$2)}',
                        monoStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.fg,
                        ),
                        textAlign: TextAlign.center,
                      );
                    }).toList();
                  },
                ),
                touchCallback: (event, response) {
                  final spot = response?.lineBarSpots?.firstOrNull;
                  if (spot == null) {
                    if (event is FlTapUpEvent ||
                        event is FlPanEndEvent ||
                        event is FlLongPressEnd) {
                      // keep last selection visible under the chart
                    }
                    return;
                  }
                  final i = spot.x.round().clamp(0, points.length - 1);
                  if (_selected != i) setState(() => _selected = i);
                },
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (v, _) => Text(
                      widget.precise ? _fmtKg(v) : _fmt(v),
                      style: monoStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.round();
                      if (i < 0 || i >= points.length) return const SizedBox.shrink();
                      if (points.length > 6 && i != 0 && i != points.length - 1 && i.isOdd) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        fmt.format(points[i].$1),
                        style: monoStyle(fontSize: 11, color: AppColors.muted),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].$2),
                  ],
                  isCurved: false,
                  color: AppColors.accent,
                  barWidth: 2.4,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) {
                      final on = selected == index;
                      return FlDotCirclePainter(
                        radius: on ? 6.5 : 4.5,
                        color: AppColors.accent,
                        strokeWidth: on ? 2.5 : 1.5,
                        strokeColor: AppColors.bg,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(show: true, color: AppColors.accentSoft),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SelectionBanner(
          text: selected == null
              ? 'Нажмите на точку, чтобы увидеть точное значение'
              : '${fmt.format(points[selected].$1)}  ·  ${_valueLabel(points[selected].$2)}',
          active: selected != null,
        ),
      ],
    );
  }
}

class _BarChart extends StatefulWidget {
  const _BarChart({required this.days});
  final List<(DateTime, double)> days;

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final maxY = days.map((d) => d.$2).reduce((a, b) => a > b ? a : b) * 1.15;
    final fmt = DateFormat('d MMM', 'ru');
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY,
              barTouchData: BarTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchExtraThreshold: const EdgeInsets.all(16),
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipBorderRadius: BorderRadius.circular(12),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  tooltipBorder: const BorderSide(color: AppColors.border),
                  getTooltipColor: (_) => AppColors.surface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final i = group.x;
                    if (i < 0 || i >= days.length) return null;
                    final d = days[i];
                    return BarTooltipItem(
                      '${fmt.format(d.$1)}\n${_fmt(d.$2)} кг',
                      monoStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.fg,
                      ),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  final group = response?.spot?.touchedBarGroupIndex;
                  if (group == null) return;
                  if (group < 0 || group >= days.length) return;
                  if (days[group].$2 <= 0) return;
                  if (_selected != group) setState(() => _selected = group);
                },
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (v, _) => Text(
                      _fmt(v),
                      style: monoStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (![0, 9, 19, 29].contains(i) || i >= days.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        fmt.format(days[i].$1),
                        style: monoStyle(fontSize: 11, color: AppColors.muted),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: days[i].$2,
                        color: days[i].$2 > 0
                            ? (selected == i ? AppColors.fg : AppColors.accent)
                            : AppColors.border,
                        width: selected == i ? 6 : 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SelectionBanner(
          text: selected == null
              ? 'Нажмите на столбец, чтобы увидеть тоннаж'
              : '${fmt.format(days[selected].$1)}  ·  ${_fmt(days[selected].$2)} кг',
          active: selected != null,
        ),
      ],
    );
  }
}

class _SelectionBanner extends StatelessWidget {
  const _SelectionBanner({
    required this.text,
    required this.active,
  });

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: active ? AppColors.accentSoft : AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.accent.withValues(alpha: 0.35) : AppColors.border,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: monoStyle(
          fontSize: active ? 17 : 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AppColors.fg : AppColors.muted,
        ),
      ),
    );
  }
}
