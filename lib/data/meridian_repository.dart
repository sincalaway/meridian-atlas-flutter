import 'dart:convert';

import 'package:flutter/services.dart';

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

  Future<({List<Meridian> meridians, List<Acupoint> acupoints})> loadAll() async {
    final results = await Future.wait([loadMeridians(), loadAcupoints()]);
    return (meridians: results[0] as List<Meridian>, acupoints: results[1] as List<Acupoint>);
  }
}
