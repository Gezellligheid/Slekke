import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

// Images are resized (max 1280px), compressed to JPEG, then stored inline in
// Firestore message documents as base64 data URLs. No storage service needed.
class StorageService {
  static const _maxDimension = 1280;
  static const _jpegQuality = 82;

  Future<String> uploadMessageImage({
    required String channelId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final compressed = await _resizeAndCompress(bytes);
    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }

  Future<String> uploadProfilePicture({
    required String uid,
    required Uint8List bytes,
    required String extension,
  }) async {
    final compressed = await _resizeAndCompress(bytes, maxDim: 400);
    if (compressed.length > 700 * 1024) {
      throw Exception(
        'Profile picture still too large after compression '
        '(${(compressed.length / 1024).round()} KB, max 700 KB). '
        'Please choose a simpler image.',
      );
    }
    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }

  Future<void> deleteFile(String url) async {}

  static Future<Uint8List> _resizeAndCompress(
    Uint8List bytes, {
    int maxDim = _maxDimension,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    img.Image resized;
    if (decoded.width > maxDim || decoded.height > maxDim) {
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxDim)
          : img.copyResize(decoded, height: maxDim);
    } else {
      resized = decoded;
    }

    return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
  }

}
