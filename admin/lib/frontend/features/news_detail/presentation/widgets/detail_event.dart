import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../../shared/widgets/pinch_zoom_surface.dart';

const double _eventCornerRadius = 4;
const Color _eventBlue = Color(0xFF2563EB);

class DetailEventBlock extends StatelessWidget {
  const DetailEventBlock({
    super.key,
    required this.data,
    required this.title,
    required this.description,
  });

  final NewsEventData data;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final schedule =
        data.schedule.where((item) => item.isValid).toList(growable: false)
          ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
    final highlights = data.highlights
        .where((item) => item.isValid)
        .toList(growable: false);
    final speakers = data.speakers
        .where((item) => item.isValid)
        .toList(growable: false);
    final stats = _eventStats(data);
    final showRegistration = _hasRegistrationInfo(data);
    final showLocation =
        data.venueName.trim().isNotEmpty ||
        data.address.trim().isNotEmpty ||
        data.latitude.trim().isNotEmpty ||
        data.longitude.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EventHeader(
          scheduleCount: schedule.length,
          speakerCount: speakers.length,
        ),
        if (title.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            title.trim(),
            style: AppTypography.mobileNewsCardTitle.copyWith(
              color: AppColors.inkStrong,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: 0,
            ),
          ),
        ],
        if (description.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description.trim(),
            style: AppTypography.mobileNewsCardSummary.copyWith(
              color: AppColors.inkSoft.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.46,
              letterSpacing: 0,
            ),
          ),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 15),
          _EventStatsPanel(stats: stats),
        ],
        if (showRegistration) ...[
          const SizedBox(height: 13),
          _EventRegistrationPanel(data: data),
        ],
        if (showLocation) ...[
          const SizedBox(height: 18),
          _EventSectionTitle(
            icon: Symbols.map_pin_line,
            title: 'Mekan',
            trailing: data.latitude.trim().isNotEmpty ? 'Konum hazır' : '',
          ),
          const SizedBox(height: 9),
          _EventLocationPanel(data: data),
        ],
        if (schedule.isNotEmpty) ...[
          const SizedBox(height: 18),
          _EventSectionTitle(
            icon: Symbols.calendar_event_line,
            title: data.scheduleTitle.trim().isEmpty
                ? 'Etkinlik Programı'
                : data.scheduleTitle.trim(),
            trailing: '${schedule.length} akış',
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < schedule.length; index += 1) ...[
            _EventScheduleCard(item: schedule[index], displayNumber: index + 1),
            if (index != schedule.length - 1) const SizedBox(height: 12),
          ],
        ],
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 18),
          _EventSectionTitle(
            icon: Symbols.local_fire_department_rounded,
            title: data.highlightsTitle.trim().isEmpty
                ? 'Etkinlik Notları'
                : data.highlightsTitle.trim(),
            trailing: '${highlights.length} not',
          ),
          const SizedBox(height: 9),
          _EventHighlightsPanel(highlights: highlights),
        ],
        if (speakers.isNotEmpty) ...[
          const SizedBox(height: 18),
          _EventSectionTitle(
            icon: Symbols.people_alt_outlined,
            title: data.speakersTitle.trim().isEmpty
                ? 'Konuklar'
                : data.speakersTitle.trim(),
            trailing: '${speakers.length} kişi',
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < speakers.length; index += 1) ...[
            _EventSpeakerCard(speaker: speakers[index]),
            if (index != speakers.length - 1) const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.scheduleCount, required this.speakerCount});

  final int scheduleCount;
  final int speakerCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (scheduleCount > 0) '$scheduleCount program',
      if (speakerCount > 0) '$speakerCount konuk',
    ];
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.actionRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(_eventCornerRadius),
            border: Border.all(
              color: AppColors.actionRed.withValues(alpha: 0.12),
            ),
          ),
          child: const Icon(
            Symbols.calendar_event_line,
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
                'Etkinlik',
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
                parts.isEmpty
                    ? 'Program ve kayıt bilgileri'
                    : parts.join(' · '),
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
        _EventTinyPill(text: scheduleCount > 0 ? 'Programlı' : 'Detay'),
      ],
    );
  }
}

class _EventStatsPanel extends StatelessWidget {
  const _EventStatsPanel({required this.stats});

