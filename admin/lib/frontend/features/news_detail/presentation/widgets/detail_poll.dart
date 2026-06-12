import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';

const double _pollCornerRadius = 4;

class DetailPollBlock extends StatefulWidget {
  const DetailPollBlock({
    super.key,
    required this.data,
    required this.title,
    required this.description,
    required this.onVoteRecorded,
  });

  final NewsPollData data;
  final String title;
  final String description;
  final VoidCallback onVoteRecorded;

  @override
  State<DetailPollBlock> createState() => _DetailPollBlockState();
}

class _DetailPollBlockState extends State<DetailPollBlock> {
  String? _selectedOptionId;

  @override
  void didUpdateWidget(covariant DetailPollBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _selectedOptionId = null;
    }
  }

  void _vote(NewsPollOption option) {
    if (_selectedOptionId != null) return;
    setState(() => _selectedOptionId = option.id);
    widget.onVoteRecorded();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final question = data.title.trim();
    final title = _distinctText(widget.title, question);
    final description = _firstDistinctText(
      widget.description,
      data.description,
    );
    final hasVoted = _selectedOptionId != null;
    final totalVotes = data.resolvedTotalVotes + (hasVoted ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PollHeader(
          optionCount: data.options.length,
          totalVotes: totalVotes,
          hasVoted: hasVoted,
        ),
        if (title.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTypography.mobileNewsCardTitle.copyWith(
              color: AppColors.inkStrong,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          question,
          style: AppTypography.titleM.copyWith(
            color: AppColors.inkStrong,
            fontSize: title.isEmpty ? 21.5 : 18,
            fontWeight: FontWeight.w900,
            height: 1.12,
            letterSpacing: 0,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTypography.mobileNewsCardSummary.copyWith(
              color: AppColors.inkSoft.withValues(alpha: 0.86),
              fontSize: 13.5,
              height: 1.46,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _PollProgressPanel(hasVoted: hasVoted, totalVotes: totalVotes),
        const SizedBox(height: 14),
        if (data.isImagePoll)
          _PollImageOptionsGrid(
            data: data,
            selectedOptionId: _selectedOptionId,
            totalVotes: totalVotes,
            onVote: _vote,
          )
        else
          _PollListOptions(
            data: data,
            selectedOptionId: _selectedOptionId,
            totalVotes: totalVotes,
            onVote: _vote,
          ),
      ],
    );
  }
}

class _PollHeader extends StatelessWidget {
  const _PollHeader({
    required this.optionCount,
    required this.totalVotes,
    required this.hasVoted,
  });

  final int optionCount;
  final int totalVotes;
  final bool hasVoted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.actionRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(_pollCornerRadius),
            border: Border.all(
              color: AppColors.actionRed.withValues(alpha: 0.12),
            ),
          ),
          child: const Icon(
            Symbols.apps_fill,
            size: 18,
            color: AppColors.actionRed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anket',
                style: AppTypography.meta.copyWith(
                  color: AppColors.inkStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$optionCount seçenek · ${CountFormat.compact(totalVotes)} katılımcı',
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
        _PollTinyPill(
          text: hasVoted ? 'Sonuçlar' : 'Oy ver',
          tone: hasVoted ? _PollPillTone.green : _PollPillTone.warm,
        ),
      ],
    );
  }
}

class _PollProgressPanel extends StatelessWidget {
  const _PollProgressPanel({required this.hasVoted, required this.totalVotes});

