import 'dart:io';
import '../../core/image_utils.dart';
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
  String? _loadError;
  String? _uploadingType;

  static const Color _accent = Color(0xFF00796B);
  static const Color _ink = Color(0xFF173B35);
  static const Color _pageBackground = Color(0xFFF4F8F7);
  bool _isProcessing = false;
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _tokenId = prefs.getString('token_id');

      if (_tokenId == null || _tokenId!.isEmpty) {
        if (mounted) {
          setState(() {
            _uploadedDocs = [];
            _loadError = 'Your session could not be found. Return to the previous screen and open Document Vault again.';
            _isLoading = false;
          });
        }
        return;
      }

      final docs = await FirestoreService().getDocuments(_tokenId!);
      if (!mounted) return;
      setState(() {
        _uploadedDocs = docs;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Document vault load failed: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _loadError = 'Could not load your documents. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUpload(String docType) async {
    if (_checkIfAadhaar(docType)) {
      final type = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Aadhaar Type', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
          content: Text('Is this a small card-size Aadhaar or a full-page Aadhaar?', style: GoogleFonts.outfit(color: Colors.black87)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'full'), child: Text('Full Page', style: GoogleFonts.outfit(color: const Color(0xFF00796B)))),
            TextButton(onPressed: () => Navigator.pop(context, 'card'), child: Text('Card Size', style: GoogleFonts.outfit(color: const Color(0xFF00796B)))),
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
      backgroundColor: Colors.white,
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
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo upload failed. Please try again later.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Photo upload error: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo upload failed. Please try again later.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
      _uploadingType = null;
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
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Text('Aadhaar Preview', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context, false),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('UPLOAD',
                      style: GoogleFonts.outfit(color: const Color(0xFF00796B), fontWeight: FontWeight.bold, fontSize: 16)),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(mergedFile, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Confirm that the front and back of the Aadhaar card are clearly joined and readable.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.black54, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.cloud_upload_rounded),
                          label: Text('Looks Good, Upload Now', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
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
      final downloadUrl = await StorageService().uploadDocument(_tokenId!, docType, mergedFile);
      if (downloadUrl != null) {
        final docModel = DocumentModel(
          docType: docType,
          fileName: 'merged_aadhaar.jpg',
          storagePath: downloadUrl,
          uploadedAt: DateTime.now(),
        );
        await FirestoreService().addDocument(_tokenId!, docModel);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Merged Aadhaar uploaded successfully', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Photo upload failed. Please try again later.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Merged photo upload error: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Photo upload failed. Please try again later.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _uploadingType = null;
        });
      }
    }
  }

  Future<void> _addCustomDocument() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Add Other Document', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Document Name',
            hintText: 'e.g. Caste Certificate',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
            child: Text('Add & Upload', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _pickAndUpload(controller.text.trim());
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
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: Text(
          'Are you sure you want to delete this document? You can upload a new one after deleting.',
          style: GoogleFonts.outfit(color: Colors.black87),
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
          SnackBar(
            content: Text('Document deleted successfully', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete. Please try again.', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(doc.id!));
    }
  }

  Widget _buildLoadError() {
    final hasSession = _tokenId != null && _tokenId!.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F2F0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  hasSession ? Icons.cloud_off_rounded : Icons.folder_off_outlined,
                  color: _accent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hasSession ? 'Unable to load documents' : 'Session not found',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _loadError ?? 'Please try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF647772),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              if (hasSession)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                    label: Text(
                      'Try again',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: const BorderSide(color: _accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Go back',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mandatoryUploaded = _uploadedDocs
        .where((d) => AppConstants.mandatoryDocTypes.contains(d.docType))
        .length;
    final customDocs = _uploadedDocs
        .where((d) => !AppConstants.mandatoryDocTypes.contains(d.docType))
        .toList();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: _pageBackground,
          appBar: AppBar(
            title: Text(
              'Document Vault',
              style: GoogleFonts.outfit(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            shape: const Border(
              bottom: BorderSide(color: Color(0xFFE7EFED)),
            ),
          ),
          body: Column(
            children: [
              const NoInternetBanner(),
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 2.5,
                  ),
                )
                    : _loadError != null
                    ? _buildLoadError()
                    : RefreshIndicator(
                  onRefresh: _loadData,
                  color: _accent,
                  backgroundColor: Colors.white,
                  child: Scrollbar(
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: _ink,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0E9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'MANDATORY',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFB65A35),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
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
                            },
                            childCount: AppConstants.mandatoryDocTypes.length,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 12, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'OTHER DOCUMENTS',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: _ink,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${customDocs.length}/3',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF748781),
                                  ),
                                ),
                                if (customDocs.length < 3) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: _addCustomDocument,
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: Text(
                                      'Add',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _accent,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (customDocs.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE3ECE9)),
                                ),
                                child: Text(
                                  'No additional documents uploaded',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF748781),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: _buildDocCard(
                                  customDocs[index].docType,
                                  customDocs[index],
                                  isMandatory: false,
                                ),
                              ),
                              childCount: customDocs.length,
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: Center(
                child: Container(
                  width: 230,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE3ECE9)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          color: _accent,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Preparing Aadhaar',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Joining front and back images…',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF748781),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressHeader(int count) {
    final totalMandatory = AppConstants.mandatoryDocTypes.length;
    final double progress = totalMandatory == 0
        ? 0.0
        : (count / totalMandatory).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3ECE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Upload progress',
                  style: GoogleFonts.outfit(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.outfit(
                  color: _accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '$count of $totalMandatory required documents uploaded',
            style: GoogleFonts.outfit(
              color: const Color(0xFF748781),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFEAF1EF),
              color: _accent,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF748781)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Complete all required uploads to finalize your application.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    height: 1.35,
                    color: const Color(0xFF748781),
                  ),
                ),
              ),
            ],
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
    final isDeleting = doc != null && doc.id != null && _deletingIds.contains(doc.id!);
    final label = AppConstants.docTypeNames[type] ?? type;

    IconData icon = Icons.description_outlined;
    if (AppConstants.docTypeIcons.containsKey(type)) {
      icon = AppConstants.docTypeIcons[type]!;
    } else {
      final low = type.toLowerCase();
      if (low.contains('photo')) icon = Icons.face_rounded;
      if (low.contains('birth')) icon = Icons.cake_rounded;
      if (low.contains('cert')) icon = Icons.verified_rounded;
      if (low.contains('aadhaar') || low.contains('pan')) {
        icon = Icons.credit_card_rounded;
      }
    }

    final statusColor = doc != null
        ? const Color(0xFF2E7D5B)
        : isMandatory
        ? const Color(0xFFB65A35)
        : const Color(0xFF748781);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: doc != null
              ? const Color(0xFFCFE7DD)
              : const Color(0xFFE3ECE9),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: (isUploading || isDeleting || doc != null)
              ? null
              : () => _pickAndUpload(type),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: doc != null
                            ? const Color(0xFFE6F4ED)
                            : const Color(0xFFEAF3F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        doc != null ? Icons.check_rounded : icon,
                        size: 22,
                        color: doc != null ? const Color(0xFF2E7D5B) : _accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              height: 1.2,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (doc != null)
                            Text(
                              'Uploaded ${DateFormat('dd MMM yyyy').format(doc.uploadedAt ?? DateTime.now())}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: const Color(0xFF748781),
                              ),
                            )
                          else
                            _buildCardStatusChip(
                              isMandatory ? 'REQUIRED' : 'OPTIONAL',
                              statusColor,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isUploading || isDeleting)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: isDeleting ? Colors.redAccent : _accent,
                        ),
                      )
                    else if (doc == null)
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 21,
                        color: _accent.withOpacity(0.8),
                      )
                    else
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 21,
                        color: Color(0xFF2E7D5B),
                      ),
                  ],
                ),
                if (isUploading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: _accent,
                    backgroundColor: Color(0xFFEAF1EF),
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Processing and uploading…',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (doc != null && !isDeleting) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFEAF0EE)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _viewDocument(doc),
                          icon: const Icon(Icons.visibility_outlined, size: 17),
                          label: Text(
                            'View',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: const BorderSide(color: Color(0xFFD0E2DE)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleDelete(doc),
                          icon: const Icon(Icons.delete_outline_rounded, size: 17),
                          label: Text(
                            'Delete',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB83A46),
                            side: const BorderSide(color: Color(0xFFF0D6D8)),
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
                  const SizedBox(height: 12),
                  Text(
                    'Deleting document…',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}
