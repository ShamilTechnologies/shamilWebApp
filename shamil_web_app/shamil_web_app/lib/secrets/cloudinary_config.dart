// cloudinary_config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryConfig {
  /// Loads the CLOUDINARY_URL from the .env file.
  static String get cloudinaryUrl => dotenv.env['CLOUDINARY_URL'] ?? '';

  /// Parses the CLOUDINARY_URL and returns a map with the API key, API secret, and cloud name.
  static Map<String, String> parseCloudinaryUrl() {
    final url = cloudinaryUrl;
    if (url.isEmpty) {
      throw Exception("CLOUDINARY_URL is not set");
    }
    // Remove the "cloudinary://" prefix.
    final trimmed = url.replaceFirst('cloudinary://', '');
    // Split at the "@" to separate credentials and cloud name.
    final parts = trimmed.split('@');
    if (parts.length != 2) {
      throw Exception("Invalid CLOUDINARY_URL format");
    }
    final credentials = parts[0].split(':');
    if (credentials.length != 2) {
      throw Exception("Invalid credentials in CLOUDINARY_URL");
    }
    return {
      'apiKey': credentials[0],
      'apiSecret': credentials[1],
      'cloudName': parts[1],
    };
  }
}
