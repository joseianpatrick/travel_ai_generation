import 'dart:io';

import 'package:kalsada/data/trip_photo.dart';
import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/photos/photos_store.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

/// Full-screen, swipeable viewer over [photos] starting at [initialIndex],
/// with a delete action wired to [PhotosStore.deletePhoto]. Pass
/// [onAddPhoto] to also surface an "add another" action (e.g. from a stop
/// that already has photos).
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<TripPhoto> photos,
  int initialIndex = 0,
  VoidCallback? onAddPhoto,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (_) => _PhotoViewerDialog(
      photos: photos,
      initialIndex: initialIndex,
      onAddPhoto: onAddPhoto,
    ),
  );
}

class _PhotoViewerDialog extends StatefulWidget {
  const _PhotoViewerDialog({
    required this.photos,
    required this.initialIndex,
    this.onAddPhoto,
  });

  final List<TripPhoto> photos;
  final int initialIndex;
  final VoidCallback? onAddPhoto;

  @override
  State<_PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<_PhotoViewerDialog> {
  late List<TripPhoto> _photos;
  late int _index;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.photos);
    _index = widget.initialIndex.clamp(0, _photos.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete this photo?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final photo = _photos[_index];
    final deleted = await sl<PhotosStore>().deletePhoto(photo.id);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the photo. Try again.')),
      );
      return;
    }
    if (_photos.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _photos.removeAt(_index);
      if (_index >= _photos.length) _index = _photos.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) return const SizedBox.shrink();
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (_photos.length > 1)
                    Text(
                      '${_index + 1} / ${_photos.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  Row(
                    children: [
                      if (widget.onAddPhoto != null)
                        IconButton(
                          icon: const Icon(
                            Icons.add_a_photo_outlined,
                            color: Colors.white,
                          ),
                          tooltip: 'Add photo',
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onAddPhoto!();
                          },
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                        tooltip: 'Delete photo',
                        onPressed: _delete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  child: Center(
                    child: _PhotoViewerImage(photo: _photos[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoViewerImage extends StatelessWidget {
  const _PhotoViewerImage({required this.photo});

  final TripPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final url = sl<PhotosStore>().displayUrl(photo);
        if (url.isEmpty) return const CircularProgressIndicator();
        return url.startsWith('http')
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)
            : Image.file(File(url), fit: BoxFit.contain);
      },
    );
  }
}
