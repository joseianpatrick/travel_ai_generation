import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';

/// Shown in place of trip content when [TripsStore.loadError] is set —
/// offers a retry instead of leaving the screen blank.
class TripLoadError extends StatelessWidget {
  const TripLoadError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 32, color: colors.sub),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.sub),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
