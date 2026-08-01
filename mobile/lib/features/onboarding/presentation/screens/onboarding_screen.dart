import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_logo.dart';

class _Slide {
  final String title;
  final String subtitle;
  final IconData icon;
  _Slide(this.title, this.subtitle, this.icon);
}

final _slides = [
  _Slide('Livraison en un tap', 'Colis, courses et repas livrés partout à Cotonou et au-delà.', Icons.local_shipping_rounded),
  _Slide('Suivez en temps réel', 'Un marker animé qui bouge vraiment avec votre livreur, sur la carte.', Icons.map_rounded),
  _Slide('Payez comme vous voulez', 'Mobile Money, carte, ou votre portefeuille Livra.', Icons.account_balance_wallet_rounded),
  _Slide('Devenez partenaire', "Livreur, chauffeur ou vendeur ? Postulez à tout moment depuis l'onglet Profil.", Icons.handshake_rounded),
];

class OnboardingScreen extends StatefulWidget {
  OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppLogo(size: 44, full: true),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text('Passer', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                          child: Icon(s.icon, size: 56, color: AppColors.gold),
                        ),
                        SizedBox(height: 32),
                        Text(s.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        SizedBox(height: 12),
                        Text(s.subtitle, style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            SmoothPageIndicator(
              controller: _controller,
              count: _slides.length,
              effect: ExpandingDotsEffect(activeDotColor: AppColors.gold, dotColor: AppColors.divider, dotHeight: 6),
            ),
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: PrimaryButton(
                label: _index == _slides.length - 1 ? 'Commencer' : 'Suivant',
                onPressed: () {
                  if (_index == _slides.length - 1) {
                    context.go('/login');
                  } else {
                    _controller.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
