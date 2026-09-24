import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../domain/calc.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(appControllerProvider);
    final activeAsync = ref.watch(activeWorkoutProvider);
    final historyAsync = ref.watch(historyProvider);

    return SafeArea(
      child: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (active) {
          if (ui.viewingPastId != null && active == null) {
            return historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(child: Text('$e')),
              data: (history) {
                final past = history.where((h) => h.id == ui.viewingPastId).firstOrNull;
                if (past == null) {
                  return const Center(child: Text('Тренировка не найдена'));
                }
                return _PastWorkoutView(past: past);
              },
            );
          }

          if (active == null) {
            return historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(child: Text('$e')),
              data: (history) => _EmptyWorkoutView(history: history),
            );
          }

          return _ActiveWorkoutView(session: active);
        },
      ),
    );
  }
}

class _EmptyWorkoutView extends ConsumerWidget {
  const _EmptyWorkoutView({required this.history});

  final List<WorkoutSession> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = [...history]
      ..sort((a, b) => (b.finishedAt ?? b.startedAt).compareTo(a.finishedAt ?? a.startedAt));
    final top = recent.take(8).toList();
    final fmt = DateFormat('d MMM, HH:mm', 'ru');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const PageTitle('Тренировка', fontSize: 24),
        if (top.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Text(
              'Нет активной тренировки. Запустите шаблон или пустую сессию.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else ...[
          const SectionLabel('Прошлые тренировки'),
          ...top.map((h) {
            final setCount = h.exercises.fold(0, (s, e) => s + e.sets.length);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey('hist-${h.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => confirmDialog(
                  context,
                  title: 'Удалить тренировку?',
                  message: '«${h.name}» будет удалена из истории. Это нельзя отменить.',
                  confirmLabel: 'Удалить',
                  destructive: true,
                ),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete, color: AppColors.danger),
                ),
                onDismissed: (_) async {
                  await ref.read(appControllerProvider.notifier).deleteWorkout(h.id);
                  if (context.mounted) showAppToast(context, 'Тренировка удалена');
                },
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ref.read(appControllerProvider.notifier).openPastWorkout(h.id),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  h.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${NumberFormat.decimalPattern('ru').format(h.tonnage.round())} кг',
                                style: monoStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${fmt.format(h.finishedAt!)} · ${h.exercises.length} упр. · $setCount подх.',
                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _PastWorkoutView extends ConsumerWidget {
  const _PastWorkoutView({required this.past});

  final WorkoutSession past;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('d MMM, HH:mm', 'ru');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => ref.read(appControllerProvider.notifier).closePastWorkout(),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: AppColors.fg,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('← К списку'),
              ),
            ),
            IconButton(
              tooltip: 'Удалить тренировку',
              onPressed: () => _deletePast(context, ref),
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
          ],
        ),
        PageTitle(past.name, fontSize: 24),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Завершена · ${fmt.format(past.finishedAt!)}',
              style: const TextStyle(color: AppColors.accent, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _TonnageCard(tonnage: past.tonnage),
        const SizedBox(height: 12),
        ...past.exercises.asMap().entries.map((entry) {
          final i = entry.key;
          final ex = entry.value;
          return _ExerciseCard(
            exercise: ex.copyWith(id: 'past-${past.id}-$i'),
            readonly: true,
            pastSets: const [],
            selected: true,
          );
        }),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => _deletePast(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
              ),
            ),
            child: const Text('Удалить тренировку'),
          ),
        ),
      ],
    );
  }

  Future<void> _deletePast(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить тренировку?',
      message: '«${past.name}» будет удалена из истории. Это нельзя отменить.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(appControllerProvider.notifier).deleteWorkout(past.id);
    if (context.mounted) showAppToast(context, 'Тренировка удалена');
  }
}

