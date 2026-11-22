import 'package:flutter/material.dart';

import 'challenge_progress.dart';

/// Habits use completed, missed, pending, and future. Days use completed,
/// partial, noActivity, pending, and future.
enum ProgressDayStatus { completed, partial, missed, noActivity, pending, future }

class HabitStat {
  const HabitStat({
    required this.id,
    required this.name,
    required this.accent,
    required this.completed,
    required this.missed,
    required this.pending,
    required this.future,
  });

  final String id;
  final String name;
  final Color accent;
  final int completed;
  final int missed;
  final int pending;
  final int future;
}

class HabitDayView {
  const HabitDayView({
    required this.id,
    required this.name,
    required this.accent,
    required this.status,
  });

  final String id;
  final String name;
  final Color accent;
  final ProgressDayStatus status;
}

class CalendarDayView {
  const CalendarDayView({
    required this.date,
    required this.status,
    required this.habits,
  });

  final DateTime date;
  final ProgressDayStatus status;
  final List<HabitDayView> habits;
}

class ProgressView {
  const ProgressView({
    required this.today,
    required this.completedDays,
    required this.totalDays,
    required this.currentDay,
    required this.progress,
    required this.streak,
    required this.goals,
    required this.habits,
    required this.days,
  });

  final DateTime today;
  final int completedDays;
  final int totalDays;

  /// 1-based challenge day for [today]; 0 before the start date.
  final int currentDay;
  final double progress;
  final int streak;
  final List<String> goals;
  final List<HabitStat> habits;
  final List<CalendarDayView> days;

  int get percent => (progress * 100).round();
}

/// Turns a challenge snapshot into overview, habit, and calendar numbers.
///
/// A day is completed only when every habit for that day is completed, and
/// partial when only some are. Today stays pending until every habit is done,
/// so an unfinished today does not break the streak. Future days are never
/// completed or missed. Each date is evaluated once.
ProgressView evaluateProgress(ChallengeProgress input) {
  final today = input.today;
  final totalDays = input.totalDays;
  if (totalDays <= 0) {
    return ProgressView(
      today: today,
      completedDays: 0,
      totalDays: 0,
      currentDay: 0,
      progress: 0,
      streak: 0,
      goals: input.goals,
      habits: [
        for (final habit in input.habits)
          HabitStat(
            id: habit.id,
            name: habit.name,
            accent: habit.accent,
            completed: 0,
            missed: 0,
            pending: 0,
            future: 0,
          ),
      ],
      days: const [],
    );
  }

  final counts = <String, Map<ProgressDayStatus, int>>{
    for (final habit in input.habits) habit.id: {},
  };

  final days = <CalendarDayView>[];
  var completedDays = 0;

  for (var index = 0; index < totalDays; index++) {
    final date = input.dateForIndex(index);
    final habitViews = <HabitDayView>[];
    final result = input.dayResults[dateOnly(date)];
    for (final habit in input.habits) {
      final status = _habitStatus(habit, date, today, closed: result != null);
      if (status == null) continue;
      habitViews.add(
        HabitDayView(
          id: habit.id,
          name: habit.name,
          accent: habit.accent,
          status: status,
        ),
      );
      final habitCounts = counts[habit.id]!;
      habitCounts[status] = (habitCounts[status] ?? 0) + 1;
    }

    final status = _dayStatus(date, today, habitViews, result);
    if (status == ProgressDayStatus.completed) completedDays++;
    days.add(CalendarDayView(date: date, status: status, habits: habitViews));
  }

  return ProgressView(
    today: today,
    completedDays: completedDays,
    totalDays: totalDays,
    currentDay: _currentDay(input.startDate, today, totalDays),
    progress: (completedDays / totalDays).clamp(0.0, 1.0),
    streak: _streak(days, today),
    goals: input.goals,
    habits: [
      for (final habit in input.habits)
        HabitStat(
          id: habit.id,
          name: habit.name,
          accent: habit.accent,
          completed: counts[habit.id]![ProgressDayStatus.completed] ?? 0,
          missed: counts[habit.id]![ProgressDayStatus.missed] ?? 0,
          pending: counts[habit.id]![ProgressDayStatus.pending] ?? 0,
          future: counts[habit.id]![ProgressDayStatus.future] ?? 0,
        ),
    ],
    days: days,
  );
}

int _currentDay(DateTime start, DateTime today, int totalDays) {
  final elapsed = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(start.year, start.month, start.day))
      .inDays;
  if (elapsed < 0) return 0;
  return elapsed + 1 > totalDays ? totalDays : elapsed + 1;
}

/// Null when this habit did not exist yet.
ProgressDayStatus? _habitStatus(
  ProgressHabit habit,
  DateTime date,
  DateTime today, {
  required bool closed,
}) {
  final day = dateOnly(date);
  if (day.isBefore(habit.createdOn)) return null;
  if (day.isAfter(today) && !closed) return ProgressDayStatus.future;

  switch (habit.marks[day]) {
    case HabitMark.completed:
      return ProgressDayStatus.completed;
    case HabitMark.missed:
      return ProgressDayStatus.missed;
    case HabitMark.pending:
    case null:
      return ProgressDayStatus.pending;
  }
}

ProgressDayStatus _dayStatus(
  DateTime date,
  DateTime today,
  List<HabitDayView> habits,
  HabitMark? result,
) {
  // A swipe decides the day as soon as it happens: right is completed,
  // left is missed.
  if (result == HabitMark.missed) return ProgressDayStatus.missed;
  if (result == HabitMark.completed) return ProgressDayStatus.completed;
  if (dateOnly(date).isAfter(today)) return ProgressDayStatus.future;

  final done = habits
      .where((habit) => habit.status == ProgressDayStatus.completed)
      .length;
  final allDone = habits.isNotEmpty && done == habits.length;

  if (allDone) return ProgressDayStatus.completed;
  if (done > 0) return ProgressDayStatus.partial;
  if (sameDate(date, today)) return ProgressDayStatus.pending;
  return ProgressDayStatus.noActivity;
}

int _streak(List<CalendarDayView> days, DateTime today) {
  var index = days.length - 1;
  while (index >= 0 && days[index].status == ProgressDayStatus.future) {
    index--;
  }
  if (index < 0) return 0;

  // An open today does not break the streak; a missed today does.
  final todayStatus = days[index].status;
  if (sameDate(days[index].date, today) &&
      (todayStatus == ProgressDayStatus.pending ||
          todayStatus == ProgressDayStatus.partial)) {
    index--;
  }

  var streak = 0;
  while (index >= 0 && days[index].status == ProgressDayStatus.completed) {
    streak++;
    index--;
  }
  return streak;
}
