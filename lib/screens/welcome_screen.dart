import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _reveal({required double start, required Widget child}) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.5).clamp(0, 1), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curve),
        child: child,
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
            const _WallBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 390).clamp(0.85, 1.15);
                  final h = constraints.maxHeight;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        SizedBox(height: h * 0.045),
                        _reveal(start: 0, child: _Logo(scale: scale)),
                        const Spacer(),
                        _reveal(start: 0.2, child: _Headline(scale: scale)),
                        SizedBox(height: 14 * scale),
                        _reveal(
                          start: 0.3,
                          child: Text(
                            'One day at a time.',
                            textAlign: TextAlign.center,
                            style: AppFonts.sansStyle(
                              size: 16 * scale,
                              color: AppColors.softWhite.withValues(alpha: 0.82),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        SizedBox(height: 34 * scale),
                        _reveal(
                          start: 0.4,
                          child: _StartButton(scale: scale, onPressed: widget.onStart),
                        ),
                        SizedBox(height: h * 0.07),
                        _reveal(start: 0.5, child: _Tagline(scale: scale)),
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

class _WallBackground extends StatelessWidget {
  const _WallBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/image1.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0.25, 0),
          filterQuality: FilterQuality.high,
        ),
        ColoredBox(color: AppColors.ink.withValues(alpha: 0.18)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.ink.withValues(alpha: 0.88),
                AppColors.ink.withValues(alpha: 0.55),
                AppColors.ink.withValues(alpha: 0.08),
                AppColors.ink.withValues(alpha: 0.10),
                AppColors.ink.withValues(alpha: 0.78),
                AppColors.ink.withValues(alpha: 0.96),
              ],
              stops: const [0.0, 0.17, 0.30, 0.50, 0.66, 0.84],
            ),
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.brush,
      fontSize: 46 * scale,
      height: 1.1,
      letterSpacing: 0.5,
      shadows: [
        Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(30 * scale, 17 * scale),
          painter: _CrownPainter(),
        ),
        SizedBox(height: 6 * scale),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Sticky', style: style.copyWith(color: AppColors.white)),
              TextSpan(text: 'Path', style: style.copyWith(color: AppColors.pink)),
            ],
          ),
          textAlign: TextAlign.center,
          semanticsLabel: 'StickyPath',
        ),
      ],
    );
  }
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = AppColors.pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final crown = Path()
      ..moveTo(w * 0.08, h * 0.82)
      ..lineTo(w * 0.04, h * 0.22)
      ..lineTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.50, h * 0.08)
      ..lineTo(w * 0.70, h * 0.52)
      ..lineTo(w * 0.96, h * 0.22)
      ..lineTo(w * 0.92, h * 0.82)
      ..close();

    canvas.drawPath(crown, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Headline extends StatelessWidget {
  const _Headline({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final base = AppFonts.sansStyle(
      size: 36 * scale,
      weight: FontWeight.w800,
      height: 1.12,
      letterSpacing: -0.8,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Small actions.\n', style: base.copyWith(color: AppColors.white)),
          TextSpan(text: 'Big changes.', style: base.copyWith(color: AppColors.pink)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.scale, this.onPressed});

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
              'Start your path  →',
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

class _Tagline extends StatelessWidget {
  const _Tagline({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '90 DAYS  •  ONE PATH  •  ONE DAY AT A TIME',
        textAlign: TextAlign.center,
        style: AppFonts.sansStyle(
          size: 10.5 * scale,
          weight: FontWeight.w600,
          color: AppColors.mutedWhite.withValues(alpha: 0.75),
          letterSpacing: 2.6,
        ),
      ),
    );
  }
}
