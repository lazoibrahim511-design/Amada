import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/attendance_record.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

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
        position: 'HR Manager',
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
  });
}
