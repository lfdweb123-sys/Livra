import 'package:flutter/material.dart';

/// Image tapable qui ouvre un aperçu plein écran zoomable (pincer pour
/// zoomer, comme demandé pour chaque photo produit/nourriture — et
/// réutilisée aussi pour les photos de profil restaurant/livreur/boutique).
class ZoomableImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ZoomableImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
        opacity: animation,
        child: _FullScreenZoomView(imageUrl: imageUrl, heroTag: imageUrl),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Hero(
        tag: imageUrl,
        child: ClipRRect(
          borderRadius: radius,
          child: Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stack) => Container(
              width: width,
              height: height,
              color: Colors.grey.shade300,
              child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenZoomView extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  const _FullScreenZoomView({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
