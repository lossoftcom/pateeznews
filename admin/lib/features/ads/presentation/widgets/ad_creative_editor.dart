import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_toast.dart';
import '../../../../shared/widgets/media_library_dialog.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../../data/admin_ads_repository.dart';

/// Reklam ekleme / düzenleme penceresini açar. Kaydedilirse oluşturulan
/// [AdCreative] döner, iptal edilirse `null`.
Future<AdCreative?> showAdCreativeEditor(
  BuildContext context, {
  required AdSlot slot,
  AdCreative? existing,
  MediaService? mediaService,
}) {
  final mobile = MediaQuery.sizeOf(context).width < 700;
  if (mobile) {
    return showGeneralDialog<AdCreative>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AdCreativeEditor',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, _) => SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: _AdCreativeDrawerFrame(
              child: _AdCreativeEditorDialog(
                slot: slot,
                existing: existing,
                mediaService: mediaService ?? MediaService(),
                mobileDrawer: true,
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  return showGeneralDialog<AdCreative>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'AdCreativeEditor',
    barrierColor: AppColors.deepOcean.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, a1, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.97,
            end: 1,
          ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, _) => _AdCreativeEditorDialog(
      slot: slot,
      existing: existing,
      mediaService: mediaService ?? MediaService(),
      mobileDrawer: false,
    ),
  );
}

