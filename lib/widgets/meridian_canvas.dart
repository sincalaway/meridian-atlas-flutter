import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../models/body_atlas.dart';
import '../models/meridian.dart';

/// 写实人体底图 + 经络流动 + 穴位标记。支持双指缩放/拖动，放大后显示穴名，轻触穴位回调。
///
/// 经络线按穴序连接同一视图内相邻的穴位（双侧分别连线），属学习示意。
class MeridianCanvas extends StatefulWidget {
  const MeridianCanvas({
    super.key,
    required this.meridians,
    required this.acupoints,
    required this.view,
    required this.animation,
    required this.reverse,
    required this.showPoints,
    required this.activePointId,
    this.figure = 'male',
    this.onPointTap,
    this.interactive = true,
    this.atlas,
    this.labelMinScale = 1.5,
    this.transformationController,
  });

  final List<Meridian> meridians;

  /// 已按选中经络过滤的穴位（可含其他视图的穴位，组件内按视图过滤）。
  final List<Acupoint> acupoints;
  final String view;
  final String figure;
  final Animation<double> animation;
  final bool reverse;
  final bool showPoints;
  final String? activePointId;
  final ValueChanged<Acupoint>? onPointTap;
  final bool interactive;
  final BodyAtlas? atlas;

  /// 缩放倍数达到该值后显示全部穴名（选中的穴位始终显示）。
  final double labelMinScale;
  final TransformationController? transformationController;

  @override
  State<MeridianCanvas> createState() => _MeridianCanvasState();
}

class _MeridianCanvasState extends State<MeridianCanvas> {
  TransformationController? _ownController;

  TransformationController get _controller =>
      widget.transformationController ?? (_ownController ??= TransformationController());

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  BodyAtlas? get _atlas => widget.atlas ?? BodyAtlas.current;

  @override
  void didUpdateWidget(covariant MeridianCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view || oldWidget.figure != widget.figure) {
      _controller.value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    final figureView = _atlas?.viewOf(widget.figure, widget.view);
    return LayoutBuilder(builder: (context, constraints) {
      final imgW = figureView?.width ?? 848;
      final imgH = figureView?.height ?? 1264;
      final fit = math.min(constraints.maxWidth / imgW, constraints.maxHeight / imgH);
      final w = imgW * fit;
      final h = imgH * fit;
      final points = widget.acupoints
          .where((p) => p.view == widget.view && p.positionsFor(widget.figure).isNotEmpty)
          .toList(growable: false);

      final content = SizedBox(
        width: w,
        height: h,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details.localPosition / fit, points, fit),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (figureView != null)
                Image.asset(
                  figureView.image,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _AtlasPainter(
                    repaint: Listenable.merge([widget.animation, _controller]),
                    animation: widget.animation,
                    controller: _controller,
                    fit: fit,
                    figure: widget.figure,
                    view: widget.view,
                    meridians: widget.meridians,
                    allPoints: widget.acupoints,
                    points: points,
                    reverse: widget.reverse,
                    showPoints: widget.showPoints,
                    activePointId: widget.activePointId,
                    labelMinScale: widget.labelMinScale,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (!widget.interactive) return Center(child: content);
      return InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 8,
        boundaryMargin: const EdgeInsets.all(40),
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Center(child: content),
        ),
      );
    });
  }

  void _handleTap(Offset imagePos, List<Acupoint> points, double fit) {
    if (!widget.showPoints || widget.onPointTap == null) return;
    final zoom = _controller.value.getMaxScaleOnAxis();
    final radius = 24 / (fit * zoom); // 24 屏幕像素
    Acupoint? nearest;
    var best = double.infinity;
    for (final p in points) {
      for (final pos in p.positionsFor(widget.figure)) {
        final d = (pos - imagePos).distance;
        if (d < best) {
          best = d;
          nearest = p;
        }
      }
    }
    if (nearest != null && best <= radius) widget.onPointTap!(nearest);
  }
}

class _AtlasPainter extends CustomPainter {
  _AtlasPainter({
    required Listenable repaint,
    required this.animation,
    required this.controller,
    required this.fit,
    required this.figure,
    required this.view,
    required this.meridians,
    required this.allPoints,
    required this.points,
    required this.reverse,
    required this.showPoints,
    required this.activePointId,
    required this.labelMinScale,
  }) : super(repaint: repaint);

  final Animation<double> animation;
  final TransformationController controller;
  final double fit;
  final String figure;
  final String view;
  final List<Meridian> meridians;
  final List<Acupoint> allPoints;
  final List<Acupoint> points;
  final bool reverse;
  final bool showPoints;
  final String? activePointId;
  final double labelMinScale;

  static final Map<String, TextPainter> _labelCache = {};

