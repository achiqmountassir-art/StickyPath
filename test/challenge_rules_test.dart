import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sticky_path/progress/challenge_progress.dart';
import 'package:sticky_path/progress/challenge_store.dart';
import 'package:sticky_path/progress/progress_logic.dart';
import 'package:sticky_path/screens/Home_screen.dart'
    show DailyResult, challengeDayLabel;
import 'package:sticky_path/screens/challenge_screen.dart';

final start = DateTime(2026, 10, 1);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ChallengeStore> started(int days, DateTime Function() clock) async {
    final store = ChallengeStore(clock: clock);
    await store.startChallenge(
      totalDays: days,
      goals: const [],
      habits: const ['Gym'],
      startDate: start,
    );
    return store;
  }

  test('Home and Progress agree on first and final day for every duration',
      () async {
    for (final days in ChallengeScreen.durations) {
      final store = await started(days, () => start);
      final challenge = store.active!;
      for (final index in [0, 1, days - 1]) {
        final date = addCalendarDays(start, index);
        final homeDay = days - index;
        final view = evaluateProgress(challenge.progress(date));

        expect(challenge.dateForDay(homeDay), date);
        expect(challengeDayLabel(homeDay, days), index + 1);
        expect(view.currentDay, index + 1, reason: '$days days, index $index');
      }
      final afterEnd = addCalendarDays(start, days + 5);
      expect(evaluateProgress(challenge.progress(afterEnd)).currentDay, days);
    }
  });

  test('a note unlocks at midnight of its own date', () async {
    var now = DateTime(2026, 10, 1, 23, 59, 59);
    final store = await started(7, () => now);
    final id = store.active!.id;

    await store.setResult(id, 7, DailyResult.completed);
    await store.setResult(id, 6, DailyResult.completed);
    expect(store.active!.results, {7: DailyResult.completed});

    now = DateTime(2026, 10, 2, 0, 0, 1);
    await store.setResult(id, 6, DailyResult.missed);
    await store.setResult(id, 6, DailyResult.completed);
    expect(store.active!.results, {
      7: DailyResult.completed,
      6: DailyResult.missed,
    });
  });

  test('undo only reverts the latest swipe', () async {
    final store = await started(7, () => addCalendarDays(start, 3));
    final id = store.active!.id;
    await store.setResult(id, 7, DailyResult.completed);
    await store.setResult(id, 6, DailyResult.missed);

    expect(await store.undoResult(id, 7), isFalse);
    expect(await store.undoResult(id, 6), isTrue);
    expect(store.active!.results, {7: DailyResult.completed});

    await store.setResult(id, 6, DailyResult.completed);
    final restarted = ChallengeStore(clock: () => addCalendarDays(start, 3));
    await restarted.load();
    expect(restarted.active!.results, {
      7: DailyResult.completed,
      6: DailyResult.completed,
      5: DailyResult.missed,
    });
  });

  test('past notes that were never swiped close as missed', () async {
    var now = start;
    final store = await started(7, () => now);
    final id = store.active!.id;
    await store.setResult(id, 7, DailyResult.completed);
    await store.setTask(id, 6, ActiveChallenge.habitId(0), true);

    now = addCalendarDays(start, 3);
    await store.closePastDays();
    expect(store.active!.results, {
      7: DailyResult.completed,
      6: DailyResult.missed,
      5: DailyResult.missed,
    });
    expect(store.active!.homeCurrentDay, 4);

    final restarted = ChallengeStore(clock: () => now);
    await restarted.load();
    expect(restarted.active!.results, store.active!.results);
    final view = evaluateProgress(restarted.active!.progress(now));
    expect(view.days[1].status, ProgressDayStatus.missed);
    expect(view.days[3].status, ProgressDayStatus.pending);
  });

  test('deleting a challenge clears it from memory and storage', () async {
    final store = await started(30, () => start);
    await store.deleteActiveChallenge();
    expect(store.active, isNull);

    final restarted = ChallengeStore();
    await restarted.load();
    expect(restarted.active, isNull);
    expect(restarted.history, isEmpty);

    await restarted.startChallenge(
      totalDays: 7,
      goals: const [],
      habits: const ['Read'],
      startDate: start,
    );
    final again = ChallengeStore();
    await again.load();
    expect(again.active!.habits, ['Read']);
    expect(again.active!.totalDays, 7);
    expect(again.active!.startDate, start);
  });

}
