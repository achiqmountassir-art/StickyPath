import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class OnboardingStepsScreen extends StatelessWidget {
  const OnboardingStepsScreen({super.key, this.onNext});

  final VoidCallback? onNext;

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
              'assets/images/image2.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.ink.withValues(alpha: 0.75),
                    AppColors.ink.withValues(alpha: 0.0),
                    AppColors.ink.withValues(alpha: 0.0),
                    AppColors.ink.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.30, 0.66, 0.92],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 390).clamp(0.85, 1.15);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        SizedBox(height: 12 * scale),
                        _Logo(scale: scale),
                        SizedBox(height: 18 * scale),
                        _Headline(scale: scale),
                        SizedBox(height: 10 * scale),
                        Text(
                          'Each day is one small action.\n'
                          'Complete it, remove it, and move\n'
                          'one step closer to your goal.',
                          textAlign: TextAlign.center,
                          style: AppFonts.sansStyle(
                            size: 14.5 * scale,
                            color: AppColors.softWhite.withValues(alpha: 0.88),
                            height: 1.45,
                          ).copyWith(shadows: _textShadow),
                        ),
                        const Spacer(),
                        const _ProgressDots(activeIndex: 1, count: 3),
                        SizedBox(height: 16 * scale),
                        _HandwrittenNote(scale: scale),
                        SizedBox(height: 22 * scale),
                        _NextButton(scale: scale, onPressed: onNext),
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

final _textShadow = [
  Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 14),
];

class _Logo extends StatelessWidget {
  const _Logo({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.brush,
      fontSize: 20 * scale,
      letterSpacing: 0.4,
      shadows: _textShadow,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Sticky', style: style.copyWith(color: AppColors.white)),
          TextSpan(text: 'Path', style: style.copyWith(color: AppColors.pink)),
        ],
      ),
      semanticsLabel: 'StickyPath',
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppFonts.brush,
      fontSize: 36 * scale,
      height: 1.15,
      shadows: _textShadow,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Small steps.\n', style: base.copyWith(color: AppColors.white)),
          TextSpan(text: 'Every day.', style: base.copyWith(color: AppColors.pink)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.activeIndex, required this.count});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.pink : Colors.transparent,
            border: Border.all(
              color: active ? AppColors.pink : AppColors.mutedWhite.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: active
                ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.6), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

class _HandwrittenNote extends StatelessWidget {
  const _HandwrittenNote({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'One day at a time.',
          style: TextStyle(
            fontFamily: AppFonts.brush,
            fontSize: 16 * scale,
            color: AppColors.white,
            shadows: _textShadow,
          ),
        ),
        SizedBox(height: 4 * scale),
        Container(
          width: 64 * scale,
          height: 2.5,
          decoration: BoxDecoration(
            color: AppColors.pink,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: AppColors.pink.withValues(alpha: 0.7), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.scale, this.onPressed});

  final double scale;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 320 * scale),
      width: double.infinity,
      height: 58 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.40),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: AppColors.pink,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: AppColors.pinkDeep,
          highlightColor: AppColors.pinkDeep.withValues(alpha: 0.4),
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed?.call();
          },
          child: Center(
            child: Text(
              'Next  →',
              style: AppFonts.sansStyle(
                size: 17 * scale,
                weight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
