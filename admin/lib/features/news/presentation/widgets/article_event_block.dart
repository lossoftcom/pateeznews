import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import '../../../../shared/widgets/media_library_dialog.dart';

const _eventBlockStrongLine = Color(0xFFDDE5E8);
const _eventBlockSoftLine = Color(0xFFE8EEF1);
const _eventBlockMutedText = Color(0xFF5F6F78);
const _eventBlockUploadInk = Color(0xFF6D7B83);
const _eventBlockEditorChrome = Color(0xFFFBF7F1);
const _eventBlockEditorLine = Color(0x298C6D53);
const _eventBlockVisualHeight = 220.0;
const _eventBlockEditorBodyHeight = 190.0;

const eventRegistrationTypeOptions = <String>[
  'none',
  'required',
  'tickets',
  'external',
];

const _eventRegistrationLabelKeys = <String, String>{
  'none': 'newsAdd.event.registrationNone',
  'required': 'newsAdd.event.registrationRequired',
  'tickets': 'newsAdd.event.registrationTickets',
  'external': 'newsAdd.event.registrationExternal',
};

class EventBlockEntry {
  EventBlockEntry()
    : startDateTimeController = TextEditingController(),
      endDateTimeController = TextEditingController(),
      organizerController = TextEditingController(),
      venueNameController = TextEditingController(),
      addressController = TextEditingController(),
      latitudeController = TextEditingController(),
      longitudeController = TextEditingController(),
      ticketUrlController = TextEditingController(),
      ticketPriceController = TextEditingController(),
      capacityController = TextEditingController(),
      scheduleTitleController = TextEditingController(),
      highlightsTitleController = TextEditingController(),
      speakersTitleController = TextEditingController();

  final TextEditingController startDateTimeController;
  final TextEditingController endDateTimeController;
  final TextEditingController organizerController;
  final TextEditingController venueNameController;
  final TextEditingController addressController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController ticketUrlController;
  final TextEditingController ticketPriceController;
  final TextEditingController capacityController;
  final TextEditingController scheduleTitleController;
  final TextEditingController highlightsTitleController;
  final TextEditingController speakersTitleController;
  String registrationType = 'none';
  final schedule = <EventScheduleEntry>[EventScheduleEntry()];
  final highlights = <EventHighlightEntry>[EventHighlightEntry()];
  final speakers = <EventSpeakerEntry>[EventSpeakerEntry()];

  void dispose() {
    startDateTimeController.dispose();
    endDateTimeController.dispose();
    organizerController.dispose();
    venueNameController.dispose();
    addressController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    ticketUrlController.dispose();
    ticketPriceController.dispose();
    capacityController.dispose();
    scheduleTitleController.dispose();
    highlightsTitleController.dispose();
    speakersTitleController.dispose();
    for (final item in schedule) {
      item.dispose();
    }
    for (final item in highlights) {
      item.dispose();
    }
    for (final speaker in speakers) {
      speaker.dispose();
    }
  }
}

class EventScheduleEntry {
  EventScheduleEntry()
    : dateController = TextEditingController(),
      timeController = TextEditingController(),
      titleController = TextEditingController(),
      descriptionController = TextEditingController(),
      imageDescriptionController = TextEditingController();

  final TextEditingController dateController;
  final TextEditingController timeController;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController imageDescriptionController;
  String? imageUrl;

  void dispose() {
    dateController.dispose();
    timeController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    imageDescriptionController.dispose();
  }
}

class EventHighlightEntry {
  EventHighlightEntry()
    : labelController = TextEditingController(),
      valueController = TextEditingController();

  final TextEditingController labelController;
  final TextEditingController valueController;

  void dispose() {
    labelController.dispose();
    valueController.dispose();
  }
}

class EventSpeakerEntry {
  EventSpeakerEntry()
    : nameController = TextEditingController(),
      roleController = TextEditingController(),
      imageDescriptionController = TextEditingController(),
      bioController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );

  final TextEditingController nameController;
  final TextEditingController roleController;
  final TextEditingController imageDescriptionController;
  final quill.QuillController bioController;
  String? imageUrl;
  var collapsed = false;

  void dispose() {
    nameController.dispose();
    roleController.dispose();
    imageDescriptionController.dispose();
    bioController.dispose();
  }
}

