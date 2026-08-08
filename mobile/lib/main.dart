import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/routing/app_router.dart';
import 'core/widgets/connectivity_banner.dart';
import 'app_role_gate.dart';

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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
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
            // Français forcé partout — sans ça, les composants systèmes
            // (barre Copier/Couper/Coller, sélecteurs de date...)
            // restaient en anglais par défaut, quelle que soit la langue
            // du téléphone.
            locale: const Locale('fr'),
            supportedLocales: const [Locale('fr')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Bannière hors-connexion visible sur TOUTE l'app, quelle que
            // soit la page — voir ConnectivityBanner.
            builder: (context, child) => ConnectivityBanner(child: child ?? const SizedBox()),
          ),
        );
      },
    );
  }
}
