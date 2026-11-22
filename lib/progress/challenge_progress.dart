import 'package:flutter/material.dart';

/// Date with the time cleared so challenge days compare by calendar date.
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// Adds calendar days, not 24-hour chunks, so daylight saving cannot
/// duplicate or skip a challenge date.
DateTime addCalendarDays(DateTime value, int days) {
  final day = dateOnly(value);
  return DateTime(day.year, day.month, day.day + days);
}

bool sameDate(DateTime a, DateTime b) {
  final left = dateOnly(a);
  final right = dateOnly(b);
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

enum HabitMark { completed, missed, pending }

/// One daily habit and the marks recorded for it.
///
/// Days before [createdOn] are ignored. Missing marks are not treated as
/// missed; the calculator decides pending, future, or completed from the date.
class ProgressHabit {
  ProgressHabit({
    required this.id,
    required this.name,
    required this.accent,
    required DateTime createdOn,
    Map<DateTime, HabitMark> marks = const {},
  }) : createdOn = dateOnly(createdOn),
       marks = {
         for (final entry in marks.entries) dateOnly(entry.key): entry.value,
       };

  final String id;
  final String name;
  final Color accent;
  final DateTime createdOn;
  final Map<DateTime, HabitMark> marks;
}

/// Inputs for the progress screen.
class ChallengeProgress {
  ChallengeProgress({
    required DateTime startDate,
    required this.totalDays,
    required DateTime today,
    required this.habits,
    this.goals = const [],
    Map<DateTime, HabitMark> dayResults = const {},
  }) : startDate = dateOnly(startDate),
       today = dateOnly(today),
       dayResults = {
         for (final entry in dayResults.entries)
           dateOnly(entry.key): entry.value,
       };

  /// Results saved when a day's sticky note was swiped away. They decide the
  /// whole day: completed (right) or missed (left), whatever was checked.
  final Map<DateTime, HabitMark> dayResults;

  final DateTime startDate;
  final int totalDays;
  final DateTime today;
  final List<ProgressHabit> habits;

  /// Goals from onboarding. They are not linked to habits yet, so they carry
  /// no progress of their own.
  final List<String> goals;

  DateTime dateForIndex(int index) => addCalendarDays(startDate, index);
}
