import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress/achievement_sticker.dart';
import '../progress/challenge_completion.dart';
import '../progress/sticker_export.dart';
import '../theme/app_colors.dart';
import 'completion_screen.dart' show StickerPrimaryButton;

enum _PreviewBackground { checker, dark, light }

class StickerPreviewScreen extends StatefulWidget {
  const StickerPreviewScreen({
    super.key,
    required this.summary,
    this.onSave,
    this.onShare,
  });

  final ChallengeSummary summary;

  /// Defaults to [saveStickerToGallery]; replaceable for tests.
  final StickerAction? onSave;

  /// Defaults to [shareSticker]; replaceable for tests.
  final StickerAction? onShare;

  @override
  State<StickerPreviewScreen> createState() => _StickerPreviewScreenState();
}

class _StickerPreviewScreenState extends State<StickerPreviewScreen> {
  StickerStyle _style = StickerStyle.classic;
  _PreviewBackground _background = _PreviewBackground.checker;
  bool _saving = false;
  bool _sharing = false;

  late final StickerData _data = StickerData(
    totalDays: widget.summary.totalDays,
    completedDays: widget.summary.completedDays,
  );

  String get _fileName =>
      'stickypath-${_data.totalDays}-days-${_style.name}';

  Future<void> _run({
    required bool share,
    required String success,
  }) async {
    setState(() => share ? _sharing = true : _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    String message;
    try {
      final png = await renderStickerPng(_data, _style);
      if (share) {
        await (widget.onShare ??
            (png, name) => shareSticker(png, name, origin: origin))(
          png,
          _fileName,
        );
      } else {
        await (widget.onSave ?? saveStickerToGallery)(png, _fileName);
      }
      message = success;
      HapticFeedback.lightImpact();
    } on StickerExportException catch (error) {
      message = error.message;
    } catch (error) {
      debugPrint('Sticky Path sticker export failed: $error');
      message = share ? 'Could not share the sticker.' : 'Could not save the sticker.';
    }
    if (!mounted) return;
    setState(() => share ? _sharing = false : _saving = false);
    if (message.isEmpty) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: AppFonts.sansStyle(size: 14)),
          backgroundColor: const Color(0xFF1A1B21),
          behavior: SnackBarBehavior.floating,
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
            ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 390).clamp(0.85, 1.12);
                  final busy = _saving || _sharing;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4 * scale),
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_ios_new),
                          color: AppColors.white,
                          iconSize: 22 * scale,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          tooltip: 'Back',
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          'Your sticker',
                          style: AppFonts.sansStyle(
                            size: 30 * scale,
                            weight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: CustomPaint(
                                  painter: _PreviewBackgroundPainter(
                                    _background,
                                  ),
                                  foregroundPainter: StickerPainter(
                                    data: _data,
                                    style: _style,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 14 * scale),
                        _Segmented<_PreviewBackground>(
                          values: _PreviewBackground.values,
                          selected: _background,
                          label: (value) => switch (value) {
                            _PreviewBackground.checker => 'Transparent',
                            _PreviewBackground.dark => 'Dark',
                            _PreviewBackground.light => 'Light',
                          },
                          scale: scale,
                          onChanged: (value) =>
                              setState(() => _background = value),
                        ),
                        SizedBox(height: 10 * scale),
                        _Segmented<StickerStyle>(
                          values: StickerStyle.values,
                          selected: _style,
                          label: (value) => value.label,
                          scale: scale,
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() => _style = value);
                          },
                        ),
                        SizedBox(height: 18 * scale),
                        StickerPrimaryButton(
                          label: 'Share to Story',
                          scale: scale,
                          busy: _sharing,
                          onPressed: busy
                              ? null
                              : () => _run(share: true, success: ''),
                        ),
                        SizedBox(height: 10 * scale),
                        SizedBox(
                          width: double.infinity,
                          height: 52 * scale,
                          child: OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _run(
                                    share: false,
                                    success: 'Sticker saved to your photos',
                                  ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.white,
                              side: const BorderSide(color: Color(0xFF343A48)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : Text(
                                    'Save PNG',
                                    style: AppFonts.sansStyle(
                                      size: 15 * scale,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
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

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.label,
    required this.scale,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final double scale;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42 * scale,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF15161B).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF343A48)),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: GestureDetector(
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == selected
                          ? AppColors.pink.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: value == selected
                            ? AppColors.pink.withValues(alpha: 0.85)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      label(value),
                      style: AppFonts.sansStyle(
                        size: 13 * scale,
                        weight: value == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: value == selected
                            ? AppColors.white
                            : AppColors.mutedWhite,
                      ),
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

/// Preview only; never part of the exported PNG.
class _PreviewBackgroundPainter extends CustomPainter {
  const _PreviewBackgroundPainter(this.background);

  final _PreviewBackground background;

  @override
  void paint(Canvas canvas, Size size) {
    switch (background) {
      case _PreviewBackground.dark:
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF16161A));
      case _PreviewBackground.light:
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEDEBE6));
      case _PreviewBackground.checker:
        final cell = size.shortestSide / 16;
        final light = Paint()..color = const Color(0xFF3A3A40);
        final dark = Paint()..color = const Color(0xFF2A2A2F);
        for (var y = 0.0; y < size.height; y += cell) {
          for (var x = 0.0; x < size.width; x += cell) {
            final even = ((x / cell).round() + (y / cell).round()).isEven;
            canvas.drawRect(
              Rect.fromLTWH(x, y, cell, cell),
              even ? light : dark,
            );
          }
        }
    }
  }

  @override
  bool shouldRepaint(_PreviewBackgroundPainter oldDelegate) =>
      oldDelegate.background != background;
}
