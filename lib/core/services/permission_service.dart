// lib/core/services/permission_service.dart

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request only required permissions
  /// Modern Android does NOT require storage/media permissions
  /// for ImagePicker/FilePicker usage.
  static Future<bool> requestFileUploadPermissions() async {
    debugPrint('🔐 Requesting file upload permissions...');

    try {
      // Non-Android platforms
      if (!Platform.isAndroid) {
        debugPrint('✅ Non-Android platform');
        return true;
      }

      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      debugPrint('📱 Android SDK: $sdkInt');

      final results = await [
        Permission.camera,
        Permission.locationWhenInUse,
      ].request();

      debugPrint('📋 Permission results: $results');

      final cameraGranted = results[Permission.camera]?.isGranted ?? false;

      if (!cameraGranted) {
        debugPrint('❌ Camera permission denied');
        return false;
      }

      debugPrint('✅ Required permissions granted');
      return true;
    } catch (e) {
      debugPrint('❌ Permission request error: $e');
      return false;
    }
  }

  /// Camera only
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();

    debugPrint(
      status.isGranted
          ? '✅ Camera permission granted'
          : '❌ Camera permission denied',
    );

    return status.isGranted;
  }

  /// Check permissions
  static Future<bool> hasFileUploadPermissions() async {
    try {
      if (!Platform.isAndroid) return true;

      return await Permission.camera.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Open settings
  static Future<void> launchAppSettings() async {
    await openAppSettings();
  }
}
