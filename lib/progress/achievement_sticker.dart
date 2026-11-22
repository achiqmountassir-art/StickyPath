import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum StickerStyle { classic, glow, minimal }

extension StickerStyleLabel on StickerStyle {
  String get label => switch (this) {
    StickerStyle.classic => 'Classic',
    StickerStyle.glow => 'Glow',
    StickerStyle.minimal => 'Minimal',
  };
}

/// The real values printed on a sticker. Identical across every style.
class StickerData {
  const StickerData({required this.totalDays, required this.completedDays});

  final int totalDays;
  final int completedDays;

  String get headline => '$totalDays DAYS';
  String get subtitle => 'COMPLETED';
  String get statistic => '$completedDays / $totalDays days';
}

/// Paints the sticker artwork into a square [size]. Nothing is drawn
/// outside the artwork, so the background stays fully transparent.
void paintSticker(
  Canvas canvas,
  Size size,
  StickerData data,
  StickerStyle style,
) {
  final s = size.shortestSide;
  final cx = size.width / 2;
  final glow = style == StickerStyle.glow;
  final minimal = style == StickerStyle.minimal;

  List<Shadow> shadows({double strength = 1}) => [
    Shadow(
      color: Colors.black.withValues(alpha: 0.55 * strength),
      blurRadius: s * 0.004,
      offset: Offset(0, s * 0.0015),
    ),
    if (glow)
      Shadow(
        color: AppColors.pink.withValues(alpha: 0.45 * strength),
        blurRadius: s * 0.022,
      ),
  ];

  TextPainter layout(
    String text,
    double fontSize,
    FontWeight weight, {
    double letterSpacing = 0,
    Color color = AppColors.white,
    double strength = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: fontSize,
          fontWeight: weight,
          fontVariations: [FontVariation.weight(weight.value.toDouble())],
          color: color,
          height: 1,
          letterSpacing: letterSpacing,
          shadows: shadows(strength: strength),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    return painter;
  }

  var headlineSize = s * 0.155;
  var headline = layout(
    data.headline,
    headlineSize,
    FontWeight.w900,
    letterSpacing: -s * 0.002,
  );
  final maxWidth = s * 0.8;
  if (headline.width > maxWidth) {
    headlineSize *= maxWidth / headline.width;
    headline.dispose();
    headline = layout(
      data.headline,
      headlineSize,
      FontWeight.w900,
      letterSpacing: -s * 0.002,
    );
  }

  final subtitleSize = s * 0.044;
  final subtitle = layout(
    data.subtitle,
    subtitleSize,
    FontWeight.w600,
    letterSpacing: subtitleSize * 0.42,
  );
  final statistic = layout(
    data.statistic,
    s * 0.038,
    FontWeight.w500,
    color: AppColors.white.withValues(alpha: 0.92),
    strength: 0.8,
  );

  final flagHeight = s * (minimal ? 0.07 : 0.085);
  final gapFlag = s * 0.045;
  final gapSubtitle = s * 0.03;
  final gapDivider = s * 0.04;
  final dividerThickness = s * 0.0045;
  final gapStat = s * 0.04;

  final total =
      flagHeight +
      gapFlag +
      headline.height +
      gapSubtitle +
      subtitle.height +
      gapDivider +
      dividerThickness +
      gapStat +
      statistic.height;
  var y = (size.height - total) / 2;

  final flagRect = Rect.fromCenter(
    center: Offset(cx, y + flagHeight / 2),
    width: flagHeight * 1.05,
    height: flagHeight,
  );
  paintFinishFlag(canvas, flagRect, glow: glow);

  if (!minimal) {
    final lineLength = s * 0.075;
    final lineGap = s * 0.035;
    final linePaint = Paint()
      ..color = AppColors.pink
      ..strokeWidth = s * 0.004
      ..strokeCap = StrokeCap.round;
    if (glow) {
      linePaint.maskFilter = MaskFilter.blur(BlurStyle.solid, s * 0.004);
    }
    final lineY = flagRect.center.dy;
    canvas
      ..drawLine(
        Offset(flagRect.left - lineGap - lineLength, lineY),
        Offset(flagRect.left - lineGap, lineY),
        linePaint,
      )
      ..drawLine(
        Offset(flagRect.right + lineGap, lineY),
        Offset(flagRect.right + lineGap + lineLength, lineY),
        linePaint,
      );
  }
  y += flagHeight + gapFlag;

  headline.paint(canvas, Offset(cx - headline.width / 2, y));
  y += headline.height + gapSubtitle;

  // Letter spacing trails the last glyph; shift so the word looks centered.
  subtitle.paint(
    canvas,
    Offset(cx - (subtitle.width - subtitleSize * 0.42) / 2, y),
  );
  y += subtitle.height + gapDivider;

  final dividerWidth = s * (minimal ? 0.12 : 0.26);
  final dividerPaint = Paint()
    ..color = minimal ? AppColors.white.withValues(alpha: 0.85) : AppColors.pink
    ..strokeWidth = dividerThickness
    ..strokeCap = StrokeCap.round;
  if (glow) {
    dividerPaint.maskFilter = MaskFilter.blur(BlurStyle.solid, s * 0.005);
  }
  canvas.drawLine(
    Offset(cx - dividerWidth / 2, y + dividerThickness / 2),
    Offset(cx + dividerWidth / 2, y + dividerThickness / 2),
    dividerPaint,
  );
  y += dividerThickness + gapStat;

  statistic.paint(canvas, Offset(cx - statistic.width / 2, y));

  headline.dispose();
  subtitle.dispose();
  statistic.dispose();
}

/// White checkered finish flag on a short pole, drawn inside [rect].
void paintFinishFlag(Canvas canvas, Rect rect, {bool glow = false}) {
  final h = rect.height;
  final pole = h * 0.075;
  final white = Paint()..color = AppColors.white;
  final shadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.45)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.03);

  final poleRect = Rect.fromLTWH(rect.left, rect.top, pole, h);
  final cloth = Rect.fromLTWH(
    rect.left + pole * 1.6,
    rect.top + h * 0.02,
    rect.width - pole * 1.6,
    h * 0.62,
  );

  const columns = 4;
  const rows = 3;
  final cellW = cloth.width / columns;
  final cellH = cloth.height / rows;
  final flag = Path()
    ..addRRect(RRect.fromRectAndRadius(poleRect, Radius.circular(pole / 2)));
  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      if ((row + column).isEven) {
        flag.addRect(
          Rect.fromLTWH(
            cloth.left + column * cellW,
            cloth.top + row * cellH,
            cellW,
            cellH,
          ),
        );
      }
    }
  }
  final outline = Path()..addRect(cloth.deflate(h * 0.0125));
  final border = Paint()
    ..color = AppColors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = h * 0.025;

  // Shadow and glow follow only the painted shapes, so the empty squares
  // stay transparent.
  canvas.drawPath(flag.shift(Offset(0, h * 0.02)), shadow);
  canvas.drawPath(
    outline.shift(Offset(0, h * 0.02)),
    Paint()
      ..color = shadow.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = border.strokeWidth
      ..maskFilter = shadow.maskFilter,
  );
  if (glow) {
    canvas.drawPath(
      flag,
      Paint()
        ..color = AppColors.pink.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, h * 0.08),
    );
  }
  canvas.drawPath(flag, white);
  canvas.drawPath(outline, border);
}

/// Renders the sticker to a transparent RGBA PNG.
Future<Uint8List> renderStickerPng(
  StickerData data,
  StickerStyle style, {
  int size = 2048,
}) async {
  final recorder = ui.PictureRecorder();
  final dimension = size.toDouble();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, dimension, dimension));
  paintSticker(canvas, Size.square(dimension), data, style);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('PNG encoding failed');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

class StickerPainter extends CustomPainter {
  const StickerPainter({required this.data, required this.style});

  final StickerData data;
  final StickerStyle style;

  @override
  void paint(Canvas canvas, Size size) =>
      paintSticker(canvas, size, data, style);

  @override
  bool shouldRepaint(StickerPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.data.totalDays != data.totalDays ||
      oldDelegate.data.completedDays != data.completedDays;
}

class FinishFlagPainter extends CustomPainter {
  const FinishFlagPainter();

  @override
  void paint(Canvas canvas, Size size) =>
      paintFinishFlag(canvas, Offset.zero & size, glow: true);

  @override
  bool shouldRepaint(FinishFlagPainter oldDelegate) => false;
}
