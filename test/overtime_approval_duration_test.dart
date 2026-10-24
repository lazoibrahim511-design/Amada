import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/request_model.dart';

void main() {
  group('Overtime Approval Duration Parsing', () {
    test('parseOvertimeApprovalDurationMinutes parses range formats and units accurately', () {
      // 08:25 to 09:00 is 35 minutes
      expect(
        parseOvertimeApprovalDurationMinutes('From 08:25 to 09:00 (0.6 Hours)'),
        35,
      );
      expect(parseOvertimeApprovalDurationMinutes('From 08:25 to 09:00'), 35);
      expect(parseOvertimeApprovalDurationMinutes('From 17:00 to 17:06'), 6);
      expect(parseOvertimeApprovalDurationMinutes('08:25 - 09:00'), 35);
      expect(parseOvertimeApprovalDurationMinutes('35 mins'), 35);
      expect(parseOvertimeApprovalDurationMinutes('35'), 35);
      expect(parseOvertimeApprovalDurationMinutes('2.5 Hours'), 150);
      expect(parseOvertimeApprovalDurationMinutes('1 Hour'), 60);
      expect(parseOvertimeApprovalDurationMinutes(''), 0);
    });
  });

  group('Overtime and Extra Time Split Calculation (User Scenario)', () {
    test('Extra time 41m with approved overtime request of 35m gives 35m Overtime and 6m Extra Time', () {
      // User scenario:
      // On 17-Oct: punches before shift = 35m (08:25-09:00), punches after shift = 6m (17:00-17:06).
      // Total extra time = 41m.
      // Request registered: Overtime Approval from 08:25 to 09:00 = 35 min.
      int extraTimeMinutes = 41;
      int nightExtraMinutes = 0;
      int overtimeMinutes = 0;

      final requests = [
        Request(
          id: 'req_1',
          type: 'Overtime Approval',
          date: 'October 17, 2026',
          duration: 'From 08:25 to 09:00 (0.6 Hours)',
          status: 'Approved',
        ),
      ];

      final group = EmployeeGroup(
        id: 'g1',
        name: 'Standard',
        shiftId: 's1',
        overtimeAllowed: true,
      );

      int approvedOvertimeMinutes = 0;
      bool hasApprovedOt = false;
      for (final req in requests) {
        if (req.type == 'Overtime Approval' && req.status == 'Approved') {
          hasApprovedOt = true;
          final mins = parseOvertimeApprovalDurationMinutes(req.duration);
          approvedOvertimeMinutes += mins > 0 ? mins : 0;
        }
      }

      expect(hasApprovedOt, isTrue);
      expect(approvedOvertimeMinutes, 35);

      if (extraTimeMinutes > 0 && hasApprovedOt) {
        final effectiveOtExtra = approvedOvertimeMinutes > 0
            ? (extraTimeMinutes < approvedOvertimeMinutes ? extraTimeMinutes : approvedOvertimeMinutes)
            : extraTimeMinutes;

        if (effectiveOtExtra > 0) {
          final nightPortion = extraTimeMinutes > 0
              ? (nightExtraMinutes * (effectiveOtExtra / extraTimeMinutes)).round()
              : 0;

          overtimeMinutes = group.calculateOvertimeMinutes(
            dayExtraMinutes: effectiveOtExtra,
            nightExtraMinutes: nightPortion,
            isWeekend: false,
            isHoliday: false,
          );

          if (overtimeMinutes > 0) {
            extraTimeMinutes = extraTimeMinutes - effectiveOtExtra;
            if (extraTimeMinutes < 0) extraTimeMinutes = 0;
          }
        }
      }

      // Expected exact result as required by user:
      expect(overtimeMinutes, 35, reason: 'Overtime must be exactly 35m');
      expect(extraTimeMinutes, 6, reason: 'Remaining extra time must be exactly 6m');
    });

    test('Both requests approved (35m + 6m) converts all 41m to overtime and 0m extra time', () {
      int extraTimeMinutes = 41;
      int overtimeMinutes = 0;

      final requests = [
        Request(
          id: 'req_1',
          type: 'Overtime Approval',
          date: 'October 17, 2026',
          duration: 'From 08:25 to 09:00 (0.6 Hours)',
          status: 'Approved',
        ),
        Request(
          id: 'req_2',
          type: 'Overtime Approval',
          date: 'October 17, 2026',
          duration: 'From 17:00 to 17:06 (0.1 Hours)',
          status: 'Approved',
        ),
      ];

      final group = EmployeeGroup(
        id: 'g1',
        name: 'Standard',
        shiftId: 's1',
        overtimeAllowed: true,
      );

      int approvedOvertimeMinutes = 0;
      bool hasApprovedOt = false;
      for (final req in requests) {
        if (req.type == 'Overtime Approval' && req.status == 'Approved') {
          hasApprovedOt = true;
          final mins = parseOvertimeApprovalDurationMinutes(req.duration);
          approvedOvertimeMinutes += mins > 0 ? mins : 0;
        }
      }

      expect(approvedOvertimeMinutes, 41);

      if (extraTimeMinutes > 0 && hasApprovedOt) {
        final effectiveOtExtra = approvedOvertimeMinutes > 0
            ? (extraTimeMinutes < approvedOvertimeMinutes ? extraTimeMinutes : approvedOvertimeMinutes)
            : extraTimeMinutes;

        if (effectiveOtExtra > 0) {
          overtimeMinutes = group.calculateOvertimeMinutes(
            dayExtraMinutes: effectiveOtExtra,
            nightExtraMinutes: 0,
            isWeekend: false,
            isHoliday: false,
          );

          if (overtimeMinutes > 0) {
            extraTimeMinutes = extraTimeMinutes - effectiveOtExtra;
            if (extraTimeMinutes < 0) extraTimeMinutes = 0;
          }
        }
      }

      expect(overtimeMinutes, 41);
      expect(extraTimeMinutes, 0);
    });

    test('Pending request does not convert extra time to overtime', () {
      int extraTimeMinutes = 41;
      int overtimeMinutes = 0;

      final requests = [
        Request(
          id: 'req_1',
          type: 'Overtime Approval',
          date: 'October 17, 2026',
          duration: 'From 08:25 to 09:00 (0.6 Hours)',
          status: 'Pending',
        ),
      ];

      final group = EmployeeGroup(
        id: 'g1',
        name: 'Standard',
        shiftId: 's1',
        overtimeAllowed: true,
      );

      int approvedOvertimeMinutes = 0;
      bool hasApprovedOt = false;
      for (final req in requests) {
        if (req.type == 'Overtime Approval' && req.status == 'Approved') {
          hasApprovedOt = true;
          final mins = parseOvertimeApprovalDurationMinutes(req.duration);
          approvedOvertimeMinutes += mins > 0 ? mins : 0;
        }
      }

      expect(hasApprovedOt, isFalse);
      expect(approvedOvertimeMinutes, 0);

      if (extraTimeMinutes > 0 && hasApprovedOt) {
        final effectiveOtExtra = approvedOvertimeMinutes > 0
            ? (extraTimeMinutes < approvedOvertimeMinutes ? extraTimeMinutes : approvedOvertimeMinutes)
            : extraTimeMinutes;

        if (effectiveOtExtra > 0) {
          overtimeMinutes = group.calculateOvertimeMinutes(
            dayExtraMinutes: effectiveOtExtra,
            nightExtraMinutes: 0,
            isWeekend: false,
            isHoliday: false,
          );
        }
      }

      expect(overtimeMinutes, 0);
      expect(extraTimeMinutes, 41);
    });
  });
}
