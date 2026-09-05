import 'package:base_project/data/supabase/supabase_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads captured/picked images to Supabase Storage. Only used when
/// [SupabaseConfig.isConfigured] — the local dev fallback stores the picked
/// file's on-device path directly instead of calling this.
class PhotoUploadService {
  PhotoUploadService({this.clientOverride});

  final SupabaseClient? clientOverride;

  SupabaseClient get _supabase => clientOverride ?? Supabase.instance.client;

  /// Uploads [file] and returns its private object path. Callers persist the
  /// path rather than a bearer-style signed URL, which is short-lived.
  Future<String> upload(XFile file, {required String tripId}) async {
    final path = createPath(file, tripId: tripId);
    await uploadToPath(file, path);
    return path;
  }

  String createPath(XFile file, {required String tripId}) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('A user must be signed in.');
    final extensionMatch = RegExp(
      r'\.([A-Za-z0-9]{1,10})$',
    ).firstMatch(file.name);
    final ext = extensionMatch?.group(1)?.toLowerCase() ?? 'jpg';
    return '$userId/$tripId/${DateTime.now().millisecondsSinceEpoch}.$ext';
  }

  Future<void> uploadToPath(XFile file, String path) async {
    final bytes = await file.readAsBytes();
    await _supabase.storage
        .from(SupabaseConfig.photosBucket)
        .uploadBinary(path, bytes);
  }

  /// Creates a short-lived URL for displaying an authenticated user's image.
  Future<String> createSignedUrl(String path) => _supabase.storage
      .from(SupabaseConfig.photosBucket)
      .createSignedUrl(path, 60 * 60);

  Future<void> deletePath(String path) =>
      _supabase.storage.from(SupabaseConfig.photosBucket).remove([path]);

  String? pathFromLegacyUrl(String url) {
    final marker = '/${SupabaseConfig.photosBucket}/';
    final uriPath = Uri.tryParse(url)?.path;
    if (uriPath == null) return null;
    final markerIndex = uriPath.indexOf(marker);
    if (markerIndex == -1) return null;
    final encodedPath = uriPath.substring(markerIndex + marker.length);
    return Uri.decodeComponent(encodedPath);
  }

  /// Removes a legacy object whose metadata stored a public URL.
  Future<void> deleteByUrl(String url) async {
    final path = pathFromLegacyUrl(url);
    if (path == null) return;
    await deletePath(path);
  }
}
