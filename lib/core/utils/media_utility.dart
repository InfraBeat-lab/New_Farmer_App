import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';

class MediaUtility {
  static final ImagePicker _picker = ImagePicker();

  /// Captures an image with the camera and applies a watermark with metadata.
  static Future<File?> captureAndWatermark({
    required String screenName,
    String? transactionId,
    Map<String, String>? additionalData,
  }) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo == null) return null;

      // Get metadata for watermark
      Position? position;
      try {
        position = await _getCurrentLocation();
      } catch (e) {
        debugPrint('MediaUtility: Could not get location for watermark: $e');
      }

      final username = LocalStorageService.getString('supervisorName') ??
          LocalStorageService.getString('supervisorName') ??
          'User';
      final timestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Build watermark lines
      final List<String> watermarkLines = [
        'Screen: $screenName',
        if (transactionId != null && transactionId.isNotEmpty)
          'ID: $transactionId',
        'User: $username',
        'Time: $timestamp',
      ];

      if (position != null) {
        watermarkLines.add('Lat: ${position.latitude.toStringAsFixed(6)}');
        watermarkLines.add('Lng: ${position.longitude.toStringAsFixed(6)}');
      }

      if (additionalData != null) {
        additionalData.forEach((key, value) {
          watermarkLines.add('$key: $value');
        });
      }

      final String watermarkText = watermarkLines.join('\n');

      // Apply watermark using dart:ui
      final bytes = await File(photo.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..filterQuality = FilterQuality.high;

      // Draw original image
      canvas.drawImage(image, Offset.zero, paint);

      // Configure text painter
      final fontSize = (image.height / 35).clamp(14.0, 40.0);
      final tp = TextPainter(
        text: TextSpan(
          text: watermarkText,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );

      tp.layout(maxWidth: image.width.toDouble() - 40);

      // Draw a semi-transparent dark background for better text readability
      final margin = 20.0;
      final padding = 12.0;
      final bgRect = Rect.fromLTWH(
        margin - padding,
        image.height - tp.height - margin - padding,
        tp.width + (padding * 2),
        tp.height + (padding * 2),
      );

      final bgPaint = Paint()..color = Colors.black.withOpacity(0.4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
        bgPaint,
      );

      // Paint the text
      tp.paint(canvas, Offset(margin, image.height - tp.height - margin));

      // Export to file
      final picture = recorder.endRecording();
      final watermarkedUiImage =
          await picture.toImage(image.width, image.height);
      final byteData =
          await watermarkedUiImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();

      // Compress to JPEG to reduce file size (PNG is too large for server limits)
      final compressedBytes = await FlutterImageCompress.compressWithList(
        pngBytes,
        minWidth: 1080,
        minHeight: 1080,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      final tempDir = await getTemporaryDirectory();
      final String fileName = 'WM_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final watermarkedFile = File('${tempDir.path}/$fileName');
      await watermarkedFile.writeAsBytes(compressedBytes);

      // Cleanup original temp file
      try {
        await File(photo.path).delete();
      } catch (_) {}

      final finalSize = await watermarkedFile.length();
      debugPrint(
          'MediaUtility: Image compressed. Original PNG size estimation: ${pngBytes.length} bytes, Final JPEG size: $finalSize bytes');

      return watermarkedFile;
    } catch (e) {
      debugPrint('MediaUtility: Error capturing photo: $e');
      return null;
    }
  }

  /// Compresses a file and returns a new File object
  static Future<File> compressFile(File file, {int quality = 80}) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.png|.jp'));
    final splitted = filePath.substring(0, (lastIndex));
    final outPath = "${splitted}_out.jpg";

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: quality,
      minWidth: 1080,
      minHeight: 1080,
    );

    return File(result!.path);
  }

  static Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (_) {
      return null;
    }
  }

  /// Generates initials from a string (e.g., "Setter Daily Transaction" -> "SDT")
  static String getInitials(String name) {
    if (name.isEmpty) return '';

    // Special common mappings
    final Map<String, String> specials = {
      'Setter Daily Transaction': 'SDT',
      'Hatcher Daily Transaction': 'HDT',
      'Chicks Pull Out': 'CPO',
      'Eggs Collection': 'EC',
      'Flock Placement': 'FP',
      'Daily Transaction': 'DT',
      'Mortality': 'MT',
      'Culls': 'CL',
      'Female Mortality': 'FM',
      'Female Culls': 'FC',
      'Male Mortality': 'MM',
      'Male Culls': 'MC',
      'Others': 'OT',
    };

    if (specials.containsKey(name)) return specials[name]!;
    if (specials.containsKey(name.trim())) return specials[name.trim()]!;

    return name
        .trim()
        .split(RegExp(r'[\s\_]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join('');
  }

  /// Creates a standardized upload payload matching the POS ERP media API contract.
  ///
  /// **Server-side field mapping:**
  /// - `module`   → `{id, refname}` — `refname` is used for overlay text
  /// - `shed`     → `{id, shedname}` — `shedname` used for overlay & DB
  /// - `batch`    → `{id, batchname}` — `batchname` used for overlay & DB
  /// - `action`   → `[{id, name}]` — action IDs are stored as tagged_actions
  /// - `metadata` → full object with geo, assignedUsers, SAP codes, etc.
  ///
  /// [moduleId]      — numeric ID of the module (e.g. 731 for Breeder)
  /// [moduleRefName] — display name shown in the media overlay
  /// [screenName]    — screen label (e.g. 'Daily Transaction')
  /// [shedId]        — numeric shed ID from the server/SAP
  /// [shedName]      — shed display name
  /// [batchId]       — numeric batch ID from the server/SAP
  /// [batchName]     — batch display name (flock name, setter no, etc.)
  /// [actionInfo]    — list of `{id, name}` action objects
  /// [assignedUsers] — list of `{id, name}` user objects for tagged_users
  /// [gpsLocation]   — device GPS position (optional)
  /// [sequence]      — photo sequence number within a transaction
  /// [transactionId] — SAP doc entry or vehicle number
  /// [remark]        — optional free-text remark
  /// [dataSource]    — defaults to 'SAP'
  /// [branchId]      — optional branch ID for CBF
  /// [farmerId]      — optional farmer ID for KYC
  /// [sapShedCode]   — SAP shed code for cross-referencing
  /// [sapBatchCode]  — SAP batch code
  /// [sapFarmerCode] — SAP farmer code
  static Map<String, dynamic> createUploadPayload({
    // Module
    required int moduleId,
    required String moduleRefName,
    // Screen
    required String screenName,
    // Actions
    required List<Map<String, dynamic>> actionInfo,
    required List<Map<String, dynamic>>? assignedUsers,
    Position? gpsLocation,
    int sequence = 1,
    String? transactionId,
    String? remark,
    String dataSource = 'SAP',
    String? sapShedCode,
    String? sapBatchCode,
    String? sapFarmerCode,
    Map<String, dynamic>? extraMetadata,
  }) {
    final companyId = LocalStorageService.getInt('company_id') ??
        LocalStorageService.getInt('companyId') ??
        42;
    final capturedById = LocalStorageService.getInt('user_id') ??
        LocalStorageService.getInt('userId') ??
        0;
    final capturedByName = LocalStorageService.getString('supervisorName') ??
        LocalStorageService.getString('login_username') ??
        'Unknown';

    // Screen ID Mapping
    final Map<String, int> screenIds = {
      'Daily Transaction': 1,
      'Egg Collection': 2,
      'Setter Daily Transaction': 3,
      'Hatcher Daily Transaction': 4,
      'Chicks Pull Out': 5,
      'Flock Placement': 6,
      'Daily Start/End': 7,
      'Farmer KYC': 8,
      'CBF Daily Transaction': 9,
    };
    final screenId = screenIds[screenName] ?? 1;

    // --- module JSON: server uses moduleObj.refname for overlay ---
    final moduleJson = json.encode({
      'id': moduleId,
      'refname': moduleRefName,
    });

    // --- action JSON: server maps a.id for tagged_actions ---
    final actionJson = json.encode(actionInfo);

    // --- screen JSON ---
    final screenJson = json.encode({'id': screenId, 'name': screenName});

    // --- metadata JSON ---
    final metadataMap = <String, dynamic>{
      'capturedById': capturedById,
      'capturedBy': capturedByName,
      'sequence': sequence,
      'dataSource': dataSource,
      'transactionId': transactionId,
      'assignedUsers': assignedUsers ?? [],
      'remark': remark ?? '',
      'geo': gpsLocation != null
          ? {'lat': gpsLocation.latitude, 'lng': gpsLocation.longitude}
          : {'lat': null, 'lng': null},
      if (sapShedCode != null) 'sapShedCode': sapShedCode,
      if (sapBatchCode != null) 'sapBatchCode': sapBatchCode,
      if (sapFarmerCode != null) 'sapFarmerCode': sapFarmerCode,
      if (extraMetadata != null) ...extraMetadata,
    };

    return {
      'companyid': companyId,
      'module': moduleJson,
      'screen': screenJson,
      'action': actionJson,
      'metadata': json.encode(metadataMap),
    };
  }

  /// Generates a standardized file name for uploads
  static String getUploadFileName({
    required String screenName,
    required String subTypeName,
    required String transactionId,
    required int sequence,
  }) {
    final screenInitials = getInitials(screenName);
    final subTypeInitials =
        subTypeName.isEmpty ? screenInitials : getInitials(subTypeName);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    return '${screenInitials}_${subTypeInitials}_${transactionId}_${timestamp}_$sequence.jpg';
  }
}
