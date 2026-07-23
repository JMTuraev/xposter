import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'state/app_state.dart';
import 'screens/root_scaffold.dart';
import 'screens/auth/login_screen.dart';
import 'screens/subscription/sub_block_screen.dart';

/// Background/terminated holatda kelgan FCM xabari. Notification-turdagi
/// xabarni tizim o'zi tray'da ko'rsatadi — bu yerda qo'shimcha ish shart emas.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase init (loyiha: poster / poster-ae945).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(
    ChangeNotifierProvider(
      // Firebase sessiyasi saqlangan bo'lsa — avtomatik tiklaymiz.
      create: (_) => AppState()..restoreSession(),
      child: const XposterApp(),
    ),
  );
}

/// Global messenger — foreground push'ni istalgan ekranda banner qilib ko'rsatish.
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class XposterApp extends StatefulWidget {
  const XposterApp({super.key});
  @override
  State<XposterApp> createState() => _XposterAppState();
}

class _XposterAppState extends State<XposterApp> {
  @override
  void initState() {
    super.initState();
    // Ilova ochiq (foreground) payt kelgan push — yuqoridan banner.
    FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      final n = m.notification;
      if (n == null) return;
      appMessengerKey.currentState?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.posDark,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          const Text('🔔', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title ?? 'Xposter',
                  style: AppTheme.sans(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
              if ((n.body ?? '').isNotEmpty)
                Text(n.body!, style: AppTheme.sans(size: 12.5, color: Colors.white70)),
            ]),
          ),
        ]),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xposter',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      theme: AppTheme.theme(),
      home: const _AuthGate(),
    );
  }
}

/// Auth gate: sessiya tiklanmoqda — splash; kirilmagan — Login; aks holda ilova.
class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.bootstrapping) return const _Splash();
    // QATTIQ BLOK: obuna muddati o'tgan — faqat to'lov ekrani (ilova yopiq).
    if (app.subBlocked) return const SubBlockScreen();
    return app.isAuthed ? const RootScaffold() : const LoginScreen();
  }
}

/// Sessiya tiklanayotgandagi yuklanish ekrani (login formasi «lip-lip» etmasin).
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62, height: 62,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(18)),
              alignment: Alignment.center,
              child: Text('X', style: AppTheme.serif(size: 30, weight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 14),
            Text('Xposter', style: AppTheme.serif(size: 24, weight: FontWeight.w700)),
            const SizedBox(height: 22),
            const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent),
            ),
            const SizedBox(height: 10),
            Text('Загрузка данных…', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
