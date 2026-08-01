import 'dart:async';
import 'package:flutter/material.dart';

/// Carrousel discret et compact (hauteur fixe modeste), défile tout seul,
/// utilisé pour les bannières promo sur l'accueil client.
class AutoBannerCarousel extends StatefulWidget {
  final List<String> imagePaths;
  final double height;
  const AutoBannerCarousel({super.key, required this.imagePaths, this.height = 110});

  @override
  State<AutoBannerCarousel> createState() => _AutoBannerCarouselState();
}

class _AutoBannerCarouselState extends State<AutoBannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.imagePaths.isEmpty) return;
      _page = (_page + 1) % widget.imagePaths.length;
      _controller.animateToPage(_page, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.imagePaths.length,
          onPageChanged: (i) => _page = i,
          itemBuilder: (context, i) => Image.asset(widget.imagePaths[i], fit: BoxFit.cover, width: double.infinity),
        ),
      ),
    );
  }
}
