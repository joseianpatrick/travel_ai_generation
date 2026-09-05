import 'package:base_project/data/trip.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';

/// Overlapping rider initial avatars with an optional "+N" overflow bubble.
class RiderAvatarRow extends StatelessWidget {
  const RiderAvatarRow({
    super.key,
    required this.riders,
    this.maxVisible,
    this.size = 26,
    this.overlap = true,
  });

  final List<Rider> riders;
  final int? maxVisible;
  final double size;
  final bool overlap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final visible = maxVisible == null
        ? riders
        : riders.take(maxVisible!).toList();
    final extra = riders.length - visible.length;
    final shift = overlap ? -8.0 : 8.0;

    Widget avatar(Color bg, Color fg, String label) {
      return Container(
        width: size,
        height: size,
        margin: EdgeInsets.only(left: overlap ? 0 : 0),
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: overlap
              ? Border.all(color: colors.card, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final children = <Widget>[
      for (final rider in visible)
        avatar(Color(rider.colorValue), Colors.white, rider.initials),
      if (extra > 0) avatar(colors.fill, colors.sub, '+$extra'),
    ];

    if (!overlap) {
      return Wrap(spacing: 8, runSpacing: 8, children: children);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, child) in children.indexed)
            Transform.translate(
              offset: Offset(shift * i, 0),
              child: child,
            ),
        ],
      ),
    );
  }
}
