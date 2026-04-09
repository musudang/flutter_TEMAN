import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressUtil {
  static const int maxFileSize = 500 * 1024; // 500KB

  /// Compresses the given image bytes until the size is under [maxFileSize].
  /// Returns the compressed bytes.
  static Future<Uint8List?> compressImage(Uint8List imageBytes, {int minWidth = 800, int minHeight = 800}) async {
    if (imageBytes.lengthInBytes <= maxFileSize) {
      return imageBytes;
    }

    int quality = 90;
    Uint8List compressed = imageBytes;
    
    // First compression with basic resize and high quality
    try {
      compressed = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
      );
    } catch (_) {
      // Fallback in case compression fails
      return imageBytes;
    }

    // Iteratively lower quality until file size is under the limit
    while (compressed.lengthInBytes > maxFileSize && quality > 10) {
      quality -= 15;
      try {
        compressed = await FlutterImageCompress.compressWithList(
          imageBytes, // compress from original to avoid compounding artifacts
          minWidth: minWidth,
          minHeight: minHeight,
          quality: quality,
        );
      } catch (_) {
        break;
      }
    }

    return compressed;
  }
}
