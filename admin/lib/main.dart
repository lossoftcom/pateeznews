import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pateeznews_frontend/app/pateeznews_app.dart';

import 'app/pateeznews_admin_app.dart';

void main() {
  runApp(_isMobileNative() ? const PateeznewsApp() : const PateeznewsAdminApp());
}

bool _isMobileNative() {
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isAndroid;
}
