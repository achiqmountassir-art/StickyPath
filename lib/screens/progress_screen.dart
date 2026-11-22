import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress/challenge_progress.dart';
import '../progress/challenge_store.dart';
import '../progress/custom_task.dart';
import '../progress/progress_logic.dart';
import '../progress/progress_widgets.dart';
import '../theme/app_colors.dart';
import 'Home_screen.dart' show challengeDayLabel;
import 'task_form_sheet.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    this.store,
    this.today,
    this.showBackButton = true,
  });

  /// Defaults to [ChallengeStore.instance], the same store Home writes to.
  final ChallengeStore? store;

  /// Overrides the current date, for tests.
  final DateTime? today;
  final bool showBackButton;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const _tabs = ['Overview', 'Goals', 'Calendar'];

  int _tab = 0;

  ChallengeStore get _store => widget.store ?? ChallengeStore.instance;

  void _selectTab(int index) {
    if (index == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = index);
  }

  Future<void> _editHabit(HabitStat habit) async {
    final challenge = _store.active;
    if (challenge == null) return;
    final habitIndex = int.tryParse(habit.id.replaceFirst('goal-', ''));
    if (habitIndex == null ||
        habitIndex < 0 ||
        habitIndex >= challenge.habits.length) {
      return;
    }

    final controller = TextEditingController(text: challenge.habits[habitIndex]);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15161B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final inset = MediaQuery.viewInsetsOf(context).bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 18, 24, 20 + inset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit habit',
                  style: AppFonts.sansStyle(size: 18, weight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  style: AppFonts.sansStyle(size: 16, weight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Habit name',
                    hintStyle: AppFonts.sansStyle(
                      size: 16,
                      color: AppColors.mutedWhite,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1A1B21),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF343A48)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF343A48)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.pink.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => Navigator.pop(context, true),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pink,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: AppFonts.sansStyle(
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    final name = controller.text;
    controller.dispose();
    if (saved != true) return;
    await _store.renameHabit(habitIndex, name);
  }

  Future<void> _confirmDeleteHabit(HabitStat habit) async {
    final byId = int.tryParse(habit.id.replaceFirst('goal-', ''));
    if (byId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15161B),
        title: Text(
          'Delete habit?',
          style: AppFonts.sansStyle(size: 18, weight: FontWeight.w700),
        ),
        content: Text(
          '“${habit.name}” will be removed. Its check history for this '
          'challenge is deleted. Other habits and custom tasks stay as they are.',
          style: AppFonts.sansStyle(size: 14, color: AppColors.mutedWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppFonts.sansStyle(size: 14, color: AppColors.mutedWhite),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppFonts.sansStyle(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.pink,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.deleteHabit(byId);
  }

  void _openDay(ProgressView view, CalendarDayView day) {
    HapticFeedback.selectionClick();
    final challenge = _store.active;
    if (challenge == null) return;
    final dayNumber = challenge.dayNumberForDate(day.date);
    final isToday = sameDate(day.date, view.today);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15161B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final active = _store.active;
            final tasks = active == null || dayNumber == null
                ? const <CustomTask>[]
                : active.customTasksForDay(dayNumber);
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      longDateLabel(day.date),
                      style: AppFonts.sansStyle(
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayStatusLabel(day.status, isToday: isToday),
                      style: AppFonts.sansStyle(
                        size: 14,
                        weight: FontWeight.w600,
                        color: _statusColor(day.status),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (day.habits.isEmpty)
                      Text(
                        'No habits for this day',
                        style: AppFonts.sansStyle(
                          size: 14,
                          color: AppColors.mutedWhite,
                        ),
                      )
                    else
                      for (final habit in day.habits) ...[
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    habit.status == ProgressDayStatus.completed
                                    ? habit.accent
                                    : _statusColor(habit.status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                habit.name,
                                style: AppFonts.sansStyle(
                                  size: 15,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              dayStatusLabel(habit.status, isToday: isToday),
                              style: AppFonts.sansStyle(
                                size: 13,
                                color: AppColors.mutedWhite,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    if (dayNumber != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Custom tasks',
                              style: AppFonts.sansStyle(
                                size: 13,
                                weight: FontWeight.w700,
                                color: AppColors.mutedWhite,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await showTaskFormSheet(
                                context: context,
                                store: _store,
                                initialDayNumber: dayNumber,
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              'Add',
                              style: AppFonts.sansStyle(
                                size: 13,
                                weight: FontWeight.w700,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.pink,
                            ),
                          ),
                        ],
                      ),
                      if (tasks.isEmpty)
                        Text(
                          'No tasks planned',
                          style: AppFonts.sansStyle(
                            size: 14,
                            color: AppColors.mutedWhite,
                          ),
                        )
                      else
                        for (final task in tasks) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              task.completed
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked,
                              color: task.completed
                                  ? AppColors.pink
                                  : AppColors.mutedWhite,
                              size: 22,
                            ),
                            title: Text(
                              task.title,
                              style: AppFonts.sansStyle(
                                size: 15,
                                weight: FontWeight.w600,
                              ),
                            ),
                            subtitle: task.reminderMinutes == null
                                ? Text(
                                    'Day ${challengeDayLabel(task.dayNumber, active!.totalDays)}',
                                    style: AppFonts.sansStyle(
                                      size: 12,
                                      color: AppColors.mutedWhite,
                                    ),
                                  )
                                : Text(
                                    '${formatReminderMinutes(task.reminderMinutes!)} · Day ${challengeDayLabel(task.dayNumber, active!.totalDays)}',
                                    style: AppFonts.sansStyle(
                                      size: 12,
                                      color: AppColors.mutedWhite,
                                    ),
                                  ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.mutedWhite,
                            ),
                            onTap: () async {
                              await showTaskFormSheet(
                                context: context,
                                store: _store,
                                existing: task,
                              );
                            },
                          ),
                        ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final challenge = _store.active;
        final view = challenge == null
            ? null
            : evaluateProgress(
                challenge.progress(widget.today ?? _store.now()),
              );
        return _buildScreen(view);
      },
    );
  }

  Widget _buildScreen(ProgressView? view) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.ink,
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/image4.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.34)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 390).clamp(0.88, 1.12);
                  final available = (constraints.maxWidth - 48).clamp(0.0, 2000.0);
                  final ring = available * 0.78 > 250 ? 250.0 : available * 0.78;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4 * scale),
                        if (widget.showBackButton)
                          IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_ios_new),
                            color: AppColors.white,
                            iconSize: 22 * scale,
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            tooltip: 'Back',
                          )
                        else
                          SizedBox(height: 16 * scale),
                        SizedBox(height: 8 * scale),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Progress',
                                style: AppFonts.sansStyle(
                                  size: 32 * scale,
                                  weight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                            if (view != null)
                              _AddTaskButton(
                                scale: scale,
                                onPressed: () => showTaskFormSheet(
                                  context: context,
                                  store: _store,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 16 * scale),
                        _ProgressTabs(
                          tabs: _tabs,
                          index: _tab,
                          scale: scale,
                          onChanged: _selectTab,
                        ),
                        SizedBox(height: 18 * scale),
                        Expanded(child: _body(view, ring, scale)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(ProgressView? view, double ring, double scale) {
    if (view == null) {
      return Center(
        child: Text(
          'No active challenge yet',
          style: AppFonts.sansStyle(size: 15, color: AppColors.mutedWhite),
        ),
      );
    }
    switch (_tab) {
      case 1:
        final challenge = _store.active!;
        return _GoalsTab(
          view: view,
          scale: scale,
          achieved: challenge.achievedGoals,
          customTasks: challenge.customTasks,
          totalDays: challenge.totalDays,
          onToggle: (goal, value) =>
              _store.setGoalAchieved(challenge.id, goal, value),
          onEditTask: (task) => showTaskFormSheet(
            context: context,
            store: _store,
            existing: task,
          ),
          onEditHabit: (habit) => _editHabit(habit),
          onDeleteHabit: (habit) => _confirmDeleteHabit(habit),
        );
      case 2:
        return ChallengeCalendar(
          view: view,
          scale: scale,
          onDayTap: (day) => _openDay(view, day),
        );
      default:
        return _OverviewTab(view: view, diameter: ring);
    }
  }
}

class _ProgressTabs extends StatelessWidget {
  const _ProgressTabs({
    required this.tabs,
    required this.index,
    required this.scale,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final double scale;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46 * scale,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF15161B).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF343A48)),
      ),
      child: Row(
        children: [
          for (var tab = 0; tab < tabs.length; tab++)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab == index,
                label: tabs[tab],
                child: GestureDetector(
                  onTap: () => onChanged(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tab == index
                          ? AppColors.pink.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tab == index
                            ? AppColors.pink.withValues(alpha: 0.85)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      tabs[tab],
                      style: AppFonts.sansStyle(
                        size: 14 * scale,
                        weight: tab == index ? FontWeight.w700 : FontWeight.w500,
                        color: tab == index
                            ? AppColors.white
                            : AppColors.mutedWhite,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.view, required this.diameter});

  final ProgressView view;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ProgressRing(
                completedDays: view.completedDays,
                totalDays: view.totalDays,
                progress: view.progress,
                streak: view.streak,
                currentDay: view.currentDay,
                diameter: diameter,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GoalsTab extends StatelessWidget {
  const _GoalsTab({
    required this.view,
    required this.scale,
    required this.achieved,
    required this.customTasks,
    required this.totalDays,
    required this.onToggle,
    required this.onEditTask,
    required this.onEditHabit,
    required this.onDeleteHabit,
  });

  final ProgressView view;
  final double scale;
  final Set<String> achieved;
  final List<CustomTask> customTasks;
  final int totalDays;
  final void Function(String goal, bool achieved) onToggle;
  final void Function(CustomTask task) onEditTask;
  final void Function(HabitStat habit) onEditHabit;
  final void Function(HabitStat habit) onDeleteHabit;

  @override
  Widget build(BuildContext context) {
    if (view.habits.isEmpty && view.goals.isEmpty && customTasks.isEmpty) {
      return Center(
        child: Text(
          'No goals or habits yet',
          style: AppFonts.sansStyle(size: 15, color: AppColors.mutedWhite),
        ),
      );
    }

    final inProgress = [
      for (final goal in view.goals)
        if (!achieved.contains(goal)) goal,
    ];
    final completed = [
      for (final goal in view.goals)
        if (achieved.contains(goal)) goal,
    ];
    final openTasks = [
      for (final task in customTasks)
        if (!task.completed) task,
    ];
    final doneTasks = [
      for (final task in customTasks)
        if (task.completed) task,
    ];

    return ListView(
      padding: EdgeInsets.only(bottom: 24 * scale),
      children: [
        if (customTasks.isNotEmpty) ...[
          for (final task in [...openTasks, ...doneTasks]) ...[
            _CustomTaskCard(
              task: task,
              totalDays: totalDays,
              scale: scale,
              onTap: () => onEditTask(task),
            ),
            SizedBox(height: 10 * scale),
          ],
          SizedBox(height: 14 * scale),
        ],
        if (inProgress.isNotEmpty) ...[
          _SectionLabel(text: 'In progress', scale: scale),
          for (final goal in inProgress) ...[
            GoalCard(
              title: goal,
              scale: scale,
              onAchievedChanged: (value) => onToggle(goal, value),
            ),
            SizedBox(height: 10 * scale),
          ],
          SizedBox(height: 14 * scale),
        ],
        if (completed.isNotEmpty) ...[
          _SectionLabel(text: 'Completed', scale: scale),
          for (final goal in completed) ...[
            GoalCard(
              title: goal,
              scale: scale,
              achieved: true,
              onAchievedChanged: (value) => onToggle(goal, value),
            ),
            SizedBox(height: 10 * scale),
          ],
          SizedBox(height: 14 * scale),
        ],
        if (view.habits.isNotEmpty) ...[
          _SectionLabel(text: 'Daily habits', scale: scale),
          for (final habit in view.habits) ...[
            HabitProgressCard(
              stat: habit,
              days: view.days,
              scale: scale,
              onEdit: () => onEditHabit(habit),
              onDelete: () => onDeleteHabit(habit),
            ),
            SizedBox(height: 12 * scale),
          ],
        ],
      ],
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton({required this.scale, required this.onPressed});

  final double scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      tooltip: 'Add task',
      icon: Icon(Icons.add_rounded, size: 26 * scale, color: AppColors.pink),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.pink.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.pink.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}

class _CustomTaskCard extends StatelessWidget {
  const _CustomTaskCard({
    required this.task,
    required this.totalDays,
    required this.scale,
    required this.onTap,
  });

  final CustomTask task;
  final int totalDays;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15161B).withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 12 * scale,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF343A48)),
          ),
          child: Row(
            children: [
              Icon(
                task.completed
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: task.completed ? AppColors.pink : AppColors.mutedWhite,
                size: 20 * scale,
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AppFonts.sansStyle(
                        size: 15 * scale,
                        weight: FontWeight.w600,
                        color: task.completed
                            ? AppColors.mutedWhite
                            : AppColors.white,
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    Text(
                      [
                        'Day ${challengeDayLabel(task.dayNumber, totalDays)}',
                        if (task.reminderMinutes != null)
                          formatReminderMinutes(task.reminderMinutes!),
                      ].join(' · '),
                      style: AppFonts.sansStyle(
                        size: 12 * scale,
                        color: AppColors.mutedWhite,
                      ),
                    ),
                  ],
                ),
              ),
              if (task.hasReminder)
                Icon(
                  Icons.notifications_none_rounded,
                  size: 18 * scale,
                  color: AppColors.pink.withValues(alpha: 0.85),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10 * scale),
      child: Text(
        text.toUpperCase(),
        style: AppFonts.sansStyle(
          size: 12 * scale,
          weight: FontWeight.w700,
          color: AppColors.mutedWhite,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

Color _statusColor(ProgressDayStatus status) {
  switch (status) {
    case ProgressDayStatus.completed:
      return AppColors.pink;
    case ProgressDayStatus.partial:
      return const Color(0xFFFF7FB5);
    case ProgressDayStatus.missed:
    case ProgressDayStatus.noActivity:
      return const Color(0xFF8B8E98);
    case ProgressDayStatus.pending:
      return AppColors.softWhite;
    case ProgressDayStatus.future:
      return AppColors.mutedWhite;
  }
}
