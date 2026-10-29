import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_notification.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';
import '../screens/chat_room_screen.dart';
import '../screens/requests_screen.dart';
import '../services/web_notification_helper.dart';
import 'neu_button.dart';

void showWebNotificationsDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, anim, secondAnim) {
      return const WebNotificationsDialog();
    },
  );
}

class WebNotificationsDialog extends StatefulWidget {
  const WebNotificationsDialog({super.key});

  @override
  State<WebNotificationsDialog> createState() => _WebNotificationsDialogState();
}

class _WebNotificationsDialogState extends State<WebNotificationsDialog> {
  bool _showOnlyUnread = false;
  late bool _isPermissionGranted;
  late bool _isPermissionDenied;

  @override
  void initState() {
    super.initState();
    _isPermissionGranted = isWebNotificationPermissionGranted();
    _isPermissionDenied = getWebNotificationPermissionStatus() == 'denied';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final notifications = provider.notifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = notifications.where((n) => !n.isRead).length;

    final displayedNotifications = _showOnlyUnread
        ? notifications.where((n) => !n.isRead).toList()
        : notifications;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dialogBg = isDark
        ? const Color(0xFF161F2E).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.96);
    final dialogBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 36.0),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 480,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.78,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: dialogBg,
                  border: Border.all(
                    color: dialogBorder,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.45)
                          : const Color(0xFF0A2342).withValues(alpha: 0.12),
                      blurRadius: 36,
                      spreadRadius: -4,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                      child: Row(
                        children: [
                          // Signature Aqua-Cyan Bell Badge
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Color(0xFF0A2342),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Title and Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifications',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (unreadCount > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00BD96).withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$unreadCount new',
                                          style: const TextStyle(
                                            color: Color(0xFF00BD96),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        'No new alerts',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryTextColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Mark All Read Action (Stadium Pill)
                          if (unreadCount > 0) ...[
                            NeuButton(
                              label: 'Mark all read',
                              variant: NeuButtonVariant.whitePill,
                              height: 32,
                              fontSize: 11,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                provider.markAllNotificationsAsRead();
                              },
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Circular Frosted Close Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: secondaryTextColor,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Filter Switcher (When notifications exist)
                    if (notifications.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // All Notifications Tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (_showOnlyUnread) {
                                      HapticFeedback.selectionClick();
                                      setState(() => _showOnlyUnread = false);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: !_showOnlyUnread
                                          ? const LinearGradient(
                                              colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(50),
                                      boxShadow: !_showOnlyUnread
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      'All (${notifications.length})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: !_showOnlyUnread ? FontWeight.w800 : FontWeight.w600,
                                        color: !_showOnlyUnread
                                            ? const Color(0xFF0A2342)
                                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Unread Notifications Tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_showOnlyUnread) {
                                      HapticFeedback.selectionClick();
                                      setState(() => _showOnlyUnread = true);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: _showOnlyUnread
                                          ? const LinearGradient(
                                              colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(50),
                                      boxShadow: _showOnlyUnread
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      'Unread ($unreadCount)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _showOnlyUnread ? FontWeight.w800 : FontWeight.w600,
                                        color: _showOnlyUnread
                                            ? const Color(0xFF0A2342)
                                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const Divider(height: 1),

                    // Enable Desktop Notifications Card (Web only, shown only when not yet granted)
                    if (kIsWeb && !_isPermissionGranted)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isPermissionDenied
                              ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                              : (isDark
                                  ? const Color(0xFF00BD96).withValues(alpha: 0.10)
                                  : const Color(0xFF00E5CE).withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _isPermissionDenied
                                ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.35 : 0.25)
                                : const Color(0xFF00BD96).withValues(alpha: isDark ? 0.35 : 0.25),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (_isPermissionDenied
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF00BD96))
                                    .withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isPermissionDenied
                                    ? Icons.notifications_off_rounded
                                    : Icons.laptop_mac_rounded,
                                size: 18,
                                color: _isPermissionDenied
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF00BD96),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isPermissionDenied
                                        ? 'Notifications Blocked'
                                        : 'Browser Alerts',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: primaryTextColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _isPermissionDenied
                                        ? 'Allow alerts in your browser address bar settings'
                                        : 'Enable live desktop notifications for alerts',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isPermissionDenied)
                              NeuButton(
                                label: 'Enable',
                                variant: NeuButtonVariant.primary,
                                height: 32,
                                fontSize: 11,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  await requestWebNotificationPermission();
                                  if (mounted) {
                                    setState(() {
                                      _isPermissionGranted = isWebNotificationPermissionGranted();
                                      _isPermissionDenied = getWebNotificationPermissionStatus() == 'denied';
                                    });
                                  }
                                },
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'Dismiss',
                                onPressed: () {
                                  setState(() {
                                    _isPermissionGranted = true;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),

                    // Notifications List or Empty State
                    Flexible(
                      child: displayedNotifications.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 48.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFF1F5F9),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_none_rounded,
                                      size: 34,
                                      color: Color(0xFF00BD96),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _showOnlyUnread ? 'No unread notifications' : 'No notifications yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _showOnlyUnread
                                        ? 'You have read all notifications. Switch to "All" to view previous history.'
                                        : 'You will see new messages, shift updates, and requests here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: displayedNotifications.length,
                              separatorBuilder: (ctx, i) => Divider(
                                height: 1,
                                indent: 64,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                              itemBuilder: (ctx, index) {
                                final item = displayedNotifications[index];
                                return _buildNotificationTile(
                                  context,
                                  provider,
                                  item,
                                  isDark,
                                  primaryTextColor,
                                  secondaryTextColor,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AttendanceProvider provider,
    AppNotification item,
    bool isDark,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final timeStr = DateFormat('h:mm a').format(item.timestamp);
    final isChat = item.type == NotificationType.chat;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          provider.markNotificationAsRead(item.id);
          Navigator.of(context).pop();

          if (item.type == NotificationType.chat && item.relatedId != null) {
            final contact = provider.employees
                .where((e) => e.id.trim().toLowerCase() == item.relatedId!.trim().toLowerCase())
                .firstOrNull ??
                CompanyEmployee(
                  id: item.relatedId!,
                  name: item.title.replaceFirst('Message from ', ''),
                  email: '',
                  position: 'Management',
                  role: 'hr',
                  companyCode: provider.currentCompanyCode,
                );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomScreen(contact: contact),
              ),
            );
          } else if (item.type == NotificationType.request) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RequestsScreen(),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          color: !item.isRead
              ? const Color(0xFF00BD96).withValues(alpha: isDark ? 0.09 : 0.05)
              : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge with App Signature Theme
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isChat
                        ? const [Color(0xFF00F0D8), Color(0xFF00BD96)]
                        : const [Color(0xFF1E3DB8), Color(0xFF122684)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isChat
                          ? const Color(0xFF00E5CE).withValues(alpha: 0.3)
                          : const Color(0xFF1E3DB8).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isChat
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.description_outlined,
                  size: 18,
                  color: isChat ? const Color(0xFF0A2342) : Colors.white,
                ),
              ),
              const SizedBox(width: 14),

              // Title and Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: primaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Pulsing Aqua Unread Dot
              if (!item.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5CE),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00E5CE),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
