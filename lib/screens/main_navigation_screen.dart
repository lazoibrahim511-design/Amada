import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'payroll_screen.dart';
import 'requests_screen.dart';
import 'clock_screen.dart';
import 'hr_management_screen.dart';
import 'profile_screen.dart';
import 'user_management_screen.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/attendance_provider.dart';
import 'chat_list_screen.dart';
import '../widgets/web_notifications_dialog.dart';
import '../widgets/company_settings_dialog.dart';
import 'super_admin_screen.dart';
import 'ai_assistant_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialTab;
  const MainNavigationScreen({super.key, this.initialTab = 0});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;
  late final PageController _pageController;
  bool _isPageAnimating = false;

  // Let's create an list of pages. We can add a Clock tab that is a dedicated view,
  // or we can reuse/navigate as required.
  // The pages corresponding to tabs: Home, Clock, History, Payroll, Requests.
  // Wait! In the screenshots, the bottom tabs are: Home, Clock, History, Payroll, Requests.
  // Let's implement all of them!
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _pageController = PageController(
      initialPage: widget.initialTab.clamp(0, 4),
    );
    _pages = [
      const HomeScreen(),
      const ClockScreen(),
      const HistoryScreen(),
      const PayrollScreen(),
      const RequestsScreen(),
      // HR Tabs Embedded
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.structures),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.shifts),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.groups),
      const UserManagementScreen(isEmbedded: true),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.holidays),

      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.locations),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.payroll),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.dailyReport),
      const RequestsScreen(initialSubordinateTab: true), // index 13: Approvals
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.device), // index 14: Device (ZKTeco)
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.periodicReport), // index 15: Periodic Report
      const AiAssistantScreen(isEmbedded: true), // index 16: AI Assistant
    ];
    _loadSavedTab();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTab = prefs.getInt('main_nav_tab');
      if (savedTab != null && savedTab >= 0 && savedTab < _pages.length) {
        if (mounted) {
          setState(() {
            _selectedIndex = savedTab;
          });
          if (_pageController.hasClients && savedTab < 5) {
            _pageController.jumpToPage(savedTab);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load saved tab: $e');
    }
  }

  void onTabSelected(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('main_nav_tab', index);
    } catch (e) {
      debugPrint('Failed to save tab: $e');
    }

    if (!kIsWeb && _pageController.hasClients && index < 5) {
      if ((_pageController.page?.round() ?? _selectedIndex) != index) {
        _isPageAnimating = true;
        try {
          await _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        } finally {
          _isPageAnimating = false;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        extendBody: true, // Allows the body to flow underneath the bottom bar
        body: Container(
          decoration: BoxDecoration(
            gradient: !isDark
                ? const LinearGradient(
                    colors: [Color(0xFFFCFDFD), Color(0xFFEDF2FE), Color(0xFFE0EAFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isDark ? const Color(0xFF0F172A) : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;
              final isMobileApp = !kIsWeb && !isDesktop;

              // Ensure PageView stays synchronized if returning from embedded desktop tabs
              if (isMobileApp && _selectedIndex < 5) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _pageController.hasClients && !_isPageAnimating) {
                    if (_pageController.page?.round() != _selectedIndex) {
                      _pageController.jumpToPage(_selectedIndex);
                    }
                  }
                });
              }

              return Stack(
                children: [
                  if (isDesktop)
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          _buildWebHeader(provider, isDark),
                          Expanded(
                            child: IndexedStack(index: _selectedIndex, children: _pages),
                          ),
                        ],
                      ),
                    )
                  else if (isMobileApp && _selectedIndex < 5)
                    // Fluid, interactive swipable PageView only in mobile app
                    SafeArea(
                      bottom: false,
                      child: PageView(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (pageIndex) {
                          if (!_isPageAnimating && _selectedIndex != pageIndex) {
                            setState(() {
                              _selectedIndex = pageIndex;
                            });
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setInt('main_nav_tab', pageIndex);
                            }).catchError((_) {});
                          }
                        },
                        children: [
                          _KeepAlivePage(child: _pages[0]),
                          _KeepAlivePage(child: _pages[1]),
                          _KeepAlivePage(child: _pages[2]),
                          _KeepAlivePage(child: _pages[3]),
                          _KeepAlivePage(child: _pages[4]),
                        ],
                      ),
                    )
                  else
                    // Fallback / Web mobile / Embedded HR tabs
                    SafeArea(
                      bottom: false,
                      child: IndexedStack(index: _selectedIndex, children: _pages),
                    ),

                  // Custom Glassmorphic Bottom Navigation Bar
                  if (!isDesktop)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomNavigationBar(provider),
                    ),

                  // Glassmorphic Loading Overlay removed per user request
                ],
              );
            },
          ),
        ),
      ),
    );
  }



  Widget _buildWebHeader(AttendanceProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
            children: [
              // Logo
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF20B3A7).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    provider.currentCompanyCode == 'all'
                        ? 'Master Network'
                        : (provider.companyProfile?.name.isNotEmpty == true
                            ? provider.companyProfile!.name
                            : 'Amada'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (provider.isSuperAdmin) ...[
                const SizedBox(width: 14),
                _buildSuperAdminCompanySwitcher(context, provider, isDark),
              ],
              const SizedBox(width: 24),
              
              // Center Navigation Links
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopNavItem(0, provider.translate('home'), Icons.home_filled),
                      if (!kIsWeb) _buildTopNavItem(1, provider.translate('clock'), Icons.access_time_filled),
                      _buildTopNavItem(2, provider.translate('history'), Icons.history),
                      _buildTopNavItem(3, provider.translate('payroll'), Icons.attach_money),
                      _buildTopNavItem(4, provider.translate('requests'), Icons.description),
                      
                      // Dropdown for HR Admin if they have access
                      if (provider.currentEmployee?.role == 'hr' || provider.currentEmployee?.role == 'admin' || provider.canEditCompanyInfo)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: PopupMenuButton<int>(
                              offset: const Offset(0, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              elevation: 8,
                              onSelected: (value) => onTabSelected(value),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                  '${provider.translate('hr_admin')} ▾',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              itemBuilder: (context) => [
                                _buildPopupMenuItem(8, provider.translate('user_management'), Icons.manage_accounts),
                                _buildPopupMenuItem(13, provider.translate('approvals'), Icons.how_to_reg),
                                _buildPopupMenuItem(5, provider.translate('structures'), Icons.business),
                                _buildPopupMenuItem(6, provider.translate('shifts'), Icons.access_time),
                                _buildPopupMenuItem(7, provider.translate('groups'), Icons.people),
                                _buildPopupMenuItem(9, provider.translate('holidays'), Icons.event_available),
                                _buildPopupMenuItem(10, provider.translate('locations'), Icons.location_on),
                                _buildPopupMenuItem(11, provider.translate('hr_payroll'), Icons.attach_money),
                                _buildPopupMenuItem(12, provider.translate('daily_report'), Icons.bar_chart),
                                _buildPopupMenuItem(15, provider.translate('periodic_report'), Icons.assessment_outlined),
                                _buildPopupMenuItem(14, provider.translate('device'), Icons.fingerprint),
                                _buildPopupMenuItem(16, provider.translate('ai_assistant'), Icons.auto_awesome),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // AI Advisor Quick Button
              if (provider.currentEmployee?.role == 'hr' || provider.currentEmployee?.role == 'admin' || provider.canEditCompanyInfo) ...[
                Tooltip(
                  message: provider.translate('ai_assistant'),
                  child: InkWell(
                    onTap: () => onTabSelected(16),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              // Chat Button
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 700),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Navigator(
                            onGenerateRoute: (settings) {
                              return MaterialPageRoute(
                                builder: (context) => const ChatListScreen(),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: isDark ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Notification
              InkWell(
                onTap: () {
                  showWebNotificationsDialog(context);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF64748B),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Settings button (Super Admin only)
              if (provider.canEditCompanyInfo) ...[
                InkWell(
                  onTap: () {
                    showCompanySettingsDialog(context);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: isDark ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Theme toggle
              InkWell(
                onTap: () => provider.toggleTheme(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 20,
                    color: isDark ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Profile
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    backgroundImage: provider.avatarPath != null ? AssetImage(provider.avatarPath!) : null,
                    child: provider.avatarPath == null
                        ? Icon(Icons.person, size: 20, color: isDark ? Colors.white70 : const Color(0xFF3B82F6))
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  PopupMenuItem<int> _buildPopupMenuItem(int value, String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildTopNavItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isSelected) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isDark ? const Color(0xFF111827) : Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => onTabSelected(index),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
  }





  Widget _buildBottomNavigationBar(AttendanceProvider provider) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 16,
            bottom: bottomPadding > 0 ? bottomPadding + 8 : 16,
          ),
          decoration: BoxDecoration(
            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.12)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border.all(
              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.2)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.home_outlined,
                Icons.home,
                provider.translate('home'),
              ),
              if (!kIsWeb)
                _buildNavItem(
                  1,
                  Icons.access_time_outlined,
                  Icons.access_time_filled,
                  provider.translate('clock'),
                ),
              _buildNavItem(
                2,
                Icons.history_outlined,
                Icons.history,
                provider.translate('history'),
              ),
              _buildNavItem(
                3,
                Icons.attach_money_outlined,
                Icons.attach_money,
                provider.translate('payroll'),
              ),
              _buildNavItem(
                4,
                Icons.description_outlined,
                Icons.description,
                provider.translate('requests'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label,
  ) {
    final isSelected = _selectedIndex == index;
    final icon = isSelected ? filledIcon : outlineIcon;

    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
            child: child,
          ),
        ),
        child: isSelected
            ? Container(
                key: ValueKey('nav_sel_$index'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.15)),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), size: 20),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                key: ValueKey('nav_unsel_$index'),
                width: 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)), size: 20),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSuperAdminCompanySwitcher(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final isAll = provider.currentCompanyCode == 'all';
    final currentLic = provider.allCompanies
        .where((c) =>
            c.companyCode.toLowerCase() ==
            provider.currentCompanyCode.toLowerCase())
        .firstOrNull;
    final currentName = isAll
        ? provider.translate('all_companies_master')
        : (currentLic?.companyName.isNotEmpty == true
            ? currentLic!.companyName
            : (provider.companyProfile?.name.isNotEmpty == true
                ? provider.companyProfile!.name
                : provider.currentCompanyCode.toUpperCase()));

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 10,
        tooltip: provider.translate('switch_company'),
        onSelected: (val) async {
          if (val == '__saas_portal__') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SuperAdminScreen()),
            );
          } else if (val != provider.currentCompanyCode) {
            await provider.setCompanyCode(val);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    val == 'all'
                        ? provider.translate('all_companies_master')
                        : 'Workspace: ${val.toUpperCase()}',
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isAll
                ? const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.25 : 0.12)
                : const Color(0xFF00E5CE).withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAll
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                  : const Color(0xFF00E5CE).withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAll ? Icons.public : Icons.domain,
                size: 15,
                color: isAll ? const Color(0xFF8B5CF6) : const Color(0xFF00E5CE),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  currentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
        itemBuilder: (ctx) {
          final items = <PopupMenuEntry<String>>[];

          // Header
          items.add(
            PopupMenuItem<String>(
              enabled: false,
              height: 32,
              child: Text(
                provider.translate('switch_company').toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ),
          );

          // All Companies (Master View)
          items.add(
            PopupMenuItem<String>(
              value: 'all',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.public, color: Color(0xFF8B5CF6), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.translate('all_companies_master'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isAll ? FontWeight.w800 : FontWeight.w600,
                            color: isAll
                                ? const Color(0xFF8B5CF6)
                                : (isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
                        ),
                        Text(
                          provider.translate('master_network_view'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAll)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF8B5CF6), size: 16),
                ],
              ),
            ),
          );

          items.add(const PopupMenuDivider(height: 12));

          // Companies list
          if (provider.allCompanies.isEmpty) {
            items.add(
              PopupMenuItem<String>(
                value: 'amada',
                child: Row(
                  children: [
                    const Icon(Icons.domain, size: 18, color: Color(0xFF00E5CE)),
                    const SizedBox(width: 10),
                    const Text('Amada Trading (amada)'),
                    if (provider.currentCompanyCode == 'amada')
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.check_circle_rounded, color: Color(0xFF00E5CE), size: 16),
                      ),
                  ],
                ),
              ),
            );
          } else {
            for (final lic in provider.allCompanies) {
              final isCurrent =
                  lic.companyCode.toLowerCase() == provider.currentCompanyCode.toLowerCase();
              items.add(
                PopupMenuItem<String>(
                  value: lic.companyCode,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF00E5CE).withValues(alpha: 0.15)
                              : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.domain,
                          size: 18,
                          color: isCurrent
                              ? const Color(0xFF00E5CE)
                              : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              lic.companyName.isNotEmpty
                                  ? lic.companyName
                                  : lic.companyCode.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                color: isCurrent
                                    ? const Color(0xFF00E5CE)
                                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
                              ),
                            ),
                            Text(
                              'Code: ${lic.companyCode} • ${lic.planName.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF00E5CE), size: 16),
                    ],
                  ),
                ),
              );
            }
          }

          items.add(const PopupMenuDivider(height: 12));

          // Direct jump to Master SaaS Portal
          items.add(
            PopupMenuItem<String>(
              value: '__saas_portal__',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Color(0xFFF59E0B), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    provider.translate('super_admin_portal'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          );

          return items;
        },
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

