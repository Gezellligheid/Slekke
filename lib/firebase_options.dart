// GENERATED FILE — run `flutterfire configure` to populate this.
// Install FlutterFire CLI: dart pub global activate flutterfire_cli
// Then: flutterfire configure --project=<your-firebase-project-id>

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Replace all values below with your Firebase project config.
  // Get them from: Firebase Console → Project Settings → Your apps

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDK1xi00zf3Hl0n9k_juF7rexAxFs83BXk',
    appId: '1:224585099790:web:183dcd4e013833831c6a5f',
    messagingSenderId: '224585099790',
    projectId: 'slekke-5f041',
    authDomain: 'slekke-5f041.firebaseapp.com',
    storageBucket: 'slekke-5f041.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVSYz0NkCXCgmt6aP-zklv3me9xauqbaU',
    appId: '1:224585099790:android:c1734c4695f8b7d41c6a5f',
    messagingSenderId: '224585099790',
    projectId: 'slekke-5f041',
    storageBucket: 'slekke-5f041.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCL0OEyAgP7l081FlrSIR3JquyR2twgRlc',
    appId: '1:224585099790:ios:a3b6813380d09ca61c6a5f',
    messagingSenderId: '224585099790',
    projectId: 'slekke-5f041',
    storageBucket: 'slekke-5f041.firebasestorage.app',
    iosBundleId: 'com.slekke.slekke',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCL0OEyAgP7l081FlrSIR3JquyR2twgRlc',
    appId: '1:224585099790:ios:a3b6813380d09ca61c6a5f',
    messagingSenderId: '224585099790',
    projectId: 'slekke-5f041',
    storageBucket: 'slekke-5f041.firebasestorage.app',
    iosBundleId: 'com.slekke.slekke',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDK1xi00zf3Hl0n9k_juF7rexAxFs83BXk',
    appId: '1:224585099790:web:aba6a7f8737dd0511c6a5f',
    messagingSenderId: '224585099790',
    projectId: 'slekke-5f041',
    authDomain: 'slekke-5f041.firebaseapp.com',
    storageBucket: 'slekke-5f041.firebasestorage.app',
  );

}