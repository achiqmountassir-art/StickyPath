// ignore_for_file: file_names

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../progress/custom_task.dart';
import '../theme/app_colors.dart';

enum DailyResult { completed, missed }

typedef RemovalResult = DailyResult;

class DailyTask {
  final String id;
  final String text;
  final bool completed;

  const DailyTask({
    required this.id,
    required this.text,
    this.completed = false,
  });

  DailyTask copyWith({bool? completed}) {
    return DailyTask(
      id: id,
      text: text,
      completed: completed ?? this.completed,
    );
  }
}

class Challenge {
  final String id;
  final int totalDays;
  final DateTime startDate;
  final int currentDay;

  const Challenge({
    required this.id,
    required this.totalDays,
    required this.startDate,
    required this.currentDay,
  });

  DateTime dateForDay(int day) =>
      DateTime(startDate.year, startDate.month, startDate.day + totalDays - day);

  Challenge copyWith({int? currentDay}) {
    return Challenge(
      id: id,
      totalDays: totalDays,
      startDate: startDate,
      currentDay: currentDay ?? this.currentDay,
    );
  }
}

abstract class ChallengeRepository {
  Future<void> saveDailyResult({
    required String challengeId,
    required int dayNumber,
    required DailyResult result,
  });

  Future<void> saveTaskState({
    required String challengeId,
    required int dayNumber,
    required DailyTask task,
  });

  Future<void> clearDailyResult({
    required String challengeId,
    required int dayNumber,
  });
}

class LocalChallengeRepository implements ChallengeRepository {
  final Map<int, DailyResult> results = {};
  final Map<String, bool> taskStates = {};

  @override
  Future<void> saveDailyResult({
    required String challengeId,
    required int dayNumber,
    required DailyResult result,
  }) async {
    results[dayNumber] = result;
  }

  @override
  Future<void> saveTaskState({
    required String challengeId,
    required int dayNumber,
    required DailyTask task,
  }) async {
    taskStates['$dayNumber/${task.id}'] = task.completed;
  }

  @override
  Future<void> clearDailyResult({
    required String challengeId,
    required int dayNumber,
  }) async {
    results.remove(dayNumber);
  }
}

/// Home stores notes counting down from [totalDays]; people read them counting
/// up, so the note on the start date is day 1.
int challengeDayLabel(int dayNumber, int totalDays) =>
    totalDays - dayNumber + 1;

const List<Color> stickyPalette = [
  Color(0xFFFFE27A),
  Color(0xFFFFB5CC),
  Color(0xFFAEDCFF),
  Color(0xFFC5EDA8),
];

/// Colors stay the same for 7 days, then rotate to the next color in the
/// palette for the next 7 days.
Color stickyColorFor(int dayNumber, int totalDays) {
  final dayIndex = totalDays - dayNumber;
  final weekIndex = dayIndex ~/ 7;
  return stickyPalette[weekIndex % stickyPalette.length];
}

const Color _ink = Color(0xFF26221C);

