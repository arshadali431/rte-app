import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Future<String?> uploadDocument(String tokenId, String docType, File file) async {
    try {
      // Step 1: Compress image to below 400KB
      Uint8List? compressed;
      int quality = 88;
      
      // Try compressing with decreasing quality until under 400KB
      while (quality >= 30) {
        compressed = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          quality: quality,
          minWidth: 1024,
          minHeight: 1024,
          keepExif: false,
        );
        
        if (compressed == null) break;
        
        // Check if under 400KB (400 * 1024 bytes)
        if (compressed.lengthInBytes <= 400 * 1024) break;
        
        quality -= 10; // reduce quality and try again
      }
      
      if (compressed == null) throw Exception("Compression failed");
      
      // Step 2: Save compressed bytes to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${docType}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressed);
      
      // Step 3: Upload to Firebase Storage
      final fileName = '${docType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('tokens/$tokenId/$fileName');
      
      await storageRef.putFile(tempFile);
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Step 4: Clean up temp file
      await tempFile.delete();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }
}
