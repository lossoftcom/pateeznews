import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Firebase options are configured for Android, iOS and Web only.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBuYEFAQzo5E9bNHPeLdYWoY3sdz-HPEVc',
    appId: '1:868646509784:web:cacd099bbcfa60553a8bad',
    messagingSenderId: '868646509784',
    projectId: 'pateez-ac151',
    authDomain: 'pateez-ac151.firebaseapp.com',
    storageBucket: 'pateez-ac151.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAEzF7crxI-Ce04ePaVn3nMpFBu1nbin74',
    appId: '1:868646509784:android:237da8e7962182363a8bad',
    messagingSenderId: '868646509784',
    projectId: 'pateez-ac151',
    storageBucket: 'pateez-ac151.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCnNGGdYrrvxo6UZJF5mknINZKTvLkNqRk',
    appId: '1:868646509784:ios:bbc52f92f0fc7dde3a8bad',
    messagingSenderId: '868646509784',
    projectId: 'pateez-ac151',
    storageBucket: 'pateez-ac151.firebasestorage.app',
    iosBundleId: 'com.pateez.app',
  );
}
