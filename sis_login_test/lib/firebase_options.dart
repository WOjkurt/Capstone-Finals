import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDDjMVje56MVJgYJvMrUhmgjJz2uDQSPyI',
    authDomain: 'dbtc-cebu.firebaseapp.com',
    projectId: 'dbtc-cebu',
    storageBucket: 'dbtc-cebu.firebasestorage.app',
    messagingSenderId: '842895749365',
    appId: '1:842895749365:web:a549bba87e41d1566b15bc',
    measurementId: 'G-S5GB4SRGFS',
  );

  static FirebaseOptions get currentPlatform => web;
}
