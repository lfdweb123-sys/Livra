import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/services/onboarding_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/maps/maps_service.dart';
import '../../../../core/services/app_content_service.dart';

class _Slide {
  final String title;
  final String Function(String city) subtitleBuilder;
  final String image;
  _Slide(this.title, this.subtitleBuilder, this.image);
}

final _slides = [
  _Slide(
    'Livrer en un tap',
    (city) => 'Colis, courses et repas livrés partout à $city et au-delà.',
    'assets/images/onboarding/slide2.png',
  ),
  _Slide(
    'Suivez en temps réel',
    (_) =>
        'Un marker animé qui bouge vraiment avec votre livreur, sur la carte.',
    'assets/images/onboarding/slide1.png',
  ),
  _Slide(
    'Payez comme vous voulez',
    (_) => 'Mobile Money, carte, espèces ou votre portefeuille Livra.',
    'assets/images/onboarding/slide3.png',
  ),
  _Slide(
    'Devenez partenaire',
    (_) =>
        "Livreur, chauffeur ou vendeur ? Postulez à tout moment depuis l'onglet Profil.",
    'assets/images/onboarding/slide4.png',
  ),
  // Ajoutée à la fin (et non insérée au milieu) pour ne pas décaler les
  // index des diapositives précédentes, utilisés par AppContentService
  // pour les images personnalisées configurées côté admin.
  _Slide(
    'Vendez ce que vous voulez',
    (_) =>
        "Nourriture, vêtements, électronique, cosmétiques… vendez tout type de produit ou d'article sur Livra, sans restriction.",
    'assets/images/onboarding/slide3.png',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  final _onboardingService = OnboardingService();
  int _index = 0;
  String _city = 'votre ville';
  bool _checking = true;
  List<String?> _overrideImages = [];

  late final AnimationController _floatCtrl;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _floatAnim;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceFade;

  @override
  void initState() {
    super.initState();
    _checkAlreadySeen();
    _detectCity();
    _loadAppContent();

    _floatCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entranceScale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutBack));
    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceCtrl.forward();
  }

  Future<void> _loadAppContent() async {
    final config = await AppContentService().fetch();
    if (!mounted) return;
    if (!config.onboardingEnabled) {
      await _finish();
      return;
    }
    if (config.onboardingSlides.isNotEmpty)
      setState(() => _overrideImages = config.onboardingSlides);
  }

  String _imageFor(int i) {
    if (i < _overrideImages.length && _overrideImages[i] != null)
      return _overrideImages[i]!;
    return _slides[i].image;
  }

  Future<void> _checkAlreadySeen() async {
    final seen = await _onboardingService.hasSeenOnboarding();
    if (seen && mounted) {
      context.go('/login');
      return;
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _detectCity() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      final city =
          await MapsService().reverseGeocodeCity(pos.latitude, pos.longitude);
      if (city != null && mounted) setState(() => _city = city);
    } catch (_) {
      // permission refusée ou géoloc indisponible — on garde le texte générique
    }
  }

  Future<void> _finish() async {
    await _onboardingService.markSeen();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _entranceCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppLogo(size: 36, full: true),
                  TextButton(
                    onPressed: _finish,
                    child: Text('Passer',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _entranceCtrl
                    ..reset()
                    ..forward();
                },
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Column(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 10,
                                right: 10,
                                child: AnimatedBuilder(
                                  animation: _floatCtrl,
                                  builder: (context, child) =>
                                      Transform.translate(
                                    offset: Offset(0, _floatAnim.value),
                                    child: child,
                                  ),
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.goldSoft,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 20,
                                left: 0,
                                child: AnimatedBuilder(
                                  animation: _floatCtrl,
                                  builder: (context, child) =>
                                      Transform.translate(
                                    offset: Offset(0, -_floatAnim.value),
                                    child: child,
                                  ),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: AppColors.surfaceElevated,
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _entranceCtrl,
                                builder: (context, child) => Opacity(
                                  opacity: _entranceFade.value,
                                  child: Transform.scale(
                                    scale: _entranceScale.value,
                                    child: child,
                                  ),
                                ),
                                child: AnimatedBuilder(
                                  animation: _floatCtrl,
                                  builder: (context, child) =>
                                      Transform.translate(
                                    offset: Offset(0, _floatAnim.value * 0.4),
                                    child: child,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              AppColors.gold.withOpacity(0.18),
                                          blurRadius: 30,
                                          spreadRadius: 4,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: (i < _overrideImages.length &&
                                              _overrideImages[i] != null)
                                          ? Image.network(_imageFor(i),
                                              fit: BoxFit.contain,
                                              width: double.infinity)
                                          : Image.asset(_imageFor(i),
                                              fit: BoxFit.contain,
                                              width: double.infinity),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: AnimatedBuilder(
                            animation: _entranceCtrl,
                            builder: (context, child) => Opacity(
                              opacity: _entranceFade.value,
                              child: Transform.translate(
                                offset:
                                    Offset(0, (1 - _entranceFade.value) * 16),
                                child: child,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(s.title,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                Text(s.subtitleBuilder(_city),
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SmoothPageIndicator(
              controller: _controller,
              count: _slides.length,
              effect: ExpandingDotsEffect(
                  activeDotColor: AppColors.gold,
                  dotColor: AppColors.divider,
                  dotHeight: 6),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PrimaryButton(
                label: _index == _slides.length - 1 ? 'Commencer' : 'Suivant',
                onPressed: () {
                  if (_index == _slides.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  }
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
