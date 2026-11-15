import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meridian.dart';
import '../models/study_quiz.dart';
import '../theme/atlas_theme.dart';

class StudyQuizPage extends StatefulWidget {
  const StudyQuizPage({
    super.key,
    required this.meridians,
    required this.acupoints,
    this.questionCount = 10,
  });

  final List<Meridian> meridians;
  final List<Acupoint> acupoints;
  final int questionCount;

  @override
  State<StudyQuizPage> createState() => _StudyQuizPageState();
}

class _StudyQuizPageState extends State<StudyQuizPage> {
  late List<QuizQuestion> _questions;
  int _questionIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _answered = false;
  bool _completed = false;

  QuizQuestion get _currentQuestion => _questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _startNewSet();
  }

  void _startNewSet() {
    _questions = StudyQuiz.generateQuestions(
      meridians: widget.meridians,
      acupoints: widget.acupoints,
      count: widget.questionCount,
    );
    _questionIndex = 0;
    _score = 0;
    _selectedAnswer = null;
    _answered = false;
    _completed = false;
  }

  void _selectAnswer(String answer) {
    if (_answered) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedAnswer = answer);
  }

  void _checkAnswer() {
    if (_selectedAnswer == null || _answered) return;
    HapticFeedback.lightImpact();
    setState(() {
      _answered = true;
      if (_selectedAnswer == _currentQuestion.correctAnswer) _score++;
    });
  }

  void _continue() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_questionIndex + 1 >= _questions.length) {
        _completed = true;
      } else {
        _questionIndex++;
        _selectedAnswer = null;
        _answered = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.atlas;
    return Scaffold(
      appBar: AppBar(
        title: const Text('穴位与经络练习',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: _questions.isEmpty
            ? _buildEmptyState(palette)
            : _completed
                ? _buildSummary(palette)
                : _buildQuestion(palette),
      ),
    );
  }

  Widget _buildQuestion(AtlasPalette palette) {
    final question = _currentQuestion;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _buildNotice(palette),
        const SizedBox(height: 22),
        Row(
          children: [
            Text('第 ${_questionIndex + 1} / ${_questions.length} 题',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textSecondary)),
            const Spacer(),
            Text('得分 $_score',
                style: TextStyle(fontSize: 12, color: palette.textMuted)),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_questionIndex + (_answered ? 1 : 0)) / _questions.length,
            minHeight: 5,
            backgroundColor: palette.surfaceMuted,
            color: palette.accent,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.quiz_outlined, size: 18, color: palette.accent),
                const SizedBox(width: 8),
                Text(_kindLabel(question.kind),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.accent)),
              ]),
              const SizedBox(height: 13),
              Text(question.prompt,
                  style: const TextStyle(
                      fontSize: 19, height: 1.45, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...question.options.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _buildOption(entry.key, entry.value, palette),
            )),
        if (_answered) ...[
          const SizedBox(height: 2),
          _buildAnswerFeedback(question, palette),
          const SizedBox(height: 14),
        ] else
          const SizedBox(height: 6),
        if (_answered)
          FilledButton.icon(
            onPressed: _continue,
            icon: Icon(_questionIndex + 1 == _questions.length
                ? Icons.flag_outlined
                : Icons.arrow_forward_rounded),
            label:
                Text(_questionIndex + 1 == _questions.length ? '查看成绩' : '下一题'),
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.page,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _selectedAnswer == null ? null : _checkAnswer,
            icon: const Icon(Icons.check_rounded),
            label: const Text('核对答案'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildOption(int index, String option, AtlasPalette palette) {
    final isSelected = _selectedAnswer == option;
    final isCorrect = option == _currentQuestion.correctAnswer;
    final showResult = _answered;
    final foreground = showResult && isCorrect
        ? const Color(0xFF27846F)
        : showResult && isSelected && !isCorrect
            ? const Color(0xFFB64C45)
            : isSelected
                ? palette.accent
                : palette.textPrimary;
    final border = showResult && isCorrect
        ? const Color(0xFF55A88F)
        : showResult && isSelected && !isCorrect
            ? const Color(0xFFD66C63)
            : isSelected
                ? palette.accent
                : palette.border;
    final background = showResult && isCorrect
        ? const Color(0x18278A70)
        : showResult && isSelected && !isCorrect
            ? const Color(0x18B64C45)
            : isSelected
                ? palette.surfaceMuted
                : palette.surface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        key: ValueKey('study_quiz_option_$option'),
        borderRadius: BorderRadius.circular(15),
        onTap: _answered ? null : () => _selectAnswer(option),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 29,
                height: 29,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: foreground.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: showResult && isCorrect
                    ? Icon(Icons.check_rounded, size: 17, color: foreground)
                    : Text(String.fromCharCode(65 + index),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: foreground)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(option,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected || (showResult && isCorrect)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerFeedback(QuizQuestion question, AtlasPalette palette) {
    final isCorrect = _selectedAnswer == question.correctAnswer;
    final color = isCorrect ? const Color(0xFF27846F) : const Color(0xFFB64C45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isCorrect ? Icons.check_circle_outline : Icons.info_outline,
              size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isCorrect ? '答对了' : '正确答案：${question.correctAnswer}',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(AtlasPalette palette) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: palette.warningSurface,
          border: Border.all(color: palette.warningBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 16, color: palette.warningText),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '题目只核对现有穴位名、代码、经络名及所属关系；不涉及主治或临床判断。',
                style: TextStyle(
                    fontSize: 11, height: 1.5, color: palette.warningText),
              ),
            ),
          ],
        ),
      );

  Widget _buildSummary(AtlasPalette palette) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                    color: palette.surfaceMuted, shape: BoxShape.circle),
                child: Icon(Icons.school_outlined,
                    size: 35, color: palette.accent),
              ),
              const SizedBox(height: 18),
              const Text('本组练习完成',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('$_score / ${_questions.length} 题答对',
                  style: TextStyle(fontSize: 16, color: palette.textSecondary)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => setState(_startNewSet),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('再练一组'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.page,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('题目仅基于本地已收录的名称、代码和所属关系。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: palette.textMuted)),
            ],
          ),
        ),
      );

  Widget _buildEmptyState(AtlasPalette palette) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_books_outlined,
                  size: 38, color: palette.textMuted),
              const SizedBox(height: 12),
              const Text('当前数据暂不能生成练习题'),
            ],
          ),
        ),
      );

  String _kindLabel(QuizQuestionKind kind) {
    switch (kind) {
      case QuizQuestionKind.pointMeridian:
        return '穴位所属经络';
      case QuizQuestionKind.meridianCode:
        return '经络代码';
      case QuizQuestionKind.pointName:
        return '穴位代码与名称';
    }
  }
}
