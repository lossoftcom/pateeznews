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
import '../data/admin_mail_repository.dart';
import 'contact_list_models.dart';
import 'mail_mobile_chrome.dart';

class ContactListContactsDialog extends StatefulWidget {
  const ContactListContactsDialog({
    super.key,
    required this.session,
    required this.repository,
    required this.list,
  });

  final AdminSession session;
  final AdminMailRepository repository;
  final AdminContactList list;

  @override
  State<ContactListContactsDialog> createState() =>
      _ContactListContactsDialogState();
}

class _ContactListContactsDialogState extends State<ContactListContactsDialog> {
  final _searchController = TextEditingController();
  var _contacts = <AdminMailContact>[];
  var _loading = true;
  var _query = '';

  List<AdminMailContact> get _filteredContacts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts
        .where((contact) {
          return [
            contact.email,
            contact.firstName,
            contact.lastName,
            contact.phone,
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

  Future<void> _showForm([AdminMailContact? contact]) async {
    final result = await showMailSideDrawer<_ContactFormResult>(
      context: context,
      minWidth: 380,
      maxWidth: 520,
      child: _ContactFormDialog(contact: contact),
    );
    if (result == null || !mounted) return;
    try {
      final saved = await widget.repository.saveContact(
        widget.session,
        listId: widget.list.id,
        id: contact?.id,
        email: result.email,
        firstName: result.firstName,
        lastName: result.lastName,
        phone: result.phone,
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

  Future<void> _delete(AdminMailContact contact) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.contacts.people.deleteTitle'),
      message: context.t('mail.contacts.people.deleteMessage'),
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
                          'mail.contacts.people.count',
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
                final searchField = TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: context.t('mail.contacts.people.search'),
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
                  label: Text(context.t('mail.contacts.people.new')),
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
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      addButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: searchField),
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
                        context.t('mail.contacts.people.empty'),
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
                              Symbols.person_outline,
                              color: AppColors.deepOcean,
                              size: 19,
                            ),
                          ),
                          title: Text(
                            contact.fullName.isEmpty
                                ? contact.email
                                : contact.fullName,
                            style: const TextStyle(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (contact.fullName.isNotEmpty) contact.email,
                              if (contact.phone.isNotEmpty) contact.phone,
                            ].join('  |  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: context.t('mail.contacts.action.edit'),
                                onPressed: () => _showForm(contact),
                                icon: const SymbolIcon(
                                  Symbols.edit_square,
                                  size: 18,
                                ),
                              ),
                              IconButton(
                                tooltip: context.t(
                                  'mail.contacts.action.delete',
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

class _ContactFormResult {
  const _ContactFormResult({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.active,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final bool active;
}

class _ContactFormDialog extends StatefulWidget {
  const _ContactFormDialog({this.contact});

  final AdminMailContact? contact;

  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late bool _active;
  var _emailError = false;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _emailController = TextEditingController(text: contact?.email ?? '');
    _firstNameController = TextEditingController(
      text: contact?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: contact?.lastName ?? '');
    _phoneController = TextEditingController(text: contact?.phone ?? '');
    _active = contact?.active ?? true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    final email = _emailController.text.trim();
    final valid = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
      caseSensitive: false,
    ).hasMatch(email);
    if (!valid) {
      setState(() => _emailError = true);
      return;
    }
    Navigator.of(context).pop(
      _ContactFormResult(
        email: email,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = context.t(
      widget.contact == null
          ? 'mail.contacts.people.formNew'
          : 'mail.contacts.people.formEdit',
    );
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
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
                  tooltip: context.t('common.close'),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (_emailError) setState(() => _emailError = false);
                    },
                    decoration: InputDecoration(
                      labelText: context.t('mail.contacts.people.email'),
                      errorText: _emailError
                          ? context.t('mail.contacts.people.emailInvalid')
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: context.t('mail.contacts.people.firstName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: context.t('mail.contacts.people.lastName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: context.t('mail.contacts.people.phone'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t('mail.contacts.dialog.status'),
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      Switch(
                        value: _active,
                        activeThumbColor: AppColors.actionRed,
                        onChanged: (value) => setState(() => _active = value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.softLine)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.actionRed,
                  ),
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
