import 'package:firebase_core/firebase_core.dart';

/// Firebase options supplied at build time through `--dart-define`s, so no
/// `GoogleService-Info.plist` / `google-services.json` has to live in the repo
/// or be wired into the native projects. CI derives the values from the
/// console config files stored as base64 secrets
/// (`.github/actions/firebase-defines`). A plain `flutter run` passes none
/// and gets null, which keeps Firebase inert exactly as before.
FirebaseOptions? firebaseOptionsFromEnvironment() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  if (apiKey.isEmpty ||
      appId.isEmpty ||
      senderId.isEmpty ||
      projectId.isEmpty) {
    return null;
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
  );
}
