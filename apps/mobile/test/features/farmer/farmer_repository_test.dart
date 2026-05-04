import 'package:flutter_test/flutter_test.dart';
import 'package:jirisewa_mobile/features/farmer/repositories/farmer_repository.dart';

void main() {
  group('producePhotoContentType', () {
    test('maps allowed photo extensions to bucket MIME types', () {
      expect(producePhotoContentType('jpg'), 'image/jpeg');
      expect(producePhotoContentType('jpeg'), 'image/jpeg');
      expect(producePhotoContentType('png'), 'image/png');
      expect(producePhotoContentType('webp'), 'image/webp');
      expect(producePhotoContentType('.JPG'), 'image/jpeg');
    });

    test('rejects unsupported photo extensions', () {
      expect(
        () => producePhotoContentType('gif'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
