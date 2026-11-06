import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/data/meridian_repository.dart';
import 'package:meridian_atlas/models/body_atlas.dart';
import 'package:meridian_atlas/models/meridian.dart';

void main() {
  test('每个穴位在男女底图上都有位置，且在图片范围内', () {
    final atlas = BodyAtlas.fromJson(
        jsonDecode(File('assets/data/body_positions.json').readAsStringSync()) as Map<String, dynamic>);
    final points = (jsonDecode(File('assets/data/acupoints.json').readAsStringSync()) as List)
        .map((row) => Acupoint.fromJson(row as Map<String, dynamic>))
        .toList();
    final merged = MeridianRepository.applyAtlas(points, atlas);
    for (final p in merged) {
      for (final figure in const ['male', 'female']) {
        final pos = p.positionsFor(figure);
        expect(pos, isNotEmpty, reason: '${p.code} $figure');
        final fv = atlas.viewOf(figure, p.view)!;
        expect(File(fv.image).existsSync(), isTrue);
        for (final o in pos) {
          expect(o.dx, inInclusiveRange(0, fv.width), reason: p.code);
          expect(o.dy, inInclusiveRange(0, fv.height), reason: p.code);
        }
      }
      final midline = p.code.startsWith('CV') || p.code.startsWith('GV');
      expect(p.positionsFor('male').length, midline ? 1 : 2, reason: p.code);
    }
  });
}
