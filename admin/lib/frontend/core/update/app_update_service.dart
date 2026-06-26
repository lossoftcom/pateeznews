import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/shell/data/app_shell_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppUpdateService {
  const AppUpdateService();

  Future<void> maybeShowUpdateDialog(
    BuildContext context,
    AppUpdateSettings settings,
  ) async {
    if (kIsWeb || !_isMobileTarget(defaultTargetPlatform)) return;
    if (!settings.enabled) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final latestVersion = settings.latestVersion.trim();
    if (!_isNewerVersion(latestVersion, packageInfo.version)) return;

    final storeUri = _storeUri(settings, packageInfo.packageName);
    if (storeUri == null) return;

    final preferences = await SharedPreferences.getInstance();
    final promptKey =
        'pateez_app_update_prompt_${defaultTargetPlatform.name}_$latestVersion';
    final lastPrompt = preferences.getInt(promptKey) ?? 0;
    final now = DateTime.now();
    if (lastPrompt > 0) {
      final elapsed = now.difference(
        DateTime.fromMillisecondsSinceEpoch(lastPrompt),
      );
      if (elapsed < Duration(hours: settings.remindAfterHours)) return;
    }

    if (!context.mounted) return;
    final action = await showDialog<_AppUpdateDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AppUpdateDialog(
        currentVersion: packageInfo.version,
        latestVersion: latestVersion,
      ),
    );

    if (action == _AppUpdateDialogAction.update) {
      await _openStore(storeUri, packageInfo.packageName);
      return;
    }

    await preferences.setInt(promptKey, now.millisecondsSinceEpoch);
  }

  Uri? _storeUri(AppUpdateSettings settings, String packageName) {
    final raw = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => settings.iosStoreUrl.trim(),
      TargetPlatform.android => settings.androidStoreUrl.trim(),
      _ => '',
    };
    if (raw.isNotEmpty) return Uri.tryParse(raw);
    if (defaultTargetPlatform == TargetPlatform.android &&
        packageName.trim().isNotEmpty) {
      return Uri.tryParse('market://details?id=${packageName.trim()}');
    }
    return null;
  }

  Future<void> _openStore(Uri uri, String packageName) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || defaultTargetPlatform != TargetPlatform.android) return;

    final fallback = Uri.https('play.google.com', '/store/apps/details', {
      'id': packageName,
    });
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  }
}

class _AppUpdateDialog extends StatelessWidget {
  const _AppUpdateDialog({
    required this.currentVersion,
    required this.latestVersion,
  });

  final String currentVersion;
  final String latestVersion;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.actionRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: AppColors.actionRed,
                  size: 26,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Yeni sürüm hazır',
                style: AppTypography.titleL.copyWith(
                  color: AppColors.inkStrong,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pateez $latestVersion mağazada. Kullandığınız sürüm $currentVersion. Güncellemek ister misiniz?',
                style: AppTypography.body.copyWith(
                  color: AppColors.inkSoft,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_AppUpdateDialogAction.later),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.deepOcean,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: AppTypography.titleS.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      child: const Text('Daha sonra'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_AppUpdateDialogAction.update),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.actionRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: AppTypography.titleS.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      child: const Text('Güncelle'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AppUpdateDialogAction { later, update }

bool _isMobileTarget(TargetPlatform platform) {
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

bool _isNewerVersion(String latest, String current) {
  final latestParts = _versionParts(latest);
  final currentParts = _versionParts(current);
  for (var i = 0; i < 3; i++) {
    final diff = latestParts[i].compareTo(currentParts[i]);
    if (diff > 0) return true;
    if (diff < 0) return false;
  }
  return false;
}

List<int> _versionParts(String value) {
  final clean = value.trim().split(RegExp(r'[+-]')).first;
  final parts = clean.split('.');
  return List<int>.generate(3, (index) {
    if (index >= parts.length) return 0;
    return int.tryParse(parts[index].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  });
}
