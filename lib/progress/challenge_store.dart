import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/Home_screen.dart'
    show ChallengeRepository, DailyResult, DailyTask;
import '../theme/app_colors.dart';
import 'challenge_progress.dart';
import 'custom_task.dart';
import 'progress_logic.dart';
import 'task_notifications.dart';

/// The challenge the user is currently running, as tracked on Home.
///
/// Home numbers days from [totalDays] down to 1, so day [totalDays] falls on
/// [startDate] and day 1 is the last date of the challenge.
class ActiveChallenge {
  ActiveChallenge({
    required this.id,
    required DateTime startDate,
    required this.totalDays,
    required this.goals,
    required this.habits,
    Map<int, Map<String, bool>>? taskStates,
    Map<int, DailyResult>? results,
    Set<String>? achievedGoals,
    List<CustomTask>? customTasks,
    this.celebratedAt,
  }) : startDate = dateOnly(startDate),
       taskStates = taskStates ?? {},
       results = results ?? {},
       achievedGoals = achievedGoals ?? {},
       customTasks = customTasks ?? [];

  final String id;

  /// When the completion ceremony was shown. Set once per challenge.
  DateTime? celebratedAt;
  final DateTime startDate;
  final int totalDays;
  final List<String> goals;
  final List<String> habits;
  final Map<int, Map<String, bool>> taskStates;
  final Map<int, DailyResult> results;

  /// Goals the user crossed out as achieved.
  final Set<String> achievedGoals;

  /// One-off tasks scheduled onto challenge days (not habits).
  final List<CustomTask> customTasks;

  /// Matches the task ids Home generates for its habits.
  static String habitId(int index) => 'goal-$index';

  DateTime dateForDay(int dayNumber) =>
      addCalendarDays(startDate, totalDays - dayNumber);

  /// When true, every challenge day can be swiped for easier local testing.
  /// Enabled from [main] while testing; leave false in unit tests.
  static bool unlockSwipeForTesting = false;

  /// A note can be swiped once its calendar date has arrived.
  bool isDayAvailable(int dayNumber, DateTime today) {
    if (dayNumber < 1 || dayNumber > totalDays) return false;
    if (unlockSwipeForTesting) return true;
    return !dateForDay(dayNumber).isAfter(dateOnly(today));
  }

  /// Home's next unswiped day, or 1 once the whole challenge was swiped.
  int get homeCurrentDay {
    if (results.isEmpty) return totalDays;
    final lowest = results.keys.reduce((a, b) => a < b ? a : b);
    return (lowest - 1).clamp(1, totalDays);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'startDate': startDate.toIso8601String(),
    'totalDays': totalDays,
    'goals': goals,
    'habits': habits,
    'tasks': {
      for (final day in taskStates.entries) '${day.key}': day.value,
    },
    'results': {
      for (final result in results.entries) '${result.key}': result.value.name,
    },
    'celebratedAt': celebratedAt?.toIso8601String(),
    'achievedGoals': achievedGoals.toList(),
    'customTasks': [for (final task in customTasks) task.toJson()],
  };