class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    required this.totalDays,
    required this.goals,
    DateTime? startDate,
    int? currentDay,
    ChallengeRepository? repository,
    this.challengeId,
    this.initialTaskStates = const {},
    this.initialResults = const {},
    this.customTasks = const [],
    this.onCustomTaskToggled,
    this.completedDays,
    this.completedBuilder,
    this.isDayAvailable,
  }) : assert(totalDays > 0),
       startDate = startDate ?? DateTime.now(),
       currentDay = currentDay ?? totalDays,
       repository = repository ?? LocalChallengeRepository();

  final int totalDays;
  final List<String> goals;
  final DateTime startDate;
  final int currentDay;
  final ChallengeRepository repository;
  final String? challengeId;

  /// Custom tasks for the whole challenge; filtered per sticky note by day.
  final List<CustomTask> customTasks;

  /// Toggle completion for a custom task on an available day.
  final void Function(CustomTask task)? onCustomTaskToggled;

  /// Completed challenge days from the shared progress calculator. Without it,
  /// Home counts saved completed results locally.
  final ValueListenable<int>? completedDays;

  /// Replaces the built-in "Challenge complete" view once every note is
  /// swiped.
  final WidgetBuilder? completedBuilder;

  /// Whether a note's date has arrived. Defaults to the device date.
  final bool Function(int dayNumber)? isDayAvailable;

  /// Saved checkbox states by day number, then task id.
  final Map<int, Map<String, bool>> initialTaskStates;

  /// Saved swipe results by day number.
  final Map<int, DailyResult> initialResults;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Challenge _challenge;
  final Map<int, List<DailyTask>> _tasksByDay = {};
  final Map<int, DailyResult> _results = {};
  final _dragProgress = ValueNotifier<double>(0);
  GlobalKey<PhysicalDayCardState> _currentKey = GlobalKey();
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _challenge = Challenge(
      id: widget.challengeId ?? 'local-${widget.startDate.millisecondsSinceEpoch}',
      totalDays: widget.totalDays,
      startDate: widget.startDate,
      currentDay: widget.currentDay.clamp(1, widget.totalDays),
    );
    _results.addAll(widget.initialResults);
    _isComplete = _results.containsKey(1);
  }

  /// Picks up results saved outside a swipe, such as past days closed as
  /// missed.
  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.goals, widget.goals)) {
      _tasksByDay.clear();
    }
    final added = {
      for (final entry in widget.initialResults.entries)
        if (!_results.containsKey(entry.key)) entry.key: entry.value,
    };
    if (added.isEmpty) return;
    _results.addAll(added);
    _isComplete = _results.containsKey(1);
    final current = widget.currentDay.clamp(1, widget.totalDays);
    if (current < _challenge.currentDay) {
      _challenge = _challenge.copyWith(currentDay: current);
      _currentKey = GlobalKey();
      _dragProgress.value = 0;
    }
  }

  @override
  void dispose() {
    _dragProgress.dispose();
    super.dispose();
  }

  List<DailyTask> _tasksFor(int day) {
    return _tasksByDay.putIfAbsent(
      day,
      () => [
        for (var i = 0; i < widget.goals.length; i++)
          DailyTask(
            id: 'goal-$i',
            text: widget.goals[i],
            completed: widget.initialTaskStates[day]?['goal-$i'] ?? false,
          ),
      ],
    );
  }

  List<CustomTask> _customTasksFor(int day) => [
    for (final task in widget.customTasks)
      if (task.dayNumber == day) task,
  ];

  void _toggleTask(int day, DailyTask task) {
    final updated = task.copyWith(completed: !task.completed);
    setState(() {
      _tasksByDay[day] = [
        for (final t in _tasksFor(day)) t.id == task.id ? updated : t,
      ];
    });
    unawaited(
      _persist(
        () => widget.repository.saveTaskState(
          challengeId: _challenge.id,
          dayNumber: day,
          task: updated,
        ),
      ),
    );
  }

  bool _isAvailable(int day) {
    final check = widget.isDayAvailable;
    if (check != null) return check(day);
    final now = DateTime.now();
    return !_challenge
        .dateForDay(day)
        .isAfter(DateTime(now.year, now.month, day));
  }

  void _showLocked(int day) {
    final date = _challenge.dateForDay(day);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Day ${challengeDayLabel(day, _challenge.totalDays)} unlocks on '
            '${_CardContent._months[date.month - 1]} ${date.day}.',
            style: AppFonts.sansStyle(size: 14),
          ),
          backgroundColor: const Color(0xFF1A1B21),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showUndo(int day, DailyResult result) {
    final label = challengeDayLabel(day, _challenge.totalDays);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Day $label marked '
            '${result == DailyResult.completed ? 'completed' : 'missed'}',
            style: AppFonts.sansStyle(size: 14),
          ),
          backgroundColor: const Color(0xFF1A1B21),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.pink,
            onPressed: () => _undo(day),
          ),
        ),
      );
  }

  /// Puts back the most recently swiped note.
  void _undo(int day) {
    if (!mounted ||
        _isComplete ||
        day != _challenge.currentDay + 1 ||
        !_results.containsKey(day)) {
      return;
    }
    _results.remove(day);
    unawaited(
      _persist(
        () => widget.repository.clearDailyResult(
          challengeId: _challenge.id,
          dayNumber: day,
        ),
      ),
    );
    setState(() {
      _challenge = _challenge.copyWith(currentDay: day);
      _currentKey = GlobalKey();
    });
    _dragProgress.value = 0;
  }

  void _handleRemoved(int day, DailyResult result) {
    if (_isComplete ||
        day != _challenge.currentDay ||
        _results.containsKey(day) ||
        !_isAvailable(day)) {
      return;
    }
    _results[day] = result;
    unawaited(
      _persist(
        () => widget.repository.saveDailyResult(
          challengeId: _challenge.id,
          dayNumber: day,
          result: result,
        ),
      ),
    );
    setState(() {
      if (day <= 1) {
        _isComplete = true;
      } else {
        _challenge = _challenge.copyWith(currentDay: day - 1);
        _currentKey = GlobalKey();
      }
    });
    _dragProgress.value = 0;
    if (day > 1) _showUndo(day, result);
  }

  Future<void> _persist(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      debugPrint('Sticky Path persistence failed: $error');
    }
  }

  Future<void> _showRemoveOptions() async {
    final result = await showModalBottomSheet<DailyResult>(
      context: context,
      backgroundColor: const Color(0xFF15161B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.arrow_forward_rounded),
                title: Text(
                  'Completed',
                  style: AppFonts.sansStyle(size: 16, weight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(context, DailyResult.completed),
              ),
              ListTile(
                leading: const Icon(Icons.arrow_back_rounded),
                title: Text(
                  'Missed',
                  style: AppFonts.sansStyle(size: 16, weight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(context, DailyResult.missed),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) _currentKey.currentState?.remove(result);
  }

  void _onRemovePressed() {
    final day = _challenge.currentDay;
    if (!_isAvailable(day)) {
      _showLocked(day);
      return;
    }
    _showRemoveOptions();
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.completedBuilder;
    if (_isComplete && completed != null) return completed(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.ink,
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/image4.png', fit: BoxFit.cover),
            ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            SafeArea(child: _isComplete ? _buildComplete() : _buildChallenge()),
          ],
        ),
      ),
    );
  }

  Widget _buildChallenge() {
    final total = _challenge.totalDays;
    final current = _challenge.currentDay;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'DAY ${challengeDayLabel(current, total)} OF $total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.sansStyle(
                        size: 15,
                        weight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _completedCount(
                    (count) => Text(
                      '$count completed',
                      style: AppFonts.sansStyle(
                        size: 13,
                        color: AppColors.mutedWhite,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (total - current) / total,
                  minHeight: 4,
                  color: AppColors.pink,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.sizeOf(context).height;
              final width = math.min(
                constraints.maxWidth * 0.88,
                constraints.maxHeight * 0.92 * 0.66,
              );
              final height = math.min(
                math.min(constraints.maxHeight * 0.92, screenHeight * 0.7),
                width / 0.66,
              );
              final nextDay = current - 1;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (nextDay >= 1)
                    RepaintBoundary(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _dragProgress,
                        builder: (context, progress, child) => Transform.scale(
                          scale: 0.96 + 0.04 * progress,
                          child: child,
                        ),
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: SizedBox(
                              width: width,
                              height: height,
                              child: PhysicalDayCard(
                                key: ValueKey('next-$nextDay'),
                                dayNumber: nextDay,
                                totalDays: total,
                                date: _challenge.dateForDay(nextDay),
                                tasks: _tasksFor(nextDay),
                                customTasks: _customTasksFor(nextDay),
                                isCurrentDay: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: width,
                    height: height,
                    child: PhysicalDayCard(
                      key: _currentKey,
                      dayNumber: current,
                      totalDays: total,
                      date: _challenge.dateForDay(current),
                      tasks: _tasksFor(current),
                      customTasks: _customTasksFor(current),
                      isCurrentDay: true,
                      locked: !_isAvailable(current),
                      onLockedAttempt: () => _showLocked(current),
                      dragProgress: _dragProgress,
                      onTaskToggled: (task) => _toggleTask(current, task),
                      onCustomTaskToggled: !_isAvailable(current)
                          ? null
                          : widget.onCustomTaskToggled,
                      onRemovedWithResult: (result) =>
                          _handleRemoved(current, result),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: TextButton.icon(
            onPressed: _onRemovePressed,
            icon: const Icon(Icons.swipe_rounded, size: 18),
            label: Text(
              'Remove day',
              style: AppFonts.sansStyle(size: 14, weight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.softWhite),
          ),
        ),
      ],
    );
  }

  Widget _completedCount(Widget Function(int count) builder) {
    final shared = widget.completedDays;
    if (shared == null) {
      return builder(
        _results.values.where((r) => r == DailyResult.completed).length,
      );
    }
    return ValueListenableBuilder<int>(
      valueListenable: shared,
      builder: (context, count, _) => builder(count),
    );
  }

  Widget _buildComplete() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Challenge complete',
            textAlign: TextAlign.center,
            style: AppFonts.sansStyle(
              size: 34,
              weight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          _completedCount(
            (count) => Text(
              '$count of ${_challenge.totalDays} days completed',
              style: AppFonts.sansStyle(size: 16, color: AppColors.mutedWhite),
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pink,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                'Done',
                style: AppFonts.sansStyle(
                  size: 17,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PhysicalDayCard extends StatefulWidget {
  final int dayNumber;
  final int totalDays;
  final DateTime date;
  final List<DailyTask> tasks;
  final List<CustomTask> customTasks;
  final bool isCurrentDay;
  final VoidCallback? onRemoved;
  final void Function(RemovalResult result)? onRemovedWithResult;
  final void Function(DailyTask task)? onTaskToggled;
  final void Function(CustomTask task)? onCustomTaskToggled;
  final ValueNotifier<double>? dragProgress;
  final double? swipeThreshold;

  /// A note whose date has not arrived returns to the wall when swiped.
  final bool locked;
  final VoidCallback? onLockedAttempt;

  const PhysicalDayCard({
    super.key,
    required this.dayNumber,
    required this.totalDays,
    required this.date,
    required this.tasks,
    this.customTasks = const [],
    required this.isCurrentDay,
    this.locked = false,
    this.onLockedAttempt,
    this.onRemoved,
    this.onRemovedWithResult,
    this.onTaskToggled,
    this.onCustomTaskToggled,
    this.dragProgress,
    this.swipeThreshold,
  });

  @override
  State<PhysicalDayCard> createState() => PhysicalDayCardState();
}

class PhysicalDayCardState extends State<PhysicalDayCard>
    with SingleTickerProviderStateMixin {
  static const _maxVertical = 18.0;
  static const _maxRotation = 0.17;

  final _offset = ValueNotifier<Offset>(Offset.zero);
  late final AnimationController _controller;
  late final List<double> _jitter;
  late final double _restRotation;
  Animation<Offset>? _animation;
  Offset _dragStartGlobal = Offset.zero;
  Offset _dragStartOffset = Offset.zero;
  double _screenWidth = 390;
  bool _isRemoving = false;
  bool _reported = false;
  DailyResult? _pendingResult;

  /// Easier swipe distance while testing; raise toward 0.35 for shipping.
  double get _threshold => widget.swipeThreshold ?? _screenWidth * 0.18;

  @override
  void initState() {
    super.initState();
    final random = math.Random(widget.dayNumber * 7919 + widget.totalDays);
    _jitter = List.generate(11, (_) => random.nextDouble() * 2 - 1);
    _restRotation = (random.nextDouble() * 2 - 1) * 0.012;
    _controller = AnimationController(vsync: this)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.sizeOf(context).width;
  }

  @override
  void dispose() {
    _controller.dispose();
    _offset.dispose();
    super.dispose();
  }

  void remove(DailyResult result) {
    if (!widget.isCurrentDay || _isRemoving) return;
    if (widget.locked) {
      widget.onLockedAttempt?.call();
      return;
    }
    _flyOut(result);
  }

  void _setOffset(Offset value) {
    _offset.value = value;
    widget.dragProgress?.value = (value.dx.abs() / _threshold).clamp(0.0, 1.0);
  }

  void _onTick() {
    final animation = _animation;
    if (animation != null) _setOffset(animation.value);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final result = _pendingResult;
    if (!_isRemoving || result == null || _reported) return;
    _reported = true;
    HapticFeedback.lightImpact();
    widget.onRemovedWithResult?.call(result);
    widget.onRemoved?.call();
  }

  double _resist(double x) {
    final a = x.abs();
    return x.sign * a * (0.5 + 0.5 * math.min(1.0, a / 80));
  }

  void _onDragStart(DragStartDetails details) {
    if (_isRemoving) return;
    _controller.stop();
    _animation = null;
    _dragStartGlobal = details.globalPosition;
    _dragStartOffset = _offset.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isRemoving) return;
    final delta = details.globalPosition - _dragStartGlobal;
    final dx = _dragStartOffset.dx + _resist(delta.dx);
    final dy = (_dragStartOffset.dy + delta.dy * 0.25).clamp(
      -_maxVertical,
      _maxVertical,
    );
    _setOffset(Offset(dx, dy));
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isRemoving) return;
    final dx = _offset.value.dx;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final flung =
        velocity.abs() > 900 &&
        dx.abs() > _threshold * 0.3 &&
        velocity.sign == dx.sign;
    if ((dx.abs() >= _threshold || flung) && widget.locked) {
      widget.onLockedAttempt?.call();
      _returnToWall();
    } else if (dx.abs() >= _threshold || flung) {
      _flyOut(
        dx > 0 ? DailyResult.completed : DailyResult.missed,
        velocity: velocity,
      );
    } else {
      _returnToWall();
    }
  }

  void _returnToWall() {
    if (_isRemoving) return;
    _animation = Tween<Offset>(
      begin: _offset.value,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller
      ..duration = const Duration(milliseconds: 460)
      ..forward(from: 0);
  }

  void _flyOut(DailyResult result, {double velocity = 0}) {
    _isRemoving = true;
    _pendingResult = result;
    final sign = result == DailyResult.completed ? 1.0 : -1.0;
    final start = _offset.value;
    final fast = velocity.abs() > 600;
    _animation =
        Tween<Offset>(
          begin: start,
          end: Offset(sign * _screenWidth * 1.3, start.dy - 36),
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: fast ? Curves.easeOutQuad : Curves.easeInQuad,
          ),
        );
    _controller
      ..duration = Duration(
        milliseconds: (420 - velocity.abs() * 0.06).clamp(240, 420).round(),
      )
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final color = stickyColorFor(widget.dayNumber, widget.totalDays);

    final face = Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: RepaintBoundary(child: CustomPaint(painter: _GrainPainter())),
        ),
        RepaintBoundary(
          child: _CardContent(
            dayNumber: widget.dayNumber,
            totalDays: widget.totalDays,
            date: widget.date,
            tasks: widget.tasks,
            customTasks: widget.customTasks,
            onToggle: widget.isCurrentDay ? widget.onTaskToggled : null,
            onCustomToggle:
                widget.isCurrentDay ? widget.onCustomTaskToggled : null,
          ),
        ),
      ],
    );

    Widget card = ValueListenableBuilder<Offset>(
      valueListenable: _offset,
      child: face,
      builder: (context, offset, child) {
        final progress = (offset.dx.abs() / _threshold).clamp(0.0, 1.0);
        final lift = Curves.easeIn.transform(progress);
        final direction = offset.dx == 0 ? 0.0 : offset.dx.sign;
        final rotation =
            _restRotation +
            (offset.dx / _screenWidth * 0.3).clamp(-_maxRotation, _maxRotation);

        return Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: 1 + 0.035 * lift,
              child: Transform(
                alignment: direction > 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(direction * 0.18 * lift),
                child: CustomPaint(
                  painter: _PaperPainter(
                    color: color,
                    jitter: _jitter,
                    lift: lift,
                    direction: direction,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!widget.isCurrentDay) return card;

    card = GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _returnToWall,
      child: card,
    );

    return Semantics(
      container: true,
      label:
          'Day ${challengeDayLabel(widget.dayNumber, widget.totalDays)} '
          'of ${widget.totalDays}. '
          'Swipe right if completed, left if missed.',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Mark day completed'): () =>
            remove(DailyResult.completed),
        const CustomSemanticsAction(label: 'Mark day missed'): () =>
            remove(DailyResult.missed),
      },
      child: card,
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.dayNumber,
    required this.totalDays,
    required this.date,
    required this.tasks,
    required this.onToggle,
    this.customTasks = const [],
    this.onCustomToggle,
  });

  final int dayNumber;
  final int totalDays;
  final DateTime date;
  final List<DailyTask> tasks;
  final List<CustomTask> customTasks;
  final void Function(DailyTask task)? onToggle;
  final void Function(CustomTask task)? onCustomToggle;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = (constraints.maxWidth / 340).clamp(0.75, 1.3);

        return Padding(
          padding: EdgeInsets.fromLTRB(26 * s, 30 * s, 22 * s, 22 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'DAY ${challengeDayLabel(dayNumber, totalDays)}',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppFonts.brush,
                        fontSize: 44 * s,
                        height: 1,
                        color: _ink,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 6 * s),
                    child: Text(
                      '${_months[date.month - 1]} ${date.day}',
                      style: AppFonts.sansStyle(
                        size: 12 * s,
                        weight: FontWeight.w700,
                        color: _ink.withValues(alpha: 0.55),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4 * s),
              Text(
                'of $totalDays',
                style: TextStyle(
                  fontFamily: AppFonts.brush,
                  fontSize: 16 * s,
                  color: _ink.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: 20 * s),
              Expanded(
                child: tasks.isEmpty && customTasks.isEmpty
                    ? Text(
                        'No goals for today',
                        style: AppFonts.sansStyle(
                          size: 16 * s,
                          color: _ink.withValues(alpha: 0.6),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        children: [
                          for (var i = 0; i < tasks.length; i++) ...[
                            if (i > 0) SizedBox(height: 14 * s),
                            Builder(
                              builder: (context) {
                                final task = tasks[i];
                                final toggle = onToggle;
                                return _TaskRow(
                                  key: ValueKey(task.id),
                                  task: task,
                                  scale: s,
                                  onTap: toggle == null
                                      ? null
                                      : () {
                                          HapticFeedback.selectionClick();
                                          toggle(task);
                                        },
                                );
                              },
                            ),
                          ],
                          if (customTasks.isNotEmpty) ...[
                            if (tasks.isNotEmpty) SizedBox(height: 16 * s),
                            Text(
                              'TASKS',
                              style: AppFonts.sansStyle(
                                size: 11 * s,
                                weight: FontWeight.w700,
                                color: _ink.withValues(alpha: 0.45),
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 10 * s),
                            for (var i = 0; i < customTasks.length; i++) ...[
                              if (i > 0) SizedBox(height: 12 * s),
                              _CustomTaskRow(
                                task: customTasks[i],
                                scale: s,
                                onTap: onCustomToggle == null
                                    ? null
                                    : () {
                                        HapticFeedback.selectionClick();
                                        onCustomToggle!(customTasks[i]);
                                      },
                              ),
                            ],
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskRow extends StatefulWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.scale,
    this.onTap,
  });

  final DailyTask task;
  final double scale;
  final VoidCallback? onTap;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow>
    with SingleTickerProviderStateMixin {
  static const _fillDuration = Duration(milliseconds: 380);
  static final _fillColor = AppColors.pink.withValues(alpha: 0.28);

  late final AnimationController _fillController;
  late final Animation<double> _fill;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: _fillDuration,
      value: widget.task.completed ? 1.0 : 0.0,
    );
    _fill = CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _TaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _fillController.value = widget.task.completed ? 1.0 : 0.0;
      return;
    }
    if (oldWidget.task.completed == widget.task.completed) return;
    if (widget.task.completed) {
      _fillController.forward();
    } else {
      _fillController.reverse();
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final task = widget.task;
    return MergeSemantics(
      child: Semantics(
        checked: task.completed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8 * s),
            child: AnimatedBuilder(
              animation: _fill,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _fill.value,
                          heightFactor: 1,
                          child: ColoredBox(color: _fillColor),
                        ),
                      ),
                    ),
                    child!,
                  ],
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 24 * s,
                    height: 24 * s,
                    decoration: BoxDecoration(
                      color: task.completed
                          ? _ink.withValues(alpha: 0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4 * s),
                      border: Border.all(
                        color: _ink.withValues(alpha: 0.8),
                        width: 2,
                      ),
                    ),
                    child: task.completed
                        ? Icon(
                            Icons.check_rounded,
                            size: 20 * s,
                            color: _ink,
                          )
                        : null,
                  ),
                  SizedBox(width: 12 * s),
                  Expanded(
                    child: Text(
                      task.text,
                      style: AppFonts.sansStyle(
                        size: 17 * s,
                        weight: FontWeight.w600,
                        height: 1.3,
                        color: _ink.withValues(
                          alpha: task.completed ? 0.72 : 0.92,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomTaskRow extends StatelessWidget {
  const _CustomTaskRow({required this.task, required this.scale, this.onTap});

  final CustomTask task;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final reminder = task.reminderMinutes;
    return MergeSemantics(
      child: Semantics(
        checked: task.completed,
        label: reminder == null
            ? task.title
            : '${task.title}, reminder ${formatReminderMinutes(reminder)}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24 * s,
                height: 24 * s,
                decoration: BoxDecoration(
                  color: task.completed
                      ? _ink.withValues(alpha: 0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12 * s),
                  border: Border.all(
                    color: _ink.withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
                child: task.completed
                    ? Icon(Icons.check_rounded, size: 18 * s, color: _ink)
                    : null,
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AppFonts.sansStyle(
                        size: 16 * s,
                        weight: FontWeight.w600,
                        height: 1.3,
                        color: _ink.withValues(
                          alpha: task.completed ? 0.55 : 0.9,
                        ),
                      ),
                    ),
                    if (reminder != null) ...[
                      SizedBox(height: 2 * s),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 13 * s,
                            color: _ink.withValues(alpha: 0.5),
                          ),
                          SizedBox(width: 4 * s),
                          Text(
                            formatReminderMinutes(reminder),
                            style: AppFonts.sansStyle(
                              size: 12 * s,
                              weight: FontWeight.w600,
                              color: _ink.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  _PaperPainter({
    required this.color,
    required this.jitter,
    required this.lift,
    required this.direction,
  });

  final Color color;
  final List<double> jitter;
  final double lift;
  final double direction;

  Path _paperPath(Size size) {
    final w = size.width;
    final h = size.height;
    final j = jitter;
    final e = math.min(w, h) * 0.004;
    final bend = w * 0.03 * lift;
    final cornerLift = h * 0.012 * lift;
    final rightBend = direction > 0 ? bend : 0.0;
    final leftBend = direction < 0 ? bend : 0.0;
    final topRightLift = direction > 0 ? cornerLift : 0.0;
    final topLeftLift = direction < 0 ? cornerLift : 0.0;
    final start = Offset(j[0] * e - leftBend * 0.4, j[1] * e - topLeftLift);

    return Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        w * 0.5,
        j[2] * e,
        w + j[3] * e + rightBend * 0.4,
        -topRightLift,
      )
      ..quadraticBezierTo(
        w + rightBend + j[4] * e,
        h * 0.5,
        w + j[5] * e,
        h + j[6] * e,
      )
      ..quadraticBezierTo(w * 0.5, h + j[7] * e, j[8] * e, h + j[9] * e)
      ..quadraticBezierTo(-leftBend + j[10] * e, h * 0.5, start.dx, start.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _paperPath(size);
    final rect = Offset.zero & size;

    canvas.drawPath(
      path.shift(Offset(direction * 5 * lift, 3 + 10 * lift)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.26 + 0.14 * lift)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 10 * lift),
    );
    canvas.drawPath(
      path.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18 * (1 - lift))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawPath(path, Paint()..color = color);

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.05),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.04),
          ],
          stops: const [0, 0.16, 1],
        ).createShader(rect),
    );
    if (lift > 0 && direction != 0) {
      final lead = direction > 0 ? Alignment.centerRight : Alignment.centerLeft;
      final stuck = direction > 0
          ? Alignment.centerLeft
          : Alignment.centerRight;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: stuck,
            end: lead,
            colors: [
              Colors.black.withValues(alpha: 0.10 * lift),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.22 * lift),
            ],
            stops: const [0, 0.4, 1],
          ).createShader(rect),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaperPainter old) {
    return old.lift != lift ||
        old.direction != direction ||
        old.color != color ||
        old.jitter != jitter;
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final count = (size.width * size.height / 90).clamp(0, 5000).toInt();
    final dark = <Offset>[];
    final light = <Offset>[];
    for (var i = 0; i < count; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      (i.isEven ? dark : light).add(point);
    }
    canvas.drawPoints(
      ui.PointMode.points,
      dark,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.05)
        ..strokeWidth = 1,
    );
    canvas.drawPoints(
      ui.PointMode.points,
      light,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
