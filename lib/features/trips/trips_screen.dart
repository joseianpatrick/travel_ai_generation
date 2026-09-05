import 'package:kalsada/data/trip.dart';
import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/auth/auth_store.dart';
import 'package:kalsada/features/trips/trips_store.dart';
import 'package:kalsada/shared/widgets/circle_icon_button.dart';
import 'package:kalsada/shared/widgets/rider_avatar_row.dart';
import 'package:kalsada/shared/widgets/theme_toggle_button.dart';
import 'package:kalsada/shared/widgets/trip_load_error.dart';
import 'package:kalsada/shared/widgets/trip_photo_banner.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

/// Home tab: upcoming and past trips.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  @override
  void initState() {
    super.initState();
    sl<TripsStore>().initialize();
  }

  void _openItinerary(Trip trip) {
    sl<TripsStore>().selectTrip(trip.id);
    context.pushNamed('itinerary', pathParameters: {'id': trip.id});
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    final authStore = sl<AuthStore>();
    await authStore.signOut();
    if (!mounted) return;
    if (authStore.errorMessage.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(authStore.errorMessage)));
    }
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.logout,
                        tooltip: 'Sign out',
                        onPressed: _signOut,
                      ),
                      const Spacer(),
                      CircleIconButton(
                        icon: Icons.add,
                        tooltip: 'Plan a trip',
                        onPressed: () => context.goNamed('plan'),
                      ),
                      const SizedBox(width: 8),
                      const ThemeToggleButton(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trips',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: colors.text,
                    ),
                  ),
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
                  final upcoming = tripsStore.upcomingTrips;
                  final past = tripsStore.pastTrips;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      const _SectionLabel('Upcoming'),
                      if (upcoming.isEmpty)
                        const _EmptySection(
                          message: 'No trips yet — plan one from the Plan tab.',
                        )
                      else
                        for (final trip in upcoming)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TripCard(
                              trip: trip,
                              onTap: () => _openItinerary(trip),
                            ),
                          ),
                      const SizedBox(height: 12),
                      const _SectionLabel('Past'),
                      if (past.isEmpty)
                        const _EmptySection(
                          message: 'Your completed trips will show up here.',
                        )
                      else
                        for (final trip in past)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TripCard(
                              trip: trip,
                              onTap: () => _openItinerary(trip),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: context.kalsada.sub,
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: colors.sub),
      ),
    );
  }
}

class _TripStatusBadge extends StatelessWidget {
  const _TripStatusBadge({required this.status});

  final TripStatus status;

  @override
  Widget build(BuildContext context) {
    final isDone = status == TripStatus.done;
    final color = isDone
        ? context.kalsada.success
        : KalsadaColors.statusOverlay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.block,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isDone ? 'Done' : 'Skipped',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 0.5,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                TripPhotoBanner(
                  height: 120,
                  caption:
                      '${(trip.destination.isNotEmpty ? trip.destination : trip.name).toUpperCase()} · PHOTO',
                  imageUrl: trip.coverImageUrl.isNotEmpty
                      ? trip.coverImageUrl
                      : null,
                ),
                if (trip.status != TripStatus.planning)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _TripStatusBadge(status: trip.status),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trip.datesLabel} · ${trip.nights} nights',
                    style: TextStyle(fontSize: 14, color: colors.sub),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      RiderAvatarRow(riders: trip.riders, maxVisible: 4),
                      const Spacer(),
                      Text(
                        trip.distanceTotal,
                        style: TextStyle(fontSize: 13, color: colors.sub),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
