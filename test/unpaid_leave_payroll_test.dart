import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/translation_keys.dart';

void main() {
  group('Unpaid Leave Calculation & Formula Tests', () {
    test('1 hour unpaid leave deduction calculation matches formula', () {
      // Formula: ((basic salary / 8) / 30) * hours
      const basicSalary = 720000.0;
      final hourlyRate = ((basicSalary / 8.0) / 30.0);
      expect(hourlyRate, 3000.0);

      const hours = 1.0;
      final deduction = hours * hourlyRate;
      expect(deduction, 3000.0);
    });

    test('8 hours daily unpaid leave equals full daily basic rate', () {
      const basicSalary = 2400.0;
      final hourlyRate = ((basicSalary / 8.0) / 30.0);
      expect(hourlyRate, 10.0);

      const dailyLeaveHours = 8.0;
      final dailyDeduction = dailyLeaveHours * hourlyRate;
      expect(dailyDeduction, 80.0);
      // Equivalent to basicSalary / 30 days
      expect(dailyDeduction, basicSalary / 30.0);
    });

    test('Fractional hourly unpaid leave calculates precisely', () {
      const basicSalary = 1200.0;
      final hourlyRate = ((basicSalary / 8.0) / 30.0); // 5.0 / hr
      expect(hourlyRate, 5.0);

      const minutes = 90; // 1.5 hours
      final hours = minutes / 60.0;
      final deduction = hours * hourlyRate;
      expect(deduction, 7.5);
    });
  });

  group('PayrollReportSnapshot & PayrollReport Model Tests', () {
    test('PayrollReportSnapshot serialization with unpaid leave fields', () {
      final snapshot = PayrollReportSnapshot(
        employeeId: 'emp_1',
        employeeName: 'Jane Doe',
        position: 'Developer',
        basicSalary: 3000.0,
        salaryCalcByDay: 3000.0,
        daysWorked: 30,
        workingHours: 240.0,
        overtimeHours: 0.0,
        overtimeValue: 0.0,
        attendanceDeficitHours: 0.0,
        attendanceDeficit: 0.0,
        foodAllowance: 0.0,
        transportationAllowance: 0.0,
        otherAllowance: 0.0,
        insuranceSalary: 0.0,
        insuranceEmployee: 0.0,
        insuranceCompany: 0.0,
        monthlyAdditions: 0.0,
        monthlyPenalties: 0.0,
        monthlyDeductions: 0.0,
        incrementalSalary: 3000.0,
        decrementalSalary: 100.0,
        netEarnings: 2900.0,
        currency: 'USD',
        hasInsurance: false,
        unpaidLeaveHours: 8.0,
        unpaidLeaveDeduction: 100.0,
      );

      final map = snapshot.toMap();
      expect(map['unpaidLeaveHours'], 8.0);
      expect(map['unpaidLeaveDeduction'], 100.0);

      final restored = PayrollReportSnapshot.fromMap(map);
      expect(restored.unpaidLeaveHours, 8.0);
      expect(restored.unpaidLeaveDeduction, 100.0);
      expect(restored.employeeName, 'Jane Doe');
      expect(restored.position, 'Developer');
      expect(restored.netEarnings, 2900.0);
    });

    test('PayrollReportSnapshot defaults unpaid leave fields when missing in map', () {
      final map = {
        'employeeId': 'emp_2',
        'employeeName': 'John Smith',
        'position': 'Designer',
        'basicSalary': 2000.0,
        'salaryCalcByDay': 2000.0,
        'daysWorked': 30,
        'workingHours': 240.0,
        'overtimeHours': 0.0,
        'overtimeValue': 0.0,
        'attendanceDeficitHours': 0.0,
        'attendanceDeficit': 0.0,
        'foodAllowance': 0.0,
        'transportationAllowance': 0.0,
        'otherAllowance': 0.0,
        'insuranceSalary': 0.0,
        'insuranceEmployee': 0.0,
        'insuranceCompany': 0.0,
        'monthlyAdditions': 0.0,
        'monthlyPenalties': 0.0,
        'monthlyDeductions': 0.0,
        'incrementalSalary': 2000.0,
        'decrementalSalary': 0.0,
        'netEarnings': 2000.0,
        'currency': 'USD',
        'hasInsurance': false,
      };

      final restored = PayrollReportSnapshot.fromMap(map);
      expect(restored.unpaidLeaveHours, 0.0);
      expect(restored.unpaidLeaveDeduction, 0.0);
    });
  });

  group('Translation Keys for Unpaid Leave', () {
    test('All languages have translations for unpaid leave keys', () {
      final requiredKeys = [
        'unpaid_leave',
        'hourly_unpaid_leave',
        'unpaid_leave_deduction',
        'unpaid_leave_hrs',
        'unpaid_leave_val',
      ];

      for (final lang in ['en', 'ar', 'ku']) {
        final dict = TranslationKeys.translations[lang];
        expect(dict, isNotNull, reason: 'Language $lang dictionary should exist');
        for (final key in requiredKeys) {
          expect(dict![key], isNotNull,
              reason: 'Key "$key" should have translation in "$lang"');
          expect(dict[key]!.isNotEmpty, isTrue,
              reason: 'Key "$key" in "$lang" should not be empty');
        }
      }
    });
  });

  group('Request Duration Parsing for Hourly Leave', () {
    test('parseHourlyLeaveDurationMinutes correctly parses hourly unpaid leave format', () {
      final durationStr = formatHourlyLeaveDurationString(
        '14:00',
        '16:00',
      );
      expect(durationStr.contains('14:00'), isTrue);
      expect(durationStr.contains('16:00'), isTrue);

      final parsedMinutes = parseHourlyLeaveDurationMinutes(durationStr);
      expect(parsedMinutes, 120);
    });
  });
}
