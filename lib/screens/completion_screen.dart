import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress/achievement_sticker.dart';
import '../progress/challenge_completion.dart';
import '../theme/app_colors.dart';
import 'sticker_preview_screen.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String shortDate(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';

class CompletionScreen extends StatelessWidget {
  const CompletionScreen({
    super.key,
    required this.summary,
    this.onContinue,
    this.animate = true,
  });

  final ChallengeSummary summary;

  /// Defaults to closing this screen.
  final VoidCallback? onContinue;

  /// Plays the flag animation; off once the ceremony was already seen.
  final bool animate;

  void _openSticker(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StickerPreviewScreen(summary: summary),
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
            ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 390).clamp(0.85, 1.12);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 24 * scale),
                          _AnimatedFlag(animate: animate),
                          SizedBox(height: 26 * scale),
                          Text(
                            'Challenge Completed',
                            textAlign: TextAlign.center,
                            style: AppFonts.sansStyle(
                              size: 32 * scale,
                              weight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          Text(
                            summary.title,
                            style: AppFonts.sansStyle(
                              size: 16 * scale,
                              weight: FontWeight.w600,
                              color: AppColors.pink,
                            ),
                          ),
                          SizedBox(height: 6 * scale),
                          Text(
                            '${shortDate(summary.startDate)} – '
                            '${shortDate(summary.endDate)}',
                            style: AppFonts.sansStyle(
                              size: 14 * scale,
                              color: AppColors.mutedWhite,
                            ),
                          ),
                          SizedBox(height: 28 * scale),
                          _StatsCard(summary: summary, scale: scale),
                          SizedBox(height: 32 * scale),
                          StickerPrimaryButton(
                            label: 'View Your Sticker',
                            scale: scale,
                            onPressed: () => _openSticker(context),
                          ),
                          SizedBox(height: 10 * scale),
                          TextButton(
                            onPressed:
                                onContinue ??
                                () => Navigator.of(context).maybePop(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.softWhite,
                              minimumSize: Size(double.infinity, 50 * scale),
                            ),
                            child: Text(
                              'Continue',
                              style: AppFonts.sansStyle(
                                size: 16 * scale,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                        ],
                      ),
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

class _AnimatedFlag extends StatelessWidget {
  const _AnimatedFlag({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.6 + 0.4 * value,
          child: Transform.rotate(angle: (1 - value) * -0.3, child: child),
        ),
      ),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.pink.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.pink.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.25),
              blurRadius: 30,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(30, 28, 26, 28),
          child: CustomPaint(painter: FinishFlagPainter()),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.summary, required this.scale});

  final ChallengeSummary summary;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Completed', '${summary.completedDays} / ${summary.totalDays} days'),
      ('Missed', '${summary.missedDays} days'),
      if (summary.partialDays > 0) ('Partial', '${summary.partialDays} days'),
      ('Final streak', '${summary.streak} days'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF15161B).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF343A48)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12 * scale),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: AppFonts.sansStyle(
                        size: 14 * scale,
                        color: AppColors.mutedWhite,
                      ),
                    ),
                  ),
                  Text(
                    rows[i].$2,
                    style: AppFonts.sansStyle(
                      size: 15 * scale,
                      weight: FontWeight.w700,
                      color: i == 0 ? AppColors.pink : AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pink call-to-action shared by the completion and sticker screens.
class StickerPrimaryButton extends StatelessWidget {
  const StickerPrimaryButton({
    super.key,
    required this.label,
    required this.scale,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final double scale;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56 * scale,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pink,
          disabledBackgroundColor: AppColors.pink.withValues(alpha: 0.5),
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.ink,
                ),
              )
            : Text(
                label,
                style: AppFonts.sansStyle(
                  size: 16 * scale,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
      ),
    );
  }
}