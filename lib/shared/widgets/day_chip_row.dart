import 'package:base_project/data/trip.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';

/// Horizontally scrollable "Day N" selector chips, shared by the itinerary
/// and map screens.
class DayChipRow extends StatelessWidget {
  const DayChipRow({
    super.key,
    required this.days,
    required this.activeDay,
    required this.onSelect,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<ItineraryDay> days;
  final int activeDay;
  final ValueChanged<int> onSelect;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final day in days) ...[
            Material(
              color: day.day == activeDay ? colors.accent : colors.fill,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(day.day),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    'Day ${day.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: day.day == activeDay
                          ? Colors.white
                          : colors.text,
                    ),
                  ),
                ),
              ),
            ),
            if (day != days.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