  static ActiveChallenge fromJson(Map<String, dynamic> json) {
    final tasks = (json['tasks'] as Map<String, dynamic>? ?? const {});
    final results = (json['results'] as Map<String, dynamic>? ?? const {});
    final custom = json['customTasks'] as List? ?? const [];
    return ActiveChallenge(
      id: json['id'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      totalDays: json['totalDays'] as int,
      goals: List<String>.from(json['goals'] as List? ?? const []),
      habits: List<String>.from(json['habits'] as List? ?? const []),
      taskStates: {
        for (final day in tasks.entries)
          int.parse(day.key): Map<String, bool>.from(day.value as Map),
      },
      results: {
        for (final result in results.entries)
          int.parse(result.key): DailyResult.values.byName(
            result.value as String,
          ),
      },
      celebratedAt: DateTime.tryParse(json['celebratedAt'] as String? ?? ''),
      achievedGoals: Set<String>.from(
        json['achievedGoals'] as List? ?? const [],
      ),
      customTasks: [
        for (final entry in custom)
          if (entry is Map<String, dynamic>) CustomTask.fromJson(entry),
      ],
    );
  }

  /// Custom tasks scheduled for a Home [dayNumber].
  List<CustomTask> customTasksForDay(int dayNumber) => [
    for (final task in customTasks)
      if (task.dayNumber == dayNumber) task,
  ];

  /// Home countdown day for a calendar [date], or null if outside the challenge.
  int? dayNumberForDate(DateTime date) {
    final target = dateOnly(date);
    final offset = target.difference(startDate).inDays;
    if (offset < 0 || offset >= totalDays) return null;
    return totalDays - offset;
  }

  /// Snapshot for the Progress screen.
  ///
  /// A checked habit is completed. An unchecked habit is missed once its date
  /// has passed or Home closed that day; until then it stays pending. A note
  /// swiped on Home counts right away, even if its date is still ahead.
  ChallengeProgress progress(DateTime today) {
    final current = dateOnly(today);
    return ChallengeProgress(
      startDate: startDate,
      totalDays: totalDays,
      today: current,
      goals: goals,
      dayResults: {
        for (final result in results.entries)
          if (result.key >= 1 && result.key <= totalDays)
            dateForDay(result.key): result.value == DailyResult.completed
                ? HabitMark.completed
                : HabitMark.missed,
      },
      habits: [
        for (var i = 0; i < habits.length; i++)
          ProgressHabit(
            id: habitId(i),
            name: habits[i],
            accent: AppColors.pink,
            createdOn: startDate,
            marks: _marksFor(habitId(i), current),
          ),
      ],
    );
  }

  Map<DateTime, HabitMark> _marksFor(String habit, DateTime today) {
    final marks = <DateTime, HabitMark>{};
    for (var index = 0; index < totalDays; index++) {
      final date = addCalendarDays(startDate, index);
      final dayNumber = totalDays - index;
      final closed = results.containsKey(dayNumber);
      if (date.isAfter(today) && !closed) continue;
      final checked = taskStates[dayNumber]?[habit] ?? false;
      if (checked) {
        marks[date] = HabitMark.completed;
      } else if (date.isBefore(today) || closed) {
        marks[date] = HabitMark.missed;
      }
    }
    return marks;
  }
}

/// Single source of truth shared by Home and Progress, saved on device.
class ChallengeStore extends ChangeNotifier {
  ChallengeStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static final ChallengeStore instance = ChallengeStore();
  static const _storageKey = 'sticky_path.active_challenge';
  static const _historyKey = 'sticky_path.challenge_history';

  final DateTime Function() _clock;

  DateTime now() => _clock();

  ActiveChallenge? _active;
  ActiveChallenge? get active => _active;

  final List<ActiveChallenge> _history = [];