  // 连线与路径度量在画家实例内缓存；动画/缩放触发的重绘只更新粒子位置与线宽。
  late final List<(Color, Path, List<PathMetric>)> _paths = [
    for (final meridian in meridians)
      for (final run in _runs(meridian))
        (meridian.color, _smooth(run), _smooth(run).computeMetrics().toList(growable: false)),
  ];

  /// 跨视图的「过渡」虚线：两穴都在本视图，但中间隔了 1–3 个位于另一面的穴位
  /// （如大肠经 臂臑 → 肩髃（正面）→ 巨骨），最多跨 3 穴，用虚线表示经络绕到另一面再回来。
  late final List<(Color, Offset, Offset)> _bridges = [
    for (final meridian in meridians) ..._bridgesOf(meridian),
  ];

  List<(Color, Offset, Offset)> _bridgesOf(Meridian meridian) {
    final seq = allPoints.where((p) => p.meridianId == meridian.id).toList()
      ..sort((a, b) => _codeNumber(a.code).compareTo(_codeNumber(b.code)));
    final out = <(Color, Offset, Offset)>[];
    Acupoint? last;
    var skipped = 0;
    for (final p in seq) {
      if (p.positionsFor(figure).isEmpty) continue;
      if (p.view != view) {
        if (last != null) skipped++;
        continue;
      }
      if (_restartAt.contains(p.code)) last = null;
      if (last != null && skipped > 0 && skipped <= 3) {
        final a = last.positionsFor(figure);
        final b = p.positionsFor(figure);
        final n = math.min(a.length, b.length);
        for (var i = 0; i < n; i++) {
          out.add((meridian.color, a[i], b[i]));
        }
      }
      last = p;
      skipped = 0;
    }
    return out;
  }

  /// 经络循行中穴序相邻却不相连的地方：从这个穴位起另起一段。
  /// 膀胱经：委中（BL40）之后，第二侧线从附分（BL41）在背部重新开始。
  static const _restartAt = {'BL41'};

  /// 穴序相邻但循行要经过前面某穴：秩边（BL54）下行经委中（BL40）与第一侧线会合，再到合阳（BL55）。
  static const _via = {'BL55': 'BL40'};

  /// 穴序号；国标新增穴（如印堂 GV24+）排在 GV24 之后、GV25 之前。
  static double _codeNumber(String code) {
    final match = RegExp(r'(\d+)(\+?)').firstMatch(code);
    if (match == null) return 0;
    return int.parse(match.group(1)!) + (match.group(2)!.isEmpty ? 0 : 0.5);
  }

