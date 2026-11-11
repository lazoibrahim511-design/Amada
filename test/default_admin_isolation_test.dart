import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/providers/attendance_provider.dart';
import 'package:attendance_app/models/hr_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Default Company Admin Isolation Tests (Reports & Payroll Exclusion)', () {
    test('isDefaultCompanyAdminUser correctly identifies default admin accounts and not regular staff', () {
      final bestEnergyAdmin = CompanyEmployee(
        id: 'bestenergy_admin',
        name: 'Best Energy Admin',
        email: 'admin@bestenergy.com',
        position: 'Company Administrator',
        role: 'admin',
        companyCode: 'bestenergy',
      );
      expect(AttendanceProvider.isDefaultCompanyAdminUser(bestEnergyAdmin), isTrue);
      expect(AttendanceProvider.isSystemAdminAccount(bestEnergyAdmin), isTrue);

      final lazoAdmin = CompanyEmployee(
        id: 'lazo_admin',
        name: 'Lazo Admin',
        email: 'admin@lazo.com',
        position: 'Company Administrator',
        role: 'admin',
        companyCode: 'lazo',
      );
      expect(AttendanceProvider.isDefaultCompanyAdminUser(lazoAdmin), isTrue);
      expect(AttendanceProvider.isSystemAdminAccount(lazoAdmin), isTrue);

      // Regular staff employee who happens to have role: admin (e.g. HR manager or Accountant)
      final regularStaffAdmin = CompanyEmployee(
        id: '2',
        name: 'Soran HR',
        email: 'soran@bestenergy.com',
        position: 'HR Manager',
        role: 'admin',
        companyCode: 'bestenergy',
      );
      expect(AttendanceProvider.isDefaultCompanyAdminUser(regularStaffAdmin), isFalse);
      expect(AttendanceProvider.isSystemAdminAccount(regularStaffAdmin), isFalse);

      // Regular employee
      final regularWorker = CompanyEmployee(
        id: '1',
        name: 'Ahmed Staff',
        email: 'ahmed@bestenergy.com',
        position: 'Technician',
        role: 'employee',
        companyCode: 'bestenergy',
      );
      expect(AttendanceProvider.isDefaultCompanyAdminUser(regularWorker), isFalse);
      expect(AttendanceProvider.isSystemAdminAccount(regularWorker), isFalse);
    });

    test('Default Company Admin is NEVER included in provider.employees (reports & payroll list)', () async {
      final provider = AttendanceProvider(initialCompanyCode: 'bestenergy');
      await Future.delayed(const Duration(milliseconds: 50));

      final beAdmin = CompanyEmployee(
        id: 'bestenergy_admin',
        name: 'Best Energy Admin',
        email: 'admin@bestenergy.com',
        position: 'Company Administrator',
        role: 'admin',
        companyCode: 'bestenergy',
      );

      final worker1 = CompanyEmployee(
        id: '1',
        name: 'Staff Worker One',
        email: 'worker1@bestenergy.com',
        position: 'Engineer',
        role: 'employee',
        companyCode: 'bestenergy',
      );

      await provider.addEmployee(beAdmin);
      await provider.addEmployee(worker1);

      // provider.employees MUST only contain worker1, NOT beAdmin
      expect(provider.employees.length, equals(1));
      expect(provider.employees.first.id, equals('1'));
      expect(provider.employees.any((e) => e.id == 'bestenergy_admin'), isFalse);
      expect(provider.employees.any((e) => e.email == 'admin@bestenergy.com'), isFalse);

      // activeEmployeesCount must be 1 (admin does not consume license seats)
      expect(provider.activeEmployeesCount, equals(1));

      // But provider.companyUsers and provider.allEmployees still have beAdmin for auth and user management
      expect(provider.companyUsers.any((e) => e.id == 'bestenergy_admin'), isTrue);
      expect(provider.allEmployees.any((e) => e.id == 'bestenergy_admin'), isTrue);
    });

    test('closeMonth strictly excludes default company admin from payroll snapshots', () async {
      final provider = AttendanceProvider(initialCompanyCode: 'bestenergy');
      await Future.delayed(const Duration(milliseconds: 50));

      final beAdmin = CompanyEmployee(
        id: 'bestenergy_admin',
        name: 'Best Energy Admin',
        email: 'admin@bestenergy.com',
        position: 'Company Administrator',
        role: 'admin',
        basicSalary: 0,
        companyCode: 'bestenergy',
      );

      final worker1 = CompanyEmployee(
        id: '1',
        name: 'Staff Worker One',
        email: 'worker1@bestenergy.com',
        position: 'Engineer',
        role: 'employee',
        basicSalary: 2000,
        companyCode: 'bestenergy',
      );

      await provider.addEmployee(beAdmin);
      await provider.addEmployee(worker1);

      final success = await provider.closeMonth(
        month: DateTime(2026, 11, 1),
        closedBy: 'Best Energy Admin',
      );
      expect(success, isTrue);

      final closure = provider.getClosureForMonthStr('2026-11');
      expect(closure, isNotNull);
      expect(closure!.snapshots.containsKey('bestenergy_admin'), isFalse);
      expect(closure.snapshots.containsKey('1'), isTrue);
      expect(closure.totalEmployees, equals(1));
    });
  });
}

