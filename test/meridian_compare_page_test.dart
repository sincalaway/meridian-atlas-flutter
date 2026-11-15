import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/models/meridian.dart';
import 'package:meridian_atlas/pages/meridian_compare_page.dart';

void main() {
  final meridians =
      (jsonDecode(File('assets/data/meridians.json').readAsStringSync())
              as List)
          .map((row) => Meridian.fromJson(row as Map<String, dynamic>))
          .toList();
  final acupoints =
      (jsonDecode(File('assets/data/acupoints.json').readAsStringSync())
              as List)
          .map((row) => Acupoint.fromJson(row as Map<String, dynamic>))
          .toList();
  Meridian byId(String id) => meridians.firstWhere((m) => m.id == id);

  test('对照表区分资料记录数、底图定位数和数据路径顺序', () {
    final rows =
        MeridianComparePage.comparisonRows(byId('LU'), byId('BL'), acupoints);
    expect(rows.first, ('国际代码', 'LU', 'BL'));
    final group = rows.firstWhere((r) => r.$1 == '手足分类');
    expect(group.$2, '手经');
    expect(group.$3, '足经');
    final records = rows.firstWhere((r) => r.$1 == '穴位资料记录');
    expect(
        records.$2, '${acupoints.where((p) => p.meridianId == 'LU').length}');
    final located = rows.firstWhere((r) => r.$1 == '当前底图可定位');
    // 此处传入的是未经 BodyAtlas 合并的原始 JSON 穴位，定位数应如实为 0。
    expect(located.$2, '0');

    final orderRows =
        MeridianComparePage.comparisonRows(byId('SP'), byId('LU'), acupoints);
    final order = orderRows.firstWhere((r) => r.$1 == '动画基准（数据顺序）');
    expect(order.$2, '穴序逆序');
    expect(order.$3, '穴序顺序');
  });

  testWidgets('打开对比页，切换叠加与交换经络', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: MeridianComparePage(
        meridians: meridians,
        acupoints: acupoints,
        initialLeftId: 'LI',
        initialRightId: 'ST',
      ),
    ));
    await tester.pump();
    expect(find.text('经络对比'), findsOneWidget);
    expect(find.text('属性对照'), findsOneWidget);
    expect(find.text('LI'), findsWidgets);

    await tester.tap(find.byTooltip('叠加显示'));
    await tester.pump();
    expect(find.byTooltip('并排显示'), findsOneWidget);

    await tester.tap(find.byTooltip('交换'));
    await tester.pump();
    final table = tester.widget<Table>(find.byType(Table));
    final header = table.children.first.children;
    expect((header[1] as Text).data, byId('ST').nameZh);
    expect((header[2] as Text).data, byId('LI').nameZh);

    await tester.tap(find.text('背面'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('路线有示意数据但无底图定位时，显示回退提示', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MeridianComparePage(
        meridians: meridians.take(2).toList(),
        acupoints: const [],
      ),
    ));
    await tester.pump();
    expect(find.textContaining('预置示意路线'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('不足两条经络时显示对比空态', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MeridianComparePage(meridians: const [], acupoints: const []),
    ));
    await tester.pump();
    expect(find.text('至少需要两条经络数据才能进行对比。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('任意两条经络组合都能渲染', (tester) async {
    for (final a in meridians) {
      final b = meridians.firstWhere((m) => m.id != a.id);
      await tester.pumpWidget(MaterialApp(
        home: MeridianComparePage(
          meridians: meridians,
          acupoints: acupoints,
          initialLeftId: a.id,
          initialRightId: b.id,
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${a.id}-${b.id}');
    }
  });
}
