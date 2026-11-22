/// A one-off task pinned to a challenge day, separate from daily habits.
class CustomTask {
  const CustomTask({
    required this.id,
    required this.title,
    required this.dayNumber,
    required this.notificationId,
    this.reminderMinutes,
    this.repeat = CustomTaskRepeat.none,
    this.completed = false,
  });

  final String id;
  final String title;

  /// Home's countdown day number (matches sticky-note [dayNumber]).
  final int dayNumber;

  /// Minutes from local midnight. Null means no reminder.
  final int? reminderMinutes;

  final CustomTaskRepeat repeat;
  final bool completed;

  /// Stable id for [flutter_local_notifications]; unique per task.
  final int notificationId;

  bool get hasReminder => reminderMinutes != null;

  CustomTask copyWith({
    String? title,
    int? dayNumber,
    int? reminderMinutes,
    bool clearReminder = false,
    CustomTaskRepeat? repeat,
    bool? completed,
  }) {
    return CustomTask(
      id: id,
      title: title ?? this.title,
      dayNumber: dayNumber ?? this.dayNumber,
      reminderMinutes: clearReminder
          ? null
          : (reminderMinutes ?? this.reminderMinutes),
      repeat: repeat ?? this.repeat,
      completed: completed ?? this.completed,
      notificationId: notificationId,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'dayNumber': dayNumber,
    'reminderMinutes': reminderMinutes,
    'repeat': repeat.name,
    'completed': completed,
    'notificationId': notificationId,
  };

  static CustomTask fromJson(Map<String, dynamic> json) {
    final repeatName = json['repeat'] as String? ?? 'none';
    return CustomTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      dayNumber: json['dayNumber'] as int? ?? 1,
      reminderMinutes: json['reminderMinutes'] as int?,
      repeat: CustomTaskRepeat.values.firstWhere(
        (value) => value.name == repeatName,
        orElse: () => CustomTaskRepeat.none,
      ),
      completed: json['completed'] as bool? ?? false,
      notificationId: json['notificationId'] as int? ??
          _fallbackNotificationId(json['id'] as String? ?? ''),
    );
  }

  static int _fallbackNotificationId(String id) {
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = 0x1fffffff & (hash + code);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash == 0 ? 1 : hash;
  }
}

enum CustomTaskRepeat { none }

/// Formats reminder minutes as a short local time, e.g. "10:00 AM".
String formatReminderMinutes(int minutes) {
  final hour24 = (minutes ~/ 60).clamp(0, 23);
  final minute = (minutes % 60).clamp(0, 59);
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final mm = minute.toString().padLeft(2, '0');
  return '$hour12:$mm $period';
}
