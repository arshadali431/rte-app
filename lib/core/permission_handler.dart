import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  AppPermissions._();

  /// Request camera permission
  static Future<bool> requestCamera() async {
    if (Platform.isIOS) {
      final status = await Permission.camera.request();
      return status.isGranted;
    }
    // Android handles via manifest for lower APIs, but still good to request
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request photo/storage permission
  static Future<bool> requestPhotos() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    
    // For Android, handle differently based on version
    if (Platform.isAndroid) {
      // Permission.photos is for Android 13+ (API 33+)
      final photoStatus = await Permission.photos.request();
      if (photoStatus.isGranted) return true;
      
      // Fallback for older Android versions
      return await Permission.storage.request().isGranted;
    }
    
    return false;
  }

  /// Show settings dialog if permanently denied
  static Future<void> showSettingsDialog([BuildContext? context]) async {
    await openAppSettings();
  }
}
