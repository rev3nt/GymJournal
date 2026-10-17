import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'guide/user_guide.dart';
import 'stats/stats_screen.dart';
import 'templates/templates_screen.dart';
import 'widgets/common.dart';
import 'workout/workout_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  bool _bootstrapped = false;
  late final ShowcaseView _showcaseView;

  @override
  void initState() {
    super.initState();
    _showcaseView = registerGuideShowcaseView();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _showcaseView.unregister();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;
    final controller = ref.read(appControllerProvider.notifier);
    await controller.restoreUiDraft();
    if (!mounted) return;

    final active = await ref.read(activeWorkoutProvider.future);
    if (!mounted) return;

    if (active != null && !ref.read(appControllerProvider).resumeBannerShown) {
      controller.setTab(1);
      controller.markResumeBannerShown();
      showAppToast(context, 'Есть незавершённая тренировка');
    }

    await maybeShowGuideOnLaunch(context, ref);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      ref.read(appControllerProvider.notifier).persistUiDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(appControllerProvider);
    final tab = ui.tabIndex;
    final viewingPast = ui.viewingPastId != null;
    final canPop = !viewingPast && tab == 0;
    final topInset = MediaQuery.paddingOf(context).top;

    return ListenableBuilder(
      listenable: guideSkipController,
      builder: (context, _) {
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final controller = ref.read(appControllerProvider.notifier);
            if (ref.read(appControllerProvider).viewingPastId != null) {
              controller.closePastWorkout();
              return;
            }
            if (ref.read(appControllerProvider).tabIndex != 0) {
              controller.setTab(0);
            }
          },
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: AppColors.bg,
                body: IndexedStack(
                  index: tab,
                  children: const [
                    TemplatesScreen(),
                    WorkoutScreen(),
                    StatsScreen(),
                  ],
                ),
                bottomNavigationBar: _ProtoTabBar(
                  index: tab,
                  onChanged: (i) => ref.read(appControllerProvider.notifier).setTab(i),
                ),
              ),
              if (guideSkipController.visible)
                Positioned(
                  top: topInset + 6,
                  right: 10,
                  child: Material(
                    color: AppColors.surface.withValues(alpha: 0.96),
                    elevation: 2,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: guideSkipController.trigger,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'Пропустить',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProtoTabBar extends StatelessWidget {
  const _ProtoTabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.list_alt_outlined, 'Шаблоны'),
    (Icons.fitness_center_outlined, 'Тренировка'),
    (Icons.bar_chart_outlined, 'Статистика'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.92),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 8, top: 6),
      child: Row(
        children: List.generate(_items.length, (i) {
          final on = i == index;
          final color = on ? AppColors.accent : AppColors.muted;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_items[i].$1, size: 22, color: color),
                    const SizedBox(height: 4),
                    Text(
                      _items[i].$2,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                        color: color,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
