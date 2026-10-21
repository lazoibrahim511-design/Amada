import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/providers/attendance_provider.dart';
import 'package:attendance_app/models/hr_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Super Admin Isolation & Multi-Company Tests', () {
    test('isSuperAdminUser correctly identifies master super admin accounts', () {
      final superAccount = CompanyEmployee(
        id: 'admin_super_account',
        name: 'Super Admin',
        email: 'admin@company.com',
        position: 'Super Administrator',
        role: 'super_admin',
      );
      expect(AttendanceProvider.isSuperAdminUser(superAccount), isTrue);

      final tenantAdmin = CompanyEmployee(
        id: 'emp_admin',
        name: 'Amada Admin',
        email: 'admin@amada.com',
        position: 'HR Manager',
        role: 'admin',
        companyCode: 'amada',
      );
      expect(AttendanceProvider.isSuperAdminUser(tenantAdmin), isFalse);

      final regularEmp = CompanyEmployee(
        id: 'emp_1',
        name: 'John Doe',
        email: 'john@amada.com',
        position: 'Developer',
        role: 'employee',
        companyCode: 'amada',
      );
      expect(AttendanceProvider.isSuperAdminUser(regularEmp), isFalse);
    });

    test('Super Admin is NEVER included in provider.employees list', () {
      final provider = AttendanceProvider();
      
      final superAdmin = CompanyEmployee(
        id: 'admin_super_account',
        name: 'Super Admin',
        email: 'admin@company.com',
        position: 'Super Administrator',
        role: 'super_admin',
        companyCode: '',
      );
      final empA = CompanyEmployee(
        id: 'emp_a',
        name: 'Alice',
        email: 'alice@amada.com',
        position: 'Engineer',
        role: 'employee',
        companyCode: 'amada',
      );
      final empB = CompanyEmployee(
        id: 'emp_b',
        name: 'Bob',
        email: 'bob@client2.com',
        position: 'Designer',
        role: 'employee',
        companyCode: 'client2',
      );

      provider.addEmployee(superAdmin);
      provider.addEmployee(empA);
      provider.addEmployee(empB);

      // Verify internal storage has them
      expect(provider.employees.any((e) => e.id == 'admin_super_account'), isFalse);
      expect(provider.employees.any((e) => e.email == 'admin@company.com'), isFalse);
      
      // When company is 'amada'
      expect(provider.employees.any((e) => e.id == 'emp_a'), isTrue);
      expect(provider.employees.any((e) => e.id == 'emp_b'), isFalse);
      expect(provider.employees.length, 1);
      expect(provider.activeEmployeesCount, 1);

      // When company is switched to 'all' (Master View)
      provider.loadCompanyLicense('all');
      expect(provider.employees.any((e) => e.id == 'emp_a'), isTrue);
      expect(provider.employees.any((e) => e.id == 'emp_b'), isTrue);
      expect(provider.employees.any((e) => e.id == 'admin_super_account'), isFalse);
      expect(provider.employees.length, 2);
      expect(provider.activeEmployeesCount, 2);
    });

    test('Payroll closeMonth never snapshots Super Admin', () async {
      final provider = AttendanceProvider();
      
      final superAdmin = CompanyEmployee(
        id: 'admin_super_account',
        name: 'Super Admin',
        email: 'admin@company.com',
        position: 'Super Administrator',
        role: 'super_admin',
        basicSalary: 10000,
        companyCode: '',
      );
      final emp = CompanyEmployee(
        id: 'emp_test',
        name: 'Regular Worker',
        email: 'worker@amada.com',
        position: 'Technician',
        role: 'employee',
        basicSalary: 1500,
        companyCode: 'amada',
      );

      await provider.addEmployee(superAdmin);
      await provider.addEmployee(emp);

      final success = await provider.closeMonth(
        month: DateTime(2026, 4, 1),
        closedBy: 'Admin',
      );
      expect(success, isTrue);

      final closure = provider.getClosureForMonthStr('2026-04');
      expect(closure, isNotNull);
      expect(closure!.snapshots.containsKey('admin_super_account'), isFalse);
      expect(closure.snapshots.containsKey('emp_test'), isTrue);
      expect(closure.totalEmployees, 1);
    });
  });
}
