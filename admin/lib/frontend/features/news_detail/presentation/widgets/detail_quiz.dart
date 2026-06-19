import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../../shared/widgets/pinch_zoom_surface.dart';

const Color _correctGreen = Color(0xFF1F9B6D);
const Color _wrongWarm = AppColors.warmHorizon;
const double _quizCornerRadius = 4;

class DetailQuizBlock extends StatefulWidget {
  const DetailQuizBlock({
    super.key,
    required this.data,
    required this.title,
    required this.description,
  });

  final NewsQuizData data;
  final String title;
  final String description;

  @override
  State<DetailQuizBlock> createState() => _DetailQuizBlockState();
}

class _DetailQuizBlockState extends State<DetailQuizBlock> {
  final Map<String, Set<String>> _selectedByQuestion = {};
  final Set<String> _lockedQuestions = {};
  final Map<String, GlobalKey> _questionKeys = {};
  final GlobalKey _resultKey = GlobalKey();
  bool _resultRevealReady = false;

  @override
  void didUpdateWidget(covariant DetailQuizBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _selectedByQuestion.clear();
      _lockedQuestions.clear();
      _questionKeys.clear();
      _resultRevealReady = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.data.orderedQuestions
        .where((question) => question.isValid)
        .toList(growable: false);
    _syncQuestionKeys(questions);
    final results = widget.data.results
        .where((result) => result.isValid)
        .toList(growable: false);
    final answeredCount = _answeredCount(questions);
    final isComplete =
        questions.isNotEmpty && answeredCount == questions.length;
    if (!isComplete && _resultRevealReady) {
      _resultRevealReady = false;
    }
    final isTrivia = _isTrivia(widget.data, questions);
    final score = isTrivia ? _scoreFor(questions) : null;
    final result = isComplete && widget.data.showResults
        ? _resolveResult(
            questions: questions,
            results: results,
            score: score,
            isTrivia: isTrivia,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuizHeader(
          quizType: widget.data.quizType,
          questionCount: questions.length,
          resultCount: results.length,
          answeredCount: answeredCount,
          isComplete: isComplete,
        ),
        if (widget.title.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: AppTypography.mobileNewsCardTitle.copyWith(
              color: AppColors.inkStrong,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: 0,
            ),
          ),
        ],
        if (widget.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: AppTypography.mobileNewsCardSummary.copyWith(
              color: AppColors.inkSoft.withValues(alpha: 0.86),
              fontSize: 14,
              height: 1.46,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _QuizProgressPanel(
          answeredCount: answeredCount,
          questionCount: questions.length,
          isComplete: isComplete,
        ),
        const SizedBox(height: 18),
        _QuizSectionLabel(
          icon: Symbols.format_list_numbered,
          label: 'Sorular',
          trailing: '$answeredCount/${questions.length}',
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < questions.length; i++) ...[
          KeyedSubtree(
            key: _keyForQuestion(questions[i], i),
            child: _QuizQuestionCard(
              question: questions[i],
              index: i,
              showNumber: !widget.data.hideQuestionNumbers,
              allowMultiple: widget.data.allowMultiple,
              isTrivia: isTrivia,
              selectedIds: _selectedFor(questions[i], i),
              locked: _isLocked(questions[i], i),
              onAnswerTap: (answer, answerIndex) =>
                  _handleAnswerTap(questions[i], i, answer, answerIndex),
              onConfirm: () => _confirmQuestion(questions[i], i),
            ),
          ),
          if (i != questions.length - 1) const SizedBox(height: 12),
        ],
        const SizedBox(height: 20),
        KeyedSubtree(
          key: _resultKey,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isComplete
                ? _QuizResultStage(
                    key: const ValueKey('quiz-result-ready'),
                    result: result,
                    score: score,
                    questionCount: questions.length,
                    quizType: widget.data.quizType,
                    showResults: widget.data.showResults,
                    reveal: _resultRevealReady,
                  )
                : _QuizLockedResultTeaser(
                    key: const ValueKey('quiz-result-locked'),
                    answeredCount: answeredCount,
                    questionCount: questions.length,
                    remainingCount: questions.length - answeredCount,
                    onJumpToMissing: () => _scrollToFirstUnanswered(questions),
                  ),
          ),
        ),
      ],
    );
  }

  int _answeredCount(List<NewsQuizQuestion> questions) {
    var count = 0;
    for (var index = 0; index < questions.length; index += 1) {
      if (_isLocked(questions[index], index)) count += 1;
    }
    return count;
  }

  Set<String> _selectedFor(NewsQuizQuestion question, int index) {
    return _selectedByQuestion[_questionKey(question, index)] ?? const {};
  }

  bool _isLocked(NewsQuizQuestion question, int index) {
    return _lockedQuestions.contains(_questionKey(question, index));
  }

  void _handleAnswerTap(
    NewsQuizQuestion question,
    int questionIndex,
    NewsQuizAnswer answer,
    int answerIndex,
  ) {
    final questionKey = _questionKey(question, questionIndex);
    if (_lockedQuestions.contains(questionKey)) return;
    final answerKey = _answerKey(answer, answerIndex);
    setState(() {
      final selected = Set<String>.of(_selectedByQuestion[questionKey] ?? {});
      if (widget.data.allowMultiple) {
        if (selected.contains(answerKey)) {
          selected.remove(answerKey);
        } else {
          selected.add(answerKey);
        }
        _selectedByQuestion[questionKey] = selected;
      } else {
        _selectedByQuestion[questionKey] = {answerKey};
        _lockedQuestions.add(questionKey);
      }
    });
    _scrollToResultIfComplete();
  }

  void _confirmQuestion(NewsQuizQuestion question, int index) {
    final questionKey = _questionKey(question, index);
    final selected = _selectedByQuestion[questionKey];
    if (selected == null || selected.isEmpty) return;
    setState(() => _lockedQuestions.add(questionKey));
    _scrollToResultIfComplete();
  }

  int _scoreFor(List<NewsQuizQuestion> questions) {
    var score = 0;
    for (
      var questionIndex = 0;
      questionIndex < questions.length;
      questionIndex += 1
    ) {
      final question = questions[questionIndex];
      final selected = _selectedFor(question, questionIndex);
      if (selected.isEmpty) continue;
      final correct = <String>{};
      for (
        var answerIndex = 0;
        answerIndex < question.answers.length;
        answerIndex += 1
      ) {
        final answer = question.answers[answerIndex];
        if (answer.isCorrect) correct.add(_answerKey(answer, answerIndex));
      }
      if (correct.isNotEmpty && _setEquals(selected, correct)) score += 1;
    }
    return score;
  }

  NewsQuizResult? _resolveResult({
    required List<NewsQuizQuestion> questions,
    required List<NewsQuizResult> results,
    required int? score,
    required bool isTrivia,
  }) {
    if (results.isEmpty) return null;
    final byAnswer = _resultFromSelectedAnswers(questions, results);
    if (byAnswer != null && !isTrivia) return byAnswer;

    final resolvedScore = score ?? _selectedAnswerCount(questions);
    for (final result in results) {
      if (result.answerCount != null && result.answerCount == resolvedScore) {
        return result;
      }
    }
    for (final result in results) {
      final min = result.minScore ?? 0;
      final max = result.maxScore ?? questions.length;
      if (resolvedScore >= min && resolvedScore <= max) return result;
    }
    return byAnswer ?? results.first;
  }

  NewsQuizResult? _resultFromSelectedAnswers(
    List<NewsQuizQuestion> questions,
    List<NewsQuizResult> results,
  ) {
    final counts = <String, int>{};
    for (
      var questionIndex = 0;
      questionIndex < questions.length;
      questionIndex += 1
    ) {
      final question = questions[questionIndex];
      final selected = _selectedFor(question, questionIndex);
      for (
        var answerIndex = 0;
        answerIndex < question.answers.length;
        answerIndex += 1
      ) {
        final answer = question.answers[answerIndex];
        final answerKey = _answerKey(answer, answerIndex);
        final resultId = answer.resultId.trim();
        if (!selected.contains(answerKey) || resultId.isEmpty) continue;
        counts[resultId] = (counts[resultId] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    NewsQuizResult? best;
    var bestCount = -1;
    for (final result in results) {
      final count = counts[result.id] ?? 0;
      if (count > bestCount) {
        best = result;
        bestCount = count;
      }
    }
    return bestCount > 0 ? best : null;
  }

  int _selectedAnswerCount(List<NewsQuizQuestion> questions) {
    var count = 0;
    for (
      var questionIndex = 0;
      questionIndex < questions.length;
      questionIndex += 1
    ) {
      count += _selectedFor(questions[questionIndex], questionIndex).length;
    }
    return count;
  }

  void _syncQuestionKeys(List<NewsQuizQuestion> questions) {
    final activeKeys = <String>{};
    for (var index = 0; index < questions.length; index += 1) {
      activeKeys.add(_questionKey(questions[index], index));
    }
    _questionKeys.removeWhere((key, _) => !activeKeys.contains(key));
  }

  GlobalKey _keyForQuestion(NewsQuizQuestion question, int index) {
    final key = _questionKey(question, index);
    return _questionKeys.putIfAbsent(key, GlobalKey.new);
  }

  void _scrollToFirstUnanswered(List<NewsQuizQuestion> questions) {
    for (var index = 0; index < questions.length; index += 1) {
      final question = questions[index];
      if (_isLocked(question, index)) continue;
      _scrollToKey(_keyForQuestion(question, index), alignment: 0.12);
      return;
    }
  }

  void _scrollToResultIfComplete() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final questions = widget.data.orderedQuestions
          .where((question) => question.isValid)
          .toList(growable: false);
      if (questions.isEmpty || _answeredCount(questions) != questions.length) {
        return;
      }
      _scrollToKey(_resultKey, alignment: 0.20).then((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 90));
        if (!mounted) return;
        setState(() => _resultRevealReady = true);
      });
    });
  }

  Future<void> _scrollToKey(GlobalKey key, {required double alignment}) {
    final context = key.currentContext;
    if (context == null) return Future<void>.value();
    return Scrollable.ensureVisible(
      context,
      alignment: alignment,
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
    );
  }
}

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({
    required this.quizType,
    required this.questionCount,
    required this.resultCount,
    required this.answeredCount,
    required this.isComplete,
  });

  final String quizType;
  final int questionCount;
  final int resultCount;
  final int answeredCount;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.deepOcean,
            borderRadius: BorderRadius.circular(_quizCornerRadius),
          ),
          child: const Icon(
            Symbols.bolt_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Test',
                style: AppTypography.meta.copyWith(
                  color: AppColors.actionRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_quizTypeLabel(quizType)} · $questionCount soru · $resultCount sonuç',
                style: AppTypography.meta.copyWith(
                  color: AppColors.support,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        _QuizTinyPill(
          text: isComplete ? 'Sonuç hazır' : '$answeredCount/$questionCount',
          tone: isComplete ? _QuizPillTone.green : _QuizPillTone.warm,
          dot: true,
        ),
      ],
    );
  }
}

