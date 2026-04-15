import 'dart:convert';
import 'dart:io';
import '../../core/image_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/rte_service.dart';
import '../../models/token_model.dart';
import '../../models/child_model.dart';
import '../../models/document_model.dart';
import '../../core/utils.dart';
import '../../core/constants.dart';
import '../../core/permission_handler.dart';
import '../../widgets/no_internet_banner.dart';

class TokenDetailScreen extends StatefulWidget {
  final TokenModel token;

  const TokenDetailScreen({
    super.key,
    required this.token,
  });

  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen> {
  late TokenModel _token;
  List<ChildModel> _children = [];
  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  String? _uploadingType;
  bool _isProcessing = false;
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirestoreService().getChildren(_token.id),
        FirestoreService().getDocuments(_token.id),
      ]);
      
      if (mounted) {
        setState(() {
          _children = results[0] as List<ChildModel>;
          _documents = results[1] as List<DocumentModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading details')),
        );
      }
    }
  }

  Future<void> _pickAndUpload(String docType) async {
    if (_checkIfAadhaar(docType)) {
      final type = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A3535),
          title: Text('Aadhaar Type', style: GoogleFonts.outfit(color: Colors.white)),
          content: Text('Is this a small card-size Aadhaar or a full-page Aadhaar?', style: GoogleFonts.outfit(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'full'), child: Text('Full Page', style: GoogleFonts.outfit(color: Color(0xFF81D4FA)))),
            TextButton(onPressed: () => Navigator.pop(context, 'card'), child: Text('Card Size', style: GoogleFonts.outfit(color: Color(0xFF81D4FA)))),
          ],
        ),
      );
      if (type == 'card') {
        _pickMergeAndUpload(docType);
        return;
      }
    }

    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00796B)),
              title: Text('Take Photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF00796B)),
              title: Text('Choose from Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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
            content: const Text('Permission denied. Please enable in Settings.'),
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
        ),
        IOSUiSettings(title: 'Crop Document'),
      ],
    );

    if (croppedFile == null) return;

    setState(() => _uploadingType = docType);

    try {
      final downloadUrl = await StorageService().uploadDocument(
        _token.id, docType, File(croppedFile.path));

      if (downloadUrl != null) {
        final docModel = DocumentModel(
          docType: docType,
          fileName: pickedFile.name,
          storagePath: downloadUrl,
          uploadedAt: DateTime.now(),
        );
        await FirestoreService().addDocument(_token.id, docModel);
        
        final docs = await FirestoreService().getDocuments(_token.id);
        if (mounted) setState(() => _documents = docs);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Document uploaded successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Upload failed. Please try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  bool _checkIfAadhaar(String type) {
    final t = type.toLowerCase();
    return t.contains('aadhaar') || t.contains('adhar') || t.contains('aadhar');
  }

  Future<File?> _pickAndCropImage(String side) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text('Select $side Image', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF00796B))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00796B)),
              title: Text('Take Photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF00796B)),
              title: Text('Choose from Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return null;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop $side Side',
          toolbarColor: const Color(0xFF00796B),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop $side Side'),
      ],
    );

    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _pickMergeAndUpload(String docType) async {
    // 1. Pick & Crop Front
    final frontFile = await _pickAndCropImage('FRONT');
    if (frontFile == null) return;

    // 2. Pick & Crop Back
    final backFile = await _pickAndCropImage('BACK');
    if (backFile == null) return;

    setState(() {
      _isProcessing = true;
      _uploadingType = null; // Clear inline loader
    });
    
    try {
      // 3. Merge
      final mergedFile = await ImageUtils.mergeImagesHorizontally(frontFile, backFile);
      
      setState(() => _isProcessing = false);
      
      if (mergedFile == null) throw 'Merge failed';

      // 4. Preview
      if (!mounted) return;
      
      final bool? confirmUpload = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Text('Aadhaar Preview', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context, false),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('UPLOAD', 
                    style: GoogleFonts.outfit(color: const Color(0xFF81D4FA), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InteractiveViewer(
                      maxScale: 5.0,
                      child: Image.file(mergedFile, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Confirm that the front and back of the Aadhaar card are correctly joined and clearly legible.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: Text('Looks Good, Upload Now', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81D4FA),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (confirmUpload != true) return;

      // 5. Final Upload
      setState(() => _uploadingType = docType);
      final downloadUrl = await StorageService().uploadDocument(_token.id, docType, mergedFile);
      if (downloadUrl != null) {
        final docModel = DocumentModel(
          docType: docType,
          fileName: 'merged_aadhaar.jpg',
          storagePath: downloadUrl,
          uploadedAt: DateTime.now(),
        );
        await FirestoreService().addDocument(_token.id, docModel);
        final docs = await FirestoreService().getDocuments(_token.id);
        if (mounted) {
          setState(() {
            _documents = docs;
            _uploadingType = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Merged Aadhaar uploaded successfully', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingType = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _handleDelete(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Document?',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this document?',
          style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
              style: GoogleFonts.outfit(color: Colors.redAccent,
              fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingIds.add(doc.id!));

    try {
      await StorageService().deleteFile(doc.storagePath);
      await FirestoreService().deleteDocument(_token.id, doc.id!);

      final docs = await FirestoreService().getDocuments(_token.id);
      if (mounted) setState(() => _documents = docs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Document deleted successfully', style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete. Please try again.', style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(doc.id!));
    }
  }

  void _viewDocument(DocumentModel doc) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black54,
              elevation: 0,
              title: Text(_formatDocType(doc.docType), style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Flexible(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InteractiveViewer(
                  maxScale: 5.0,
                  child: CachedNetworkImage(
                    imageUrl: doc.storagePath,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: Color(0xFF00796B)),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                          const SizedBox(height: 12),
                          Text('Failed to load image', style: GoogleFonts.outfit(color: Colors.black54)),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF0D2B2B),
          appBar: AppBar(
            title: Text('Token #${_token.tokenNumber}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (_token.govStatus == 'ERROR' || (_token.govStatusMessage?.contains('No status information found') ?? false))
                IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  tooltip: 'Delete Token',
                  onPressed: _confirmDeleteToken,
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              const NoInternetBanner(),
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0D2B2B),
                        Color(0xFF004D40),
                        Color(0xFF00796B),
                      ],
                    ),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF81D4FA)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildParentSection(),
                              const SizedBox(height: 24),
                              if (_token.applicationId != null) ...[
                                _buildRegisteredIdCard(),
                                const SizedBox(height: 24),
                                _buildGovStatusSection(),
                                const SizedBox(height: 24),
                              ],
                              if (_token.applicationHistory.isNotEmpty) ...[
                                _buildHistorySection(),
                                const SizedBox(height: 24),
                              ],
                              _buildStatusUpdateSection(),
                              const SizedBox(height: 24),
                              _buildChildrenSection(),
                              const SizedBox(height: 24),
                              _buildDocumentsManager(),
                              const SizedBox(height: 24),
                              _buildQrSection(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                width: 220,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: Color(0xFF00796B),
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Wait for Processing',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Joining Aadhaar Sides...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRegisteredIdCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF00796B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00796B).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF81D4FA), size: 20),
                  const SizedBox(width: 8),
                  Text('RTE REGISTERED ID', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
                ],
              ),
              if (_token.applicationHistory.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81D4FA).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Attempt #${_token.applicationHistory.length + 1}',
                    style: GoogleFonts.outfit(color: const Color(0xFF81D4FA), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _token.applicationId!,
                      style: GoogleFonts.outfit(color: const Color(0xFF81D4FA), fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Child DOB: ${_token.childDob}',
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showInProgressDialog,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Re-submit', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Application History'),
        ...(_token.applicationHistory.reversed).map((entry) {
          final DateTime? date = (entry['updatedAt'] as Timestamp?)?.toDate();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3535).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${entry['attempt']}',
                    style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['id'] ?? 'Unknown ID',
                        style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Status: ${entry['status'] ?? 'N/A'} • DOB: ${entry['dob'] ?? 'N/A'}',
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('dd MMM').format(date),
                    style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color ?? Colors.white38,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildParentSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3535),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Token #${_token.tokenNumber}',
                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF81D4FA)),
              ),
              _buildStatusChip(_token.status),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person_outline_rounded, _token.parentName, fontSize: 18, isBold: true),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.phone_iphone_rounded, _token.parentMobile),
          const Divider(height: 32, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Created: ${DateFormat('dd MMM yyyy').format(_token.createdAt ?? DateTime.now())}',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
              ),
              Text(
                'Staff UID: ${_token.createdBy.substring(0, 5)}...',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUpdateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Update Status'),
        Row(
          children: [
            _buildStatusButton('pending', 'Pending'),
            const SizedBox(width: 8),
            _buildStatusButton('in_progress', 'In Progress'),
            const SizedBox(width: 8),
            _buildStatusButton('completed', 'Completed'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusButton(String status, String label) {
    final bool isActive = _token.status == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (status == 'in_progress') {
            _showInProgressDialog();
          } else {
            _updateStatus(status);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00796B) : const Color(0xFF1A3535),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? Colors.transparent : Colors.white10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isActive ? Colors.white : Colors.white38,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showInProgressDialog() async {
    final formKey = GlobalKey<FormState>();
    final appIdController = TextEditingController(text: "GJ/2026-27/SRC/");
    final dobController = TextEditingController(text: _token.childDob);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3535),
        title: Text(
          _token.applicationId == null ? 'Enter Application Details' : 'New Application (Re-submission)', 
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _token.applicationId == null 
                  ? 'These details are required to mark application as In Progress'
                  : 'Previous ID (${_token.applicationId}) will be moved to history.',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: appIdController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Application ID', 'GJ/2026-27/SRC/1234567'),
                validator: (v) => v!.length < 15 ? 'Enter valid Application ID' : null,
              ),
              if (_token.childDob == null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: dobController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [DateInputFormatter()],
                  decoration: _inputDecoration('Child DOB', 'DD-MM-YYYY'),
                  validator: (v) => v!.length != 10 ? 'Enter valid date (DD-MM-YYYY)' : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _updateStatus(
                  'in_progress', 
                  applicationId: appIdController.text.trim(),
                  childDob: dobController.text.trim(),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
            child: Text('Confirm', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.black26,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
    );
  }

  Future<void> _updateStatus(String status, {String? applicationId, String? childDob}) async {
    try {
      Map<String, dynamic>? historyEntry;

      // If we are providing a NEW applicationId and there was an OLD one
      if (applicationId != null && _token.applicationId != null && applicationId != _token.applicationId) {
        historyEntry = {
          'id': _token.applicationId,
          'dob': _token.childDob,
          'status': _token.status,
          'updatedAt': Timestamp.now(),
          'attempt': _token.applicationHistory.length + 1,
        };
      }

      await FirestoreService().updateTokenStatus(
        _token.id, 
        status,
        applicationId: applicationId,
        childDob: childDob,
        historyEntry: historyEntry,
      );
      
      final updatedToken = await FirestoreService().getTokenById(_token.id);
      if (updatedToken != null && mounted) {
        setState(() => _token = updatedToken);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  Widget _buildChildrenSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Children Profile'),
        if (_children.isEmpty)
          _buildEmptyText('No child profile added yet')
        else
          ..._children.map((child) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3535),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF00796B).withOpacity(0.2),
                      child: Icon(Icons.child_care_rounded, color: const Color(0xFF81D4FA), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(child.childName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('${child.dob} • ${child.gender}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54)),
                        ],
                      ),
                    ),
                  ],
                ),
              )).toList(),
      ],
    );
  }

  Widget _buildDocumentsManager() {
    int mandatoryUploaded = _documents.where((d) => AppConstants.mandatoryDocTypes.contains(d.docType)).length;
    double progress = mandatoryUploaded / AppConstants.mandatoryDocTypes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Documents Vault'),
        
        // Progress Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3535),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$mandatoryUploaded of ${AppConstants.mandatoryDocTypes.length} Required', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('${(progress * 100).toInt()}%', style: GoogleFonts.outfit(color: const Color(0xFF81D4FA), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  color: const Color(0xFF00796B),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Required Documents', color: Colors.redAccent.withOpacity(0.8)),
        ...AppConstants.mandatoryDocTypes.map((type) => _buildDocItem(type, isMandatory: true)),
        
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildSectionHeader('Other Documents (Max 3)')),
            if (_documents.where((d) => !AppConstants.mandatoryDocTypes.contains(d.docType)).length < 3)
              TextButton.icon(
                onPressed: _addCustomDocument,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF81D4FA)),
                label: Text('Add New', style: GoogleFonts.outfit(color: const Color(0xFF81D4FA), fontSize: 12)),
              ),
          ],
        ),
        if (_documents.where((d) => !AppConstants.mandatoryDocTypes.contains(d.docType)).isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('No additional documents added', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
          )
        else
          ..._documents.where((d) => !AppConstants.mandatoryDocTypes.contains(d.docType)).map((d) => _buildDocItem(d.docType, isMandatory: false)),
      ],
    );
  }

  Future<void> _addCustomDocument() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Other Document Name', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Document Name', 'e.g. Caste Certificate'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38))),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
            child: Text('Add', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _pickAndUpload(controller.text.trim());
    }
  }

  Widget _buildDocItem(String type, {required bool isMandatory}) {
    final existing = _documents.firstWhere((d) => d.docType == type, orElse: () => DocumentModel(id: '', docType: '', fileName: '', storagePath: ''));
    final bool isUploaded = existing.storagePath.isNotEmpty;
    final bool isUploading = _uploadingType == type;
    final bool isDeleting = isUploaded && _deletingIds.contains(existing.id!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3535),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(
          color: isUploaded ? Colors.green : (isMandatory ? Colors.redAccent.withOpacity(0.5) : Colors.white10),
          width: 4,
        )),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(_getDocIcon(type), color: isUploaded ? Colors.green : Colors.white24),
            title: Text(_formatDocType(type), style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: isUploaded ? FontWeight.bold : FontWeight.normal)),
            subtitle: isUploaded 
              ? Text('Uploaded ${DateFormat('dd MMM yyyy').format(existing.uploadedAt ?? DateTime.now())}', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11))
              : Text(isMandatory ? 'Required' : 'Optional', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11)),
            trailing: isUploaded 
              ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24)
              : (isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF81D4FA))) 
                  : const Icon(Icons.add_a_photo_outlined, color: Colors.white24, size: 20)),
          ),
          
          if (isUploaded && !isDeleting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewDocument(existing),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: Text('View', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF81D4FA),
                        side: BorderSide(color: const Color(0xFF81D4FA).withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleDelete(existing),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text('Delete', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          if (!isUploaded && !isUploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _pickAndUpload(type),
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text('Upload Now', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),

          if (isUploading || isDeleting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.white10, color: Color(0xFF00796B)),
                  const SizedBox(height: 4),
                  Text(isUploading ? 'Uploading...' : 'Deleting...', style: GoogleFonts.outfit(color: isUploading ? const Color(0xFF81D4FA) : Colors.redAccent, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGovStatusSection() {
    final bool hasGovStatus = _token.govStatus != null;
    final bool isNoStatus = _token.govStatusMessage?.contains('No status information found') ?? false;
    final bool isApproved = _token.govStatus == 'APPROVED';
    final bool isCancelled = _token.govStatus == 'CANCELLED';
    final bool isError = _token.govStatus == 'ERROR' && !isNoStatus;

    final Color color = isNoStatus
        ? Colors.white54
        : isApproved
            ? Colors.greenAccent
            : isCancelled
                ? Colors.redAccent
                : isError
                    ? Colors.redAccent
                    : Colors.orangeAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: isError ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isError) const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                    if (isError) const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isError ? 'DETAIL MISMATCH ERROR' : (isNoStatus ? 'DATA NOT FOUND' : 'LATEST GOV. STATUS'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (_token.lastSyncAt != null)
                Text(
                  'Synced ${DateFormat('dd MMM HH:mm').format(_token.lastSyncAt!)}',
                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.white24),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasGovStatus)
            Text(
              'Not synced yet. Click sync to fetch latest status from portal.',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
            )
          else ...[
            Text(
              _token.govStatusMessage ?? 'No message found',
              style: GoogleFonts.notoSansGujarati(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            if (isError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Office Side Note: Government portal could not find this application. Please re-check the Application ID and DOB entered above. If details are wrong, you may delete this token and generate a new one.',
                  style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _syncGovStatus,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: Text(hasGovStatus ? 'Update Status' : 'Sync Status Now'),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteToken() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete this token?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('This will permanently delete Token #${_token.tokenNumber}, all uploaded documents, and child details. This action cannot be undone.', 
          style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete Everything', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // 1. Delete all documents from storage and firestore
      for (final doc in _documents) {
        try {
          await StorageService().deleteFile(doc.storagePath);
          await FirestoreService().deleteDocument(_token.id, doc.id!);
        } catch (_) {}
      }

      // 2. Delete the token itself (this should trigger Firestore rules or cloud functions to clean up if any)
      await FirestoreService().deleteToken(_token.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token deleted successfully')));
        context.go('/office/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _syncGovStatus() async {
    if (_token.applicationId == null || _token.childDob == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await RteService().fetchApplicationStatus(
        _token.applicationId!,
        _token.childDob!,
      );
      
      final classified = RteService().classifyStatus(data.statusMessage);
      await FirestoreService().updateGovStatus(
        _token.id,
        govStatus: classified,
        message: data.statusMessage,
      );

      final updated = await FirestoreService().getTokenById(_token.id);
      if (mounted && updated != null) {
        setState(() {
          _token = updated;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status synced with government portal')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portal sync failed. Try again later.')),
        );
      }
    }
  }
  Widget _buildQrSection() {
    final String qrJson = jsonEncode({
      'tokenId': _token.id,
      'tokenNumber': _token.tokenNumber,
      'parentName': _token.parentName,
      'parentMobile': _token.parentMobile,
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Token QR Code'),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3535),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: QrImageView(
                    data: qrJson,
                    version: QrVersions.auto,
                    size: 180.0,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF004D40)),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF004D40)),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () {
                    Share.share('Your RTE Token is #${_token.tokenNumber}. Download our app to track status.');
                  },
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF81D4FA)),
                  label: Text('Share Token Details', style: GoogleFonts.outfit(color: const Color(0xFF81D4FA))),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {double fontSize = 14, bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white38),
        const SizedBox(width: 12),
        Text(text, style: GoogleFonts.outfit(fontSize: fontSize, color: Colors.white, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending': color = Colors.orange; break;
      case 'in_progress': color = Colors.blue; break;
      case 'completed': color = Colors.green; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status.toUpperCase().replaceAll('_', ' '), style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(text, style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic)),
    );
  }

  String _formatDocType(String type) {
    return AppConstants.docTypeNames[type] ?? type;
  }

  IconData _getDocIcon(String type) {
    if (AppConstants.docTypeIcons.containsKey(type)) return AppConstants.docTypeIcons[type]!;
    if (type.toLowerCase().contains('photo')) return Icons.face_rounded;
    if (type.toLowerCase().contains('birth')) return Icons.cake_rounded;
    if (type.toLowerCase().contains('cert')) return Icons.verified_rounded;
    if (type.toLowerCase().contains('aadhaar') || type.toLowerCase().contains('pan')) return Icons.credit_card_rounded;
    return Icons.description_rounded;
  }
}
