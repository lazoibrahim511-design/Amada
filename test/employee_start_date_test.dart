import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/translation_keys.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Employee Start Date (Hire Date) Tests', () {
    test('Translation keys for hire_date exist across EN, AR, and KU', () {
      expect(TranslationKeys.translations['en']!['hire_date'], isNotEmpty);
      expect(TranslationKeys.translations['ar']!['hire_date'], isNotEmpty);
      expect(TranslationKeys.translations['ku']!['hire_date'], isNotEmpty);

      expect(TranslationKeys.translations['en']!['start_date_hint'], isNotEmpty);
      expect(TranslationKeys.translations['ar']!['start_date_hint'], isNotEmpty);
      expect(TranslationKeys.translations['ku']!['start_date_hint'], isNotEmpty);

      expect(TranslationKeys.translations['en']!['no_records_before_hire'], isNotEmpty);
      expect(TranslationKeys.translations['ar']!['no_records_before_hire'], isNotEmpty);
      expect(TranslationKeys.translations['ku']!['no_records_before_hire'], isNotEmpty);
    });

    test('generatePayrollReport skips dates prior to employee startDate', () {
      final provider = AttendanceProvider();

      final emp = CompanyEmployee(
        id: 'EMP-START-TEST',
        name: 'New Hire',
        email: 'newhire@amada.com',
        position: 'Software Engineer',
        startDate: '2026-10-20',
        basicSalary: 3000.0,
        workingHours: 160.0,
        foodAllowance: 310.0,
        transportationAllowance: 0.0,
        otherAllowance: 0.0,
      );

      // Generate report for October 2026
      final targetMonth = DateTime(2026, 10, 1);
      final report = provider.generatePayrollReport(
        emp,
        targetMonth,
        customRecords: [],
      );

      // Days before Oct 20 should NOT count as deficit or absences
      // Since emp started on Oct 20, active days in Oct (31 days total) are Oct 20..31 = 12 days
      // Pro-rated food allowance: 310 * (12 / 31) = 120.0
      expect(report.foodAllowance, closeTo(120.0, 0.1));

      // Employee has not clocked in yet on 20..31 in this mock, but days 1..19 are completely ignored.
      expect(report.basicSalary, equals(3000.0));
    });

    test('generatePayrollReport yields 0 allowance if startDate is in a future month', () {
      final provider = AttendanceProvider();

      final emp = CompanyEmployee(
        id: 'EMP-FUTURE',
        name: 'Future Hire',
        email: 'future@amada.com',
        position: 'Accountant',
        startDate: '2026-11-01',
        basicSalary: 2000.0,
        workingHours: 160.0,
        foodAllowance: 200.0,
      );

      // Target month is October 2026 (before hire date)
      final targetMonth = DateTime(2026, 10, 1);
      final report = provider.generatePayrollReport(
        emp,
        targetMonth,
        customRecords: [],
      );

      // Employee was not employed in October 2026
      expect(report.foodAllowance, equals(0.0));
      expect(report.transportationAllowance, equals(0.0));
      expect(report.otherAllowance, equals(0.0));
    });
  });
}
