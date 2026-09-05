import 'package:base_project/data/trip.dart';
import 'package:base_project/shared/utils/external_maps.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';

/// What the sheet needs to render, independent of whether it came from a
/// day pin or a stop pin.
class _LocationSheetData {
  const _LocationSheetData({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
}

/// Opens the location sheet for a day's pin: its details plus buttons that
/// hand the coordinates off to an external maps app.
Future<void> showMapLocationSheet(BuildContext context, ItineraryDay day) {
  return _showLocationSheet(
    context,
    _LocationSheetData(
      kicker: 'DAY ${day.day}',
      title: day.title,
      subtitle: '${day.distance} · ${day.duration}',
      latitude: day.latitude,
      longitude: day.longitude,
    ),
  );
}

/// Opens the location sheet for a single stop's pin within [dayNumber].
/// Only call this when `stop.hasCoordinates` is true.
Future<void> showStopLocationSheet(
  BuildContext context,
  int dayNumber,
  int stopIndex,
  TripStop stop,
) {
  return _showLocationSheet(
    context,
    _LocationSheetData(
      kicker: 'DAY $dayNumber · STOP ${stopIndex + 1}',
      title: stop.place,
      subtitle: stop.time.isEmpty ? stop.note : '${stop.time} · ${stop.note}',
      latitude: stop.latitude!,
      longitude: stop.longitude!,
    ),
  );
}

Future<void> _showLocationSheet(BuildContext context, _LocationSheetData data) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _MapLocationSheet(data: data),
  );
}

class _MapLocationSheet extends StatelessWidget {
  const _MapLocationSheet({required this.data});

  final _LocationSheetData data;

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final launched = await launchExternalMap(uri);
    if (navigator.canPop()) navigator.pop();
    if (!launched) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No maps app found to open this place.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.ter,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.kicker,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.sub,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            style: TextStyle(fontSize: 13, color: colors.sub),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SheetButton(
                  icon: Icons.place_outlined,
                  label: 'Open in Maps',
                  filled: true,
                  onTap: () => _open(
                    context,
                    mapsViewUri(data.latitude, data.longitude, data.title),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetButton(
                  icon: Icons.directions_outlined,
                  label: 'Directions',
                  filled: false,
                  onTap: () => _open(
                    context,
                    mapsDirectionsUri(data.latitude, data.longitude),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Routing opens in your maps app.',
              style: TextStyle(fontSize: 12, color: colors.sub),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final fg = filled ? Colors.white : colors.accent;
    return Material(
      color: filled ? colors.accent : colors.fill,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
