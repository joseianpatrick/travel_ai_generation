import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/trips/trips_store.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

/// Placeholder for location-aware restaurant discovery around the selected
/// itinerary day. Restaurant providers and AI summaries are intentionally
/// deferred; the active day remains the future search context.
class NearbyFoodScreen extends StatefulWidget {
  const NearbyFoodScreen({super.key});

  @override
  State<NearbyFoodScreen> createState() => _NearbyFoodScreenState();
}

class _NearbyFoodScreenState extends State<NearbyFoodScreen> {
  @override
  void initState() {
    super.initState();
    sl<TripsStore>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final tripsStore = sl<TripsStore>();
    return Scaffold(
      body: SafeArea(
        child: Observer(
          builder: (context) {
            if (tripsStore.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (tripsStore.loadError.isNotEmpty) {
              return _NearbyFoodMessage(
                icon: Icons.error_outline,
                title: 'Could not load trip location',
                body: tripsStore.loadError,
                actionLabel: 'Retry',
                onAction: tripsStore.initialize,
              );
            }
            final trip = tripsStore.activeTrip;
            if (trip.id.isEmpty) {
              return const _NearbyFoodMessage(
                icon: Icons.restaurant_outlined,
                title: 'Nearby food is coming soon',
                body:
                    'Open an itinerary to set the day and location for restaurant discovery.',
              );
            }
            final day = tripsStore.activeDay;
            return _NearbyFoodPlaceholder(
              tripName: trip.name,
              dayNumber: day.day,
              dayTitle: day.title,
            );
          },
        ),
      ),
    );
  }
}

class _NearbyFoodPlaceholder extends StatelessWidget {
  const _NearbyFoodPlaceholder({
    required this.tripName,
    required this.dayNumber,
    required this.dayTitle,
  });

  final String tripName;
  final int dayNumber;
  final String dayTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEARBY FOOD',
                  style: kalsadaMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Restaurants around Day $dayNumber',
                  style: kalsadaHeadline(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$tripName · $dayTitle',
                  style: TextStyle(fontSize: 14, color: colors.sub),
                ),
                const SizedBox(height: 32),
                _ComingSoonCard(colors: colors),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.colors});

  final KalsadaColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.sep),
        borderRadius: BorderRadius.circular(KalsadaRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.restaurant_menu_outlined, size: 32, color: colors.accent),
          const SizedBox(height: 16),
          Text(
            'Restaurant discovery is coming soon',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This space will list nearby restaurants and let you filter by cuisine, price, and rating. Optional AI summaries can help the group decide.',
            style: TextStyle(fontSize: 14, height: 1.45, color: colors.sub),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FutureFilter(label: 'Cuisine'),
              _FutureFilter(label: 'Price'),
              _FutureFilter(label: 'Rating'),
              _FutureFilter(label: 'AI summary'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FutureFilter extends StatelessWidget {
  const _FutureFilter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Chip(
      avatar: Icon(Icons.lock_outline, size: 15, color: colors.sub),
      label: Text(label),
      backgroundColor: colors.fill,
      side: BorderSide(color: colors.sep),
      labelStyle: TextStyle(fontSize: 13, color: colors.sub),
    );
  }
}

class _NearbyFoodMessage extends StatelessWidget {
  const _NearbyFoodMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.accent),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: kalsadaHeadline(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.sub),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
