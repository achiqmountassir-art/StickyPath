import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sticky_path/progress/challenge_progress.dart';
import 'package:sticky_path/progress/challenge_store.dart';
import 'package:sticky_path/progress/progress_logic.dart';
import 'package:sticky_path/screens/Home_screen.dart' show DailyResult;
import 'package:sticky_path/screens/main_shell.dart';
import 'package:sticky_path/screens/progress_screen.dart';

final today = DateTime(2026, 10, 9);

Future<ChallengeStore> startStore({
  required int days,
  required List<String> habits,
  required DateTime start,
  List<String> goals = const [],
  DateTime Function()? clock,
}) async {
  final store = ChallengeStore(clock: clock ?? () => today);
  await store.startChallenge(
    totalDays: days,
    goals: goals,
    habits: habits,
    startDate: start,
  );
  return store;
}

/// Checks habits on the challenge date at [index] (0 = start date).
Future<void> check(
  ChallengeStore store,
  int index,
  List<int> habits, {
  bool completed = true,
}) async {
  final challenge = store.active!;
  for (final habit in habits) {
    await store.setTask(
      challenge.id,
      challenge.totalDays - index,
      ActiveChallenge.habitId(habit),
      completed,
    );
  }
}

Future<void> swipe(ChallengeStore store, int index, DailyResult result) {
  final challenge = store.active!;
  return store.setResult(challenge.id, challenge.totalDays - index, result);
}