  final List<_EventStat> stats;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(_eventCornerRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth < 330
                ? constraints.maxWidth
                : (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final stat in stats)
                  SizedBox(width: itemWidth, child: _EventStatTile(stat)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventStatTile extends StatelessWidget {
  const _EventStatTile(this.stat);

  final _EventStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_eventCornerRadius),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        children: [
          Icon(stat.icon, size: 16, color: stat.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.support,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stat.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 12.6,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    letterSpacing: 0,
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

class _EventRegistrationPanel extends StatelessWidget {
  const _EventRegistrationPanel({required this.data});

  final NewsEventData data;

  @override
  Widget build(BuildContext context) {
    final typeLabel = _registrationLabel(data.registrationType);
    final price = data.ticketPrice.trim();
    final url = data.ticketUrl.trim();
    final caption = price.isNotEmpty
        ? price
        : url.isNotEmpty
        ? url
        : 'Katılım bilgisi hazır';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(_eventCornerRadius),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.actionRed,
                borderRadius: BorderRadius.circular(_eventCornerRadius),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.actionRed.withValues(alpha: 0.24),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Symbols.open_in_new,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: AppTypography.titleS.copyWith(
                      color: AppColors.inkStrong,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.inkSoft,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                      height: 1.22,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventLocationPanel extends StatelessWidget {
  const _EventLocationPanel({required this.data});

  final NewsEventData data;

  @override
  Widget build(BuildContext context) {
    final venue = data.venueName.trim();
    final address = data.address.trim();
    final coordinates = [
      data.latitude.trim(),
      data.longitude.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_eventCornerRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _eventBlue.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(_eventCornerRadius),
              ),
              child: const Icon(
                Symbols.location_on_rounded,
                size: 17,
                color: _eventBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (venue.isNotEmpty)
                    Text(
                      venue,
                      style: AppTypography.titleS.copyWith(
                        color: AppColors.inkStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                  if (address.isNotEmpty) ...[
                    if (venue.isNotEmpty) const SizedBox(height: 5),
                    Text(
                      address,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.inkSoft,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                  if (coordinates.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      coordinates,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.support,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventSectionTitle extends StatelessWidget {
  const _EventSectionTitle({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.actionRed),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleS.copyWith(
              color: AppColors.inkStrong,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              height: 1.14,
              letterSpacing: 0,
            ),
          ),
        ),
        if (trailing.trim().isNotEmpty)
          Text(
            trailing.trim(),
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
      ],
    );
  }
}

class _EventScheduleCard extends StatelessWidget {
  const _EventScheduleCard({required this.item, required this.displayNumber});

  final NewsEventScheduleItem item;
  final int displayNumber;

  @override
  Widget build(BuildContext context) {
    final date = item.date.trim();
    final time = item.time.trim();
    final title = item.title.trim();
    final description = item.description.trim();
    final imageUrl = item.imageUrl.trim();
    final caption = item.imageDescription.trim();
    final timeParts = [
      if (date.isNotEmpty) date,
      if (time.isNotEmpty) time,
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_eventCornerRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: const BoxDecoration(
                color: AppColors.actionRed,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(_eventCornerRadius),
                  bottomLeft: Radius.circular(_eventCornerRadius),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.deepOcean,
                        borderRadius: BorderRadius.circular(_eventCornerRadius),
                      ),
                      child: Text(
                        '$displayNumber',
                        style: AppTypography.meta.copyWith(
                          color: Colors.white,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (timeParts.isNotEmpty) ...[
                            Text(
                              timeParts,
                              style: AppTypography.meta.copyWith(
                                color: AppColors.actionRed,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w900,
                                height: 1.18,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 5),
                          ],
                          Text(
                            title.isEmpty ? 'Program $displayNumber' : title,
                            style: AppTypography.titleM.copyWith(
                              color: AppColors.inkStrong,
                              fontSize: 17.2,
                              fontWeight: FontWeight.w900,
                              height: 1.14,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_eventCornerRadius),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: ColoredBox(
                        color: AppColors.surfaceSoft,
                        child: PinchZoomSurface(
                          child: CachedImage(
                            url: imageUrl,
                            fit: BoxFit.contain,
                            placeholderColor: AppColors.surfaceSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    caption,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.support,
                      fontSize: 11.3,
                      fontStyle: FontStyle.italic,
                      height: 1.32,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: AppTypography.mobileDetailBody.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.92),
                      fontSize: 15.2,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHighlightsPanel extends StatelessWidget {
  const _EventHighlightsPanel({required this.highlights});

  final List<NewsEventHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(_eventCornerRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            for (var index = 0; index < highlights.length; index += 1) ...[
              _EventHighlightRow(item: highlights[index]),
              if (index != highlights.length - 1)
                Divider(height: 13, thickness: 1, color: AppColors.softLine),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventHighlightRow extends StatelessWidget {
  const _EventHighlightRow({required this.item});

  final NewsEventHighlight item;

  @override
  Widget build(BuildContext context) {
    final label = item.label.trim();
    final value = item.value.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: AppColors.warmHorizon,
            borderRadius: BorderRadius.circular(_eventCornerRadius),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.inkSoft,
                fontSize: 12.6,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: 0,
              ),
              children: [
                if (label.isNotEmpty)
                  TextSpan(
                    text: value.isEmpty ? label : '$label: ',
                    style: const TextStyle(
                      color: AppColors.inkStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (value.isNotEmpty) TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EventSpeakerCard extends StatelessWidget {
  const _EventSpeakerCard({required this.speaker});

  final NewsEventSpeaker speaker;

  @override
  Widget build(BuildContext context) {
    final imageUrl = speaker.imageUrl.trim();
    final name = speaker.name.trim();
    final role = speaker.role.trim();
    final bio = speaker.bio.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_eventCornerRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_eventCornerRadius),
              child: SizedBox(
                width: 58,
                height: 58,
                child: imageUrl.isEmpty
                    ? ColoredBox(
                        color: AppColors.surfaceSoft,
                        child: Icon(
                          Symbols.person,
                          size: 24,
                          color: AppColors.support.withValues(alpha: 0.74),
                        ),
                      )
                    : CachedImage(
                        url: imageUrl,
                        fit: BoxFit.contain,
                        placeholderColor: AppColors.surfaceSoft,
                      ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Konuk' : name,
                    style: AppTypography.titleS.copyWith(
                      color: AppColors.inkStrong,
                      fontSize: 14.8,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                      letterSpacing: 0,
                    ),
                  ),
                  if (role.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      role,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.actionRed,
                        fontSize: 11.1,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      bio,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.inkSoft,
                        fontSize: 12.3,
                        fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _EventTinyPill extends StatelessWidget {
  const _EventTinyPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warmHorizon.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(_eventCornerRadius),
        border: Border.all(color: AppColors.warmHorizon.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          text,
          style: AppTypography.meta.copyWith(
            color: AppColors.warmHorizon,
            fontSize: 10.6,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _EventStat {
  const _EventStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

List<_EventStat> _eventStats(NewsEventData data) {
  final stats = <_EventStat>[];
  if (data.startDateTime.trim().isNotEmpty) {
    stats.add(
      _EventStat(
        icon: Symbols.calendar_event_line,
        label: 'Başlangıç',
        value: data.startDateTime.trim(),
        color: AppColors.deepOcean,
      ),
    );
  }
  if (data.endDateTime.trim().isNotEmpty) {
    stats.add(
      _EventStat(
        icon: Symbols.time_fill,
        label: 'Bitiş',
        value: data.endDateTime.trim(),
        color: AppColors.actionRed,
      ),
    );
  }
  if (data.organizer.trim().isNotEmpty) {
    stats.add(
      _EventStat(
        icon: Symbols.group,
        label: 'Düzenleyen',
        value: data.organizer.trim(),
        color: _eventBlue,
      ),
    );
  }
  if (data.capacity.trim().isNotEmpty) {
    stats.add(
      _EventStat(
        icon: Symbols.people_alt_outlined,
        label: 'Kapasite',
        value: data.capacity.trim(),
        color: AppColors.warmHorizon,
      ),
    );
  }
  return stats;
}

bool _hasRegistrationInfo(NewsEventData data) {
  return data.registrationType.trim().toLowerCase() != 'none' ||
      data.ticketUrl.trim().isNotEmpty ||
      data.ticketPrice.trim().isNotEmpty;
}

String _registrationLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'required' => 'Kayıt gerekli',
    'tickets' => 'Biletli etkinlik',
    'external' => 'Harici kayıt',
    _ => 'Kayıt bilgisi',
  };
}
