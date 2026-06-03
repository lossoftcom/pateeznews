import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import 'symbol_icon.dart';

/// Shared, production-grade building blocks for the **mobile** card layout used
/// across every admin list/table screen.
///
/// The desktop layout is never touched: screens render these only inside their
/// `if (mobile) { ... }` branch. The goal is a single, consistent, modern card
/// system — always-visible search, filters tucked into a bottom sheet, clean
/// selectable cards and a compact pager — so authors get the same fast, easy
/// experience everywhere.
class AdminMobile {
  const AdminMobile._();

  /// Breakpoint below which screens switch to the card layout.
  static const double breakpoint = 800;

  /// Softer, friendlier radius for mobile surfaces than the desktop 4px.
  static const double cardRadius = 16;
  static const double controlRadius = 12;

  /// Comfortable touch height for primary controls.
  static const double controlHeight = 46;

  static BoxDecoration cardDecoration({required bool selected}) {
    return BoxDecoration(
      color: selected
          ? AppColors.deepOcean.withValues(alpha: 0.035)
          : Colors.white,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(
        color: selected
            ? AppColors.deepOcean.withValues(alpha: 0.34)
            : AppColors.line.withValues(alpha: 0.9),
        width: selected ? 1.4 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.deepOcean.withValues(alpha: selected ? 0.10 : 0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Toolbar: always-visible search + a "Filters" button (with active badge).
// ---------------------------------------------------------------------------

class AdminMobileToolbar extends StatefulWidget {
  const AdminMobileToolbar({
    super.key,
    required this.query,
    required this.hintText,
    required this.onSearchChanged,
    required this.activeFilterCount,
    required this.onOpenFilters,
    this.filtersLabel = 'Filtreler',
    this.showFilters = true,
    this.controller,
  });

  final String query;
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final int activeFilterCount;
  final VoidCallback onOpenFilters;
  final String filtersLabel;
  final bool showFilters;

  /// Optional external controller. When provided, the screen owns search state
  /// (e.g. drives reload via its own listener) and this widget won't dispose it.
  final TextEditingController? controller;

  @override
  State<AdminMobileToolbar> createState() => _AdminMobileToolbarState();
}

class _AdminMobileToolbarState extends State<AdminMobileToolbar> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = TextEditingController(text: widget.query);
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(covariant AdminMobileToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ownsController && widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = widget.activeFilterCount > 0;
    final search = Container(
      height: AdminMobile.controlHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AdminMobile.controlRadius),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onSearchChanged,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: AppColors.deepOcean,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.placeholder,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: SymbolIcon(
              Symbols.search,
              color: AppColors.iconMuted,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: AdminMobile.controlHeight,
          ),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  visualDensity: VisualDensity.compact,
                  splashRadius: 18,
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.iconMuted,
                    size: 18,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onSearchChanged('');
                    setState(() {});
                  },
                ),
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );

    if (!widget.showFilters) return search;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        search,
        const SizedBox(height: 10),
        AdminMobileFiltersButton(
          label: widget.filtersLabel,
          count: widget.activeFilterCount,
          active: hasFilters,
          fullWidth: true,
          onPressed: () {
            FocusScope.of(context).unfocus();
            widget.onOpenFilters();
          },
        ),
      ],
    );
  }
}

class AdminMobileActionButton extends StatelessWidget {
  const AdminMobileActionButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onPressed,
    this.primary = false,
    this.active = false,
    this.count = 0,
    this.fullWidth = false,
    this.backgroundColor,
  });

  final String label;
  final Widget leading;
  final VoidCallback onPressed;
  final bool primary;
  final bool active;
  final int count;
  final bool fullWidth;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = primary ? Colors.white : AppColors.deepOcean;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: fullWidth ? double.infinity : null,
          height: AdminMobile.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: primary
                ? backgroundColor ?? AppColors.actionRed
                : active
                ? AppColors.deepOcean.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(AdminMobile.controlRadius),
            border: Border.all(
              color: primary
                  ? backgroundColor ?? AppColors.actionRed
                  : active
                  ? AppColors.deepOcean.withValues(alpha: 0.45)
                  : AppColors.line.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminMobileFiltersButton extends StatelessWidget {
  const AdminMobileFiltersButton({
    super.key,
    required this.label,
    required this.count,
    required this.active,
    required this.onPressed,
    this.fullWidth = false,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return AdminMobileActionButton(
      label: label,
      leading: const _FunnelIcon(),
      count: count,
      active: active,
      fullWidth: fullWidth,
      onPressed: onPressed,
    );
  }
}

/// A small funnel drawn with a [CustomPaint] — the icon font has no filter
/// glyph, so we render a crisp one to keep the control instantly recognizable.
class _FunnelIcon extends StatelessWidget {
  const _FunnelIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _FunnelPainter()),
    );
  }
}

