import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/admin_toast.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_whatsapp_repository.dart';
import 'whatsapp_contact_list_models.dart';
import 'whatsapp_mobile_chrome.dart';

class WhatsappContactListContactsDialog extends StatefulWidget {
  const WhatsappContactListContactsDialog({
    super.key,
    required this.session,
    required this.repository,
    required this.list,
  });

  final AdminSession session;
  final AdminWhatsappRepository repository;
  final AdminWhatsappContactList list;

  @override
  State<WhatsappContactListContactsDialog> createState() =>
      _WhatsappContactListContactsDialogState();
}

class _WhatsappContactListContactsDialogState
    extends State<WhatsappContactListContactsDialog> {
  final _searchController = TextEditingController();
  var _contacts = <AdminWhatsappContact>[];
  var _loading = true;
  var _query = '';

  List<AdminWhatsappContact> get _filteredContacts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts
        .where((contact) {
          return [
            contact.phone,
            contact.firstName,
            contact.lastName,
            contact.email,
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contacts = await widget.repository.fetchContacts(
        widget.session,
        widget.list.id,
      );
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  void _showError(Object error) {
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
  }

  Future<void> _showForm([AdminWhatsappContact? contact]) async {
    final result = await showWhatsappSideDrawer<_WhatsappContactFormResult>(
      context: context,
      minWidth: 380,
      maxWidth: 520,
      child: _WhatsappContactFormDialog(contact: contact),
    );
    if (result == null || !mounted) return;
    try {
      final saved = await widget.repository.saveContact(
        widget.session,
        listId: widget.list.id,
        id: contact?.id,
        phone: result.phone,
        firstName: result.firstName,
        lastName: result.lastName,
        email: result.email,
        active: result.active,
      );
      if (!mounted) return;
      setState(() {
        final index = _contacts.indexWhere((item) => item.id == saved.id);
        if (index == -1) {
          _contacts = [saved, ..._contacts];
        } else {
          _contacts = [
            for (final item in _contacts)
              if (item.id == saved.id) saved else item,
          ];
        }
      });
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _delete(AdminWhatsappContact contact) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('whatsapp.contacts.people.deleteTitle'),
      message: context.t('whatsapp.contacts.people.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.deleteContact(
        widget.session,
        listId: widget.list.id,
        contactId: contact.id,
      );
      if (!mounted) return;
      setState(() {
        _contacts = _contacts
            .where((item) => item.id != contact.id)
            .toList(growable: false);
      });
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.value),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.list.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.deepOcean,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        context.t(
                          'whatsapp.contacts.people.count',
                          values: {'count': _contacts.length},
                        ),
                        style: const TextStyle(
                          color: AppColors.support,
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.t('common.close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const SymbolIcon(Symbols.close, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: context.t('whatsapp.contacts.people.search'),
                    prefixIcon: const SymbolIcon(Symbols.search, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                );
                final addButton = FilledButton.icon(
                  onPressed: () => _showForm(),
                  icon: const SymbolIcon(
                    Symbols.person,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(context.t('whatsapp.contacts.people.new')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.actionRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                  ),
                );

                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [search, const SizedBox(height: 10), addButton],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    addButton,
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : contacts.isEmpty
                  ? Center(
                      child: Text(
                        context.t('whatsapp.contacts.people.empty'),
                        style: const TextStyle(color: AppColors.support),
                      ),
                    )
                  : ListView.separated(
                      itemCount: contacts.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.softLine),
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.surface,
                            child: const SymbolIcon(
                              Symbols.phone_outlined,
                              color: AppColors.deepOcean,
                              size: 19,
                            ),
                          ),
                          title: Text(
                            contact.fullName.isEmpty
                                ? contact.phone
                                : contact.fullName,
                            style: const TextStyle(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                          subtitle: Text(
                            [
                              contact.phone,
                              if (contact.email.isNotEmpty) contact.email,
                              contact.active
                                  ? context.t('whatsapp.contacts.status.active')
                                  : context.t(
                                      'whatsapp.contacts.status.passive',
                                    ),
                            ].join('  |  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: context.t(
                                  'whatsapp.contacts.action.edit',
                                ),
                                onPressed: () => _showForm(contact),
                                icon: const SymbolIcon(
                                  Symbols.edit_square,
                                  size: 18,
                                ),
                              ),
                              IconButton(
                                tooltip: context.t(
                                  'whatsapp.contacts.action.delete',
                                ),
                                onPressed: () => _delete(contact),
                                icon: const SymbolIcon(
                                  Symbols.delete,
                                  color: AppColors.actionRed,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsappContactFormResult {
  const _WhatsappContactFormResult({
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.active,
  });

  final String phone;
  final String firstName;
  final String lastName;
  final String email;
  final bool active;
}

class _WhatsappContactFormDialog extends StatefulWidget {
  const _WhatsappContactFormDialog({this.contact});

  final AdminWhatsappContact? contact;

  @override
  State<_WhatsappContactFormDialog> createState() =>
      _WhatsappContactFormDialogState();
}

class _WhatsappContactFormDialogState
    extends State<_WhatsappContactFormDialog> {
  late final TextEditingController _phoneController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late bool _active;
  var _phoneError = false;
  var _emailError = false;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _phoneController = TextEditingController(text: contact?.phone ?? '');
    _firstNameController = TextEditingController(
      text: contact?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: contact?.lastName ?? '');
    _emailController = TextEditingController(text: contact?.email ?? '');
    _active = contact?.active ?? true;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    final phone = _phoneController.text.trim();
    final validPhone = RegExp(r'^\+?[0-9][0-9\s().-]{6,}$').hasMatch(phone);
    final email = _emailController.text.trim();
    final validEmail =
        email.isEmpty ||
        RegExp(
          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
          caseSensitive: false,
        ).hasMatch(email);
    if (!validPhone || !validEmail) {
      setState(() {
        _phoneError = !validPhone;
        _emailError = !validEmail;
      });
      return;
    }
    Navigator.of(context).pop(
      _WhatsappContactFormResult(
        phone: phone,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: email,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t(
                      widget.contact == null
                          ? 'whatsapp.contacts.people.formNew'
                          : 'whatsapp.contacts.people.formEdit',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.deepOcean,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.softLine),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                children: [
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) {
                      if (_phoneError) setState(() => _phoneError = false);
                    },
                    decoration: InputDecoration(
                      labelText: context.t('whatsapp.contacts.people.phone'),
                      errorText: _phoneError
                          ? context.t('whatsapp.contacts.people.phoneInvalid')
                          : null,
                    ),
                  ),
                  TextField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: context.t(
                        'whatsapp.contacts.people.firstName',
                      ),
                    ),
                  ),
                  TextField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: context.t('whatsapp.contacts.people.lastName'),
                    ),
                  ),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (_emailError) setState(() => _emailError = false);
                    },
                    decoration: InputDecoration(
                      labelText: context.t('whatsapp.contacts.people.email'),
                      errorText: _emailError
                          ? context.t('whatsapp.contacts.people.emailInvalid')
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t('whatsapp.contacts.dialog.status'),
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      Switch(
                        value: _active,
                        onChanged: (value) => setState(() => _active = value),
                        activeThumbColor: const Color(0xFF198754),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.softLine)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.t('common.cancel')),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _save,
                  child: Text(context.t('common.save')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
