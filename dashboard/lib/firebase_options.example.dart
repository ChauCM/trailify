import 'package:firebase_core/firebase_core.dart';

/// FOR SELF-DEPLOY ONLY.
///
/// Copy this file to `firebase_options.dart` and fill in your Firebase config.
/// Get these values from: Firebase Console > Project Settings > General > Your apps > Web app.
///
/// If using the hosted dashboard at trailify.run, you don't need this file --
/// the config is entered at runtime in the browser.
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT.appspot.com',
  );
}
