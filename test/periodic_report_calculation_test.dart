import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';

void main() {
  group('Periodic Report Row & Audit Calculations', () {
    test('PeriodicDailyAudit holds extraTimeMinutes correctly', () {
      final audit = PeriodicDailyAudit(
        date: DateTime(2026, 11, 15),
        dateStr: '2026-11-15',
        dayName: 'Sunday',
        shiftName: 'Normal Shift',
        shiftTime: '09:00 - 17:00',
        isWorkingDay: true,
        hasRecord: true,
        checkIn: '08:30',
        checkOut: '18:00',
        delayMinutes: 0,
        earlyExitMinutes: 0,
        actualMinutes: 570,
        scheduledMinutes: 480,
        overtimeMinutes: 90,
        extraTimeMinutes: 90,
        status: 'Present (+1.5h Extra)',
      );

      expect(audit.extraTimeMinutes, 90);
      expect(audit.overtimeMinutes, 90);
      expect(audit.actualMinutes, 570);
    });

    test('PeriodicReportRow holds extraTimeHours and nightOvertimeHours', () {
      final emp = CompanyEmployee(id: '1', name: 'Test Employee', email: 'test@example.com', position: 'Staff');
      final row = PeriodicReportRow(
        employee: emp,
        structureName: 'IT',
        groupName: 'HQ Group',
        shiftName: 'Standard',
        requiredHours: 40.0,
        actualWorkedHours: 46.5,
        deficitHours: 0.0,
        delayMinutes: 0,
        delayCount: 0,
        earlyExitMinutes: 0,
        earlyExitCount: 0,
        penaltyDeductions: 0.0,
        penaltyDays: 0,
        extraTimeHours: 6.5,
        totalOvertimeHours: 9.75, // 6.5 * 1.5
        dayOvertimeHours: 6.75,
        nightOvertimeHours: 3.0,
        dailyLeaveDays: 0,
        hourlyLeaveHours: 0.0,
        remainingAnnualHours: 120.0,
        remainingAnnualDays: 15.0,
        absentDays: 0,
        presentDays: 5,
      );

      expect(row.extraTimeHours, 6.5);
      expect(row.totalOvertimeHours, 9.75);
      expect(row.nightOvertimeHours, 3.0);
      expect(row.dayOvertimeHours, 6.75);
    });

    test('Weekend / Holiday 100% Extra Time rule logic', () {
      // When an employee works on an off-day (scheduled = 0):
      const workedMinutes = 360; // 6 hours
      const isWorkingDay = false;
      const isHoliday = false;

      final scheduledMinutes = isWorkingDay ? 480 : 0;
      final extraTimeMinutes = !isWorkingDay || isHoliday ? workedMinutes : 0;

      expect(scheduledMinutes, 0);
      expect(extraTimeMinutes, 360);
    });

    test('Overnight shift comparison with DateTime handles cross-midnight correctly', () {
      final date = DateTime(2026, 11, 15);
      final shiftStart = DateTime(2026, 11, 15, 17, 0); // 17:00
      var shiftEnd = DateTime(2026, 11, 15, 1, 0); // 01:00
      if (shiftEnd.isBefore(shiftStart)) {
        shiftEnd = shiftEnd.add(const Duration(days: 1)); // 2026-11-16 01:00
      }

      // CheckIn at 17:15
      final checkIn = DateTime(2026, 11, 15, 17, 15);
      final checkOut = DateTime(2026, 11, 16, 2, 0); // Extra 1 hour after shift

      expect(checkIn.isBefore(shiftEnd), isTrue);

      final delay = checkIn.difference(shiftStart).inMinutes;
      expect(delay, 15);

      final extraAfter = checkOut.difference(shiftEnd).inMinutes;
      expect(extraAfter, 60);
    });
  });
}
