import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';
import '../widgets/avatar_image_helper.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/neu_button.dart';
import 'user_management_screen.dart';
import 'face_auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _copiedKey;

  void _copyToClipboard(String key, String title, String value) {
    if (value.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: value.trim()));
    HapticFeedback.lightImpact();
    setState(() => _copiedKey = key);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _copiedKey == key) {
        setState(() => _copiedKey = null);
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF0A2342), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title copied to clipboard!',
                style: const TextStyle(
                  color: Color(0xFF0A2342),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF00E5CE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getDepartmentName(AttendanceProvider provider) {
    final currentEmp = provider.currentEmployee;
    final structId = currentEmp?.structureId ?? provider.department;
    final structMatch = provider.structures.where((s) => s.id == structId).firstOrNull;
    if (structMatch != null) {
      return structMatch.name;
    }
    final dept = provider.department;
    if (dept.isNotEmpty && !dept.startsWith('struct_')) {
      return dept;
    }
    return currentEmp?.position.isNotEmpty == true ? currentEmp!.position : 'General';
  }

  String _getRoleLabel(String? role) {
    switch (role?.toLowerCase().trim()) {
      case 'super_admin':
      case 'superadmin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'hr':
        return 'HR Manager';
      case 'supervisor':
        return 'Supervisor';
      case 'employee':
      default:
        return 'Employee';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = provider.currentLanguageDirection == TextDirection.rtl;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final currentEmp = provider.currentEmployee;
    WorkShift? activeShift;
    if (currentEmp != null) {
      activeShift = provider.getShiftForDate(currentEmp, DateTime.now());
    }

    final departmentName = _getDepartmentName(provider);
    final roleLabel = _getRoleLabel(currentEmp?.role);

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // Ambient top decoration glow (Matching App Aqua Theme)
            Positioned(
              top: -120,
              left: 0,
              right: 0,
              height: 320,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      isDark
                          ? const Color(0xFF00F0D8).withValues(alpha: 0.12)
                          : const Color(0xFF00E5CE).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      // Modern Navigation Header
                      _buildHeader(context, provider, isDark, isRtl, primaryTextColor, secondaryTextColor),

                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hero Profile Card
                              _buildHeroProfileCard(
                                context,
                                provider,
                                isDark,
                                cardBg,
                                cardBorder,
                                primaryTextColor,
                                secondaryTextColor,
                                currentEmp,
                                activeShift,
                                departmentName,
                                roleLabel,
                              ),
                              const SizedBox(height: 24),

                              // Section: Personal & Employment Information
                              _buildSectionTitle(
                                icon: Icons.badge_outlined,
                                iconColor: const Color(0xFF00BD96),
                                title: provider.translate('personal_info'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildPersonalInfoCard(
                                context,
                                provider,
                                isDark,
                                cardBg,
                                cardBorder,
                                primaryTextColor,
                                secondaryTextColor,
                                currentEmp,
                                activeShift,
                                departmentName,
                                roleLabel,
                              ),
                              const SizedBox(height: 24),

                              // Section: Preferences (Language & Appearance)
                              _buildSectionTitle(
                                icon: Icons.tune_rounded,
                                iconColor: const Color(0xFF00BD96),
                                title: provider.translate('change_language'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildLanguageSelector(context, provider, isDark, cardBg, cardBorder),
                              const SizedBox(height: 24),

                              _buildSectionTitle(
                                icon: Icons.palette_outlined,
                                iconColor: const Color(0xFF00BD96),
                                title: provider.translate('theme'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildThemeSelector(context, provider, isDark, cardBg, cardBorder),
                              const SizedBox(height: 24),

                              // Section: Security
                              _buildSectionTitle(
                                icon: Icons.shield_outlined,
                                iconColor: const Color(0xFFEF4444),
                                title: provider.translate('security'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildFaceIdCard(
                                context,
                                provider,
                                isDark,
                                cardBg,
                                cardBorder,
                                primaryTextColor,
                                secondaryTextColor,
                                isRtl,
                              ),
                              const SizedBox(height: 12),
                              _buildSecurityCard(
                                context,
                                provider,
                                isDark,
                                cardBg,
                                cardBorder,
                                primaryTextColor,
                                secondaryTextColor,
                                isRtl,
                              ),
                              const SizedBox(height: 24),

                              // Administrative Access (If applicable)
                              if (currentEmp?.role == 'hr' || currentEmp?.role == 'admin') ...[
                                _buildSectionTitle(
                                  icon: Icons.admin_panel_settings_outlined,
                                  iconColor: const Color(0xFF1E3DB8),
                                  title: provider.translate('user_and_access_mgmt'),
                                  textColor: secondaryTextColor,
                                ),
                                const SizedBox(height: 12),
                                _buildUserManagementCard(
                                  context,
                                  isDark,
                                  cardBg,
                                  cardBorder,
                                  primaryTextColor,
                                  secondaryTextColor,
                                  isRtl,
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Account Switcher (Testing Mode)
                              _buildSectionTitle(
                                icon: Icons.swap_horiz_rounded,
                                iconColor: const Color(0xFF00BD96),
                                title: provider.translate('switch_account'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildAccountSwitcherCard(
                                context,
                                provider,
                                isDark,
                                cardBg,
                                cardBorder,
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const SizedBox(height: 28),

                              // Sign Out Button
                              _buildSignOutCard(context, provider, isDark),
                              const SizedBox(height: 20),
                            ],
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
    );
  }

  // --- HEADER APP BAR ---
  Widget _buildHeader(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    bool isRtl,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Frosted Back Button (Stadium shape)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                  color: primaryColor,
                  size: 18,
                ),
              ),
            ),
          ),

          // Title & Subtitle
          Column(
            children: [
              Text(
                provider.translate('profile'),
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                provider.translate('personal_info'),
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Quick Theme Toggle Button in Header (Stadium shape)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                provider.toggleTheme();
              },
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? const Color(0xFF00F0D8) : const Color(0xFF00BD96),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionTitle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // --- HERO PROFILE CARD ---
  Widget _buildHeroProfileCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
    CompanyEmployee? currentEmp,
    WorkShift? activeShift,
    String departmentName,
    String roleLabel,
  ) {
    final avatarProvider = getAvatarProvider(provider.avatarPath);
    final initials = provider.userName.trim().isNotEmpty
        ? provider.userName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'U';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Banner with App Signature Gradient (Royal Navy to Aqua Cyan)
          Stack(
            children: [
              Container(
                height: 95,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A2342),
                      Color(0xFF1330A6),
                      Color(0xFF00BD96),
                    ],
                  ),
                ),
              ),
              // Subtle background circle accents
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: 30,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ],
          ),

          // Avatar overlapping the banner
          Transform.translate(
            offset: const Offset(0, -48),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                        border: Border.all(
                          color: cardBg,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: avatarProvider != null
                          ? Image(
                              image: avatarProvider,
                              fit: BoxFit.cover,
                              width: 96,
                              height: 96,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Color(0xFF0A2342),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Color(0xFF0A2342),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),

                    // Camera floating action badge (Signature Aqua-Cyan stadium circle)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showPhotoPickerSheet(context, provider),
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: cardBg, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5CE).withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF0A2342),
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Full Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    provider.userName.isNotEmpty ? provider.userName : 'Employee',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Job Title
                Text(
                  provider.userTitle.isNotEmpty ? provider.userTitle : 'Staff Member',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),

                // Badges Row (Stadium capsules)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Role Badge (Signature Aqua-Cyan)
                    _buildPillBadge(
                      icon: Icons.shield_rounded,
                      label: roleLabel,
                      bgColor: const Color(0xFF00BD96).withValues(alpha: isDark ? 0.22 : 0.12),
                      fgColor: isDark ? const Color(0xFF00F0D8) : const Color(0xFF00897B),
                    ),

                    // Department Badge
                    _buildPillBadge(
                      icon: Icons.domain_rounded,
                      label: departmentName,
                      bgColor: const Color(0xFF1E3DB8).withValues(alpha: isDark ? 0.22 : 0.10),
                      fgColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3DB8),
                    ),

                    // Active Status Badge
                    _buildPillBadge(
                      icon: Icons.fiber_manual_record_rounded,
                      label: 'Active',
                      bgColor: const Color(0xFF10B981).withValues(alpha: isDark ? 0.20 : 0.10),
                      fgColor: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick Highlights Bottom Row
          Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      label: 'EMP ID',
                      value: provider.employeeId.isNotEmpty ? provider.employeeId : 'N/A',
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                    ),
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      label: 'SHIFT',
                      value: activeShift != null ? activeShift.name : 'Standard',
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                    ),
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      label: 'HOURS',
                      value: activeShift != null
                          ? '${activeShift.startTime} - ${activeShift.endTime}'
                          : '09:00 - 17:00',
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
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

  Widget _buildPillBadge({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color fgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fgColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: secondaryColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // --- PERSONAL INFO CARD ---
  Widget _buildPersonalInfoCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
    CompanyEmployee? currentEmp,
    WorkShift? activeShift,
    String departmentName,
    String roleLabel,
  ) {
    final shiftValue = activeShift != null
        ? '${activeShift.name} (${activeShift.startTime} - ${activeShift.endTime})'
        : 'Standard Shift (09:00 - 17:00)';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Full Name
          _buildInfoRow(
            context: context,
            icon: Icons.person_rounded,
            gradientColors: const [Color(0xFF00F0D8), Color(0xFF00BD96)],
            title: 'Full Name',
            value: provider.userName,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
          _buildDivider(isDark),

          // User / Employee ID
          _buildInfoRow(
            context: context,
            icon: Icons.badge_rounded,
            gradientColors: const [Color(0xFF1E3DB8), Color(0xFF122684)],
            title: provider.translate('user_id'),
            value: provider.employeeId,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trailing: _buildCopyButton('emp_id', provider.translate('user_id'), provider.employeeId, isDark),
          ),
          _buildDivider(isDark),

          // Email Address
          _buildInfoRow(
            context: context,
            icon: Icons.alternate_email_rounded,
            gradientColors: const [Color(0xFF00BD96), Color(0xFF00897B)],
            title: provider.translate('email'),
            value: provider.email,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trailing: _buildCopyButton('email', provider.translate('email'), provider.email, isDark),
          ),
          _buildDivider(isDark),

          // Department (Properly resolved!)
          _buildInfoRow(
            context: context,
            icon: Icons.domain_rounded,
            gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            title: provider.translate('department'),
            value: departmentName,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
          _buildDivider(isDark),

          // Job Position
          _buildInfoRow(
            context: context,
            icon: Icons.work_rounded,
            gradientColors: const [Color(0xFFF59E0B), Color(0xFFB45309)],
            title: provider.translate('position'),
            value: provider.position.isNotEmpty ? provider.position : provider.userTitle,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
          _buildDivider(isDark),

          // Current Shift & Schedule
          _buildInfoRow(
            context: context,
            icon: Icons.schedule_rounded,
            gradientColors: const [Color(0xFF00E5CE), Color(0xFF00BFA5)],
            title: 'Assigned Shift',
            value: shiftValue,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),

          // Phone Number (if available)
          if (currentEmp?.phoneNumber.isNotEmpty == true) ...[
            _buildDivider(isDark),
            _buildInfoRow(
              context: context,
              icon: Icons.phone_rounded,
              gradientColors: const [Color(0xFF14B8A6), Color(0xFF0F766E)],
              title: 'Phone Number',
              value: currentEmp!.phoneNumber,
              isDark: isDark,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              trailing: _buildCopyButton('phone', 'Phone Number', currentEmp.phoneNumber, isDark),
            ),
          ],

          _buildDivider(isDark),

          // Access Role
          _buildInfoRow(
            context: context,
            icon: Icons.admin_panel_settings_rounded,
            gradientColors: const [Color(0xFFEC4899), Color(0xFFBE185D)],
            title: provider.translate('role'),
            value: roleLabel,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
    );
  }

  Widget _buildCopyButton(String key, String title, String value, bool isDark) {
    final isCopied = _copiedKey == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copyToClipboard(key, title, value),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: isCopied
                ? const LinearGradient(
                    colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isCopied
                ? null
                : (isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: isCopied
                  ? const Color(0xFF00F0D8)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCopied ? Icons.check_rounded : Icons.copy_rounded,
                size: 13,
                color: isCopied ? const Color(0xFF0A2342) : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
              const SizedBox(width: 4),
              Text(
                isCopied ? 'Copied' : 'Copy',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isCopied ? const Color(0xFF0A2342) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    required String value,
    required bool isDark,
    required Color primaryColor,
    required Color secondaryColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          // Gradient Icon Container
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradientColors[0].withValues(alpha: isDark ? 0.25 : 0.12),
                  gradientColors[1].withValues(alpha: isDark ? 0.20 : 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: gradientColors[0].withValues(alpha: isDark ? 0.35 : 0.25),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: gradientColors[0],
              size: 19,
            ),
          ),
          const SizedBox(width: 14),

          // Titles and Values
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // --- LANGUAGE SELECTOR (Stadium Capsule Switcher matching Requests design) ---
  Widget _buildLanguageSelector(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'ku', 'name': 'کوردی'},
      {'code': 'ar', 'name': 'العربية'},
    ];

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        children: languages.map((lang) {
          final isSelected = provider.currentLanguage == lang['code'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                provider.setLanguage(lang['code']!);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_rounded, color: Color(0xFF0A2342), size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      lang['name']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF0A2342)
                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- THEME SELECTOR (Stadium Capsule Switcher matching Requests design) ---
  Widget _buildThemeSelector(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Light Mode Segment
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (provider.isDarkMode) {
                  HapticFeedback.selectionClick();
                  provider.toggleTheme();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: !provider.isDarkMode
                      ? const LinearGradient(
                          colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: !provider.isDarkMode
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.light_mode_rounded,
                      size: 17,
                      color: !provider.isDarkMode
                          ? const Color(0xFF0A2342)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.translate('light_mode'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: !provider.isDarkMode ? FontWeight.w800 : FontWeight.w600,
                        color: !provider.isDarkMode
                            ? const Color(0xFF0A2342)
                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dark Mode Segment
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!provider.isDarkMode) {
                  HapticFeedback.selectionClick();
                  provider.toggleTheme();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: provider.isDarkMode
                      ? const LinearGradient(
                          colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: provider.isDarkMode
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.dark_mode_rounded,
                      size: 17,
                      color: provider.isDarkMode
                          ? const Color(0xFF0A2342)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.translate('dark_mode'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: provider.isDarkMode ? FontWeight.w800 : FontWeight.w600,
                        color: provider.isDarkMode
                            ? const Color(0xFF0A2342)
                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FACE ID / BIOMETRIC AUTHENTICATION CARD ---
  Widget _buildFaceIdCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
    bool isRtl,
  ) {
    final currentEmp = provider.currentEmployee;
    final hasFaceId = currentEmp?.faceEmbedding != null && currentEmp!.faceEmbedding!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasFaceId
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00F0D8).withValues(alpha: isDark ? 0.25 : 0.15),
                      const Color(0xFF00BD96).withValues(alpha: isDark ? 0.20 : 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: const Color(0xFF00F0D8).withValues(alpha: isDark ? 0.5 : 0.35),
                  ),
                ),
                child: Icon(
                  hasFaceId ? Icons.face_retouching_natural : Icons.face_unlock_rounded,
                  color: const Color(0xFF00BD96),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.translate('face_id'),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasFaceId
                          ? provider.translate('face_id_enrolled')
                          : provider.translate('face_id_not_enrolled'),
                      style: TextStyle(
                        color: hasFaceId ? const Color(0xFF10B981) : secondaryColor,
                        fontSize: 12,
                        fontWeight: hasFaceId ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: hasFaceId
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasFaceId
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : (isDark ? Colors.white24 : Colors.black12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasFaceId ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 13,
                      color: hasFaceId ? const Color(0xFF10B981) : secondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasFaceId ? 'Active' : 'Disabled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasFaceId ? const Color(0xFF10B981) : secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            provider.translate('face_id_desc'),
            style: TextStyle(
              color: secondaryColor,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (!provider.isHRManager)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: secondaryColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.translate('only_hr_manage_face'),
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (hasFaceId)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FaceAuthScreen(
                            title: provider.translate('rescan_face_id'),
                            checkForDuplicate: true,
                            excludeEmployeeId: currentEmp.id,
                          ),
                        ),
                      );
                      if (result != null && result is List<double> && context.mounted) {
                        final duplicate = provider.findDuplicateFaceEmployee(result, excludeEmployeeId: currentEmp.id);
                        if (duplicate != null) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      provider.translate('duplicate_face_detected').replaceAll('{name}', duplicate.name),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFFEF4444),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                        await provider.updateEmployeeFaceEmbedding(currentEmp.id, result);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(child: Text(provider.translate('face_id_enrolled_success'))),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(provider.translate('rescan_face_id')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5CE),
                      foregroundColor: const Color(0xFF0A2342),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text(
                          provider.translate('remove_face_id'),
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                        content: Text(
                          'Are you sure you want to remove your Face ID? You will need your password to log in and Face ID will not be required for clock in/out.',
                          style: TextStyle(color: secondaryColor),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              Navigator.pop(ctx);
                              await provider.updateEmployeeFaceEmbedding(currentEmp.id, null);
                              if (context.mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(provider.translate('face_id_removed_success')),
                                    backgroundColor: Colors.blueGrey,
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              'Remove',
                              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  label: Text(
                    provider.translate('remove_face_id'),
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (currentEmp == null) return;
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FaceAuthScreen(
                        title: provider.translate('setup_face_id'),
                        checkForDuplicate: true,
                        excludeEmployeeId: currentEmp.id,
                      ),
                    ),
                  );
                  if (result != null && result is List<double> && context.mounted) {
                    final duplicate = provider.findDuplicateFaceEmployee(result, excludeEmployeeId: currentEmp.id);
                    if (duplicate != null) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  provider.translate('duplicate_face_detected').replaceAll('{name}', duplicate.name),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                    await provider.updateEmployeeFaceEmbedding(currentEmp.id, result);
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(child: Text(provider.translate('face_id_enrolled_success'))),
                          ],
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: Text(provider.translate('setup_face_id')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5CE),
                  foregroundColor: const Color(0xFF0A2342),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- SECURITY CARD (CHANGE PASSWORD) ---
  Widget _buildSecurityCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
    bool isRtl,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showChangePasswordDialog(context, provider),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00F0D8).withValues(alpha: isDark ? 0.25 : 0.12),
                      const Color(0xFF00BD96).withValues(alpha: isDark ? 0.20 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: const Color(0xFF00F0D8).withValues(alpha: isDark ? 0.45 : 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Color(0xFF00BD96),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.translate('change_pwd'),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.translate('update_pwd'),
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: secondaryColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- USER MANAGEMENT CARD (ADMIN / HR) ---
  Widget _buildUserManagementCard(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
    bool isRtl,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserManagementScreen()),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E3DB8).withValues(alpha: isDark ? 0.25 : 0.12),
                      const Color(0xFF122684).withValues(alpha: isDark ? 0.20 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: const Color(0xFF1E3DB8).withValues(alpha: isDark ? 0.4 : 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.manage_accounts_rounded,
                  color: Color(0xFF1E3DB8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage System Users & Roles',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Configure employee permissions and accounts',
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: secondaryColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ACCOUNT SWITCHER (TESTING) ---
  Widget _buildAccountSwitcherCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final currentId = provider.employeeId.trim();
    final currentEmp = provider.currentEmployee;

    // Deduplicate employees and ensure current active user is included
    final seenIds = <String>{};
    final distinctEmps = <CompanyEmployee>[];

    // Ensure active user is present in the list
    if (currentId.isNotEmpty) {
      seenIds.add(currentId);
      distinctEmps.add(
        currentEmp ??
            CompanyEmployee(
              id: currentId,
              name: provider.userName.isNotEmpty ? provider.userName : 'Admin',
              email: provider.email,
              position: provider.position.isNotEmpty ? provider.position : 'Administrator',
              role: provider.userRole.isNotEmpty ? provider.userRole : 'admin',
              companyCode: provider.currentCompanyCode,
            ),
      );
    }

    for (final emp in provider.employees) {
      final empId = emp.id.trim();
      if (empId.isNotEmpty && seenIds.add(empId)) {
        distinctEmps.add(emp);
      }
    }

    // Determine a guaranteed safe selected value
    final effectiveValue = distinctEmps.any((e) => e.id.trim() == currentId)
        ? currentId
        : (distinctEmps.isNotEmpty ? distinctEmps.first.id.trim() : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          dropdownColor: cardBg,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(
            Icons.unfold_more_rounded,
            color: secondaryColor,
          ),
          style: TextStyle(
            color: primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: distinctEmps.map((emp) {
            final role = _getRoleLabel(emp.role);
            final isCurrent = emp.id.trim() == effectiveValue;
            return DropdownMenuItem<String>(
              value: emp.id.trim(),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isCurrent
                          ? const LinearGradient(
                              colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                            )
                          : null,
                      color: isCurrent
                          ? null
                          : (isDark ? Colors.white12 : const Color(0xFFF1F5F9)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFF0A2342)
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${emp.name} ($role)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null && val != provider.employeeId) {
              HapticFeedback.mediumImpact();
              provider.switchProfile(val);
            }
          },
        ),
      ),
    );
  }

  // --- SIGN OUT BUTTON ---
  Widget _buildSignOutCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _confirmSignOut(context, provider, isDark),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                  : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.translate('sign_out'),
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.translate('sign_out_confirm_subtitle'),
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF87171).withValues(alpha: 0.7) : const Color(0xFFB91C1C).withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AttendanceProvider provider, bool isDark) {
    showGlassDialog(
      context: context,
      title: provider.translate('sign_out'),
      subtitle: provider.translate('sign_out_confirm_subtitle'),
      icon: Icons.logout_rounded,
      iconBackgroundColor: const [Color(0xFFEF4444), Color(0xFFDC2626)],
      content: Text(
        provider.translate('sign_out_confirm_desc'),
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      actions: [
        NeuButton(
          label: provider.translate('cancel'),
          variant: NeuButtonVariant.whitePill,
          height: 38,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        NeuButton(
          label: provider.translate('sign_out'),
          variant: NeuButtonVariant.danger,
          height: 38,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          onPressed: () {
            Navigator.pop(context);
            provider.logout();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
    );
  }

  Future<void> _processAndSaveImage(
    XFile image,
    AttendanceProvider provider,
    BuildContext context,
  ) async {
    try {
      final bytes = await image.readAsBytes();
      String base64String;
      try {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final resized = img.copyResize(decoded, width: 256, height: 256);
          final compressed = img.encodeJpg(resized, quality: 80);
          base64String = base64Encode(compressed);
        } else {
          base64String = base64Encode(bytes);
        }
      } catch (_) {
        base64String = base64Encode(bytes);
      }

      await provider.updateProfileImage(base64String);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: Color(0xFF00BD96),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // --- PHOTO PICKER SHEET ---
  void _showPhotoPickerSheet(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how you want to update your profile photo',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Camera option (Signature Aqua-Cyan)
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(
                              source: ImageSource.camera,
                              maxWidth: 512,
                              maxHeight: 512,
                              imageQuality: 85,
                            );
                            if (image != null && context.mounted) {
                              await _processAndSaveImage(image, provider, context);
                            }
                          } catch (e) {
                            debugPrint('Camera error: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Camera not supported or available on this device. Please choose from gallery.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF161F2E)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              child: const Icon(
                                Icons.photo_camera_rounded,
                                color: Color(0xFF0A2342),
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Take Photo',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Gallery option (Royal Navy)
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 512,
                            maxHeight: 512,
                            imageQuality: 85,
                          );
                          if (image != null && context.mounted) {
                            await _processAndSaveImage(image, provider, context);
                          }
                        } catch (e) {
                          debugPrint('Gallery picker error: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to pick image: $e'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF161F2E)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF1E3DB8), Color(0xFF122684)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.photo_library_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Choose Gallery',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Remove Photo Option (if user has avatar)
              if (provider.avatarPath != null && provider.avatarPath!.isNotEmpty) ...[
                const SizedBox(height: 14),
                NeuButton(
                  onPressed: () async {
                    await provider.updateProfileImage(null);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile picture removed!'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: 'Remove Photo',
                  variant: NeuButtonVariant.danger,
                  height: 44,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

  // --- CHANGE PASSWORD DIALOG ---
  void _showChangePasswordDialog(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    showGlassDialog(
      context: context,
      title: provider.translate('change_pwd'),
      subtitle: provider.translate('change_pwd_subtitle'),
      icon: Icons.lock_reset_rounded,
      iconBackgroundColor: const [Color(0xFF00F0D8), Color(0xFF00BD96)],
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: newPasswordController,
                obscureText: obscureNew,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: '${provider.translate('password')} *',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                  hintText: provider.translate('new_pwd_hint'),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white60, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white60,
                      size: 18,
                    ),
                    onPressed: () {
                      setModalState(() => obscureNew = !obscureNew);
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00F0D8), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                  hintText: 'Re-enter your new password',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                  prefixIcon: const Icon(Icons.verified_user_outlined, color: Colors.white60, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white60,
                      size: 18,
                    ),
                    onPressed: () {
                      setModalState(() => obscureConfirm = !obscureConfirm);
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00F0D8), width: 1.5),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        NeuButton(
          label: provider.translate('cancel'),
          variant: NeuButtonVariant.whitePill,
          height: 38,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        NeuButton(
          label: provider.translate('save'),
          variant: NeuButtonVariant.primary,
          height: 38,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          onPressed: () {
            final newPass = newPasswordController.text.trim();
            final confirmPass = confirmPasswordController.text.trim();

            if (newPass.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a new password'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
              return;
            }
            if (newPass.length < 6) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password must be at least 6 characters long'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
              return;
            }
            if (newPass != confirmPass) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Passwords do not match'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
              return;
            }

            provider.updatePassword(newPass);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.translate('pwd_success')),
                backgroundColor: const Color(0xFF00BD96),
              ),
            );
          },
        ),
      ],
    );
  }
}
