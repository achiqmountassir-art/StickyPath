import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sticky_path/progress/challenge_store.dart';
import 'package:sticky_path/progress/custom_task.dart';
import 'package:sticky_path/screens/Home_screen.dart' show challengeDayLabel;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late ChallengeStore store;
  final start = DateTime(2026, 10, 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = start;
    store = ChallengeStore(clock: () => now);
    await store.load();
    await store.startChallenge(
      totalDays: 30,
      goals: const ['Goal'],
      habits: const ['Meditate', 'Walk'],
      startDate: start,
    );
  });

  test('creates and persists a future-day custom task', () async {
    expect(challengeDayLabel(21, 30), 10);

    final task = await store.addCustomTask(
      title: 'Go swimming',
      dayNumber: 21,
      reminderMinutes: 10 * 60,
    );
    expect(task, isNotNull);
    expect(task!.title, 'Go swimming');
    expect(task.dayNumber, 21);
    expect(task.reminderMinutes, 600);
    expect(store.active!.customTasksForDay(21), hasLength(1));

    final reloaded = ChallengeStore(clock: () => start);
    await reloaded.load();
    expect(reloaded.active!.customTasks, hasLength(1));
    expect(reloaded.active!.customTasks.first.title, 'Go swimming');
    expect(reloaded.active!.customTasks.first.id, task.id);
  });

  test('rejects empty titles and days outside the challenge', () async {
    expect(await store.addCustomTask(title: '  ', dayNumber: 5), isNull);
    expect(await store.addCustomTask(title: 'Ok', dayNumber: 0), isNull);
    expect(await store.addCustomTask(title: 'Ok', dayNumber: 31), isNull);
  });

  test('edit, reschedule, complete, and delete keep a stable id', () async {
    final created = await store.addCustomTask(
      title: 'Swim',
      dayNumber: 21,
      reminderMinutes: 9 * 60,
    );
    final id = created!.id;

    expect(
      await store.updateCustomTask(
        id,
        title: 'Swim laps',
        dayNumber: 15,
        reminderMinutes: 11 * 60,
      ),
      isTrue,
    );
    var task = store.active!.customTasks.single;
    expect(task.id, id);
    expect(task.title, 'Swim laps');
    expect(task.dayNumber, 15);
    expect(task.reminderMinutes, 660);

    // With calendar lock (default in tests), future days cannot complete early.
    ActiveChallenge.unlockSwipeForTesting = false;
    expect(await store.setCustomTaskCompleted(id, true), isFalse);

    now = store.active!.dateForDay(15);
    expect(await store.setCustomTaskCompleted(id, true), isTrue);
    expect(store.active!.customTasks.single.completed, isTrue);

    expect(await store.deleteCustomTask(id), isTrue);
    expect(store.active!.customTasks, isEmpty);
  });

  test('habit task state stays separate from custom tasks', () async {
    await store.addCustomTask(title: 'Custom', dayNumber: 30);
    await store.setTask(store.active!.id, 30, 'goal-0', true);
    expect(store.active!.taskStates[30]!['goal-0'], isTrue);
    expect(store.active!.customTasks.single.completed, isFalse);
  });

  test('deleting a challenge clears its custom tasks from storage', () async {
    await store.addCustomTask(title: 'Temp', dayNumber: 20);
    await store.deleteActiveChallenge();
    expect(store.active, isNull);

    final reloaded = ChallengeStore(clock: () => start);
    await reloaded.load();
    expect(reloaded.active, isNull);
  });

  test('older saved challenges without customTasks still load', () {
    final challenge = ActiveChallenge.fromJson({
      'id': 'challenge-old',
      'startDate': start.toIso8601String(),
      'totalDays': 7,
      'goals': ['G'],
      'habits': ['H'],
      'tasks': <String, dynamic>{},
      'results': <String, dynamic>{},
      'achievedGoals': <String>[],
    });
    expect(challenge.customTasks, isEmpty);
  });

  test('formatReminderMinutes uses 12-hour labels', () {
    expect(formatReminderMinutes(0), '12:00 AM');
    expect(formatReminderMinutes(10 * 60), '10:00 AM');
    expect(formatReminderMinutes(15 * 60 + 30), '3:30 PM');
  });

  test('renaming a habit keeps its check history', () async {
    await store.setTask(store.active!.id, 30, 'goal-0', true);
    expect(await store.renameHabit(0, 'Meditate longer'), isTrue);
    expect(store.active!.habits[0], 'Meditate longer');
    expect(store.active!.taskStates[30]!['goal-0'], isTrue);
    expect(store.active!.habits[1], 'Walk');
  });

  test('deleting a habit remaps later habit history', () async {
    await store.setTask(store.active!.id, 30, 'goal-0', true);
    await store.setTask(store.active!.id, 30, 'goal-1', true);
    expect(await store.deleteHabit(0), isTrue);
    expect(store.active!.habits, ['Walk']);
    expect(store.active!.taskStates[30]!.containsKey('goal-0'), isTrue);
    expect(store.active!.taskStates[30]!['goal-0'], isTrue);
    expect(store.active!.taskStates[30]!.containsKey('goal-1'), isFalse);
  });
}
