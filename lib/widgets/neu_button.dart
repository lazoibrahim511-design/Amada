import 'package:flutter/material.dart';

enum NeuButtonVariant {
  /// Signature vibrant Aqua-Cyan gradient with deep midnight navy text & luminous glow (from screenshot "CONTINUE")
  primary,

  /// Deep Royal Navy with crisp white / aqua text & subtle indigo glow (from screenshot "Share")
  navy,

  /// Clean crisp pill button (light white / dark slate) with high-contrast text (from screenshot "Invite Friends +")
  whitePill,

  /// Vibrant Coral/Red capsule for destructive actions (Delete, Reject)
  danger,

  /// Amber / Orange capsule for cautionary actions (Reopen Month, Attention)
  warning,
}

/// Premium pill button styled after the reference fitness/dashboard design.
///
/// Features:
/// - Smooth stadium capsule geometry
/// - Vibrant color gradients matching the reference UI
/// - Ambient luminous glow shadows tuned for both Light and Dark themes
/// - Tactile scale & elevation micro-animations on hover and press
class NeuButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final String label;
  final double height;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double fontSize;
  final NeuButtonVariant variant;
  final bool isLoading;

  const NeuButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.height = 44,
    this.padding,
    this.borderRadius = 50,
    this.fontSize = 14,
    this.variant = NeuButtonVariant.primary,
    this.isLoading = false,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInteractive = widget.onPressed != null && !widget.isLoading;

    // 1. Resolve colors based on variant & theme
    late final Gradient backgroundGradient;
    late final Color textColor;
    late final Color glowColor;
    late final Color borderColor;
    late final Color specularHighlight;

    switch (widget.variant) {
      case NeuButtonVariant.primary:
        // Vibrant Aqua Cyan (matches "CONTINUE" from reference)
        backgroundGradient = LinearGradient(
          colors: isDark
              ? const [Color(0xFF00F0D8), Color(0xFF00CBB4)]
              : const [Color(0xFF00E5CE), Color(0xFF00BFA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        // Deep Midnight Navy text provides maximum contrast (> AAA standard)
        textColor = const Color(0xFF0A2342);
        glowColor = isDark
            ? const Color(0xFF00F0D8).withValues(alpha: 0.42)
            : const Color(0xFF00E5CE).withValues(alpha: 0.35);
        borderColor = const Color(0xFF80FFF3).withValues(alpha: isDark ? 0.5 : 0.4);
        specularHighlight = Colors.white.withValues(alpha: 0.3);
        break;

      case NeuButtonVariant.navy:
        // Deep Royal Navy (matches "Share" from reference)
        backgroundGradient = LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E3DB8), Color(0xFF122684)]
              : const [Color(0xFF1330A6), Color(0xFF0D2275)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        textColor = Colors.white;
        glowColor = isDark
            ? const Color(0xFF1E3DB8).withValues(alpha: 0.38)
            : const Color(0xFF0D2275).withValues(alpha: 0.3);
        borderColor = const Color(0xFF3B5BDB).withValues(alpha: 0.4);
        specularHighlight = Colors.white.withValues(alpha: 0.15);
        break;

      case NeuButtonVariant.whitePill:
        // Crisp White Pill on Light / Dark Slate on Dark (matches "Invite Friends +")
        if (isDark) {
          backgroundGradient = const LinearGradient(
            colors: [Color(0xFF1E283C), Color(0xFF161F2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          textColor = const Color(0xFF00F0D8);
          glowColor = Colors.black.withValues(alpha: 0.35);
          borderColor = const Color(0xFF334155);
          specularHighlight = Colors.white.withValues(alpha: 0.08);
        } else {
          backgroundGradient = const LinearGradient(
            colors: [Colors.white, Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          textColor = const Color(0xFF102B94);
          glowColor = const Color(0xFF0D2275).withValues(alpha: 0.08);
          borderColor = const Color(0xFFE2E8F0);
          specularHighlight = Colors.white;
        }
        break;

      case NeuButtonVariant.danger:
        // Coral Red (matches negative actions)
        backgroundGradient = const LinearGradient(
          colors: [Color(0xFFFF4B4B), Color(0xFFE11D48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        textColor = Colors.white;
        glowColor = const Color(0xFFEF4444).withValues(alpha: 0.38);
        borderColor = const Color(0xFFFDA4AF).withValues(alpha: 0.3);
        specularHighlight = Colors.white.withValues(alpha: 0.2);
        break;

      case NeuButtonVariant.warning:
        // Vibrant Amber / Orange capsule
        backgroundGradient = const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        textColor = Colors.white;
        glowColor = const Color(0xFFF59E0B).withValues(alpha: 0.38);
        borderColor = const Color(0xFFFCD34D).withValues(alpha: 0.35);
        specularHighlight = Colors.white.withValues(alpha: 0.2);
        break;
    }

    final double scale = _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0);
    final double blur = _isHovered ? 20.0 : (_isPressed ? 8.0 : 14.0);
    final double offsetDy = _isHovered ? 7.0 : (_isPressed ? 2.0 : 5.0);

    return MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isInteractive) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isInteractive) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (isInteractive) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (isInteractive) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (isInteractive) setState(() => _isPressed = false);
        },
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: widget.height,
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              gradient: backgroundGradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: isInteractive
                  ? [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: blur,
                        offset: Offset(0, offsetDy),
                      ),
                      BoxShadow(
                        color: specularHighlight,
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                      ),
                    ]
                  : const [],
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          IconTheme(
                            data: IconThemeData(
                              color: textColor,
                              size: widget.fontSize + 4,
                            ),
                            child: widget.icon!,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: textColor,
                              fontSize: widget.fontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular or capsule icon button styled after the reference fitness/dashboard UI.
/// Used for navigation chevrons, exports, floating quick actions, etc.
class NeuIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final double size;
  final NeuButtonVariant variant;
  final String? tooltip;
  final bool isLoading;

  const NeuIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = 42,
    this.variant = NeuButtonVariant.whitePill,
    this.tooltip,
    this.isLoading = false,
  });

  @override
  State<NeuIconButton> createState() => _NeuIconButtonState();
}

class _NeuIconButtonState extends State<NeuIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInteractive = widget.onPressed != null && !widget.isLoading;

    late final Gradient backgroundGradient;
    late final Color iconColor;
    late final Color glowColor;
    late final Color borderColor;
    late final Color specularHighlight;

    switch (widget.variant) {
      case NeuButtonVariant.primary:
        backgroundGradient = LinearGradient(
          colors: isDark
              ? const [Color(0xFF00F0D8), Color(0xFF00CBB4)]
              : const [Color(0xFF00E5CE), Color(0xFF00BFA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        iconColor = const Color(0xFF0A2342);
        glowColor = isDark
            ? const Color(0xFF00F0D8).withValues(alpha: 0.42)
            : const Color(0xFF00E5CE).withValues(alpha: 0.35);
        borderColor = const Color(0xFF80FFF3).withValues(alpha: isDark ? 0.5 : 0.4);
        specularHighlight = Colors.white.withValues(alpha: 0.3);
        break;

      case NeuButtonVariant.navy:
        backgroundGradient = LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E3DB8), Color(0xFF122684)]
              : const [Color(0xFF1330A6), Color(0xFF0D2275)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        iconColor = Colors.white;
        glowColor = isDark
            ? const Color(0xFF1E3DB8).withValues(alpha: 0.38)
            : const Color(0xFF0D2275).withValues(alpha: 0.3);
        borderColor = const Color(0xFF3B5BDB).withValues(alpha: 0.4);
        specularHighlight = Colors.white.withValues(alpha: 0.15);
        break;

      case NeuButtonVariant.whitePill:
        if (isDark) {
          backgroundGradient = const LinearGradient(
            colors: [Color(0xFF1E283C), Color(0xFF161F2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          iconColor = const Color(0xFF00F0D8);
          glowColor = Colors.black.withValues(alpha: 0.35);
          borderColor = const Color(0xFF334155);
          specularHighlight = Colors.white.withValues(alpha: 0.08);
        } else {
          backgroundGradient = const LinearGradient(
            colors: [Colors.white, Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          iconColor = const Color(0xFF102B94);
          glowColor = const Color(0xFF0D2275).withValues(alpha: 0.08);
          borderColor = const Color(0xFFE2E8F0);
          specularHighlight = Colors.white;
        }
        break;

      case NeuButtonVariant.danger:
        backgroundGradient = const LinearGradient(
          colors: [Color(0xFFFF4B4B), Color(0xFFE11D48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        iconColor = Colors.white;
        glowColor = const Color(0xFFEF4444).withValues(alpha: 0.38);
        borderColor = const Color(0xFFFDA4AF).withValues(alpha: 0.3);
        specularHighlight = Colors.white.withValues(alpha: 0.2);
        break;

      case NeuButtonVariant.warning:
        backgroundGradient = const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        iconColor = Colors.white;
        glowColor = const Color(0xFFF59E0B).withValues(alpha: 0.38);
        borderColor = const Color(0xFFFCD34D).withValues(alpha: 0.35);
        specularHighlight = Colors.white.withValues(alpha: 0.2);
        break;
    }

    final double scale = _isPressed ? 0.92 : (_isHovered ? 1.08 : 1.0);
    final double blur = _isHovered ? 16.0 : (_isPressed ? 6.0 : 10.0);
    final double offsetDy = _isHovered ? 5.0 : (_isPressed ? 1.0 : 3.0);

    Widget btn = MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isInteractive) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isInteractive) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (isInteractive) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (isInteractive) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (isInteractive) setState(() => _isPressed = false);
        },
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: backgroundGradient,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: isInteractive
                  ? [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: blur,
                        offset: Offset(0, offsetDy),
                      ),
                      BoxShadow(
                        color: specularHighlight,
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                      ),
                    ]
                  : const [],
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: widget.size * 0.42,
                      height: widget.size * 0.42,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : IconTheme(
                      data: IconThemeData(
                        color: iconColor,
                        size: widget.size * 0.48,
                      ),
                      child: widget.icon,
                    ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }

    return btn;
  }
}