class _AdCreativeDrawerFrame extends StatelessWidget {
  const _AdCreativeDrawerFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Container(
      width: size.width,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            spreadRadius: 2,
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AdCreativeEditorDialog extends StatefulWidget {
  const _AdCreativeEditorDialog({
    required this.slot,
    required this.existing,
    required this.mediaService,
    required this.mobileDrawer,
  });

  final AdSlot slot;
  final AdCreative? existing;
  final MediaService mediaService;
  final bool mobileDrawer;

  @override
  State<_AdCreativeEditorDialog> createState() =>
      _AdCreativeEditorDialogState();
}

class _AdCreativeEditorDialogState extends State<_AdCreativeEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _widthCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _linkCtrl;
  late final TextEditingController _htmlCtrl;
  late final TextEditingController _adsenseCtrl;

  late AdCreativeType _type;
  late bool _responsive;
  String _imageUrl = '';
  int _weight = 1;
  bool _active = true;
  bool _fitToWidth = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final slot = widget.slot;
    _type = existing?.type ?? AdCreativeType.image;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _linkCtrl = TextEditingController(text: existing?.linkUrl ?? '');
    _htmlCtrl = TextEditingController(text: existing?.htmlCode ?? '');
    _adsenseCtrl = TextEditingController(text: existing?.adsenseSlotId ?? '');
    _imageUrl = existing?.imageUrl ?? '';
    _weight = existing?.weight ?? 1;
    _active = existing?.active ?? true;

    final bool slotFlexible = slot.responsive || slot.fullscreen;
    final int initialW = existing?.responsive == true
        ? 0
        : (existing?.width ?? (slotFlexible ? 0 : slot.width));
    final int initialH = existing?.responsive == true
        ? 0
        : (existing?.height ?? (slotFlexible ? 0 : slot.height));
    _responsive = existing?.responsive ?? slotFlexible;
    final defaults = _platformDefault();
    _widthCtrl = TextEditingController(
      text: '${initialW > 0 ? initialW : defaults.$1}',
    );
    _heightCtrl = TextEditingController(
      text: '${initialH > 0 ? initialH : defaults.$2}',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _linkCtrl.dispose();
    _htmlCtrl.dispose();
    _adsenseCtrl.dispose();
    super.dispose();
  }

  (int, int) _platformDefault() =>
      widget.slot.platform == AdPlatform.mobile ? (320, 100) : (728, 90);

  int get _width => int.tryParse(_widthCtrl.text.trim()) ?? 0;
  int get _height => int.tryParse(_heightCtrl.text.trim()) ?? 0;

  void _applyPreset(AdSize size) {
    setState(() {
      if (size.responsive || size.fullscreen) {
        _responsive = true;
      } else {
        _responsive = false;
        _widthCtrl.text = '${size.width}';
        _heightCtrl.text = '${size.height}';
      }
    });
  }

  Future<void> _pickImage() async {
    final url = await showMediaLibraryDialog(
      context,
      type: 'image',
      mediaService: widget.mediaService,
    );
    if (!mounted || url == null || url.isEmpty) return;
    setState(() => _imageUrl = url);
  }

  void _save() {
    if (_type == AdCreativeType.image && _imageUrl.trim().isEmpty) {
      AdminToast.show(
        context,
        message: 'Lütfen önce bir görsel seçin.',
        tone: AdminToastTone.error,
      );
      return;
    }
    if (_type == AdCreativeType.html && _htmlCtrl.text.trim().isEmpty) {
      AdminToast.show(
        context,
        message: 'Lütfen HTML / embed kodunu girin.',
        tone: AdminToastTone.error,
      );
      return;
    }

    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : switch (_type) {
            AdCreativeType.adsense => 'AdSense reklamı',
            AdCreativeType.html => 'HTML reklam',
            AdCreativeType.image => 'Görsel reklam',
          };

    final creative = AdCreative(
      id: widget.existing?.id ?? generateAdId('ad'),
      name: name,
      type: _type,
      width: _responsive ? 0 : _width,
      height: _responsive ? 0 : _height,
      responsive: _responsive,
      imageUrl: _imageUrl.trim(),
      linkUrl: _linkCtrl.text.trim(),
      htmlCode: _htmlCtrl.text.trim(),
      adsenseSlotId: _adsenseCtrl.text.trim(),
      weight: _weight,
      active: _active,
      accentColor: widget.existing?.accentColor,
    );
    Navigator.of(context).pop(creative);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final viewport = MediaQuery.sizeOf(context);
    final maxHeight = math.min(860.0, math.max(560.0, viewport.height - 72));
    final horizontalInset = viewport.width < 720 ? 16.0 : 28.0;
    if (widget.mobileDrawer) {
      return _dialogContent(isEdit, mobile: true);
    }

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 940, maxHeight: maxHeight),
        child: _dialogContent(isEdit, mobile: false),
      ),
    );
  }

  Widget _dialogContent(bool isEdit, {required bool mobile}) {
    final body = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        mobile ? 14 : 22,
        mobile ? 16 : 20,
        mobile ? 14 : 22,
        mobile ? 18 : 22,
      ),
      child: _editorBody(),
    );

    return Column(
      mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _header(isEdit),
        mobile ? Expanded(child: body) : Flexible(child: body),
        _footer(isEdit),
      ],
    );
  }

  Widget _editorBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 820) return _wideEditorBody();
        return _narrowEditorBody();
      },
    );
  }

  Widget _narrowEditorBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepLabel(1, 'Reklam türü'),
        const SizedBox(height: 10),
        _sourceTiles(),
        const SizedBox(height: 22),
        _stepLabel(2, 'Boyut', hint: 'AdSense standart ölçüleri'),
        const SizedBox(height: 10),
        _sizeGrid(),
        const SizedBox(height: 12),
        _customSizeRow(),
        const SizedBox(height: 22),
        _stepLabel(3, 'İçerik'),
        const SizedBox(height: 10),
        _contentPanel(),
        const SizedBox(height: 22),
        _stepLabel(4, 'Yayın ayarları'),
        const SizedBox(height: 10),
        _publishRow(),
        const SizedBox(height: 22),
        _previewBlock(),
      ],
    );
  }

  Widget _wideEditorBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stepLabel(1, 'Reklam türü'),
              const SizedBox(height: 10),
              _sourceTiles(),
              const SizedBox(height: 22),
              _stepLabel(2, 'Boyut', hint: 'AdSense standart ölçüleri'),
              const SizedBox(height: 10),
              _sizeGrid(),
              const SizedBox(height: 12),
              _customSizeRow(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stepLabel(3, 'İçerik'),
              const SizedBox(height: 10),
              _contentPanel(),
              const SizedBox(height: 22),
              _stepLabel(4, 'Yayın ayarları'),
              const SizedBox(height: 10),
              _publishRow(),
              const SizedBox(height: 22),
              _previewBlock(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _previewHeader(),
        const SizedBox(height: 8),
        _AdRealSizePreview(
          type: _type,
          width: _width,
          height: _height,
          responsive: _responsive,
          imageUrl: _imageUrl,
          htmlCode: _htmlCtrl.text,
          fitToWidth: _fitToWidth,
        ),
      ],
    );
  }

  Widget _header(bool isEdit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SymbolIcon(
            isEdit ? Symbols.edit_outlined : Symbols.add,
            color: AppColors.actionRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Reklamı düzenle' : 'Reklam ekle',
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  '${widget.slot.name} alanına',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12.5,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            mouseCursor: SystemMouseCursors.click,
            icon: const SymbolIcon(
              Symbols.close,
              color: AppColors.iconMuted,
              size: 20,
            ),
            tooltip: 'Kapat',
          ),
        ],
      ),
    );
  }

  Widget _stepLabel(int step, String label, {String? hint}) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.deepOcean,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            letterSpacing: 0,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '— $hint',
              style: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 12,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sourceTiles() {
    return Row(
      children: [
        _sourceTile(
          AdCreativeType.adsense,
          Symbols.google_fill,
          'Google AdSense',
          'Otomatik',
        ),
        const SizedBox(width: 9),
        _sourceTile(
          AdCreativeType.image,
          Symbols.add_photo_alternate_outlined,
          'Görsel yükle',
          'JPG·PNG·WebP·GIF·SVG',
        ),
        const SizedBox(width: 9),
        _sourceTile(
          AdCreativeType.html,
          Symbols.code_outlined,
          'HTML / Kod',
          'Embed',
        ),
      ],
    );
  }

  Widget _sourceTile(
    AdCreativeType type,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final selected = _type == type;
    return Expanded(
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(AppRadius.value),
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3F6F8) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected ? AppColors.deepOcean : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              SymbolIcon(icon, color: AppColors.deepOcean, size: 24),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.placeholder,
                  fontSize: 10.5,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sizeGrid() {
    final sizes = AdSize.forPlatform(widget.slot.platform);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final columns = compact ? 3 : 4;
        final cardWidth =
            ((constraints.maxWidth - (8 * (columns - 1))) / columns)
                .clamp(82.0, compact ? 104.0 : 112.0)
                .toDouble();

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final size in sizes)
              _sizeChip(size, width: cardWidth, compact: compact),
          ],
        );
      },
    );
  }

  Widget _sizeChip(
    AdSize size, {
    required double width,
    required bool compact,
  }) {
    final selected = (size.responsive || size.fullscreen)
        ? _responsive
        : (!_responsive && _width == size.width && _height == size.height);
    final maxBox = compact ? 30.0 : 34.0;
    double bw = maxBox, bh = maxBox * 0.4;
    if (!size.responsive && !size.fullscreen && size.width > 0) {
      final scale = maxBox / math.max(size.width, size.height);
      bw = math.max(8, size.width * scale);
      bh = math.max(6, size.height * scale);
    }
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: () => _applyPreset(size),
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(
          vertical: compact ? 8 : 9,
          horizontal: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF3F6F8) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(
            color: selected ? AppColors.deepOcean : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: compact ? 34 : 38,
              child: Center(
                child: (size.responsive || size.fullscreen)
                    ? SymbolIcon(
                        size.fullscreen
                            ? Symbols.crop_square_outlined
                            : Symbols.swap_horiz,
                        color: AppColors.support,
                        size: 22,
                      )
                    : Container(
                        width: bw,
                        height: bh,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2F4),
                          border: Border.all(color: AppColors.deepOcean),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              size.dimensionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                fontSize: 11.2,
                letterSpacing: 0,
              ),
            ),
            Text(
              size.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 9.6,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customSizeRow() {
    final message = _responsive
        ? null
        : AdSize.validationMessage(_width, _height);
    final compliant = !_responsive && message == null;
    final status = _responsive
        ? 'Duyarlı'
        : compliant
        ? 'AdSense uyumlu'
        : message ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 370;
        final fields = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: compact ? 68 : 72, child: _numField(_widthCtrl)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('×', style: TextStyle(color: AppColors.placeholder)),
            ),
            SizedBox(width: compact ? 68 : 72, child: _numField(_heightCtrl)),
            const SizedBox(width: 6),
            const Text(
              'px',
              style: TextStyle(color: AppColors.placeholder, fontSize: 12),
            ),
          ],
        );
        final statusText = Text(
          status,
          textAlign: compact ? TextAlign.start : TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _responsive
                ? AppColors.inkSoft
                : compliant
                ? const Color(0xFF0F6E56)
                : const Color(0xFF9A6207),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Özel boyut',
                style: TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              fields,
              const SizedBox(height: 6),
              statusText,
            ],
          );
        }

        return Row(
          children: [
            const Text(
              'Özel boyut:',
              style: TextStyle(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 10),
            fields,
            const SizedBox(width: 10),
            Expanded(child: statusText),
          ],
        );
      },
    );
  }

  Widget _numField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      enabled: !_responsive,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontSize: 13,
        letterSpacing: 0,
      ),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _contentPanel() {
    return switch (_type) {
      AdCreativeType.adsense => _adsensePanel(),
      AdCreativeType.image => _imagePanel(),
      AdCreativeType.html => _htmlPanel(),
    };
  }

  Widget _adsensePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _adsenseCtrl,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            letterSpacing: 0,
          ),
          decoration: const InputDecoration(
            hintText: 'AdSense reklam birimi kimliği — örn. 1234567890',
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SymbolIcon(
              Symbols.info_outline,
              color: AppColors.placeholder,
              size: 16,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Boş bırakırsan Google otomatik (duyarlı) reklam seçer.',
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 11.5,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _imagePanel() {
    final hasImage = _imageUrl.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(AppRadius.value),
          onTap: _pickImage,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: AppColors.line,
                width: 1.4,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                const SymbolIcon(
                  Symbols.cloud_upload_outlined,
                  color: AppColors.deepOcean,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  hasImage
                      ? 'Görsel seçildi — değiştirmek için tıkla'
                      : 'Görsel seç ya da yükle',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasImage
                      ? _imageUrl.split('/').last
                      : 'JPG · PNG · WebP · GIF · SVG — aşağıda gerçek boyutta görünür',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.placeholder,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _linkCtrl,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            letterSpacing: 0,
          ),
          decoration: const InputDecoration(
            prefixIcon: Padding(
              padding: EdgeInsets.all(10),
              child: SymbolIcon(
                Symbols.link,
                color: AppColors.iconMuted,
                size: 18,
              ),
            ),
            hintText: 'Tıklanınca gidilecek bağlantı (opsiyonel)',
          ),
        ),
      ],
    );
  }

  Widget _htmlPanel() {
    return TextField(
      controller: _htmlCtrl,
      maxLines: 4,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontFamily: 'monospace',
        color: AppColors.deepOcean,
        fontSize: 12.5,
        letterSpacing: 0,
      ),
      decoration: const InputDecoration(
        hintText:
            '<a href="..."><img src="reklam.webp" width="728" height="90"></a>',
      ),
    );
  }

  Widget _publishRow() {
    return Column(
      children: [
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            letterSpacing: 0,
          ),
          decoration: const InputDecoration(
            hintText: 'Reklam adı (örn. Bahar kampanyası)',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const SymbolIcon(
              Symbols.dynamic_feed,
              color: AppColors.iconMuted,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              'Ağırlık',
              style: TextStyle(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                letterSpacing: 0,
              ),
            ),
            Expanded(
              child: Slider(
                mouseCursor: SystemMouseCursors.click,
                value: _weight.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: AppColors.actionRed,
                label: '$_weight',
                onChanged: (v) => setState(() => _weight = v.round()),
              ),
            ),
            SizedBox(
              width: 26,
              child: Text(
                '$_weight',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Reklam aktif',
                style: TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  letterSpacing: 0,
                ),
              ),
            ),
            _AdEditorSwitch(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewHeader() {
    final ruler = _responsive ? 'Duyarlı' : '$_width × $_height px';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final title = Row(
          children: [
            const SymbolIcon(
              Symbols.crop_square_outlined,
              color: AppColors.deepOcean,
              size: 18,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Gerçek boyut önizleme',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        );
        final meta = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _previewMetaChip(ruler),
            if (!_responsive) _scaleToggle(compact: compact),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 8), meta],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 8),
            Flexible(child: meta),
          ],
        );
      },
    );
  }

  Widget _previewMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F4),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _scaleToggle({bool compact = false}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.softLine,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scaleButton(
            '%100',
            !_fitToWidth,
            () => setState(() => _fitToWidth = false),
            compact: compact,
          ),
          _scaleButton(
            'Sığdır',
            _fitToWidth,
            () => setState(() => _fitToWidth = true),
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _scaleButton(
    String label,
    bool selected,
    VoidCallback onTap, {
    bool compact = false,
  }) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.deepOcean : AppColors.inkSoft,
            fontWeight: FontWeight.w600,
            fontSize: compact ? 11 : 11.5,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _footer(bool isEdit) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: mobile
          ? Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const SymbolIcon(
                        Symbols.close,
                        color: AppColors.deepOcean,
                        size: 16,
                      ),
                      label: const Text('İptal'),
                      style:
                          TextButton.styleFrom(
                            foregroundColor: AppColors.deepOcean,
                            backgroundColor: Colors.white,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.value,
                              ),
                              side: const BorderSide(color: AppColors.line),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ).copyWith(
                            mouseCursor: const WidgetStatePropertyAll(
                              SystemMouseCursors.click,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextButton.icon(
                      onPressed: _save,
                      icon: const SymbolIcon(
                        Symbols.save,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: const Text('Kaydet'),
                      style:
                          TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: AppColors.actionRed,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.value,
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ).copyWith(
                            mouseCursor: const WidgetStatePropertyAll(
                              SystemMouseCursors.click,
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogTextButton(
                  label: 'İptal',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                _DialogPrimaryButton(label: 'Kaydet', onPressed: _save),
              ],
            ),
    );
  }
}

class _DialogTextButton extends StatelessWidget {
  const _DialogTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style:
          TextButton.styleFrom(
            foregroundColor: AppColors.deepOcean,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(64, 38),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ).copyWith(
            mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
          ),
      child: Text(label),
    );
  }
}

