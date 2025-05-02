
// lib/domain/repositories/image_repository.dart
import 'package:dartz/dartz.dart';
import 'package:shamil_web_app/core/error/failures.dart';

abstract class ImageRepository {
  /// Uploads image data (path string or Uint8List)
  /// Returns the public URL on success.
  Future<Either<Failure, String>> uploadImage({
    required dynamic imageData,
    required String folder, // e.g., "logos", "identity", "gallery"
    required String providerUid,
  });

  /// Deletes an image using its URL (implementation needs to parse publicId)
  Future<Either<Failure, void>> deleteImage(String imageUrl);
}
