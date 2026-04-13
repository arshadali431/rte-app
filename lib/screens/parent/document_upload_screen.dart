import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/document_model.dart';
import '../../core/constants.dart';
import '../../core/permission_handler.dart';
import '../../widgets/no_internet_banner.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  String? _tokenId;
  List<DocumentModel> _uploadedDocs = [];
  bool _isLoading = true;
  String? _uploadingType;
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _tokenId = prefs.getString('token_id');

      if (_tokenId != null) {
        final docs = await FirestoreService().getDocuments(_tokenId!);
        if (mounted) {
          setState(() {
            _uploadedDocs = docs;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUpload(String docType) async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF00796B),
              ),
              title: Text(
                'Take Photo',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Color(0xFF00796B),
              ),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    // Check permissions
    bool granted = false;
    if (source == ImageSource.camera) {
      granted = await AppPermissions.requestCamera();
    } else {
      granted = await AppPermissions.requestPhotos();
    }

    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Permission denied. Please enable in Settings.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => AppPermissions.showSettingsDialog(),
            ),
          ),
        );
      }
      return;
    }

    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Document',
          toolbarColor: const Color(0xFF00796B),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF00796B),
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
          ],
        ),
        IOSUiSettings(
          title: 'Crop Document',
          aspectRatioLockEnabled: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
          ],
        ),
      ],
    );

    if (croppedFile == null) return;

    setState(() => _uploadingType = docType);

    try {
      final downloadUrl = await StorageService().uploadDocument(
        _tokenId!,
        docType,
        File(croppedFile.path),
      );

      if (downloadUrl != null) {
        final docModel = DocumentModel(
          docType: docType,
          fileName: pickedFile.name,
          storagePath: downloadUrl,
          uploadedAt: DateTime.now(),
        );

        await FirestoreService().addDocument(_tokenId!, docModel);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Please check file size or signal.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  void _viewDocument(DocumentModel doc) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppConstants.docTypeNames[doc.docType] ?? doc.docType,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Image with Caching
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: doc.storagePath,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: Color(0xFF00796B),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDelete(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Document?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this document? You can upload a new one after deleting.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingIds.add(doc.id!));

    try {
      await StorageService().deleteFile(doc.storagePath);
      await FirestoreService().deleteDocument(_tokenId!, doc.id!);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(doc.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    int mandatoryUploaded = _uploadedDocs
        .where((d) => AppConstants.mandatoryDocTypes.contains(d.docType))
        .length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Document Vault',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          const NoInternetBanner(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00796B)),
                  )
          : Scrollbar(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildProgressHeader(mandatoryUploaded),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            'REQUIRED DOCUMENTS',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.redAccent,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const CircleAvatar(
                            radius: 3,
                            backgroundColor: Colors.redAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final type = AppConstants.mandatoryDocTypes[index];
                      final existing = _uploadedDocs.firstWhere(
                        (d) => d.docType == type,
                        orElse: () => DocumentModel(
                          id: '',
                          docType: '',
                          fileName: '',
                          storagePath: '',
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildDocCard(
                          type,
                          existing.storagePath.isNotEmpty ? existing : null,
                          isMandatory: true,
                        ),
                      );
                    }, childCount: AppConstants.mandatoryDocTypes.length),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                      child: Text(
                        'OPTIONAL DOCUMENTS',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueGrey[600],
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final type = AppConstants.optionalDocTypes[index];
                      final existing = _uploadedDocs.firstWhere(
                        (d) => d.docType == type,
                        orElse: () => DocumentModel(
                          id: '',
                          docType: '',
                          fileName: '',
                          storagePath: '',
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildDocCard(
                          type,
                          existing.storagePath.isNotEmpty ? existing : null,
                          isMandatory: false,
                        ),
                      );
                    }, childCount: AppConstants.optionalDocTypes.length),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader(int count) {
    int totalMandatory = AppConstants.mandatoryDocTypes.length;
    double progress = count / totalMandatory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count of $totalMandatory Required',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF00796B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[100],
              color: const Color(0xFF00796B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete mandatory uploads to finalize your application',
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(
    String type,
    DocumentModel? doc, {
    required bool isMandatory,
  }) {
    final isUploading = _uploadingType == type;
    final isDeleting = doc != null && _deletingIds.contains(doc.id!);
    final String label = AppConstants.docTypeNames[type] ?? type;
    final IconData icon =
        AppConstants.docTypeIcons[type] ?? Icons.description_outlined;

    Color leftBorderColor = Colors.grey[300]!;
    if (doc != null) {
      leftBorderColor = Colors.green;
    } else if (isMandatory) {
      leftBorderColor = Colors.redAccent.withOpacity(0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: (isUploading || isDeleting || doc != null)
            ? null
            : () => _pickAndUpload(type),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: leftBorderColor, width: 4)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: doc != null ? Colors.green[50] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: doc != null ? Colors.green : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (doc != null)
                          Text(
                            'Uploaded ${DateFormat('dd MMM, yyyy').format(doc.uploadedAt ?? DateTime.now())}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          )
                        else
                          Row(
                            children: [
                              _buildCardStatusChip(
                                isMandatory ? 'REQUIRED' : 'OPTIONAL',
                                isMandatory
                                    ? Colors.redAccent
                                    : Colors.grey[600]!,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (doc != null)
                    const SizedBox.shrink()
                  else if (isUploading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00796B),
                      ),
                    )
                  else
                    const Icon(
                      Icons.add_a_photo_outlined,
                      color: Color(0xFF00796B),
                      size: 24,
                    ),
                ],
              ),
              if (isUploading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: Color(0xFF00796B),
                ),
                const SizedBox(height: 4),
                Text(
                  'Compressing & Uploading...',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: const Color(0xFF00796B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (doc != null && !isDeleting) ...[
                const Divider(height: 20, thickness: 0.5),
                Row(
                  children: [
                    // VIEW button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewDocument(doc),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: Text(
                          'View',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00796B),
                          side: const BorderSide(
                            color: Color(0xFF00796B),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // DELETE button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleDelete(doc),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        label: Text(
                          'Delete',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (isDeleting) ...[
                const Divider(height: 20, thickness: 0.5),
                const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
