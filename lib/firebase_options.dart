import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// ⚠️ INSTRUÇÕES IMPORTANTES:
///
/// 1. Acesse: https://console.firebase.google.com/project/eva-push-01
/// 2. Clique no ícone Android para adicionar um app Android
/// 3. Use o package name do seu app (ex: com.example.eva)
/// 4. Baixe o google-services.json e coloque em: android/app/
/// 5. Copie o Android App ID e cole abaixo substituindo "COLE_AQUI_O_APP_ID_ANDROID"
///
/// O App ID Android tem este formato:
/// 1:1017997949026:android:abc123def456...
///
/// NÃO use o App ID Web que você mencionou (ele termina com :web:...)

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ✅ Configuração WEB (Atualizada para Eva Push)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:
        'AIzaSyBJiWQtzLwwfv6e2dOSxnAoEirKxrZuTLQ', // key do google-services.json
    appId: '1:1017997949026:web:placeholder', // ID Web, se houver
    messagingSenderId: '1017997949026',
    projectId: 'eva-push-01',
    authDomain: 'eva-push-01.firebaseapp.com',
    storageBucket: 'eva-push-01.firebasestorage.app',
    measurementId: 'G-XXXXXXXXXX',
  );

  // ✅ Configuração ANDROID (Atualizada para Eva Push)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:
        'AIzaSyBJiWQtzLwwfv6e2dOSxnAoEirKxrZuTLQ', // key do google-services.json
    appId:
        '1:1017997949026:android:2a1512c94c29934cda793b', // ID do google-services.json
    messagingSenderId:
        '1017997949026', // project_number do google-services.json
    projectId: 'eva-push-01',
    storageBucket: 'eva-push-01.firebasestorage.app',
  );

  // Configuração iOS (Placeholder atualizado para Eva Push)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBJiWQtzLwwfv6e2dOSxnAoEirKxrZuTLQ',
    appId: '1:1017997949026:ios:placeholder',
    messagingSenderId: '1017997949026',
    projectId: 'eva-push-01',
    storageBucket: 'eva-push-01.firebasestorage.app',
    iosBundleId: 'com.eva.br',
  );
}
