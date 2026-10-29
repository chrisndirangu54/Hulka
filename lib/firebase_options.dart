// File generated for FlutterFire from Firebase CLI SDK configs.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
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
        return ios;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBlUmq-1YAAYYHEoYBZ6f5X4zmFStMEA-w',
    appId: '1:769087734424:web:0b52aae42f4be319e346ed',
    messagingSenderId: '769087734424',
    projectId: 'hulka-health-261029',
    authDomain: 'hulka-health-261029.firebaseapp.com',
    storageBucket: 'hulka-health-261029.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAbDW1KIdQiy6CQw1x1BwHMXaQIi2Xj48o',
    appId: '1:769087734424:android:33dcac8db3b5f330e346ed',
    messagingSenderId: '769087734424',
    projectId: 'hulka-health-261029',
    storageBucket: 'hulka-health-261029.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA90R1wGAkG5zsvLpWfK4e9pRp41Ft2-2g',
    appId: '1:769087734424:ios:d96cae9e08709b3de346ed',
    messagingSenderId: '769087734424',
    projectId: 'hulka-health-261029',
    storageBucket: 'hulka-health-261029.firebasestorage.app',
    iosBundleId: 'com.hulka.hulka',
  );
}
