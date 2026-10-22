import 'dart:async';
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

  const TokenDetailScreen({super.key, required this.token});

  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen> {
  late TokenModel _token;
  List<ChildModel> _children = [];
  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  bool _isSyncingGov = false;
  String? _uploadingType;
  bool _isProcessing = false;
  final Set<String> _deletingIds = {};
  StreamSubscription<DocumentSnapshot>? _tokenSubscription;

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _startTokenListener();
    if (_token.deletionPending) {
      // Pending self-service deletion: never load or show personal data.
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  void _startTokenListener() {
    _tokenSubscription = FirebaseFirestore.instance
        .collection(AppConstants.kTokensCollection)
        .doc(_token.id)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null || !mounted) return;
      final fresh = TokenModel.fromFirestore(snapshot.data()!, snapshot.id);
      final wasPending = _token.deletionPending;
      setState(() {
        _token = fresh;
        if (fresh.deletionPending) {
          // Block document viewing while a deletion request is pending.
          _children = [];
          _documents = [];
          _isLoading = false;
        }
      });
      if (wasPending && !fresh.deletionPending) {
        // Parent cancelled the deletion elsewhere; load data again.
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool forceServer = false}) async {
    if (_token.deletionPending) {
      // Never load personal data while a self-service deletion is pending.
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (forceServer) setState(() => _isLoading = true);
    try {
      if (forceServer) {
        final fresh = await FirestoreService().getTokenById(
          _token.id,
          forceServer: true,
        );
        if (fresh != null && mounted) setState(() => _token = fresh);
      }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading details')));
      }
    }
  }

  Future<void> _pickAndUpload(String docType) async {
    if (_checkIfAadhaar(docType)) {
      final type = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A3535),
          title: Text(
            'Aadhaar Type',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          content: Text(
            'Is this a small card-size Aadhaar or a full-page Aadhaar?',
            style: GoogleFonts.outfit(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'full'),
              child: Text(
                'Full Page',
                style: GoogleFonts.outfit(color: Color(0xFF81D4FA)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'card'),
              child: Text(
                'Card Size',
                style: GoogleFonts.outfit(color: Color(0xFF81D4FA)),
              ),
            ),
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
        ),
        IOSUiSettings(title: 'Crop Document'),
      ],
    );

    if (croppedFile == null) return;

    setState(() => _uploadingType = docType);

    try {
      final downloadUrl = await StorageService().uploadDocument(
        _token.id,
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
        await FirestoreService().addDocument(_token.id, docModel);

        final docs = await FirestoreService().getDocuments(_token.id);
        if (mounted) setState(() => _documents = docs);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo upload failed. Please try again later.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Photo upload failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo upload failed. Please try again later.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Select $side Image',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xFF00796B),
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
      final mergedFile = await ImageUtils.mergeImagesHorizontally(
        frontFile,
        backFile,
      );

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
              title: Text(
                'Aadhaar Preview',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context, false),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'UPLOAD',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF81D4FA),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: Text(
                        'Looks Good, Upload Now',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81D4FA),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
      final downloadUrl = await StorageService().uploadDocument(
        _token.id,
        docType,
        mergedFile,
      );
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
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Merged Aadhaar uploaded successfully',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo upload failed. Please try again later.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Merged photo upload error: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo upload failed. Please try again later.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Future<void> _handleDelete(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Document?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this document?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white38),
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
      await FirestoreService().deleteDocument(_token.id, doc.id!);

      final docs = await FirestoreService().getDocuments(_token.id);
      if (mounted) setState(() => _documents = docs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Document deleted successfully',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete. Please try again.',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
              title: Text(
                _formatDocType(doc.docType),
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
              ),
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
                        child: CircularProgressIndicator(
                          color: Color(0xFF00796B),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load image',
                            style: GoogleFonts.outfit(color: Colors.black54),
                          ),
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

  /// Neutral, non-personal state for tokens whose parent requested deletion.
  /// No name, phone, Aadhaar, documents or application data are shown here.
  Widget _buildDeletionPendingView(BuildContext context) {
    const accent = Color(0xFF4DB6AC);
    return Scaffold(
      backgroundColor: const Color(0xFF081F20),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  _buildGlassButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/office/dashboard');
                      }
                    },
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Token Details',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.delete_sweep_outlined,
                          color: Color(0xFFFF8A80),
                          size: 52,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Deletion requested',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'The parent/guardian requested deletion of this data. '
                          'Personal details and documents are hidden while the '
                          'request is pending.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                        if (_token.applicationId != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCC80).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFCC80).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.gavel_rounded,
                                  color: Color(0xFFFFCC80),
                                  size: 17,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This application was already submitted to the '
                                    'official RTE portal. The government copy cannot '
                                    'be deleted by the Trust.',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFFFCC80),
                                      fontSize: 12.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final fresh = await FirestoreService().getTokenById(
                              _token.id,
                              forceServer: true,
                            );
                            if (fresh != null && mounted) {
                              setState(() => _token = fresh);
                              if (!fresh.deletionPending) _loadData();
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            'Refresh status',
                            style: GoogleFonts.outfit(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(color: accent.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
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
    const accent = Color(0xFF4DB6AC);

    if (_token.deletionPending) {
      // Hard block: no personal data, documents or actions for pending
      // deletion requests.
      return _buildDeletionPendingView(context);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF081F20),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceServer: true),
        color: accent,
        backgroundColor: const Color(0xFF102F2B),
        child: Stack(
          children: [
            // Subtle dark-teal background; keeps focus on the content.
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF103D35),
                    Color(0xFF092C26),
                    Color(0xFF081F20),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Compact, safe-area-aware header.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Row(
                      children: [
                        _buildGlassButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/office/dashboard');
                            }
                          },
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Token Details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (_token.applicationId != null) ...[
                          const SizedBox(width: 8),
                          _buildTextGlassButton(
                            label: 'RESUBMIT',
                            icon: Icons.refresh_rounded,
                            onTap: _showInProgressDialog,
                          ),
                        ],
                        if (_token.govStatus == 'ERROR' ||
                            (_token.govStatusMessage?.contains(
                              'No status information found',
                            ) ??
                                false)) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Delete token',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFFF6B6B),
                            ),
                            onPressed: _confirmDeleteToken,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: accent,
                        strokeWidth: 2.5,
                      ),
                    )
                        : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const NoInternetBanner(),
                          const SizedBox(height: 12),
                          _buildParentSection(),
                          const SizedBox(height: 24),
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
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isProcessing) _buildProcessingHUD(),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingHUD() {
    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF102F2B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  color: Color(0xFF4DB6AC),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Processing',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please keep this screen open.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextGlassButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4DB6AC).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4DB6AC).withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildHistoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4DB6AC).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Attempt #${_token.applicationHistory.length + 1}',
        style: GoogleFonts.outfit(
          color: const Color(0xFF4DB6AC),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEliteIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF4DB6AC).withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Application History'),
        ..._token.applicationHistory.reversed.map((entry) {
          final DateTime? date = (entry['updatedAt'] as Timestamp?)?.toDate();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.045),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4DB6AC).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${entry['attempt'] ?? '—'}',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF4DB6AC),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['id'] ?? 'Unknown ID',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${entry['status'] ?? 'N/A'}  •  DOB: ${entry['dob'] ?? 'N/A'}',
                        style: GoogleFonts.outfit(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM').format(date),
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color ?? Colors.white,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildParentSection() {
    final bool hasRegId = _token.applicationId != null;
    const accent = Color(0xFF4DB6AC);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Token #${_token.tokenNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(_token.status),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      Icons.person_outline_rounded,
                      _token.parentName,
                      fontSize: 17,
                      isBold: true,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.phone_iphone_rounded,
                      _token.parentMobile.isEmpty ? 'N/A' : _token.parentMobile,
                    ),
                    if (_token.govParentMobile != null &&
                        _token.govParentMobile != _token.parentMobile) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.verified_user_outlined,
                        'Gov: ${_token.govParentMobile}',
                        color: accent,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildGlassButton(
                icon: Icons.edit_outlined,
                onTap: _showEditParentDialog,
              ),
            ],
          ),
          if (hasRegId) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1, color: Colors.white12),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            color: accent,
                            size: 15,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'RTE APPLICATION',
                            style: GoogleFonts.outfit(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        _token.applicationId!,
                        style: GoogleFonts.outfit(
                          color: accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _token.govChildName?.isNotEmpty == true
                            ? _token.govChildName!
                            : '—',
                        style: GoogleFonts.notoSansGujarati(
                          color: _token.govChildName?.isNotEmpty == true
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DOB: ${_token.childDob ?? '—'}',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      if (_token.lastSyncAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last sync: ${DateFormat('dd MMM, HH:mm').format(_token.lastSyncAt!)}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    _isSyncingGov
                        ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        ),
                      ),
                    )
                        : _buildGlassButton(
                      icon: Icons.sync_rounded,
                      onTap: _syncGovStatus,
                    ),
                    if (_token.applicationHistory.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildHistoryBadge(),
                    ],
                  ],
                ),
              ],
            ),
            if (_token.govStatusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Text(
                  _token.govStatusMessage!,
                  style: GoogleFonts.notoSansGujarati(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: Colors.white12),
          ),
          Row(
            children: [
              Expanded(
                child: _buildMetaInfo(
                  'ISSUED ON',
                  DateFormat('dd MMM yyyy').format(
                    _token.createdAt ?? DateTime.now(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetaInfo(
                  'AGENT ID',
                  (_token.createdBy.length > 8
                      ? _token.createdBy.substring(0, 8)
                      : _token.createdBy)
                      .toUpperCase(),
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment:
      alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: Colors.white54,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStatusUpdateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Workflow Status'),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              _buildStatusButton('pending', 'Pending'),
              _buildStatusButton('in_progress', 'Progress'),
              _buildStatusButton('completed', 'Finished'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton(String status, String label) {
    final bool isActive = _token.status == status;
    const accent = Color(0xFF4DB6AC);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: isActive ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () {
              if (status == 'in_progress') {
                _showInProgressDialog();
              } else {
                _updateStatus(status);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: isActive ? const Color(0xFF082923) : Colors.white70,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
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
          _token.applicationId == null
              ? 'Enter Application Details'
              : 'New Application (Re-submission)',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
                decoration: _inputDecoration(
                  'Application ID',
                  'GJ/2026-27/SRC/1234567',
                ),
                validator: (v) =>
                v!.length < 15 ? 'Enter valid Application ID' : null,
              ),
              if (_token.childDob == null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: dobController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [DateInputFormatter()],
                  decoration: _inputDecoration('Child DOB', 'DD-MM-YYYY'),
                  validator: (v) =>
                  v!.length != 10 ? 'Enter valid date (DD-MM-YYYY)' : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final id = appIdController.text.trim();
                final dob = dobController.text.isNotEmpty ? dobController.text.trim() : _token.childDob;

                Navigator.pop(context);

                await _updateStatus(
                  'in_progress',
                  applicationId: id,
                  childDob: dob,
                );

                // 🔥 Trigger auto-sync immediately after saving
                if (dob != null) {
                  _syncGovStatus(forcedId: id, forcedDob: dob);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
    );
  }

  Future<void> _updateStatus(
      String status, {
        String? applicationId,
        String? childDob,
      }) async {
    try {
      Map<String, dynamic>? historyEntry;

      // If we are providing a NEW applicationId and there was an OLD one
      if (applicationId != null &&
          _token.applicationId != null &&
          applicationId != _token.applicationId) {
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

      // No need to manually refresh _token, StreamSubscription handles it!
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  Future<void> _showEditParentDialog() async {
    final nameController = TextEditingController(text: _token.parentName);
    final mobileController = TextEditingController(text: _token.parentMobile);
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Edit Parent Details',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Parent Name', 'Full Name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: mobileController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  'Mobile Number',
                  '10-digit mobile',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) =>
                v!.length != 10 ? 'Enter 10-digit mobile' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                try {
                  await FirestoreService().updateParentInfo(
                    _token.id,
                    nameController.text.trim(),
                    mobileController.text.trim(),
                  );
                  // No need to manually refresh, StreamSubscription handles it!
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Parent details updated')),
                    );
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Update failed')),
                    );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
            ),
            child: Text(
              'Update',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenSection() {
    if (_children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Children Profile'),
        ..._children.map(
              (child) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.045),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4DB6AC).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.face_rounded,
                    color: Color(0xFF4DB6AC),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.childName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${child.dob} • ${child.gender.toUpperCase()}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsManager() {
    final mandatoryTypes = AppConstants.mandatoryDocTypes;
    final mandatoryUploaded = _documents
        .where((d) => mandatoryTypes.contains(d.docType))
        .length;
    final double progress = mandatoryTypes.isEmpty
        ? 0
        : (mandatoryUploaded / mandatoryTypes.length).clamp(0.0, 1.0).toDouble();
    final int extraDocumentCount = _documents
        .where((d) => !mandatoryTypes.contains(d.docType))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Documents'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document checklist',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$mandatoryUploaded of ${mandatoryTypes.length} mandatory documents uploaded',
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildProgressCircle(progress),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFF4DB6AC),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildSectionHeader('Verification Pack')),
            if (extraDocumentCount < 3)
              _buildEliteIconButton(
                icon: Icons.add_rounded,
                label: 'Add Extra',
                onTap: _addCustomDocument,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...mandatoryTypes.map(
              (type) => _buildDocItem(type, isMandatory: true),
        ),
        ..._documents
            .where((d) => !mandatoryTypes.contains(d.docType))
            .map((d) => _buildDocItem(d.docType, isMandatory: false)),
      ],
    );
  }

  Widget _buildProgressCircle(double progress) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF4DB6AC).withOpacity(0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Text(
        '${(progress * 100).toInt()}%',
        style: GoogleFonts.outfit(
          color: const Color(0xFF4DB6AC),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Future<void> _addCustomDocument() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Other Document Name',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            'Document Name',
            'e.g. Caste Certificate',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty)
                Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
            ),
            child: Text(
              'Add',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _pickAndUpload(controller.text.trim());
    }
  }

  Widget _buildDocItem(String type, {required bool isMandatory}) {
    final existing = _documents.firstWhere(
          (d) => d.docType == type,
      orElse: () =>
          DocumentModel(id: '', docType: '', fileName: '', storagePath: ''),
    );
    final bool isUploaded = existing.storagePath.isNotEmpty;
    final bool isUploading = _uploadingType == type;
    final bool isDeleting = isUploaded && _deletingIds.contains(existing.id!);

    final Color accentColor = isUploaded
        ? const Color(0xFF69F0AE)
        : (isMandatory ? const Color(0xFFFF8A80) : Colors.white60);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded
              ? accentColor.withOpacity(0.22)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              minLeadingWidth: 42,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getDocIcon(type), color: accentColor, size: 21),
              ),
              title: Text(
                _formatDocType(type),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isUploaded
                      ? 'Uploaded ${DateFormat('dd MMM yyyy').format(existing.uploadedAt ?? DateTime.now())}'
                      : (isMandatory ? 'Required document' : 'Optional document'),
                  style: GoogleFonts.outfit(
                    color: isUploaded ? Colors.white60 : accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (isUploaded && !isDeleting)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn(
                        label: 'View',
                        icon: Icons.visibility_outlined,
                        color: const Color(0xFF4DB6AC),
                        onTap: () => _viewDocument(existing),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionBtn(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFFF6B6B),
                        onTap: () => _handleDelete(existing),
                      ),
                    ),
                  ],
                ),
              ),
            if (!isUploaded && !isUploading)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Material(
                  color: Colors.white.withOpacity(0.035),
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () => _pickAndUpload(type),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.upload_file_rounded,
                            color: Color(0xFF4DB6AC),
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Upload document',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (isUploading || isDeleting)
              _buildProgressOverlay(
                isUploading ? 'Uploading document…' : 'Deleting document…',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverlay(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          const LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: Colors.white10,
            color: Color(0xFF4DB6AC),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovStatusSection() {
    final bool hasGovStatus = _token.govStatus != null;
    final bool isNoStatus =
        _token.govStatusMessage?.contains('No status information found') ??
            false;
    final bool isApproved = _token.govStatus == 'APPROVED';
    final bool isCancelled = _token.govStatus == 'CANCELLED';
    final bool isSubmitted = _token.govStatus == 'SUBMITTED';
    final bool isError = false; // no longer classified as ERROR

    final Color statusColor = isNoStatus
        ? Colors.white54
        : isApproved
        ? const Color(0xFF69F0AE) // green
        : isSubmitted
        ? const Color(0xFF90CAF9) // light blue
        : isCancelled
        ? const Color(0xFFFF5252) // red
        : const Color(0xFFFFD54F); // yellow — PENDING

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: statusColor.withOpacity(0.15),
          width: isError ? 2 : 1,
        ),
        boxShadow: isApproved
            ? [
          BoxShadow(
            color: statusColor.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ]
            : null,
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
                    Icon(
                      Icons.account_balance_rounded,
                      color: statusColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'GOVERNMENT STATUS',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_token.lastSyncAt != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'SYNCED: ${DateFormat('dd MMM HH:mm').format(_token.lastSyncAt!)}',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.white24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!hasGovStatus)
            Text(
              'Government portal not yet synchronized.',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
            )
          else ...[
            // ── Child Name Row ──────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.child_care_rounded,
                    size: 16,
                    color: statusColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'CHILD NAME',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white24,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _token.govChildName?.isNotEmpty == true
                          ? _token.govChildName!
                          : '—',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansGujarati(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _token.govChildName != null
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_token.govParentMobile != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_iphone_rounded,
                      size: 16,
                      color: statusColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'GOV MOBILE',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white24,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _token.govParentMobile!,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              _token.govStatusMessage ?? 'No message found',
              style: GoogleFonts.notoSansGujarati(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 24),
          InkWell(
            onTap: _syncGovStatus,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sync_rounded, size: 18, color: statusColor),
                  const SizedBox(width: 12),
                  Text(
                    hasGovStatus ? 'Update Status' : 'Sync Portal Now',
                    style: GoogleFonts.outfit(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
        title: Text(
          'Delete Token?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete Token #${_token.tokenNumber} and all its associated data. This action is irreversible.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep It',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete Now',
              style: GoogleFonts.outfit(
                color: const Color(0xFFFF5252),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      for (final doc in _documents) {
        try {
          await StorageService().deleteFile(doc.storagePath);
          await FirestoreService().deleteDocument(_token.id, doc.id!);
        } catch (_) {}
      }
      await FirestoreService().deleteToken(_token.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token decommissioned successfully')),
        );
        context.go('/office/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Decommission failed: $e')));
      }
    }
  }

  Future<void> _syncGovStatus({String? forcedId, String? forcedDob}) async {
    // 🛡️ Skip sync if already approved (Smart Cache)
    if (_token.govStatus == 'APPROVED' && forcedId == null) {
      debugPrint('Skipping sync for Token #${_token.tokenNumber}: Already Approved.');
      return;
    }

    final appId = forcedId ?? _token.applicationId;
    final dob = forcedDob ?? _token.childDob;

    if (appId == null || dob == null) return;

    setState(() => _isSyncingGov = true);
    try {
      final result = await RteService().fetchStatusWithChildName(
        appId,
        dob,
      );

      await FirestoreService().updateGovStatus(
        _token.id,
        govStatus: result.classifiedStatus,
        message: result.statusMessage,
        govChildName: result.childName,
        govParentMobile: result.parentMobile,
      );

      final updated = await FirestoreService().getTokenById(_token.id);
      if (mounted && updated != null) {
        setState(() {
          _token = updated;
          _isSyncingGov = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System synchronized with government gateway'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingGov = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gateway communication failed. Try again.'),
          ),
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
        _buildSectionHeader('Management QR'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: qrJson,
                  version: QrVersions.auto,
                  size: 152,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF00251A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF00251A),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Token #${_token.tokenNumber}',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Scan or share the token details',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Share.share(
                  'RTE Management Token #${_token.tokenNumber} for ${_token.parentName}.',
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(
                  'Share token',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4DB6AC),
                  side: BorderSide(
                    color: const Color(0xFF4DB6AC).withOpacity(0.45),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      IconData icon,
      String text, {
        double fontSize = 14,
        bool isBold = false,
        Color color = Colors.white,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: Colors.white54),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: fontSize,
              color: color,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'in_progress':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: Colors.white24,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  String _formatDocType(String type) {
    return AppConstants.docTypeNames[type] ?? type;
  }

  IconData _getDocIcon(String type) {
    if (AppConstants.docTypeIcons.containsKey(type))
      return AppConstants.docTypeIcons[type]!;
    if (type.toLowerCase().contains('photo')) return Icons.face_rounded;
    if (type.toLowerCase().contains('birth')) return Icons.cake_rounded;
    if (type.toLowerCase().contains('cert')) return Icons.verified_rounded;
    if (type.toLowerCase().contains('aadhaar') ||
        type.toLowerCase().contains('pan'))
      return Icons.credit_card_rounded;
    return Icons.description_rounded;
  }

  Widget _buildGovStatusBadge(String? status) {
    if (status == null) return _buildStatusChip('NO SYNC');

    final bool isApproved = status == 'APPROVED';
    final bool isCancelled = status == 'CANCELLED';
    final bool isSubmitted = status == 'SUBMITTED';

    final Color color = isApproved
        ? const Color(0xFF69F0AE)
        : isSubmitted
        ? const Color(0xFF90CAF9)
        : isCancelled
        ? const Color(0xFFFF5252)
        : const Color(0xFFFFD54F);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
