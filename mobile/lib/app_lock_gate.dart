import 'package:flutter/material.dart';
import 'core/services/lock_service.dart';
import 'core/services/inactivity_service.dart';
import 'core/services/remote_logger.dart';
import 'core/theme/app_colors.dart';

/// Enveloppe l'app entière : si l'utilisateur a activé la biométrie
/// (Profil > Verrouillage biométrique), l'app se verrouille :
/// - au cold start,
/// - au retour depuis l'arrière-plan,
/// - après [InactivityService.timeout] sans interaction alors qu'elle est
///   restée au premier plan (ex: oubliée ouverte sur la table).
/// La session Firebase Auth n'est jamais touchée par ce verrou, c'est un
/// verrou d'accès purement local.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _lockService = LockService();
  bool _locked = false;
  bool _checked = false;
  bool _unlocking = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    InactivityService.instance.shouldLock.addListener(_onInactivityTimeout);
    _checkLockAtStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    InactivityService.instance.shouldLock.removeListener(_onInactivityTimeout);
    InactivityService.instance.stop();
    super.dispose();
  }

  void _onInactivityTimeout() {
    if (InactivityService.instance.shouldLock.value && mounted && !_locked) {
      setState(() => _locked = true);
      InactivityService.instance.stop();
      _tryUnlock();
    }
  }

  Future<void> _checkLockAtStart() async {
    final enabled = await _lockService.isEnabled();
    setState(() {
      _locked = enabled;
      _checked = true;
    });
    if (enabled) {
      // On attend la 1ère frame + un court délai : appeler le prompt
      // biométrique natif avant que l'Activity Android soit pleinement
      // "resumed" le fait échouer silencieusement sur certains appareils.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _tryUnlock();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && await _lockService.isEnabled() && !_locked) {
      setState(() => _locked = true);
      InactivityService.instance.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _tryUnlock();
    } else if (state == AppLifecycleState.paused) {
      // en arrière-plan, le minuteur d'inactivité n'a plus de sens :
      // le retour de background reverrouille déjà systématiquement.
      InactivityService.instance.stop();
    }
  }

  Future<void> _tryUnlock() async {
    if (_unlocking) return;
    setState(() { _unlocking = true; _lastError = null; });
    try {
      final ok = await _lockService.authenticate();
      if (ok && mounted) {
        setState(() => _locked = false);
        InactivityService.instance.start();
      } else if (mounted) {
        setState(() => _lastError = 'Authentification annulée ou échouée.');
      }
    } catch (e, stack) {
      RemoteLogger.log(context: 'biometric_unlock', error: e, stack: stack);
      if (mounted) {
        setState(() => _lastError = RemoteLogger.readableAuthError(e));
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();

    if (!_locked) {
      // Listener global : n'importe quel tap dans l'app remet le minuteur
      // d'inactivité à zéro, sans intercepter ni retarder les gestes normaux.
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => InactivityService.instance.registerActivity(),
        child: widget.child,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.gold),
                const SizedBox(height: 16),
                const Text('Livra est verrouillé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                if (_lastError != null) ...[
                  const SizedBox(height: 10),
                  Text(_lastError!, style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    onPressed: _unlocking ? null : _tryUnlock,
                    child: _unlocking
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Déverrouiller'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