class _DialogPrimaryButton extends StatelessWidget {
  const _DialogPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.deepOcean,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              minimumSize: const Size(104, 38),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Text(label),
      ),
    );
  }
}

class _AdEditorSwitch extends StatelessWidget {
  const _AdEditorSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 42,
            height: 24,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? AppColors.actionRed : AppColors.softLine,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: value
                    ? AppColors.actionRed
                    : AppColors.line.withValues(alpha: 0.9),
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: value
                    ? const SymbolIcon(
                        Symbols.check,
                        color: AppColors.actionRed,
                        size: 12,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reklamı gerçek piksel boyutunda gösteren önizleme paneli.
class _AdRealSizePreview extends StatelessWidget {
  const _AdRealSizePreview({
    required this.type,
    required this.width,
    required this.height,
    required this.responsive,
    required this.imageUrl,
    required this.htmlCode,
    required this.fitToWidth,
  });

  final AdCreativeType type;
  final int width;
  final int height;
  final bool responsive;
  final String imageUrl;
  final String htmlCode;
  final bool fitToWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F7),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final avail = constraints.maxWidth;
          if (responsive || width <= 0 || height <= 0) {
            return _responsivePreview();
          }

          final scale = fitToWidth ? math.min(1.0, avail / width) : 1.0;
          final dispW = width * scale;
          final dispH = height * scale;

          final scaled = SizedBox(
            width: dispW,
            height: dispH,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: width.toDouble(),
                height: height.toDouble(),
                child: _creativeContent(),
              ),
            ),
          );

          final body = (!fitToWidth && dispW > avail)
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: scaled,
                )
              : Align(alignment: Alignment.center, child: scaled);

          return Column(
            children: [
              body,
              const SizedBox(height: 8),
              Text(
                fitToWidth
                    ? 'Sığdırıldı · %${(scale * 100).round()} ölçek (gerçek $width × $height px)'
                    : 'Gerçek piksel boyutunda (%100). Geniş reklamlar için yatay kaydır.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _responsivePreview() {
    return Column(
      children: [
        Container(
          height: 84,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.placeholder, width: 1.2),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SymbolIcon(
                Symbols.swap_horiz,
                color: AppColors.support,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                'Duyarlı reklam — ekran genişliğine göre uyum sağlar',
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 11.5,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _creativeContent() {
    switch (type) {
      case AdCreativeType.image:
        if (imageUrl.trim().isEmpty) {
          return _placeholder(
            'Görsel seçilince burada gerçek boyutta görünür',
            const Color(0xFFF8F9FA),
            AppColors.placeholder,
          );
        }
        return Image.network(
          imageUrl,
          fit: BoxFit.fill,
          errorBuilder: (_, _, _) => _placeholder(
            'Görsel yüklenemedi',
            const Color(0xFFFCEBEB),
            const Color(0xFFB8281D),
          ),
        );
      case AdCreativeType.html:
        return Container(
          color: Colors.white,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SymbolIcon(
                Symbols.code_outlined,
                color: AppColors.deepOcean,
                size: 22,
              ),
              SizedBox(height: 4),
              Text(
                'HTML reklam · canlı sitede bu ölçüde render edilir',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        );
      case AdCreativeType.adsense:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEB),
            border: Border.all(color: const Color(0xFFE9A59F)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Google AdSense',
                  style: TextStyle(
                    color: Color(0xFFB8281D),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  'otomatik reklam · $width × $height',
                  style: const TextStyle(
                    color: Color(0xFFB8281D),
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _placeholder(String text, Color bg, Color fg) {
    return Container(
      color: bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
