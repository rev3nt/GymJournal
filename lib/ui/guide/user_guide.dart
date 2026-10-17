import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

/// Stable demo markers — cleanup only touches these.
const kGuideDemoTemplateId = 'tpl-guide-demo';
const kGuideDemoExerciseId = 'tex-guide-demo';
const kGuideDemoTemplateName = 'Демо · гайд';
const kGuideDemoExerciseName = 'Жим лёжа';

/// Shared GlobalKeys for scenario tour targets.
abstract final class GuideKeys {
  static final demoTemplatePlay = GlobalKey();
  static final logSet = GlobalKey();
  static final addExtra = GlobalKey();
  static final finishWorkout = GlobalKey();
  static final weightField = GlobalKey();
  static final statsTitle = GlobalKey();
}

/// Floating «Пропустить» visibility — listened by [AppShell].
final guideSkipController = GuideSkipController();

class GuideSkipController extends ChangeNotifier {
  bool visible = false;
  VoidCallback? _onSkip;

  void arm(VoidCallback onSkip) {
    _onSkip = onSkip;
    if (!visible) {
      visible = true;
      notifyListeners();
    } else {
      _onSkip = onSkip;
    }
  }

  void disarm() {
    if (!visible && _onSkip == null) return;
    visible = false;
    _onSkip = null;
    notifyListeners();
  }

  void trigger() {
    final handler = _onSkip;
    disarm();
    handler?.call();
  }
}

bool _guideRunning = false;
bool _aborted = false;
BuildContext? _tipSheetContext;

class _GuideAborted implements Exception {
  const _GuideAborted();
}

/// Styled [Showcase] wrapper matching app tokens.
class GuideShowcase extends StatelessWidget {
  const GuideShowcase({
    super.key,
    required this.guideKey,
    required this.title,
    required this.description,
    required this.child,
    this.tooltipPosition,
  });

  final GlobalKey guideKey;
  final String title;
  final String description;
  final Widget child;
  final TooltipPosition? tooltipPosition;

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: guideKey,
      title: title,
      description: description,
      tooltipPosition: tooltipPosition,
      tooltipBackgroundColor: AppColors.surface,
      textColor: AppColors.fg,
      titleTextStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: AppColors.fg,
      ),
      descTextStyle: const TextStyle(
        fontSize: 13,
        height: 1.35,
        color: AppColors.muted,
      ),
      overlayColor: Colors.black,
      overlayOpacity: 0.62,
      targetPadding: const EdgeInsets.all(4),
      targetBorderRadius: BorderRadius.circular(AppColors.radius),
      targetShapeBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      tooltipBorderRadius: BorderRadius.circular(14),
      tooltipPadding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: child,
    );
  }
}

