import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/models/meridian.dart';
import 'package:meridian_atlas/widgets/acupoint_search_panel.dart';

void main() {
  final meridianIds = (jsonDecode(File('assets/data/meridians.json').readAsStringSync()) as List)
      .map((row) => (row as Map<String, dynamic>)['id'] as String)
      .toSet();
  final points = (jsonDecode(File('assets/data/acupoints.json').readAsStringSync()) as List)
      .map((row) => Acupoint.fromJson(row as Map<String, dynamic>))
      .toList();

  test('导入的穴位数据完整：编号唯一、经络存在、坐标在画布内、有出处', () {
    expect(points.length, 362);
    expect(points.map((p) => p.id).toSet().length, points.length);
    for (final p in points) {
      expect(meridianIds, contains(p.meridianId), reason: p.code);
      expect(p.x, inInclusiveRange(0, 1000), reason: p.code);
      expect(p.y, inInclusiveRange(0, 1600), reason: p.code);
      if (p.code == 'GV24+') {
        // 国标 2021 新增的印堂：只有定位，功效主治暂未收录
        expect(p.source, contains('GB/T 12346-2021'));
        continue;
      }
      expect(p.efficacyTags, isNotEmpty, reason: p.code);
      expect(p.source, anyOf(contains('CC BY-SA 4.0'), contains('CC BY 4.0')), reason: p.code);
    }
    // 本草典 208 穴 + AcuAtlas 补全 153 穴 + 国标印堂
    expect(points.where((p) => p.source.contains('AcuAtlas')).length, 153);
    // 14 条经络都有穴位
    expect(points.map((p) => p.meridianId).toSet(), meridianIds);
  });

  test('功效标签数量较多时，折叠只显示前 N 个且保留已选标签', () {
    final tags = AcupointSearchPanel.availableEfficacyTags(points);
    expect(tags.length, greaterThan(16));
    final last = tags.last;
    final collapsed = EfficacyTagPicker.visibleTags(
        tags: tags, selected: {last}, expanded: false, keyword: '', collapsedCount: 16);
    expect(collapsed.length, 17);
    expect(collapsed, contains(last));
    final filtered = EfficacyTagPicker.visibleTags(
        tags: tags, selected: const {}, expanded: true, keyword: '安神', collapsedCount: 16);
    expect(filtered, isNotEmpty);
    expect(filtered.every((t) => t.contains('安神')), isTrue);
  });

  testWidgets('展开全部后可过滤功效标签', (tester) async {
    // 测试夹具使用中性占位标签，不代表任何真实穴位功效。
    final fixture = List.generate(
      20,
      (i) => Acupoint(
        id: 'T$i', nameZh: '测试$i', pinyin: 'ceshi', code: 'T$i', meridianId: 'LI',
        view: 'front', x: 0, y: 0, location: '', indications: const [],
        efficacyTags: ['标签$i'], source: '测试',
      ),
    );
    final tags = AcupointSearchPanel.availableEfficacyTags(fixture);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EfficacyTagPicker(tags: tags, selected: const {}, onToggled: (_) {}),
        ),
      ),
    ));
    expect(find.byType(FilterChip), findsNWidgets(16));
    await tester.tap(find.text('展开全部 20 个标签'));
    await tester.pump();
    expect(find.byType(FilterChip), findsNWidgets(20));
    await tester.enterText(find.byType(TextField), '标签19');
    await tester.pump();
    expect(find.byType(FilterChip), findsOneWidget);
  });
}
