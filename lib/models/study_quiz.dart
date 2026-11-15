import 'dart:math';

import 'meridian.dart';

enum QuizQuestionKind {
  pointMeridian,
  meridianCode,
  pointName,
}

/// A multiple-choice question derived exclusively from existing records.
class QuizQuestion {
  const QuizQuestion({
    required this.kind,
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    this.point,
    this.meridian,
  });

  final QuizQuestionKind kind;
  final String prompt;
  final List<String> options;
  final String correctAnswer;
  final Acupoint? point;
  final Meridian? meridian;
}

class StudyQuiz {
  const StudyQuiz._();

  /// Builds a balanced set of questions from the supplied local records.
  ///
  /// No efficacy, indication, location, or clinical field is read here.
  static List<QuizQuestion> generateQuestions({
    required List<Meridian> meridians,
    required List<Acupoint> acupoints,
    int count = 10,
    Random? random,
  }) {
    if (count <= 0) return const [];

    final rng = random ?? Random();
    final meridianById = {for (final item in meridians) item.id: item};
    final pointMeridianQuestions = <QuizQuestion>[];
    final meridianCodeQuestions = <QuizQuestion>[];
    final pointNameQuestions = <QuizQuestion>[];
    final meridianNames = meridians.map((item) => item.nameZh).toList();
    final meridianCodes = meridians.map((item) => item.code).toList();
    final pointNames = acupoints.map((item) => item.nameZh).toList();

    for (final point in acupoints) {
      final meridian = meridianById[point.meridianId];
      if (meridian == null) continue;

      final relationOptions = _makeOptions(meridian.nameZh, meridianNames, rng);
      if (relationOptions.isNotEmpty) {
        pointMeridianQuestions.add(QuizQuestion(
          kind: QuizQuestionKind.pointMeridian,
          prompt: '「${point.nameZh}（${point.code}）」所属哪条经络？',
          options: relationOptions,
          correctAnswer: meridian.nameZh,
          point: point,
          meridian: meridian,
        ));
      }

      final nameOptions = _makeOptions(point.nameZh, pointNames, rng);
      if (nameOptions.isNotEmpty) {
        pointNameQuestions.add(QuizQuestion(
          kind: QuizQuestionKind.pointName,
          prompt: '穴位代码 ${point.code} 对应的穴位名称是？',
          options: nameOptions,
          correctAnswer: point.nameZh,
          point: point,
        ));
      }
    }

    for (final meridian in meridians) {
      final options = _makeOptions(meridian.code, meridianCodes, rng);
      if (options.isNotEmpty) {
        meridianCodeQuestions.add(QuizQuestion(
          kind: QuizQuestionKind.meridianCode,
          prompt: '${meridian.nameZh} 的经络代码是什么？',
          options: options,
          correctAnswer: meridian.code,
          meridian: meridian,
        ));
      }
    }

    final pools = [
      pointMeridianQuestions,
      meridianCodeQuestions,
      pointNameQuestions,
    ];
    for (final pool in pools) {
      pool.shuffle(rng);
    }

    final positions = List<int>.filled(pools.length, 0);
    final questions = <QuizQuestion>[];
    var nextPool = 0;
    while (questions.length < count) {
      var foundQuestion = false;
      for (var offset = 0; offset < pools.length; offset++) {
        final poolIndex = (nextPool + offset) % pools.length;
        if (positions[poolIndex] >= pools[poolIndex].length) continue;
        questions.add(pools[poolIndex][positions[poolIndex]++]);
        nextPool = (poolIndex + 1) % pools.length;
        foundQuestion = true;
        break;
      }
      if (!foundQuestion) break;
    }
    return List.unmodifiable(questions);
  }

  static List<String> _makeOptions(
    String correctAnswer,
    List<String> sourceValues,
    Random random,
  ) {
    final values =
        sourceValues.where((value) => value.isNotEmpty).toSet().toList();
    if (!values.contains(correctAnswer) || values.length < 2) return const [];

    values.remove(correctAnswer);
    values.shuffle(random);
    final options = [correctAnswer, ...values.take(3)]..shuffle(random);
    return List.unmodifiable(options);
  }
}
