import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'challenge_progress.dart';
import 'progress_logic.dart';

const _card = Color(0xFF15161B);
const _border = Color(0xFF343A48);
const _missed = Color(0xFF8B8E98);
const _partial = Color(0xFF6B2A48);
const _futureTile = Color(0xFF101114);
const _futureBar = Color(0xFF1A1C22);
const _pendingTile = Color(0xFF14151A);
const _pendingBar = Color(0xFF3A3E4A);
const _track = Color(0xFF2A2C33);

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.completedDays,
    required this.totalDays,
    required this.progress,
    required this.streak,
    required this.currentDay,
    this.diameter = 240,
  });

  final int completedDays;
  final int totalDays;
  final double progress;
  final int streak;
  final int currentDay;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final fraction = totalDays <= 0 ? 0.0 : progress.clamp(0.0, 1.0);
    final countSize = diameter * 0.16;
    final percent = (fraction * 100).round();
    final dayLabel = currentDay <= 0
        ? 'Starts soon'
        : 'Day $currentDay of $totalDays';

    return Semantics(
      label:
          '$completedDays of $totalDays days completed, $percent percent. '
          '$dayLabel. $streak day streak',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.16),
                  blurRadius: 36,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _RingPainter(progress: value),
                  child: child,
                );
              },
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(diameter * 0.16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$completedDays/$totalDays',
                          style: AppFonts.sansStyle(
                            size: countSize,
                            weight: FontWeight.w800,
                            letterSpacing: -1,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'days completed',
                          style: AppFonts.sansStyle(
                            size: diameter * 0.055,
                            color: AppColors.mutedWhite,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: diameter * 0.1),
          Text(
            '$percent% complete · $dayLabel',
            style: AppFonts.sansStyle(
              size: diameter * 0.058,
              color: AppColors.mutedWhite,
              weight: FontWeight.w500,
            ),
          ),
          SizedBox(height: diameter * 0.05),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.pink,
                size: diameter * 0.085,
              ),
              const SizedBox(width: 6),
              Text(
                '$streak day streak',
                style: AppFonts.sansStyle(
                  size: diameter * 0.068,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.07;
    final radius = (size.shortestSide - stroke) / 2;
    final center = size.center(Offset.zero);
    final arc = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = _track,
    );

    final sweep = progress.clamp(0.0, 1.0) * math.pi * 2;
    if (sweep <= 0) return;

    canvas.drawArc(
      arc,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.pink,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class HabitProgressCard extends StatelessWidget {
  const HabitProgressCard({
    super.key,
    required this.stat,
    required this.days,
    this.scale = 1,
    this.onEdit,
    this.onDelete,
  });

  final HabitStat stat;
  final List<CalendarDayView> days;
  final double scale;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18 * scale,
        12 * scale,
        8 * scale,
        16 * scale,
      ),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 4 * scale),
                  child: Text(
                    stat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sansStyle(
                      size: 17 * scale,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'Habit options',
                  padding: EdgeInsets.zero,
                  color: const Color(0xFF1A1B21),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: _border),
                  ),
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 22 * scale,
                    color: AppColors.mutedWhite,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit?.call();
                    } else if (value == 'delete') {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          'Edit',
                          style: AppFonts.sansStyle(size: 14),
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: AppFonts.sansStyle(
                            size: 14,
                            color: AppColors.pink,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Padding(
            padding: EdgeInsets.only(right: 10 * scale),
            child: _HabitTimeline(habitId: stat.id, days: days, scale: scale),
          ),
        ],
      ),
    );
  }
}

