import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';

/// A "− value +" row for incrementing/decrementing a count (trip nights,
/// planner rider count, etc). Named to avoid colliding with Material's
/// own [Stepper] widget.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Row(
      children: [
        _StepButton(icon: Icons.remove, onTap: onDecrement),
        Expanded(
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
        ),
        _StepButton(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final enabled = onTap != null;
    return Material(
      color: colors.fill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: enabled ? colors.text : colors.ter),
        ),
      ),
    );
  }
}
