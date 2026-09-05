import 'package:kalsada/features/photos/photo_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts and decodes a legacy public storage path', () {
    final service = PhotoUploadService();

    expect(
      service.pathFromLegacyUrl(
        'https://project.supabase.co/storage/v1/object/public/'
        'trip-photos/trip%201/photo.jpg?download=1',
      ),
      'trip 1/photo.jpg',
    );
    expect(service.pathFromLegacyUrl('https://example.com/photo.jpg'), isNull);
  });
}