  /// Earlier challenges, oldest first, kept when a new one starts.
  List<ActiveChallenge> get history => List.unmodifiable(_history);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      _active = raw == null
          ? null
          : ActiveChallenge.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      debugPrint('Sticky Path could not restore the challenge: $error');
      _active = null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      _history
        ..clear()
        ..addAll([
          if (raw != null)
            for (final entry in jsonDecode(raw) as List)
              ActiveChallenge.fromJson(entry as Map<String, dynamic>),
        ]);
    } catch (error) {
      debugPrint('Sticky Path could not restore challenge history: $error');
    }
    notifyListeners();
    await closePastDays();
    final active = _active;
    if (active != null) {
      await TaskNotificationService.instance.rescheduleAll(
        tasks: active.customTasks,
        dateForDay: active.dateForDay,
        challengeId: active.id,
      );
    }
  }

  /// A note whose date has passed without a swipe counts as swiped left.
  /// Today's note stays open until midnight.
  Future<void> closePastDays() async {
    final challenge = _active;
    if (challenge == null) return;
    final today = dateOnly(now());
    var changed = false;
    for (var day = challenge.totalDays; day >= 1; day--) {
      if (!challenge.dateForDay(day).isBefore(today)) break;
      if (challenge.results.containsKey(day)) continue;
      challenge.results[day] = DailyResult.missed;
      changed = true;
    }
    if (!changed) return;
    notifyListeners();
    await _save();
  }

  /// Records that the completion ceremony was shown for [challengeId].
  /// Returns false if it was already recorded.
  Future<bool> markCelebrated(String challengeId, {DateTime? at}) async {
    final challenge = _active;
    if (challenge == null ||
        challenge.id != challengeId ||
        challenge.celebratedAt != null) {
      return false;
    }
    challenge.celebratedAt = at ?? DateTime.now();
    notifyListeners();
    await _save();
    return true;
  }

  /// Starts a fresh challenge. The previous one moves to [history] unchanged,
  /// so its results never mix with the new one.
  Future<void> startChallenge({
    required int totalDays,
    required List<String> goals,
    required List<String> habits,
    DateTime? startDate,
  }) async {
    final now = this.now();
    var stamp = DateTime.now().microsecondsSinceEpoch;
    final previous = _active?.id;
    if (previous == 'challenge-$stamp') stamp++;
    final archived = _active;
    if (archived != null) {
      await TaskNotificationService.instance.cancelAll(archived.customTasks);
      if (_history.every((c) => c.id != archived.id)) {
        _history.add(archived);
        await _saveHistory();
      }
    }
    _active = ActiveChallenge(
      id: 'challenge-$stamp',
      startDate: startDate ?? now,
      totalDays: totalDays,
      goals: List.unmodifiable(goals),
      habits: List<String>.from(habits),
    );
    notifyListeners();
    await _save();
  }

  /// Renames a daily habit. Checkbox history stays keyed by habit id, so
  /// completed/missed marks are preserved.
  Future<bool> renameHabit(int index, String name) async {
    final challenge = _active;
    final trimmed = name.trim();
    if (challenge == null ||
        trimmed.isEmpty ||
        index < 0 ||
        index >= challenge.habits.length) {
      return false;
    }
    if (challenge.habits[index] == trimmed) return true;
    challenge.habits[index] = trimmed;
    notifyListeners();
    await _save();
    return true;
  }

  /// Removes a daily habit and remaps later habit ids so remaining history
  /// stays with the correct habit. Deleted habit marks are discarded.
  Future<bool> deleteHabit(int index) async {
    final challenge = _active;
    if (challenge == null ||
        index < 0 ||
        index >= challenge.habits.length) {
      return false;
    }
    for (final day in challenge.taskStates.keys.toList()) {
      final old = challenge.taskStates[day] ?? const <String, bool>{};
      final next = <String, bool>{};
      for (var i = 0; i < challenge.habits.length; i++) {
        if (i == index) continue;
        final oldId = ActiveChallenge.habitId(i);
        if (!old.containsKey(oldId)) continue;
        final newIndex = i > index ? i - 1 : i;
        next[ActiveChallenge.habitId(newIndex)] = old[oldId]!;
      }
      if (next.isEmpty) {
        challenge.taskStates.remove(day);
      } else {
        challenge.taskStates[day] = next;
      }
    }
    challenge.habits.removeAt(index);
    notifyListeners();
    await _save();
    return true;
  }

  /// Creates a custom task on an eligible challenge day and schedules its
  /// reminder when configured.
  Future<CustomTask?> addCustomTask({
    required String title,
    required int dayNumber,
    int? reminderMinutes,
    CustomTaskRepeat repeat = CustomTaskRepeat.none,
  }) async {
    final challenge = _active;
    final trimmed = title.trim();
    if (challenge == null ||
        trimmed.isEmpty ||
        dayNumber < 1 ||
        dayNumber > challenge.totalDays) {
      return null;
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final id = 'task-$stamp';
    final task = CustomTask(
      id: id,
      title: trimmed,
      dayNumber: dayNumber,
      reminderMinutes: reminderMinutes,
      repeat: repeat,
      notificationId: _notificationIdFor(challenge.id, id),
    );
    challenge.customTasks.add(task);
    notifyListeners();
    await _save();
    await _syncReminder(challenge, task);
    return task;
  }

  Future<bool> updateCustomTask(
    String taskId, {
    String? title,
    int? dayNumber,
    int? reminderMinutes,
    bool clearReminder = false,
    CustomTaskRepeat? repeat,
  }) async {
    final challenge = _active;
    if (challenge == null) return false;
    final index = challenge.customTasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return false;
    final current = challenge.customTasks[index];
    final nextTitle = title?.trim() ?? current.title;
    final nextDay = dayNumber ?? current.dayNumber;
    if (nextTitle.isEmpty ||
        nextDay < 1 ||
        nextDay > challenge.totalDays) {
      return false;
    }
    final updated = current.copyWith(
      title: nextTitle,
      dayNumber: nextDay,
      reminderMinutes: reminderMinutes,
      clearReminder: clearReminder,
      repeat: repeat,
    );
    challenge.customTasks[index] = updated;
    notifyListeners();
    await _save();
    await _syncReminder(challenge, updated);
    return true;
  }

  Future<bool> setCustomTaskCompleted(String taskId, bool completed) async {
    final challenge = _active;
    if (challenge == null) return false;
    final index = challenge.customTasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return false;
    final current = challenge.customTasks[index];
    if (!challenge.isDayAvailable(current.dayNumber, now()) && completed) {
      return false;
    }
    if (current.completed == completed) return true;
    final updated = current.copyWith(completed: completed);
    challenge.customTasks[index] = updated;
    notifyListeners();
    await _save();
    await _syncReminder(challenge, updated);
    return true;
  }

  Future<bool> deleteCustomTask(String taskId) async {
    final challenge = _active;
    if (challenge == null) return false;
    final index = challenge.customTasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return false;
    final removed = challenge.customTasks.removeAt(index);
    notifyListeners();
    await _save();
    await TaskNotificationService.instance.cancel(removed.notificationId);
    return true;
  }

  Future<void> _syncReminder(ActiveChallenge challenge, CustomTask task) {
    return TaskNotificationService.instance.syncTask(
      task: task,
      taskDate: challenge.dateForDay(task.dayNumber),
      challengeId: challenge.id,
    );
  }

  static int _notificationIdFor(String challengeId, String taskId) {
    final raw = '$challengeId|$taskId';
    var hash = 0;
    for (final code in raw.codeUnits) {
      hash = 0x1fffffff & (hash + code);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash == 0 ? 1 : hash;
  }

  Future<void> setTask(
    String challengeId,
    int dayNumber,
    String habitId,
    bool completed,
  ) async {
    final challenge = _active;
    if (challenge == null || challenge.id != challengeId) return;
    challenge.taskStates.putIfAbsent(dayNumber, () => {})[habitId] = completed;
    notifyListeners();
    await _save();
  }

  Future<void> setResult(
    String challengeId,
    int dayNumber,
    DailyResult result,
  ) async {
    final challenge = _active;
    if (challenge == null ||
        challenge.id != challengeId ||
        !challenge.isDayAvailable(dayNumber, now()) ||
        challenge.results.containsKey(dayNumber)) {
      return;
    }
    challenge.results[dayNumber] = result;
    notifyListeners();
    await _save();
  }

  /// Reverts the most recent swipe. Earlier days are never touched, and a
  /// celebrated challenge stays finished.
  Future<bool> undoResult(String challengeId, int dayNumber) async {
    final challenge = _active;
    if (challenge == null ||
        challenge.id != challengeId ||
        challenge.celebratedAt != null ||
        !challenge.results.containsKey(dayNumber) ||
        challenge.results.keys.any((day) => day < dayNumber)) {
      return false;
    }
    challenge.results.remove(dayNumber);
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> setGoalAchieved(
    String challengeId,
    String goal,
    bool achieved,
  ) async {
    final challenge = _active;
    if (challenge == null || challenge.id != challengeId) return;
    if (achieved) {
      challenge.achievedGoals.add(goal);
    } else {
      challenge.achievedGoals.remove(goal);
    }
    notifyListeners();
    await _save();
  }

  /// Removes the active challenge. It is not archived, so it never returns.
  Future<void> deleteActiveChallenge() async {
    final challenge = _active;
    if (challenge == null) return;
    await TaskNotificationService.instance.cancelAll(challenge.customTasks);
    _active = null;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final challenge = _active;
      if (challenge == null) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, jsonEncode(challenge.toJson()));
      }
    } catch (error) {
      debugPrint('Sticky Path could not save the challenge: $error');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _historyKey,
        jsonEncode([for (final challenge in _history) challenge.toJson()]),
      );
    } catch (error) {
      debugPrint('Sticky Path could not save challenge history: $error');
    }
  }
}

