import 'dart:io';

import 'package:base_project/data/trip_photo.dart';
import 'package:base_project/dependency/dependency_manager.dart';
import 'package:base_project/features/photos/photos_store.dart';
import 'package:base_project/features/trips/trips_store.dart';
import 'package:base_project/shared/widgets/circle_icon_button.dart';
import 'package:base_project/shared/widgets/photo_viewer_dialog.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

/// Compiled photo gallery for one trip, grouped by day.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    sl<TripsStore>().initialize();
    sl<PhotosStore>().initialize();
  }

  void _showAiVideoStubDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generate AI Video'),
        content: const Text(
          'AI-generated trip recap videos are coming soon — this is a '
          'preview of the feature. Nothing is generated yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
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
                  CircleIconButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Observer(
                        builder: (context) {
                          final trip = tripsStore.tripById(widget.tripId);
                          return Text(
                            trip.name.isEmpty ? 'Trip Photos' : trip.name,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.movie_creation_outlined,
                    tooltip: 'Generate AI Video',
                    onPressed: () => _showAiVideoStubDialog(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Observer(
                builder: (context) {
                  final photosStore = sl<PhotosStore>();
                  if (photosStore.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final currentTrip = tripsStore.tripById(widget.tripId);
                  final grouped = photosStore.groupedByDay(
                    widget.tripId,
                    trip: currentTrip,
                  );
                  if (grouped.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No photos yet. Add photos to a destination from '
                          'the itinerary to see them compiled here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: colors.sub),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Text(
                          'Day ${entry.key}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: entry.value.length,
                          itemBuilder: (context, index) {
                            final photo = entry.value[index];
                            return GestureDetector(
                              onTap: () => showPhotoViewer(
                                context,
                                photos: entry.value,
                                initialIndex: index,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _GalleryThumbnail(photo: photo),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
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

class _GalleryThumbnail extends StatelessWidget {
  const _GalleryThumbnail({required this.photo});

  final TripPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final url = sl<PhotosStore>().displayUrl(photo);
        if (url.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return url.startsWith('http')
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Image.file(File(url), fit: BoxFit.cover);
      },
    );
  }
}