  /// 每条经络在本视图内的连线段：同侧、穴序连续且都在本视图的穴位连成一段。
  List<List<Offset>> _runs(Meridian meridian) {
    final seq = allPoints.where((p) => p.meridianId == meridian.id).toList()
      ..sort((a, b) => _codeNumber(a.code).compareTo(_codeNumber(b.code)));
    final runs = <List<Offset>>[];
    for (var side = 0; side < 2; side++) {
      var current = <Offset>[];
      var bilateral = false;
      for (final p in seq) {
        final pos = p.positionsFor(figure);
        if (p.view != view || pos.isEmpty) {
          if (current.length > 1) runs.add(current);
          current = <Offset>[];
          continue;
        }
        if (_restartAt.contains(p.code)) {
          if (current.length > 1) runs.add(current);
          current = <Offset>[];
        }
        final viaCode = _via[p.code];
        if (viaCode != null && current.isNotEmpty) {
          final via = seq.where((q) => q.code == viaCode && q.view == view).firstOrNull;
          final vp = via?.positionsFor(figure) ?? const <Offset>[];
          if (vp.isNotEmpty) current.add(vp[math.min(side, vp.length - 1)]);
        }
        if (pos.length > 1) bilateral = true;
        current.add(pos[math.min(side, pos.length - 1)]);
      }
      if (current.length > 1) runs.add(current);
      if (!bilateral) break; // 正中线经络只画一次
    }
    return runs;
  }

  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) return path..lineTo(pts[1].dx, pts[1].dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = controller.value.getMaxScaleOnAxis();
    final px = 1 / (fit * zoom); // 1 屏幕像素对应的图片像素
    canvas.save();
    canvas.scale(fit);

    for (final (color, a, b) in _bridges) {
      final d = b - a;
      final len = d.distance;
      if (len == 0) continue;
      final dash = 6 * px, gap = 5 * px;
      final paint = Paint()
        ..color = color.withOpacity(0.8)
        ..strokeWidth = 1.8 * px
        ..strokeCap = StrokeCap.round;
      for (var t = 0.0; t < len; t += dash + gap) {
        final e = math.min(t + dash, len);
        canvas.drawLine(a + d * (t / len), a + d * (e / len), paint);
      }
    }

    for (final (color, path, metrics) in _paths) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * px
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * px
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      _drawFlow(canvas, metrics, color, px);
    }

    if (showPoints) {
      final colorOf = {for (final m in meridians) m.id: m.color};
      Acupoint? active;
      for (final p in points) {
        if (p.id == activePointId) {
          active = p;
          continue;
        }
        final c = colorOf[p.meridianId] ?? Colors.white;
        for (final pos in p.positionsFor(figure)) {
          canvas.drawCircle(pos, 4.2 * px, Paint()..color = const Color(0xFF0E1A1C).withOpacity(0.85));
          canvas.drawCircle(pos, 3.0 * px, Paint()..color = Color.lerp(c, Colors.white, 0.55)!);
        }
      }
      if (active != null) {
        for (final pos in active.positionsFor(figure)) {
          canvas.drawCircle(pos, 14 * px, Paint()..color = const Color(0xFFFFE08A).withOpacity(0.28));
          canvas.drawCircle(pos, 5.5 * px, Paint()..color = const Color(0xFFFFE08A));
          canvas.drawCircle(
              pos,
              5.5 * px,
              Paint()
                ..color = const Color(0xFF3B2F0B)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2 * px);
        }
      }
      _drawLabels(canvas, zoom, px, active);
    }
    canvas.restore();
  }

  void _drawLabels(Canvas canvas, double zoom, double px, Acupoint? active) {
    final showAll = zoom >= labelMinScale;
    final candidates = <Acupoint>[
      if (active != null) active,
      if (showAll) ...points.where((p) => p.id != active?.id),
    ];
    final placed = <Rect>[];
    for (final p in candidates) {
      final isActive = p.id == active?.id;
      final tp = _labelCache.putIfAbsent(
        '${p.nameZh}|$isActive',
        () => TextPainter(
          text: TextSpan(
            text: p.nameZh,
            style: TextStyle(
              fontSize: isActive ? 13 : 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFF2A2006) : const Color(0xFFF3F7F4),
              height: 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      for (final pos in p.positionsFor(figure)) {
        // 依次尝试右上、右、左上、左、正上、正下、右下、左下，选第一个不与已放标签/其他穴位点重叠的位置
        final w = (tp.width + 8) * px;
        final h = (tp.height + 4) * px;
        final gap = 6 * px;
        final candidates = [
          Offset(pos.dx + gap, pos.dy - h - 2 * px),
          Offset(pos.dx + gap, pos.dy - h / 2),
          Offset(pos.dx - gap - w, pos.dy - h - 2 * px),
          Offset(pos.dx - gap - w, pos.dy - h / 2),
          Offset(pos.dx - w / 2, pos.dy - h - gap),
          Offset(pos.dx - w / 2, pos.dy + gap),
          Offset(pos.dx + gap, pos.dy + 2 * px),
          Offset(pos.dx - gap - w, pos.dy + 2 * px),
        ];
        Rect? rect;
        for (final c in candidates) {
          final r = Rect.fromLTWH(c.dx, c.dy, w, h);
          if (isActive || !placed.any((o) => o.overlaps(r))) {
            rect = r;
            break;
          }
        }
        // 实在放不下（点太密）时仍画在右上方，保证每个穴位都有名字；继续放大即可分开
        rect ??= Rect.fromLTWH(candidates.first.dx, candidates.first.dy, w, h);
        placed.add(rect);
        canvas.drawLine(
          pos,
          Offset(pos.dx < rect.left ? rect.left : (pos.dx > rect.right ? rect.right : pos.dx),
              pos.dy < rect.top ? rect.top : (pos.dy > rect.bottom ? rect.bottom : pos.dy)),
          Paint()
            ..color = const Color(0x99FFFFFF)
            ..strokeWidth = 0.8 * px,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(4 * px)),
          Paint()..color = isActive ? const Color(0xFFFFE08A) : const Color(0xCC0D1719),
        );
        canvas.save();
        canvas.translate(rect.left + 4 * px, rect.top + 2 * px);
        canvas.scale(px);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  void _drawFlow(Canvas canvas, List<PathMetric> metrics, Color color, double px) {
    for (final metric in metrics) {
      final total = metric.length;
      if (total <= 0) continue;
      final count = math.max(1, (total / 160).round());
      for (var i = 0; i < count; i++) {
        var unit = (animation.value + i / count) % 1.0;
        if (reverse) unit = 1 - unit;
        final tangent = metric.getTangentForOffset(unit * total);
        if (tangent == null) continue;
        final pos = tangent.position;
        canvas.drawCircle(pos, 9 * px, Paint()..color = color.withOpacity(0.18));
        canvas.drawCircle(pos, 3.6 * px, Paint()..color = color);
        canvas.drawCircle(pos, 1.4 * px, Paint()..color = const Color(0xFFF4FBF7));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtlasPainter old) {
    return old.view != view ||
        old.figure != figure ||
        old.fit != fit ||
        old.reverse != reverse ||
        old.showPoints != showPoints ||
        old.activePointId != activePointId ||
        old.meridians != meridians ||
        old.points != points ||
        old.allPoints != allPoints;
  }
}
