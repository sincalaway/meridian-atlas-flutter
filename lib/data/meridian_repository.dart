import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/body_atlas.dart';
import '../models/meridian.dart';

class MeridianRepository {
  const MeridianRepository();

  Future<List<Meridian>> loadMeridians() async {
    final raw = await rootBundle.loadString('assets/data/meridians.json');
    final rows = jsonDecode(raw) as List<dynamic>;
    return rows
        .map((row) => Meridian.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Acupoint>> loadAcupoints() async {
    final raw = await rootBundle.loadString('assets/data/acupoints.json');
    final rows = jsonDecode(raw) as List<dynamic>;
    return rows
        .map((row) => Acupoint.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<BodyAtlas> loadBodyAtlas() async {
    final raw = await rootBundle.loadString('assets/data/body_positions.json');
    return BodyAtlas.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// 把底图定位合并进穴位（视图以底图定位为准）。
  static List<Acupoint> applyAtlas(List<Acupoint> points, BodyAtlas atlas) {
    return points.map((point) {
      final placement = atlas.placements[point.code];
      if (placement == null) return point;
      return point.withPlacement(placement.view, placement.byFigure);
    }).toList(growable: false);
  }

  Future<({List<Meridian> meridians, List<Acupoint> acupoints})> loadAll() async {
    final results = await Future.wait([loadMeridians(), loadAcupoints(), loadBodyAtlas()]);
    final atlas = results[2] as BodyAtlas;
    BodyAtlas.current = atlas;
    return (
      meridians: results[0] as List<Meridian>,
      acupoints: applyAtlas(results[1] as List<Acupoint>, atlas),
    );
  }
}