class _ActiveWorkoutView extends ConsumerWidget {
  const _ActiveWorkoutView({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final ton = sessionTonnage(session);
    final activeId = ui.activeExerciseId ?? session.exercises.firstOrNull?.id;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              PageTitle(session.name, fontSize: 24),
              const SizedBox(height: 12),
              _TonnageCard(tonnage: ton),
              const SizedBox(height: 12),
              ...session.exercises.map((ex) {
                return FutureBuilder<List<Approach>>(
                  future: ref.read(databaseProvider).lastPastSetsForExercise(ex.name),
                  builder: (context, snap) {
                    final selected = activeId == ex.id;
                    return _ExerciseCard(
                      exercise: ex,
                      readonly: false,
                      pastSets: snap.data ?? const [],
                      selected: selected,
                      onSelect: () async {
                        final past =
                            await ref.read(databaseProvider).lastPastSetsForExercise(ex.name);
                        controller.setActiveExercise(ex.id, applyPrefill: true, past: past);
                        final nextIdx = ex.sets.length;
                        if (nextIdx < past.length && past[nextIdx].legs.isNotEmpty) {
                          final main = past[nextIdx].legs.firstWhere(
                            (l) => l.type == SetType.normal,
                            orElse: () => past[nextIdx].legs.first,
                          );
                          controller.setWeight(main.weight);
                          controller.setReps(main.reps);
                        }
                      },
                      onRename: () async {
                        final name = await _promptName(context, initial: ex.name, title: 'Переименовать');
                        if (name == null || name.trim().isEmpty) return;
                        await controller.renameExercise(session, ex.id, name);
                      },
                      onEditSet: (set) async {
                        final updated = await showEditApproachSheet(context, approach: set);
                        if (updated == null) return;
                        if (updated.legs.isEmpty) {
                          await controller.deleteSet(session, ex.id, set.id);
                          if (context.mounted) showAppToast(context, 'Подход удалён');
                          return;
                        }
                        await controller.updateApproach(session, ex.id, updated);
                      },
                      onDeleteSet: (setId) async {
                        await controller.deleteSet(session, ex.id, setId);
                        if (context.mounted) showAppToast(context, 'Подход удалён');
                      },
                    );
                  },
                );
              }),
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Добавить упражнение',
                onPressed: () async {
                  final name = await _promptName(context);
                  if (name == null || name.trim().isEmpty) return;
                  await controller.addExercise(session, name);
                },
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: OutlinedButton(
                  onPressed: () async {
                    final hasSets = session.exercises.any((e) => e.sets.isNotEmpty);
                    if (!hasSets) {
                      final ok = await confirmDialog(
                        context,
                        title: 'Отменить?',
                        message: 'Нет подходов. Отменить тренировку?',
                        confirmLabel: 'Отменить',
                        destructive: true,
                      );
                      if (!ok) return;
                    }
                    await controller.finishWorkout(session);
                    if (context.mounted && hasSets) {
                      showAppToast(context, 'Тренировка сохранена');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.32)),
                    backgroundColor: Color.lerp(AppColors.surface, AppColors.danger, 0.16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    ),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Завершить тренировку'),
                ),
              ),
            ],
          ),
        ),
        _InputPanel(session: session),
      ],
    );
  }

  Future<String?> _promptName(
    BuildContext context, {
    String? initial,
    String title = 'Название упражнения',
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Например, Жим лёжа'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

class _TonnageCard extends StatelessWidget {
  const _TonnageCard({required this.tonnage});

  final double tonnage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ТОННАЖ',
            style: monoStyle(
              fontSize: 10,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: NumberFormat.decimalPattern('ru').format(tonnage.round()),
              style: monoStyle(fontSize: 22, fontWeight: FontWeight.w600),
              children: [
                TextSpan(
                  text: ' кг',
                  style: monoStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.readonly,
    required this.pastSets,
    this.selected = false,
    this.onSelect,
    this.onRename,
    this.onEditSet,
    this.onDeleteSet,
  });

  final WorkoutExercise exercise;
  final bool readonly;
  final List<Approach> pastSets;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onRename;
  final ValueChanged<Approach>? onEditSet;
  final ValueChanged<String>? onDeleteSet;

  @override
  Widget build(BuildContext context) {
    final done = exercise.sets.length;
    final target = [
      exercise.targetSets,
      done,
      if (!readonly) pastSets.length,
    ].reduce((a, b) => a > b ? a : b);
    final maxLen = [
      exercise.sets.length,
      if (!readonly) pastSets.length,
      0,
    ].reduce((a, b) => a > b ? a : b);

    final activeBorder = Color.lerp(AppColors.border, AppColors.fg, 0.28)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: selected ? activeBorder : AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onSelect,
            onLongPress: readonly ? null : onRename,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  if (!readonly)
                    IconButton(
                      tooltip: 'Переименовать',
                      onPressed: onRename,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
                    ),
                  Row(
                    children: List.generate(target.clamp(0, 12), (i) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < done ? AppColors.fg : AppColors.border,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.muted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (selected || readonly)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: maxLen == 0
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Пока нет подходов.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    )
                  : Column(
                      children: List.generate(maxLen, (i) {
                        if (i < exercise.sets.length) {
                          final set = exercise.sets[i];
                          final row = _SetRow(
                            index: i,
                            set: set,
                            ghost: false,
                            onTap: readonly || onEditSet == null
                                ? null
                                : () => onEditSet!(set),
                          );
                          if (readonly || onDeleteSet == null) return row;
                          return Dismissible(
                            key: ValueKey(set.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: AppColors.danger.withValues(alpha: 0.2),
                              child: const Icon(Icons.delete, color: AppColors.danger),
                            ),
                            onDismissed: (_) => onDeleteSet!(set.id),
                            child: row,
                          );
                        }
                        return _SetRow(
                          index: i,
                          set: pastSets[i],
                          ghost: true,
                          isNext: i == exercise.sets.length,
                        );
                      }),
                    ),
            ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.set,
    required this.ghost,
    this.isNext = false,
    this.onTap,
  });

  final int index;
  final Approach set;
  final bool ghost;
  final bool isNext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Opacity(
      opacity: ghost ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isNext ? AppColors.surface.withValues(alpha: 0.55) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.right,
                style: monoStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                children: set.legs.map((leg) {
                  final color = ghost && leg.type == SetType.normal
                      ? AppColors.fg.withValues(alpha: 0.7)
                      : colorForSetType(leg.type);
                  return Text(
                    '${_fmtWeight(leg.weight)}×${leg.reps}',
                    style: monoStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: -0.32,
                    ),
                  );
                }).toList(),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: row,
      ),
    );
  }

  String _fmtWeight(double w) {
    if (w == w.roundToDouble()) return w.toStringAsFixed(0);
    return w.toStringAsFixed(1);
  }
}


