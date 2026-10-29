import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Sokonis grocery project (`sokoni-s-grocery`). Public client config.
abstract final class SokonisFirebaseOptions {
  static const projectId = 'sokoni-s-grocery';
  static const mcpUrl =
      'https://us-central1-sokoni-s-grocery.cloudfunctions.net/mcpServer';
  static const restUrl =
      'https://us-central1-sokoni-s-grocery.cloudfunctions.net/sokonisApi';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyB2dnWnePtbejHQcvS8xKw4GKkPdr2Eaj0',
    appId: '1:492372104602:web:fa0b5a298ae3968c831623',
    messagingSenderId: '492372104602',
    projectId: projectId,
    authDomain: 'sokoni-s-grocery.firebaseapp.com',
    databaseURL: 'https://sokoni-s-grocery-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'sokoni-s-grocery.appspot.com',
    measurementId: 'G-P3VRML5K6G',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBGmhtaiwTfZga_WOceocEYKsYrRtS11l0',
    appId: '1:492372104602:android:992b8ed44f5c8ab6831623',
    messagingSenderId: '492372104602',
    projectId: projectId,
    databaseURL: 'https://sokoni-s-grocery-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'sokoni-s-grocery.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyBZRoToJm0W9ebYlZGkmY0TzhajP0tJr64',
    appId: '1:492372104602:ios:91ef8a27758766a6831623',
    messagingSenderId: '492372104602',
    projectId: projectId,
    databaseURL: 'https://sokoni-s-grocery-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'sokoni-s-grocery.appspot.com',
    iosBundleId: 'com.example.grocerry',
  );
}
