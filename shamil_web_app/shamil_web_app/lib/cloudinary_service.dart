// cloudinary_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shamil_web_app/secrets/cloudinary_config.dart';

class CloudinaryService {
  static final _config = CloudinaryConfig.parseCloudinaryUrl();
  static final String cloudName = _config['cloudName']!;
  // For unsigned uploads, you still need to create an upload preset in your Cloudinary dashboard.
  // Replace the following with your actual unsigned upload preset.
  static const String uploadPreset = 'ml_default';
  static final String apiKey = _config['apiKey']!;
  static final String apiSecret = _config['apiSecret']!;

  /// Uploads a file to Cloudinary.
  /// Optionally, specify a [folder] to organize uploads.
  static Future<String?> uploadFile(File file, {String folder = ''}) async {
    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      if (folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        // Returns the secure URL of the uploaded file.
        return jsonData['secure_url'];
      } else {
        print('Cloudinary upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  /// Deletes a file from Cloudinary using its [publicId].
  /// **WARNING:** Generating a signature on the client is insecure.
  /// Use this function for demonstration purposes only.
  static Future<bool> deleteFile(String publicId,
      {String resourceType = 'image'}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Build the string to sign: "public_id=PUBLIC_ID&timestamp=TIMESTAMP{API_SECRET}"
    final stringToSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
    final signature = sha1.convert(utf8.encode(stringToSign)).toString();
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy');

    try {
      final response = await http.post(url, body: {
        'public_id': publicId,
        'timestamp': '$timestamp',
        'api_key': apiKey,
        'signature': signature,
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'ok') {
          return true;
        }
      }
      print('Cloudinary deletion failed: ${response.body}');
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// Retrieves details of a resource from Cloudinary using its [publicId].
  /// Note: This uses the public API endpoint. For administrative tasks, consider
  /// performing such actions on your secure backend.
  static Future<Map<String, dynamic>?> getResource(String publicId,
      {String resourceType = 'image'}) async {
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/resources/image/upload?public_ids[]=$publicId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      }
      print('Failed to fetch resource details: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error fetching resource: $e');
      return null;
    }
  }
}
