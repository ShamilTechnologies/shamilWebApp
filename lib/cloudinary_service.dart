import 'dart:convert';
import 'dart:io'; // Used for File type check, though we expect path string on non-web
import 'dart:typed_data'; // Used for Uint8List check on web

import 'package:flutter/foundation.dart' show kIsWeb; // For platform check
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart'; // Keep for deleteFile if used
import 'package:shamil_web_app/secrets/cloudinary_config.dart'; // Adjust path if needed

class CloudinaryService {
  // Keep static config properties as they were
  static final _config = CloudinaryConfig.parseCloudinaryUrl();
  static final String cloudName = _config['cloudName']!;
  static const String uploadPreset = 'ml_default'; // Ensure this is your correct unsigned preset
  static final String apiKey = _config['apiKey']!;
  static final String apiSecret = _config['apiSecret']!;

  /// Uploads file data (Uint8List for web, String path for non-web) to Cloudinary.
  /// Optionally, specify a [folder] to organize uploads.
  static Future<String?> uploadFile(dynamic fileData, {String folder = ''}) async {
    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    print("CloudinaryService (HTTP): Attempting upload. Platform Web: $kIsWeb, Data Type: ${fileData.runtimeType}, Folder: $folder");

    // Input validation
    if (fileData == null) {
      print("CloudinaryService Error: fileData is null.");
      return null;
    }

    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      if (folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      // --- Platform-Specific File Handling for HTTP ---
      if (kIsWeb && fileData is Uint8List) {
         print("CloudinaryService (HTTP): Adding bytes for web upload.");
         if (fileData.isEmpty) {
              print("CloudinaryService Error: Received empty Uint8List for web upload.");
              return null;
         }
         // Generate a unique filename for web uploads
         final String fileName = 'web_upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
         request.files.add(http.MultipartFile.fromBytes(
             'file', // Cloudinary expects the file field named 'file'
             fileData,
             filename: fileName // Provide a filename
         ));
      } else if (!kIsWeb && fileData is String) {
         print("CloudinaryService (HTTP): Adding file from path for non-web: $fileData");
         // Assuming fileData is the path string returned by file_selector on non-web
          if (fileData.isEmpty) {
              print("CloudinaryService Error: Received empty file path for non-web upload.");
              return null;
          }
         // Check if file exists before attempting to create MultipartFile from path
         if (!File(fileData).existsSync()) {
             print("CloudinaryService Error: File not found at path: $fileData");
             return null;
         }
         request.files.add(await http.MultipartFile.fromPath(
             'file', // Field name
             fileData // The file path
         ));
      }
      // Add handling for File object if picker returns that on non-web
      // else if (!kIsWeb && fileData is File) { ... }
      else {
         print("CloudinaryService Error: Unsupported file data type received: ${fileData.runtimeType}");
         return null; // Or throw an error
      }
      // --- End Platform-Specific File Handling ---

      print("CloudinaryService (HTTP): Sending upload request...");
      final response = await request.send();
      final responseBody = await response.stream.bytesToString(); // Read response body

      if (response.statusCode >= 200 && response.statusCode < 300) { // Check for 2xx success codes
        final jsonData = json.decode(responseBody);
        final secureUrl = jsonData['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
             print("CloudinaryService (HTTP): Upload successful. URL: $secureUrl");
             return secureUrl; // Return the secure URL
        } else {
             print('CloudinaryService Error: Upload succeeded but no secure_url found in response: $responseBody');
             return null;
        }
      } else {
        print('CloudinaryService Error: Upload failed with status: ${response.statusCode}');
        print('CloudinaryService Error Response: $responseBody');
        return null;
      }
    } catch (e, s) {
      print('CloudinaryService Exception during HTTP upload: $e\n$s');
      return null;
    }
  }

  /// Deletes a file from Cloudinary using its [publicId].
  /// **WARNING:** Generating a signature on the client is insecure.
  /// Use this function for demonstration purposes only or move to backend.
  static Future<bool> deleteFile(String publicId, {String resourceType = 'image'}) async {
    /* ... (Keep existing deleteFile implementation, but be aware of security warning) ... */
     final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
     final stringToSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
     final signature = sha1.convert(utf8.encode(stringToSign)).toString();
     final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy');
     try {
       final response = await http.post(url, body: {
         'public_id': publicId, 'timestamp': '$timestamp', 'api_key': apiKey, 'signature': signature,
       });
       if (response.statusCode == 200) {
         final data = json.decode(response.body);
         if (data['result'] == 'ok') { return true; }
       }
       print('Cloudinary deletion failed: ${response.body}'); return false;
     } catch (e) { print('Error deleting file: $e'); return false; }
  }

  /// Retrieves details of resources from Cloudinary. Can use [publicId] or other params.
  /// Note: This likely requires authentication (API Key/Secret) for most uses.
  static Future<Map<String, dynamic>?> getResource(String publicId, {String resourceType = 'image'}) async {
    /* ... (Keep existing getResource implementation, but verify endpoint/auth requirements) ... */
     // WARNING: This endpoint might be incorrect or require authentication not included here.
     final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/resources/$resourceType/upload?public_ids[]=$publicId');
     try {
       final response = await http.get(url); // Attempt without auth first
       if (response.statusCode == 200) {
         final data = json.decode(response.body);
         return data;
       }
       print('Failed to fetch resource details: ${response.statusCode}');
       print('Response body: ${response.body}');
       return null;
     } catch (e) { print('Error fetching resource: $e'); return null; }
  }
}

// Ensure your CloudinaryConfig class/logic correctly provides cloudName, apiKey, apiSecret
// Example:
// class CloudinaryConfig {
//   static Map<String, String> parseCloudinaryUrl() {
//      // Replace with your actual URL parsing or config loading
//      const String cloudinaryUrl = "cloudinary://API_KEY:API_SECRET@CLOUD_NAME";
//      final uri = Uri.parse(cloudinaryUrl);
//      return {
//         'cloudName': uri.host,
//         'apiKey': uri.userInfo.split(':')[0],
//         'apiSecret': uri.userInfo.split(':')[1],
//      };
//   }
// }
