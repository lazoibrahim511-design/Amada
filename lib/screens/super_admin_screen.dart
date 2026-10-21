import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/company_license.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/neu_button.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _searchController = TextEditingController();
  List<CompanyLicense> _companies = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final list = await provider.firebaseService.getAllCompanyLicenses();
    
    // If empty, ensure current company exists in list
    if (list.isEmpty) {
      final current = provider.currentLicense ??
          CompanyLicense.defaultLicense(code: provider.currentCompanyCode);
      await provider.firebaseService.saveCompanyLicense(current);
      list.add(current);
    }

    if (mounted) {
      setState(() {
        _companies = list;
        _isLoading = false;
      });
    }
  }

  List<CompanyLicense> get _filteredCompanies {
    if (_searchQuery.trim().isEmpty) return _companies;
    final q = _searchQuery.trim().toLowerCase();
    return _companies.where((c) {
      return c.companyName.toLowerCase().contains(q) ||
          c.companyCode.toLowerCase().contains(q) ||
          c.planName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    final totalCompanies = _companies.length;
    final activeCompanies = _companies.where((c) => c.isActive && !c.isExpired).length;
    final suspendedCompanies = _companies.where((c) => !c.isActive).length;
    final totalSeats = _companies.fold<int>(0, (sum, c) => sum + c.maxActiveUsers);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E65FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF2E65FF), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.translate('super_admin_portal'),
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Multi-Tenant SaaS Licensing & Quota Control',
                  style: TextStyle(color: subtextColor, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: NeuButton(
              onPressed: () => _showAddCompanyDialog(context, provider),
              icon: const Icon(Icons.add_business_rounded, size: 16),
              label: provider.translate('add_new_company'),
              variant: NeuButtonVariant.primary,
              height: 38,
              fontSize: 12.5,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCompanies,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary KPIs
                    _buildKpiRow(
                      isDark: isDark,
                      totalCompanies: totalCompanies,
                      activeCompanies: activeCompanies,
                      suspendedCompanies: suspendedCompanies,
                      totalSeats: totalSeats,
                    ),
                    const SizedBox(height: 20),

                    // Search & Controls Bar
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: textColor, fontSize: 13),
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search clients by name, company code or plan...',
                                hintStyle: TextStyle(color: subtextColor, fontSize: 12.5),
                                prefixIcon: Icon(Icons.search_rounded, color: subtextColor, size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh list',
                          onPressed: _loadCompanies,
                          color: textColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Company Cards List
                    if (_filteredCompanies.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No client companies found.',
                            style: TextStyle(color: subtextColor, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      for (final comp in _filteredCompanies) ...[
                        _buildCompanyCard(context, provider, comp, isDark),
                        const SizedBox(height: 14),
                      ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKpiRow({
    required bool isDark,
    required int totalCompanies,
    required int activeCompanies,
    required int suspendedCompanies,
    required int totalSeats,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final chips = [
          _buildKpiCard(
            label: 'Total Clients',
            value: '$totalCompanies',
            icon: Icons.business_rounded,
            color: const Color(0xFF2E65FF),
            isDark: isDark,
          ),
          _buildKpiCard(
            label: 'Active Clients',
            value: '$activeCompanies',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          _buildKpiCard(
            label: 'Suspended / Expired',
            value: '$suspendedCompanies',
            icon: Icons.pause_circle_rounded,
            color: const Color(0xFFEF4444),
            isDark: isDark,
          ),
          _buildKpiCard(
            label: 'Total User Seats',
            value: '$totalSeats',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
          ),
        ];

        if (isMobile) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in chips) ...[
                  SizedBox(width: 180, child: c),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              Expanded(child: chips[i]),
              if (i < chips.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(
    BuildContext context,
    AttendanceProvider provider,
    CompanyLicense comp,
    bool isDark,
  ) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final isCurrent = comp.companyCode.toLowerCase() == provider.currentCompanyCode.toLowerCase();
    final isExpired = comp.isExpired;
    final isActive = comp.isActive && !isExpired;

    return GlassContainer(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Logo / Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: (comp.logoBase64 != null && comp.logoBase64!.isNotEmpty)
                      ? null
                      : LinearGradient(
                          colors: isActive
                              ? [const Color(0xFF2E65FF), const Color(0xFF8B5CF6)]
                              : [Colors.grey.shade600, Colors.grey.shade800],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: (comp.logoBase64 != null && comp.logoBase64!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(
                          base64Decode(comp.logoBase64!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              comp.companyName.isNotEmpty
                                  ? comp.companyName.substring(0, 1).toUpperCase()
                                  : 'C',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          comp.companyName.isNotEmpty
                              ? comp.companyName.substring(0, 1).toUpperCase()
                              : 'C',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
              const SizedBox(width: 14),

              // Title and Code
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comp.companyName,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Text(
                              'CURRENT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E65FF)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Code: ${comp.companyCode}',
                          style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            comp.planName,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 13,
                      color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive ? 'Active' : (isExpired ? 'Expired' : 'Suspended'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Quota & Expiration Details
          Row(
            children: [
              // Max Users Info
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.group_outlined, size: 18, color: Color(0xFF2E65FF)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${comp.maxActiveUsers} Max Users',
                          style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Licensed Workforce Limit',
                          style: TextStyle(color: subtextColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Expiry Date Info
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd').format(comp.subscriptionExpiresAt),
                          style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${comp.daysRemaining} days left',
                          style: TextStyle(color: subtextColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Actions Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              // 1-Click Toggle Active / Suspend
              NeuButton(
                onPressed: () async {
                  final updated = comp.copyWith(isActive: !comp.isActive);
                  await provider.saveCompanyLicense(updated);
                  _loadCompanies();
                },
                icon: Icon(comp.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 15),
                label: comp.isActive ? 'Suspend' : 'Activate',
                variant: comp.isActive ? NeuButtonVariant.warning : NeuButtonVariant.primary,
                height: 34,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // Edit Company Info & Logo
              NeuButton(
                onPressed: () => _showEditCompanyDialog(context, provider, comp),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: 'Edit Info & Logo',
                variant: NeuButtonVariant.primary,
                height: 34,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // Edit Max Users
              NeuButton(
                onPressed: () => _showEditUsersDialog(context, provider, comp),
                icon: const Icon(Icons.people_alt_outlined, size: 15),
                label: 'Set User Limit',
                variant: NeuButtonVariant.navy,
                height: 34,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // Extend Subscription
              NeuButton(
                onPressed: () => _showExtendDialog(context, provider, comp),
                icon: const Icon(Icons.more_time_rounded, size: 15),
                label: 'Extend Plan',
                variant: NeuButtonVariant.primary,
                height: 34,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // View / Copy Login Credentials
              NeuButton(
                onPressed: () => _showCredentialsDialog(context, comp),
                icon: const Icon(Icons.vpn_key_rounded, size: 15),
                label: 'Login Details',
                variant: NeuButtonVariant.whitePill,
                height: 34,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // Switch to this company (if not current)
              if (!isCurrent)
                NeuButton(
                  onPressed: () async {
                    await provider.setCompanyCode(comp.companyCode);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Switched active workspace to "${comp.companyName}"'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                    _loadCompanies();
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                  label: 'Switch To',
                  variant: NeuButtonVariant.whitePill,
                  height: 34,
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper to pick and compress company logo
  Future<void> _pickCompanyLogo(
    void Function(void Function()) setDialogState,
    void Function(String?) onLogoSelected,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final resized = img.copyResize(decoded, width: 300);
          final compressed = img.encodeJpg(resized, quality: 75);
          setDialogState(() {
            onLogoSelected(base64Encode(compressed));
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking company logo: $e');
    }
  }

  Widget _buildLogoPickerSection({
    required BuildContext context,
    required String? logoBase64,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E283C) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (logoBase64 != null && logoBase64.isNotEmpty)
                      ? const Color(0xFF2E65FF)
                      : (isDark ? Colors.white24 : Colors.black12),
                  width: 1.5,
                ),
                boxShadow: [
                  if (logoBase64 != null && logoBase64.isNotEmpty)
                    BoxShadow(
                      color: const Color(0xFF2E65FF).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: (logoBase64 != null && logoBase64.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14.5),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            base64Decode(logoBase64),
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 2.5),
                              child: const Text(
                                'Change',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 28,
                          color: Color(0xFF2E65FF),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload Logo',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          if (logoBase64 != null && logoBase64.isNotEmpty)
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
              label: const Text(
                'Remove Logo',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          else
            Text(
              'PNG, JPG or WEBP (Max 300px)',
              style: TextStyle(color: subtextColor, fontSize: 10),
            ),
        ],
      ),
    );
  }

  // Dialog to Add a New Client Company
  void _showAddCompanyDialog(BuildContext context, AttendanceProvider provider) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final maxUsersCtrl = TextEditingController(text: '50');
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? logoBase64;
    String selectedPlan = 'Standard';
    int selectedDurationMonths = 12;

    showGlassDialog(
      context: context,
      title: 'Add New Client Company',
      subtitle: 'Create a new client with license, quota and branding',
      icon: Icons.add_business_rounded,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final subtextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.72,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLogoPickerSection(
                    context: ctx,
                    logoBase64: logoBase64,
                    onPick: () => _pickCompanyLogo(setDialogState, (b64) => logoBase64 = b64),
                    onRemove: () => setDialogState(() => logoBase64 = null),
                    isDark: isDark,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: textColor, fontSize: 13),
                    onChanged: (val) {
                      // Auto generate slug
                      if (codeCtrl.text.isEmpty || codeCtrl.text == nameCtrl.text.toLowerCase().replaceAll(' ', '_')) {
                        setDialogState(() {
                          codeCtrl.text = val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      hintText: 'e.g. Acme Corporation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Company Code / Slug',
                      hintText: 'e.g. acme',
                      helperText: 'Used by employees to log into their tenant',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedPlan,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(labelText: 'Plan'),
                          items: const [
                            DropdownMenuItem(value: 'Starter', child: Text('Starter')),
                            DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                            DropdownMenuItem(value: 'Professional', child: Text('Professional')),
                            DropdownMenuItem(value: 'Enterprise', child: Text('Enterprise')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => selectedPlan = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxUsersCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Max Users Limit',
                            hintText: '50',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedDurationMonths,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Subscription Duration'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 Month')),
                      DropdownMenuItem(value: 3, child: Text('3 Months')),
                      DropdownMenuItem(value: 6, child: Text('6 Months')),
                      DropdownMenuItem(value: 12, child: Text('1 Year (12 Months)')),
                      DropdownMenuItem(value: 24, child: Text('2 Years (24 Months)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedDurationMonths = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Owner Email (Optional)',
                            hintText: 'admin@acme.com',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Owner Phone (Optional)',
                            hintText: '+1 234 567 890',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Physical Address (Optional)',
                      hintText: 'e.g. 100 Innovation Way, Suite 400',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks (Optional)',
                      hintText: 'Billing terms, branch contacts, etc.',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        NeuButton(
          label: 'Create Client',
          variant: NeuButtonVariant.primary,
          height: 38,
          onPressed: () async {
            final name = nameCtrl.text.trim();
            final code = codeCtrl.text.trim().toLowerCase();
            final maxUsers = int.tryParse(maxUsersCtrl.text.trim()) ?? 50;

            if (name.isEmpty || code.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter company name and code.')),
              );
              return;
            }

            final now = DateTime.now();
            final expires = DateTime(now.year, now.month + selectedDurationMonths, now.day);

            final newComp = CompanyLicense(
              companyId: code,
              companyCode: code,
              companyName: name,
              planName: selectedPlan,
              maxActiveUsers: maxUsers,
              subscriptionStartDate: now,
              subscriptionExpiresAt: expires,
              ownerEmail: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
              ownerPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
              address: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
              notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
              logoBase64: logoBase64,
              isActive: true,
            );

            Navigator.pop(context);
            await provider.saveCompanyLicense(newComp);
            _loadCompanies();

            if (context.mounted) {
              _showCredentialsDialog(context, newComp);
            }
          },
        ),
      ],
    );
  }

  // Dialog to Edit an Existing Client Company Information & Logo
  void _showEditCompanyDialog(BuildContext context, AttendanceProvider provider, CompanyLicense comp) {
    final nameCtrl = TextEditingController(text: comp.companyName);
    final maxUsersCtrl = TextEditingController(text: comp.maxActiveUsers.toString());
    final emailCtrl = TextEditingController(text: comp.ownerEmail ?? '');
    final phoneCtrl = TextEditingController(text: comp.ownerPhone ?? '');
    final addressCtrl = TextEditingController(text: comp.address ?? '');
    final notesCtrl = TextEditingController(text: comp.notes ?? '');
    String? logoBase64 = comp.logoBase64;
    String selectedPlan = comp.planName;

    showGlassDialog(
      context: context,
      title: 'Edit Company Information',
      subtitle: '${comp.companyName} (${comp.companyCode})',
      icon: Icons.edit_note_rounded,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final subtextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.72,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLogoPickerSection(
                    context: ctx,
                    logoBase64: logoBase64,
                    onPick: () => _pickCompanyLogo(setDialogState, (b64) => logoBase64 = b64),
                    onRemove: () => setDialogState(() => logoBase64 = null),
                    isDark: isDark,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      hintText: 'e.g. Acme Corporation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Readonly Company Code banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tag_rounded, size: 16, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 8),
                        Text(
                          'Company Code: ',
                          style: TextStyle(color: subtextColor, fontSize: 12),
                        ),
                        Text(
                          comp.companyCode,
                          style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedPlan,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(labelText: 'Plan'),
                          items: const [
                            DropdownMenuItem(value: 'Starter', child: Text('Starter')),
                            DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                            DropdownMenuItem(value: 'Professional', child: Text('Professional')),
                            DropdownMenuItem(value: 'Enterprise', child: Text('Enterprise')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => selectedPlan = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxUsersCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Max Users Limit',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Owner Email',
                            hintText: 'admin@company.com',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Owner Phone',
                            hintText: '+1 234 567 890',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Physical Address',
                      hintText: 'e.g. 100 Innovation Way, Suite 400',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks',
                      hintText: 'Billing terms, branch contacts, etc.',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        NeuButton(
          label: 'Save Changes',
          variant: NeuButtonVariant.primary,
          height: 38,
          onPressed: () async {
            final name = nameCtrl.text.trim();
            final maxUsers = int.tryParse(maxUsersCtrl.text.trim()) ?? comp.maxActiveUsers;

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Company name cannot be empty.')),
              );
              return;
            }

            final updated = comp.copyWith(
              companyName: name,
              planName: selectedPlan,
              maxActiveUsers: maxUsers,
              ownerEmail: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
              ownerPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
              address: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
              notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
              logoBase64: logoBase64,
              overrideLogo: true,
            );

            Navigator.pop(context);
            await provider.saveCompanyLicense(updated);
            _loadCompanies();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Updated "${updated.companyName}" successfully.'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  // Dialog showing client login credentials with 1-click copy
  void _showCredentialsDialog(BuildContext context, CompanyLicense comp) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final adminEmail = comp.ownerEmail != null && comp.ownerEmail!.isNotEmpty
        ? comp.ownerEmail!
        : 'admin@${comp.companyCode}.com';
    const defaultPassword = 'admin123';

    showGlassDialog(
      context: context,
      title: 'Client Login Credentials',
      subtitle: comp.companyName,
      icon: Icons.vpn_key_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Share these credentials with the client so their administrator can log in:',
            style: TextStyle(color: subtextColor, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E283C) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _buildCredentialRow('Company Code', comp.companyCode, isDark, textColor),
                const Divider(height: 20),
                _buildCredentialRow('Admin Email', adminEmail, isDark, textColor),
                const Divider(height: 20),
                _buildCredentialRow('Default Password', defaultPassword, isDark, textColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: The administrator can also simply use "$adminEmail" or "admin" with "$defaultPassword".',
            style: TextStyle(color: subtextColor, fontSize: 11.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        NeuButton(
          label: 'Copy Credentials',
          icon: const Icon(Icons.copy_rounded, size: 15),
          variant: NeuButtonVariant.primary,
          height: 38,
          onPressed: () {
            final text =
                '--- ${comp.companyName} Login ---\nCompany Code: ${comp.companyCode}\nAdmin Email: $adminEmail\nPassword: $defaultPassword\n---------------------------------';
            Clipboard.setData(ClipboardData(text: text));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login credentials copied to clipboard!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCredentialRow(String label, String value, bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            SelectableText(
              value,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
              },
              child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2E65FF)),
            ),
          ],
        ),
      ],
    );
  }

  // Dialog to Edit Max Users limit for a company
  void _showEditUsersDialog(BuildContext context, AttendanceProvider provider, CompanyLicense comp) {
    final ctrl = TextEditingController(text: '${comp.maxActiveUsers}');
    showGlassDialog(
      context: context,
      title: 'Set Max User Limit',
      subtitle: comp.companyName,
      icon: Icons.people_alt_rounded,
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Allowed Active Employees',
          helperText: 'Number of workforce accounts this company can create',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        NeuButton(
          label: 'Save Limit',
          variant: NeuButtonVariant.primary,
          height: 38,
          onPressed: () async {
            final val = int.tryParse(ctrl.text.trim());
            if (val != null && val > 0) {
              Navigator.pop(context);
              final updated = comp.copyWith(maxActiveUsers: val);
              await provider.saveCompanyLicense(updated);
              _loadCompanies();
            }
          },
        ),
      ],
    );
  }

  // Dialog to Extend Subscription
  void _showExtendDialog(BuildContext context, AttendanceProvider provider, CompanyLicense comp) {
    int addMonths = 12;
    showGlassDialog(
      context: context,
      title: 'Extend Subscription',
      subtitle: comp.companyName,
      icon: Icons.more_time_rounded,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current expiry: ${DateFormat('yyyy-MM-dd').format(comp.subscriptionExpiresAt)}',
                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: addMonths,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Extension Period'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('+ 1 Month')),
                  DropdownMenuItem(value: 3, child: Text('+ 3 Months')),
                  DropdownMenuItem(value: 6, child: Text('+ 6 Months')),
                  DropdownMenuItem(value: 12, child: Text('+ 1 Year (12 Months)')),
                  DropdownMenuItem(value: 24, child: Text('+ 2 Years')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => addMonths = v);
                },
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        NeuButton(
          label: 'Extend',
          variant: NeuButtonVariant.primary,
          height: 38,
          onPressed: () async {
            Navigator.pop(context);
            final base = comp.isExpired ? DateTime.now() : comp.subscriptionExpiresAt;
            final newExpiry = DateTime(base.year, base.month + addMonths, base.day);
            final updated = comp.copyWith(
              subscriptionExpiresAt: newExpiry,
              isActive: true, // Auto-reactivate on renewal
            );
            await provider.saveCompanyLicense(updated);
            _loadCompanies();
          },
        ),
      ],
    );
  }
}