/// Goals are not linked to habits yet, so no progress is shown for them.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.title,
    this.scale = 1,
    this.achieved = false,
    this.onAchievedChanged,
  });

  final String title;
  final double scale;
  final bool achieved;
  final ValueChanged<bool>? onAchievedChanged;

  @override
  Widget build(BuildContext context) {
    final toggle = onAchievedChanged;
    return Semantics(
      button: toggle != null,
      checked: achieved,
      label: title,
      child: GestureDetector(
        onTap: toggle == null ? null : () => toggle(!achieved),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 15 * scale,
          ),
          decoration: BoxDecoration(
            color: _card.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: achieved ? AppColors.pink : _border,
              width: achieved ? 1.5 : 1,
            ),
            boxShadow: [
              if (achieved)
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.22),
                  blurRadius: 16,
                ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: AppColors.pink, size: 20 * scale),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.sansStyle(
                        size: 16 * scale,
                        weight: FontWeight.w700,
                        color: achieved
                            ? AppColors.mutedWhite
                            : AppColors.white,
                      ).copyWith(
                        decoration:
                            achieved ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.pink,
                        decorationThickness: 2,
                      ),
                    ),
                    SizedBox(height: 3 * scale),
                    Text(
                      achieved ? 'Goal achieved!' : 'Not tracked yet',
                      style: AppFonts.sansStyle(
                        size: 12.5 * scale,
                        weight: achieved ? FontWeight.w700 : FontWeight.w400,
                        color:
                            achieved ? AppColors.pink : AppColors.mutedWhite,
                      ),
                    ),
                  ],
                ),
              ),
              if (toggle != null) ...[
                SizedBox(width: 12 * scale),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 26 * scale,
                  height: 26 * scale,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: achieved ? AppColors.pink : Colors.transparent,
                    border: Border.all(
                      color: achieved ? AppColors.pink : AppColors.mutedWhite,
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (achieved)
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                    ],
                  ),
                  child: achieved
                      ? Icon(
                          Icons.check_rounded,
                          color: AppColors.ink,
                          size: 19 * scale,
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitTimeline extends StatelessWidget {
  const _HabitTimeline({
    required this.habitId,
    required this.days,
    required this.scale,
  });

  final String habitId;
  final List<CalendarDayView> days;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final tile = 22.0 * scale;
    final gap = 6.0 * scale;

    return SizedBox(
      height: 40 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: days.length,
        separatorBuilder: (context, index) => SizedBox(width: gap),
        itemBuilder: (context, index) {
          final status = _habitStatusOnDay(days[index], habitId);
          return _HabitDayTile(
            dayNumber: index + 1,
            status: status,
            size: tile,
            scale: scale,
          );
        },
      ),
    );
  }
}

ProgressDayStatus _habitStatusOnDay(CalendarDayView day, String habitId) {
  for (final habit in day.habits) {
    if (habit.id == habitId) return habit.status;
  }
  return day.status == ProgressDayStatus.future
      ? ProgressDayStatus.future
      : ProgressDayStatus.pending;
}

class _HabitDayTile extends StatelessWidget {
  const _HabitDayTile({
    required this.dayNumber,
    required this.status,
    required this.size,
    required this.scale,
  });

  final int dayNumber;
  final ProgressDayStatus status;
  final double size;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final completed = status == ProgressDayStatus.completed;
    final missed = status == ProgressDayStatus.missed;
    final fill = completed
        ? AppColors.pink
        : missed
        ? const Color(0xFF3A3E4A)
        : Colors.transparent;
    final border = completed
        ? null
        : Border.all(
            color: missed ? const Color(0xFF4A4E5A) : const Color(0xFF5A5E6A),
            width: 1,
          );

