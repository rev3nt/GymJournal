import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'template_editor_sheet.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider);

    return SafeArea(
      child: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (templates) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: PageTitle('Lift Log')),
                  IconButton(
                    tooltip: 'Удалить все данные',
                    onPressed: () => _clearData(context, ref),
                    icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Начать пустую тренировку',
                onPressed: () => _start(context, ref, null),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Создать шаблон',
                onPressed: () => showTemplateEditor(context, ref),
              ),
              const SectionLabel('Данные'),
              SecondaryButton(
                label: 'Скачать резервную копию',
                onPressed: () => _exportBackup(context, ref),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Импорт из файла',
                onPressed: () => _importBackup(context, ref),
              ),
              const SectionLabel('Шаблоны'),
              if (templates.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Пока нет шаблонов. Создайте первый или начните пустую тренировку.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ...templates.map((tpl) {
                final names =
                    tpl.exercises.map((e) => e.name).where((n) => n.isNotEmpty).toList();
                final sub =
                    '${tpl.exercises.length} упр. · ${tpl.targetSetsSum} подх. · ${names.take(2).join(', ')}${names.length > 2 ? '…' : ''}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TemplateCard(
                    name: tpl.name,
                    subtitle: sub,
                    onPlay: () => _start(context, ref, tpl.id),
                    onLongPress: () => _openActions(context, ref, tpl),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _clearData(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить все данные?',
      message:
          'Будут удалены шаблоны, история и активная тренировка. Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(appControllerProvider.notifier).clearAllData();
    if (context.mounted) showAppToast(context, 'Все данные удалены');
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final json = await ref.read(appControllerProvider.notifier).exportBackupJson();
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'lift_log_backup_$stamp.json';
      final bytes = Uint8List.fromList(utf8.encode(json));

      final useShare = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      if (useShare) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            subject: 'Lift Log — резервная копия',
            text: 'Резервная копия Lift Log',
          ),
        );
        if (!context.mounted) return;
        if (result.status == ShareResultStatus.dismissed) return;
        showAppToast(context, 'Копия готова к сохранению');
        return;
      }

      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Сохранить резервную копию',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (!context.mounted) return;
      if (savedUri == null) return;
      showAppToast(context, 'Резервная копия сохранена');
    } catch (_) {
      if (context.mounted) showAppToast(context, 'Не удалось сохранить копию');
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Импортировать данные?',
      message:
          'Текущие шаблоны, история и активная тренировка будут заменены данными из файла.',
      confirmLabel: 'Импортировать',
      destructive: true,
    );
    if (!ok) return;

    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Выберите резервную копию',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked.isEmpty) return;

      final raw = utf8.decode(await picked.first.readAsBytes());
      await ref.read(appControllerProvider.notifier).importBackupJson(raw);
      if (context.mounted) showAppToast(context, 'Данные импортированы');
    } on FormatException catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    } catch (_) {
      if (context.mounted) showAppToast(context, 'Не удалось импортировать файл');
    }
  }

  Future<void> _start(BuildContext context, WidgetRef ref, String? templateId) async {
    final controller = ref.read(appControllerProvider.notifier);
    try {
      await controller.startWorkout(templateId: templateId);
      if (context.mounted) showAppToast(context, 'Тренировка начата');
    } on StateError catch (e) {
      if (e.message != 'active_exists') rethrow;
      if (!context.mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'Заменить тренировку?',
        message: 'Заменить текущую незавершённую тренировку?',
        confirmLabel: 'Заменить',
        destructive: true,
      );
      if (!ok) return;
      await controller.startWorkout(templateId: templateId, replace: true);
      if (context.mounted) showAppToast(context, 'Тренировка начата');
    }
  }

  Future<void> _openActions(BuildContext context, WidgetRef ref, WorkoutTemplate tpl) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Column(
                          children: [
                            Text(
                              tpl.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Действия с шаблоном',
                              style: TextStyle(color: AppColors.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _ActionBtn(
                        label: 'Начать тренировку',
                        color: AppColors.accent,
                        onTap: () => Navigator.pop(ctx, 'start'),
                      ),
                      _ActionBtn(label: 'Изменить', onTap: () => Navigator.pop(ctx, 'edit')),
                      _ActionBtn(label: 'Копировать', onTap: () => Navigator.pop(ctx, 'copy')),
                      _ActionBtn(
                        label: 'Удалить',
                        color: AppColors.danger,
                        onTap: () => Navigator.pop(ctx, 'delete'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _ActionBtn(
                    label: 'Отмена',
                    minHeight: 56,
                    onTap: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || action == null) return;
    final controller = ref.read(appControllerProvider.notifier);
    switch (action) {
      case 'start':
        await _start(context, ref, tpl.id);
      case 'edit':
        await showTemplateEditor(context, ref, existing: tpl);
      case 'copy':
        await controller.duplicateTemplate(tpl);
        if (context.mounted) showAppToast(context, 'Шаблон скопирован');
      case 'delete':
        await controller.deleteTemplate(tpl.id);
        if (context.mounted) showAppToast(context, '«${tpl.name}» удалён');
    }
  }
}

class _TemplateCard extends StatefulWidget {
  const _TemplateCard({
    required this.name,
    required this.subtitle,
    required this.onPlay,
    required this.onLongPress,
  });

  final String name;
  final String subtitle;
  final VoidCallback onPlay;
  final VoidCallback onLongPress;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _holding = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _holding ? 0.97 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Material(
        color: _holding
            ? Color.lerp(AppColors.surface, Colors.white, 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        child: InkWell(
          onLongPress: () {
            setState(() => _holding = false);
            widget.onLongPress();
          },
          onTapDown: (_) => setState(() => _holding = true),
          onTapUp: (_) => setState(() => _holding = false),
          onTapCancel: () => setState(() => _holding = false),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          letterSpacing: -0.34,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: AppColors.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onPlay,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.accentOn,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.onTap,
    this.color,
    this.minHeight = 52,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: minHeight,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color ?? AppColors.fg,
              fontWeight: FontWeight.w500,
              fontSize: 17,
            ),
          ),
        ),
      ),
    );
  }
}
