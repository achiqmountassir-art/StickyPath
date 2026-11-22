import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress/challenge_completion.dart';
import '../progress/challenge_store.dart';
import '../theme/app_colors.dart';
import 'challenge_screen.dart';
import 'sticker_preview_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            ColoredBox(color: Colors.black.withValues(alpha: 0.34)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: AppFonts.sansStyle(
                        size: 32,
                        weight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Material(
                      color: const Color(0xFF15161B).withValues(alpha: 0.9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                        side: const BorderSide(color: Color(0xFF343A48)),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                        leading: const Icon(
                          Icons.restart_alt_rounded,
                          color: AppColors.pink,
                        ),
                        title: Text(
                          'Start a new challenge',
                          style: AppFonts.sansStyle(
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Your current progress is replaced once you finish setup',
                          style: AppFonts.sansStyle(
                            size: 12.5,
                            color: AppColors.mutedWhite,
                          ),
                        ),
                        onTap: () => Navigator.of(context, rootNavigator: true)
                            .push(
                              CupertinoPageRoute(
                                builder: (context) => const ChallengeScreen(),
                              ),
                            ),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: ChallengeStore.instance,
                      builder: (context, _) {
                        final challenge = ChallengeStore.instance.active;
                        if (challenge == null ||
                            challenge.celebratedAt == null) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Material(
                            color: const Color(
                              0xFF15161B,
                            ).withValues(alpha: 0.9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                              side: const BorderSide(color: Color(0xFF343A48)),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                              leading: const Icon(
                                Icons.emoji_events_outlined,
                                color: AppColors.pink,
                              ),
                              title: Text(
                                'View your achievement sticker',
                                style: AppFonts.sansStyle(
                                  size: 15,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).push(
                                MaterialPageRoute(
                                  builder: (context) => StickerPreviewScreen(
                                    summary: ChallengeSummary.of(
                                      challenge,
                                      ChallengeStore.instance.now(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: ChallengeStore.instance,
                        builder: (context, _) => ListView(
                          padding: const EdgeInsets.only(top: 12, bottom: 120),
                          children: _extraTiles(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _extraTiles(BuildContext context) {
    final active = ChallengeStore.instance.active;
    return [
      if (active != null)
        _SettingsTile(
          icon: Icons.delete_outline_rounded,
          title: 'Delete current challenge',
          subtitle: 'Removes its progress from this phone',
          onTap: () => _confirmDelete(context),
        ),
    ];
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15161B),
        title: Text(
          'Delete challenge?',
          style: AppFonts.sansStyle(size: 18, weight: FontWeight.w700),
        ),
        content: Text(
          'All progress for this challenge will be removed. '
          'This cannot be undone.',
          style: AppFonts.sansStyle(size: 14, color: AppColors.mutedWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ChallengeStore.instance.deleteActiveChallenge();
    if (!context.mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/', (route) => false);
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15161B).withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xFF343A48)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        leading: Icon(icon, color: AppColors.pink),
        title: Text(
          title,
          style: AppFonts.sansStyle(size: 15, weight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: AppFonts.sansStyle(size: 12.5, color: AppColors.mutedWhite),
        ),
        onTap: onTap,
      ),
    );
  }
}
