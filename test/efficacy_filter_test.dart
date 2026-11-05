import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/models/meridian.dart';
import 'package:meridian_atlas/widgets/acupoint_search_panel.dart';

// 测试夹具使用中性占位标签，不代表任何真实穴位功效。
Acupoint _point(String id, List<String> tags) => Acupoint(
      id: id,
      nameZh: '测试$id',
      pinyin: 'ceshi$id',
      code: 'T$id',
      meridianId: 'LI',
      view: 'front',
      x: 0,
      y: 0,
      location: '',
      indications: const [],
      efficacyTags: tags,
      source: '测试',
    );

void main() {
  final points = [
    _point('1', ['标签A', '标签B']),
    _point('2', ['标签B']),
    _point('3', []),
  ];

  test('可用标签按出现次数排序并去空白', () {
    expect(AcupointSearchPanel.availableEfficacyTags([
      ...points,
      _point('4', [' 标签B ', '']),
    ]), ['标签B', '标签A']);
  });

  test('超长功效描述不进筛选列表，但仍可命中筛选', () {
    final longTag = '标签' * 5; // 10 个字，超过上限
    final withLong = _point('5', ['标签A', longTag]);
    expect(AcupointSearchPanel.availableEfficacyTags([withLong]), ['标签A']);
    expect(AcupointSearchPanel.matchesEfficacy(withLong, {'标签A'}), isTrue);
  });

  test('未选标签时全部通过，选中后按任一命中筛选', () {
    expect(points.where((p) => AcupointSearchPanel.matchesEfficacy(p, {})).length, 3);
    expect(points.where((p) => AcupointSearchPanel.matchesEfficacy(p, {'标签A'})).map((p) => p.id), ['1']);
    expect(points.where((p) => AcupointSearchPanel.matchesEfficacy(p, {'标签A', '标签B'})).map((p) => p.id), ['1', '2']);
  });

  testWidgets('无标签数据时显示待录入提示', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AcupointSearchPanel(
            points: [_point('3', [])],
            meridians: const [],
            controller: TextEditingController(),
            query: '',
            onQueryChanged: (_) {},
            selectedMeridianId: 'all',
            onMeridianChanged: (_) {},
            favoritesOnly: false,
            onFavoritesOnlyChanged: (_) {},
            favoriteIds: const {},
            favoritesReady: true,
            onFavoriteToggle: (_) {},
            onPointSelected: (_) {},
          ),
        ),
      ),
    ));
    expect(find.textContaining('功效标签尚未录入'), findsOneWidget);
  });
}
