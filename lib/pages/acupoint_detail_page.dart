import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/body_atlas.dart';
import '../models/meridian.dart';
import '../widgets/meridian_canvas.dart';

/// 穴位介绍页：底图上放大显示穴位位置 + 定位、分类、功效、主治、注意事项与资料来源。
class AcupointDetailPage extends StatefulWidget {
  const AcupointDetailPage({
    super.key,
    required this.point,
    required this.meridian,
    required this.acupoints,
    this.figure = 'male',
    this.isFavorite,
    this.onFavoriteToggle,
    this.onOpenMeridian,
  });

  final Acupoint point;
  final Meridian meridian;

  /// 同经穴位（用于画出所属经络）。
  final List<Acupoint> acupoints;
  final String figure;
  /// 判断某穴位是否已收藏；切换到同经其他穴位时也会用到。
  final bool Function(Acupoint point)? isFavorite;
  final ValueChanged<Acupoint>? onFavoriteToggle;
  final VoidCallback? onOpenMeridian;

  @override
  State<AcupointDetailPage> createState() => _AcupointDetailPageState();
}

class _AcupointDetailPageState extends State<AcupointDetailPage> with SingleTickerProviderStateMixin {
  late final AnimationController _flow =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
  final TransformationController _zoom = TransformationController();
  late bool _favorite = widget.isFavorite?.call(widget.point) ?? false;
  bool _zoomed = false;

  @override
  void dispose() {
    _flow.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _focusPoint(Size box) {
    if (_zoomed) return;
    final atlas = BodyAtlas.current;
    final fv = atlas?.viewOf(widget.figure, widget.point.view);
    final positions = widget.point.positionsFor(widget.figure);
    if (fv == null || positions.isEmpty) return;
    _zoomed = true;
    final fit = math.min(box.width / fv.width, box.height / fv.height);
    final ox = (box.width - fv.width * fit) / 2;
    final oy = (box.height - fv.height * fit) / 2;
    // 双侧穴取受试者右侧（正面在图左）作为焦点
    final p = positions.first;
    final target = Offset(ox + p.dx * fit, oy + p.dy * fit);
    const scale = 3.0;
    final tx = (box.width / 2 - target.dx * scale).clamp(box.width - box.width * scale, 0.0);
    final ty = (box.height / 2 - target.dy * scale).clamp(box.height - box.height * scale, 0.0);
    _zoom.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final color = widget.meridian.color;
    final hasPlacement = point.positionsFor(widget.figure).isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${point.nameZh} ${point.code}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (widget.onFavoriteToggle != null)
            IconButton(
              tooltip: _favorite ? '取消收藏' : '收藏穴位',
              onPressed: () {
                HapticFeedback.selectionClick();
                widget.onFavoriteToggle!(widget.point);
                setState(() => _favorite = !_favorite);
              },
              icon: Icon(_favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: _favorite ? const Color(0xFFE2C66E) : null),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.adjust_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(point.nameZh, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${point.pinyin} · ${point.code} · ${widget.meridian.nameZh}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFA8BDB5))),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            if (hasPlacement)
              Container(
                height: 340,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF121619),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.35)),
                ),
                child: Stack(children: [
                  Positioned.fill(
                    child: LayoutBuilder(builder: (context, c) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _focusPoint(c.biggest));
                      return MeridianCanvas(
                        meridians: [widget.meridian],
                        acupoints: widget.acupoints,
                        view: point.view,
                        figure: widget.figure,
                        animation: _flow,
                        reverse: false,
                        showPoints: true,
                        activePointId: point.id,
                        transformationController: _zoom,
                        labelMinScale: 2.5,
                        onPointTap: _openOther,
                      );
                    }),
                  ),
                  const Positioned(left: 10, top: 10, child: MeridianLineLegend()),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Text('${point.view == 'front' ? '正面' : '背面'} · 双指缩放 · 点其他穴位可切换 · 位置为示意',
                        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.55))),
                  ),
                ]),
              ),
            const SizedBox(height: 18),
            _section('定位', Text(point.location.isEmpty ? '资料未注明' : point.location, style: _body)),
            if (point.specialCategories.isNotEmpty)
              _section('特定穴分类', _chips(point.specialCategories, color)),
            if (point.efficacyTags.isNotEmpty) _section('功效（学习资料）', _chips(point.efficacyTags, color)),
            if (point.indications.isNotEmpty)
              _section(
                '主治（学习资料）',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: point.indications
                      .map((i) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text('· $i', style: _body),
                          ))
                      .toList(),
                ),
              ),
            if (point.cautions.isNotEmpty)
              _section(
                '注意事项',
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE2B86E)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(point.cautions, style: _body.copyWith(color: const Color(0xFFE2C99A)))),
                ]),
              ),
            _section(
              '资料来源',
              Text(point.source, style: TextStyle(fontSize: 11, height: 1.5, color: Colors.white.withOpacity(0.55))),
            ),
            if (widget.onOpenMeridian != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onOpenMeridian,
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: Text('查看${widget.meridian.nameZh}'),
                  style: TextButton.styleFrom(foregroundColor: color),
                ),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF211F19),
                border: Border.all(color: const Color(0xFF49402B)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '仅供学习参考，不作诊疗依据。图上位置按骨度分寸由体表标志推算，为示意位置；实际取穴请以教材与专业人员指导为准。',
                style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xFFC6B98F)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 在介绍页的图上点另一个穴位：直接换成该穴位的介绍页（替换当前页，返回仍回到上一级）。
  void _openOther(Acupoint other) {
    if (other.id == widget.point.id) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => AcupointDetailPage(
        point: other,
        meridian: widget.meridian,
        acupoints: widget.acupoints,
        figure: widget.figure,
        isFavorite: widget.isFavorite,
        onFavoriteToggle: widget.onFavoriteToggle,
        onOpenMeridian: widget.onOpenMeridian,
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 180),
    ));
  }

  static const _body = TextStyle(fontSize: 14, height: 1.6, color: Color(0xFFD5DFDA));

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9FB7AF))),
          const SizedBox(height: 6),
          child,
        ]),
      );

  Widget _chips(List<String> items, Color color) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items
            .map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(8)),
                  child: Text(t, style: const TextStyle(fontSize: 12, color: Color(0xFFDDE8E3))),
                ))
            .toList(),
      );
}
