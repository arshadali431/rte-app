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
  static const _primary = Color(0xFF00796B);
  static const _background = Color(0xFFF7F9F8);

  String? _tokenId;
  List<ChildModel> _children = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenId = prefs.getString('token_id');

      if (tokenId == null || tokenId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _tokenId = null;
          _children = [];
          _isLoading = false;
          _loadError = 'Your session could not be found. Please sign in again.';
        });
        return;
      }

      final children = await FirestoreService().getChildren(tokenId);
      if (!mounted) return;
      setState(() {
        _tokenId = tokenId;
        _children = children;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load child profiles. Please try again.';
      });
    }
  }

  void _showAddEditSheet([ChildModel? child]) {
    final tokenId = _tokenId;
    if (tokenId == null || tokenId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session is unavailable. Please sign in again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => _ChildFormSheet(
        tokenId: tokenId,
        child: child,
        onSave: _loadChildren,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C2927),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Text(
          'Child Profile',
          style: GoogleFonts.outfit(
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          const NoInternetBanner(),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
                : _loadError != null
                ? _buildErrorState()
                : _children.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadChildren,
              color: _primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CHILD PROFILES',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF6B7975),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.15,
                          ),
                        ),
                      ),
                      Text(
                        '${_children.length} ${_children.length == 1 ? 'profile' : 'profiles'}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF60716C),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._children.map(_buildChildCard),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _children.isNotEmpty && !_isLoading
          ? FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 1,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Child',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      )
          : null,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF52615C),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _loadChildren,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: Color(0xFFB8D7CF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F3F0),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.child_care_rounded,
                size: 36,
                color: _primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No child profile yet',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF24332F),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Add your child’s details to keep the application information organised.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                height: 1.45,
                color: const Color(0xFF75817D),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showAddEditSheet(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Add Child Profile',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard(ChildModel child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6ECE9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3F0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: _primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.childName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF24332F),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${child.dob}  ·  ${child.gender}',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF6C7975),
                      fontSize: 13,
                    ),
                  ),
                  if (child.aadhaarNumber.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Aadhaar: ${child.aadhaarNumber}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF87918D),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Edit child profile',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showAddEditSheet(child),
            icon: const Icon(Icons.edit_outlined, size: 19),
            color: const Color(0xFF61716B),
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

  const _ChildFormSheet({
    required this.tokenId,
    this.child,
    required this.onSave,
  });

  @override
  State<_ChildFormSheet> createState() => _ChildFormSheetState();
}

class _ChildFormSheetState extends State<_ChildFormSheet> {
  static const _primary = Color(0xFF00796B);
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dobController;
  late final TextEditingController _aadhaarController;
  late final TextEditingController _schoolController;
  String _gender = 'Male';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child?.childName ?? '');
    _dobController = TextEditingController(text: widget.child?.dob ?? '');
    _aadhaarController = TextEditingController(text: widget.child?.aadhaarNumber ?? '');
    _schoolController = TextEditingController(
      text: widget.child?.schoolPreferences.join(', ') ?? '',
    );
    const genders = ['Male', 'Female', 'Other'];
    if (widget.child != null && genders.contains(widget.child!.gender)) {
      _gender = widget.child!.gender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _aadhaarController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final schools = _schoolController.text
          .split(',')
          .map((school) => school.trim())
          .where((school) => school.isNotEmpty)
          .toList();

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
        await FirestoreService().updateChild(
          widget.tokenId,
          widget.child!.id!,
          childModel,
        );
      }

      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save child profile. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(22, 12, 22, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6DEDA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.child == null ? 'Add Child Profile' : 'Edit Child Profile',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF24332F),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF65716D),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your child’s details below.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFF77827E),
                ),
              ),
              const SizedBox(height: 22),
              _buildField(
                'Child Full Name',
                _nameController,
                Icons.person_outline_rounded,
                    (value) => value == null || value.trim().isEmpty ? 'Name is required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 17),
              _buildField(
                'Date of Birth',
                _dobController,
                Icons.calendar_month_outlined,
                    (value) => value == null || value.length < 10 ? 'Enter date as DD-MM-YYYY' : null,
                keyboardType: TextInputType.number,
                inputFormatters: [DateInputFormatter()],
                hint: 'DD-MM-YYYY',
              ),
              const SizedBox(height: 17),
              _buildGenderDropdown(),
              const SizedBox(height: 17),
              _buildField(
                'Aadhaar Number (Optional)',
                _aadhaarController,
                Icons.badge_outlined,
                    (value) => value != null && value.isNotEmpty && value.length != 12
                    ? 'Enter a 12-digit Aadhaar number'
                    : null,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                maxLength: 12,
                hint: '12-digit number',
              ),
              const SizedBox(height: 17),
              _buildField(
                'School Preferences',
                _schoolController,
                Icons.school_outlined,
                null,
                hint: 'ABC School, XYZ School',
                helperText: 'Separate multiple schools with commas.',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withOpacity(0.45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                      : Text(
                    'Save Profile',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  Widget _buildField(
      String label,
      TextEditingController controller,
      IconData icon,
      String? Function(String?)? validator, {
        List<TextInputFormatter>? inputFormatters,
        TextInputType? keyboardType,
        int? maxLength,
        String? hint,
        String? helperText,
        TextCapitalization textCapitalization = TextCapitalization.none,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: const Color(0xFF44534E),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          validator: validator,
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF24332F),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 19, color: const Color(0xFF6D7A75)),
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF9AA5A0),
            ),
            helperText: helperText,
            helperStyle: GoogleFonts.outfit(
              fontSize: 11,
              color: const Color(0xFF7D8984),
            ),
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF5F7F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E8E4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E8E4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD75A5A)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD75A5A), width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: const Color(0xFF44534E),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: _gender,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF24332F),
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.wc_rounded,
              size: 19,
              color: Color(0xFF6D7A75),
            ),
            filled: true,
            fillColor: const Color(0xFFF5F7F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E8E4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E8E4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.2),
            ),
          ),
          items: ['Male', 'Female', 'Other']
              .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _gender = value);
          },
        ),
      ],
    );
  }
}