class ArticleEventSettingsCard extends StatelessWidget {
  const ArticleEventSettingsCard({
    super.key,
    required this.entry,
    required this.onRegistrationTypeChanged,
  });

  final EventBlockEntry entry;
  final ValueChanged<String> onRegistrationTypeChanged;

  @override
  Widget build(BuildContext context) {
    return _EventSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventSectionHeader(
            icon: Icons.calendar_today_outlined,
            title: 'newsAdd.event.blockTitle',
          ),
          const SizedBox(height: 20),
          _EventResponsiveGrid(
            minItemWidth: 190,
            children: [
              _EventTextFieldControl(
                label: 'newsAdd.event.startDateTime',
                controller: entry.startDateTimeController,
                hintTextKey: 'newsAdd.event.startDateTimeHint',
              ),
              _EventTextFieldControl(
                label: 'newsAdd.event.endDateTime',
                controller: entry.endDateTimeController,
                hintTextKey: 'newsAdd.event.endDateTimeHint',
              ),
              _EventTextFieldControl(
                label: 'newsAdd.event.organizer',
                controller: entry.organizerController,
                hintTextKey: 'newsAdd.event.organizerHint',
              ),
              _EventTextFieldControl(
                label: 'newsAdd.event.venueName',
                controller: entry.venueNameController,
                hintTextKey: 'newsAdd.event.venueNameHint',
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final address = _EventTextFieldControl(
                label: 'newsAdd.event.address',
                controller: entry.addressController,
                hintTextKey: 'newsAdd.event.addressHint',
                maxLines: 3,
              );
              final latitude = _EventTextFieldControl(
                label: 'newsAdd.event.latitude',
                controller: entry.latitudeController,
                hintTextKey: 'newsAdd.event.latitudeHint',
              );
              final longitude = _EventTextFieldControl(
                label: 'newsAdd.event.longitude',
                controller: entry.longitudeController,
                hintTextKey: 'newsAdd.event.longitudeHint',
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    address,
                    const SizedBox(height: 14),
                    latitude,
                    const SizedBox(height: 14),
                    longitude,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: address),
                  const SizedBox(width: 16),
                  Expanded(child: latitude),
                  const SizedBox(width: 16),
                  Expanded(child: longitude),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _EventResponsiveGrid(
            minItemWidth: 190,
            children: [
              _EventRegistrationControl(
                value: entry.registrationType,
                onChanged: onRegistrationTypeChanged,
              ),
              _EventTextFieldControl(
                label: 'newsAdd.event.ticketUrl',
                controller: entry.ticketUrlController,
                hintTextKey: 'newsAdd.event.ticketUrlHint',
              ),
              _EventTextFieldControl(
                label: 'newsAdd.event.ticketPrice',
                controller: entry.ticketPriceController,
                hintTextKey: 'newsAdd.event.ticketPriceHint',
              ),
              _EventTextFieldControl(
                label: 'newsAdd.event.capacity',
                controller: entry.capacityController,
                hintTextKey: 'newsAdd.event.capacityHint',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ArticleEventSectionsCard extends StatelessWidget {
  const ArticleEventSectionsCard({
    super.key,
    required this.entry,
    required this.onAddSchedule,
    required this.onRemoveSchedule,
    required this.onScheduleImageChanged,
    required this.onAddHighlight,
    required this.onRemoveHighlight,
    required this.onAddSpeaker,
    required this.onRemoveSpeaker,
    required this.onMoveSpeaker,
    required this.onToggleSpeakerCollapsed,
    required this.onSpeakerImageChanged,
  });

  final EventBlockEntry entry;
  final VoidCallback onAddSchedule;
  final ValueChanged<EventScheduleEntry> onRemoveSchedule;
  final void Function(EventScheduleEntry schedule, String? imageUrl)
  onScheduleImageChanged;
  final VoidCallback onAddHighlight;
  final ValueChanged<EventHighlightEntry> onRemoveHighlight;
  final VoidCallback onAddSpeaker;
  final ValueChanged<EventSpeakerEntry> onRemoveSpeaker;
  final void Function(EventSpeakerEntry speaker, int delta) onMoveSpeaker;
  final ValueChanged<EventSpeakerEntry> onToggleSpeakerCollapsed;
  final void Function(EventSpeakerEntry speaker, String? imageUrl)
  onSpeakerImageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EventScheduleListCard(
          sectionTitleController: entry.scheduleTitleController,
          entries: entry.schedule,
          onAdd: onAddSchedule,
          onRemove: onRemoveSchedule,
          onImageChanged: onScheduleImageChanged,
        ),
        const SizedBox(height: 18),
        _EventHighlightsListCard(
          sectionTitleController: entry.highlightsTitleController,
          entries: entry.highlights,
          onAdd: onAddHighlight,
          onRemove: onRemoveHighlight,
        ),
        const SizedBox(height: 18),
        _EventSpeakersListCard(
          sectionTitleController: entry.speakersTitleController,
          entries: entry.speakers,
          onAdd: onAddSpeaker,
          onRemove: onRemoveSpeaker,
          onMove: onMoveSpeaker,
          onToggleCollapsed: onToggleSpeakerCollapsed,
          onImageChanged: onSpeakerImageChanged,
        ),
      ],
    );
  }
}

class _EventScheduleListCard extends StatelessWidget {
  const _EventScheduleListCard({
    required this.sectionTitleController,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    required this.onImageChanged,
  });

  final TextEditingController sectionTitleController;
  final List<EventScheduleEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<EventScheduleEntry> onRemove;
  final void Function(EventScheduleEntry schedule, String? imageUrl)
  onImageChanged;

  @override
  Widget build(BuildContext context) {
    return _EventSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EventListHeader(
            icon: Icons.event_note_outlined,
            title: 'newsAdd.event.schedule',
            addLabel: 'newsAdd.event.addSchedule',
            onAdd: onAdd,
          ),
          const SizedBox(height: 18),
          const _EventFieldLabel('newsAdd.event.sectionTitle'),
          _EventTextInputBox(
            controller: sectionTitleController,
            hintTextKey: 'newsAdd.event.scheduleTitleHint',
            bold: true,
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < entries.length; i++) ...[
            _EventScheduleEntryCard(
              entry: entries[i],
              index: i,
              canDelete: entries.length > 1,
              onRemove: () => onRemove(entries[i]),
              onImageChanged: (imageUrl) =>
                  onImageChanged(entries[i], imageUrl),
            ),
            if (i != entries.length - 1) const SizedBox(height: 14),
          ],
          const SizedBox(height: 12),
          Text(
            context.t('newsAdd.event.scheduleExample'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventScheduleEntryCard extends StatelessWidget {
  const _EventScheduleEntryCard({
    required this.entry,
    required this.index,
    required this.canDelete,
    required this.onRemove,
    required this.onImageChanged,
  });

  final EventScheduleEntry entry;
  final int index;
  final bool canDelete;
  final VoidCallback onRemove;
  final ValueChanged<String?> onImageChanged;

  Future<void> _pickImage(BuildContext context) async {
    final selected = await showMediaLibraryDialog(context);
    if (selected != null) onImageChanged(selected);
  }

  Future<void> _pickUrl(BuildContext context) async {
    final selected = await showUrlImageDialog(context);
    if (selected != null && selected.trim().isNotEmpty) {
      onImageChanged(selected.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _eventBlockStrongLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 780;
              final rowFields = [
                _EventDateInputBox(
                  controller: entry.dateController,
                  hintTextKey: 'newsAdd.event.scheduleDateHint',
                ),
                _EventTextInputBox(
                  controller: entry.timeController,
                  hintTextKey: 'newsAdd.event.scheduleTimeHint',
                  bold: true,
                ),
                _EventTextInputBox(
                  controller: entry.titleController,
                  hintTextKey: 'newsAdd.event.scheduleItemHint',
                  bold: true,
                ),
                _EventTextInputBox(
                  controller: entry.descriptionController,
                  hintTextKey: 'newsAdd.event.scheduleDescriptionHint',
                ),
              ];

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _EventNumberBadge(index + 1),
                        const SizedBox(width: 10),
                        Expanded(child: rowFields[0]),
                        const SizedBox(width: 8),
                        _EventTinyIconButton(
                          icon: Icons.delete_outline,
                          active: canDelete,
                          onTap: onRemove,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (var i = 1; i < rowFields.length; i++) ...[
                      rowFields[i],
                      if (i != rowFields.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EventNumberBadge(index + 1),
                    const SizedBox(width: 10),
                    SizedBox(width: 160, child: rowFields[0]),
                    const SizedBox(width: 10),
                    SizedBox(width: 140, child: rowFields[1]),
                    const SizedBox(width: 10),
                    Expanded(child: rowFields[2]),
                    const SizedBox(width: 10),
                    Expanded(child: rowFields[3]),
                    const SizedBox(width: 8),
                    _EventTinyIconButton(
                      icon: Icons.delete_outline,
                      active: canDelete,
                      onTap: onRemove,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final image = _EventImagePanel(
                label: 'newsAdd.event.scheduleImage',
                imageUrl: entry.imageUrl,
                imageDescriptionController: entry.imageDescriptionController,
                onPickImage: () => _pickImage(context),
                onPickUrl: () => _pickUrl(context),
                onClear: () => onImageChanged(null),
              );
              final description = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _EventFieldLabel('newsAdd.event.imageDescription'),
                  _EventTextInputBox(
                    controller: entry.imageDescriptionController,
                    hintTextKey: 'newsAdd.event.imageDescriptionHint',
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [image, const SizedBox(height: 12), description],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 220, child: image),
                  const SizedBox(width: 14),
                  Expanded(child: description),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EventHighlightsListCard extends StatelessWidget {
  const _EventHighlightsListCard({
    required this.sectionTitleController,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController sectionTitleController;
  final List<EventHighlightEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<EventHighlightEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    return _EventSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EventListHeader(
            icon: Icons.info_outline,
            title: 'newsAdd.event.highlights',
            addLabel: 'newsAdd.event.addHighlight',
            onAdd: onAdd,
          ),
          const SizedBox(height: 18),
          const _EventFieldLabel('newsAdd.event.sectionTitle'),
          _EventTextInputBox(
            controller: sectionTitleController,
            hintTextKey: 'newsAdd.event.highlightsTitleHint',
            bold: true,
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < entries.length; i++) ...[
            _EventHighlightRow(
              entry: entries[i],
              index: i,
              canDelete: entries.length > 1,
              onRemove: () => onRemove(entries[i]),
            ),
            if (i != entries.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          Text(
            context.t('newsAdd.event.highlightsExample'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHighlightRow extends StatelessWidget {
  const _EventHighlightRow({
    required this.entry,
    required this.index,
    required this.canDelete,
    required this.onRemove,
  });

  final EventHighlightEntry entry;
  final int index;
  final bool canDelete;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EventNumberBadge(index + 1),
          const SizedBox(width: 10),
          Expanded(
            child: _EventTextInputBox(
              controller: entry.labelController,
              hintTextKey: 'newsAdd.event.highlightLabelHint',
              bold: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _EventTextInputBox(
              controller: entry.valueController,
              hintTextKey: 'newsAdd.event.highlightValueHint',
              bold: true,
            ),
          ),
          const SizedBox(width: 8),
          _EventTinyIconButton(
            icon: Icons.delete_outline,
            active: canDelete,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _EventSpeakersListCard extends StatelessWidget {
  const _EventSpeakersListCard({
    required this.sectionTitleController,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    required this.onMove,
    required this.onToggleCollapsed,
    required this.onImageChanged,
  });

  final TextEditingController sectionTitleController;
  final List<EventSpeakerEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<EventSpeakerEntry> onRemove;
  final void Function(EventSpeakerEntry speaker, int delta) onMove;
  final ValueChanged<EventSpeakerEntry> onToggleCollapsed;
  final void Function(EventSpeakerEntry speaker, String? imageUrl)
  onImageChanged;

  @override
  Widget build(BuildContext context) {
    return _EventSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EventListHeader(
            icon: Icons.groups_outlined,
            title: 'newsAdd.event.speakers',
            addLabel: 'newsAdd.event.addSpeaker',
            onAdd: onAdd,
          ),
          const SizedBox(height: 18),
          const _EventFieldLabel('newsAdd.event.sectionTitle'),
          _EventTextInputBox(
            controller: sectionTitleController,
            hintTextKey: 'newsAdd.event.speakersTitleHint',
            bold: true,
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < entries.length; i++) ...[
            _EventSpeakerCard(
              speaker: entries[i],
              index: i,
              totalItems: entries.length,
              onRemove: () => onRemove(entries[i]),
              onMoveUp: () => onMove(entries[i], -1),
              onMoveDown: () => onMove(entries[i], 1),
              onToggleCollapsed: () => onToggleCollapsed(entries[i]),
              onImageChanged: (imageUrl) =>
                  onImageChanged(entries[i], imageUrl),
            ),
            if (i != entries.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _EventSpeakerCard extends StatelessWidget {
  const _EventSpeakerCard({
    required this.speaker,
    required this.index,
    required this.totalItems,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleCollapsed,
    required this.onImageChanged,
  });

  final EventSpeakerEntry speaker;
  final int index;
  final int totalItems;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<String?> onImageChanged;

  Future<void> _pickImage(BuildContext context) async {
    final selected = await showMediaLibraryDialog(context);
    if (selected != null) onImageChanged(selected);
  }

  Future<void> _pickUrl(BuildContext context) async {
    final selected = await showUrlImageDialog(context);
    if (selected != null && selected.trim().isNotEmpty) {
      onImageChanged(selected.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayNumber = index + 1;
    return _EventSectionCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.actionRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.value),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppColors.actionRed,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${context.t('newsAdd.event.speaker')} #$displayNumber',
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      _EventCollapseButton(
                        collapsed: speaker.collapsed,
                        onTap: onToggleCollapsed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: _eventBlockSoftLine),
                  if (!speaker.collapsed) ...[
                    const SizedBox(height: 20),
                    _SpeakerNameRoleRow(speaker: speaker),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 760;
                        final imagePanel = _EventImagePanel(
                          label: 'newsAdd.event.speakerImage',
                          imageUrl: speaker.imageUrl,
                          imageDescriptionController:
                              speaker.imageDescriptionController,
                          showDescription: true,
                          onPickImage: () => _pickImage(context),
                          onPickUrl: () => _pickUrl(context),
                          onClear: () => onImageChanged(null),
                        );
                        final bioPanel = _EventRichTextPanel(
                          label: 'newsAdd.event.speakerBio',
                          controller: speaker.bioController,
                          placeholder: 'newsAdd.event.speakerBioHint',
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              imagePanel,
                              const SizedBox(height: 16),
                              bioPanel,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: imagePanel),
                            const SizedBox(width: 24),
                            Expanded(flex: 10, child: bioPanel),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _EventActionRail(
              canMoveUp: index > 0,
              canMoveDown: index < totalItems - 1,
              canDelete: totalItems > 1,
              onDelete: onRemove,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakerNameRoleRow extends StatelessWidget {
  const _SpeakerNameRoleRow({required this.speaker});

  final EventSpeakerEntry speaker;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final name = _EventTextFieldControl(
          label: 'newsAdd.event.speakerName',
          controller: speaker.nameController,
          hintTextKey: 'newsAdd.event.speakerNameHint',
        );
        final role = _EventTextFieldControl(
          label: 'newsAdd.event.speakerRole',
          controller: speaker.roleController,
          hintTextKey: 'newsAdd.event.speakerRoleHint',
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [name, const SizedBox(height: 14), role],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: name),
            const SizedBox(width: 16),
            Expanded(child: role),
          ],
        );
      },
    );
  }
}

class _EventResponsiveGrid extends StatelessWidget {
  const _EventResponsiveGrid({
    required this.children,
    required this.minItemWidth,
  });

  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final available = constraints.maxWidth;
        final columns = (available / minItemWidth).floor().clamp(1, 4).toInt();
        final width = columns == 1
            ? available
            : (available - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _EventListHeader extends StatelessWidget {
  const _EventListHeader({
    required this.icon,
    required this.title,
    required this.addLabel,
    required this.onAdd,
  });

  final IconData icon;
  final String title;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _eventBlockSoftLine)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.actionRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(title),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          _EventSmallAddButton(label: addLabel, onTap: onAdd),
        ],
      ),
    );
  }
}

class _EventSectionHeader extends StatelessWidget {
  const _EventSectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _eventBlockSoftLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Icon(icon, color: AppColors.actionRed, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(title),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSectionCard extends StatelessWidget {
  const _EventSectionCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _eventBlockStrongLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EventTextFieldControl extends StatelessWidget {
  const _EventTextFieldControl({
    required this.label,
    required this.controller,
    required this.hintTextKey,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hintTextKey;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EventFieldLabel(label),
        _EventTextInputBox(
          controller: controller,
          hintTextKey: hintTextKey,
          fontSize: 13,
          bold: true,
          maxLines: maxLines,
        ),
      ],
    );
  }
}

class _EventRegistrationControl extends StatelessWidget {
  const _EventRegistrationControl({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EventFieldLabel('newsAdd.event.registrationType'),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _eventBlockStrongLine),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: eventRegistrationTypeOptions.contains(value)
                  ? value
                  : 'none',
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: _eventBlockMutedText,
              ),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              items: [
                for (final option in eventRegistrationTypeOptions)
                  DropdownMenuItem(
                    value: option,
                    child: Text(
                      context.t(_eventRegistrationLabelKeys[option]!),
                    ),
                  ),
              ],
              onChanged: (next) => onChanged(next ?? 'none'),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventFieldLabel extends StatelessWidget {
  const _EventFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _eventBlockMutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _EventNumberBadge extends StatelessWidget {
  const _EventNumberBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.deepOcean,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EventDateInputBox extends StatelessWidget {
  const _EventDateInputBox({
    required this.controller,
    required this.hintTextKey,
  });

  final TextEditingController controller;
  final String hintTextKey;

  @override
  Widget build(BuildContext context) {
    return _EventTextInputBox(
      controller: controller,
      hintTextKey: hintTextKey,
      bold: true,
      suffixIcon: Icons.calendar_today_outlined,
    );
  }
}

class _EventTextInputBox extends StatelessWidget {
  const _EventTextInputBox({
    required this.controller,
    required this.hintTextKey,
    this.bold = false,
    this.fontSize = 14,
    this.maxLines = 1,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintTextKey;
  final bool bold;
  final double fontSize;
  final int maxLines;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _eventBlockStrongLine),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: maxLines > 1 ? maxLines : null,
        cursorColor: AppColors.deepOcean,
        style: TextStyle(
          color: AppColors.deepOcean,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: context.t(hintTextKey),
          hintStyle: TextStyle(
            color: AppColors.placeholder,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
            letterSpacing: 0,
          ),
          suffixIcon: suffixIcon == null
              ? null
              : Icon(suffixIcon, size: 16, color: _eventBlockMutedText),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 38,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

class _EventImagePanel extends StatelessWidget {
  const _EventImagePanel({
    required this.label,
    required this.imageUrl,
    required this.imageDescriptionController,
    this.showDescription = false,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClear,
  });

  final String label;
  final String? imageUrl;
  final TextEditingController imageDescriptionController;
  final bool showDescription;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EventFieldLabel(label),
        _EventDashedImageBox(
          imageUrl: imageUrl,
          onPickImage: onPickImage,
          onPickUrl: onPickUrl,
          onClear: onClear,
        ),
        if (showDescription) ...[
          const SizedBox(height: 10),
          _EventTextInputBox(
            controller: imageDescriptionController,
            hintTextKey: 'newsAdd.event.imageDescriptionHint',
          ),
        ],
      ],
    );
  }
}

class _EventDashedImageBox extends StatelessWidget {
  const _EventDashedImageBox({
    required this.imageUrl,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClear,
  });

  final String? imageUrl;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;

  String _resolvedImageUrl(String value) {
    if (value.startsWith('http')) return value;
    return MediaService().resolveImageUrl(value, width: 720, quality: 90);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EventDashedBorderPainter(
        color: _eventBlockStrongLine,
        radius: AppRadius.value,
      ),
      child: Container(
        height: _eventBlockVisualHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: imageUrl == null
            ? _EventEmptyImagePicker(
                onPickImage: onPickImage,
                onPickUrl: onPickUrl,
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: AdminCachedImage(
                      url: _resolvedImageUrl(imageUrl!),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      memCacheWidth: 720,
                      useOldImageOnUrlChange: true,
                      errorWidget: _EventEmptyImagePicker(
                        onPickImage: onPickImage,
                        onPickUrl: onPickUrl,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _EventImageActionButton(
                          icon: Icons.edit_outlined,
                          color: AppColors.deepOcean,
                          onTap: onPickImage,
                        ),
                        const SizedBox(width: 8),
                        _EventImageActionButton(
                          icon: Icons.delete_outline,
                          color: AppColors.actionRed,
                          onTap: onClear,
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

class _EventEmptyImagePicker extends StatelessWidget {
  const _EventEmptyImagePicker({
    required this.onPickImage,
    required this.onPickUrl,
  });

  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPickImage,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: _eventBlockUploadInk, size: 32),
              const SizedBox(height: 8),
              Text(
                context.t('newsAdd.imageSelect'),
                style: const TextStyle(
                  color: _eventBlockUploadInk,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              _EventUrlUploadButton(onTap: onPickUrl),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventUrlUploadButton extends StatelessWidget {
  const _EventUrlUploadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _eventBlockStrongLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 13, color: AppColors.deepOcean),
              const SizedBox(width: 7),
              Text(
                context.t('newsAdd.addUrl'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventImageActionButton extends StatelessWidget {
  const _EventImageActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _EventRichTextPanel extends StatelessWidget {
  const _EventRichTextPanel({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  final String label;
  final quill.QuillController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EventFieldLabel(label),
        _EventRichTextEditor(controller: controller, placeholder: placeholder),
      ],
    );
  }
}

class _EventRichTextEditor extends StatelessWidget {
  const _EventRichTextEditor({
    required this.controller,
    required this.placeholder,
  });

  final quill.QuillController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.value);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: _eventBlockStrongLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: _eventBlockEditorChrome,
              border: Border(bottom: BorderSide(color: _eventBlockEditorLine)),
            ),
            child: quill.QuillSimpleToolbar(
              controller: controller,
              config: const quill.QuillSimpleToolbarConfig(
                toolbarSize: 30,
                toolbarIconAlignment: WrapAlignment.start,
                toolbarIconCrossAlignment: WrapCrossAlignment.center,
                toolbarSectionSpacing: 4,
                toolbarRunSpacing: 2,
                sectionDividerSpace: 8,
                iconTheme: quill.QuillIconTheme(
                  iconButtonUnselectedData: quill.IconButtonData(
                    iconSize: 17,
                    padding: EdgeInsets.all(2),
                    visualDensity: VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(width: 26, height: 26),
                    color: Color(0xFF8C7A6A),
                  ),
                  iconButtonSelectedData: quill.IconButtonData(
                    iconSize: 17,
                    padding: EdgeInsets.all(2),
                    visualDensity: VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(width: 26, height: 26),
                    color: AppColors.deepOcean,
                  ),
                ),
                multiRowsDisplay: true,
                showFontFamily: false,
                showFontSize: false,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showColorButton: true,
                showBackgroundColorButton: true,
                showHeaderStyle: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: false,
                showQuote: true,
                showCodeBlock: true,
                showLink: true,
                showSubscript: true,
                showSuperscript: true,
                showUndo: false,
                showRedo: false,
                showSearchButton: false,
                showAlignmentButtons: false,
                showIndent: false,
                showClearFormat: false,
                showDirection: false,
              ),
            ),
          ),
          SizedBox(
            height: _eventBlockEditorBodyHeight,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: quill.QuillEditorConfig(
                    placeholder: context.t(placeholder),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventActionRail extends StatelessWidget {
  const _EventActionRail({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canDelete,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _eventBlockSoftLine)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _EventRailIconButton(
            icon: Icons.keyboard_arrow_up,
            active: canMoveUp,
            onTap: onMoveUp,
          ),
          const SizedBox(height: 8),
          _EventRailIconButton(
            icon: Icons.keyboard_arrow_down,
            active: canMoveDown,
            onTap: onMoveDown,
          ),
          const Spacer(),
          _EventRailIconButton(
            icon: Icons.delete_outline,
            active: canDelete,
            activeColor: AppColors.actionRed,
            onTap: onDelete,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _EventRailIconButton extends StatelessWidget {
  const _EventRailIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeColor = AppColors.deepOcean,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? activeColor
        : AppColors.iconMuted.withValues(alpha: 0.38);
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _EventTinyIconButton extends StatelessWidget {
  const _EventTinyIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? onTap : null,
        child: Container(
          width: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? AppColors.actionRed.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: active
                  ? AppColors.actionRed.withValues(alpha: 0.14)
                  : _eventBlockStrongLine.withValues(alpha: 0.6),
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: active
                ? AppColors.actionRed
                : AppColors.iconMuted.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}

class _EventCollapseButton extends StatelessWidget {
  const _EventCollapseButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            collapsed ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_down,
            size: 22,
            color: _eventBlockMutedText,
          ),
        ),
      ),
    );
  }
}

class _EventSmallAddButton extends StatelessWidget {
  const _EventSmallAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warmHorizon,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.warmHorizon.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '+ ${context.t(label)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDashedBorderPainter extends CustomPainter {
  const _EventDashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;
  static const _strokeWidth = 1.2;
  static const _dashWidth = 6.0;
  static const _dashGap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EventDashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
