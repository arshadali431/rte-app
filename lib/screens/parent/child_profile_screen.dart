import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firestore_service.dart';
import '../../models/child_model.dart';
import '../../core/utils.dart';
import '../../widgets/no_internet_banner.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  String? _tokenId;
  List<ChildModel> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _tokenId = prefs.getString('token_id');

      if (_tokenId != null) {
        final children = await FirestoreService().getChildren(_tokenId!);
        if (mounted) {
          setState(() {
            _children = children;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditSheet([ChildModel? child]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChildFormSheet(
        tokenId: _tokenId!,
        child: child,
        onSave: _loadChildren,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Child Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                    child: CircularProgressIndicator(color: Color(0xFF00796B)))
                : _children.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _children.length,
                        itemBuilder: (context, index) =>
                            _buildChildCard(_children[index]),
                      ),
          ),
        ],
      ),
      floatingActionButton: _children.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddEditSheet(),
              backgroundColor: const Color(0xFF00796B),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.child_care_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No child added yet', style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showAddEditSheet(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Add Child Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(ChildModel child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFE0F2F1),
            child: Icon(Icons.person_rounded, color: const Color(0xFF00796B)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.childName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${child.dob} • ${child.gender}', style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13)),
                if (child.aadhaarNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Aadhaar: ${child.aadhaarNumber}', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 12)),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showAddEditSheet(child),
            icon: Icon(Icons.edit_note_rounded, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class _ChildFormSheet extends StatefulWidget {
  final String tokenId;
  final ChildModel? child;
  final VoidCallback onSave;

  const _ChildFormSheet({required this.tokenId, this.child, required this.onSave});

  @override
  State<_ChildFormSheet> createState() => _ChildFormSheetState();
}

class _ChildFormSheetState extends State<_ChildFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _aadhaarController;
  late TextEditingController _schoolController;
  String _gender = 'Male';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child?.childName);
    _dobController = TextEditingController(text: widget.child?.dob);
    _aadhaarController = TextEditingController(text: widget.child?.aadhaarNumber);
    _schoolController = TextEditingController(text: widget.child?.schoolPreferences.join(', '));
    if (widget.child != null) _gender = widget.child!.gender;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final schools = _schoolController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      
      final childModel = ChildModel(
        id: widget.child?.id,
        childName: _nameController.text.trim(),
        dob: _dobController.text.trim(),
        gender: _gender,
        aadhaarNumber: _aadhaarController.text.trim(),
        schoolPreferences: schools,
      );

      if (widget.child == null) {
        await FirestoreService().addChild(widget.tokenId, childModel);
      } else {
        await FirestoreService().updateChild(widget.tokenId, widget.child!.id!, childModel);
      }

      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save child profile')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.child == null ? 'Add Child' : 'Edit Child', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 24),
              _buildField('Child Full Name', _nameController, Icons.person_outline, (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 20),
              _buildField('Date of Birth', _dobController, Icons.calendar_month_outlined, (v) => v!.length < 10 ? 'Enter DD-MM-YYYY' : null, inputFormatters: [DateInputFormatter()]),
              const SizedBox(height: 20),
              _buildGenderDropdown(),
              const SizedBox(height: 20),
              _buildField('Aadhaar Number (Optional)', _aadhaarController, Icons.badge_outlined, null, keyboardType: TextInputType.number, maxLength: 12),
              const SizedBox(height: 20),
              _buildField('School Preferences (Comma separated)', _schoolController, Icons.school_outlined, null, hint: 'e.g. ABC School, XYZ School'),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, String? Function(String?)? validator, {List<TextInputFormatter>? inputFormatters, TextInputType? keyboardType, int? maxLength, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: hint,
            counterText: '',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.wc_rounded, size: 20),
            filled: true, fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _gender = v!),
        ),
      ],
    );
  }
}
