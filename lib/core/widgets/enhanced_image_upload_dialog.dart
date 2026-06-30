import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';
import 'package:poultryos_farmer_app/core/services/media_api_service.dart';
import 'package:poultryos_farmer_app/core/providers/api_client_provider.dart';

class UploadedImage {
  final File file;

  final List<Map<String, dynamic>> tagObjects;
  final List<Map<String, dynamic>> sharedUserObjects;

  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? remarks;

  UploadedImage({
    required this.file,
    this.tagObjects = const [],
    this.sharedUserObjects = const [],
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.remarks,
  });

  List<String> get tagNames =>
      tagObjects.map((e) => e['name'].toString()).toList();

  List<String> get sharedUserNames =>
      sharedUserObjects.map((e) => e['name'].toString()).toList();

  Map<String, dynamic> toJson(String module, String screen) {
    return {
      'module': module,
      'screen': screen,
      'tagObjects': tagObjects,
      'sharedUserObjects': sharedUserObjects,
      'file': file,
      'metadata': {
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'remarks': remarks,
        'sharedUserObjects': sharedUserObjects,
      }
    };
  }
}

class EnhancedImageUploadDialog extends ConsumerStatefulWidget {
  final String title;
  final String module;
  final String screen;
  final bool cameraOnly;
  final int maxFilesPerTag;
  final int maxFileSizeMB;
  final List<UploadedImage> initialImages;

  const EnhancedImageUploadDialog({
    super.key,
    this.title = 'Upload Images',
    required this.module,
    required this.screen,
    this.cameraOnly = false,
    this.maxFilesPerTag = 5,
    this.maxFileSizeMB = 5,
    this.initialImages = const [],
  });

  @override
  ConsumerState<EnhancedImageUploadDialog> createState() =>
      _EnhancedImageUploadDialogState();
}

