import 'package:flutter/material.dart';

/// Creates high-contrast, fully visible [TimePickerThemeData] for light/dark modes.
TimePickerThemeData createAdaptiveTimePickerTheme({
  required bool isDark,
  Color primaryColor = const Color(0xFF2E65FF),
}) {
  const onPrimaryColor = Colors.white;
  final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
  final onSurfaceColor = isDark ? Colors.white : const Color(0xFF0F172A);
  final dialBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

  return TimePickerThemeData(
    backgroundColor: surfaceColor,
    dialBackgroundColor: dialBgColor,
    dialHandColor: primaryColor,
    dialTextColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return onPrimaryColor;
      }
      return onSurfaceColor;
    }),
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
    dayPeriodBorderSide: BorderSide(
      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
    ),
    entryModeIconColor: isDark ? Colors.white70 : const Color(0xFF64748B),
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    ),
    confirmButtonStyle: TextButton.styleFrom(
      foregroundColor: primaryColor,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  );
}

/// Creates high-contrast, fully visible [DatePickerThemeData] for light/dark modes.
DatePickerThemeData createAdaptiveDatePickerTheme({
  required bool isDark,
  Color primaryColor = const Color(0xFF2E65FF),
}) {
  const onPrimaryColor = Colors.white;
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
    confirmButtonStyle: TextButton.styleFrom(
      foregroundColor: primaryColor,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  );
}

/// Provides an adaptive theme for [showTimePicker], [showDatePicker],
/// and [showDateRangePicker] that cleanly respects light and dark modes,
/// ensuring clock numbers, AM/PM selectors, and calendar dates remain
/// completely visible and high-contrast.
Widget buildAdaptivePickerTheme(
  BuildContext context,
  Widget? child, {
  Color primaryColor = const Color(0xFF2E65FF),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const onPrimaryColor = Colors.white;
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
      ),
      datePickerTheme: createAdaptiveDatePickerTheme(
        isDark: isDark,
        primaryColor: primaryColor,
      ),
    ),
    child: child!,
  );
}