/// Registers [ShowcaseView] once at app shell level. Call [unregister] on dispose.
ShowcaseView registerGuideShowcaseView() {
  return ShowcaseView.register(
    skipIfTargetNotPresent: true,
    enableAutoScroll: true,
    disableBarrierInteraction: false,
    blurValue: 0.5,
    overlayColor: Colors.black,
    overlayOpacity: 0.62,
    globalTooltipActionConfig: const TooltipActionConfig(
      position: TooltipActionPosition.inside,
      alignment: MainAxisAlignment.end,
      actionGap: 10,
      gapBetweenContentAndAction: 12,
    ),
    // Only «Далее» here — Skip is the floating overlay.
    globalTooltipActions: [
      TooltipActionButton(
        type: TooltipDefaultActionType.next,
        name: 'Далее',
        backgroundColor: AppColors.accent,
        textStyle: const TextStyle(
          color: AppColors.accentOn,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        borderRadius: BorderRadius.circular(10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    ],
  );
}

Future<void> maybeShowGuideOnLaunch(BuildContext context, WidgetRef ref) async {
  final seen = await ref.read(appControllerProvider.notifier).isGuideSeen();
  if (seen || !context.mounted) return;
  await startScenarioGuide(context, ref);
}

/// Entry used by first launch and the «?» button.
Future<void> startScenarioGuide(BuildContext context, WidgetRef ref) async {
  if (_guideRunning) return;
  _guideRunning = true;
  _aborted = false;
  final controller = ref.read(appControllerProvider.notifier);

  void onSkip() {
    _aborted = true;
    final tipCtx = _tipSheetContext;
    if (tipCtx != null && tipCtx.mounted) {
      Navigator.of(tipCtx).pop(false);
    }
    try {
      final view = ShowcaseView.get();
      if (view.isShowcaseRunning) view.dismiss();
    } catch (_) {}
  }

  guideSkipController.arm(onSkip);

  try {
    final gateOk = await _gateActiveWorkout(context, ref);
    if (!gateOk || !context.mounted) return;
    _throwIfAborted();

    controller.setTab(0);
    await _waitFrames();
    _throwIfAborted();
    if (!context.mounted) return;

    final intro = await showGuideTip(
      context,
      title: 'Короткий тур',
      body:
          'Покажем главный сценарий: шаблон → тренировка → повторный старт с памятью подходов → статистика. '
          'В конце демо-данные удалятся. Справа сверху можно пропустить.',
    );
    if (!intro || !context.mounted) {
      await _finishAborted(controller);
      return;
    }
    _throwIfAborted();

    final demoTpl = WorkoutTemplate(
      id: kGuideDemoTemplateId,
      name: kGuideDemoTemplateName,
      exercises: const [
        TemplateExercise(
          id: kGuideDemoExerciseId,
          name: kGuideDemoExerciseName,
          targetSets: 3,
          volumeMultiplier: 1,
        ),
      ],
    );
    await controller.saveTemplate(demoTpl);
    await _waitFrames();
    _throwIfAborted();
    if (!context.mounted) return;

    final tplTip = await showGuideTip(
      context,
      title: 'Шаблон',
      body:
          'Шаблон — список упражнений и число подходов. Чип ×2 нужен для одной руки/ноги. '
          'Мы создали «$kGuideDemoTemplateName» с упражнением «$kGuideDemoExerciseName». '
          'Редактировать шаблон можно долгим нажатием на карточку.',
    );
    if (!tplTip || !context.mounted) {
      await _finishAborted(controller, cleanup: true);
      return;
    }
    _throwIfAborted();

    await _waitFrames();
    final playPhase = await _runShowcase([GuideKeys.demoTemplatePlay]);
    if (playPhase == _ShowcaseOutcome.dismissed || _aborted || !context.mounted) {
      await _finishAborted(controller, cleanup: true);
      return;
    }

    await controller.startWorkout(templateId: kGuideDemoTemplateId, replace: true);
    await _waitFrames(3);
    _throwIfAborted();
    if (!context.mounted) return;

    final workoutUi = await _runShowcase([
      GuideKeys.logSet,
      GuideKeys.addExtra,
      GuideKeys.finishWorkout,
    ]);
    if (workoutUi == _ShowcaseOutcome.dismissed || _aborted || !context.mounted) {
      await _finishAborted(controller, cleanup: true);
      return;
    }

    final session1 = await ref.read(activeWorkoutProvider.future);
    if (session1 == null || !context.mounted) {
      await _finishAborted(controller, cleanup: true);
      return;
    }
    controller.setWeight(60);
    controller.setReps(8);
    await controller.logSet(session1);
    await _waitFrames();
    _throwIfAborted();
    if (!context.mounted) return;

    final loggedTip = await showGuideTip(
      context,
      title: 'Подход записан',
      body:
          'Галочка пишет обычный подход. «+ к подходу» добавляет дроп, миорепы или читинг. '
          'Тап по подходу — правка, свайп влево — удаление.',
    );
    if (!loggedTip || !context.mounted) {
      await _finishAborted(controller, cleanup: true);
      return;
    }
    _throwIfAborted();

    final toFinish1 = await ref.read(activeWorkoutProvider.future);
    if (toFinish1 == null || !context.mounted) {
      await _finishAborted(controller, cleanup: true);
      return;
    }
    final firstWorkoutId = toFinish1.id;
    await controller.finishWorkout(toFinish1);
    await _waitFrames();
    _throwIfAborted();
    if (!context.mounted) return;

    final finishedTip = await showGuideTip(
      context,
      title: 'Тренировка сохранена',
      body:
          '«Завершить» переносит сессию в историю. Незавершённая тренировка тоже лежит в базе — '
          'можно закрыть приложение и продолжить позже.',
    );
    if (!finishedTip || !context.mounted) {
      await _finishAborted(controller, cleanup: true, extraWorkoutIds: [firstWorkoutId]);
      return;
    }
    _throwIfAborted();

    await controller.startWorkout(templateId: kGuideDemoTemplateId, replace: true);
    await _waitFrames(3);
    _throwIfAborted();
    if (!context.mounted) return;

    final prefillPhase = await _runShowcase([GuideKeys.weightField]);
    if (prefillPhase == _ShowcaseOutcome.dismissed || _aborted || !context.mounted) {
      await _finishAborted(controller, cleanup: true, extraWorkoutIds: [firstWorkoutId]);
      return;
    }

    final prefillTip = await showGuideTip(
      context,
      title: 'Память подходов',
      body:
          'При повторном старте того же шаблона вес и повторы подставляются из прошлой тренировки — '
          'не нужно вспоминать рабочие веса вручную.',
    );
    if (!prefillTip || !context.mounted) {
      await _finishAborted(controller, cleanup: true, extraWorkoutIds: [firstWorkoutId]);
      return;
    }
    _throwIfAborted();

    final session2 = await ref.read(activeWorkoutProvider.future);
    if (session2 == null || !context.mounted) {
      await _finishAborted(controller, cleanup: true, extraWorkoutIds: [firstWorkoutId]);
      return;
    }
    await controller.logSet(session2);
    final toFinish2 = await ref.read(activeWorkoutProvider.future);
    if (toFinish2 == null || !context.mounted) {
      await _finishAborted(controller, cleanup: true, extraWorkoutIds: [firstWorkoutId]);
      return;
    }
    final secondWorkoutId = toFinish2.id;
    await controller.finishWorkout(toFinish2);
    await _waitFrames();
    _throwIfAborted();
    if (!context.mounted) return;

    controller.setTab(2);
    await _waitFrames();
    final statsPhase = await _runShowcase([GuideKeys.statsTitle]);
    if (statsPhase == _ShowcaseOutcome.dismissed || _aborted || !context.mounted) {
      await _finishAborted(
        controller,
        cleanup: true,
        extraWorkoutIds: [firstWorkoutId, secondWorkoutId],
      );
      return;
    }

    final statsTip = await showGuideTip(
      context,
      title: 'Статистика и бэкап',
      body:
          'Здесь тоннаж и рабочие веса. Резервную копию JSON можно скачать на экране шаблонов. '
          'Сейчас удалим демо-тренировки и шаблон — ваши данные не трогаем.',
      continueLabel: 'Готово',
    );
    if (!context.mounted) {
      await controller.cleanupGuideDemo();
      await controller.markGuideSeen();
      return;
    }
    if (!statsTip || _aborted) {
      await _finishAborted(
        controller,
        cleanup: true,
        extraWorkoutIds: [firstWorkoutId, secondWorkoutId],
      );
      return;
    }

    await controller.cleanupGuideDemo();
    controller.setTab(0);
    await controller.markGuideSeen();
    if (context.mounted) {
      showAppToast(context, 'Демо удалено — «?» повторит тур');
    }
  } on _GuideAborted {
    await _finishAborted(controller, cleanup: true);
  } catch (_) {
    await _finishAborted(controller, cleanup: true);
  } finally {
    guideSkipController.disarm();
    _tipSheetContext = null;
    _guideRunning = false;
  }
}

/// Alias for older call sites.
Future<void> startHybridGuide(BuildContext context, WidgetRef ref) {
  return startScenarioGuide(context, ref);
}

Future<void> showUserGuide(BuildContext context, WidgetRef ref, {bool markSeen = true}) {
  return startScenarioGuide(context, ref);
}

Future<bool> _gateActiveWorkout(BuildContext context, WidgetRef ref) async {
  final active = await ref.read(activeWorkoutProvider.future);
  if (active == null) return true;
  final hasSets = active.exercises.any((e) => e.sets.isNotEmpty);
  if (!hasSets) return true;
  if (!context.mounted) return false;
  // Demo already running — replace quietly for replay.
  if (active.name == kGuideDemoTemplateName) return true;
  return confirmDialog(
    context,
    title: 'Для гайда нужна чистая сессия',
    message:
        'Сейчас есть незавершённая тренировка. Заменить её демо-сценарием? '
        'Иначе откройте гайд позже через «?».',
    confirmLabel: 'Заменить',
    destructive: true,
  );
}

Future<void> _finishAborted(
  AppController controller, {
  bool cleanup = false,
  List<String> extraWorkoutIds = const [],
}) async {
  if (cleanup) {
    await controller.cleanupGuideDemo(extraWorkoutIds: extraWorkoutIds);
  }
  await controller.markGuideSeen();
  controller.setTab(0);
}

void _throwIfAborted() {
  if (_aborted) throw const _GuideAborted();
}

enum _ShowcaseOutcome { finished, dismissed }

Future<_ShowcaseOutcome> _runShowcase(List<GlobalKey> keys) async {
  _throwIfAborted();
  final view = ShowcaseView.get();
  final present = keys.where(view.isTargetRendered).toList();
  if (present.isEmpty) return _ShowcaseOutcome.finished;

  final completer = Completer<_ShowcaseOutcome>();

  void onFinish() {
    if (!completer.isCompleted) completer.complete(_ShowcaseOutcome.finished);
  }

  void onDismiss(GlobalKey? _) {
    if (!completer.isCompleted) {
      completer.complete(
        _aborted ? _ShowcaseOutcome.dismissed : _ShowcaseOutcome.dismissed,
      );
    }
  }

  view.addOnFinishCallback(onFinish);
  view.addOnDismissCallback(onDismiss);
  view.startShowCase(present, delay: const Duration(milliseconds: 100));

  try {
    return await completer.future;
  } finally {
    view.removeOnFinishCallback(onFinish);
    view.removeOnDismissCallback(onDismiss);
  }
}

Future<void> _waitFrames([int count = 2]) async {
  for (var i = 0; i < count; i++) {
    final c = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!c.isCompleted) c.complete();
    });
    await c.future;
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

/// Tip card. Skip is only via floating overlay (returns false).
Future<bool> showGuideTip(
  BuildContext context, {
  required String title,
  required String body,
  String continueLabel = 'Далее',
}) async {
  _throwIfAborted();
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      _tipSheetContext = ctx;
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom * 0.2),
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
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.fg,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: continueLabel,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      );
    },
  );
  _tipSheetContext = null;
  if (_aborted) return false;
  return result ?? false;
}
