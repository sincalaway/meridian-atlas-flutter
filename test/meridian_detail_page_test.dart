import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/models/meridian.dart';
import 'package:meridian_atlas/pages/meridian_detail_page.dart';

void main() {
  final meridians = (jsonDecode(File('assets/data/meridians.json').readAsStringSync()) as List)
      .map((row) => Meridian.fromJson(row as Map<String, dynamic>))
      .toList();
  final acupoints = (jsonDecode(File('assets/data/acupoints.json').readAsStringSync()) as List)
      .map((row) => Acupoint.fromJson(row as Map<String, dynamic>))
      .toList();

  testWidgets('经络详情页展示说明与相关穴位，点选穴位返回结果', (tester) async {
    final li = meridians.firstWhere((m) => m.id == 'LI');
    Acupoint? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            picked = await Navigator.of(context).push<Acupoint>(MaterialPageRoute(
              builder: (_) => MeridianDetailPage(meridian: li, acupoints: acupoints, favoriteIds: const {}),
            ));
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(li.nameZh), findsOneWidget);
    expect(find.text('经络说明'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('合谷  LI4'), 200);
    await tester.tap(find.text('合谷  LI4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(picked?.code, 'LI4');
  });

  testWidgets('每条经络的详情页都能渲染', (tester) async {
    for (final meridian in meridians) {
      await tester.pumpWidget(MaterialApp(
        home: MeridianDetailPage(meridian: meridian, acupoints: acupoints, favoriteIds: const {}),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: meridian.id);
    }
  });
}
