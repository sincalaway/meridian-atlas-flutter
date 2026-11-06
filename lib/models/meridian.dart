import 'package:flutter/material.dart';

class MeridianRoute {
  const MeridianRoute({required this.view, required this.points});

  final String view;
  final List<Offset> points;

  factory MeridianRoute.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List<dynamic>? ?? const []);
    return MeridianRoute(
      view: json['view'] as String? ?? 'front',
      points: rawPoints.map((point) {
        final pair = point as List<dynamic>;
        return Offset(
          (pair[0] as num).toDouble(),
          (pair[1] as num).toDouble(),
        );
      }).toList(growable: false),
    );
  }
}

class Meridian {
  const Meridian({
    required this.id,
    required this.nameZh,
    required this.pinyin,
    required this.code,
    required this.colorHex,
    required this.group,
    required this.yinYang,
    required this.direction,
    required this.routes,
    required this.summary,
    required this.source,
  });

  final String id;
  final String nameZh;
  final String pinyin;
  final String code;
  final String colorHex;
  final String group;
  final String yinYang;
  final String direction;
  final List<MeridianRoute> routes;
  final String summary;
  final String source;

  Color get color {
    final value = int.tryParse(colorHex.replaceFirst('#', ''), radix: 16) ?? 0xFF76C7C0;
    return Color(0xFF000000 | value);
  }

  factory Meridian.fromJson(Map<String, dynamic> json) {
    return Meridian(
      id: json['id'] as String,
      nameZh: json['nameZh'] as String,
      pinyin: json['pinyin'] as String? ?? '',
      code: json['code'] as String,
      colorHex: json['color'] as String? ?? '#76C7C0',
      group: json['group'] as String? ?? 'hand',
      yinYang: json['yinYang'] as String? ?? '',
      direction: json['direction'] as String? ?? 'forward',
      routes: (json['routes'] as List<dynamic>? ?? const [])
          .map((item) => MeridianRoute.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      summary: json['summary'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}

class Acupoint {
  const Acupoint({
    required this.id,
    required this.nameZh,
    required this.pinyin,
    required this.code,
    required this.meridianId,
    required this.view,
    required this.x,
    required this.y,
    required this.location,
    required this.indications,
    this.efficacyTags = const [],
    this.specialCategories = const [],
    this.cautions = '',
    required this.source,
    this.placements = const {},
  });

  final String id;
  final String nameZh;
  final String pinyin;
  final String code;
  final String meridianId;
  final String view;
  final double x;
  final double y;
  final String location;
  final List<String> indications;

  /// 功效分类标签（如按教材主治归类后的短标签），用于「按功效筛选」。
  /// 必须来自经审校的资料；为空表示尚未录入。
  final List<String> efficacyTags;

  /// 特定穴分类（如原穴、合穴、四总穴）。
  final List<String> specialCategories;

  /// 注意事项（如孕妇慎用）；为空表示资料未注明。
  final String cautions;
  final String source;

  /// 写实底图上的位置：figure ('male'/'female') -> 1~2 个图片像素坐标。
  /// 由 [BodyAtlas] 合并；为空表示尚无底图定位。
  final Map<String, List<Offset>> placements;

  List<Offset> positionsFor(String figure) => placements[figure] ?? const [];

  Acupoint withPlacement(String newView, Map<String, List<Offset>> newPlacements) => Acupoint(
        id: id,
        nameZh: nameZh,
        pinyin: pinyin,
        code: code,
        meridianId: meridianId,
        view: newView,
        x: x,
        y: y,
        location: location,
        indications: indications,
        efficacyTags: efficacyTags,
        specialCategories: specialCategories,
        cautions: cautions,
        source: source,
        placements: newPlacements,
      );

  factory Acupoint.fromJson(Map<String, dynamic> json) {
    final coordinate = json['coordinate'] as Map<String, dynamic>;
    return Acupoint(
      id: json['id'] as String,
      nameZh: json['nameZh'] as String,
      pinyin: json['pinyin'] as String? ?? '',
      code: json['code'] as String,
      meridianId: json['meridianId'] as String,
      view: json['view'] as String? ?? 'front',
      x: (coordinate['x'] as num).toDouble(),
      y: (coordinate['y'] as num).toDouble(),
      location: json['location'] as String? ?? '',
      indications: (json['indications'] as List<dynamic>? ?? const []).cast<String>(),
      efficacyTags: (json['efficacyTags'] as List<dynamic>? ?? const []).cast<String>(),
      specialCategories: (json['specialCategories'] as List<dynamic>? ?? const []).cast<String>(),
      cautions: json['cautions'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}
