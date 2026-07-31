import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/routing/app_router.dart';
import 'core/services/notifications/fcm_service.dart';
import 'app_role_gate.dart';
import 'app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await ThemeController.instance.load();
  runApp(LivraApp());
}

class LivraApp extends StatefulWidget {
  LivraApp({super.key});
  @override
  State<LivraApp> createState() => _LivraAppState();
}

class _LivraAppState extends State<LivraApp> {
  @override
  void initState() {
    super.initState();
    // best-effort — ne bloque jamais le démarrage de l'app si refusé
    FcmService().initAndSaveToken().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return AppLockGate(
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.mode,
        builder: (context, mode, _) {
          return RoleGate(
            child: MaterialApp.router(
              title: 'Livra',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.current,
              darkTheme: AppTheme.current,
              themeMode: mode,
              routerConfig: AppRouter.router,
            ),
          );
        },
      ),
    );
  }
}
