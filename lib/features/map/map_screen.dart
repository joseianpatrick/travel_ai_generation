import 'package:kalsada/data/trip.dart';
import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/map/widgets/map_location_sheet.dart';
import 'package:kalsada/features/trips/trips_store.dart';
import 'package:kalsada/shared/widgets/day_chip_row.dart';
import 'package:kalsada/shared/widgets/primary_button.dart';
import 'package:kalsada/shared/widgets/theme_toggle_button.dart';
import 'package:kalsada/shared/widgets/trip_load_error.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobx/mobx.dart' as mobx;

/// Map tab: real OpenStreetMap with numbered day markers and a floating day
/// card. There is no drawn route — a straight line between day locations would
/// misrepresent the real roads — so each marker instead hands off to an
/// external maps app for actual routing.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  mobx.ReactionDisposer? _dayReaction;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    final tripsStore = sl<TripsStore>();
    tripsStore.initialize();
    // Fly to the selected day's location whenever the chip selection changes.
    _dayReaction = mobx.reaction<ItineraryDay>(
      (_) => tripsStore.activeDay,
      (day) {
        if (!_mapReady || (day.latitude == 0 && day.longitude == 0)) return;
        _mapController.move(
          LatLng(day.latitude, day.longitude),
          _mapController.camera.zoom,
        );
      },
    );
  }

  @override
  void dispose() {
    _dayReaction?.call();
    _mapController.dispose();
    super.dispose();
  }

  void _fitRoute(List<ItineraryDay> days) {
    final points = [
      for (final day in days)
        if (day.latitude != 0 || day.longitude != 0)
          LatLng(day.latitude, day.longitude),
    ];
    if (points.length < 2) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 100, 48, 220),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final tripsStore = sl<TripsStore>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Route Map',
                    style: kalsadaHeadline(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const ThemeToggleButton(),
                ],
              ),
            ),
            Expanded(
              child: Observer(
                builder: (context) {
                  if (tripsStore.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (tripsStore.loadError.isNotEmpty) {
                    return TripLoadError(
                      message: tripsStore.loadError,
                      onRetry: tripsStore.initialize,
                    );
                  }
                  final trip = tripsStore.activeTrip;
                  final activeDay = tripsStore.activeDay;
                  final dark = Theme.of(context).brightness ==
                      Brightness.dark;
                  final routePoints = [
                    for (final day in trip.days)
                      if (day.latitude != 0 || day.longitude != 0)
                        LatLng(day.latitude, day.longitude),
                  ];
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: colors.mapBg,
                          child: routePoints.isEmpty
                              ? Center(
                                  child: Text(
                                    'Plan a trip to see its route here.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.sub,
                                    ),
                                  ),
                                )
                              : FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: routePoints.first,
                                    initialZoom: 8,
                                    onMapReady: () {
                                      _mapReady = true;
                                      _fitRoute(trip.days);
                                    },
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: dark
                                          ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                                          : 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.kalsada.kalsada',
                                      tileProvider: sl<TileProvider>(),
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        for (final day in trip.days)
                                          if (day.latitude != 0 ||
                                              day.longitude != 0)
                                            Marker(
                                              point: LatLng(
                                                day.latitude,
                                                day.longitude,
                                              ),
                                              width: 26,
                                              height: 26,
                                              child: _DayPin(
                                                day: day.day,
                                                active: day.day ==
                                                    activeDay.day,
                                                onTap: () {
                                                  tripsStore.selectDay(day.day);
                                                  showMapLocationSheet(
                                                    context,
                                                    day,
                                                  );
                                                },
                                              ),
                                            ),
                                        for (
                                          var i = 0;
                                          i < activeDay.stops.length;
                                          i++
                                        )
                                          if (activeDay.stops[i]
                                              .hasCoordinates)
                                            Marker(
                                              point: LatLng(
                                                activeDay.stops[i].latitude!,
                                                activeDay.stops[i].longitude!,
                                              ),
                                              width: 18,
                                              height: 18,
                                              child: _StopPin(
                                                index: i,
                                                onTap: () =>
                                                    showStopLocationSheet(
                                                  context,
                                                  activeDay.day,
                                                  i,
                                                  activeDay.stops[i],
                                                ),
                                              ),
                                            ),
                                      ],
                                    ),
                                    const Align(
                                      alignment: Alignment.bottomRight,
                                      child: _MapAttribution(),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: DayChipRow(
                          days: trip.days,
                          activeDay: tripsStore.activeDayNumber,
                          onSelect: tripsStore.selectDay,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _DayDetailCard(
                          trip: trip,
                          day: activeDay,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPin extends StatelessWidget {
  const _DayPin({
    required this.day,
    required this.active,
    required this.onTap,
  });

  final int day;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: active ? colors.accent : colors.sub,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// A single destination within the active day — smaller and outlined so it
/// reads as a sub-marker beneath the filled day pin.
class _StopPin extends StatelessWidget {
  const _StopPin({required this.index, required this.onTap});

  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          shape: BoxShape.circle,
          border: Border.all(color: colors.accent, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}

/// OSM/CARTO tile usage requires visible attribution.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2, right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: const Color(0x99FFFFFF),
      child: const Text(
        '© OpenStreetMap contributors © CARTO',
        style: TextStyle(fontSize: 9, color: Color(0xCC000000)),
      ),
    );
  }
}

/// Small green pill flagging AI-optimized route stats, matching the
/// "Kinetic Horizon" secondary-container badge treatment.
class _AiOptimizedBadge extends StatelessWidget {
  const _AiOptimizedBadge({required this.colors});

  final KalsadaColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(KalsadaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 11, color: colors.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            'AI OPTIMIZED',
            style: kalsadaMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: colors.onSecondaryContainer,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDetailCard extends StatelessWidget {
  const _DayDetailCard({required this.trip, required this.day});

  final Trip trip;
  final ItineraryDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(KalsadaRadius.xl),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.14),
            offset: const Offset(0, 8),
            blurRadius: 28,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAY ${day.day}',
            style: kalsadaMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.sub,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            day.title,
            style: kalsadaHeadline(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${day.distance} · ${day.duration}',
                style: kalsadaMono(fontSize: 13, color: colors.sub),
              ),
              const SizedBox(width: 8),
              _AiOptimizedBadge(colors: colors),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'View Day Details',
            height: 42,
            onPressed: trip.id.isEmpty
                ? null
                : () => context.pushNamed(
                    'itinerary',
                    pathParameters: {'id': trip.id},
                  ),
          ),
        ],
      ),
    );
  }
}
