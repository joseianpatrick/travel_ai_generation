import 'package:base_project/theme/kalsada_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Photo banner used for trip imagery: shows [imageUrl] when available,
/// falling back to a striped teal placeholder (offline, no photo yet, or a
/// failed load). Optional monospace caption pinned to the bottom-left
/// corner.
class TripPhotoBanner extends StatelessWidget {
  const TripPhotoBanner({
    super.key,
    required this.height,
    this.caption,
    this.imageUrl,
    this.gradientOverlay = false,
    this.stripeA = KalsadaColors.heroStripeA,
    this.stripeB = KalsadaColors.heroStripeB,
  });

  final double height;
  final String? caption;
  final String? imageUrl;
  final bool gradientOverlay;
  final Color stripeA;
  final Color stripeB;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => CustomPaint(
                painter: _StripePainter(a: stripeA, b: stripeB),
              ),
              errorWidget: (context, url, error) => CustomPaint(
                painter: _StripePainter(a: stripeA, b: stripeB),
              ),
            )
          else
            CustomPaint(
              painter: _StripePainter(a: stripeA, b: stripeB),
            ),
          if (gradientOverlay)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.3, 0.55, 1],
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x99000000),
                  ],
                ),
              ),
            ),
          if (caption != null)
            Positioned(
              left: 16,
              bottom: 12,
              child: Text(
                caption!,
                style: kalsadaMono(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: const Color(0xBFFFFFFF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter({required this.a, required this.b});

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    const stripeWidth = 14.0;
    final paintA = Paint()..color = a;
    final paintB = Paint()..color = b;
    canvas.drawRect(Offset.zero & size, paintA);
    // Diagonal 135° stripes, matching the design's repeating gradient.
    canvas.clipRect(Offset.zero & size);
    var i = 0;
    for (
      double x = -size.height;
      x < size.width + size.height;
      x += stripeWidth
    ) {
      if (i.isOdd) {
        final path = Path()
          ..moveTo(x, 0)
          ..lineTo(x + stripeWidth, 0)
          ..lineTo(x + stripeWidth + size.height, size.height)
          ..lineTo(x + size.height, size.height)
          ..close();
        canvas.drawPath(path, paintB);
      }
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.a != a || oldDelegate.b != b;
}
