import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

Future<void> showTemplateEditor(
  BuildContext context,
  WidgetRef ref, {
  WorkoutTemplate? existing,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, anim, secondary) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (ctx, anim, secondary, child) {
      final size = MediaQuery.sizeOf(ctx);
      final inset = MediaQuery.viewInsetsOf(ctx);
      final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      return FadeTransition(
        opacity: fade,
        child: SafeArea(
          child: Padding(
            // Lift the whole sheet above the keyboard.
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + inset.bottom),
            child: Center(
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: size.width.clamp(0, 520),
                  height: (size.height - inset.bottom) * 0.92,
                  child: _TemplateEditorBody(existing: existing),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _TemplateEditorBody extends ConsumerStatefulWidget {
  const _TemplateEditorBody({this.existing});

  final WorkoutTemplate? existing;

  @override
  ConsumerState<_TemplateEditorBody> createState() => _TemplateEditorBodyState();
}

class _TemplateEditorBodyState extends ConsumerState<_TemplateEditorBody> {
  static const _addCooldown = Duration(milliseconds: 450);

  late final TextEditingController _nameCtrl;
  late List<TemplateExercise> _exercises;
  final Map<String, TextEditingController> _nameCtrls = {};
  final Map<String, FocusNode> _focusNodes = {};
  final ScrollController _scrollCtrl = ScrollController();

  bool _addingLocked = false;
  DateTime? _lastAddAt;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    final initial = existing != null
        ? existing.exercises
            .map((e) => TemplateExercise(
                  id: AppDatabase.newId('tex'),
                  name: e.name,
                  targetSets: e.targetSets,
                ))
            .toList()
        : [TemplateExercise(id: AppDatabase.newId('tex'), name: '', targetSets: 4)];
    _exercises = initial;
    for (final ex in _exercises) {
      _nameCtrls[ex.id] = TextEditingController(text: ex.name);
      _focusNodes[ex.id] = FocusNode();
    }
  }

  TextEditingController _ctrlFor(TemplateExercise ex) {
    return _nameCtrls.putIfAbsent(ex.id, () => TextEditingController(text: ex.name));
  }

  FocusNode _focusFor(String id) {
    return _focusNodes.putIfAbsent(id, FocusNode.new);
  }

  void _syncNamesFromControllers() {
    _exercises = [
      for (final ex in _exercises) ex.copyWith(name: _ctrlFor(ex).text),
    ];
  }

  void _disposeEx(String id) {
    _nameCtrls.remove(id)?.dispose();
    _focusNodes.remove(id)?.dispose();
  }

  Future<void> _scrollToExercise(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    if (_scrollCtrl.hasClients) {
      await _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    // Focus after layout settles so the keyboard/field stay visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusFor(id).requestFocus();
    });
  }

  Future<void> _addExercise() async {
    final now = DateTime.now();
    if (_addingLocked) return;
    if (_lastAddAt != null && now.difference(_lastAddAt!) < _addCooldown) return;

    _addingLocked = true;
    _lastAddAt = now;
    _syncNamesFromControllers();

    final ex = TemplateExercise(
      id: AppDatabase.newId('tex'),
      name: '',
      targetSets: 4,
    );
    setState(() {
      _exercises.add(ex);
      _nameCtrls[ex.id] = TextEditingController();
      _focusNodes[ex.id] = FocusNode();
    });

    await _scrollToExercise(ex.id);

    if (mounted) {
      setState(() => _addingLocked = false);
    } else {
      _addingLocked = false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scrollCtrl.dispose();
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    _nameCtrls.clear();
    _focusNodes.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final canAdd = !_addingLocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isEdit ? 'Изменить шаблон' : 'Новый шаблон',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _nameCtrl,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Название',
              hintText: 'Например, Push Day',
              counterText: '',
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('Упражнения', style: TextStyle(color: AppColors.muted)),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            scrollController: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _exercises.length,
            onReorderItem: (oldIndex, newIndex) {
              _syncNamesFromControllers();
              setState(() {
                final item = _exercises.removeAt(oldIndex);
                _exercises.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final ex = _exercises[index];
              final nameCtrl = _ctrlFor(ex);
              return Container(
                key: ValueKey(ex.id),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                decoration: BoxDecoration(
                  color: AppColors.bg.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 44,
                            child: TextField(
                              controller: nameCtrl,
                              focusNode: _focusFor(ex.id),
                              maxLength: 48,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Название упражнения',
                                counterText: '',
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Подходы',
                                style: monoStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StepBtn(
                                icon: Icons.remove,
                                onTap: () {
                                  _syncNamesFromControllers();
                                  setState(() {
                                    final cur = _exercises[index];
                                    _exercises[index] = cur.copyWith(
                                      targetSets: (cur.targetSets - 1).clamp(1, 20),
                                    );
                                  });
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '${ex.targetSets}',
                                  style: monoStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ),
                              _StepBtn(
                                icon: Icons.add,
                                onTap: () {
                                  _syncNamesFromControllers();
                                  setState(() {
                                    final cur = _exercises[index];
                                    _exercises[index] = cur.copyWith(
                                      targetSets: (cur.targetSets + 1).clamp(1, 20),
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _syncNamesFromControllers();
                        setState(() {
                          final removed = _exercises.removeAt(index);
                          _disposeEx(removed.id);
                        });
                      },
                      icon: const Icon(Icons.close, size: 20, color: AppColors.danger),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          color: AppColors.surface,
                        ),
                        child: const Icon(Icons.drag_indicator, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Material(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Opacity(
              opacity: canAdd ? 1 : 0.45,
              child: InkWell(
                onTap: canAdd ? _addExercise : null,
                borderRadius: BorderRadius.circular(14),
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: AppColors.border,
                    radius: 14,
                  ),
                  child: const SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        '+ Упражнение',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Material(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Отмена',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(label: 'Сохранить', onPressed: _save),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    _syncNamesFromControllers();
    final name = _nameCtrl.text.trim();
    final exercises = _exercises
        .map((e) => e.copyWith(name: e.name.trim()))
        .where((e) => e.name.isNotEmpty)
        .toList();
    if (name.isEmpty) {
      showAppToast(context, 'Укажите название шаблона');
      return;
    }
    if (exercises.isEmpty) {
      showAppToast(context, 'Добавьте хотя бы одно упражнение');
      return;
    }
    final tpl = WorkoutTemplate(
      id: widget.existing?.id ?? AppDatabase.newId('tpl'),
      name: name,
      exercises: exercises,
    );
    await ref.read(appControllerProvider.notifier).saveTemplate(tpl);
    if (!mounted) return;
    showAppToast(context, widget.existing != null ? 'Шаблон обновлён' : 'Шаблон сохранён');
    Navigator.pop(context);
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.fg),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, const [5, 4]);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, List<double> dashArray) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      var index = 0;
      while (distance < metric.length) {
        final len = dashArray[index % dashArray.length];
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
        index++;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