/// Completed challenge days from [evaluateProgress], refreshed on every
/// store change, so Home shows the same count as Overview.
class CompletedDaysListenable extends ChangeNotifier
    implements ValueListenable<int> {
  CompletedDaysListenable(this.store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    store.addListener(notifyListeners);
  }

  final ChallengeStore store;
  final DateTime Function() _clock;

  @override
  int get value {
    final challenge = store.active;
    if (challenge == null) return 0;
    return evaluateProgress(challenge.progress(_clock())).completedDays;
  }

  @override
  void dispose() {
    store.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Lets Home's existing repository calls write into [ChallengeStore].
class StoreChallengeRepository implements ChallengeRepository {
  StoreChallengeRepository(this.store);

  final ChallengeStore store;

  @override
  Future<void> saveTaskState({
    required String challengeId,
    required int dayNumber,
    required DailyTask task,
  }) {
    return store.setTask(challengeId, dayNumber, task.id, task.completed);
  }

  @override
  Future<void> saveDailyResult({
    required String challengeId,
    required int dayNumber,
    required DailyResult result,
  }) {
    return store.setResult(challengeId, dayNumber, result);
  }

  @override
  Future<void> clearDailyResult({
    required String challengeId,
    required int dayNumber,
  }) {
    return store.undoResult(challengeId, dayNumber);
  }
}
