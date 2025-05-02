// lib/domain/use_cases/assets/upload_asset.dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/core/use_cases/usecase.dart';
import 'package:shamil_web_app/domain/repositories/image_repository.dart';

/// Use Case for uploading an asset (image).
class UploadAssetUseCase implements UseCase<String, UploadAssetParams> {
  final ImageRepository repository;

  UploadAssetUseCase(this.repository);

  /// Executes the upload process.
  @override
  Future<Either<Failure, String>> call(UploadAssetParams params) async {
    // Basic validation
    if (params.assetData == null || (params.assetData is List && params.assetData.isEmpty)) {
      return Left(ValidationFailure(message: "Asset data cannot be null or empty"));
    }
     if (params.uid.isEmpty || params.uid == 'temp_uid') {
       return Left(ValidationFailure(message: "Invalid UID for asset upload"));
    }
    if (params.targetFolder.isEmpty) {
        return Left(ValidationFailure(message: "Target folder cannot be empty"));
    }

    return await repository.uploadImage(
      imageData: params.assetData,
      folder: params.targetFolder,
      providerUid: params.uid,
    );
  }
}

/// Parameters required for the [UploadAssetUseCase].
class UploadAssetParams extends Equatable {
  final dynamic assetData; // path string or Uint8List
  final String targetFolder; // e.g., "logos", "identity", "gallery"
  final String uid; // Provider UID for folder structure

  const UploadAssetParams({
    required this.assetData,
    required this.targetFolder,
    required this.uid,
  });

  // Exclude assetData from props for simplicity with Uint8List comparison
  @override List<Object?> get props => [targetFolder, uid];
}