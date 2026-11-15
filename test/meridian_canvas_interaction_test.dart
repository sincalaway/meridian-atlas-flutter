import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/models/meridian.dart';
import 'package:meridian_atlas/widgets/meridian_canvas.dart';

void main() {
  final meridians =
      (jsonDecode(File('assets/data/meridians.json').readAsStringSync())
              as List)
          .map((row) => Meridian.fromJson(row as Map<String, dynamic>))
          .toList();
  final point = Acupoint(
    id: 'test-point',
    nameZh: '测试穴位',
    pinyin: 'ceshi',
    code: 'T1',
    meridianId: 'LI',
    view: 'front',
    x: 0.5,
    y: 0.5,
    location: '测试定位',
    indications: const [],
    source: '测试数据',
    placements: const {
      'male': [Offset(424, 632)]
    },
  );

  Future<void> pumpCanvas(WidgetTester tester,
      {required bool showPoints, required ValueChanged<Acupoint> onTap}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 600,
            child: MeridianCanvas(
              meridians: [meridians.firstWhere((item) => item.id == 'LI')],
              acupoints: [point],
              view: 'front',
              animation: const AlwaysStoppedAnimation<double>(0),
              reverse: false,
              showPoints: showPoints,
              activePointId: point.id,
              interactive: false,
              onPointTap: onTap,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Offset pointPosition(WidgetTester tester) {
    final rect = tester.getRect(find.byType(MeridianCanvas));
    const imageWidth = 848.0;
    const imageHeight = 1264.0;
    const pointX = 424.0;
    const pointY = 632.0;
    final fit = math.min(rect.width / imageWidth, rect.height / imageHeight);
    final renderedWidth = imageWidth * fit;
    final renderedHeight = imageHeight * fit;
    return rect.topLeft +
        Offset(
          (rect.width - renderedWidth) / 2 + pointX * fit,
          (rect.height - renderedHeight) / 2 + pointY * fit,
        );
  }

  testWidgets('触摸穴位标记时调用穴位回调', (tester) async {
    Acupoint? tapped;
    await pumpCanvas(tester,
        showPoints: true, onTap: (value) => tapped = value);
    await tester.tapAt(pointPosition(tester));
    await tester.pump();
    expect(tapped?.id, point.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏穴位标记时画布不触发点选', (tester) async {
    Acupoint? tapped;
    await pumpCanvas(tester,
        showPoints: false, onTap: (value) => tapped = value);
    await tester.tapAt(pointPosition(tester));
    await tester.pump();
    expect(tapped, isNull);
    expect(tester.takeException(), isNull);
  });
}
