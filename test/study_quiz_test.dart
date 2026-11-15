import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/models/meridian.dart';
import 'package:meridian_atlas/models/study_quiz.dart';
import 'package:meridian_atlas/pages/study_quiz_page.dart';
import 'package:meridian_atlas/theme/atlas_theme.dart';

void main() {
  late List<Meridian> meridians;
  late List<Acupoint> acupoints;

  setUpAll(() {
    meridians =
        (jsonDecode(File('assets/data/meridians.json').readAsStringSync())
                as List)
            .map((row) => Meridian.fromJson(row as Map<String, dynamic>))
            .toList();
    acupoints =
        (jsonDecode(File('assets/data/acupoints.json').readAsStringSync())
                as List)
            .map((row) => Acupoint.fromJson(row as Map<String, dynamic>))
            .toList();
  });

  test('练习题的答案与选项均可由现有名称、代码和所属关系推出', () {
    final questions = StudyQuiz.generateQuestions(
      meridians: meridians,
      acupoints: acupoints,
      count: 15,
      random: Random(7),
    );
    final meridianById = {for (final item in meridians) item.id: item};
    final meridianNames = meridians.map((item) => item.nameZh).toSet();
    final meridianCodes = meridians.map((item) => item.code).toSet();
    final pointNames = acupoints.map((item) => item.nameZh).toSet();

    expect(questions, hasLength(15));
    expect(questions.map((question) => question.prompt).toSet(), hasLength(15));
    for (final question in questions) {
      expect(question.options, hasLength(4));
      expect(question.options.toSet(), hasLength(4));
      expect(question.options, contains(question.correctAnswer));
      switch (question.kind) {
        case QuizQuestionKind.pointMeridian:
          final point = question.point!;
          final meridian = meridianById[point.meridianId]!;
          expect(question.meridian?.id, meridian.id);
          expect(question.correctAnswer, meridian.nameZh);
          expect(question.options.toSet().difference(meridianNames), isEmpty);
          expect(question.prompt, contains(point.nameZh));
          expect(question.prompt, contains(point.code));
        case QuizQuestionKind.meridianCode:
          final meridian = question.meridian!;
          expect(question.correctAnswer, meridian.code);
          expect(question.options.toSet().difference(meridianCodes), isEmpty);
          expect(question.prompt, contains(meridian.nameZh));
        case QuizQuestionKind.pointName:
          final point = question.point!;
          expect(question.correctAnswer, point.nameZh);
          expect(question.options.toSet().difference(pointNames), isEmpty);
          expect(question.prompt, contains(point.code));
      }
    }
  });

  test('没有足够数据时不生成伪造选项', () {
    final questions = StudyQuiz.generateQuestions(
      meridians: const [],
      acupoints: const [],
      count: 10,
      random: Random(1),
    );
    expect(questions, isEmpty);
    expect(
      StudyQuiz.generateQuestions(
        meridians: meridians,
        acupoints: acupoints,
        count: 0,
      ),
      isEmpty,
    );
  });

  testWidgets('可以选择答案、查看反馈并完成一组练习', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AtlasThemes.light(),
      darkTheme: AtlasThemes.dark(),
      home: StudyQuizPage(
        meridians: meridians,
        acupoints: acupoints,
        questionCount: 2,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('第 1 / 2 题'), findsOneWidget);
    expect(find.text('核对答案'), findsOneWidget);

    Future<void> answerCurrentQuestion() async {
      final firstOption = find
          .byWidgetPredicate(
            (widget) =>
                widget is InkWell &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                      'study_quiz_option_',
                    ),
          )
          .first;
      await tester.ensureVisible(firstOption);
      await tester.tap(firstOption);
      await tester.pump();
      await tester.ensureVisible(find.text('核对答案'));
      await tester.tap(find.text('核对答案'));
      await tester.pump();
      expect(
        find.text('答对了').evaluate().isNotEmpty ||
            find.textContaining('正确答案：').evaluate().isNotEmpty,
        isTrue,
      );
    }

    await answerCurrentQuestion();
    final nextButton = find.ancestor(
      of: find.text('下一题'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    await tester.ensureVisible(nextButton);
    await tester.pumpAndSettle();
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    expect(find.text('第 2 / 2 题'), findsOneWidget);

    await answerCurrentQuestion();
    final scoreButton = find.ancestor(
      of: find.text('查看成绩'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    await tester.ensureVisible(scoreButton);
    await tester.pumpAndSettle();
    await tester.tap(scoreButton);
    await tester.pumpAndSettle();
    expect(find.text('本组练习完成'), findsOneWidget);
    expect(find.text('再练一组'), findsOneWidget);
  });
}
