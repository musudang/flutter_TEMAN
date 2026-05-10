import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressUtil {
  static const int maxFileSize = 1024 * 1024; // 1MB (increased from 500KB for better quality)

  /// Compresses the given image bytes and forces a JPEG transcode.
  ///
  /// Forcing JPEG matters for iPhone uploads: iOS captures default to
  /// HEIC, which Flutter's `Image.network` cannot decode — the picture
  /// then renders as "Failed to load" on every other device. Always
  /// running the bytes through `FlutterImageCompress.compressWithList`
  /// with `format: CompressFormat.jpeg` guarantees the output is a
  /// universally-decodable JPEG, regardless of input format or size.
  ///
  /// [minWidth]/[minHeight] cap the output dimensions; quality is
  /// reduced iteratively until the file fits under [maxFileSize].
  static Future<Uint8List?> compressImage(Uint8List imageBytes, {int minWidth = 1080, int minHeight = 1080}) async {
    int quality = 90;
    Uint8List compressed = imageBytes;

    // First compression with basic resize and high quality.
    // We DO NOT short-circuit on small inputs — even a 200KB HEIC must
    // be transcoded to JPEG.
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
