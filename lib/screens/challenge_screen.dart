import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'goals_screen.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  static const durations = [7, 30, 60, 90, 100, 180];

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  int _selectedDays = 0 ;

  void _goNext() {
    if (_selectedDays <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Please choose a challenge duration.',
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
      CupertinoPageRoute(
        builder: (context) => GoalsScreen(durationDays: _selectedDays),
      ),
    );
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
            Image.asset(
              'assets/images/image4.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            ColoredBox(color: AppColors.ink.withValues(alpha: 0.35)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 390).clamp(0.85, 1.15);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8 * scale),
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.white,
                          iconSize: 26,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          tooltip: 'Back',
                        ),
                        SizedBox(height: 20 * scale),
                        Text(
                          'What\u2019s your\nchallenge?',
                          style: AppFonts.sansStyle(
                            size: 36 * scale,
                            weight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 12 * scale),
                        Text(
                          'Choose the duration that fits your goals.',
                          style: AppFonts.sansStyle(
                            size: 15 * scale,
                            color: AppColors.mutedWhite,
                          ),
                        ),
                        SizedBox(height: 32 * scale),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          mainAxisSpacing: 12 * scale,
                          crossAxisSpacing: 12 * scale,
                          childAspectRatio: 0.82,
                          children: [
                            for (final days in ChallengeScreen.durations)
                              _DurationCard(
                                days: days,
                                scale: scale,
                                selected: days == _selectedDays,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedDays = days);
                                },
                              ),
                          ],
                        ),
                        const Spacer(),
                        _NextButton(scale: scale, onPressed: _goNext),
                        SizedBox(height: 20 * scale),
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

class _DurationCard extends StatelessWidget {
  const _DurationCard({
    required this.days,
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  final int days;
  final double scale;
  final bool selected;
  final VoidCallback onTap;

  static const _duration = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.ink : AppColors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? AppColors.pink : const Color(0xFF15161B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.pink : const Color(0xFF2E3442),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.pink.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.45),
              blurRadius: selected ? 22 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10 * scale,
              right: 10 * scale,
              child: AnimatedOpacity(
                duration: _duration,
                opacity: selected ? 1 : 0,
                child: CustomPaint(
                  size: Size(16 * scale, 10 * scale),
                  painter: _CrownPainter(),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: _duration,
                    style: AppFonts.sansStyle(
                      size: 32 * scale,
                      weight: FontWeight.w800,
                      color: fg,
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                    child: Text('$days'),
                  ),
                  SizedBox(height: 4 * scale),
                  AnimatedDefaultTextStyle(
                    duration: _duration,
                    style: AppFonts.sansStyle(
                      size: 13 * scale,
                      weight: FontWeight.w500,
                      color: selected
                          ? AppColors.ink.withValues(alpha: 0.85)
                          : AppColors.mutedWhite,
                    ),
                    child: const Text('Days'),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10 * scale,
              child: AnimatedOpacity(
                duration: _duration,
                opacity: selected ? 1 : 0,
                child: AnimatedScale(
                  duration: _duration,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : 0.5,
                  child: Icon(Icons.check_rounded, size: 18 * scale, color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final crown = Path()
      ..moveTo(w * 0.08, h * 0.85)
      ..lineTo(w * 0.04, h * 0.2)
      ..lineTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.70, h * 0.52)
      ..lineTo(w * 0.96, h * 0.2)
      ..lineTo(w * 0.92, h * 0.85)
      ..close();

    canvas.drawPath(crown, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  void _setPressed(bool value) => setState(() => _pressed = value);

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
        child: Container(
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
