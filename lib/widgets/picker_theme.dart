import 'package:flutter/material.dart';

/// Creates high-contrast, fully visible [TimePickerThemeData] styled with the
/// app's signature teal/green button branding and rounded card design.
TimePickerThemeData createAdaptiveTimePickerTheme({
  required bool isDark,
  Color primaryColor = const Color(0xFF00E5CE),
  Color onPrimaryColor = const Color(0xFF0A2342),
}) {
  final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
  final onSurfaceColor = isDark ? Colors.white : const Color(0xFF0F172A);
  final dialBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  return TimePickerThemeData(
    backgroundColor: surfaceColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: borderColor, width: 1.2),
    ),
    dialBackgroundColor: dialBgColor,
    dialHandColor: primaryColor,
    dialTextColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return onPrimaryColor;
      }
      return onSurfaceColor;
    }),
    dialTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
    hourMinuteShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    hourMinuteColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return primaryColor;
      }
      return dialBgColor;
    }),
    hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return onPrimaryColor;
      }
      return onSurfaceColor;
    }),
    hourMinuteTextStyle: const TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w800,
    ),
    dayPeriodShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    dayPeriodBorderSide: BorderSide(
      color: borderColor,
      width: 1.1,
    ),
    dayPeriodColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return primaryColor;
      }
      return dialBgColor;
    }),
    dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return onPrimaryColor;
      }
      return isDark ? Colors.white70 : const Color(0xFF64748B);
    }),
    dayPeriodTextStyle: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
    ),
    timeSelectorSeparatorColor: WidgetStateColor.resolveWith((states) => onSurfaceColor),
    timeSelectorSeparatorTextStyle: WidgetStateProperty.all(
      TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        color: onSurfaceColor,
      ),
    ),
    entryModeIconColor: isDark ? Colors.white70 : const Color(0xFF64748B),
    helpTextStyle: TextStyle(
      color: onSurfaceColor,
      fontWeight: FontWeight.w700,
      fontSize: 14.5,
    ),
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    confirmButtonStyle: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        }
        return primaryColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return isDark ? Colors.white38 : const Color(0xFF94A3B8);
        }
        return onPrimaryColor;
      }),
      elevation: WidgetStateProperty.all(3),
      shadowColor: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.4)),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 22, vertical: 10)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}

/// Creates high-contrast, fully visible [DatePickerThemeData] for light/dark modes.
DatePickerThemeData createAdaptiveDatePickerTheme({
  required bool isDark,
  Color primaryColor = const Color(0xFF00E5CE),
  Color onPrimaryColor = const Color(0xFF0A2342),
}) {
  final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
  final onSurfaceColor = isDark ? Colors.white : const Color(0xFF0F172A);

  return DatePickerThemeData(
    backgroundColor: surfaceColor,
    headerBackgroundColor: primaryColor,
    headerForegroundColor: onPrimaryColor,
    surfaceTintColor: Colors.transparent,
    dayForegroundColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return onPrimaryColor;
      }
      if (states.contains(WidgetState.disabled)) {
        return isDark ? Colors.white24 : const Color(0xFFCBD5E1);
      }
      return onSurfaceColor;
    }),
    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return primaryColor;
      }
      return null;
    }),
    todayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return onPrimaryColor;
      }
      return primaryColor;
    }),
    todayBorder: BorderSide(color: primaryColor, width: 1.5),
    yearForegroundColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return onPrimaryColor;
      }
      return onSurfaceColor;
    }),
    rangeSelectionBackgroundColor: primaryColor.withValues(alpha: 0.18),
    rangePickerBackgroundColor: surfaceColor,
    rangePickerHeaderBackgroundColor: primaryColor,
    rangePickerHeaderForegroundColor: onPrimaryColor,
    rangePickerSurfaceTintColor: Colors.transparent,
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    ),
    confirmButtonStyle: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        }
        return primaryColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return isDark ? Colors.white38 : const Color(0xFF94A3B8);
        }
        return onPrimaryColor;
      }),
      elevation: WidgetStateProperty.all(3),
      shadowColor: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.4)),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 22, vertical: 10)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}

/// Provides an adaptive theme for [showTimePicker], [showDatePicker],
/// and [showDateRangePicker] that cleanly respects light and dark modes,
/// ensuring clock numbers, AM/PM selectors, and calendar dates remain
/// completely visible, high-contrast, and branded with the app's button green color.
Widget buildAdaptivePickerTheme(
  BuildContext context,
  Widget? child, {
  Color primaryColor = const Color(0xFF00E5CE),
  Color onPrimaryColor = const Color(0xFF0A2342),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
  final onSurfaceColor = isDark ? Colors.white : const Color(0xFF0F172A);
  final dialBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

  return Theme(
    data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primaryColor,
              onPrimary: onPrimaryColor,
              surface: surfaceColor,
              onSurface: onSurfaceColor,
              surfaceContainerHighest: dialBgColor,
              onSurfaceVariant: const Color(0xFF94A3B8),
              outline: const Color(0xFF475569),
            )
          : ColorScheme.light(
              primary: primaryColor,
              onPrimary: onPrimaryColor,
              surface: surfaceColor,
              onSurface: onSurfaceColor,
              surfaceContainerHighest: dialBgColor,
              onSurfaceVariant: const Color(0xFF64748B),
              outline: const Color(0xFFCBD5E1),
            ),
      timePickerTheme: createAdaptiveTimePickerTheme(
        isDark: isDark,
        primaryColor: primaryColor,
        onPrimaryColor: onPrimaryColor,
      ),
      datePickerTheme: createAdaptiveDatePickerTheme(
        isDark: isDark,
        primaryColor: primaryColor,
        onPrimaryColor: onPrimaryColor,
      ),
    ),
    child: child!,
  );
}
