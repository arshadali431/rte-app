import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/token_model.dart';
import '../../models/child_model.dart';
import '../../models/document_model.dart';
import '../../core/utils.dart';
import '../../core/constants.dart';
import '../../core/permission_handler.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Document deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to delete. Please try again.'),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D2B2B),
      appBar: AppBar(
        title: Text('Token #${_token.tokenNumber}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2B2B), Color(0xFF0A1A1A)],
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF81D4FA)))
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
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF81D4FA), size: 20),
              const SizedBox(width: 8),
              Text('RTE REGISTERED ID', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _token.applicationId!,
            style: GoogleFonts.outfit(color: const Color(0xFF81D4FA), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Child DOB: ${_token.childDob}',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
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
    final dobController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3535),
        title: Text('Enter Application Details', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'These details are required to mark application as In Progress',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: appIdController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Application ID', 'GJ/2026-27/SRC/1234567'),
                validator: (v) => v!.length < 15 ? 'Enter valid Application ID' : null,
              ),
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
      await FirestoreService().updateTokenStatus(
        _token.id, 
        status,
        applicationId: applicationId,
        childDob: childDob,
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
                  Text('$mandatoryUploaded of 9 Required', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
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
        _buildSectionHeader('Optional Documents'),
        ...AppConstants.optionalDocTypes.map((type) => _buildDocItem(type, isMandatory: false)),
      ],
    );
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
    if (type.contains('aadhaar')) return Icons.badge_rounded;
    if (type.contains('photo')) return Icons.face_rounded;
    if (type.contains('birth')) return Icons.child_friendly_rounded;
    return Icons.description_rounded;
  }
}