ProgressView viewOf(ChallengeStore store, [DateTime? day]) =>
    evaluateProgress(store.active!.progress(day ?? today));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('7-day challenge with nothing completed', () async {
    final store = await startStore(days: 7, habits: ['Gym'], start: today);
    final view = viewOf(store);

    expect(view.completedDays, 0);
    expect(view.totalDays, 7);
    expect(view.progress, 0);
    expect(view.percent, 0);
    expect(view.streak, 0);
    expect(view.currentDay, 1);
    expect(view.days, hasLength(7));
    expect(view.days.first.status, ProgressDayStatus.pending);
    expect(view.days.skip(1).every((d) => d.status == ProgressDayStatus.future),
        isTrue);
  });

  test('7-day challenge with one fully completed day', () async {
    final store = await startStore(
      days: 7,
      habits: ['Gym', 'Read'],
      start: addCalendarDays(today, -1),
    );
    await check(store, 0, [0, 1]);
    final view = viewOf(store);

    expect(view.completedDays, 1);
    expect(view.percent, 14);
    expect(view.streak, 1);
    expect(view.currentDay, 2);
    expect(view.days[0].status, ProgressDayStatus.completed);
    expect(view.days[1].status, ProgressDayStatus.pending);
  });

  test('30-day challenge with completed, partial, and empty days', () async {
    final store = await startStore(
      days: 30,
      habits: ['Gym', 'Python'],
      goals: ['Get fit'],
      start: addCalendarDays(today, -9),
    );
    for (final index in [0, 1, 2, 5, 6, 7, 8]) {
      await check(store, index, [0, 1]);
    }
    await check(store, 3, [0]);
    await check(store, 9, [1]);
    final view = viewOf(store);

    expect(view.completedDays, 7);
    expect(view.progress, closeTo(7 / 30, 0.0001));
    expect(view.percent, 23);
    expect(view.currentDay, 10);
    expect(view.streak, 4);
    expect(view.days[3].status, ProgressDayStatus.partial);
    expect(view.days[4].status, ProgressDayStatus.noActivity);
    expect(view.days[9].status, ProgressDayStatus.partial);
    expect(view.days[10].status, ProgressDayStatus.future);
    expect(view.goals, ['Get fit']);

    final gym = view.habits[0];
    expect(gym.completed, 8);
    expect(gym.missed, 1);
    expect(gym.pending, 1);
    expect(gym.future, 20);
    final python = view.habits[1];
    expect(python.completed, 8);
    expect(python.missed, 2);
    expect(python.pending, 0);
  });

  test('toggling a habit updates the day once and ignores future dates',
      () async {
    final store = await startStore(days: 7, habits: ['Gym'], start: today);
    var notified = 0;
    store.addListener(() => notified++);

    await check(store, 0, [0]);
    expect(viewOf(store).completedDays, 1);
    expect(viewOf(store).streak, 1);

    await check(store, 0, [0]);
    expect(viewOf(store).completedDays, 1);

    await check(store, 0, [0], completed: false);
    expect(viewOf(store).completedDays, 0);
    expect(viewOf(store).days[0].status, ProgressDayStatus.pending);

    await check(store, 1, [0]);
    expect(viewOf(store).completedDays, 0);
    expect(viewOf(store).days[1].status, ProgressDayStatus.future);
    expect(
      viewOf(store, addCalendarDays(today, 1)).days[1].status,
      ProgressDayStatus.completed,
    );
    expect(notified, 4);
  });

  test('saved tracking is restored after a restart', () async {
    final store = await startStore(
      days: 30,
      habits: ['Gym'],
      goals: ['Get fit'],
      start: addCalendarDays(today, -2),
    );
    await check(store, 0, [0]);
    await swipe(store, 0, DailyResult.completed);
    await check(store, 1, [0]);
    await swipe(store, 1, DailyResult.completed);

    final restarted = ChallengeStore(clock: () => today);
    await restarted.load();

    expect(restarted.active!.id, store.active!.id);
    expect(restarted.active!.goals, ['Get fit']);
    expect(restarted.active!.habits, ['Gym']);
    final view = viewOf(restarted);
    expect(view.completedDays, 2);
    expect(view.streak, 2);
    expect(view.totalDays, 30);
  });

  test('a new challenge does not inherit the previous one', () async {
    final store = await startStore(
      days: 7,
      habits: ['Gym'],
      start: addCalendarDays(today, -1),
    );
    await check(store, 0, [0]);
    final oldId = store.active!.id;

    await store.startChallenge(
      totalDays: 30,
      goals: const [],
      habits: const ['Run'],
      startDate: today,
    );
    await store.setTask(oldId, 7, ActiveChallenge.habitId(0), true);

    final view = viewOf(store);
    expect(store.active!.id, isNot(oldId));
    expect(store.active!.taskStates, isEmpty);
    expect(view.totalDays, 30);
    expect(view.completedDays, 0);
    expect(view.habits.single.name, 'Run');
  });

  group('swipe results', () {
    late ChallengeStore store;
    setUp(() async {
      store = await startStore(
        days: 7,
        habits: ['Gym', 'Read'],
        start: addCalendarDays(today, -2),
      );
    });

    test('right swipe with all habits checked completes the day', () async {
      await check(store, 0, [0, 1]);
      await swipe(store, 0, DailyResult.completed);
      final view = viewOf(store);

      expect(store.active!.results[7], DailyResult.completed);
      expect(view.days[0].status, ProgressDayStatus.completed);
      expect(view.completedDays, 1);
      expect(view.percent, 14);
    });

    test('right swipe with unchecked habits still completes the day', () async {
      await check(store, 0, [0]);
      await swipe(store, 0, DailyResult.completed);
      final view = viewOf(store);

      expect(store.active!.results[7], DailyResult.completed);
      expect(view.days[0].status, ProgressDayStatus.completed);
      expect(view.completedDays, 1);
      expect(view.habits[0].completed, 1);
      expect(view.habits[1].missed, 2);
    });

    test('left swipe overrides checked habits', () async {
      await check(store, 0, [0, 1]);
      await swipe(store, 0, DailyResult.missed);
      final view = viewOf(store);

      expect(view.days[0].status, ProgressDayStatus.missed);
      expect(view.completedDays, 0);
      expect(view.habits[0].completed, 1);
    });

    test('left swipe today is missed and breaks the streak', () async {
      await check(store, 0, [0, 1]);
      await check(store, 1, [0, 1]);
      expect(viewOf(store).streak, 2);

      await check(store, 2, [0, 1]);
      await swipe(store, 2, DailyResult.missed);
      final view = viewOf(store);

      expect(view.days[2].status, ProgressDayStatus.missed);
      expect(view.days[3].status, ProgressDayStatus.future);
      expect(view.completedDays, 2);
      expect(view.streak, 0);
      expect(view.percent, 29);
    });

    test('duplicate and out-of-range results are ignored', () async {
      await swipe(store, 0, DailyResult.missed);
      await check(store, 0, [0, 1]);
      await swipe(store, 0, DailyResult.completed);
      await store.setResult(store.active!.id, 0, DailyResult.missed);
      await store.setResult(store.active!.id, 8, DailyResult.missed);

      expect(store.active!.results, {7: DailyResult.missed});
      expect(viewOf(store).days[0].status, ProgressDayStatus.missed);
    });

    test('right swipe today counts and extends the streak', () async {
      await swipe(store, 0, DailyResult.completed);
      await swipe(store, 1, DailyResult.completed);
      await swipe(store, 2, DailyResult.completed);
      final view = viewOf(store);

      expect(view.days[2].status, ProgressDayStatus.completed);
      expect(view.completedDays, 3);
      expect(view.streak, 3);
      expect(view.percent, 43);
    });

    test('notes ahead of today cannot be swiped', () async {
      for (var index = 0; index < 5; index++) {
        await swipe(
          store,
          index,
          index == 1 ? DailyResult.missed : DailyResult.completed,
        );
      }
      final view = viewOf(store);

      expect(store.active!.results, {
        7: DailyResult.completed,
        6: DailyResult.missed,
        5: DailyResult.completed,
      });
      expect(view.days.map((d) => d.status).take(4).toList(), [
        ProgressDayStatus.completed,
        ProgressDayStatus.missed,
        ProgressDayStatus.completed,
        ProgressDayStatus.future,
      ]);
      expect(view.completedDays, 2);
      expect(view.streak, 1);
    });

    test('checking a future note without swiping stays future', () async {
      await check(store, 4, [0, 1]);
      expect(viewOf(store).days[4].status, ProgressDayStatus.future);
      expect(viewOf(store).completedDays, 0);
    });

    test('calendar statuses and streak across a mixed week', () async {
      await check(store, 0, [0, 1]);
      await swipe(store, 0, DailyResult.completed);
      await check(store, 1, [0]);
      await check(store, 2, [0, 1]);
      final view = viewOf(store);

      expect(view.days.map((d) => d.status).toList(), [
        ProgressDayStatus.completed,
        ProgressDayStatus.partial,
        ProgressDayStatus.completed,
        ProgressDayStatus.future,
        ProgressDayStatus.future,
        ProgressDayStatus.future,
        ProgressDayStatus.future,
      ]);
      expect(view.completedDays, 2);
      expect(view.streak, 1);
    });

    test('swipe results persist after restart', () async {
      await check(store, 0, [0, 1]);
      await swipe(store, 0, DailyResult.completed);
      await swipe(store, 1, DailyResult.missed);

      final restarted = ChallengeStore(clock: () => today);
      await restarted.load();
      expect(restarted.active!.results, {
        7: DailyResult.completed,
        6: DailyResult.missed,
      });
      expect(restarted.active!.homeCurrentDay, 5);
      final view = viewOf(restarted);
      expect(view.days[0].status, ProgressDayStatus.completed);
      expect(view.days[1].status, ProgressDayStatus.missed);
      expect(view.completedDays, 1);
    });
  });

  test('invalid durations are safe', () {
    for (final days in [0, -3]) {
      final view = evaluateProgress(
        ChallengeProgress(
          startDate: today,
          totalDays: days,
          today: today,
          habits: const [],
        ),
      );
      expect(view.totalDays, 0);
      expect(view.progress, 0);
      expect(view.days, isEmpty);
    }
  });

  testWidgets('Progress shows store data and the empty state', (tester) async {
    final empty = ChallengeStore();
    await tester.pumpWidget(
      MaterialApp(home: ProgressScreen(store: empty, today: today)),
    );
    expect(find.text('No active challenge yet'), findsOneWidget);

    final store = await tester.runAsync(
      () => startStore(
        days: 7,
        habits: ['Gym'],
        goals: ['Get fit'],
        start: addCalendarDays(today, -1),
      ),
    );
    await tester.runAsync(() => check(store!, 0, [0]));
    await tester.pumpWidget(
      MaterialApp(home: ProgressScreen(store: store, today: today)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1/7'), findsOneWidget);
    expect(find.text('14% complete · Day 2 of 7'), findsOneWidget);
    expect(find.text('1 day streak'), findsOneWidget);

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('Get fit'), findsOneWidget);
    expect(find.text('Not tracked yet'), findsOneWidget);
    expect(find.text('1 completed · 0 missed · 1 pending · 5 future'),
        findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Partial'), findsOneWidget);
    expect(find.text('No activity'), findsOneWidget);
  });

  testWidgets('checking a habit on Home updates Progress', (tester) async {
    final now = dateOnly(DateTime.now());
    final store = await tester.runAsync(
      () => startStore(
        days: 7,
        habits: ['Gym'],
        start: now,
        clock: DateTime.now,
      ),
    );
    await tester.pumpWidget(MaterialApp(home: MainShell(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gym').hitTestable());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(store!.active!.taskStates[7]?['goal-0'], isTrue);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('1/7').hitTestable(), findsOneWidget);
    expect(find.text('1 day streak').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Calendar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('1 completed · 0 missed · 6 future').hitTestable(),
        findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gym').hitTestable());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('0/7').hitTestable(), findsOneWidget);
  });

  Future<ChallengeStore> openShell(WidgetTester tester) async {
    final now = dateOnly(DateTime.now());
    final store = await tester.runAsync(
      () => startStore(
        days: 7,
        habits: ['Gym', 'Read'],
        start: now,
        clock: DateTime.now,
      ),
    );
    await tester.pumpWidget(MaterialApp(home: MainShell(store: store)));
    await tester.pumpAndSettle();
    return store!;
  }

  void hideSnackBar(WidgetTester tester) {
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
  }

  Future<void> removeDay(WidgetTester tester, String choice) async {
    hideSnackBar(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('right swipe on Home completes the day', (tester) async {
    final store = await openShell(tester);
    await removeDay(tester, 'Completed');

    expect(store.active!.results[7], DailyResult.completed);
    expect(find.text('1 completed'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('1/7').hitTestable(), findsOneWidget);
    expect(find.text('1 day streak').hitTestable(), findsOneWidget);
  });

  testWidgets('tomorrow\'s note stays locked on Home', (tester) async {
    final store = await openShell(tester);
    expect(find.text('DAY 1 OF 7'), findsOneWidget);
    await removeDay(tester, 'Completed');
    expect(find.text('DAY 2 OF 7'), findsOneWidget);

    hideSnackBar(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove day'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Day 2 unlocks on'), findsOneWidget);
    expect(find.text('Missed'), findsNothing);
    expect(store.active!.results, {7: DailyResult.completed});

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('1/7').hitTestable(), findsOneWidget);
  });

  testWidgets('undo restores the last swiped note', (tester) async {
    final store = await openShell(tester);
    await removeDay(tester, 'Completed');
    expect(find.text('1 completed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(store.active!.results, isEmpty);
    expect(find.text('DAY 1 OF 7'), findsOneWidget);
    expect(find.text('0 completed'), findsOneWidget);

    await removeDay(tester, 'Missed');
    expect(store.active!.results, {7: DailyResult.missed});
  });

  testWidgets('left swipe on Home marks today missed', (tester) async {
    final store = await openShell(tester);
    await tester.tap(find.text('Gym').hitTestable());
    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();
    await removeDay(tester, 'Missed');

    expect(store.active!.results[7], DailyResult.missed);
    expect(find.text('0 completed'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('0/7').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Calendar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().day}').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Missed').hitTestable(), findsWidgets);
  });

  testWidgets('right swipe with all habits checked updates Home and Overview',
      (tester) async {
    final store = await openShell(tester);
    await tester.tap(find.text('Gym').hitTestable());
    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();
    await removeDay(tester, 'Completed');

    expect(store.active!.results[7], DailyResult.completed);
    expect(find.text('1 completed'), findsOneWidget);
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('1/7').hitTestable(), findsOneWidget);
  });
}
