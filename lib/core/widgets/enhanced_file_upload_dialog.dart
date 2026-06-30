import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

class EnhancedFileUploadDialog extends StatefulWidget {
  final List<String> predefinedTags;
  final List<Map<String, dynamic>> availableUsers;
  final String title;

  const EnhancedFileUploadDialog({
    super.key,
    this.predefinedTags = const [
      'Mortality',
      'Inspection',
      'Invoice',
      'Health Report',
      'Farmer ID',
      'Address Proof',
      'Agreement'
    ],
    required this.availableUsers,
    this.title = 'Upload Document',
  });

  @override
  State<EnhancedFileUploadDialog> createState() =>
      _EnhancedFileUploadDialogState();
}

class _EnhancedFileUploadDialogState extends State<EnhancedFileUploadDialog> {
  File? _selectedFile;
  String? _fileType;
  final List<String> _selectedTags = [];
  final List<String> _selectedUsers = [];
  final TextEditingController _remarksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _pickFile(bool isImage, {bool fromCamera = false}) async {
    if (isImage) {
      final picker = ImagePicker();
      final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 70);

      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _fileType = 'image';
        });
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          final ext = result.files.single.extension?.toLowerCase() ?? '';
          _fileType = ext == 'pdf' ? 'pdf' : 'doc';
        });
      }
    }
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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

              // File Selection Area
              if (_selectedFile == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPickerOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () => _pickFile(true, fromCamera: true),
                    ),
                    _buildPickerOption(
                      icon: Icons.image,
                      label: 'Gallery',
                      onTap: () => _pickFile(true),
                    ),
                    _buildPickerOption(
                      icon: Icons.picture_as_pdf,
                      label: 'PDF/Docs',
                      onTap: () => _pickFile(false),
                    ),
                  ],
                )
              else
                _buildFilePreview(),

              const SizedBox(height: AppTheme.spacing20),

              // Tags Selection
              const Text(
                'Custom Tags (Multi-select)',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize14),
              ),
              const SizedBox(height: AppTheme.spacing8),
              DropdownSearch<String>.multiSelection(
                items: (filter, loadProps) => widget.predefinedTags,
                suffixProps: const DropdownSuffixProps(
                  dropdownButtonProps: DropdownButtonProps(
                    iconClosed: Icon(Icons.arrow_drop_down),
                  ),
                ),
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(
                    hintText: "Select tags",
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                onSelected: (values) {
                  setState(() {
                    _selectedTags.clear();
                    _selectedTags.addAll(values);
                  });
                },
              ),

              const SizedBox(height: AppTheme.spacing20),

              // User Sharing
              const Text(
                'Share with Users (Read-only)',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize14),
              ),
              const SizedBox(height: AppTheme.spacing8),
              DropdownSearch<Map<String, dynamic>>.multiSelection(
                items: (filter, loadProps) => widget.availableUsers,
                itemAsString: (u) =>
                    u['U_FullNm'] ?? u['U_FullNm'] ?? 'Unknown',
                suffixProps: const DropdownSuffixProps(
                  dropdownButtonProps: DropdownButtonProps(
                    iconClosed: Icon(Icons.person_add_alt_1),
                  ),
                ),
                compareFn: (item1, item2) => item1['empID'] == item2['empID'],
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(
                    hintText: "Search users to tag",
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                onSelected: (values) {
                  setState(() {
                    _selectedUsers.clear();
                    _selectedUsers.addAll(values.map((v) =>
                        (v['U_FullNm'] ?? v['U_FullNm'] ?? '').toString()));
                  });
                },
              ),

              const SizedBox(height: AppTheme.spacing20),

              // Remarks
              const Text(
                'Remarks / Notes',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize14),
              ),
              const SizedBox(height: AppTheme.spacing8),
              TextFormField(
                controller: _remarksController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter description or remarks...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedFile == null ? null : _handleUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Upload & Attach',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppTheme.primaryRed),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Row(
        children: [
          if (_fileType == 'image')
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_selectedFile!,
                  width: 60, height: 60, fit: BoxFit.cover),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _fileType == 'pdf' ? Icons.picture_as_pdf : Icons.description,
                color: _fileType == 'pdf' ? Colors.red : Colors.blue,
                size: 32,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFile!.path.split(Platform.pathSeparator).last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(_selectedFile!.lengthSync() / 1024).toStringAsFixed(2)} KB',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _selectedFile = null;
              _fileType = null;
            }),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  void _handleUpload() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'file': _selectedFile,
        'fileType': _fileType,
        'tags': _selectedTags,
        'sharedUsers': _selectedUsers,
        'remarks': _remarksController.text,
      });
    }
  }
}
