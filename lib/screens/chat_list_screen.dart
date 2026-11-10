import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../widgets/avatar_image_helper.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AttendanceProvider>(context, listen: false)
            .loadChatsForCurrentUser();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = provider.currentEmployee;

    // Resolve contacts based on unified provider logic
    List<CompanyEmployee> contacts = [];
    String screenTitle = provider.translate('chat');

    if (currentUser != null) {
      contacts = provider.getChatContacts(currentUser);
      if (currentUser.role == 'supervisor' || currentUser.role == 'hr') {
        screenTitle = provider.translate('subordinate_chat');
      } else {
        screenTitle = provider.translate('supervisor_chat');
      }
    }

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
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
          child: SafeArea(
            child: Column(
              children: [
                // Custom Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBackButton(context),
                      Text(
                        screenTitle,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                // Chat List
                Expanded(
                  child: contacts.isEmpty
                      ? _buildEmptyState(provider)
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 10.0,
                          ),
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final contact = contacts[index];
                            final messages = provider.getMessagesWith(
                              contact.id,
                            );
                            final lastMsg = messages.isNotEmpty
                                ? messages.last
                                : null;

                            // Check if there are pending requests from this subordinate (only relevant for supervisors)
                            int pendingRequestCount = 0;
                            if (currentUser?.role == 'supervisor' ||
                                currentUser?.role == 'hr') {
                              for (var msg in messages) {
                                if (msg.isRequestCard &&
                                    msg.requestId != null) {
                                  final req = provider.getRequestById(
                                    contact.id,
                                    msg.requestId!,
                                  );
                                  if (req != null && req.status == 'Pending') {
                                    pendingRequestCount++;
                                  }
                                }
                              }
                            }

                            final unreadCount = provider.getUnreadCountForContact(contact.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: unreadCount > 0
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                        : (isDark ? Colors.white12 : Colors.black12),
                                    width: unreadCount > 0 ? 1.5 : 1,
                                  ),
                                  boxShadow: isDark ? [] : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                padding: EdgeInsets.zero,
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  onTap: () {
                                    provider.markMessagesAsRead(contact.id);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ChatRoomScreen(contact: contact),
                                      ),
                                    );
                                  },
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _buildAvatar(contact),
                                      if (unreadCount > 0)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEF4444),
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 16,
                                              minHeight: 16,
                                            ),
                                            child: Center(
                                              child: Text(
                                                unreadCount > 9 ? '9+' : '$unreadCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          contact.name,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                                            fontSize: 15,
                                            fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (lastMsg != null)
                                        Text(
                                          _formatTime(lastMsg.timestamp),
                                          style: TextStyle(
                                            color: unreadCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                            fontSize: 11,
                                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lastMsg != null
                                                ? (lastMsg.isRequestCard
                                                      ? '[Request Card]'
                                                      : lastMsg.text)
                                                : contact.position,
                                            style: TextStyle(
                                              color: unreadCount > 0
                                                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                                  : const Color(0xFF64748B),
                                              fontSize: 13,
                                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (pendingRequestCount > 0)
                                              Container(
                                                margin: const EdgeInsets.only(left: 6),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '$pendingRequestCount Pending',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            if (unreadCount > 0 && pendingRequestCount == 0)
                                              Container(
                                                margin: const EdgeInsets.only(left: 6),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  provider.translate('new') != 'new' ? provider.translate('new') : 'NEW',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF1E293B), size: 20),
      ),
    );
  }

  Widget _buildAvatar(CompanyEmployee contact) {
    final avatarProvider = getAvatarProvider(contact.avatarUrl);
    final initials = contact.name.isNotEmpty
        ? contact.name.substring(0, 1).toUpperCase()
        : 'E';

    final List<Color> gradientColors = contact.role == 'supervisor'
        ? [
            const Color(0xFFEC4899),
            const Color(0xFF8236FE),
          ] // Pink-Purple for Supervisors
        : [
            const Color(0xFF2E65FF),
            const Color(0xFF2EBD96),
          ]; // Blue-Green for Employees

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: avatarProvider != null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
        image: avatarProvider != null
            ? DecorationImage(
                image: avatarProvider,
                fit: BoxFit.cover,
              )
            : null,
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: avatarProvider != null
          ? null
          : Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(AttendanceProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 64,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            provider.translate('no_chat_partners'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
