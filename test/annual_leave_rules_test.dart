import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/request_model.dart';
import 'package:attendance_app/models/translation_keys.dart';

DateTime? parseRequestStartDate(String dateStr) {
  try {
    final trimmed = dateStr.trim();
    if (trimmed.contains(' - ')) {
      final parts = trimmed.split(' - ');
      final startPart = parts[0].trim();
      final endPart = parts[1].trim();
      if (RegExp(r'\d{4}').hasMatch(startPart)) {
        return DateFormat('MMMM d, yyyy').parse(startPart);
      }
      final yearMatch = RegExp(r'\d{4}').firstMatch(endPart);
      if (yearMatch != null) {
        final year = yearMatch.group(0);
        return DateFormat('MMMM d, yyyy').parse('$startPart, $year');
      }
      return DateFormat('MMMM d, yyyy').parse(endPart);
    }
    return DateFormat('MMMM d, yyyy').parse(trimmed);
  } catch (_) {
    try {
      return DateTime.parse(dateStr.trim());
    } catch (_) {
      return null;
    }
  }
}

void main() {
  group('Annual Leave Form Rules - Model & Serialization', () {
    test('EmployeeGroup defaults for annual leave form rules', () {
      final group = EmployeeGroup(id: 'g1', name: 'Standard', shiftId: 's1');
      expect(group.annualLeaveMinNoticeDays, 0);
      expect(group.annualLeaveMaxRequestsPerPeriod, 0);
      expect(group.annualLeavePeriodType, 'Month');
    });

    test('EmployeeGroup toMap and fromMap serialization', () {
      final group = EmployeeGroup(
        id: 'g_vip',
        name: 'VIP Group',
        shiftId: 's1',
        annualLeaveMinNoticeDays: 2,
        annualLeaveMaxRequestsPerPeriod: 1,
        annualLeavePeriodType: 'Month',
      );

      final map = group.toMap();
      expect(map['annualLeaveMinNoticeDays'], 2);
      expect(map['annualLeaveMaxRequestsPerPeriod'], 1);
      expect(map['annualLeavePeriodType'], 'Month');

      final restored = EmployeeGroup.fromMap(map, 'g_vip');
      expect(restored.annualLeaveMinNoticeDays, 2);
      expect(restored.annualLeaveMaxRequestsPerPeriod, 1);
      expect(restored.annualLeavePeriodType, 'Month');
    });

    test('EmployeeGroup copyWith modifies rules accurately', () {
      final group = EmployeeGroup(
        id: 'g1',
        name: 'Initial',
        shiftId: 's1',
        annualLeaveMinNoticeDays: 1,
        annualLeaveMaxRequestsPerPeriod: 2,
        annualLeavePeriodType: 'Month',
      );

      final updated = group.copyWith(
        annualLeaveMinNoticeDays: 3,
        annualLeaveMaxRequestsPerPeriod: 5,
        annualLeavePeriodType: 'Year',
      );

      expect(updated.annualLeaveMinNoticeDays, 3);
      expect(updated.annualLeaveMaxRequestsPerPeriod, 5);
      expect(updated.annualLeavePeriodType, 'Year');
    });
  });

  group('Annual Leave Advance Notice Calculation Rule', () {
    test('Minimum notice days calculation matches user requirement', () {
      // User scenario: Today is 2026-10-20. Notice requirement is 2 days.
      final today = DateTime(2026, 10, 20);
      const minNoticeDays = 2;

      // Applying for today (2026-10-20): difference = 0 -> Blocked
      final dateToday = DateTime(2026, 10, 20);
      expect(dateToday.difference(today).inDays < minNoticeDays, isTrue);

      // Applying for tomorrow (2026-10-21): difference = 1 -> Blocked
      final dateTomorrow = DateTime(2026, 10, 21);
      expect(dateTomorrow.difference(today).inDays < minNoticeDays, isTrue);

      // Applying for 22-10-2026: difference = 2 -> Allowed
      final dateIn2Days = DateTime(2026, 10, 22);
      expect(dateIn2Days.difference(today).inDays >= minNoticeDays, isTrue);

      // Applying for 25-10-2026: difference = 5 -> Allowed
      final dateIn5Days = DateTime(2026, 10, 25);
      expect(dateIn5Days.difference(today).inDays >= minNoticeDays, isTrue);

      // Applying for past date (yesterday): difference = -1 -> Blocked
      final dateYesterday = DateTime(2026, 10, 19);
      expect(dateYesterday.difference(today).inDays < minNoticeDays, isTrue);
    });

    test('Earliest available date calculation', () {
      final today = DateTime(2026, 10, 20);
      const minNoticeDays = 2;
      final earliestDate = today.add(const Duration(days: minNoticeDays));
      expect(DateFormat('yyyy-MM-dd').format(earliestDate), '2026-10-22');
    });

    test('Date range parser extracts correct start date with or without year in first segment', () {
      final d1 = parseRequestStartDate('June 20 - June 22, 2026');
      expect(d1, isNotNull);
      expect(d1!.year, 2026);
      expect(d1.month, 6);
      expect(d1.day, 20);

      final d2 = parseRequestStartDate('October 22, 2026');
      expect(d2, isNotNull);
      expect(d2!.year, 2026);
      expect(d2.month, 10);
      expect(d2.day, 22);

      final d3 = parseRequestStartDate('November 1, 2026 - November 5, 2026');
      expect(d3, isNotNull);
      expect(d3!.year, 2026);
      expect(d3.month, 11);
      expect(d3.day, 1);
    });
  });

  group('Annual Leave Frequency Limit Per Period Rule', () {
    test('Monthly limit validation ignores rejected requests', () {
      const maxPerMonth = 1;

      final existingRequests = [
        Request(
          id: 'r1',
          type: 'Annual Leave',
          date: 'October 10, 2026',
          duration: '1 Day',
          status: 'Rejected',
        ),
        Request(
          id: 'r2',
          type: 'Sick Leave',
          date: 'October 12, 2026',
          duration: '1 Day',
          status: 'Approved',
        ),
      ];

      final targetDate = DateTime(2026, 10, 25);

      int activeAnnualCount = 0;
      for (var req in existingRequests) {
        if (req.type == 'Annual Leave' && req.status != 'Rejected') {
          final rDate = parseRequestStartDate(req.date);
          if (rDate != null &&
              rDate.year == targetDate.year &&
              rDate.month == targetDate.month) {
            activeAnnualCount++;
          }
        }
      }

      // Since the existing October annual leave was Rejected, activeAnnualCount is 0 (< maxPerMonth)
      expect(activeAnnualCount < maxPerMonth, isTrue);

      // Now add an approved annual leave
      existingRequests.add(
        Request(
          id: 'r3',
          type: 'Annual Leave',
          date: 'October 15, 2026',
          duration: '1 Day',
          status: 'Approved',
        ),
      );

      activeAnnualCount = 0;
      for (var req in existingRequests) {
        if (req.type == 'Annual Leave' && req.status != 'Rejected') {
          final rDate = parseRequestStartDate(req.date);
          if (rDate != null &&
              rDate.year == targetDate.year &&
              rDate.month == targetDate.month) {
            activeAnnualCount++;
          }
        }
      }

      // Now active count is 1 >= maxPerMonth -> limit reached
      expect(activeAnnualCount >= maxPerMonth, isTrue);
    });

    test('Yearly limit validation counts across the entire year', () {
      const maxPerYear = 2;

      final existingRequests = [
        Request(
          id: 'r1',
          type: 'Annual Leave',
          date: 'March 10, 2026',
          duration: '2 Days',
          status: 'Approved',
        ),
        Request(
          id: 'r2',
          type: 'Annual Leave',
          date: 'July 5, 2026',
          duration: '3 Days',
          status: 'Pending',
        ),
      ];

      final targetDate = DateTime(2026, 11, 20);

      int activeAnnualCount = 0;
      for (var req in existingRequests) {
        if (req.type == 'Annual Leave' && req.status != 'Rejected') {
          final rDate = parseRequestStartDate(req.date);
          if (rDate != null && rDate.year == targetDate.year) {
            activeAnnualCount++;
          }
        }
      }

      // 2 active requests in 2026 -> limit reached
      expect(activeAnnualCount >= maxPerYear, isTrue);
    });
  });

  group('Translations for Annual Leave Rules', () {
    test('All 3 languages have required keys', () {
      final requiredKeys = [
        'annual_leave_min_notice_days',
        'annual_leave_max_requests_per_period',
        'annual_leave_max_requests_per_month',
        'annual_leave_period_type',
        'annual_leave_min_notice_error',
        'annual_leave_period_limit_error',
        'period_month',
        'period_year',
      ];

      for (var lang in ['en', 'ar', 'ku']) {
        final langMap = TranslationKeys.translations[lang];
        expect(langMap, isNotNull);
        for (var key in requiredKeys) {
          expect(
            langMap!.containsKey(key),
            isTrue,
            reason: 'Missing key "$key" in language "$lang"',
          );
          expect(langMap[key]!.isNotEmpty, isTrue);
        }
      }
    });
  });
}
