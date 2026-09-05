import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';

/// 36pt circular filled icon button used in every screen header.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.fill,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: colors.text),
          ),
        ),
      ),
    );
  }
}
