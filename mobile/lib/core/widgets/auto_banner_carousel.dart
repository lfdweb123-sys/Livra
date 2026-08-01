import 'dart:async';
import 'package:flutter/material.dart';

/// Carrousel discret et compact (hauteur fixe modeste), défile tout seul.
/// Affiche des URLs réseau (gérées depuis le dashboard admin) si fournies,
/// sinon des assets locaux en repli.
class AutoBannerCarousel extends StatefulWidget {
  final List<String> imagePaths;
  final bool isNetwork;
  final double height;
  const AutoBannerCarousel({super.key, required this.imagePaths, this.isNetwork = false, this.height = 110});

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
          itemBuilder: (context, i) => widget.isNetwork
              ? Image.network(widget.imagePaths[i], fit: BoxFit.contain, width: double.infinity)
              : Image.asset(widget.imagePaths[i], fit: BoxFit.contain, width: double.infinity),
        ),
      ),
    );
  }
}
