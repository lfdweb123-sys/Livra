import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
