import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/attendance_record.dart';
import 'package:attendance_app/models/request_model.dart';
import 'package:attendance_app/providers/attendance_provider.dart';
import 'package:attendance_app/services/zkteco_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Tenant Requests and Records Scoping Tests', () {
    test('allCompanyRequests and allCompanyRecords strictly isolate by company', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = AttendanceProvider(
        initialCompanyCode: 'bestenergy',
      );

      // Wait for constructor async initialization to settle
      await Future.delayed(const Duration(milliseconds: 100));

      final bestEnergyAdmin = CompanyEmployee(
        id: 'be_admin',
        name: 'Best Energy Admin',
        email: 'admin@bestenergy.com',
        position: 'Admin',
        role: 'admin',
        companyCode: 'bestenergy',
      );

      final bestEnergyEmp = CompanyEmployee(
        id: 'be_emp_1',
        name: 'Bilal',
        email: 'bilal@bestenergy.com',
        position: 'Field Engineer',
        role: 'employee',
        companyCode: 'bestenergy',
      );

      final otherCompanyEmp = CompanyEmployee(
        id: 'other_emp_99',
        name: 'Foreign Employee',
        email: 'user@other.com',
        position: 'Staff',
        role: 'employee',
        companyCode: 'lazo',
      );

      // Add company employees
      await provider.addEmployee(bestEnergyAdmin);
      await provider.addEmployee(bestEnergyEmp);
      await provider.addEmployee(otherCompanyEmp);

      // Login as bestEnergyAdmin
      await provider.loginAsEmployee(bestEnergyAdmin);

      // Verify current company code
      expect(provider.currentCompanyCode, equals('bestenergy'));

      // Create attendance records
      final rec1 = AttendanceRecord(
        checkIn: DateTime.now().subtract(const Duration(hours: 2)),
        employeeId: 'be_emp_1',
      );
      final recForeign = AttendanceRecord(
        checkIn: DateTime.now().subtract(const Duration(hours: 3)),
        employeeId: 'other_emp_99',
      );

      provider.upsertRecordLocally(rec1);
      provider.upsertRecordLocally(recForeign);

      // Check allCompanyRecords for bestenergy:
      final companyRecords = provider.allCompanyRecords;
      expect(companyRecords.any((r) => r.employeeId == 'be_emp_1'), isTrue);
      expect(companyRecords.any((r) => r.employeeId == 'other_emp_99'), isFalse);

      // Submit request as Bilal (switch user momentarily)
      await provider.loginAsEmployee(bestEnergyEmp);
      await provider.submitRequest('Annual Leave', '2026-11-20', '2 Days');

      // Now login back as Best Energy Admin
      await provider.loginAsEmployee(bestEnergyAdmin);

      // In bestenergy view, only Best Energy request should appear
      final companyRequests = provider.allCompanyRequests;
      expect(companyRequests.any((r) => r.employeeId == 'be_emp_1'), isTrue);
      expect(companyRequests.any((r) => r.employeeId == 'other_emp_99'), isFalse);

      // Pending approvals count should count Bilal's pending request
      expect(provider.pendingApprovalsCount, greaterThanOrEqualTo(1));
    });

    test('Master view ("all") sees requests across all tenants, switching isolates each', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider(initialCompanyCode: 'all');
      await Future.delayed(const Duration(milliseconds: 50));

      final empA = CompanyEmployee(
        id: 'emp_a1',
        name: 'Employee A',
        email: 'a1@amada.com',
        position: 'Staff',
        role: 'employee',
        companyCode: 'amada',
      );
      final empB = CompanyEmployee(
        id: 'emp_b1',
        name: 'Employee B',
        email: 'b1@bestenergy.com',
        position: 'Staff',
        role: 'employee',
        companyCode: 'bestenergy',
      );

      await provider.addEmployee(empA);
      await provider.addEmployee(empB);

      // Submit request for empA
      await provider.loginAsEmployee(empA);
      await provider.submitRequest('Annual Leave', '2026-11-21', '1 Day');

      // Submit request for empB
      await provider.loginAsEmployee(empB);
      await provider.submitRequest('Sick Leave', '2026-11-22', '1 Day');

      // In 'all' master view, both requests must be visible
      await provider.setCompanyCode('all');
      expect(provider.allCompanyRequests.any((r) => r.employeeId == 'emp_a1'), isTrue);
      expect(provider.allCompanyRequests.any((r) => r.employeeId == 'emp_b1'), isTrue);

      // In 'amada' company view, ONLY empA request must be visible
      await provider.setCompanyCode('amada');
      expect(provider.allCompanyRequests.any((r) => r.employeeId == 'emp_a1'), isTrue);
      expect(provider.allCompanyRequests.any((r) => r.employeeId == 'emp_b1'), isFalse);

      // In 'bestenergy' company view, ONLY empB request must be visible
      await provider.setCompanyCode('bestenergy');
      expect(provider.allCompanyRequests.any((r) => r.employeeId == 'emp_a1'), isFalse);
      expect(provider.allCompanyRequests.any((r) => r.employeeId == 'emp_b1'), isTrue);
    });

    test('Identical employee ID "1" across lazo and bestenergy are 100% isolated', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider(initialCompanyCode: 'lazo');
      await Future.delayed(const Duration(milliseconds: 50));

      final lazoEmp1 = CompanyEmployee(
        id: '1',
        name: 'Lazo Employee One',
        email: 'emp1@lazo.com',
        position: 'Engineer',
        role: 'employee',
        companyCode: 'lazo',
      );

      final bestEnergyEmp1 = CompanyEmployee(
        id: '1',
        name: 'Best Energy Employee One',
        email: 'emp1@bestenergy.com',
        position: 'Technician',
        role: 'employee',
        companyCode: 'bestenergy',
      );

      final bestEnergyHR = CompanyEmployee(
        id: 'be_hr',
        name: 'Best Energy HR',
        email: 'hr@bestenergy.com',
        position: 'HR Manager',
        role: 'hr',
        companyCode: 'bestenergy',
      );

      await provider.addEmployee(lazoEmp1);
      await provider.addEmployee(bestEnergyEmp1);
      await provider.addEmployee(bestEnergyHR);

      // --- Test 1: Requests Isolation ---
      // Log in as Lazo employee 1 and submit a request
      await provider.setCompanyCode('lazo');
      await provider.loginAsEmployee(lazoEmp1);
      await provider.submitRequest('Sick Leave', '2026-11-25', '1 Day');

      // Check Lazo employee 1 requests
      expect(provider.requests.length, equals(1));
      expect(provider.requests.first.companyCode, equals('lazo'));

      // Switch to Best Energy view
      await provider.setCompanyCode('bestenergy');
      await provider.loginAsEmployee(bestEnergyEmp1);

      // Best Energy employee 1's "requests" must be EMPTY (no bleed from Lazo employee 1)
      expect(provider.requests.isEmpty, isTrue);

      // Best Energy HR dashboard must NOT see Lazo employee 1's request
      await provider.loginAsEmployee(bestEnergyHR);
      final beRequests = provider.allCompanyRequests;
      expect(beRequests.any((r) => r.companyCode == 'lazo'), isFalse);
      expect(provider.getRequestsForEmployee('1', companyCode: 'bestenergy').isEmpty, isTrue);

      // Switch back to Lazo: request is there
      await provider.setCompanyCode('lazo');
      expect(provider.allCompanyRequests.any((r) => r.companyCode == 'lazo'), isTrue);

      // --- Test 2: Biometric Punch Isolation with Same ID "1" ---
      final now = DateTime.now();
      final lazoPunch = AttendanceRecord(
        checkIn: DateTime(now.year, now.month, now.day, 8, 30),
        employeeId: '1',
        companyCode: 'lazo',
      );
      final bestEnergyPunch = AttendanceRecord(
        checkIn: DateTime(now.year, now.month, now.day, 9, 0),
        checkOut: DateTime(now.year, now.month, now.day, 9, 30),
        employeeId: '1',
        companyCode: 'bestenergy',
      );

      provider.upsertRecordLocally(lazoPunch);
      provider.upsertRecordLocally(bestEnergyPunch);

      // In lazo company view:
      await provider.setCompanyCode('lazo');
      final lazoRecords = provider.allCompanyRecords;
      expect(lazoRecords.any((r) => r.checkIn.hour == 8 && r.checkIn.minute == 30), isTrue);
      expect(lazoRecords.any((r) => r.checkIn.hour == 9 && r.checkIn.minute == 0), isFalse);

      // In bestenergy company view:
      await provider.setCompanyCode('bestenergy');
      final beRecords = provider.allCompanyRecords;
      expect(beRecords.any((r) => r.checkIn.hour == 8 && r.checkIn.minute == 30), isFalse);
      expect(beRecords.any((r) => r.checkIn.hour == 9 && r.checkIn.minute == 0), isTrue);

      // When logged in as Best Energy employee 1:
      await provider.loginAsEmployee(bestEnergyEmp1);
      expect(provider.records.any((r) => r.checkIn.hour == 9 && r.checkIn.minute == 0), isTrue);
      expect(provider.records.any((r) => r.checkIn.hour == 8 && r.checkIn.minute == 30), isFalse);

      // --- Test 3: ZKTeco Service Biometric Device Punch Pairing Isolation ---
      final zkService = ZkTecoService.instance;
      final biometricPunchTime = DateTime(now.year, now.month, now.day, 10, 15);

      // Best Energy biometric device produces raw punch for userId '1'
      final rawPunch = ZkRawPunch(
        userId: '1',
        timestamp: biometricPunchTime,
        status: 0,
        punchType: 0,
      );

      await zkService.pairAndSavePunchesForTesting(
        punches: [rawPunch],
        provider: provider,
        firebase: provider.firebaseService,
        deviceCompanyCode: 'bestenergy',
      );

      // Verify Best Energy employee 1 has the biometric record
      await provider.setCompanyCode('bestenergy');
      final beBiometricRecords = provider.allCompanyRecords;
      expect(
        beBiometricRecords.any((r) =>
            r.employeeId == '1' &&
            r.companyCode == 'bestenergy' &&
            r.checkIn.hour == 10 &&
            r.checkIn.minute == 15),
        isTrue,
      );

      // Verify Lazo employee 1 did NOT get this biometric punch
      await provider.setCompanyCode('lazo');
      final lazoBiometricRecords = provider.allCompanyRecords;
      expect(
        lazoBiometricRecords.any((r) =>
            r.employeeId == '1' &&
            r.checkIn.hour == 10 &&
            r.checkIn.minute == 15),
        isFalse,
      );
    });

    test('Mock/dummy requests (req_1..req_4) are strictly excluded and client admin starts clean', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider(initialCompanyCode: 'bestenergy');
      await Future.delayed(const Duration(milliseconds: 50));

      final beAdmin = CompanyEmployee(
        id: 'bestenergy_admin',
        name: 'Best Energy Admin',
        email: 'admin@bestenergy.com',
        position: 'Administrator',
        role: 'admin',
        companyCode: 'bestenergy',
      );

      await provider.addEmployee(beAdmin);
      await provider.loginAsEmployee(beAdmin);

      // Verify isMockRequestId identifies legacy mock requests
      expect(AttendanceProvider.isMockRequestId('req_1'), isTrue);
      expect(AttendanceProvider.isMockRequestId('req_2'), isTrue);
      expect(AttendanceProvider.isMockRequestId('req_3'), isTrue);
      expect(AttendanceProvider.isMockRequestId('req_4'), isTrue);
      expect(
        AttendanceProvider.isMockRequestId('custom_id', 'May 14, 2026', 'Sick Leave'),
        isTrue,
      );
      expect(
        AttendanceProvider.isMockRequestId('req_${DateTime.now().millisecondsSinceEpoch}'),
        isFalse,
      );

      // Simulate legacy mock requests being injected in in-memory caches
      final mock1 = Request(
        id: 'req_1',
        type: 'Sick Leave',
        date: 'May 14, 2026',
        duration: '1 Day',
        status: 'Approved',
        employeeId: 'bestenergy_admin',
      );
      final mock2 = Request(
        id: 'req_2',
        type: 'Annual Leave',
        date: 'June 15 - June 18, 2026',
        duration: '4 Days',
        status: 'Pending',
        employeeId: 'bestenergy_admin',
      );

      // Even if inserted into local structures, getters must filter them out
      provider.upsertRequestLocally(mock1);
      provider.upsertRequestLocally(mock2);

      expect(provider.requests.isEmpty, isTrue);
      expect(provider.allCompanyRequests.isEmpty, isTrue);
      expect(provider.pendingApprovalsCount, equals(0));
    });
  });
}
