import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';

/// The app's full-width accent CTA: a solid electric-blue pill with an
/// uppercase, letter-spaced label, plus an optional loading spinner and
/// trailing icon. This is the one primary call-to-action style used across
/// splash, onboarding, auth, planner, map, and itinerary.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final enabled = !isLoading && onPressed != null;
    final fontSize = height >= 52 ? 15.0 : (height >= 46 ? 14.0 : 13.0);
    final radius = height >= 52 ? KalsadaRadius.lg : height / 2.6;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: colors.accent,
        borderRadius: BorderRadius.circular(radius),
        shadowColor: colors.accent,
        elevation: enabled ? 6 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: enabled ? onPressed : null,
          child: Container(
            width: double.infinity,
            height: height,
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: kalsadaHeadline(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 10),
                        Icon(icon, size: fontSize + 5, color: Colors.white),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