  final bool hasVoted;
  final int totalVotes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(_pollCornerRadius),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        children: [
          Icon(
            hasVoted ? Symbols.check_rounded : Symbols.cursor_hand,
            size: 15,
            color: hasVoted ? const Color(0xFF1F9B6D) : AppColors.actionRed,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                hasVoted
                    ? 'Sonuçlar oyunla birlikte açıldı'
                    : 'Sonuçları görmek için bir seçeneğe oy ver',
                key: ValueKey<bool>(hasVoted),
                style: AppTypography.meta.copyWith(
                  color: AppColors.inkStrong,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${CountFormat.compact(totalVotes)} oy',
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontSize: 10.8,
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

class _PollImageOptionsGrid extends StatelessWidget {
  const _PollImageOptionsGrid({
    required this.data,
    required this.selectedOptionId,
    required this.totalVotes,
    required this.onVote,
  });

  final NewsPollData data;
  final String? selectedOptionId;
  final int totalVotes;
  final ValueChanged<NewsPollOption> onVote;

  @override
  Widget build(BuildContext context) {
    final columns = data.columns == 3 ? 3 : 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        const gap = 8.0;
        final itemWidth = (availableWidth - (gap * (columns - 1))) / columns;
        final itemHeight = _imageOptionTileHeight(
          itemWidth,
          columns,
          hasVoted: selectedOptionId != null,
        );
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < data.options.length; index += 1)
              SizedBox(
                width: math.max(0.0, itemWidth).toDouble(),
                height: itemHeight,
                child: _PollImageOption(
                  option: data.options[index],
                  index: index,
                  selected: selectedOptionId == data.options[index].id,
                  hasVoted: selectedOptionId != null,
                  totalVotes: totalVotes,
                  columns: columns,
                  onTap: () => onVote(data.options[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PollImageOption extends StatelessWidget {
  const _PollImageOption({
    required this.option,
    required this.index,
    required this.selected,
    required this.hasVoted,
    required this.totalVotes,
    required this.columns,
    required this.onTap,
  });

  final NewsPollOption option;
  final int index;
  final bool selected;
  final bool hasVoted;
  final int totalVotes;
  final int columns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final votes = option.votes + (selected && hasVoted ? 1 : 0);
    final percent = _pollPercent(votes, totalVotes);
    final muted = hasVoted && !selected;
    return Semantics(
      key: ValueKey<String>('detail-poll-option-${option.id}'),
      button: true,
      selected: selected,
      label: option.text,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasVoted ? null : onTap,
          borderRadius: BorderRadius.circular(_pollCornerRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.warmHorizon.withValues(alpha: 0.08)
                  : AppColors.surfaceSoft.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(_pollCornerRadius),
              border: Border.all(
                color: selected
                    ? AppColors.warmHorizon
                    : hasVoted
                    ? AppColors.softLine
                    : AppColors.line,
                width: selected ? 1.4 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.warmHorizon.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Opacity(
              opacity: muted ? 0.68 : 1,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PollOptionVisual(
                      imageUrl: option.imageUrl,
                      index: index,
                      selected: selected,
                      hasVoted: hasVoted,
                      percent: percent,
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Text(
                        option.text,
                        maxLines: hasVoted ? 5 : 7,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: AppTypography.body.copyWith(
                          color: AppColors.inkStrong,
                          fontSize: columns == 3 ? 11.2 : 12.8,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w800,
                          height: columns == 3 ? 1.14 : 1.18,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (hasVoted) ...[
                      const SizedBox(height: 6),
                      _PollResultLine(
                        percent: percent,
                        votes: votes,
                        selected: selected,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PollOptionVisual extends StatelessWidget {
  const _PollOptionVisual({
    required this.imageUrl,
    required this.index,
    required this.selected,
    required this.hasVoted,
    required this.percent,
  });

  final String imageUrl;
  final int index;
  final bool selected;
  final bool hasVoted;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _PollOptionImage(imageUrl: imageUrl),
        Positioned(
          top: 5,
          left: 5,
          child: _PollOptionBadge(index: index, selected: selected),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: _PollPercentBadge(
            percent: hasVoted ? percent : 0,
            selected: selected,
          ),
        ),
      ],
    );
  }
}

class _PollOptionImage extends StatelessWidget {
  const _PollOptionImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(_pollCornerRadius),
      child: AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: AppColors.surfaceSoft,
          child: cleanUrl.isEmpty
              ? const _PollImageFallback()
              : CachedImage(
                  url: cleanUrl,
                  fit: BoxFit.contain,
                  memCacheWidth: 520,
                  placeholderColor: AppColors.surfaceSoft,
                  errorWidget: const _PollImageFallback(),
                ),
        ),
      ),
    );
  }
}

class _PollListOptions extends StatelessWidget {
  const _PollListOptions({
    required this.data,
    required this.selectedOptionId,
    required this.totalVotes,
    required this.onVote,
  });

  final NewsPollData data;
  final String? selectedOptionId;
  final int totalVotes;
  final ValueChanged<NewsPollOption> onVote;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < data.options.length; index += 1) ...[
          _PollListOption(
            option: data.options[index],
            index: index,
            selected: selectedOptionId == data.options[index].id,
            hasVoted: selectedOptionId != null,
            totalVotes: totalVotes,
            onTap: () => onVote(data.options[index]),
          ),
          if (index != data.options.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PollListOption extends StatelessWidget {
  const _PollListOption({
    required this.option,
    required this.index,
    required this.selected,
    required this.hasVoted,
    required this.totalVotes,
    required this.onTap,
  });

  final NewsPollOption option;
  final int index;
  final bool selected;
  final bool hasVoted;
  final int totalVotes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final votes = option.votes + (selected && hasVoted ? 1 : 0);
    final percent = _pollPercent(votes, totalVotes);
    final progress = totalVotes <= 0 ? 0.0 : votes / totalVotes;
    return Semantics(
      key: ValueKey<String>('detail-poll-option-${option.id}'),
      button: true,
      selected: selected,
      label: option.text,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasVoted ? null : onTap,
          borderRadius: BorderRadius.circular(_pollCornerRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.warmHorizon.withValues(alpha: 0.08)
                  : AppColors.surfaceSoft.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(_pollCornerRadius),
              border: Border.all(
                color: selected
                    ? AppColors.warmHorizon
                    : hasVoted
                    ? AppColors.softLine
                    : AppColors.line,
                width: selected ? 1.4 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (hasVoted)
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: progress.clamp(0.0, 1.0).toDouble(),
                      ),
                      duration: const Duration(milliseconds: 720),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: value,
                            child: ColoredBox(
                              color: selected
                                  ? AppColors.warmHorizon.withValues(
                                      alpha: 0.16,
                                    )
                                  : AppColors.surfaceInk,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Row(
                    children: [
                      _PollOptionBadge(index: index, selected: selected),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          option.text,
                          style: AppTypography.body.copyWith(
                            color: AppColors.inkStrong,
                            fontSize: 13.5,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w800,
                            height: 1.22,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (hasVoted) ...[
                        const SizedBox(width: 10),
                        _PollResultText(
                          percent: percent,
                          votes: votes,
                          selected: selected,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PollOptionBadge extends StatelessWidget {
  const _PollOptionBadge({required this.index, required this.selected});

  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 23,
      height: 23,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.warmHorizon.withValues(alpha: 0.94)
            : Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(_pollCornerRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '${index + 1}',
        style: AppTypography.meta.copyWith(
          color: Colors.white,
          fontSize: 10.2,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PollPercentBadge extends StatelessWidget {
  const _PollPercentBadge({required this.percent, required this.selected});

  final int percent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.deepOcean.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(_pollCornerRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: _AnimatedPollPercentText(
        percent: percent,
        color: selected ? Colors.white : AppColors.inkStrong,
        fontSize: 11.5,
      ),
    );
  }
}

class _PollResultLine extends StatelessWidget {
  const _PollResultLine({
    required this.percent,
    required this.votes,
    required this.selected,
  });

  final int percent;
  final int votes;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_pollCornerRadius),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (percent / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 720),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  minHeight: 5,
                  value: value,
                  backgroundColor: AppColors.surfaceInk,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    selected ? AppColors.warmHorizon : AppColors.support,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${CountFormat.compact(votes)} oy',
          style: AppTypography.meta.copyWith(
            color: selected ? AppColors.deepOcean : AppColors.support,
            fontSize: 10.4,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _PollResultText extends StatelessWidget {
  const _PollResultText({
    required this.percent,
    required this.votes,
    required this.selected,
  });

  final int percent;
  final int votes;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedPollPercentText(
          percent: percent,
          color: selected ? AppColors.deepOcean : AppColors.inkSoft,
          fontSize: 16,
        ),
        const SizedBox(height: 3),
        Text(
          '${CountFormat.compact(votes)} oy',
          style: AppTypography.meta.copyWith(
            color: AppColors.support,
            fontSize: 10.4,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _AnimatedPollPercentText extends StatelessWidget {
  const _AnimatedPollPercentText({
    required this.percent,
    required this.color,
    required this.fontSize,
  });

  final int percent;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent.toDouble()),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          '%${value.round().clamp(0, 100)}',
          style: AppTypography.meta.copyWith(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        );
      },
    );
  }
}

class _PollTinyPill extends StatelessWidget {
  const _PollTinyPill({required this.text, required this.tone});

  final String text;
  final _PollPillTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _PollPillTone.green => const Color(0xFF1F9B6D),
      _PollPillTone.warm => AppColors.warmHorizon,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_pollCornerRadius),
      ),
      child: Text(
        text,
        style: AppTypography.meta.copyWith(
          color: color,
          fontSize: 10.2,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PollImageFallback extends StatelessWidget {
  const _PollImageFallback();

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

enum _PollPillTone { green, warm }

double _imageOptionTileHeight(
  double width,
  int columns, {
  required bool hasVoted,
}) {
  final imageHeight = math.max(0.0, width);
  final textBlockHeight = columns >= 3
      ? (hasVoted ? 112.0 : 82.0)
      : (hasVoted ? 94.0 : 66.0);
  return 6 + imageHeight + 7 + textBlockHeight + 6;
}

int _pollPercent(int votes, int totalVotes) {
  if (totalVotes <= 0 || votes <= 0) return 0;
  return ((votes / totalVotes) * 100).round().clamp(0, 100);
}

String _distinctText(String value, String duplicate) {
  final text = value.trim();
  if (text.isEmpty) return '';
  return text == duplicate.trim() ? '' : text;
}

String _firstDistinctText(String primary, String fallback) {
  final cleanPrimary = primary.trim();
  final cleanFallback = fallback.trim();
  if (cleanPrimary.isNotEmpty) return cleanPrimary;
  return cleanFallback;
}
