import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final List<Color>? gradientColors;
  final double borderWidth;
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.blur = 15.0,
    this.padding = const EdgeInsets.all(20.0),
    this.margin,
    this.gradientColors,
    this.borderWidth = 1.0,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Instead of blurry glass, use a solid, eye-friendly card color
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = borderColor ?? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05));

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderCol, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}
