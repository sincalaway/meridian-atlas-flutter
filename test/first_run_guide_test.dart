import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/theme/atlas_theme.dart';
import 'package:meridian_atlas/widgets/first_run_guide.dart';

void main() {
  testWidgets('三步引导可前进并在结束时关闭', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AtlasThemes.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => FirstRunGuide(
                onFinish: () => Navigator.of(dialogContext).pop(),
              ),
            ),
            child: const Text('open guide'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open guide'));
    await tester.pumpAndSettle();
    expect(find.text('先认识人体画布'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('搜索、收藏与比较'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('请把内容当作学习示意'), findsOneWidget);
    expect(find.textContaining('尚未完成专业校勘'), findsOneWidget);

    await tester.tap(find.text('开始探索'));
    await tester.pumpAndSettle();
    expect(find.text('使用指南'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