class _FunnelPainter extends CustomPainter {
  const _FunnelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.deepOcean
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.16)
      ..lineTo(w * 0.92, h * 0.16)
      ..lineTo(w * 0.58, h * 0.54)
      ..lineTo(w * 0.58, h * 0.9)
      ..lineTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.42, h * 0.54)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FunnelPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Filter bottom sheet.
// ---------------------------------------------------------------------------

/// Opens a premium modal bottom sheet for filters. [contentBuilder] receives a
/// [StateSetter] so filter fields can refresh the sheet's own display while
/// also calling the screen's change callbacks.
Future<void> showAdminMobileFilterSheet({
  required BuildContext context,
  required Widget Function(BuildContext context, StateSetter setSheetState)
  contentBuilder,
  VoidCallback? onClear,
  String title = 'Filtreler',
  String clearLabel = 'Temizle',
  String applyLabel = 'Sonuçları göster',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.deepOcean.withValues(alpha: 0.32),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final media = MediaQuery.of(context);
          return Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepOcean,
                          ),
                        ),
                      ),
                      if (onClear != null)
                        TextButton(
                          onPressed: () {
                            onClear();
                            setSheetState(() {});
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.actionRed,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(clearLabel),
                        ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const SymbolIcon(
                          Symbols.close,
                          color: AppColors.iconMuted,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: AppColors.line.withValues(alpha: 0.8),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: contentBuilder(context, setSheetState),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    16 + media.padding.bottom,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.deepOcean,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(applyLabel),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// A labelled dropdown styled for use inside [showAdminMobileFilterSheet].
class AdminMobileFilterField extends StatelessWidget {
  const AdminMobileFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 48,
              padding: const EdgeInsets.only(left: 14, right: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AdminMobile.controlRadius),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.9),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: safeValue,
                  borderRadius: BorderRadius.circular(
                    AdminMobile.controlRadius,
                  ),
                  dropdownColor: Colors.white,
                  focusColor: Colors.transparent,
                  icon: const SymbolIcon(
                    Symbols.keyboard_arrow_down,
                    color: AppColors.iconMuted,
                    size: 20,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w600,
                  ),
                  items: items,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary call-to-action button (e.g. "Add"), styled to match the toolbar.
class AdminMobilePrimaryButton extends StatelessWidget {
  const AdminMobilePrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppColors.actionRed,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return AdminMobileActionButton(
      label: label,
      leading: SymbolIcon(icon, color: Colors.white, size: 18),
      primary: true,
      backgroundColor: backgroundColor,
      fullWidth: fullWidth,
      onPressed: onPressed,
    );
  }
}

// ---------------------------------------------------------------------------
// Contextual selection bar (shown when one or more rows are selected).
// ---------------------------------------------------------------------------

class AdminMobileSelectionBar extends StatelessWidget {
  const AdminMobileSelectionBar({
    super.key,
    required this.selectedCount,
    required this.onClear,
    required this.onDelete,
    this.label,
    this.deleteLabel = 'Sil',
  });

  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onDelete;
  final String? label;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.deepOcean,
        borderRadius: BorderRadius.circular(AdminMobile.controlRadius),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
            icon: const SymbolIcon(
              Symbols.close,
              color: Colors.white,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              label ?? '$selectedCount seçildi',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SymbolIcon(Symbols.delete, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(deleteLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The card shell.
// ---------------------------------------------------------------------------

class AdminMobileCard extends StatelessWidget {
  const AdminMobileCard({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(15),
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: AdminMobile.cardDecoration(selected: selected),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminMobile.cardRadius),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3.5, color: AppColors.deepOcean),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Standard header row: leading visual + title/subtitle + trailing (menu).
class AdminMobileCardHeader extends StatelessWidget {
  const AdminMobileCardHeader({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTapContent,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTapContent;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle.merge(
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.deepOcean,
            height: 1.25,
          ),
          child: title,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.support,
              height: 1.2,
            ),
            child: subtitle!,
          ),
        ],
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: onTapContent == null
              ? content
              : MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapContent,
                    child: content,
                  ),
                ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Rounded leading visual for thumbnails / avatars / icons.
class AdminMobileThumb extends StatelessWidget {
  const AdminMobileThumb({
    super.key,
    this.imageUrl,
    this.fallbackIcon = Symbols.visibility,
    this.size = 54,
    this.fit = BoxFit.cover,
    this.child,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final double size;
  final BoxFit fit;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          child ??
          (url.isEmpty
              ? Center(
                  child: SymbolIcon(
                    fallbackIcon,
                    color: AppColors.iconMuted,
                    size: size * 0.4,
                  ),
                )
              : Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: fit,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, _, _) => Center(
                    child: SymbolIcon(
                      fallbackIcon,
                      color: AppColors.iconMuted,
                      size: size * 0.4,
                    ),
                  ),
                )),
    );
  }
}

/// Circular initials avatar (people-oriented screens).
class AdminMobileAvatar extends StatelessWidget {
  const AdminMobileAvatar({
    super.key,
    required this.label,
    this.imageUrl,
    this.size = 46,
  });

  final String label;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final initials = _initials(label);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: AppColors.deepOcean,
              ),
            )
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepOcean,
                ),
              ),
            ),
    );
  }

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Badges & pills.
// ---------------------------------------------------------------------------

