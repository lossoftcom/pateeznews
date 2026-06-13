import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/admin_cached_image.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_account_settings_repository.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.onAccountDeleted,
  });

  final AdminSession session;
  final AdminAccountSettingsRepository repository;
  final VoidCallback onAccountDeleted;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _form = _AccountSettingsForm();
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  var _selectedTab = _AccountSettingsTab.profile;
  var _loading = true;
  var _saving = false;
  var _updatingPassword = false;
  var _deletingAccount = false;
  var _deleteConfirmed = false;
  AccountProfileImageKind? _uploadingKind;
  String? _error;
  AdminAccountProfile? _profile;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _form.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.repository.fetchProfile(widget.session);
      if (!mounted) return;
      _form.apply(profile);
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _profile = AdminAccountProfile.empty(widget.session);
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final profile = _buildProfileFromForm();
    if (profile.fullName.trim().isEmpty || profile.username.trim().isEmpty) {
      setState(() => _selectedTab = _AccountSettingsTab.profile);
      _showMessage(context.t('This field is required'));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? true)) return;

    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveProfile(
        session: widget.session,
        profile: profile,
      );
      if (!mounted) return;
      _form.apply(saved);
      setState(() {
        _profile = saved;
        _saving = false;
      });
      _showMessage(context.t('Profile saved successfully'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = error.toString().contains('Username is already taken')
          ? context.t('Username is already taken')
          : error.toString();
      _showMessage(message);
    }
  }

  Future<void> _uploadImage(AccountProfileImageKind kind) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'webp']),
      ],
    );
    if (file == null) return;

    setState(() => _uploadingKind = kind);
    try {
      final src = await widget.repository.uploadProfileImage(
        session: widget.session,
        kind: kind,
        fileName: file.name,
        bytes: await file.readAsBytes(),
      );
      if (!mounted) return;
      if (kind == AccountProfileImageKind.avatar) {
        _form.avatarUrl = src;
      } else {
        _form.coverUrl = src;
      }
      setState(() {
        _profile = _buildProfileFromForm();
        _uploadingKind = null;
      });
      _showMessage(context.t('Profile image uploaded'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadingKind = null);
      _showMessage(error.toString());
    }
  }

  Future<void> _updatePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showMessage(context.t('Passwords do not match'));
      return;
    }

    setState(() => _updatingPassword = true);
    try {
      await widget.repository.updatePassword(
        session: widget.session,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _updatingPassword = false);
      _showMessage(context.t('Password updated successfully'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingPassword = false);
      _showMessage(error.toString());
    }
  }

  Future<void> _deleteAccount() async {
    if (!_deleteConfirmed) {
      _showMessage(context.t('Please check the confirmation box'));
      return;
    }
    if (_deletePasswordController.text.trim().isEmpty) {
      _showMessage(context.t('Enter your password to confirm'));
      return;
    }

    setState(() => _deletingAccount = true);
    try {
      await widget.repository.deleteAccount(
        session: widget.session,
        currentPassword: _deletePasswordController.text,
      );
      if (!mounted) return;
      widget.onAccountDeleted();
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      _showMessage(error.toString());
    }
  }

  AdminAccountProfile _buildProfileFromForm() {
    final base = _profile ?? AdminAccountProfile.empty(widget.session);
    return base.copyWith(
      fullName: _form.fullName.text,
      username: _form.username.text,
      email: _form.email.text,
      phone: _form.phone.text,
      expertise: _form.expertise.text,
      foundationDate: _form.foundationDate.text,
      address: _form.address.text,
      website: _form.website.text,
      aboutMe: _form.aboutMe.text,
      slug: _form.slug.text,
      metaTitle: _form.metaTitle.text,
      metaKeywords: _form.metaKeywords.text,
      metaDescription: _form.metaDescription.text,
      canonicalUrl: _form.canonicalUrl.text,
      avatarUrl: _form.avatarUrl,
      coverUrl: _form.coverUrl,
      socialLinks: _form.socialLinks,
      rewardSystem: _form.rewardSystem,
      showEmail: _form.showEmail,
      rssFeeds: _form.rssFeeds,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 820
        ? 18.0
        : 28.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        28,
        horizontalPadding,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Account Settings'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const _AccountLoading()
          else if (_error != null)
            _AccountError(message: _error!, onRetry: _loadProfile)
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AccountTabs(
                    selected: _selectedTab,
                    onChanged: (tab) => setState(() => _selectedTab = tab),
                  ),
                  const SizedBox(height: 22),
                  _AccountCard(
                    title: _selectedTab.title(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileHero(
                          profile: _buildProfileFromForm(),
                          repository: widget.repository,
                          uploadingKind: _uploadingKind,
                          onUpload: _uploadImage,
                        ),
                        const SizedBox(height: 24),
                        _buildSelectedTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    return switch (_selectedTab) {
      _AccountSettingsTab.profile => _ProfileInfoTab(
        form: _form,
        saving: _saving,
        onSave: _saveProfile,
      ),
      _AccountSettingsTab.social => _SocialAccountsTab(
        form: _form,
        saving: _saving,
        onSave: _saveProfile,
      ),
      _AccountSettingsTab.preferences => _PreferencesTab(
        form: _form,
        saving: _saving,
        onChanged: () => setState(() {}),
        onSave: _saveProfile,
      ),
      _AccountSettingsTab.password => _PasswordTab(
        formKey: _passwordFormKey,
        currentPasswordController: _currentPasswordController,
        newPasswordController: _newPasswordController,
        confirmPasswordController: _confirmPasswordController,
        saving: _updatingPassword,
        onSubmit: _updatePassword,
      ),
      _AccountSettingsTab.delete => _DeleteAccountTab(
        passwordController: _deletePasswordController,
        confirmed: _deleteConfirmed,
        deleting: _deletingAccount,
        onConfirmChanged: (value) {
          setState(() => _deleteConfirmed = value);
        },
        onDelete: _deleteAccount,
      ),
    };
  }
}

enum _AccountSettingsTab { profile, social, preferences, password, delete }

extension on _AccountSettingsTab {
  String title(BuildContext context) {
    return switch (this) {
      _AccountSettingsTab.profile => context.t('Profile Information'),
      _AccountSettingsTab.social => context.t('Social Accounts'),
      _AccountSettingsTab.preferences => context.t('Preferences'),
      _AccountSettingsTab.password => context.t('Change Password'),
      _AccountSettingsTab.delete => context.t('Delete Account'),
    };
  }
}

class _AccountSettingsForm {
  final fullName = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final expertise = TextEditingController();
  final foundationDate = TextEditingController();
  final address = TextEditingController();
  final website = TextEditingController();
  final aboutMe = TextEditingController();
  final slug = TextEditingController();
  final metaTitle = TextEditingController();
  final metaKeywords = TextEditingController();
  final metaDescription = TextEditingController();
  final canonicalUrl = TextEditingController();
  final socialControllers = <String, TextEditingController>{
    for (final field in _socialFields) field.key: TextEditingController(),
  };
  var _baseSocialLinks = <String, String>{};

  var avatarUrl = '';
  var coverUrl = '';
  var rewardSystem = false;
  var showEmail = true;
  var rssFeeds = true;

  Map<String, String> get socialLinks {
    return {
      ..._baseSocialLinks,
      for (final entry in socialControllers.entries)
        entry.key: entry.value.text.trim(),
    };
  }

  void apply(AdminAccountProfile profile) {
    fullName.text = profile.fullName;
    username.text = profile.username;
    email.text = profile.email;
    phone.text = profile.phone;
    expertise.text = profile.expertise;
    foundationDate.text = profile.foundationDate;
    address.text = profile.address;
    website.text = profile.website;
    aboutMe.text = profile.aboutMe;
    slug.text = profile.slug;
    metaTitle.text = profile.metaTitle;
    metaKeywords.text = profile.metaKeywords;
    metaDescription.text = profile.metaDescription;
    canonicalUrl.text = profile.canonicalUrl;
    _baseSocialLinks = Map<String, String>.from(profile.socialLinks);
    for (final entry in socialControllers.entries) {
      entry.value.text = profile.socialLinks[entry.key] ?? '';
    }
    avatarUrl = profile.avatarUrl;
    coverUrl = profile.coverUrl;
    rewardSystem = profile.rewardSystem;
    showEmail = profile.showEmail;
    rssFeeds = profile.rssFeeds;
  }

  void dispose() {
    fullName.dispose();
    username.dispose();
    email.dispose();
    phone.dispose();
    expertise.dispose();
    foundationDate.dispose();
    address.dispose();
    website.dispose();
    aboutMe.dispose();
    slug.dispose();
    metaTitle.dispose();
    metaKeywords.dispose();
    metaDescription.dispose();
    canonicalUrl.dispose();
    for (final controller in socialControllers.values) {
      controller.dispose();
    }
  }
}

class _ProfileInfoTab extends StatelessWidget {
  const _ProfileInfoTab({
    required this.form,
    required this.saving,
    required this.onSave,
  });

  final _AccountSettingsForm form;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResponsiveFieldGrid(
          children: [
            _TextInputField(
              label: context.t('Full Name'),
              controller: form.fullName,
              requiredField: true,
            ),
            _TextInputField(
              label: context.t('Username'),
              controller: form.username,
              requiredField: true,
            ),
            _TextInputField(
              label: context.t('Email'),
              controller: form.email,
              keyboardType: TextInputType.emailAddress,
            ),
            _TextInputField(label: context.t('Phone'), controller: form.phone),
            _TextInputField(
              label: context.t('Expertise / Category'),
              controller: form.expertise,
            ),
            _TextInputField(
              label: context.t('Foundation / Birth Date'),
              controller: form.foundationDate,
            ),
            _TextInputField(
              label: context.t('Website'),
              controller: form.website,
            ),
            _TextInputField(
              label: context.t('Profile Link (Slug)'),
              controller: form.slug,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TextAreaField(label: context.t('Address'), controller: form.address),
        const SizedBox(height: 18),
        _TextAreaField(
          label: context.t('About Me / Biography'),
          controller: form.aboutMe,
          minLines: 4,
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldGrid(
          children: [
            _TextInputField(
              label: context.t('SEO Title'),
              controller: form.metaTitle,
            ),
            _TextInputField(
              label: context.t('Canonical URL'),
              controller: form.canonicalUrl,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TextAreaField(
          label: context.t('Meta Keywords'),
          controller: form.metaKeywords,
        ),
        const SizedBox(height: 18),
        _TextAreaField(
          label: context.t('Meta Description'),
          controller: form.metaDescription,
          minLines: 3,
        ),
        _SaveRow(saving: saving, onSave: onSave),
      ],
    );
  }
}

class _SocialAccountsTab extends StatelessWidget {
  const _SocialAccountsTab({
    required this.form,
    required this.saving,
    required this.onSave,
  });

  final _AccountSettingsForm form;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResponsiveFieldGrid(
          children: [
            for (final field in _socialFields)
              _TextInputField(
                label: field.label,
                controller: form.socialControllers[field.key]!,
                hintText: context.t('Social URL or username'),
              ),
          ],
        ),
        _SaveRow(saving: saving, onSave: onSave),
      ],
    );
  }
}

class _PreferencesTab extends StatelessWidget {
  const _PreferencesTab({
    required this.form,
    required this.saving,
    required this.onChanged,
    required this.onSave,
  });

  final _AccountSettingsForm form;
  final bool saving;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BooleanChoice(
          label: context.t('Show Email on Profile Page'),
          value: form.showEmail,
          onChanged: (value) {
            form.showEmail = value;
            onChanged();
          },
        ),
        const SizedBox(height: 14),
        _BooleanChoice(
          label: context.t('RSS Feeds'),
          value: form.rssFeeds,
          onChanged: (value) {
            form.rssFeeds = value;
            onChanged();
          },
        ),
        const SizedBox(height: 14),
        _BooleanChoice(
          label: context.t('Reward System'),
          value: form.rewardSystem,
          onChanged: (value) {
            form.rewardSystem = value;
            onChanged();
          },
        ),
        _SaveRow(saving: saving, onSave: onSave),
      ],
    );
  }
}