class _QuizProgressPanel extends StatelessWidget {
  const _QuizProgressPanel({
    required this.answeredCount,
    required this.questionCount,
    required this.isComplete,
  });

  final int answeredCount;
  final int questionCount;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final progress = questionCount <= 0 ? 0.0 : answeredCount / questionCount;
    final activeColor = isComplete ? _correctGreen : AppColors.actionRed;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_quizCornerRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(_quizCornerRadius),
                ),
                child: Icon(
                  isComplete
                      ? Symbols.check_rounded
                      : Symbols.lock_outline_rounded,
                  size: 13,
                  color: activeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isComplete
                      ? 'Tüm cevaplar tamamlandı'
                      : 'Sonucu görmek için soruları cevapla',
                  style: AppTypography.meta.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppTypography.meta.copyWith(
                  color: activeColor,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: progress.clamp(0, 1).toDouble()),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              if (questionCount <= 0 || questionCount > 24) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(_quizCornerRadius),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: value,
                    backgroundColor: AppColors.surfaceInk,
                    valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                  ),
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < questionCount; i += 1) ...[
                    Expanded(
                      child: _QuizProgressSegment(
                        fill: ((value * questionCount) - i)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        color: activeColor,
                      ),
                    ),
                    if (i != questionCount - 1) const SizedBox(width: 4),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuizProgressSegment extends StatelessWidget {
  const _QuizProgressSegment({required this.fill, required this.color});

  final double fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 7,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.surfaceInk),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill,
                heightFactor: 1,
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizSectionLabel extends StatelessWidget {
  const _QuizSectionLabel({
    required this.icon,
    required this.label,
    required this.trailing,
    this.accent = AppColors.actionRed,
  });

  final IconData icon;
  final String label;
  final String trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(_quizCornerRadius),
          ),
          child: Icon(icon, size: 13, color: accent),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleM.copyWith(
              color: AppColors.inkStrong,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: AppColors.softLine),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceInk,
            borderRadius: BorderRadius.circular(_quizCornerRadius),
          ),
          child: Text(
            trailing,
            style: AppTypography.meta.copyWith(
              color: AppColors.inkSoft,
              fontSize: 10.4,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.question,
    required this.index,
    required this.showNumber,
    required this.allowMultiple,
    required this.isTrivia,
    required this.selectedIds,
    required this.locked,
    required this.onAnswerTap,
    required this.onConfirm,
  });

  final NewsQuizQuestion question;
  final int index;
  final bool showNumber;
  final bool allowMultiple;
  final bool isTrivia;
  final Set<String> selectedIds;
  final bool locked;
  final void Function(NewsQuizAnswer answer, int index) onAnswerTap;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final imageUrl = question.imageUrl.trim();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_quizCornerRadius),
        border: Border.all(
          color: locked
              ? AppColors.deepOcean.withValues(alpha: 0.2)
              : AppColors.line,
        ),
        boxShadow: locked
            ? [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.65),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showNumber) ...[
                  _QuizQuestionNumber(value: index + 1, answered: locked),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.title,
                        style: AppTypography.titleM.copyWith(
                          color: AppColors.inkStrong,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          height: 1.22,
                          letterSpacing: 0,
                        ),
                      ),
                      if (question.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          question.description,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.inkSoft,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.36,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              _QuizQuestionImage(imageUrl: imageUrl),
            ],
            const SizedBox(height: 10),
            _QuizAnswers(
              answers: question.answers,
              layout: question.layout,
              selectedIds: selectedIds,
              locked: locked,
              isTrivia: isTrivia,
              onAnswerTap: onAnswerTap,
            ),
            if (allowMultiple && !locked) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _QuizConfirmButton(
                  enabled: selectedIds.isNotEmpty,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizQuestionNumber extends StatelessWidget {
  const _QuizQuestionNumber({required this.value, required this.answered});

  final int value;
  final bool answered;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: answered ? AppColors.deepOcean : AppColors.surface,
        borderRadius: BorderRadius.circular(_quizCornerRadius),
        border: Border.all(
          color: answered ? AppColors.deepOcean : AppColors.line,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutBack,
        child: answered
            ? const Icon(
                Symbols.check_rounded,
                key: ValueKey('question-number-check'),
                size: 15,
                color: Colors.white,
              )
            : Text(
                value.toString(),
                key: const ValueKey('question-number-value'),
                style: AppTypography.meta.copyWith(
                  color: AppColors.deepOcean,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
      ),
    );
  }
}

enum _QuizAnswerState { idle, selected, correct, wrong, dimmed }

_QuizAnswerState _answerStateFor({
  required NewsQuizAnswer answer,
  required bool selected,
  required bool locked,
  required bool isTrivia,
}) {
  if (locked && isTrivia) {
    if (answer.isCorrect) return _QuizAnswerState.correct;
    if (selected) return _QuizAnswerState.wrong;
    return _QuizAnswerState.dimmed;
  }
  if (selected) return _QuizAnswerState.selected;
  return locked ? _QuizAnswerState.dimmed : _QuizAnswerState.idle;
}

class _QuizAnswers extends StatelessWidget {
  const _QuizAnswers({
    required this.answers,
    required this.layout,
    required this.selectedIds,
    required this.locked,
    required this.isTrivia,
    required this.onAnswerTap,
  });

  final List<NewsQuizAnswer> answers;
  final String layout;
  final Set<String> selectedIds;
  final bool locked;
  final bool isTrivia;
  final void Function(NewsQuizAnswer answer, int index) onAnswerTap;

  @override
  Widget build(BuildContext context) {
    final hasImages = answers.any(
      (answer) => answer.imageUrl.trim().isNotEmpty,
    );
    final revealExplanationsAsList =
        locked && answers.any((answer) => answer.explanation.trim().isNotEmpty);
    if (!hasImages || layout == 'list' || revealExplanationsAsList) {
      return Column(
        children: [
          for (var i = 0; i < answers.length; i++) ...[
            _QuizAnswerTile(
              answer: answers[i],
              index: i,
              selected: selectedIds.contains(_answerKey(answers[i], i)),
              locked: locked,
              isTrivia: isTrivia,
              compact: false,
              onTap: () => onAnswerTap(answers[i], i),
            ),
            if (i != answers.length - 1) const SizedBox(height: 7),
          ],
        ],
      );
    }

    final columns = layout == 'grid3' ? 3 : 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final effectiveColumns = math.max(1, math.min(columns, answers.length));
        const gap = 8.0;
        final itemWidth =
            (availableWidth - (gap * (effectiveColumns - 1))) /
            effectiveColumns;
        final itemHeight = _compactAnswerTileHeight(
          itemWidth,
          effectiveColumns,
          locked: locked,
        );
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < answers.length; index += 1)
              SizedBox(
                width: math.max(0.0, itemWidth).toDouble(),
                height: itemHeight,
                child: _QuizAnswerTile(
                  answer: answers[index],
                  index: index,
                  selected: selectedIds.contains(
                    _answerKey(answers[index], index),
                  ),
                  locked: locked,
                  isTrivia: isTrivia,
                  compact: true,
                  onTap: () => onAnswerTap(answers[index], index),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuizAnswerTile extends StatelessWidget {
  const _QuizAnswerTile({
    required this.answer,
    required this.index,
    required this.selected,
    required this.locked,
    required this.isTrivia,
    required this.compact,
    required this.onTap,
  });

  final NewsQuizAnswer answer;
  final int index;
  final bool selected;
  final bool locked;
  final bool isTrivia;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = answer.imageUrl.trim();
    final state = _answerStateFor(
      answer: answer,
      selected: selected,
      locked: locked,
      isTrivia: isTrivia,
    );
    final borderColor = switch (state) {
      _QuizAnswerState.correct => _correctGreen.withValues(alpha: 0.5),
      _QuizAnswerState.wrong => _wrongWarm.withValues(alpha: 0.5),
      _QuizAnswerState.selected => AppColors.actionRed.withValues(alpha: 0.42),
      _QuizAnswerState.dimmed => AppColors.softLine,
      _QuizAnswerState.idle => AppColors.softLine,
    };
    final background = switch (state) {
      _QuizAnswerState.correct => _correctGreen.withValues(alpha: 0.075),
      _QuizAnswerState.wrong => _wrongWarm.withValues(alpha: 0.07),
      _QuizAnswerState.selected =>
        AppColors.actionRed.withValues(alpha: 0.055),
      _QuizAnswerState.dimmed => AppColors.surfaceSoft.withValues(alpha: 0.42),
      _QuizAnswerState.idle => AppColors.surfaceSoft,
    };

    return Semantics(
      key: ValueKey<String>('quiz-answer-tile-${_answerKey(answer, index)}'),
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(_quizCornerRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(_quizCornerRadius),
              border: Border.all(color: borderColor),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 190),
              opacity: state == _QuizAnswerState.dimmed ? 0.62 : 1,
              child: Padding(
                padding: EdgeInsets.all(compact ? 6 : 8),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _QuizAnswerVisual(
                            imageUrl: imageUrl,
                            index: index,
                            state: state,
                          ),
                          const SizedBox(height: 7),
                          Expanded(
                            child: _QuizAnswerText(
                              answer: answer,
                              index: index,
                              selected: selected,
                              state: state,
                              locked: locked,
                              isTrivia: isTrivia,
                              compact: true,
                              showLetter: false,
                            ),
                          ),
                          if (_showExplanation) ...[
                            const SizedBox(height: 6),
                            _QuizExplanation(text: answer.explanation),
                          ],
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl.isNotEmpty) ...[
                            _QuizThumb(imageUrl: imageUrl, size: 58),
                            const SizedBox(width: 9),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _QuizAnswerText(
                                  answer: answer,
                                  index: index,
                                  selected: selected,
                                  state: state,
                                  locked: locked,
                                  isTrivia: isTrivia,
                                  compact: false,
                                  showLetter: true,
                                ),
                                if (_showExplanation) ...[
                                  const SizedBox(height: 6),
                                  _QuizExplanation(text: answer.explanation),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _showExplanation {
    if (!locked || answer.explanation.trim().isEmpty) return false;
    if (!isTrivia) return selected;
    return selected || answer.isCorrect;
  }
}

class _QuizAnswerText extends StatelessWidget {
  const _QuizAnswerText({
    required this.answer,
    required this.index,
    required this.selected,
    required this.state,
    required this.locked,
    required this.isTrivia,
    required this.compact,
    required this.showLetter,
  });

  final NewsQuizAnswer answer;
  final int index;
  final bool selected;
  final _QuizAnswerState state;
  final bool locked;
  final bool isTrivia;
  final bool compact;
  final bool showLetter;

  @override
  Widget build(BuildContext context) {
    final showCorrect = locked && isTrivia && answer.isCorrect;
    final showChoice = locked && selected;
    final textStyle = AppTypography.body.copyWith(
      color: AppColors.inkStrong,
      fontSize: compact ? 11.2 : 13.4,
      fontWeight: FontWeight.w800,
      height: compact ? 1.14 : 1.28,
      letterSpacing: 0,
    );
    final text = Text(
      answer.text,
      maxLines: compact ? (showCorrect || showChoice ? 5 : 7) : null,
      overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
      softWrap: true,
      style: textStyle,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLetter)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuizAnswerLetter(index: index, state: state),
              const SizedBox(width: 8),
              Expanded(child: text),
            ],
          )
        else
          text,
        if (showCorrect || showChoice) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              if (showCorrect)
                const _QuizTinyPill(
                  text: 'Doğru cevap',
                  tone: _QuizPillTone.green,
                ),
              if (showChoice)
                _QuizTinyPill(
                  text: answer.isCorrect || !isTrivia ? 'Seçimin' : 'Seçimin',
                  tone: answer.isCorrect || !isTrivia
                      ? _QuizPillTone.red
                      : _QuizPillTone.warm,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuizAnswerLetter extends StatelessWidget {
  const _QuizAnswerLetter({required this.index, required this.state});

  final int index;
  final _QuizAnswerState state;

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + (index % 26));
    final (Color fill, Color border) = switch (state) {
      _QuizAnswerState.correct => (_correctGreen, _correctGreen),
      _QuizAnswerState.wrong => (_wrongWarm, _wrongWarm),
      _QuizAnswerState.selected => (AppColors.actionRed, AppColors.actionRed),
      _ => (AppColors.surface, AppColors.line.withValues(alpha: 0.9)),
    };
    final isFilled = state == _QuizAnswerState.correct ||
        state == _QuizAnswerState.wrong ||
        state == _QuizAnswerState.selected;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: switch (state) {
        _QuizAnswerState.correct => const Icon(
          Symbols.check_rounded,
          size: 12,
          color: Colors.white,
        ),
        _QuizAnswerState.wrong => const Icon(
          Symbols.close_rounded,
          size: 12,
          color: Colors.white,
        ),
        _ => Text(
          letter,
          style: AppTypography.meta.copyWith(
            color: isFilled ? Colors.white : AppColors.inkSoft,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      },
    );
  }
}

class _QuizConfirmButton extends StatelessWidget {
  const _QuizConfirmButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.actionRed,
        disabledForegroundColor: AppColors.support.withValues(alpha: 0.7),
        disabledBackgroundColor: AppColors.surfaceInk,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_quizCornerRadius),
        ),
      ),
      icon: const Icon(Symbols.check_rounded, size: 14),
      label: Text(
        'Cevabı onayla',
        style: AppTypography.meta.copyWith(
          color: enabled ? Colors.white : AppColors.support,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _QuizLockedResultTeaser extends StatelessWidget {
  const _QuizLockedResultTeaser({
    super.key,
    required this.answeredCount,
    required this.questionCount,
    required this.remainingCount,
    required this.onJumpToMissing,
  });

  final int answeredCount;
  final int questionCount;
  final int remainingCount;
  final VoidCallback onJumpToMissing;

  @override
  Widget build(BuildContext context) {
    final remainingLabel = remainingCount == 1
        ? '1 sorunuz kaldı'
        : '$remainingCount sorunuz kaldı';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuizSectionLabel(
          icon: Symbols.lock_outline_rounded,
          label: 'Sonuç',
          trailing: '$answeredCount/$questionCount tamamlandı',
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: remainingCount > 0 ? onJumpToMissing : null,
            borderRadius: BorderRadius.circular(_quizCornerRadius),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(_quizCornerRadius),
                border: Border.all(
                  color: AppColors.deepOcean.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.deepOcean.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(_quizCornerRadius),
                    ),
                    child: const Icon(
                      Symbols.lock_outline_rounded,
                      size: 17,
                      color: AppColors.deepOcean,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          remainingLabel,
                          style: AppTypography.titleM.copyWith(
                            color: AppColors.inkStrong,
                            fontSize: 15.3,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sonucu açmak için eksik soruya dön.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.28,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.actionRed,
                      borderRadius: BorderRadius.circular(_quizCornerRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Eksik soruya git',
                          style: AppTypography.meta.copyWith(
                            color: Colors.white,
                            fontSize: 10.6,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Symbols.arrow_forward_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizResultStage extends StatelessWidget {
  const _QuizResultStage({
    super.key,
    required this.result,
    required this.score,
    required this.questionCount,
    required this.quizType,
    required this.showResults,
    required this.reveal,
  });

  final NewsQuizResult? result;
  final int? score;
  final int questionCount;
  final String quizType;
  final bool showResults;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    if (!showResults) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuizSectionLabel(
          icon: Symbols.sparkling_fill,
          label: 'Sonucun',
          trailing: score == null ? 'tamamlandı' : '$score/$questionCount',
          accent: AppColors.warmHorizon,
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: !reveal
              ? const SizedBox(key: ValueKey('result-wait'), height: 4)
              : result == null
              ? const _QuizEmptyResultCard(key: ValueKey('result-empty'))
              : _QuizResultCard(
                  key: const ValueKey('result-card'),
                  result: result!,
                  quizType: quizType,
                  questionCount: questionCount,
                  score: score,
                ),
        ),
      ],
    );
  }
}

class _QuizResultCard extends StatelessWidget {
  const _QuizResultCard({
    super.key,
    required this.result,
    required this.quizType,
    required this.questionCount,
    required this.score,
  });

  final NewsQuizResult result;
  final String quizType;
  final int questionCount;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final imageUrl = result.imageUrl.trim();
    final scoreLabel = score == null
        ? _quizResultScoreLabel(result, quizType, questionCount)
        : '$score doğru';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 760),
      curve: Curves.linear,
      builder: (context, raw, child) {
        final card = Curves.easeOutQuint.transform(
          const Interval(0.0, 0.72).transform(raw),
        );
        final body = Curves.easeOutCubic.transform(
          const Interval(0.22, 1.0).transform(raw),
        );
        return Opacity(
          opacity: card.clamp(0, 1).toDouble(),
          child: Transform.translate(
            offset: Offset(0, (1 - card) * 26),
            child: Transform.scale(
              scale: 0.965 + (0.035 * card),
              alignment: Alignment.topCenter,
              child: _QuizResultCardBody(
                result: result,
                scoreLabel: scoreLabel,
                imageUrl: imageUrl,
                bodyReveal: body,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuizResultCardBody extends StatelessWidget {
  const _QuizResultCardBody({
    required this.result,
    required this.scoreLabel,
    required this.imageUrl,
    required this.bodyReveal,
  });

  final NewsQuizResult result;
  final String scoreLabel;
  final String imageUrl;
  final double bodyReveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_quizCornerRadius),
        border: Border.all(
          color: AppColors.deepOcean.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.85),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ColoredBox(
            color: AppColors.deepOcean,
            child: SizedBox(height: 3),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl.isNotEmpty) ...[
                  _QuizResultImage(imageUrl: imageUrl),
                  const SizedBox(height: 12),
                ],
                Opacity(
                  opacity: bodyReveal.clamp(0, 1).toDouble(),
                  child: Transform.translate(
                    offset: Offset(0, (1 - bodyReveal) * 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.deepOcean,
                                borderRadius: BorderRadius.circular(
                                  _quizCornerRadius,
                                ),
                              ),
                              child: const Icon(
                                Symbols.verified,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                result.title,
                                style: AppTypography.titleM.copyWith(
                                  color: AppColors.inkStrong,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            if (scoreLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _QuizTinyPill(
                                text: scoreLabel,
                                tone: _QuizPillTone.warm,
                              ),
                            ],
                          ],
                        ),
                        if (result.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            result.description,
                            style: const TextStyle(
                              fontFamily: 'Newsreader',
                              color: AppColors.ink,
                              fontSize: 17,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400,
                              height: 1.52,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizEmptyResultCard extends StatelessWidget {
  const _QuizEmptyResultCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(_quizCornerRadius),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Text(
        'Test tamamlandı.',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.inkSoft,
          fontSize: 12.4,
          fontWeight: FontWeight.w700,
          height: 1.35,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _QuizExplanation extends StatelessWidget {
  const _QuizExplanation({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(_quizCornerRadius),
        border: Border.all(color: AppColors.softLine),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2.5,
              color: AppColors.deepOcean.withValues(alpha: 0.3),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 9, 8),
                child: Text(
                  text,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkSoft,
                    fontSize: 11.6,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizTinyPill extends StatelessWidget {
  const _QuizTinyPill({
    required this.text,
    this.tone = _QuizPillTone.warm,
    this.dot = false,
  });

  final String text;
  final _QuizPillTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _QuizPillTone.red => AppColors.actionRed,
      _QuizPillTone.green => _correctGreen,
      _QuizPillTone.warm => AppColors.warmHorizon,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_quizCornerRadius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: AppTypography.meta.copyWith(
              color: color,
              fontSize: 10.2,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

enum _QuizPillTone { warm, red, green }

class _QuizQuestionImage extends StatelessWidget {
  const _QuizQuestionImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return _QuizAutoRatioImage(
      imageUrl: imageUrl,
      borderRadius: _quizCornerRadius,
      backgroundColor: AppColors.surfaceInk,
      fallbackAspectRatio: 16 / 9,
      memCacheWidth: 900,
    );
  }
}

class _QuizResultImage extends StatelessWidget {
  const _QuizResultImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return _QuizAutoRatioImage(
      imageUrl: imageUrl,
      borderRadius: _quizCornerRadius,
      backgroundColor: AppColors.surfaceSoft,
      fallbackAspectRatio: 1,
      memCacheWidth: 900,
    );
  }
}

class _QuizAutoRatioImage extends StatefulWidget {
  const _QuizAutoRatioImage({
    required this.imageUrl,
    required this.borderRadius,
    required this.backgroundColor,
    required this.fallbackAspectRatio,
    required this.memCacheWidth,
  });

  final String imageUrl;
  final double borderRadius;
  final Color backgroundColor;
  final double fallbackAspectRatio;
  final int memCacheWidth;

  @override
  State<_QuizAutoRatioImage> createState() => _QuizAutoRatioImageState();
}

class _QuizAutoRatioImageState extends State<_QuizAutoRatioImage> {
  ImageStream? _pendingImageStream;
  ImageStreamListener? _pendingImageListener;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _QuizAutoRatioImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.fallbackAspectRatio != widget.fallbackAspectRatio) {
      _removeImageListener();
      _aspectRatio = null;
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _resolveAspectRatio() {
    final fallback = widget.fallbackAspectRatio;
    if (fallback.isFinite && fallback > 0) {
      _aspectRatio = fallback;
    }
    final imageUrl = widget.imageUrl.trim();
    if (imageUrl.isEmpty) return;

    final stream = CachedNetworkImageProvider(
      imageUrl,
      maxWidth: widget.memCacheWidth,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((image, _) {
      _removeImageListener();
      final width = image.image.width;
      final height = image.image.height;
      if (!mounted || width <= 0 || height <= 0) return;
      final ratio = width / height;
      final current = _aspectRatio;
      if (current != null && (current - ratio).abs() < 0.001) return;
      setState(() => _aspectRatio = ratio);
    }, onError: (_, _) => _removeImageListener());
    _pendingImageStream = stream;
    _pendingImageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _pendingImageStream;
    final listener = _pendingImageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _pendingImageStream = null;
    _pendingImageListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = (_aspectRatio ?? widget.fallbackAspectRatio).clamp(0.25, 4.5);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AspectRatio(
          aspectRatio: ratio.toDouble(),
          child: ColoredBox(
            color: widget.backgroundColor,
            child: PinchZoomSurface(
              child: CachedImage(
                url: widget.imageUrl,
                fit: BoxFit.contain,
                memCacheWidth: widget.memCacheWidth,
                placeholderColor: widget.backgroundColor,
                errorWidget: const _QuizImageFallback(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizAnswerImage extends StatelessWidget {
  const _QuizAnswerImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(_quizCornerRadius),
      child: AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: AppColors.surfaceSoft,
          child: cleanUrl.isEmpty
              ? const _QuizImageFallback()
              : CachedImage(
                  url: cleanUrl,
                  fit: BoxFit.contain,
                  memCacheWidth: 520,
                  placeholderColor: AppColors.surfaceSoft,
                  errorWidget: const _QuizImageFallback(),
                ),
        ),
      ),
    );
  }
}

class _QuizAnswerVisual extends StatelessWidget {
  const _QuizAnswerVisual({
    required this.imageUrl,
    required this.index,
    required this.state,
  });

  final String imageUrl;
  final int index;
  final _QuizAnswerState state;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _QuizAnswerImage(imageUrl: imageUrl),
        Positioned(
          top: 5,
          left: 5,
          child: _QuizAnswerImageBadge(index: index, state: state),
        ),
      ],
    );
  }
}

class _QuizAnswerImageBadge extends StatelessWidget {
  const _QuizAnswerImageBadge({required this.index, required this.state});

  final int index;
  final _QuizAnswerState state;

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + (index % 26));
    final background = switch (state) {
      _QuizAnswerState.correct => _correctGreen.withValues(alpha: 0.94),
      _QuizAnswerState.wrong => _wrongWarm.withValues(alpha: 0.94),
      _QuizAnswerState.selected =>
        AppColors.actionRed.withValues(alpha: 0.94),
      _ => Colors.black.withValues(alpha: 0.78),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 23,
      height: 23,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_quizCornerRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: switch (state) {
        _QuizAnswerState.correct => const Icon(
          Symbols.check_rounded,
          size: 13,
          color: Colors.white,
        ),
        _QuizAnswerState.wrong => const Icon(
          Symbols.close_rounded,
          size: 13,
          color: Colors.white,
        ),
        _ => Text(
          letter,
          style: AppTypography.meta.copyWith(
            color: Colors.white,
            fontSize: 10.2,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      },
    );
  }
}

class _QuizThumb extends StatelessWidget {
  const _QuizThumb({required this.imageUrl, required this.size});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_quizCornerRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: CachedImage(
          url: imageUrl,
          fit: BoxFit.contain,
          placeholderColor: AppColors.surfaceSoft,
          errorWidget: const _QuizImageFallback(),
        ),
      ),
    );
  }
}

class _QuizImageFallback extends StatelessWidget {
  const _QuizImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceSoft,
      alignment: Alignment.center,
      child: Icon(
        Symbols.image_outlined,
        size: 20,
        color: AppColors.support.withValues(alpha: 0.6),
      ),
    );
  }
}

String _questionKey(NewsQuizQuestion question, int index) {
  final id = question.id.trim();
  return id.isNotEmpty ? id : 'quiz-question-${index + 1}';
}

String _answerKey(NewsQuizAnswer answer, int index) {
  final id = answer.id.trim();
  return id.isNotEmpty ? id : 'quiz-answer-${index + 1}';
}

bool _isTrivia(NewsQuizData data, List<NewsQuizQuestion> questions) {
  final type = data.quizType.trim().toLowerCase();
  if (type == 'trivia') return true;
  return questions.any(
    (question) => question.answers.any((answer) => answer.isCorrect),
  );
}

bool _setEquals(Set<String> a, Set<String> b) {
  if (a.length != b.length) return false;
  for (final item in a) {
    if (!b.contains(item)) return false;
  }
  return true;
}

double _compactAnswerTileHeight(
  double width,
  int columns, {
  required bool locked,
}) {
  final imageHeight = math.max(0.0, width);
  final textBlockHeight = columns >= 3
      ? (locked ? 89.0 : 82.0)
      : (locked ? 70.0 : 58.0);
  return 6 + imageHeight + 7 + textBlockHeight + 6;
}

String _quizTypeLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'trivia' => 'Bilgi yarışması',
    'checklist' => 'Kontrol listesi',
    _ => 'Kişilik testi',
  };
}

String _quizResultScoreLabel(
  NewsQuizResult result,
  String quizType,
  int questionCount,
) {
  final answerCount = result.answerCount;
  if (answerCount != null) return '$answerCount doğru';
  final minScore = result.minScore;
  final maxScore = result.maxScore;
  if (minScore == null && maxScore == null) return '';
  final fallbackMax = questionCount <= 0 ? null : questionCount;
  final start = minScore ?? 0;
  final end = maxScore ?? fallbackMax;
  if (end == null) return '$start+';
  if (start == end) {
    return quizType.trim().toLowerCase() == 'trivia'
        ? '$start doğru'
        : '$start cevap';
  }
  return '$start-$end';
}
