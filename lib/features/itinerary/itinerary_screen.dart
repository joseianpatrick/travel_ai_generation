import 'dart:io';

import 'package:kalsada/data/trip.dart';
import 'package:kalsada/data/trip_photo.dart';
import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/photos/photos_store.dart';
import 'package:kalsada/features/trips/trips_store.dart';
import 'package:kalsada/features/trips/widgets/refine_sheet.dart';
import 'package:kalsada/shared/widgets/circle_icon_button.dart';
import 'package:kalsada/shared/widgets/day_chip_row.dart';
import 'package:kalsada/shared/widgets/photo_viewer_dialog.dart';
import 'package:kalsada/shared/widgets/primary_button.dart';
import 'package:kalsada/shared/widgets/theme_toggle_button.dart';
import 'package:kalsada/shared/widgets/trip_load_error.dart';
import 'package:kalsada/shared/utils/external_maps.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Full itinerary for one trip: day selector and stop timeline.
class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  Future<void> _findNearbyFood(ItineraryDay day) async {
    final launched = await launchExternalMap(
      nearbyFoodUri(day.latitude, day.longitude),
    );
    if (!mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No maps app found to search nearby food.')),
    );
  }

  @override
  void initState() {
    super.initState();
    final tripsStore = sl<TripsStore>();
    tripsStore.initialize();
    tripsStore.selectTrip(widget.tripId);
    sl<PhotosStore>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final tripsStore = sl<TripsStore>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Observer(
          builder: (context) {
            if (tripsStore.isLoading) {
              return _ItineraryLoading(onBack: () => context.pop());
            }
            if (tripsStore.loadError.isNotEmpty) {
              return _ItineraryLoadError(
                message: tripsStore.loadError,
                onRetry: tripsStore.initialize,
                onBack: () => context.pop(),
              );
            }
            final trip = tripsStore.tripById(widget.tripId);
            if (trip.id.isEmpty) {
              return _ItineraryLoadError(
                message: 'This trip no longer exists.',
                onRetry: tripsStore.initialize,
                onBack: () => context.pop(),
              );
            }
            final activeDay = trip.days.firstWhere(
              (day) => day.day == tripsStore.activeDayNumber,
              orElse: () =>
                  trip.days.isEmpty ? ItineraryDay.empty() : trip.days.first,
            );
            // The seeded shared demo trip has no owner, so it is read-only
            // (its edits would be rejected by row-level security).
            final canEdit =
                trip.id.isNotEmpty && trip.id != 'palawan-coastal-loop';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleIconButton(
                            icon: Icons.arrow_back_ios_new,
                            tooltip: 'Back',
                            onPressed: () => context.pop(),
                          ),
                          Row(
                            children: [
                              if (trip.id.isNotEmpty) ...[
                                CircleIconButton(
                                  icon: Icons.map_outlined,
                                  tooltip: 'View on map',
                                  onPressed: () {
                                    tripsStore.selectTrip(trip.id);
                                    context.goNamed('map');
                                  },
                                ),
                                const SizedBox(width: 8),
                                CircleIconButton(
                                  icon: Icons.photo_library_outlined,
                                  tooltip: 'Trip photos',
                                  onPressed: () => context.pushNamed(
                                    'gallery',
                                    pathParameters: {'id': trip.id},
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (canEdit) ...[
                                CircleIconButton(
                                  icon: Icons.auto_awesome,
                                  tooltip: 'Refine with AI',
                                  onPressed: () =>
                                      showRefineSheet(context, trip),
                                ),
                                const SizedBox(width: 8),
                                CircleIconButton(
                                  icon: Icons.edit_outlined,
                                  tooltip: 'Edit trip',
                                  onPressed: () => context.pushNamed(
                                    'trip-edit',
                                    pathParameters: {'id': trip.id},
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              const ThemeToggleButton(),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        trip.name,
                        style: kalsadaHeadline(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${trip.datesLabel} · ${trip.riderCount} riders · '
                        '${trip.distanceTotal}',
                        style: TextStyle(fontSize: 14, color: colors.sub),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 14),
                  child: DayChipRow(
                    days: trip.days,
                    activeDay: tripsStore.activeDayNumber,
                    onSelect: tripsStore.selectDay,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      Row(
                        children: [
                          _DayStat(
                            label: 'Distance',
                            value: activeDay.distance,
                          ),
                          const SizedBox(width: 24),
                          _DayStat(
                            label: 'Duration',
                            value: activeDay.duration,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        activeDay.title,
                        style: kalsadaHeadline(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.restaurant_outlined),
                          label: const Text('Find nearby food'),
                          onPressed: () => _findNearbyFood(activeDay),
                        ),
                      ),
                      if (activeDay.stay.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.hotel_outlined,
                              size: 16,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                activeDay.stayPrice.isEmpty
                                    ? 'Staying at ${activeDay.stay}'
                                    : 'Staying at ${activeDay.stay} · '
                                          '${activeDay.stayPrice}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.sub,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      for (var i = 0; i < activeDay.stops.length; i++)
                        _StopTimelineTile(
                          stop: activeDay.stops[i],
                          isLast: i == activeDay.stops.length - 1,
                          tripId: trip.id,
                          dayNumber: activeDay.day,
                          dayId: activeDay.id,
                          stopIndex: i,
                          canEdit: canEdit,
                        ),
                    ],
                  ),
                ),
                if (canEdit)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: _TripStatusFooter(trip: trip),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ItineraryLoading extends StatelessWidget {
  const _ItineraryLoading({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 8,
          left: 20,
          child: CircleIconButton(
            icon: Icons.arrow_back_ios_new,
            tooltip: 'Back',
            onPressed: onBack,
          ),
        ),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ItineraryLoadError extends StatelessWidget {
  const _ItineraryLoadError({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 8,
          left: 20,
          child: CircleIconButton(
            icon: Icons.arrow_back_ios_new,
            tooltip: 'Back',
            onPressed: onBack,
          ),
        ),
        TripLoadError(message: message, onRetry: onRetry),
      ],
    );
  }
}

class _DayStat extends StatelessWidget {
  const _DayStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: kalsadaMono(fontSize: 11, color: colors.sub),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: kalsadaMono(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

/// Replaces the old "Book This Trip" CTA: mark the whole trip done/skipped,
/// or undo back to planning once one of those is set.
class _TripStatusFooter extends StatelessWidget {
  const _TripStatusFooter({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    switch (trip.status) {
      case TripStatus.planning:
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.sub,
                    side: BorderSide(color: colors.sep),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KalsadaRadius.lg),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => sl<TripsStore>().updateTripStatus(
                    trip.id,
                    TripStatus.skipped,
                  ),
                  child: const Text('Skip Trip'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Mark Trip as Done',
                onPressed: () =>
                    sl<TripsStore>().updateTripStatus(trip.id, TripStatus.done),
              ),
            ),
          ],
        );
      case TripStatus.done:
        return _StatusBanner(
          icon: Icons.check_circle,
          label: 'Trip marked as done',
          color: colors.success,
          onUndo: () =>
              sl<TripsStore>().updateTripStatus(trip.id, TripStatus.done),
        );
      case TripStatus.skipped:
        return _StatusBanner(
          icon: Icons.block,
          label: 'Trip skipped',
          color: colors.sub,
          onUndo: () =>
              sl<TripsStore>().updateTripStatus(trip.id, TripStatus.skipped),
        );
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.label,
    required this.color,
    required this.onUndo,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          TextButton(onPressed: onUndo, child: const Text('Undo')),
        ],
      ),
    );
  }
}

class _StopTimelineTile extends StatelessWidget {
  const _StopTimelineTile({
    required this.stop,
    required this.isLast,
    required this.tripId,
    required this.dayNumber,
    required this.dayId,
    required this.stopIndex,
    required this.canEdit,
  });

  final TripStop stop;
  final bool isLast;
  final String tripId;
  final int dayNumber;
  final String dayId;
  final int stopIndex;
  final bool canEdit;

  void _onThumbnailTap(BuildContext context) {
    final stopPhotos = sl<PhotosStore>().forStop(
      tripId,
      dayNumber,
      stopIndex,
      dayId: dayId,
      stopId: stop.id,
    );
    if (stopPhotos.isEmpty) {
      _showPhotoSheet(context);
      return;
    }
    showPhotoViewer(
      context,
      photos: stopPhotos,
      initialIndex: stopPhotos.length - 1,
      onAddPhoto: canEdit ? () => _showPhotoSheet(context) : null,
    );
  }

  void _setStatus(StopStatus status) {
    sl<TripsStore>().updateStopStatus(tripId, dayNumber, stopIndex, status);
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    final added = await sl<PhotosStore>().addPhoto(
      file: picked,
      tripId: tripId,
      dayNumber: dayNumber,
      stopIndex: stopIndex,
      dayId: dayId,
      stopId: stop.id,
    );
    if (!added) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the photo. Try again.')),
      );
      return;
    }
    try {
      if (navigator.canPop()) navigator.pop();
    } catch (_) {
      // The sheet's context may already be disposed if the screen was
      // popped while the upload was in flight; nothing left to close.
    }
  }

  void _showPhotoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = sheetContext.kalsada;
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              ListTile(
                leading: Icon(
                  Icons.photo_camera_outlined,
                  color: colors.accent,
                ),
                title: const Text('Take Photo'),
                onTap: () => _pickImage(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_outlined, color: colors.accent),
                title: const Text('Choose from Gallery'),
                onTap: () => _pickImage(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final isDone = stop.status == StopStatus.done;
    final isSkipped = stop.status == StopStatus.skipped;
    final dotColor = isDone
        ? colors.success
        : isSkipped
        ? colors.ter
        : colors.accent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 8, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: colors.sep)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              stop.time,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.sub,
                              ),
                            ),
                            if (isDone) ...[
                              const SizedBox(width: 6),
                              _StatusChip(label: 'Done', color: colors.success),
                            ] else if (isSkipped) ...[
                              const SizedBox(width: 6),
                              _StatusChip(
                                label: 'Skipped',
                                color: colors.warning,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stop.place,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSkipped ? colors.sub : colors.text,
                            decoration: isSkipped
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          stop.note,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.sub,
                            decoration: isSkipped
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      Observer(
                        builder: (context) {
                          final photosStore = sl<PhotosStore>();
                          final count = photosStore.countForStop(
                            tripId,
                            dayNumber,
                            stopIndex,
                            dayId: dayId,
                            stopId: stop.id,
                          );
                          final latest = photosStore.latestForStop(
                            tripId,
                            dayNumber,
                            stopIndex,
                            dayId: dayId,
                            stopId: stop.id,
                          );
                          return GestureDetector(
                            onTap: () => _onThumbnailTap(context),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colors.fill,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colors.sep),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: latest == null
                                      ? Icon(
                                          Icons.camera_alt_outlined,
                                          size: 18,
                                          color: colors.sub,
                                        )
                                      : _StopThumbnail(photo: latest),
                                ),
                                if (count > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.accent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (canEdit) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StopActionButton(
                              icon: Icons.check,
                              active: isDone,
                              activeColor: colors.success,
                              tooltip: 'Mark as done',
                              onTap: () => _setStatus(StopStatus.done),
                            ),
                            const SizedBox(width: 6),
                            _StopActionButton(
                              icon: Icons.block,
                              active: isSkipped,
                              activeColor: colors.warning,
                              tooltip: 'Skip this stop',
                              onTap: () => _setStatus(StopStatus.skipped),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StopActionButton extends StatelessWidget {
  const _StopActionButton({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final Color activeColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? activeColor.withValues(alpha: 0.15) : colors.fill,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 26,
            height: 26,
            child: Icon(
              icon,
              size: 14,
              color: active ? activeColor : colors.sub,
            ),
          ),
        ),
      ),
    );
  }
}

class _StopThumbnail extends StatelessWidget {
  const _StopThumbnail({required this.photo});

  final TripPhoto photo;

  @override
  Widget build(BuildContext context) {
    final url = sl<PhotosStore>().displayUrl(photo);
    if (url.isEmpty) return const CircularProgressIndicator(strokeWidth: 2);
    return url.startsWith('http')
        ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
        : Image.file(File(url), fit: BoxFit.cover);
  }
}
