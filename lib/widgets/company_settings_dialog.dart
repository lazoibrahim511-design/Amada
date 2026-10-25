import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../screens/super_admin_screen.dart';
import 'glass_dialog.dart';
import 'neu_button.dart';

Future<void> showCompanySettingsDialog(BuildContext context) async {
  final provider = Provider.of<AttendanceProvider>(context, listen: false);
  await showGlassDialog(
    context: context,
    title: provider.translate('company_settings'),
    subtitle: provider.translate('manage_company_branding'),
    icon: Icons.business,
    content: const CompanySettingsForm(),
  );
}

class CompanySettingsForm extends StatefulWidget {
  const CompanySettingsForm({super.key});

  @override
  State<CompanySettingsForm> createState() => _CompanySettingsFormState();
}

class _CompanySettingsFormState extends State<CompanySettingsForm> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _logoBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    if (provider.companyProfile != null) {
      _nameController.text = provider.companyProfile!.name;
      _addressController.text = provider.companyProfile!.address;
      _emailController.text = provider.companyProfile!.email ?? '';
      _phoneController.text = provider.companyProfile!.phone ?? '';
      _logoBase64 = provider.companyProfile!.logoBase64;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image != null) {
          // Resize to max 300 width to save space in Firestore
          final resized = img.copyResize(image, width: 300);
          final compressedBytes = img.encodeJpg(resized, quality: 75);
          setState(() {
            _logoBase64 = base64Encode(compressedBytes);
          });
        }
      } catch (e) {
        debugPrint('Error compressing image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load image: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _save() async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.translate('name_is_required'))));
      return;
    }

    setState(() => _isLoading = true);
    
    final newProfile = CompanyProfile(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      logoBase64: _logoBase64,
      geminiApiKey: provider.companyProfile?.geminiApiKey,
    );

    await provider.firebaseService.saveCompanyProfile(newProfile);
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.translate('company_settings_saved'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AttendanceProvider>(context);
    final license = provider.currentLicense;
    final maxUsers = provider.maxActiveUsers;
    final activeUsers = provider.activeEmployeesCount;
    final isExpired = license?.isExpired ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Subscription & License Status Card ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF1E283C), Color(0xFF161F2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Color(0xFF2E65FF), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        provider.translate('license_info'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      license?.planName ?? 'Standard',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E65FF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${provider.translate('active_licenses_quota')}:',
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$activeUsers / $maxUsers seats',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: activeUsers >= maxUsers ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${provider.translate('expires_on')}:',
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        license != null ? DateFormat('yyyy-MM-dd').format(license.subscriptionExpiresAt) : 'Never',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isExpired ? const Color(0xFFEF4444) : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Open Super Admin / SaaS Master Button
              NeuButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const SuperAdminScreen()),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings_rounded, size: 16),
                label: provider.translate('super_admin_portal'),
                variant: NeuButtonVariant.primary,
                height: 36,
                fontSize: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Logo Picker
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                ),
                image: _logoBase64 != null
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(_logoBase64!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _logoBase64 == null
                  ? Icon(Icons.add_a_photo, color: isDark ? Colors.white54 : Colors.black54)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            provider.translate('tap_to_upload_logo'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Fields
        _buildTextField(provider.translate('company_name'), _nameController, Icons.business),
        const SizedBox(height: 16),
        _buildTextField(provider.translate('email'), _emailController, Icons.email),
        const SizedBox(height: 16),
        _buildTextField(provider.translate('phone'), _phoneController, Icons.phone),
        const SizedBox(height: 16),
        _buildTextField(provider.translate('address'), _addressController, Icons.location_on),
        const SizedBox(height: 32),

        // Save Button
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E65FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(provider.translate('save_changes'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black54),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
