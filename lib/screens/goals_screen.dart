import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import 'habits_screen.dart';

class Goal {
  final String title;
  final IconData icon;
  final bool isCustom;
  bool isSelected;

  Goal({
    required this.title,
    required this.icon,
    this.isCustom = false,
    this.isSelected = false,
  });
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key, int selectedDuration = 0, int durationDays = 0})
    : assert(
        selectedDuration > 0 || durationDays > 0,
        'A challenge duration is required.',
      ),
      selectedDuration = selectedDuration > 0 ? selectedDuration : durationDays;

  final int selectedDuration;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  static const _animationDuration = Duration(milliseconds: 220);

  final _customGoalController = TextEditingController();
  final _customGoalFocusNode = FocusNode();

  static const _draftKey = 'sticky_path.goals_draft';

  final List<Goal> _goals = [
    Goal(title: 'Build muscle', icon: Icons.fitness_center_rounded),
    Goal(title: 'Learn a new skill', icon: Icons.lightbulb_outline_rounded),
    Goal(title: 'Read more', icon: Icons.menu_book_rounded),
    Goal(title: 'Be healthier', icon: Icons.favorite_border_rounded),
    Goal(title: 'Build a business', icon: Icons.storefront_outlined),
  ];

  bool _isInputFocused = false;

  @override
  void initState() {
    super.initState();
    _customGoalFocusNode.addListener(_updateInputFocus);
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || !mounted) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final selected = Set<String>.from(json['selected'] as List? ?? const []);
      final custom = List<String>.from(json['custom'] as List? ?? const []);
      setState(() {
        for (final title in custom) {
          if (_goals.every((goal) => goal.title != title)) {
            _goals.add(
              Goal(title: title, icon: Icons.flag_outlined, isCustom: true),
            );
          }
        }
        for (final goal in _goals) {
          goal.isSelected = selected.contains(goal.title);
        }
      });
    } catch (error) {
      debugPrint('Sticky Path could not restore goals: $error');
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftKey,
        jsonEncode({
          'selected': [
            for (final goal in _goals)
              if (goal.isSelected) goal.title,
          ],
          'custom': [
            for (final goal in _goals)
              if (goal.isCustom) goal.title,
          ],
        }),
      );
    } catch (error) {
      debugPrint('Sticky Path could not save goals: $error');
    }
  }

  void _updateInputFocus() {
    if (mounted) {
      setState(() => _isInputFocused = _customGoalFocusNode.hasFocus);
    }
  }

  void _toggleGoal(Goal goal) {
    HapticFeedback.selectionClick();
    setState(() => goal.isSelected = !goal.isSelected);
    _saveDraft();
  }

  void _addCustomGoal() {
    final title = _customGoalController.text.trim();
    if (title.isEmpty) return;

    Goal? existingGoal;
    for (final goal in _goals) {
      if (goal.title.toLowerCase() == title.toLowerCase()) {
        existingGoal = goal;
        break;
      }
    }

    HapticFeedback.lightImpact();
    setState(() {
      if (existingGoal != null) {
        existingGoal.isSelected = true;
      } else {
        _goals.add(
          Goal(
            title: title,
            icon: Icons.flag_outlined,
            isCustom: true,
            isSelected: true,
          ),
        );
      }
    });
    _saveDraft();
    _customGoalController.clear();
    _customGoalFocusNode.requestFocus();
  }

  void _continue() {
    final selectedGoals = _goals
        .where((goal) => goal.isSelected)
        .toList(growable: false);

    if (selectedGoals.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Please select at least one goal.',
              style: AppFonts.sansStyle(size: 14),
            ),
            backgroundColor: const Color(0xFF1A1B21),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitsScreen(
          selectedDuration: widget.selectedDuration,
          goals: [for (final goal in selectedGoals) goal.title],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customGoalFocusNode
      ..removeListener(_updateInputFocus)
      ..dispose();
    _customGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            ColoredBox(color: Colors.black.withValues(alpha: 0.52)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 390).clamp(0.88, 1.12);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4 * scale),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new),
                          color: AppColors.white,
                          iconSize: 23 * scale,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          tooltip: 'Back',
                        ),
                        SizedBox(height: 10 * scale),
                        Text(
                          'Set your goals',
                          style: AppFonts.sansStyle(
                            size: 36 * scale,
                            weight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 10 * scale),
                        Text(
                          'What do you want to achieve?',
                          style: AppFonts.sansStyle(
                            size: 15 * scale,
                            color: AppColors.mutedWhite,
                          ),
                        ),
                        SizedBox(height: 24 * scale),
                        Expanded(
                          child: ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.only(bottom: 16 * scale),
                            children: [
                              Wrap(
                                spacing: 9 * scale,
                                runSpacing: 9 * scale,
                                children: [
                                  for (final goal in _goals)
                                    if (!goal.isCustom)
                                      _PresetGoalChip(
                                        goal: goal,
                                        scale: scale,
                                        onTap: () => _toggleGoal(goal),
                                      ),
                                ],
                              ),
                              SizedBox(height: 24 * scale),
                              Text(
                                'Add your own goal',
                                style: AppFonts.sansStyle(
                                  size: 17 * scale,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 12 * scale),
                              _CustomGoalInput(
                                controller: _customGoalController,
                                focusNode: _customGoalFocusNode,
                                isFocused: _isInputFocused,
                                scale: scale,
                                onAdd: _addCustomGoal,
                              ),
                              if (_goals.any((goal) => goal.isCustom))
                                SizedBox(height: 18 * scale),
                              for (final goal in _goals)
                                if (goal.isCustom) ...[
                                _GoalCard(
                                  goal: goal,
                                  scale: scale,
                                  onTap: () => _toggleGoal(goal),
                                ),
                                SizedBox(height: 11 * scale),
                              ],
                            ],
                          ),
                        ),
                        _NextButton(scale: scale, onPressed: _continue),
                        SizedBox(height: 16 * scale),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetGoalChip extends StatelessWidget {
  const _PresetGoalChip({
    required this.goal,
    required this.scale,
    required this.onTap,
  });

  final Goal goal;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = goal.isSelected ? AppColors.pink : AppColors.mutedWhite;
    return Semantics(
      button: true,
      selected: goal.isSelected,
      label: goal.title,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _GoalsScreenState._animationDuration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: 13 * scale,
            vertical: 10 * scale,
          ),
          decoration: BoxDecoration(
            color: goal.isSelected
                ? AppColors.pink.withValues(alpha: 0.14)
                : const Color(0xFF15161B).withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: goal.isSelected ? AppColors.pink : const Color(0xFF343A48),
              width: goal.isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                goal.isSelected ? Icons.check_circle_rounded : goal.icon,
                color: color,
                size: 17 * scale,
              ),
              SizedBox(width: 7 * scale),
              Text(
                goal.title,
                style: AppFonts.sansStyle(
                  size: 14 * scale,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.scale,
    required this.onTap,
  });

  final Goal goal;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: goal.isSelected,
      label: goal.title,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _GoalsScreenState._animationDuration,
          curve: Curves.easeOutCubic,
          height: 64 * scale,
          padding: EdgeInsets.symmetric(horizontal: 17 * scale),
          decoration: BoxDecoration(
            color: const Color(0xFF15161B).withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: goal.isSelected ? AppColors.pink : const Color(0xFF343A48),
              width: goal.isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: goal.isSelected
                    ? AppColors.pink.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.28),
                blurRadius: goal.isSelected ? 16 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.sansStyle(
                    size: 15 * scale,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 12 * scale),
              AnimatedContainer(
                duration: _GoalsScreenState._animationDuration,
                curve: Curves.easeOutCubic,
                width: 23 * scale,
                height: 23 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goal.isSelected ? AppColors.pink : Colors.transparent,
                  border: Border.all(
                    color: goal.isSelected
                        ? AppColors.pink
                        : AppColors.mutedWhite,
                    width: 1.5,
                  ),
                ),
                child: AnimatedScale(
                  duration: _GoalsScreenState._animationDuration,
                  curve: Curves.easeOutBack,
                  scale: goal.isSelected ? 1 : 0,
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.ink,
                    size: 16 * scale,
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

class _CustomGoalInput extends StatelessWidget {
  const _CustomGoalInput({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.scale,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final double scale;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _GoalsScreenState._animationDuration,
      height: 62 * scale,
      padding: EdgeInsets.only(left: 17 * scale, right: 8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF15161B).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isFocused ? AppColors.pink : const Color(0xFF343A48),
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (_) => onAdd(),
              textInputAction: TextInputAction.done,
              maxLines: 1,
              style: AppFonts.sansStyle(size: 15 * scale),
              cursorColor: AppColors.pink,
              decoration: InputDecoration(
                hintStyle: AppFonts.sansStyle(
                  size: 15 * scale,
                  color: AppColors.mutedWhite,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          Semantics(
            button: true,
            label: 'Add goal',
            child: Material(
              color: AppColors.pink,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onAdd,
                customBorder: const CircleBorder(),
                child: SizedBox.square(
                  dimension: 44 * scale,
                  child: Icon(
                    Icons.add_rounded,
                    color: AppColors.ink,
                    size: 27 * scale,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatefulWidget {
  const _NextButton({required this.scale, required this.onPressed});

  final double scale;
  final VoidCallback onPressed;

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          height: 58 * widget.scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _pressed ? AppColors.pinkDeep : AppColors.pink,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            'Next',
            style: AppFonts.sansStyle(
              size: 17 * widget.scale,
              weight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
