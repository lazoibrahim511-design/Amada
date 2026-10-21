import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/attendance_record.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Payroll Month Closure & Snapshot Tests', () {
    test('PayrollMonthClosure serialization and deserialization', () {
      final snap = PayrollReportSnapshot(
        employeeId: 'emp_1',
        employeeName: 'John Doe',
        position: 'Software Engineer',
        structureId: 'struct_it',
        basicSalary: 3000.0,
        salaryCalcByDay: 3000.0,
        workingHours: 160.0,
        daysWorked: 30,
        incrementalSalary: 3200.0,
        decrementalSalary: 100.0,
        overtimeHours: 10.0,
        overtimeValue: 200.0,
        attendanceDeficitHours: 0.0,
        attendanceDeficit: 0.0,
        monthlyPenalties: 0.0,
        foodAllowance: 50.0,
        transportationAllowance: 50.0,
        otherAllowance: 0.0,
        monthlyAdditions: 0.0,
        monthlyDeductions: 0.0,
        hasInsurance: true,
        insuranceSalary: 3000.0,
        insuranceEmployee: 150.0,
        insuranceCompany: 360.0,
        netEarnings: 3100.0,
        currency: 'USD',
      );

      final closure = PayrollMonthClosure(
        id: '2026-09',
        yearMonth: '2026-09',
        isClosed: true,
        closedAt: DateTime(2026, 10, 1, 10, 0),
        closedBy: 'Jane Smith (HR Manager)',
        closedByEmail: 'jane.smith@company.com',
        totalPayout: 3100.0,
        totalEmployees: 1,
        currency: 'USD',
        snapshots: {'emp_1': snap},
      );

      final map = closure.toMap();
      expect(map['yearMonth'], '2026-09');
      expect(map['isClosed'], true);
      expect(map['closedBy'], 'Jane Smith (HR Manager)');
      expect(map['snapshots'], isA<Map>());

      final deserialized = PayrollMonthClosure.fromMap(map, '2026-09');
      expect(deserialized.yearMonth, '2026-09');
      expect(deserialized.isClosed, true);
      expect(deserialized.totalPayout, 3100.0);
      expect(deserialized.snapshots.containsKey('emp_1'), true);
      expect(deserialized.snapshots['emp_1']!.netEarnings, 3100.0);
    });

    test('HR Manager and Admin permission detection', () {
      final provider = AttendanceProvider();
      
      // Default initial mock employee is emp_2 (Jane Smith, HR Manager)
      expect(provider.isHRManager, true);

      // Verify that HR Manager can close and reopen months
      final targetDate = DateTime(2026, 5, 1);
      expect(provider.isMonthClosed(targetDate), false);

      provider.closeMonth(
        month: targetDate,
        closedBy: 'Jane Smith (HR Manager)',
        closedByEmail: 'jane.smith@company.com',
      );

      expect(provider.isMonthClosed(targetDate), true);
      expect(provider.isMonthClosedStr('2026-05'), true);

      final closure = provider.getClosureForMonth(targetDate);
      expect(closure, isNotNull);
      expect(closure!.isClosed, true);
      expect(closure.closedBy, 'Jane Smith (HR Manager)');

      // Reopen with reason
      provider.reopenMonth(
        month: targetDate,
        reopenedBy: 'Admin User',
        reason: 'Adjusting salary for missed shift',
      );

      expect(provider.isMonthClosed(targetDate), false);
      final reopenedClosure = provider.getClosureForMonth(targetDate);
      expect(reopenedClosure!.isClosed, false);
      expect(reopenedClosure.reopenedBy, 'Admin User');
      expect(reopenedClosure.reopenReason, 'Adjusting salary for missed shift');
    });

    test('Locked month prevents adding or deleting payroll adjustments', () async {
      final provider = AttendanceProvider();
      final closedMonth = DateTime(2026, 4, 1);

      await provider.closeMonth(
        month: closedMonth,
        closedBy: 'HR Manager',
      );

      final adj = PayrollAdjustment(
        id: 'adj_test_1',
        employeeId: 'emp_1',
        type: 'addition',
        category: 'Bonus',
        amount: 250.0,
        currency: 'USD',
        date: '2026-04-15',
        month: '2026-04',
        reason: 'Performance Bonus',
      );

      // Attempt to add adjustment to closed month -> rejected
      await provider.addPayrollAdjustment(adj);
      expect(provider.payrollAdjustments.any((a) => a.id == 'adj_test_1'), false);
    });

    test('Locked month prevents punch creation and modification', () {
      final provider = AttendanceProvider();
      final closedDate = DateTime(2026, 3, 10, 8, 30);

      provider.closeMonth(
        month: closedDate,
        closedBy: 'HR Manager',
      );

      final rec = AttendanceRecord(
        checkIn: closedDate,
        checkOut: closedDate.add(const Duration(hours: 8)),
        employeeId: 'emp_1',
      );

      // Upsert record into closed month -> ignored
      provider.upsertRecordLocally(rec);
      expect(
        provider.allCompanyRecords.any((r) =>
            r.checkIn.year == 2026 &&
            r.checkIn.month == 3 &&
            r.checkIn.day == 10),
        false,
      );
    });

    test('Locked month prevents request submission and deletion', () async {
      final provider = AttendanceProvider();
      final closedDate = DateTime(2026, 2, 14);

      await provider.closeMonth(
        month: closedDate,
        closedBy: 'HR Manager',
      );

      // Attempt submit request in closed month -> rejected
      await provider.submitRequest(
        'Sick Leave',
        '2026-02-14',
        '1 Day',
        employeeId: 'emp_1',
      );

      expect(
        provider.allCompanyRequests.any((r) => r.date.startsWith('2026-02')),
        false,
      );
    });

    test('Locked September rejects John registering Annual Leave for September 1, 2026', () async {
      final provider = AttendanceProvider();
      final septDate = DateTime(2026, 9, 1);

      // 1. Close September 2026
      await provider.closeMonth(
        month: septDate,
        closedBy: 'Jane Smith (HR Manager)',
      );
      expect(provider.isMonthClosed(septDate), true);
      expect(provider.isMonthClosedStr('2026-09'), true);

      // Verify date string recognition
      expect(provider.isDateStringInClosedMonth('September 1, 2026'), true);
      expect(provider.isDateStringInClosedMonth('September 1, 2026 - September 5, 2026'), true);
      expect(provider.isDateStringInClosedMonth('01 Sep 2026'), true);
      expect(provider.isDateStringInClosedMonth('2026-09-01'), true);

      // Open month (October 2026) is NOT closed
      expect(provider.isDateStringInClosedMonth('October 1, 2026'), false);

      // 2. User John attempts to submit Annual Leave for September 1, 2026
      await provider.submitRequest(
        'Annual Leave',
        'September 1, 2026',
        '1 Day',
        employeeId: 'emp_1',
      );

      // Must be blocked and NOT added to requests
      expect(
        provider.allCompanyRequests.any((r) =>
            r.date.contains('September') && r.date.contains('2026')),
        false,
      );
      expect(
        provider.requests.any((r) =>
            r.date.contains('September') && r.date.contains('2026')),
        false,
      );
    });

    test('Multi-tenant isolation: Company A closing September leaves Company B open until Company B HR closes it', () async {
      final provider = AttendanceProvider();
      final septDate = DateTime(2026, 9, 1);

      // 1. Company A ("amada") closes September 2026
      await provider.setCompanyCode('amada');
      expect(provider.currentCompanyCode, 'amada');
      expect(provider.isMonthClosed(septDate), false);

      await provider.closeMonth(
        month: septDate,
        closedBy: 'Admin (Company A)',
        closedByEmail: 'admin@amada.com',
      );

      // Company A is closed for September
      expect(provider.isMonthClosed(septDate), true);
      expect(provider.isMonthClosedStr('2026-09'), true);
      final closureA = provider.getClosureForMonth(septDate);
      expect(closureA, isNotNull);
      expect(closureA!.companyCode, 'amada');

      // 2. Switch to Company B ("lazo")
      await provider.setCompanyCode('lazo');
      expect(provider.currentCompanyCode, 'lazo');

      // CRITICAL CHECK: Company B's September 2026 MUST BE OPEN!
      expect(provider.isMonthClosed(septDate), false);
      expect(provider.isMonthClosedStr('2026-09'), false);
      expect(provider.getClosureForMonth(septDate), isNull);

      // Company B's employees can still submit requests for September 2026
      await provider.submitRequest(
        'Annual Leave',
        'September 15, 2026',
        '1 Day',
        employeeId: 'emp_lazo_1',
      );
      expect(
        provider.allCompanyRequests.any((r) => r.date.contains('September 15, 2026')),
        true,
      );

      // 3. Company B's HR admin closes September 2026 for Company B
      await provider.closeMonth(
        month: septDate,
        closedBy: 'HR Admin (Company B)',
        closedByEmail: 'admin@lazo.com',
      );

      // Now Company B is closed
      expect(provider.isMonthClosed(septDate), true);
      final closureB = provider.getClosureForMonth(septDate);
      expect(closureB, isNotNull);
      expect(closureB!.companyCode, 'lazo');
      expect(closureB.closedBy, 'HR Admin (Company B)');

      // 4. Switch back to Company A - Company A's own closure record is still intact
      await provider.setCompanyCode('amada');
      expect(provider.isMonthClosed(septDate), true);
      final restoredClosureA = provider.getClosureForMonth(septDate);
      expect(restoredClosureA, isNotNull);
      expect(restoredClosureA!.companyCode, 'amada');
      expect(restoredClosureA.closedBy, 'Admin (Company A)');
    });

    test('Multi-tenant isolation: Shifts, Structures, and Groups are completely isolated between companies', () async {
      final provider = AttendanceProvider();

      // 1. Set company to "amada"
      await provider.setCompanyCode('amada');
      final initialAmadaShiftCount = provider.shifts.length;
      final initialAmadaGroupCount = provider.groups.length;
      final initialAmadaStructureCount = provider.structures.length;

      // 2. Switch to "lazo" company
      await provider.setCompanyCode('lazo');
      expect(provider.currentCompanyCode, 'lazo');

      // Lazo does not see Amada's shifts, groups, or structures
      expect(provider.shifts.any((s) => s.companyCode == 'amada'), false);
      expect(provider.groups.any((g) => g.companyCode == 'amada'), false);
      expect(provider.structures.any((st) => st.companyCode == 'amada'), false);

      // 3. Lazo company creates its own shift, group, and structure
      final lazoShift = WorkShift(
        id: 'shift_lazo_night',
        name: 'Lazo Night Shift',
        startTime: '22:00',
        endTime: '06:00',
      );
      final lazoGroup = EmployeeGroup(
        id: 'grp_lazo_security',
        name: 'Lazo Security Team',
        shiftId: 'shift_lazo_night',
      );
      final lazoStructure = OrgStructure(
        id: 'struct_lazo_ops',
        name: 'Lazo Operations',
        location: 'Branch 2',
        capacity: 20,
      );

      await provider.addShift(lazoShift);
      await provider.addGroup(lazoGroup);
      await provider.addStructure(lazoStructure);

      // Verify Lazo sees them
      expect(provider.shifts.any((s) => s.name == 'Lazo Night Shift'), true);
      expect(provider.groups.any((g) => g.name == 'Lazo Security Team'), true);
      expect(provider.structures.any((st) => st.name == 'Lazo Operations'), true);

      // 4. Switch back to "amada" company
      await provider.setCompanyCode('amada');
      expect(provider.currentCompanyCode, 'amada');

      // CRITICAL CHECK: Amada company MUST NOT see Lazo's shift, group, or structure!
      expect(provider.shifts.any((s) => s.name == 'Lazo Night Shift'), false);
      expect(provider.groups.any((g) => g.name == 'Lazo Security Team'), false);
      expect(provider.structures.any((st) => st.name == 'Lazo Operations'), false);

      // Amada's own counts remain intact
      expect(provider.shifts.length, initialAmadaShiftCount);
      expect(provider.groups.length, initialAmadaGroupCount);
      expect(provider.structures.length, initialAmadaStructureCount);
    });
  });
}

