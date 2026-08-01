import 'package:flutter/material.dart';
import 'core/services/lock_service.dart';
import 'core/services/inactivity_service.dart';
import 'core/services/remote_logger.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/pin_pad.dart';
import 'core/widgets/app_logo.dart';

/// Enveloppe l'app entière : si l'utilisateur a activé le verrouillage
/// (Profil > Verrouillage), l'app se verrouille au cold start, au retour
/// d'arrière-plan, et après inactivité. Le code PIN est le mécanisme fiable
/// de base ; la biométrie est tentée en premier UNIQUEMENT si activée en
/// plus, et retombe toujours sur le PIN en cas d'échec — jamais bloquant.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _lockService = LockService();
  final _pinPadKey = GlobalKey<PinPadState>();
  bool _locked = false;
  bool _checked = false;
  bool _biometricTrying = false;
  bool _pinError = false;

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
      _tryBiometricFirst();
    }
  }

  Future<void> _checkLockAtStart() async {
    final enabled = await _lockService.isLockEnabled();
    setState(() {
      _locked = enabled;
      _checked = true;
    });
    if (enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _tryBiometricFirst();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && await _lockService.isLockEnabled() && !_locked) {
      setState(() => _locked = true);
      InactivityService.instance.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _tryBiometricFirst();
    } else if (state == AppLifecycleState.paused) {
      InactivityService.instance.stop();
    }
  }

  /// Tente la biométrie SEULEMENT si l'utilisateur l'a activée en plus du
  /// PIN. Toute erreur/annulation retombe silencieusement sur le clavier
  /// PIN déjà affiché — jamais d'écran bloqué sans solution.
  Future<void> _tryBiometricFirst() async {
    final biometricOn = await _lockService.isBiometricEnabled();
    if (!biometricOn) return;
    setState(() => _biometricTrying = true);
    try {
      final ok = await _lockService.authenticateBiometric();
      if (ok && mounted) {
        setState(() => _locked = false);
        InactivityService.instance.start();
      }
    } catch (e, stack) {
      RemoteLogger.log(context: 'biometric_unlock', error: e, stack: stack);
      // silencieux — le clavier PIN reste affiché en dessous, pas de blocage
    } finally {
      if (mounted) setState(() => _biometricTrying = false);
    }
  }

  Future<void> _onPinComplete(String pin) async {
    final ok = await _lockService.verifyPin(pin);
    if (ok && mounted) {
      setState(() { _locked = false; _pinError = false; });
      InactivityService.instance.start();
    } else if (mounted) {
      setState(() => _pinError = true);
      await Future.delayed(const Duration(milliseconds: 400));
      _pinPadKey.currentState?.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();

    if (!_locked) {
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
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 64, full: true),
                  const SizedBox(height: 28),
                  if (_biometricTrying) ...[
                    CircularProgressIndicator(color: AppColors.gold),
                    const SizedBox(height: 16),
                    const Text('Vérification biométrique…', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 20),
                  ],
                  PinPad(
                    key: _pinPadKey,
                    title: 'Entrez votre code',
                    subtitle: _pinError ? 'Code incorrect, réessayez.' : null,
                    showError: _pinError,
                    onComplete: _onPinComplete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
