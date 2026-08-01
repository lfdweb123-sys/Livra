import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.icon,
  });

  bool get _disabled => onPressed == null || loading;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: _disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _disabled ? AppColors.divider : AppColors.gold, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            foregroundColor: AppColors.gold,
          ),
          child: _content(color: AppColors.gold),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: _disabled
              ? null
              : LinearGradient(colors: [AppColors.goldSoft, AppColors.gold], begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: _disabled ? AppColors.divider : null,
          boxShadow: _disabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _disabled ? null : onPressed,
            child: Center(child: _content(color: _disabled ? AppColors.textSecondary : Colors.black)),
          ),
        ),
      ),
    );
  }

  Widget _content({required Color color}) {
    if (loading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15.5)),
        ],
      );
    }
    return Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15.5));
  }
}