class _EnhancedImageUploadDialogState
    extends ConsumerState<EnhancedImageUploadDialog> {
  final List<UploadedImage> _images = [];

  final List<Map<String, dynamic>> _selectedTagObjects = [];
  final List<Map<String, dynamic>> _selectedUserObjects = [];
  bool _isCapturing = false;
  final TextEditingController _remarksController = TextEditingController();

  List<String> _availableTags = [];
  List<Map<String, dynamic>> _availableTagObjects = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _images.addAll(widget.initialImages);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch tag objects (with real IDs) from the action master API
      final actionObjects =
          await MediaApiService.fetchActionsByScreenName(widget.screen);
      if (actionObjects.isNotEmpty) {
        if (mounted) {
          setState(() {
            _availableTagObjects = actionObjects;
            _availableTags =
                actionObjects.map((e) => e['name'].toString()).toList();
            _selectedTagObjects.clear();
            if (_availableTags.isNotEmpty) {
              _selectedTagObjects.add(_availableTagObjects.first);
            }
          });
        }
      } else {
        // Fallback to string-only fetch
        final tags = await MediaApiService.fetchTagsByScreenName(widget.screen);
        if (tags.isNotEmpty && mounted) {
          setState(() {
            _availableTags = tags;
            _availableTagObjects =
                tags.map((t) => {'id': 1, 'name': t}).toList();
            _selectedTagObjects.clear();
            if (_availableTags.isNotEmpty) {
              _selectedTagObjects.add(_availableTagObjects.first);
            }
          });
        }
      }

      final response = await ref
          .read(apiClientProvider)
          .get("SQLQueries('GetAllUsersToTag')/List");
      if (response.data != null && response.data['value'] is List) {
        if (mounted) {
          setState(() {
            _availableUsers =
                List<Map<String, dynamic>>.from(response.data['value']);
          });
        }
      }
    } catch (e) {
      debugPrint('[EnhancedImageUploadDialog] fetch error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedTagObjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one tag first')),
      );
      return;
    }

    final currentTagCount = _images
        .where(
            (img) => img.tagObjects.any((t) => _selectedTagObjects.contains(t)))
        .length;
    if (currentTagCount >= widget.maxFilesPerTag) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Maximum ${widget.maxFilesPerTag} images allowed for selected tags')),
      );
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSizeMB = await file.length() / (1024 * 1024);

        if (fileSizeMB > widget.maxFileSizeMB) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'File size exceeds ${widget.maxFileSizeMB}MB limit')),
            );
          }
          return;
        }

        final position = await _getCurrentLocation();

        if (mounted) {
          final List<Map<String, dynamic>> resolvedTagObjects =
              _selectedTagObjects.isNotEmpty
                  ? List<Map<String, dynamic>>.from(_selectedTagObjects)
                  : [];

          setState(() {
            _images.add(UploadedImage(
              file: file,
              tagObjects: resolvedTagObjects,
              sharedUserObjects: List.from(_selectedUserObjects),
              timestamp: DateTime.now(),
              latitude: position?.latitude,
              longitude: position?.longitude,
              remarks: _remarksController.text.isNotEmpty
                  ? _remarksController.text
                  : null,
            ));
            _remarksController.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppTheme.spacing16,
        right: AppTheme.spacing16,
        top: AppTheme.spacing16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radius20)),
      ),
      child: _isLoading
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSize18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryRed,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: AppTheme.spacing12),

                  // Tag Selection (Multi)
                  const Text(
                    'Select Tags (Multi-select)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppTheme.fontSize14),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  DropdownSearch<Map<String, dynamic>>.multiSelection(
                    items: (filter, loadProps) => _availableTagObjects,
                    selectedItems: _selectedTagObjects,
                    itemAsString: (item) => item['name'] as String,
                    compareFn: (item1, item2) => item1['id'] == item2['id'],
                    suffixProps: const DropdownSuffixProps(
                      dropdownButtonProps: DropdownButtonProps(
                        iconClosed: Icon(Icons.arrow_drop_down),
                      ),
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        hintText: "Select tags",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    onSelected: (values) {
                      setState(() {
                        _selectedTagObjects
                          ..clear()
                          ..addAll(values);
                      });
                    },
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // User Sharing (Multi)
                  const Text(
                    'Share with Users (Read-only)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppTheme.fontSize14),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  DropdownSearch<Map<String, dynamic>>.multiSelection(
                    items: (filter, loadProps) => _availableUsers,
                    itemAsString: (u) => u['U_FullNm'] ?? 'Unknown',
                    compareFn: (item1, item2) =>
                        item1['empID'] == item2['empID'],
                    suffixProps: const DropdownSuffixProps(
                      dropdownButtonProps: DropdownButtonProps(
                        iconClosed: Icon(Icons.person_add_alt_1),
                      ),
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        hintText: "Search users to tag",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    onSelected: (values) {
                      setState(() {
                        _selectedUserObjects.clear();
                        _selectedUserObjects.addAll(values.map((v) => {
                              'id': v['empID'],
                              'name': v['U_FullNm'],
                            }));
                      });
                    },
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // Remarks
                  const Text(
                    'Remarks (Optional)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppTheme.fontSize14),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  TextField(
                    controller: _remarksController,
                    decoration: InputDecoration(
                      hintText: 'Add notes for the next capture...',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isCapturing
                              ? null
                              : () => _pickImage(ImageSource.camera),
                          icon: _isCapturing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      if (!widget.cameraOnly) ...[
                        const SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isCapturing
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacing20),

                  // Image Grid
                  if (_images.isNotEmpty) ...[
                    const Text(
                      'Captured Images',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppTheme.fontSize14),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          final img = _images[index];
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.grey300),
                                  image: DecorationImage(
                                    image: FileImage(img.file),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      color: Colors.black54,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Text(
                                        img.tagNames.join(', '),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel,
                                      color: Colors.red, size: 24),
                                  onPressed: () => _removeImage(index),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: AppTheme.spacing24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _images.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context, _images);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'Save ${_images.length} Images',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                ],
              ),
            ),
    );
  }
}
