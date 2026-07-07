import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static bool get isConfigured =>
      currentPlatform.apiKey != 'YOUR_API_KEY' &&
      currentPlatform.projectId != 'YOUR_PROJECT_ID';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      case TargetPlatform.fuchsia:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCgrhdiOq9N-AuJ_UUAp2DRxiM4lNxQGvc',
    appId: '1:265813124433:web:7427a2318c730c2c27df70',
    messagingSenderId: '265813124433',
    projectId: 'tap-drop-arena-omer',
    authDomain: 'tap-drop-arena-omer.firebaseapp.com',
    storageBucket: 'tap-drop-arena-omer.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCSHQBXOXxzI2uwjcw-NSwBZiFWrljyIYw',
    appId: '1:265813124433:android:b3fe586242974bea27df70',
    messagingSenderId: '265813124433',
    projectId: 'tap-drop-arena-omer',
    storageBucket: 'tap-drop-arena-omer.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDcRWzYgU405CJnz6uVwsSZjcx52ipgBdk',
    appId: '1:931838852481:ios:9fa6955e5b590f774fbc80',
    messagingSenderId: '931838852481',
    projectId: 'hoop-keys',
    storageBucket: 'hoop-keys.firebasestorage.app',
    iosBundleId: 'com.omergames.hoopkeys',
  );

  static const FirebaseOptions macos = ios;

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_WINDOWS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions linux = windows;
}
