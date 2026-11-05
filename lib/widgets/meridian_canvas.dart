import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/meridian.dart';

class MeridianCanvas extends StatelessWidget {
  const MeridianCanvas({
    super.key,
    required this.meridians,
    required this.acupoints,
    required this.view,
    required this.progress,
    required this.reverse,
    required this.showPoints,
    required this.activePointId,
    required this.onTapDown,
  });

  final List<Meridian> meridians;
  final List<Acupoint> acupoints;
  final String view;
  final double progress;
  final bool reverse;
  final bool showPoints;
  final String? activePointId;
  final ValueChanged<TapDownDetails> onTapDown;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: onTapDown,
      child: CustomPaint(
        painter: _MeridianPainter(
          meridians: meridians,
          acupoints: acupoints,
          view: view,
          progress: progress,
          reverse: reverse,
          showPoints: showPoints,
          activePointId: activePointId,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MeridianPainter extends CustomPainter {
  _MeridianPainter({
    required this.meridians,
    required this.acupoints,
    required this.view,
    required this.progress,
    required this.reverse,
    required this.showPoints,
    required this.activePointId,
  });

  final List<Meridian> meridians;
  final List<Acupoint> acupoints;
  final String view;
  final double progress;
  final bool reverse;
  final bool showPoints;
  final String? activePointId;

  @override
  void paint(Canvas canvas, Size size) {
    const modelWidth = 1000.0;
    const modelHeight = 1600.0;
    final scale = math.min(size.width / modelWidth, size.height / modelHeight);
    final dx = (size.width - modelWidth * scale) / 2;
    final dy = (size.height - modelHeight * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    _drawSilhouette(canvas);

    for (final meridian in meridians) {
      for (final route in meridian.routes.where((route) => route.view == view)) {
        if (route.points.length < 2) continue;
        final routePath = _makePath(route.points);
        canvas.drawPath(
          routePath,
          Paint()
            ..color = meridian.color.withOpacity(0.72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 13
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(
          routePath,
          Paint()
            ..color = meridian.color.withOpacity(0.96)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        _drawFlow(canvas, route.points, meridian.color);
      }
    }

    if (showPoints) {
      for (final point in acupoints.where((item) => item.view == view)) {
        final isActive = point.id == activePointId;
        final center = Offset(point.x, point.y);
        if (isActive) {
          canvas.drawCircle(center, 25, Paint()..color = const Color(0xFFFFF4C2).withOpacity(0.25));
        }
        canvas.drawCircle(
          center,
          isActive ? 11 : 8,
          Paint()
            ..color = isActive ? const Color(0xFFFFE08A) : const Color(0xFFF4F7F3)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          isActive ? 11 : 8,
          Paint()
            ..color = isActive ? const Color(0xFFFFE08A) : const Color(0xFF34474C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
    canvas.restore();
  }

  Path _makePath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  void _drawFlow(Canvas canvas, List<Offset> originalPoints, Color color) {
    final points = reverse ? originalPoints.reversed.toList() : originalPoints;
    final lengths = <double>[];
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final length = (points[i + 1] - points[i]).distance;
      lengths.add(length);
      total += length;
    }
    if (total <= 0) return;

    for (var particle = 0; particle < 3; particle++) {
      final unit = (progress + particle / 3) % 1.0;
      var remaining = unit * total;
      var position = points.last;
      for (var i = 0; i < lengths.length; i++) {
        if (remaining <= lengths[i]) {
          final t = lengths[i] == 0 ? 0.0 : remaining / lengths[i];
          position = Offset.lerp(points[i], points[i + 1], t)!;
          break;
        }
        remaining -= lengths[i];
      }
      canvas.drawCircle(position, 20, Paint()..color = color.withOpacity(0.16));
      canvas.drawCircle(position, 8, Paint()..color = color.withOpacity(0.94));
      canvas.drawCircle(position, 3, Paint()..color = const Color(0xFFF4FBF7));
    }
  }

  void _drawSilhouette(Canvas canvas) {
    final bodyColor = const Color(0xFFD8E1DB).withOpacity(0.92);
    final shadowPaint = Paint()
      ..color = const Color(0xFF0A1114).withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    canvas.drawOval(const Rect.fromLTRB(414, 68, 586, 266).shift(const Offset(0, 12)), shadowPaint);

    final head = Path()..addOval(const Rect.fromLTRB(414, 68, 586, 266));
    final neck = Path()
      ..moveTo(452, 235)
      ..lineTo(548, 235)
      ..lineTo(565, 335)
      ..lineTo(435, 335)
      ..close();
    final torso = Path()
      ..moveTo(430, 300)
      ..cubicTo(385, 305, 350, 320, 320, 360)
      ..lineTo(300, 450)
      ..lineTo(345, 510)
      ..lineTo(370, 470)
      ..lineTo(380, 820)
      ..cubicTo(390, 900, 430, 940, 500, 945)
      ..cubicTo(570, 940, 610, 900, 620, 820)
      ..lineTo(630, 470)
      ..lineTo(655, 510)
      ..lineTo(700, 450)
      ..lineTo(680, 360)
      ..cubicTo(650, 320, 615, 305, 570, 300)
      ..cubicTo(535, 330, 465, 330, 430, 300)
      ..close();
    final leftArm = Path()
      ..moveTo(330, 355)
      ..cubicTo(290, 375, 275, 425, 260, 480)
      ..lineTo(220, 650)
      ..cubicTo(205, 695, 215, 735, 244, 748)
      ..cubicTo(270, 755, 286, 724, 284, 690)
      ..lineTo(325, 535)
      ..lineTo(375, 430)
      ..close();
    final rightArm = Path()
      ..moveTo(670, 355)
      ..cubicTo(710, 375, 725, 425, 740, 480)
      ..lineTo(780, 650)
      ..cubicTo(795, 695, 785, 735, 756, 748)
      ..cubicTo(730, 755, 714, 724, 716, 690)
      ..lineTo(675, 535)
      ..lineTo(625, 430)
      ..close();
    final leftLeg = Path()
      ..moveTo(410, 900)
      ..lineTo(495, 930)
      ..lineTo(480, 1190)
      ..lineTo(462, 1420)
      ..cubicTo(460, 1460, 440, 1482, 405, 1482)
      ..lineTo(360, 1482)
      ..cubicTo(350, 1478, 354, 1460, 366, 1445)
      ..lineTo(392, 1180)
      ..lineTo(370, 1010)
      ..close();
    final rightLeg = Path()
      ..moveTo(590, 900)
      ..lineTo(505, 930)
      ..lineTo(520, 1190)
      ..lineTo(538, 1420)
      ..cubicTo(540, 1460, 560, 1482, 595, 1482)
      ..lineTo(640, 1482)
      ..cubicTo(650, 1478, 646, 1460, 634, 1445)
      ..lineTo(608, 1180)
      ..lineTo(630, 1010)
      ..close();

    final silhouettePaint = Paint()..color = bodyColor;
    for (final path in [head, neck, torso, leftArm, rightArm, leftLeg, rightLeg]) {
      canvas.drawPath(path, shadowPaint);
      canvas.drawPath(path, silhouettePaint);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFF2F6F2).withOpacity(0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    if (view == 'front') {
      canvas.drawLine(const Offset(500, 340), const Offset(500, 920), Paint()
        ..color = const Color(0xFF879994).withOpacity(0.25)
        ..strokeWidth = 2);
    } else {
      canvas.drawLine(const Offset(500, 335), const Offset(500, 950), Paint()
        ..color = const Color(0xFF879994).withOpacity(0.25)
        ..strokeWidth = 2);
      canvas.drawLine(const Offset(432, 420), const Offset(420, 900), Paint()
        ..color = const Color(0xFF879994).withOpacity(0.18)
        ..strokeWidth = 2);
      canvas.drawLine(const Offset(568, 420), const Offset(580, 900), Paint()
        ..color = const Color(0xFF879994).withOpacity(0.18)
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _MeridianPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.view != view ||
        oldDelegate.reverse != reverse ||
        oldDelegate.showPoints != showPoints ||
        oldDelegate.activePointId != activePointId ||
        oldDelegate.meridians != meridians ||
        oldDelegate.acupoints != acupoints;
  }
}
