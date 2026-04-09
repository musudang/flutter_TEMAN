import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressUtil {
  static const int maxFileSize = 1024 * 1024; // 1MB (increased from 500KB for better quality)

  /// Compresses the given image bytes until the size is under [maxFileSize].
  /// Returns the compressed bytes.
  static Future<Uint8List?> compressImage(Uint8List imageBytes, {int minWidth = 1080, int minHeight = 1080}) async {
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
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      // Fallback in case compression fails
      return imageBytes;
    }

    // Iteratively lower quality until file size is under the limit
    // We use a less aggressive step (10 instead of 15) to preserve quality
    while (compressed.lengthInBytes > maxFileSize && quality > 20) {
      quality -= 10;
      try {
        compressed = await FlutterImageCompress.compressWithList(
          imageBytes, // compress from original to avoid compounding artifacts
          minWidth: minWidth,
          minHeight: minHeight,
          quality: quality,
          format: CompressFormat.jpeg,
        );
      } catch (_) {
        break;
      }
    }

    return compressed;
  }
}