    return Semantics(
      label:
          'Day $dayNumber, ${dayStatusLabel(status, isToday: false)}',
      child: SizedBox(
        width: size,
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(6 * scale),
                border: border,
              ),
              child: completed
                  ? Icon(
                      Icons.check_rounded,
                      size: 14 * scale,
                      color: AppColors.white,
                    )
                  : missed
                  ? Icon(
                      Icons.close_rounded,
                      size: 12 * scale,
                      color: AppColors.mutedWhite.withValues(alpha: 0.7),
                    )
                  : null,
            ),
            SizedBox(height: 4 * scale),
            Text(
              '$dayNumber',
              style: AppFonts.sansStyle(
                size: 9 * scale,
                weight: FontWeight.w600,
                color: AppColors.mutedWhite,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChallengeCalendar extends StatelessWidget {
  const ChallengeCalendar({
    super.key,
    required this.view,
    required this.onDayTap,
    this.scale = 1,
  });

  final ProgressView view;
  final ValueChanged<CalendarDayView> onDayTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final months = _monthBlocks(view.days);
    if (months.isEmpty) {
      return Center(
        child: Text(
          'No challenge days yet',
          style: AppFonts.sansStyle(size: 15, color: AppColors.mutedWhite),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: 28 * scale),
      children: [
        const _CalendarLegend(),
        SizedBox(height: 18 * scale),
        for (var index = 0; index < months.length; index++) ...[
          if (index > 0) SizedBox(height: 22 * scale),
          _MonthGrid(
            block: months[index],
            today: view.today,
            scale: scale,
            onDayTap: onDayTap,
          ),
        ],
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _LegendItem(color: AppColors.pink, label: 'Completed'),
        _LegendItem(color: _partial, label: 'Partial'),
        _LegendItem(color: _missed, label: 'No activity'),
        _LegendItem(color: _pendingTile, label: 'Today', outlined: true),
        _LegendItem(color: _futureTile, label: 'Upcoming'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: outlined
                ? Border.all(color: AppColors.pink.withValues(alpha: 0.9))
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppFonts.sansStyle(size: 12, color: AppColors.mutedWhite),
        ),
      ],
    );
  }
}

class _MonthBlock {
  const _MonthBlock({
    required this.year,
    required this.month,
    required this.cells,
  });

  final int year;
  final int month;
  final List<CalendarDayView?> cells;
}

List<_MonthBlock> _monthBlocks(List<CalendarDayView> days) {
  if (days.isEmpty) return const [];

  final byDate = <DateTime, CalendarDayView>{
    for (final day in days) dateOnly(day.date): day,
  };
  final start = days.first.date;
  final end = days.last.date;
  final blocks = <_MonthBlock>[];
  var cursor = DateTime(start.year, start.month);
  final last = DateTime(end.year, end.month);

  while (!cursor.isAfter(last)) {
    final first = DateTime(cursor.year, cursor.month);
    final leading = first.weekday - 1;
    final daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
    final cells = List<CalendarDayView?>.filled(leading, null, growable: true);
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(byDate[DateTime(cursor.year, cursor.month, day)]);
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    blocks.add(
      _MonthBlock(year: cursor.year, month: cursor.month, cells: cells),
    );
    cursor = DateTime(cursor.year, cursor.month + 1);
  }

  return blocks;
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.block,
    required this.today,
    required this.scale,
    required this.onDayTap,
  });

  final _MonthBlock block;
  final DateTime today;
  final double scale;
  final ValueChanged<CalendarDayView> onDayTap;

  @override
  Widget build(BuildContext context) {
    final rows = block.cells.length ~/ 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_months[block.month - 1]} ${block.year}',
          style: AppFonts.sansStyle(size: 16 * scale, weight: FontWeight.w700),
        ),
        SizedBox(height: 12 * scale),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: AppFonts.sansStyle(
                      size: 11 * scale,
                      weight: FontWeight.w600,
                      color: AppColors.mutedWhite,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 8 * scale),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: EdgeInsets.only(bottom: 6 * scale),
            child: Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _DayCell(
                      day: block.cells[row * 7 + column],
                      today: today,
                      scale: scale,
                      onTap: onDayTap,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.scale,
    required this.onTap,
  });

  final CalendarDayView? day;
  final DateTime today;
  final double scale;
  final ValueChanged<CalendarDayView> onTap;

  @override
  Widget build(BuildContext context) {
    final entry = day;
    if (entry == null) {
      return SizedBox(height: 42 * scale);
    }

    final isToday = sameDate(entry.date, today);
    final colors = _colorsFor(entry.status, isToday);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3 * scale),
      child: Semantics(
        button: true,
        label:
            '${_weekdays[entry.date.weekday - 1]}, '
            '${_months[entry.date.month - 1]} ${entry.date.day}, '
            '${dayStatusLabel(entry.status, isToday: isToday)}',
        child: Material(
          color: colors.fill,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onTap(entry),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 42 * scale,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: colors.border,
              ),
              child: Text(
                '${entry.date.day}',
                style: AppFonts.sansStyle(
                  size: 13 * scale,
                  weight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayColors {
  const _DayColors({
    required this.fill,
    required this.foreground,
    this.border,
  });

  final Color fill;
  final Color foreground;
  final Border? border;
}

_DayColors _colorsFor(ProgressDayStatus status, bool isToday) {
  switch (status) {
    case ProgressDayStatus.completed:
      return const _DayColors(fill: AppColors.pink, foreground: AppColors.ink);
    case ProgressDayStatus.partial:
      return _DayColors(
        fill: _partial,
        foreground: AppColors.white,
        border: isToday
            ? Border.all(color: AppColors.pink.withValues(alpha: 0.9), width: 1.5)
            : null,
      );
    case ProgressDayStatus.missed:
    case ProgressDayStatus.noActivity:
      return const _DayColors(fill: _missed, foreground: AppColors.white);
    case ProgressDayStatus.pending:
      return _DayColors(
        fill: _pendingTile,
        foreground: AppColors.white,
        border: Border.all(
          color: isToday
              ? AppColors.pink.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.28),
          width: isToday ? 1.5 : 1,
        ),
      );
    case ProgressDayStatus.future:
      return const _DayColors(
        fill: _futureTile,
        foreground: Color(0xFF454955),
      );
  }
}

String dayStatusLabel(ProgressDayStatus status, {required bool isToday}) {
  switch (status) {
    case ProgressDayStatus.completed:
      return 'Completed';
    case ProgressDayStatus.partial:
      return 'Partially completed';
    case ProgressDayStatus.missed:
      return 'Missed';
    case ProgressDayStatus.noActivity:
      return 'No activity';
    case ProgressDayStatus.pending:
      return isToday ? 'In progress' : 'Pending';
    case ProgressDayStatus.future:
      return 'Upcoming';
  }
}

String longDateLabel(DateTime date) {
  final day = dateOnly(date);
  return '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}';
}
