// lib/domain/use_cases/assets/remove_asset.dart
import 'package:dartz/dartz.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/core/use_cases/usecase.dart';
import 'package:shamil_web_app/domain/repositories/image_repository.dart';

/// Use Case for removing an asset using its URL.
class RemoveAssetUseCase implements UseCase<void, String> {
  final ImageRepository repository;

  RemoveAssetUseCase(this.repository);

  /// [imageUrl] The public URL of the asset to remove.
  @override
  Future<Either<Failure, void>> call(String imageUrl) async {
     if (imageUrl.isEmpty || !(imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
       return Left(ValidationFailure(message: "Invalid image URL provided"));
     }

    // --- Extract Public ID from Cloudinary URL ---
    String? publicId;
    try {
       Uri uri = Uri.parse(imageUrl);
       List<String> segments = uri.pathSegments;
       // Find the segment after version (e.g., v12345) which starts the path+public_id
       int versionSegmentIndex = segments.indexWhere((s) => s.startsWith('v') && int.tryParse(s.substring(1)) != null);

       if (versionSegmentIndex != -1 && versionSegmentIndex < segments.length -1) {
          // Join remaining segments and remove file extension
          String pathWithExtension = segments.sublist(versionSegmentIndex + 1).join('/');
          if (pathWithExtension.contains('.')) {
             publicId = pathWithExtension.substring(0, pathWithExtension.lastIndexOf('.'));
          } else {
             publicId = pathWithExtension; // No extension
          }
       }

       if (publicId == null || publicId.isEmpty) {
          print("RemoveAssetUseCase: Could not extract public ID from URL: $imageUrl");
          return Left(ValidationFailure(message: "Could not extract public ID from URL"));
       }

    } catch (e) {
       print("RemoveAssetUseCase: Error parsing URL: $e");
       return Left(ValidationFailure(message: "Invalid image URL format"));
    }
    // --- End Public ID Extraction ---

    print("RemoveAssetUseCase: Attempting to delete publicId '$publicId'");
    return await repository.deleteImageByPublicId(publicId);
  }
}