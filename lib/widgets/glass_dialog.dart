import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';

Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required String title,
  required String subtitle,
  required IconData icon,
  required Widget content,
  List<Color>? iconBackgroundColor,
  List<Widget>? actions,
}) {
  AttendanceProvider? provider;
  try {
    provider = Provider.of<AttendanceProvider>(context, listen: false);
  } catch (_) {}
  final textDirection = provider?.currentLanguageDirection ??
      Directionality.maybeOf(context) ??
      TextDirection.ltr;

  final primaryAccent = (iconBackgroundColor != null && iconBackgroundColor.isNotEmpty)
      ? iconBackgroundColor.first
      : const Color(0xFF10B981);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
    pageBuilder: (ctx, anim, secondAnim) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
      final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
      final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
      final borderColor = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : const Color(0xFFE2E8F0);

      return Directionality(
        textDirection: textDirection,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                  maxWidth: 620,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: borderColor,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      spreadRadius: -2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header (matching ZK Device popup design)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryAccent.withValues(alpha: isDark ? 0.2 : 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              color: primaryAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 20,
                              color: subtextColor,
                            ),
                            splashRadius: 18,
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                    ),

                    // Content Area (Flexible and Scrollable)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          18,
                          20,
                          actions != null ? 8 : 20,
                        ),
                        child: content,
                      ),
                    ),

                    if (actions != null) ...[
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions
                              .expand(
                                (widget) => [widget, const SizedBox(width: 8)],
                              )
                              .toList()
                            ..removeLast(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
