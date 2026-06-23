import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/symbol_icon.dart';

Future<T?> showSmsSideDrawer<T>({
  required BuildContext context,
  required Widget child,
  double minWidth = 340,
  double maxWidth = 900,
  Duration transitionDuration = const Duration(milliseconds: 280),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.t('common.cancel'),
    barrierColor: Colors.black.withValues(alpha: 0.48),
    transitionDuration: transitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      final size = MediaQuery.sizeOf(context);
      final mobile = size.width < 700;
      final drawerWidth = mobile
          ? size.width
          : math.min(maxWidth, math.max(minWidth, size.width - 24));

      return SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: drawerWidth,
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
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
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

class SmsMobileSearchPanel extends StatefulWidget {
  const SmsMobileSearchPanel({
    super.key,
    this.controller,
    required this.query,
    required this.hintText,
    required this.onSearchChanged,
    required this.recordCount,
    required this.pageSize,
    required this.onPageSizeChanged,
    this.filterCount = 0,
  });

  final TextEditingController? controller;
  final String query;
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final int recordCount;
  final int pageSize;
  final ValueChanged<int?> onPageSizeChanged;
  final int filterCount;

  @override
  State<SmsMobileSearchPanel> createState() => _SmsMobileSearchPanelState();
}

class _SmsMobileSearchPanelState extends State<SmsMobileSearchPanel> {
  static const _borderColor = Color(0xFFE6EAF0);
  static const _muted = Color(0xFF9AA3AA);
  static const _navy = Color(0xFF2F4053);

  late final TextEditingController _controller;
  late final bool _ownsController;
  var _expanded = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant SmsMobileSearchPanel oldWidget) {
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
    final filterText = widget.filterCount == 0
        ? 'Filtre yok'
        : '${widget.filterCount} filtre';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const SymbolIcon(
                          Symbols.search,
                          color: _muted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextField(
                                controller: _controller,
                                onChanged: widget.onSearchChanged,
                                textAlignVertical: TextAlignVertical.center,
                                cursorColor: _navy,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: _navy,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.hintText,
                                  hintStyle: const TextStyle(
                                    color: _muted,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                              Container(
                                height: 1,
                                color: const Color(0xFFB9BEC4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 78),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _expanded ? 'Gizle' : 'Göster',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _navy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                RotatedBox(
                                  quarterTurns: _expanded ? 2 : 0,
                                  child: const SymbolIcon(
                                    Symbols.keyboard_arrow_down,
                                    color: _navy,
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.recordCount} kayıt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _navy,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              filterText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: _borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SmsMobilePageSizeDropdown(
                  value: widget.pageSize,
                  onChanged: widget.onPageSizeChanged,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SmsMobilePageSizeDropdown extends StatelessWidget {
  const SmsMobilePageSizeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _values = ['25', '50', '100'];

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _values.contains(value.toString())
        ? value.toString()
        : '25';
    return Container(
      width: 66,
      height: 42,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          icon: const SymbolIcon(
            Symbols.keyboard_arrow_down,
            color: Color(0xFF6F7780),
            size: 16,
          ),
          style: const TextStyle(
            color: Color(0xFF2F4053),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(value: '25', child: Text('25')),
            DropdownMenuItem(value: '50', child: Text('50')),
            DropdownMenuItem(value: '100', child: Text('100')),
          ],
          onChanged: (value) => onChanged(int.tryParse(value ?? '')),
        ),
      ),
    );
  }
}
