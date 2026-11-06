import 'package:flutter/material.dart';

/// 写实人体底图（男/女 × 正/背面）及穴位在底图上的位置（图片像素坐标）。
///
/// 位置由 `tool/body_atlas/` 按骨度分寸从解剖标志点推算，属学习示意，非精确体表定位。
class BodyFigureView {
  const BodyFigureView({required this.image, required this.width, required this.height});

  final String image;
  final double width;
  final double height;

  double get aspectRatio => width / height;

  factory BodyFigureView.fromJson(Map<String, dynamic> json) => BodyFigureView(
        image: json['image'] as String,
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

class PointPlacement {
  const PointPlacement({required this.view, required this.byFigure});

  final String view;

  /// figure id ('male' / 'female') -> 1 个（正中线穴）或 2 个（双侧穴）位置。
  final Map<String, List<Offset>> byFigure;

  factory PointPlacement.fromJson(Map<String, dynamic> json) {
    final map = <String, List<Offset>>{};
    for (final entry in json.entries) {
      if (entry.key == 'view') continue;
      map[entry.key] = (entry.value as List<dynamic>)
          .map((p) => Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList(growable: false);
    }
    return PointPlacement(view: json['view'] as String, byFigure: map);
  }
}

class BodyAtlas {
  const BodyAtlas({required this.figures, required this.placements, required this.note});

  /// figure -> view -> 底图
  final Map<String, Map<String, BodyFigureView>> figures;
  final Map<String, PointPlacement> placements;
  final String note;

  static const figureLabels = {'male': '男', 'female': '女'};

  /// 应用启动时由仓库加载后设置；组件测试中可能为空。
  static BodyAtlas? current;

  BodyFigureView? viewOf(String figure, String view) => figures[figure]?[view];

  factory BodyAtlas.fromJson(Map<String, dynamic> json) {
    final figures = <String, Map<String, BodyFigureView>>{};
    (json['figures'] as Map<String, dynamic>).forEach((figure, views) {
      figures[figure] = (views as Map<String, dynamic>).map(
        (view, v) => MapEntry(view, BodyFigureView.fromJson(v as Map<String, dynamic>)),
      );
    });
    final placements = (json['points'] as Map<String, dynamic>).map(
      (code, v) => MapEntry(code, PointPlacement.fromJson(v as Map<String, dynamic>)),
    );
    return BodyAtlas(figures: figures, placements: placements, note: json['note'] as String? ?? '');
  }
}
