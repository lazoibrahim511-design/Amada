import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/attendance_record.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/request_model.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Approved Missing Punch Reconciliation Tests', () {
    late AttendanceProvider provider;
    late CompanyEmployee emp;
    late WorkShift shift;

    setUp(() {
      provider = AttendanceProvider();
      emp = CompanyEmployee(
        id: 'emp_test',
        name: 'iawi lazo ibrahim',
        email: 'iawi@company.com',
        position: 'Team Member',
      );
      shift = WorkShift(
        id: 'shift_default',
        name: '09:00 - 17:00',
        startTime: '09:00',
        endTime: '17:00',
        workingDays: [1, 2, 3, 4, 5, 6, 7],
      );
    });

    test('Tuesday 20 Oct user scenario: 12:30-13:32 and 16:40-null with approved Clock In: 09:00', () {
      final targetDate = DateTime(2026, 10, 20);

      // Raw punches as observed in user screenshot
      final rawRecords = [
        AttendanceRecord(
          checkIn: DateTime(2026, 10, 20, 12, 30),
          checkOut: DateTime(2026, 10, 20, 13, 32),
          employeeId: emp.id,
        ),
        AttendanceRecord(
          checkIn: DateTime(2026, 10, 20, 16, 40),
          checkOut: null,
          employeeId: emp.id,
        ),
      ];

      // Approved request: Missing Punch for Clock In: 09:00
      final requests = [
        Request(
          id: 'req_1',
          employeeId: emp.id,
          type: 'Missing Punch',
          date: 'October 20, 2026',
          duration: 'Clock In: 09:00',
          status: 'Approved',
        ),
      ];

      final reconciled = provider.getRecordsForDate(
        targetDate,
        emp: emp,
        recordsPool: rawRecords,
        requestsPool: requests,
      );

      // Should pair into 2 completed sessions:
      // Session 1: 09:00 -> 12:30 (3h 30m)
      // Session 2: 13:32 -> 16:40 (3h 8m)
      expect(reconciled.length, 2);

      expect(reconciled[0].checkIn, DateTime(2026, 10, 20, 9, 0));
      expect(reconciled[0].checkOut, DateTime(2026, 10, 20, 12, 30));

      expect(reconciled[1].checkIn, DateTime(2026, 10, 20, 13, 32));
      expect(reconciled[1].checkOut, DateTime(2026, 10, 20, 16, 40));

      // Total attendance: (12:30 - 09:00 = 210m) + (16:40 - 13:32 = 188m) = 398m = 6h 38m
      final totalMins = reconciled.fold<int>(0, (sum, r) => sum + r.duration.inMinutes);
      expect(totalMins, 398);
      expect(totalMins ~/ 60, 6);
      expect(totalMins % 60, 38);
    });

    test('Zero physical punches with approved Clock In: 09:00 and Clock Out: 17:00 produces completed 8h record', () {
      final targetDate = DateTime(2026, 10, 21);

      final requests = [
        Request(
          id: 'req_2',
          employeeId: emp.id,
          type: 'Missing Punch',
          date: 'October 21, 2026',
          duration: 'Clock In: 09:00 Clock Out: 17:00',
          status: 'Approved',
        ),
      ];

      final reconciled = provider.getRecordsForDate(
        targetDate,
        emp: emp,
        recordsPool: [],
        requestsPool: requests,
      );

      expect(reconciled.length, 1);
      expect(reconciled[0].checkIn, DateTime(2026, 10, 21, 9, 0));
      expect(reconciled[0].checkOut, DateTime(2026, 10, 21, 17, 0));
      expect(reconciled[0].duration.inMinutes, 480);
    });

    test('Single checkIn with missing checkOut completed by approved Clock Out: 17:00', () {
      final targetDate = DateTime(2026, 10, 22);

      final rawRecords = [
        AttendanceRecord(
          checkIn: DateTime(2026, 10, 22, 9, 0),
          checkOut: null,
          employeeId: emp.id,
        ),
      ];

      final requests = [
        Request(
          id: 'req_3',
          employeeId: emp.id,
          type: 'Missing Punch',
          date: 'October 22, 2026',
          duration: 'Clock Out: 17:00',
          status: 'Approved',
        ),
      ];

      final reconciled = provider.getRecordsForDate(
        targetDate,
        emp: emp,
        recordsPool: rawRecords,
        requestsPool: requests,
      );

      expect(reconciled.length, 1);
      expect(reconciled[0].checkIn, DateTime(2026, 10, 22, 9, 0));
      expect(reconciled[0].checkOut, DateTime(2026, 10, 22, 17, 0));
      expect(reconciled[0].duration.inMinutes, 480);
    });

    test('Unapproved / Pending Missing Punch does not alter records', () {
      final targetDate = DateTime(2026, 10, 23);

      final rawRecords = [
        AttendanceRecord(
          checkIn: DateTime(2026, 10, 23, 12, 30),
          checkOut: DateTime(2026, 10, 23, 13, 32),
          employeeId: emp.id,
        ),
      ];

      final requests = [
        Request(
          id: 'req_4',
          employeeId: emp.id,
          type: 'Missing Punch',
          date: 'October 23, 2026',
          duration: 'Clock In: 09:00',
          status: 'Pending HR',
        ),
      ];

      final reconciled = provider.getRecordsForDate(
        targetDate,
        emp: emp,
        recordsPool: rawRecords,
        requestsPool: requests,
      );

      // Pending should not change records
      expect(reconciled.length, 1);
      expect(reconciled[0].checkIn, DateTime(2026, 10, 23, 12, 30));
      expect(reconciled[0].checkOut, DateTime(2026, 10, 23, 13, 32));
    });

    test('Tuesday 20 Oct metrics: Delay is 0m, Early Exit is 20m, Duty is 6h 38m, Attendance is 6h 38m', () {
      final targetDate = DateTime(2026, 10, 20);

      final rawRecords = [
        AttendanceRecord(
          checkIn: DateTime(2026, 10, 20, 12, 30),
          checkOut: DateTime(2026, 10, 20, 13, 32),
          employeeId: emp.id,
        ),
        AttendanceRecord(
          checkIn: DateTime(2026, 10, 20, 16, 40),
          checkOut: null,
          employeeId: emp.id,
        ),
      ];

      final requests = [
        Request(
          id: 'req_1',
          employeeId: emp.id,
          type: 'Missing Punch',
          date: 'October 20, 2026',
          duration: 'Clock In: 09:00',
          status: 'Approved',
        ),
      ];

      final dateRecords = provider.getRecordsForDate(
        targetDate,
        emp: emp,
        recordsPool: rawRecords,
        requestsPool: requests,
      );

      final shiftStart = DateTime(2026, 10, 20, 9, 0);
      final shiftEnd = DateTime(2026, 10, 20, 17, 0);

      // 1. Attendance & Duty
      int totalActualMinutes = 0;
      int dutyMinutes = 0;
      for (var rec in dateRecords) {
        totalActualMinutes += rec.duration.inMinutes;

        final rawStart = rec.checkIn;
        final rawEnd = rec.checkOut ?? rawStart;
        final intersectStart = rawStart.isAfter(shiftStart) ? rawStart : shiftStart;
        final intersectEnd = rawEnd.isBefore(shiftEnd) ? rawEnd : shiftEnd;
        if (intersectEnd.isAfter(intersectStart)) {
          dutyMinutes += intersectEnd.difference(intersectStart).inMinutes;
        }
      }

      expect(totalActualMinutes, 398); // 6h 38m
      expect(dutyMinutes, 398); // 6h 38m

      // 2. Delay & Early Exit
      final sortedRecords = List<AttendanceRecord>.from(dateRecords)
        ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

      int delayMinutes = 0;
      int earlyExitMinutes = 0;

      final firstRec = sortedRecords.first;
      final delay = firstRec.checkIn.difference(shiftStart).inMinutes;
      if (delay > shift.forgivenessOfDelay) {
        delayMinutes = delay;
      }

      final lastRec = sortedRecords.last;
      if (lastRec.checkOut != null) {
        final earlyExit = shiftEnd.difference(lastRec.checkOut!).inMinutes;
        if (earlyExit > shift.earlyExit) {
          earlyExitMinutes = earlyExit;
        }
      }

      expect(delayMinutes, 0); // Started at 09:00, so Delay is 0m!
      expect(earlyExitMinutes, 20); // Left at 16:40 instead of 17:00, so Early Exit is 20m!

      // 3. Clock time formatting
      final List<String> sessionTimes = [];
      for (var rec in sortedRecords) {
        final startStr = '${rec.checkIn.hour.toString().padLeft(2, '0')}:${rec.checkIn.minute.toString().padLeft(2, '0')}';
        final endStr = rec.checkOut != null
            ? '${rec.checkOut!.hour.toString().padLeft(2, '0')}:${rec.checkOut!.minute.toString().padLeft(2, '0')}'
            : 'Missing';
        sessionTimes.add('$startStr - $endStr');
      }
      final clockTimeStr = sessionTimes.join('\n');
      expect(clockTimeStr, '09:00 - 12:30\n13:32 - 16:40');
    });

    test('Cross-employee isolation: Employee A approved missing punch does NOT leak to Employee B', () {
      final targetDate = DateTime(2026, 11, 15);
      final empA = CompanyEmployee(
        id: 'emp_A',
        name: 'Bilal Admin',
        email: 'bilal@bestenergy.com',
        position: 'HR Admin',
      );
      final empB = CompanyEmployee(
        id: 'emp_B',
        name: 'Shaho Worker',
        email: 'shaho@bestenergy.com',
        position: 'Worker',
      );

      // Approved request for Employee A at 08:45
      final sharedRequestsPool = [
        Request(
          id: 'req_empA',
          employeeId: empA.id,
          type: 'Missing Punch',
          date: 'November 15, 2026',
          duration: 'Clock In: 08:45',
          status: 'Approved',
        ),
      ];

      // Reconcile for Employee A
      final reconciledA = provider.getRecordsForDate(
        targetDate,
        emp: empA,
        recordsPool: [],
        requestsPool: sharedRequestsPool,
      );
      expect(reconciledA.length, 1);
      expect(reconciledA.first.checkIn, DateTime(2026, 11, 15, 8, 45));

      // Reconcile for Employee B with the exact same shared requests pool
      final reconciledB = provider.getRecordsForDate(
        targetDate,
        emp: empB,
        recordsPool: [],
        requestsPool: sharedRequestsPool,
      );
      // Must be empty! Employee B should NEVER receive Employee A's 08:45 punch!
      expect(reconciledB.isEmpty, isTrue);
    });

    test('Deleted punch signature prevents deleted punch or request from re-appearing in reconciled records', () {
      final targetDate = DateTime(2026, 11, 15);
      final employee = CompanyEmployee(
        id: 'emp_accidental',
        name: 'Accidental Puncher',
        email: 'accidental@test.com',
        position: 'Staff',
      );

      final reqs = [
        Request(
          id: 'req_acc',
          employeeId: employee.id,
          type: 'Missing Punch',
          date: 'November 15, 2026',
          duration: 'Clock In: 08:45',
          status: 'Approved',
        ),
      ];

      // Initially reconciled
      final beforeDelete = provider.getRecordsForDate(
        targetDate,
        emp: employee,
        recordsPool: [],
        requestsPool: reqs,
      );
      expect(beforeDelete.length, 1);
      expect(beforeDelete.first.checkIn, DateTime(2026, 11, 15, 8, 45));

      // Admin blacklists / deletes this accidental punch
      provider.recordDeletedPunchSignature(employee.id, DateTime(2026, 11, 15, 8, 45));

      // Now re-checking getRecordsForDate: the deleted punch MUST be excluded!
      final afterDelete = provider.getRecordsForDate(
        targetDate,
        emp: employee,
        recordsPool: [],
        requestsPool: reqs,
      );
      expect(afterDelete.isEmpty, isTrue);
    });

    test('Company scoped ID matching: employee with id "6" matches record with employeeId "bestenergy_6" or "6"', () {
      final targetDate = DateTime(2026, 11, 10);
      final jalalEmp = CompanyEmployee(
        id: '6',
        name: 'جلال محمد رشاد',
        email: 'jalal@gmail.com',
        companyCode: 'bestenergy',
        position: 'وەستا',
      );

      final records = [
        AttendanceRecord(
          checkIn: DateTime(2026, 11, 10, 8, 0),
          checkOut: DateTime(2026, 11, 10, 20, 32),
          employeeId: 'bestenergy_6',
          companyCode: 'bestenergy',
        ),
      ];

      final dateRecords = provider.getRecordsForDate(
        targetDate,
        emp: jalalEmp,
        recordsPool: records,
      );

      expect(dateRecords.length, 1);
      expect(dateRecords.first.checkIn, DateTime(2026, 11, 10, 8, 0));
      expect(dateRecords.first.checkOut, DateTime(2026, 11, 10, 20, 32));
    });
  });
}

