import 'challenge_progress.dart';
import 'challenge_store.dart';
import 'progress_logic.dart';

/// Achievement numbers for a finished challenge, taken from the same
/// [evaluateProgress] result the Progress screen shows.
class ChallengeSummary {
  const ChallengeSummary({
    required this.challengeId,
    required this.totalDays,
    required this.startDate,
    required this.endDate,
    required this.completedDays,
    required this.missedDays,
    required this.partialDays,
    required this.streak,
  });

  factory ChallengeSummary.of(ActiveChallenge challenge, DateTime today) {
    final view = evaluateProgress(challenge.progress(today));
    int count(Set<ProgressDayStatus> statuses) =>
        view.days.where((day) => statuses.contains(day.status)).length;

    return ChallengeSummary(
      challengeId: challenge.id,
      totalDays: view.totalDays,
      startDate: challenge.startDate,
      endDate: challengeEndDate(challenge),
      completedDays: view.completedDays,
      missedDays: count({
        ProgressDayStatus.missed,
        ProgressDayStatus.noActivity,
      }),
      partialDays: count({ProgressDayStatus.partial}),
      streak: view.streak,
    );
  }

  final String challengeId;
  final int totalDays;
  final DateTime startDate;
  final DateTime endDate;
  final int completedDays;

  /// Days swiped left or past days with nothing checked.
  final int missedDays;

  /// Past days with only some habits checked; neither completed nor missed.
  final int partialDays;
  final int streak;

  String get title => '$totalDays-Day Challenge';
}

DateTime challengeEndDate(ActiveChallenge challenge) =>
    addCalendarDays(challenge.startDate, challenge.totalDays - 1);

/// True once every sticky note on Home has been swiped.
bool isDeckFinished(ActiveChallenge challenge) =>
    challenge.totalDays > 0 &&
    List.generate(
      challenge.totalDays,
      (index) => index + 1,
    ).every(challenge.results.containsKey);

/// A challenge is finished when every sticky note has been swiped (the last
/// note, day 1, closes the deck), or once the calendar has passed its last
/// date and every day has a final status. Checking habits alone never
/// finishes it.
bool isChallengeComplete(ActiveChallenge challenge, DateTime today) {
  if (challenge.totalDays <= 0) return false;
  final now = dateOnly(today);
  if (challenge.startDate.isAfter(now)) return false;

  if (isDeckFinished(challenge)) return true;

  if (now.isBefore(challengeEndDate(challenge))) return false;

  final view = evaluateProgress(challenge.progress(now));
  return view.days.length == challenge.totalDays &&
      view.days.every(
        (day) =>
            day.status != ProgressDayStatus.pending &&
            day.status != ProgressDayStatus.future,
      );
}
