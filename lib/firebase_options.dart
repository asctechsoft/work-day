// Cấu hình Firebase cho dự án "tick-go".
// Sinh thủ công từ google-services.json (package: com.campany.tickgo).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('WorkDay chưa cấu hình cho nền tảng Web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'WorkDay chưa cấu hình cho nền tảng $defaultTargetPlatform. '
          'Hãy chạy "flutterfire configure" để bổ sung.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBkwiPQMIxAh0nPH_ZphT2QiYZS5NNkyBA',
    appId: '1:923485174653:android:7d7a33581f3db7ae45ea14',
    messagingSenderId: '923485174653',
    projectId: 'tick-go',
    storageBucket: 'tick-go.firebasestorage.app',
  );
}
