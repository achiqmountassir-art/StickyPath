import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress/challenge_completion.dart';
import '../progress/challenge_store.dart';
import '../theme/app_colors.dart';
import 'Home_screen.dart';
import 'completion_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.store, this.initialIndex = 0, this.clock});

  /// Defaults to [ChallengeStore.instance].
  final ChallengeStore? store;
  final int initialIndex;

  /// Overrides the current time, for tests.
  final DateTime Function()? clock;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late int _index = widget.initialIndex;
  late final ChallengeStore _store = widget.store ?? ChallengeStore.instance;
  late final DateTime Function() _clock = widget.clock ?? _store.now;
  late final CompletedDaysListenable _completedDays = CompletedDaysListenable(
    _store,
    clock: _clock,
  );
  bool _celebrating = false;

  /// The ceremony was seen in an earlier session, so it shows without its
  /// entrance animation.
  late final bool _seenBefore = _store.active?.celebratedAt != null;

  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_checkCompletion);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCompletion());
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The date may have changed while the app was in the background.
    _onNewDay();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      _onNewDay();
      _scheduleMidnight();
    });
  }

  void _onNewDay() {
    if (!mounted) return;
    setState(() {});
    unawaited(_store.closePastDays());
    _checkCompletion();
  }

  /// Shows the ceremony once per challenge, after its last date is resolved.
  Future<void> _checkCompletion() async {
    final challenge = _store.active;
    if (_celebrating ||
        !mounted ||
        challenge == null ||
        challenge.celebratedAt != null) {
      return;
    }
    final now = _clock();
    if (!isChallengeComplete(challenge, now)) return;

    _celebrating = true;
    final summary = ChallengeSummary.of(challenge, now);
    // A finished deck shows the ceremony in place on Home; only record it.
    final inline = isDeckFinished(challenge);
    if (!await _store.markCelebrated(challenge.id, at: now) ||
        !mounted ||
        inline) {
      _celebrating = false;
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CompletionScreen(summary: summary),
      ),
    );
    _celebrating = false;
  }
  List<Widget> _pages() => [
    _buildHome(),
    ProgressScreen(store: _store, today: widget.clock?.call(), showBackButton: false),
    const SettingsScreen(),
  ];

  Widget _buildHome() {
    final challenge = _store.active;
    if (challenge == null || challenge.totalDays <= 0) {
      return const SettingsScreen();
    }
    return HomeScreen(
      key: ValueKey(challenge.id),
      totalDays: challenge.totalDays,
      goals: challenge.habits,
      startDate: challenge.startDate,
      currentDay: challenge.homeCurrentDay,
      challengeId: challenge.id,
      repository: StoreChallengeRepository(_store),
      initialTaskStates: {
        for (final day in challenge.taskStates.entries)
          day.key: Map.of(day.value),
      },
      initialResults: Map.of(challenge.results),
      customTasks: List.of(challenge.customTasks),
      onCustomTaskToggled: (task) {
        unawaited(
          _store.setCustomTaskCompleted(task.id, !task.completed),
        );
      },
      completedDays: _completedDays,
      isDayAvailable: (day) =>
          _store.active?.isDayAvailable(day, _clock()) ?? false,
      completedBuilder: (context) {
        final current = _store.active;
        if (current == null) return const SizedBox.shrink();
        return CompletionScreen(
          summary: ChallengeSummary.of(current, _clock()),
          animate: !_seenBefore,
          onContinue: () => _select(1),
        );
      },
    );
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_checkCompletion);
    _completedDays.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      extendBody: true,
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) =>
            IndexedStack(index: _index, children: _pages()),
      ),
      bottomNavigationBar: _BottomNav(index: _index, onChanged: _select),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.insights_rounded, 'Progress'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0F13).withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: Color(0xFF2A2E38))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: _items[i].$2,
                    child: InkResponse(
                      onTap: () => onChanged(i),
                      radius: 36,
                      child: _NavItem(
                        icon: _items[i].$1,
                        label: _items[i].$2,
                        selected: i == index,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.pink : AppColors.mutedWhite;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.pink.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppFonts.sansStyle(
            size: 11,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
