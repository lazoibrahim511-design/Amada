import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppSnackBarType {
  success,
  error,
  warning,
  info,
}

/// A centralized, modern floating pill SnackBar utility matching the Mobbin-inspired
/// design system across the application.
class AppSnackBar {
  /// Build a modern floating SnackBar widget
  static SnackBar build({
    String? message,
    Widget? contentWidget,
    AppSnackBarType type = AppSnackBarType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
    Color textColor = Colors.white,
    EdgeInsetsGeometry? margin,
  }) {
    Color bg;
    IconData defaultIcon;

    switch (type) {
      case AppSnackBarType.success:
        bg = const Color(0xFF2EBD96);
        defaultIcon = Icons.check_circle_rounded;
        break;
      case AppSnackBarType.error:
        bg = const Color(0xFFFF5C5C);
        defaultIcon = Icons.error_outline_rounded;
        break;
      case AppSnackBarType.warning:
        bg = const Color(0xFFF59E0B);
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case AppSnackBarType.info:
        bg = const Color(0xFF1E293B);
        defaultIcon = Icons.info_outline_rounded;
        break;
    }

    if (backgroundColor != null) {
      bg = backgroundColor;
    }

    return SnackBar(
      content: Row(
        children: [
          Icon(
            icon ?? defaultIcon,
            color: textColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: contentWidget ??
                Text(
                  message ?? '',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
          ),
        ],
      ),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      elevation: 6,
      duration: duration,
      action: action,
    );
  }

  /// Show the modern floating message box using either BuildContext or ScaffoldMessengerState
  static void show(
    dynamic target, {
    String? message,
    Widget? contentWidget,
    AppSnackBarType type = AppSnackBarType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    _triggerHaptic(type);

    ScaffoldMessengerState? messenger;
    if (target is BuildContext) {
      messenger = ScaffoldMessenger.maybeOf(target);
    } else if (target is ScaffoldMessengerState) {
      messenger = target;
    }

    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      build(
        message: message,
        contentWidget: contentWidget,
        type: type,
        icon: icon,
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
      ),
    );
  }

  /// Show with a ScaffoldMessengerState directly
  static void showWithMessenger(
    ScaffoldMessengerState messenger, {
    String? message,
    Widget? contentWidget,
    AppSnackBarType type = AppSnackBarType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    show(
      messenger,
      message: message,
      contentWidget: contentWidget,
      type: type,
      icon: icon,
      duration: duration,
      action: action,
      backgroundColor: backgroundColor,
    );
  }

  /// Success message (Emerald / Mint Teal with check icon)
  static void success(
    dynamic target,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      target,
      message: message,
      type: AppSnackBarType.success,
      icon: icon,
      duration: duration,
      action: action,
    );
  }

  /// Error message (Vibrant Coral Red with error icon)
  static void error(
    dynamic target,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      target,
      message: message,
      type: AppSnackBarType.error,
      icon: icon,
      duration: duration,
      action: action,
    );
  }

  /// Warning message (Amber / Gold with warning icon)
  static void warning(
    dynamic target,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      target,
      message: message,
      type: AppSnackBarType.warning,
      icon: icon,
      duration: duration,
      action: action,
    );
  }

  /// Info message (Midnight Navy / Slate with info icon)
  static void info(
    dynamic target,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      target,
      message: message,
      type: AppSnackBarType.info,
      icon: icon,
      duration: duration,
      action: action,
    );
  }

  static void _triggerHaptic(AppSnackBarType type) {
    try {
      if (type == AppSnackBarType.error) {
        HapticFeedback.heavyImpact();
      } else if (type == AppSnackBarType.warning) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }
}

extension AppSnackBarExtension on BuildContext {
  void showAppSnackBar(
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    AppSnackBar.show(
      this,
      message: message,
      type: type,
      icon: icon,
      duration: duration,
      action: action,
      backgroundColor: backgroundColor,
    );
  }

  void showSuccessSnackBar(String message, {IconData? icon, Duration? duration}) =>
      AppSnackBar.success(this, message, icon: icon, duration: duration ?? const Duration(seconds: 4));

  void showErrorSnackBar(String message, {IconData? icon, Duration? duration}) =>
      AppSnackBar.error(this, message, icon: icon, duration: duration ?? const Duration(seconds: 4));

  void showWarningSnackBar(String message, {IconData? icon, Duration? duration}) =>
      AppSnackBar.warning(this, message, icon: icon, duration: duration ?? const Duration(seconds: 4));

  void showInfoSnackBar(String message, {IconData? icon, Duration? duration}) =>
      AppSnackBar.info(this, message, icon: icon, duration: duration ?? const Duration(seconds: 4));
}

extension AppScaffoldMessengerExtension on ScaffoldMessengerState {
  void showAppSnackBar(
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    AppSnackBar.showWithMessenger(
      this,
      message: message,
      type: type,
      icon: icon,
      duration: duration,
      action: action,
      backgroundColor: backgroundColor,
    );
  }

  void showSuccess(String message, {IconData? icon, Duration? duration}) =>
      AppSnackBar.showWithMessenger(
        this,
        message: message,
        type: AppSnackBarType.success,
        icon: icon,
        duration: duration ?? const Duration(seconds: 4),
      );

  void showError(String message, {IconData? icon, Duration? duration}) =>
      AppSnackBar.showWithMessenger(
        this,
        message: message,
        type: AppSnackBarType.error,
        icon: icon,
        duration: duration ?? const Duration(seconds: 4),
      );

  void showWarning(String message, {IconData? icon, Duration? duration}) =>
      AppSnackBar.showWithMessenger(
        this,
        message: message,
        type: AppSnackBarType.warning,
        icon: icon,
        duration: duration ?? const Duration(seconds: 4),
      );

  void showInfo(String message, {IconData? icon, Duration? duration}) =>
      AppSnackBar.showWithMessenger(
        this,
        message: message,
        type: AppSnackBarType.info,
        icon: icon,
        duration: duration ?? const Duration(seconds: 4),
      );
}
