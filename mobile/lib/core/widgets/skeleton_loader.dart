import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

/// Jamais de spinner plein écran — toujours un skeleton qui épouse la forme
/// du contenu final (cartes, lignes de texte…).
class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const SkeletonBox({super.key, required this.height, this.width, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonCardList extends StatelessWidget {
  final int count;
  const SkeletonCardList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (_, __) => SkeletonBox(height: 88, borderRadius: 18),
    );
  }
}
