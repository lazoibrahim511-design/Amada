import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_calendar.dart';
import '../widgets/stat_card.dart';
import '../widgets/avatar_image_helper.dart';
import 'profile_screen.dart';
import 'hr_management_screen.dart';
import 'chat_list_screen.dart';
import 'face_auth_screen.dart';
import '../widgets/company_settings_dialog.dart';
import 'super_admin_screen.dart';
import 'ai_assistant_screen.dart';

class HomeScreenMobile extends StatelessWidget {
  const HomeScreenMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayStr = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background gradient is on the shell
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.translate('welcome_back'),
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.userName,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  // Header Buttons
                  Row(
                    children: [
                      if (provider.isSuperAdmin) ...[
                        _buildHeaderButton(
                          context,
                          icon: provider.currentCompanyCode == 'all'
                              ? Icons.public
                              : Icons.domain,
                          onTap: () =>
                              _showMobileCompanySwitcher(context, provider),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (provider.canEditCompanyInfo) ...[
                        _buildHeaderButton(context, 
                          icon: Icons.settings_outlined,
                          onTap: () {
                            showCompanySettingsDialog(context);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildHeaderButton(context, 
                          icon: Icons.admin_panel_settings_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const HrManagementScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (provider.currentEmployee?.role == 'hr' || provider.currentEmployee?.role == 'admin' || provider.canEditCompanyInfo) ...[
                        _buildHeaderButton(context, 
                          icon: Icons.auto_awesome,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AiAssistantScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                      ],
                      _buildHeaderButton(context, 
                        icon: Icons.chat_bubble_outline_rounded,
                        hasBadge: provider.hasUnreadMessages,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatListScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderButton(context, 
                        icon: Icons.person_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                        isProfile: true,
                        avatarUrl: provider.avatarPath,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Title
              Center(
                child: Text(
                  todayStr,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Clock Status Card
              _buildClockStatusCard(context, provider),
              const SizedBox(height: 20),

              // Calendar Card
              const CustomCalendar(),
              const SizedBox(height: 20),

              // Statistics Grid
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: MediaQuery.of(context).size.width > 800 ? 1.5 : 1.15,
                children: [
                  StatCard(
                    icon: Icons.access_time_outlined,
                    value: provider.weeklyHours.toStringAsFixed(1),
                    label: provider.translate('weekly_hours'),
                    accentColor: const Color(0xFF38BDF8), // Sky blue
                  ),
                  StatCard(
                    icon: Icons.attach_money_outlined,
                    value:
                        '\$${NumberFormat('#,##0').format(provider.monthlyEarnings)}',
                    label: provider.translate('monthly_earnings'),
                    accentColor: const Color(0xFF10B981), // Emerald green
                  ),
                  StatCard(
                    icon: Icons.calendar_today_outlined,
                    value: '${provider.daysWorked}',
                    label: provider.translate('days_worked'),
                    accentColor: const Color(0xFF8B5CF6), // Purple / Violet
                  ),
                  StatCard(
                    icon: Icons.trending_up_outlined,
                    value: '${provider.overtimeHours.toStringAsFixed(1)}h',
                    label: provider.translate('overtime'),
                    accentColor: const Color(0xFFF59E0B), // Amber / Warm Orange
                  ),
                  StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    value: '${provider.currentEmployee?.annualLeaveBalance ?? 0}h',
                    label: provider.translate('remain_balance'),
                    accentColor: const Color(0xFF06B6D4), // Cyan / Teal
                  ),
                ],
              ),
              // Extra padding to scroll above bottom nav bar
              const SizedBox(height: 100),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton(BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool isProfile = false,
    String? avatarUrl,
    bool hasBadge = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarProvider = isProfile ? getAvatarProvider(avatarUrl) : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          image: avatarProvider != null
              ? DecorationImage(
                  image: avatarProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (avatarProvider == null)
              Icon(icon, color: isDark ? Colors.white : const Color(0xFF1E293B), size: 20),
            if (hasBadge)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockStatusCard(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasClockedIn = provider.isClockedIn;
    bool isProcessing = false;

    return GlassContainer(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.translate('current_status'),
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasClockedIn
                        ? provider.translate('clocked_in')
                        : provider.translate('clocked_out'),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final zones = provider.getAllowedZones();
                      if (zones.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_off_outlined, size: 14, color: Colors.redAccent),
                              const SizedBox(width: 4),
                              Text(
                                provider.translate('location_outside_range'),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
              // Clock Icon container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.access_time,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Buttons
          StatefulBuilder(
            builder: (context, setState) {
              Widget buildButton({
                required String label,
                required bool isActive,
                required bool isClockIn,
                required Future<void> Function() onTap,
              }) {
                final isDark = Theme.of(context).brightness == Brightness.dark;

                late final Gradient bgGradient;
                late final Color txtColor;
                late final Color glow;
                late final Color border;

                if (isActive) {
                  if (isClockIn) {
                    bgGradient = LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF00F0D8), Color(0xFF00CBB4)]
                          : const [Color(0xFF00E5CE), Color(0xFF00BFA5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    );
                    txtColor = const Color(0xFF0A2342);
                    glow = isDark
                        ? const Color(0xFF00F0D8).withValues(alpha: 0.38)
                        : const Color(0xFF00E5CE).withValues(alpha: 0.32);
                    border = const Color(0xFF80FFF3).withValues(alpha: isDark ? 0.6 : 0.45);
                  } else {
                    bgGradient = const LinearGradient(
                      colors: [Color(0xFFFF4B4B), Color(0xFFE11D48)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    );
                    txtColor = Colors.white;
                    glow = const Color(0xFFEF4444).withValues(alpha: 0.38);
                    border = const Color(0xFFFDA4AF).withValues(alpha: 0.35);
                  }
                } else {
                  bgGradient = LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF161F2E)]
                        : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  );
                  txtColor = isDark ? Colors.white38 : Colors.black38;
                  glow = Colors.transparent;
                  border = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: (isActive && !isProcessing)
                        ? () async {
                            setState(() {
                              isProcessing = true;
                            });
                            try {
                              await onTap();
                            } finally {
                              if (context.mounted) {
                                setState(() {
                                  isProcessing = false;
                                });
                              }
                            }
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: bgGradient,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: border, width: 1.2),
                        boxShadow: (isActive && !isProcessing)
                            ? [
                                BoxShadow(
                                  color: glow,
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: isClockIn ? 0.3 : 0.15),
                                  blurRadius: 2,
                                  offset: const Offset(0, -1),
                                ),
                              ]
                            : const [],
                      ),
                      child: isProcessing && isActive
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(txtColor),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: txtColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              }

              if (kIsWeb) return const SizedBox.shrink();

              return Row(
                children: [
                  buildButton(
                    label: provider.translate('clock_in_btn'),
                    isActive: !hasClockedIn,
                    isClockIn: true,
                    onTap: () async {
                      final locError = await provider.verifyLocation();
                      if (locError != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(locError),
                            backgroundColor: const Color(0xFFFF5C5C),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        return;
                      }

                      if (provider.currentEmployee?.faceEmbedding != null) {
                        if (!context.mounted) return;
                        final success = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FaceAuthScreen(
                              targetEmbedding: provider.currentEmployee!.faceEmbedding,
                            ),
                          ),
                        );
                        
                        if (success != true) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(provider.translate('face_auth_failed')),
                                backgroundColor: Colors.redAccent,
                              )
                            );
                          }
                          return;
                        }
                      }

                      final error = await provider.clockIn();
                      if (!context.mounted) return;
                      if (error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.translate('success_clock_in')),
                            backgroundColor: const Color(0xFF2EBD96),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: const Color(0xFFFF5C5C),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(width: 16),
                  buildButton(
                    label: provider.translate('clock_out_btn'),
                    isActive: true, // Always active so they can clock out if they forgot check in
                    isClockIn: false,
                    onTap: () async {
                      final locError = await provider.verifyLocation();
                      if (locError != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(locError),
                            backgroundColor: const Color(0xFFFF5C5C),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        return;
                      }

                      if (provider.currentEmployee?.faceEmbedding != null) {
                        if (!context.mounted) return;
                        final success = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FaceAuthScreen(
                              targetEmbedding: provider.currentEmployee!.faceEmbedding,
                            ),
                          ),
                        );
                        
                        if (success != true) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(provider.translate('face_auth_failed')),
                                backgroundColor: Colors.redAccent,
                              )
                            );
                          }
                          return;
                        }
                      }

                      final result = await provider.clockOut();
                      if (!context.mounted) return;
                      if (result == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.translate('success_clock_out')),
                            backgroundColor: const Color(0xFF2EBD96),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (result == 'missed_checkin') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.translate('missed_check_in_msg')),
                            backgroundColor: const Color(0xFFFFA726), // Orange warning
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result),
                            backgroundColor: const Color(0xFFFF5C5C),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showMobileCompanySwitcher(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAll = provider.currentCompanyCode == 'all';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.hub, color: Color(0xFF8B5CF6), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        provider.translate('switch_company'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Master Network View
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.public, color: Color(0xFF8B5CF6)),
                    ),
                    title: Text(
                      provider.translate('all_companies_master'),
                      style: TextStyle(
                        fontWeight: isAll ? FontWeight.bold : FontWeight.w600,
                        color: isAll
                            ? const Color(0xFF8B5CF6)
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    subtitle: Text(
                      provider.translate('master_network_view'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: isAll
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF8B5CF6))
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await provider.setCompanyCode('all');
                    },
                  ),
                  const Divider(),
                  // Companies
                  if (provider.allCompanies.isEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5CE).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.domain, color: Color(0xFF00E5CE)),
                      ),
                      title: const Text('Amada Trading (amada)'),
                      trailing: provider.currentCompanyCode == 'amada'
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF00E5CE))
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await provider.setCompanyCode('amada');
                      },
                    )
                  else
                    ...provider.allCompanies.map((lic) {
                      final isCurrent = lic.companyCode.toLowerCase() ==
                          provider.currentCompanyCode.toLowerCase();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF00E5CE).withValues(alpha: 0.15)
                                : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.domain,
                            color: isCurrent
                                ? const Color(0xFF00E5CE)
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                        title: Text(
                          lic.companyName.isNotEmpty
                              ? lic.companyName
                              : lic.companyCode.toUpperCase(),
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                            color: isCurrent
                                ? const Color(0xFF00E5CE)
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        subtitle: Text(
                          'Code: ${lic.companyCode} • ${lic.planName.toUpperCase()}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF00E5CE))
                            : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await provider.setCompanyCode(lic.companyCode);
                        },
                      );
                    }),
                  const Divider(),
                  // SaaS portal link
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                          color: Color(0xFFF59E0B)),
                    ),
                    title: Text(
                      provider.translate('super_admin_portal'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFF59E0B)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SuperAdminScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
