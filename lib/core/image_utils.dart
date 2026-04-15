import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  static Future<File?> mergeImagesHorizontally(File front, File back) async {
    try {
      final frontBytes = await front.readAsBytes();
      final backBytes = await back.readAsBytes();

      // Run heavy image processing in a background isolate
      final mergedBytes = await compute(_mergeImagesCompute, [frontBytes, backBytes]);

      if (mergedBytes == null) return null;

      final tempDir = await getTemporaryDirectory();
      final mergedPath = '${tempDir.path}/merged_aadhaar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final file = File(mergedPath);
      await file.writeAsBytes(mergedBytes);

      return file;
    } catch (e) {
      debugPrint('Error merging images: $e');
      return null;
    }
  }

  // Pure function for compute()
  static Uint8List? _mergeImagesCompute(List<Uint8List> bytesList) {
    try {
      img.Image? frontImg = img.decodeImage(bytesList[0]);
      img.Image? backImg = img.decodeImage(bytesList[1]);

      if (frontImg == null || backImg == null) return null;

      // PREVENT CRASH: Resize to a reasonable height (e.g. 1000px) 
      // This keeps memory usage low while maintaining high readability
      const int maxHeight = 1000;
      if (frontImg.height > maxHeight || backImg.height > maxHeight) {
        frontImg = img.copyResize(frontImg, height: maxHeight, interpolation: img.Interpolation.linear);
        backImg = img.copyResize(backImg, height: maxHeight, interpolation: img.Interpolation.linear);
      } else {
        // Ensure heights match for horizontal merge
        backImg = img.copyResize(backImg, height: frontImg.height, interpolation: img.Interpolation.linear);
      }

      // Calculate total width and max height
      final mergedWidth = frontImg.width + backImg.width;
      final mergedHeight = frontImg.height;

      // Create a base image
      final merged = img.Image(width: mergedWidth, height: mergedHeight);
      
      // Fill with white background
      img.fill(merged, color: img.ColorRgb8(255, 255, 255));

      // Draw front at (0,0)
      img.compositeImage(merged, frontImg, dstX: 0, dstY: 0);
      
      // Draw back after front
      img.compositeImage(merged, backImg, dstX: frontImg.width, dstY: 0);

      // Encode at 85% quality to save space
      return img.encodeJpg(merged, quality: 85);
    } catch (e) {
      return null;
    }
  }
}