class AdminMobileStatusPill extends StatelessWidget {
  const AdminMobileStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.showDot = true,
  });

  final String label;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminMobileChip extends StatelessWidget {
  const AdminMobileChip({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.deepOcean,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 8 : 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            SymbolIcon(icon!, color: fg, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label + value used inside the card footer/meta grid.
class AdminMobileMeta extends StatelessWidget {
  const AdminMobileMeta({
    super.key,
    required this.icon,
    required this.value,
    this.color = AppColors.support,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SymbolIcon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Selection checkbox.
// ---------------------------------------------------------------------------

class AdminMobileCheckbox extends StatelessWidget {
  const AdminMobileCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Checkbox(
        value: value,
        tristate: tristate,
        onChanged: onChanged,
        activeColor: AppColors.deepOcean,
        checkColor: Colors.white,
        side: BorderSide(
          color: AppColors.line.withValues(alpha: 1),
          width: 1.6,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overflow ("...") action menu — anchored popover, reusable by every screen.
// ---------------------------------------------------------------------------

class AdminMobileMenuAction {
  const AdminMobileMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class AdminMobileMenuButton extends StatefulWidget {
  const AdminMobileMenuButton({super.key, required this.actions, this.tooltip});

  final List<AdminMobileMenuAction> actions;
  final String? tooltip;

  @override
  State<AdminMobileMenuButton> createState() => _AdminMobileMenuButtonState();
}

class _AdminMobileMenuButtonState extends State<AdminMobileMenuButton> {
  final _layerLink = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  void _toggle() {
    if (_entry == null) {
      _open();
    } else {
      _close();
    }
  }

  void _open() {
    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 6),
              child: _MenuCard(
                actions: widget.actions
                    .map(
                      (a) => AdminMobileMenuAction(
                        icon: a.icon,
                        label: a.label,
                        danger: a.danger,
                        onTap: () {
                          _close();
                          a.onTap();
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.9),
                ),
              ),
              child: const SymbolIcon(
                Symbols.menu,
                color: AppColors.inkSoft,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.actions});

  final List<AdminMobileMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 224,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.12),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              InkWell(
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(10),
                onTap: action.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      SymbolIcon(
                        action.icon,
                        color: action.danger
                            ? AppColors.actionRed
                            : AppColors.deepOcean,
                        size: 19,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: action.danger
                                ? AppColors.actionRed
                                : AppColors.deepOcean,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List shell (loading / empty / list) and pager.
// ---------------------------------------------------------------------------

class AdminMobileListView extends StatelessWidget {
  const AdminMobileListView({
    super.key,
    required this.loading,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyLabel,
    this.gap = 12,
    this.padding = EdgeInsets.zero,
  });

  final bool loading;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyLabel;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (loading && itemCount == 0) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.deepOcean,
          ),
        ),
      );
    }
    if (itemCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SymbolIcon(
                    Symbols.search,
                    color: AppColors.iconMuted,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) => SizedBox(height: gap),
      itemBuilder: itemBuilder,
    );
  }
}

class AdminMobilePager extends StatelessWidget {
  const AdminMobilePager({
    super.key,
    required this.page,
    required this.lastPage,
    required this.rangeText,
    required this.loading,
    required this.onPageChanged,
  });

  final int page;
  final int lastPage;
  final String rangeText;
  final bool loading;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final hasPrevious = page > 1 && !loading;
    final hasNext = page < lastPage && !loading;
    return Container(
      height: AdminMobile.controlHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AdminMobile.controlRadius),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          _PagerArrow(
            icon: Symbols.arrow_forward,
            flip: true,
            enabled: hasPrevious,
            onTap: () => onPageChanged(page - 1),
          ),
          Expanded(
            child: Text(
              rangeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _PagerArrow(
            icon: Symbols.arrow_forward,
            flip: false,
            enabled: hasNext,
            onTap: () => onPageChanged(page + 1),
          ),
        ],
      ),
    );
  }
}

class _PagerArrow extends StatelessWidget {
  const _PagerArrow({
    required this.icon,
    required this.flip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool flip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 38,
      height: 38,
      child: Center(
        child: Opacity(
          opacity: enabled ? 1 : 0.32,
          child: flip
              ? Transform.flip(
                  flipX: true,
                  child: const SymbolIcon(
                    Symbols.arrow_forward,
                    color: AppColors.deepOcean,
                    size: 20,
                  ),
                )
              : const SymbolIcon(
                  Symbols.arrow_forward,
                  color: AppColors.deepOcean,
                  size: 20,
                ),
        ),
      ),
    );
    if (!enabled) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