class _PasswordTab extends StatelessWidget {
  const _PasswordTab({
    required this.formKey,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.saving,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResponsiveFieldGrid(
            children: [
              _PasswordInput(
                label: context.t('Current Password'),
                controller: currentPasswordController,
              ),
              _PasswordInput(
                label: context.t('New Password'),
                controller: newPasswordController,
              ),
              _PasswordInput(
                label: context.t('Confirm New Password'),
                controller: confirmPasswordController,
              ),
            ],
          ),
          _SaveRow(
            saving: saving,
            onSave: onSubmit,
            label: context.t('Update Password'),
            savingLabel: context.t('Saving...'),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountTab extends StatelessWidget {
  const _DeleteAccountTab({
    required this.passwordController,
    required this.confirmed,
    required this.deleting,
    required this.onConfirmChanged,
    required this.onDelete,
  });

  final TextEditingController passwordController;
  final bool confirmed;
  final bool deleting;
  final ValueChanged<bool> onConfirmChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DangerPanel(
          title: context.t('Are you sure you want to delete your account?'),
          description: context.t('This action cannot be undone.'),
        ),
        const SizedBox(height: 18),
        _PasswordInput(
          label: context.t('Current Password'),
          controller: passwordController,
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: confirmed,
          onChanged: (value) => onConfirmChanged(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.actionRed,
          title: Text(
            context.t('I understand, confirm deletion'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(190, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
            ),
            onPressed: deleting ? null : onDelete,
            icon: deleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const SymbolIcon(Symbols.delete, size: 18),
            label: Text(
              deleting
                  ? context.t('Deleting...')
                  : context.t('Delete My Account Permanently'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.repository,
    required this.uploadingKind,
    required this.onUpload,
  });

  final AdminAccountProfile profile;
  final AdminAccountSettingsRepository repository;
  final AccountProfileImageKind? uploadingKind;
  final ValueChanged<AccountProfileImageKind> onUpload;

  @override
  Widget build(BuildContext context) {
    final coverUrl = repository.publicUrl(profile.coverUrl);
    final avatarUrl = repository.publicUrl(profile.avatarUrl);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.value),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 190,
                  child: coverUrl.isEmpty
                      ? const ColoredBox(color: AppColors.surface)
                      : AdminCachedImage(
                          url: coverUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 1080,
                          errorWidget:
                              const ColoredBox(color: AppColors.surface),
                        ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: _ImageActionButton(
                    label: context.t('Upload cover image'),
                    loading: uploadingKind == AccountProfileImageKind.cover,
                    onPressed: () => onUpload(AccountProfileImageKind.cover),
                  ),
                ),
              ),
              Positioned(
                left: 28,
                bottom: -44,
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deepOcean.withValues(alpha: 0.14),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: avatarUrl.isEmpty
                            ? _ProfileInitials(profile: profile)
                            : AdminCachedImage(
                                url: avatarUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 200,
                                errorWidget:
                                    _ProfileInitials(profile: profile),
                              ),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: _ImageActionButton(
                          compact: true,
                          label: context.t('Upload avatar image'),
                          loading:
                              uploadingKind == AccountProfileImageKind.avatar,
                          onPressed: () =>
                              onUpload(AccountProfileImageKind.avatar),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(150, 22, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.trim().isEmpty
                      ? context.t('Profile Information')
                      : profile.fullName.trim(),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.username.trim().isEmpty
                      ? '@${profile.email}'
                      : '@${profile.username.trim()}',
                  style: const TextStyle(
                    color: AppColors.actionRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _ProfileInitials extends StatelessWidget {
  const _ProfileInitials({required this.profile});

  final AdminAccountProfile profile;

  @override
  Widget build(BuildContext context) {
    final source = [
      profile.fullName,
      profile.username,
      profile.email,
    ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => 'P');
    final words = source
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    final initials = words.length > 1
        ? '${words.first[0]}${words.last[0]}'
        : source.trim()[0];
    return ColoredBox(
      color: AppColors.deepOcean,
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white.withValues(alpha: compact ? 0.64 : 0.52),
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: SizedBox(
            width: compact ? 34 : 54,
            height: compact ? 34 : 54,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.deepOcean,
                      ),
                    )
                  : SymbolIcon(
                      Symbols.photo_camera,
                      size: compact ? 18 : 22,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTabs extends StatelessWidget {
  const _AccountTabs({required this.selected, required this.onChanged});

  final _AccountSettingsTab selected;
  final ValueChanged<_AccountSettingsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in _AccountSettingsTab.values)
          _AccountTabButton(
            label: tab.title(context),
            selected: selected == tab,
            onPressed: () => onChanged(tab),
          ),
      ],
    );
  }
}

class _AccountTabButton extends StatelessWidget {
  const _AccountTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: selected ? AppColors.actionRed : Colors.white,
          foregroundColor: selected ? Colors.white : AppColors.deepOcean,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            side: BorderSide(
              color: selected ? AppColors.actionRed : AppColors.line,
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_SectionTitle(title), const SizedBox(height: 24), child],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.actionRed,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFieldGrid extends StatelessWidget {
  const _ResponsiveFieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 760;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - 24) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 24,
          runSpacing: 18,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _TextInputField extends StatelessWidget {
  const _TextInputField({
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.requiredField = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(requiredField ? '$label *' : label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: requiredField
              ? (value) => (value ?? '').trim().isEmpty
                    ? context.t('This field is required')
                    : null
              : null,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          decoration: _inputDecoration(hintText: hintText),
        ),
      ],
    );
  }
}

class _TextAreaField extends StatelessWidget {
  const _TextAreaField({
    required this.label,
    required this.controller,
    this.minLines = 3,
  });

  final String label;
  final TextEditingController controller;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: minLines + 2,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }
}

class _PasswordInput extends StatefulWidget {
  const _PasswordInput({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  State<_PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<_PasswordInput> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(widget.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          validator: (value) => (value ?? '').trim().isEmpty
              ? context.t('This field is required')
              : null,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          decoration: _inputDecoration().copyWith(
            suffixIcon: IconButton(
              tooltip: _obscure
                  ? context.t('Show password')
                  : context.t('Hide password'),
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: SymbolIcon(
                _obscure ? Symbols.visibility : Symbols.visibility_off,
                size: 18,
                color: AppColors.iconMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BooleanChoice extends StatelessWidget {
  const _BooleanChoice({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF198754),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DangerPanel extends StatelessWidget {
  const _DangerPanel({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SymbolIcon(
            Symbols.warning,
            color: AppColors.actionRed,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.iconMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

InputDecoration _inputDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.actionRed, width: 1.2),
    ),
  );
}

class _SaveRow extends StatelessWidget {
  const _SaveRow({
    required this.saving,
    required this.onSave,
    this.label,
    this.savingLabel,
  });

  final bool saving;
  final VoidCallback onSave;
  final String? label;
  final String? savingLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.actionRed,
            foregroundColor: Colors.white,
            minimumSize: const Size(178, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
          ),
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const SymbolIcon(Symbols.save, size: 18),
          label: Text(
            saving
                ? (savingLabel ?? context.t('Saving...'))
                : (label ?? context.t('Save Changes')),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountLoading extends StatelessWidget {
  const _AccountLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.deepOcean,
          ),
        ),
      ),
    );
  }
}

class _AccountError extends StatelessWidget {
  const _AccountError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(context.t('Retry'))),
        ],
      ),
    );
  }
}

class _SocialField {
  const _SocialField(this.key, this.label);

  final String key;
  final String label;
}

const _socialFields = [
  _SocialField('facebook', 'Facebook'),
  _SocialField('twitter', 'Twitter'),
  _SocialField('instagram', 'Instagram'),
  _SocialField('tiktok', 'Tiktok'),
  _SocialField('whatsapp', 'WhatsApp'),
  _SocialField('youtube', 'YouTube'),
  _SocialField('discord', 'Discord'),
  _SocialField('telegram', 'Telegram'),
  _SocialField('pinterest', 'Pinterest'),
  _SocialField('linkedin', 'Linkedin'),
  _SocialField('twitch', 'Twitch'),
  _SocialField('vk', 'VK'),
  _SocialField('nsosyal', 'NSosyal'),
  _SocialField('personal_website_url', 'Personal Website URL'),
];
