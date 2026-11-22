import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sticky_path/progress/achievement_sticker.dart';
import 'package:sticky_path/progress/challenge_completion.dart';
import 'package:sticky_path/progress/challenge_progress.dart';
import 'package:sticky_path/progress/challenge_store.dart';
import 'package:sticky_path/screens/Home_screen.dart' show DailyResult;
import 'package:sticky_path/screens/completion_screen.dart';
import 'package:sticky_path/screens/main_shell.dart';
import 'package:sticky_path/screens/sticker_preview_screen.dart';

final start = DateTime(2026, 10, 1);

Future<ChallengeStore> newStore({int days = 7}) async {
  final store = ChallengeStore(clock: () => addCalendarDays(start, 200));
  await store.startChallenge(
    totalDays: days,
    goals: const ['Get fit'],
    habits: const ['Gym'],
    startDate: start,
  );
  return store;
}

Future<void> swipeAll(ChallengeStore store, List<DailyResult> results) async {
  final challenge = store.active!;
  for (var index = 0; index < results.length; index++) {
    await store.setResult(
      challenge.id,
      challenge.totalDays - index,
      results[index],
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('eligibility', () {
    test('completes only when the last note is swiped', () async {
      final store = await newStore();
      await swipeAll(store, List.filled(6, DailyResult.completed));
      expect(isChallengeComplete(store.active!, start), isFalse);

      await store.setResult(store.active!.id, 1, DailyResult.missed);
      expect(isChallengeComplete(store.active!, start), isTrue);
    });

    test('checking habits without swiping never completes early', () async {
      final store = await newStore();
      for (var day = 7; day >= 1; day--) {
        await store.setTask(store.active!.id, day, 'goal-0', true);
      }
      expect(
        isChallengeComplete(store.active!, addCalendarDays(start, 3)),
        isFalse,
      );
    });

    test('last day completes only once its note is resolved', () async {
      final store = await newStore();
      final lastDay = addCalendarDays(start, 6);
      await swipeAll(store, List.filled(6, DailyResult.completed));
      expect(isChallengeComplete(store.active!, lastDay), isFalse);

      await store.setResult(store.active!.id, 1, DailyResult.missed);
      expect(isChallengeComplete(store.active!, lastDay), isTrue);
    });

    test('after the end date the challenge is complete', () async {
      final store = await newStore();
      expect(
        isChallengeComplete(store.active!, addCalendarDays(start, 7)),
        isTrue,
      );
    });

    test('invalid durations and future starts never complete', () {
      final zero = ActiveChallenge(
        id: 'zero',
        startDate: start,
        totalDays: 0,
        goals: const [],
        habits: const [],
      );
      final later = ActiveChallenge(
        id: 'later',
        startDate: addCalendarDays(start, 30),
        totalDays: 1,
        goals: const [],
        habits: const ['Gym'],
      );
      expect(isChallengeComplete(zero, addCalendarDays(start, 100)), isFalse);
      expect(isChallengeComplete(later, start), isFalse);
    });
  });

  test('summary matches Progress and keeps missed days separate', () async {
    final store = await newStore();
    await swipeAll(store, [
      DailyResult.completed,
      DailyResult.completed,
      DailyResult.missed,
      DailyResult.completed,
      DailyResult.completed,
    ]);
    final summary = ChallengeSummary.of(
      store.active!,
      addCalendarDays(start, 7),
    );

    expect(summary.totalDays, 7);
    expect(summary.completedDays, 4);
    expect(summary.missedDays, 3);
    expect(summary.partialDays, 0);
    expect(summary.streak, 0);
    expect(summary.startDate, start);
    expect(summary.endDate, DateTime(2026, 10, 7));
    expect(summary.title, '7-Day Challenge');
  });

  test('celebration is stored once and survives a restart', () async {
    final store = await newStore();
    final id = store.active!.id;
    expect(await store.markCelebrated(id), isTrue);
    expect(await store.markCelebrated(id), isFalse);

    final restarted = ChallengeStore();
    await restarted.load();
    expect(restarted.active!.celebratedAt, isNotNull);
    expect(await restarted.markCelebrated(id), isFalse);
  });

  test('a new challenge keeps the finished one in history', () async {
    final store = await newStore();
    await swipeAll(store, [DailyResult.completed]);
    final oldId = store.active!.id;
    await store.markCelebrated(oldId);
    await store.startChallenge(
      totalDays: 30,
      goals: const [],
      habits: const ['Run'],
      startDate: addCalendarDays(start, 10),
    );

    final restarted = ChallengeStore();
    await restarted.load();
    expect(restarted.history.single.id, oldId);
    expect(restarted.history.single.results, {7: DailyResult.completed});
    expect(restarted.history.single.celebratedAt, isNotNull);
    expect(restarted.active!.celebratedAt, isNull);
    expect(restarted.active!.totalDays, 30);
  });

  group('sticker', () {
    const data = StickerData(totalDays: 90, completedDays: 73);

    test('text is real data and identical across styles', () {
      expect(data.headline, '90 DAYS');
      expect(data.subtitle, 'COMPLETED');
      expect(data.statistic, '73 / 90 days');
    });

    testWidgets('exports a transparent RGBA PNG for every style',
        (tester) async {
      for (final style in StickerStyle.values) {
        final result = await tester.runAsync(() async {
          final png = await renderStickerPng(data, style, size: 512);
          final codec = await ui.instantiateImageCodec(png);
          final frame = await codec.getNextFrame();
          final rgba = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final size = frame.image.width;
          frame.image.dispose();
          return (png, rgba!, size);
        });
        final (png, rgba, size) = result!;

        expect(png.sublist(1, 4), 'PNG'.codeUnits);
        expect(png[25], 6, reason: 'IHDR color type must be RGBA');
        expect(size, 512);

        int alphaAt(int x, int y) => rgba.getUint8((y * size + x) * 4 + 3);
        expect(alphaAt(0, 0), 0);
        expect(alphaAt(size - 1, size - 1), 0);
        expect(alphaAt(size ~/ 2, 4), 0);
        var opaque = 0;
        for (var i = 3; i < rgba.lengthInBytes; i += 4) {
          if (rgba.getUint8(i) > 200) opaque++;
        }
        expect(opaque, greaterThan(500), reason: '${style.name} has artwork');
      }
    });
  });

  testWidgets('Save and Share receive the generated PNG', (tester) async {
    final calls = <(String, Uint8List, String)>[];
    final summary = ChallengeSummary.of(
      (await tester.runAsync(newStore))!.active!,
      addCalendarDays(start, 7),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StickerPreviewScreen(
          summary: summary,
          onSave: (png, name) async => calls.add(('save', png, name)),
          onShare: (png, name) async => calls.add(('share', png, name)),
        ),
      ),
    );

    await tester.tap(find.text('Glow'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save PNG'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Share to Story'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(calls.map((c) => c.$1), ['save', 'share']);
    for (final call in calls) {
      expect(call.$2.sublist(1, 4), 'PNG'.codeUnits);
      expect(call.$2[25], 6);
      expect(call.$3, 'stickypath-7-days-glow');
    }
    expect(find.text('Sticker saved to your photos'), findsOneWidget);
  });

  group('ceremony', () {
    Future<void> openShell(
      WidgetTester tester,
      ChallengeStore store,
      DateTime now,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: MainShell(store: store, clock: () => now)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a partly swiped deck shows no ceremony', (tester) async {
      final store = (await tester.runAsync(newStore))!;
      await tester.runAsync(
        () => swipeAll(store, List.filled(6, DailyResult.completed)),
      );
      await openShell(tester, store, addCalendarDays(start, 2));

      expect(find.text('Challenge Completed'), findsNothing);
      expect(store.active!.celebratedAt, isNull);
    });

    testWidgets('swiping the last note on Home opens the ceremony',
        (tester) async {
      final store = (await tester.runAsync(
        () async {
          final store = ChallengeStore();
          await store.startChallenge(
            totalDays: 2,
            goals: const [],
            habits: const ['Gym'],
            startDate: addCalendarDays(dateOnly(DateTime.now()), -1),
          );
          return store;
        },
      ))!;
      await openShell(tester, store, DateTime.now());

      for (final choice in ['Completed', 'Missed']) {
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove day'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(choice));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Challenge Completed'), findsOneWidget);
      expect(find.text('Challenge complete'), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.text('1 / 2 days'), findsOneWidget);
      expect(store.active!.celebratedAt, isNotNull);

      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('1/2').hitTestable(), findsOneWidget);
    });

    testWidgets('shows once after the final day, never again after restart',
        (tester) async {
      final store = (await tester.runAsync(newStore))!;
      await tester.runAsync(
        () => swipeAll(store, [
          DailyResult.completed,
          DailyResult.missed,
          ...List.filled(4, DailyResult.completed),
        ]),
      );
      final after = addCalendarDays(start, 7);
      await openShell(tester, store, after);

      expect(find.text('Challenge Completed'), findsOneWidget);
      expect(find.text('7-Day Challenge'), findsOneWidget);
      expect(find.text('5 / 7 days'), findsOneWidget);
      expect(find.text('2 days'), findsOneWidget);
      expect(store.active!.celebratedAt, isNotNull);

      await tester.tap(find.text('View Your Sticker'));
      await tester.pumpAndSettle();
      expect(find.text('Your sticker'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Challenge Completed'), findsNothing);

      final celebratedAt = store.active!.celebratedAt;
      final restarted = ChallengeStore(clock: () => after);
      await tester.runAsync(restarted.load);
      expect(restarted.active!.results[1], DailyResult.missed);
      await tester.pumpWidget(const SizedBox());
      await openShell(tester, restarted, after);
      expect(restarted.active!.celebratedAt, celebratedAt);
      expect(find.byType(CompletionScreen), findsOneWidget);
      expect(find.text('5 / 7 days'), findsOneWidget);
      expect(find.text('View Your Sticker'), findsOneWidget);
    });
  });
}
