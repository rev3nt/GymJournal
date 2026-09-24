import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'stats/stats_screen.dart';
import 'templates/templates_screen.dart';
import 'workout/workout_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(appControllerProvider);
    final tab = ui.tabIndex;
    final viewingPast = ui.viewingPastId != null;
    // Nested UI states (past workout, non-home tabs) must intercept system back
    // so Android back / predictive swipe don't exit the app.
    final canPop = !viewingPast && tab == 0;

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
      child: Scaffold(
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