class _InputPanel extends ConsumerStatefulWidget {
  const _InputPanel({required this.session});

  final WorkoutSession session;

  @override
  ConsumerState<_InputPanel> createState() => _InputPanelState();
}

class _InputPanelState extends ConsumerState<_InputPanel> {
  bool _menuOpen = false;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final ui = ref.read(appControllerProvider);
    _weightCtrl = TextEditingController(text: _fmtWeight(ui.weight));
    _repsCtrl = TextEditingController(text: ui.reps > 0 ? '${ui.reps}' : '');
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  String _fmtWeight(double w) {
    if (w == w.roundToDouble()) return w.toStringAsFixed(0);
    return w.toString();
  }

  void _syncFromUi({bool force = false}) {
    final ui = ref.read(appControllerProvider);
    final w = _fmtWeight(ui.weight);
    final r = ui.reps > 0 ? '${ui.reps}' : '';
    if (force || !_weightFocus.hasFocus) {
      if (_weightCtrl.text != w) _weightCtrl.text = w;
    }
    if (force || !_repsFocus.hasFocus) {
      if (_repsCtrl.text != r) _repsCtrl.text = r;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(appControllerProvider.select((s) => s.pendingLegType));
    final activeExerciseId = ref.watch(appControllerProvider.select((s) => s.activeExerciseId));
    final controller = ref.read(appControllerProvider.notifier);

    ref.listen(appControllerProvider.select((s) => s.activeExerciseId), (_, _) {
      _syncFromUi(force: true);
    });
    ref.listen(appControllerProvider.select((s) => s.pendingLegType), (_, _) {
      _syncFromUi(force: true);
    });
    ref.listen(appControllerProvider.select((s) => (s.weight, s.reps)), (_, _) {
      _syncFromUi();
    });

    final ex = widget.session.exercises.where((e) => e.id == activeExerciseId).firstOrNull ??
        widget.session.exercises.firstOrNull;
    final hasApproach = ex != null && ex.sets.isNotEmpty;
    final setCount = ex?.sets.length ?? 0;
    final armed = pending != SetType.normal;
    final tint = armed ? colorForSetType(pending) : null;

    return Material(
      color: Color.lerp(AppColors.bg, AppColors.surface, 0.5),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: EdgeInsets.fromLTRB(14, 12, 14, 12 + MediaQuery.paddingOf(context).bottom * 0.15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: NumericField(
                    label: 'Вес, кг',
                    controller: _weightCtrl,
                    focusNode: _weightFocus,
                    decimal: true,
                    tint: tint,
                    onChanged: (v) {
                      final parsed = double.tryParse(v.replaceAll(',', '.'));
                      if (parsed != null) controller.setWeight(parsed);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NumericField(
                    label: 'Повторы',
                    controller: _repsCtrl,
                    focusNode: _repsFocus,
                    tint: tint,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) {
                        controller.setReps(parsed);
                      } else if (v.isEmpty) {
                        controller.setReps(0);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      setState(() => _menuOpen = false);
                      try {
                        await controller.logSet(widget.session);
                        _syncFromUi(force: true);
                      } on ArgumentError {
                        if (context.mounted) {
                          showAppToast(context, 'Проверьте вес и повторы');
                        }
                      } on StateError catch (e) {
                        if (context.mounted && e.message == 'need_normal_first') {
                          showAppToast(context, 'Сначала запишите обычный подход');
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: tint ?? AppColors.accent,
                      foregroundColor: AppColors.accentOn,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.check, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_menuOpen && hasApproach) ...[
              _ExtendMenu(
                armed: armed,
                onPick: (type) {
                  controller.setPendingLegType(type);
                  setState(() => _menuOpen = false);
                },
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: hasApproach ? 1 : 0.35,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: !hasApproach
                        ? null
                        : () => setState(() => _menuOpen = !_menuOpen),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: armed ? tint! : AppColors.border,
                        ),
                        color: armed ? tint!.withValues(alpha: 0.22) : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            !hasApproach
                                ? '+ к подходу'
                                : armed
                                    ? pending.label
                                    : '+ к подходу · $setCount',
                            style: TextStyle(
                              color: hasApproach ? AppColors.fg : AppColors.muted,
                              fontWeight: armed ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _menuOpen ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtendMenu extends StatelessWidget {
  const _ExtendMenu({required this.armed, required this.onPick});

  final bool armed;
  final ValueChanged<SetType> onPick;

  @override
  Widget build(BuildContext context) {
    final items = <(SetType?, String, Color?)>[
      (SetType.drop, 'Дроп', AppColors.setDrop),
      (SetType.myo, 'Миорепы', AppColors.setMyo),
      (SetType.cheat, 'Читинг', AppColors.setCheat),
      if (armed) (SetType.normal, 'Сбросить тип', null),
    ];

    return Material(
      color: AppColors.surface,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) {
            return InkWell(
              onTap: () => onPick(item.$1!),
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    if (item.$3 != null)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.$3,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(width: 10),
                    const SizedBox(width: 10),
                    Text(
                      item.$2,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

Future<Approach?> showEditApproachSheet(
  BuildContext context, {
  required Approach approach,
}) {
  return showModalBottomSheet<Approach>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _EditApproachSheet(approach: approach),
  );
}

class _EditApproachSheet extends StatefulWidget {
  const _EditApproachSheet({required this.approach});

  final Approach approach;

  @override
  State<_EditApproachSheet> createState() => _EditApproachSheetState();
}

class _EditApproachSheetState extends State<_EditApproachSheet> {
  late List<_EditableLeg> _legs;

  @override
  void initState() {
    super.initState();
    _legs = widget.approach.legs
        .map(
          (leg) => _EditableLeg(
            id: leg.id,
            weight: TextEditingController(
              text: leg.weight == leg.weight.roundToDouble()
                  ? leg.weight.toStringAsFixed(0)
                  : leg.weight.toString(),
            ),
            reps: TextEditingController(text: '${leg.reps}'),
            type: leg.type,
            at: leg.at,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final leg in _legs) {
      leg.weight.dispose();
      leg.reps.dispose();
    }
    super.dispose();
  }

  Approach _buildResult() {
    final legs = <SetLeg>[];
    for (final leg in _legs) {
      final weight = double.tryParse(leg.weight.text.replaceAll(',', '.'));
      final reps = int.tryParse(leg.reps.text);
      if (weight == null || weight < 0 || reps == null || reps <= 0) continue;
      legs.add(
        SetLeg(
          id: leg.id,
          weight: weight,
          reps: reps,
          type: leg.type,
          at: leg.at,
        ),
      );
    }
    return widget.approach.copyWith(legs: legs);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Редактировать подход',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Измените вес, повторы или тип. Можно удалить часть или весь подход.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (_legs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Нет частей подхода. Сохраните, чтобы удалить.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              ...List.generate(_legs.length, (index) {
                final leg = _legs[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: index == _legs.length - 1 ? 0 : 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(AppColors.radius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: NumericField(
                                label: 'Вес',
                                controller: leg.weight,
                                decimal: true,
                                onChanged: (_) {},
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: NumericField(
                                label: 'Повторы',
                                controller: leg.reps,
                                onChanged: (_) {},
                              ),
                            ),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () {
                                setState(() {
                                  leg.weight.dispose();
                                  leg.reps.dispose();
                                  _legs.removeAt(index);
                                });
                              },
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: SetType.values.map((type) {
                            final selected = leg.type == type;
                            final color = colorForSetType(type);
                            return ChoiceChip(
                              label: Text(type.label),
                              selected: selected,
                              onSelected: (_) => setState(() => leg.type = type),
                              selectedColor: color.withValues(alpha: 0.28),
                              labelStyle: TextStyle(
                                color: selected ? color : AppColors.fg,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                              ),
                              side: BorderSide(color: selected ? color : AppColors.border),
                              backgroundColor: AppColors.surface,
                              showCheckmark: false,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Сохранить',
              onPressed: () => Navigator.pop(context, _buildResult()),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                widget.approach.copyWith(legs: const []),
              ),
              child: const Text(
                'Удалить подход',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableLeg {
  _EditableLeg({
    required this.id,
    required this.weight,
    required this.reps,
    required this.type,
    required this.at,
  });

  final String id;
  final TextEditingController weight;
  final TextEditingController reps;
  SetType type;
  final DateTime at;
}
