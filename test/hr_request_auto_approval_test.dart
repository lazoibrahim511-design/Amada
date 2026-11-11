import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/providers/attendance_provider.dart';
import 'package:attendance_app/models/hr_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HR Request Direct Auto-Approval Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('When HR Manager submits request for an employee, it is directly Approved', () async {
      final provider = AttendanceProvider(initialCompanyCode: 'bestenergy');
      await Future.delayed(const Duration(milliseconds: 50));

      final empWorker = CompanyEmployee(
        id: 'be_worker_1',
        name: 'Worker 1',
        email: 'w1@bestenergy.com',
        position: 'Field Engineer',
        role: 'employee',
        companyCode: 'bestenergy',
        annualLeaveBalance: 20.0,
      );
      final empHR = CompanyEmployee(
        id: 'be_hr_1',
        name: 'HR Manager',
        email: 'hr@bestenergy.com',
        position: 'HR Manager',
        role: 'hr',
        companyCode: 'bestenergy',
      );

      await provider.addEmployee(empWorker);
      await provider.addEmployee(empHR);

      // Login as HR Manager
      await provider.loginAsEmployee(empHR);
      expect(provider.isHRManager, isTrue);

      // HR fills out request for worker_1
      await provider.submitRequest(
        'Annual Leave',
        'November 25, 2026',
        '1 Day',
        employeeId: 'be_worker_1',
        note: 'Approved vacation granted by HR',
      );

      // Find the request
      final requests = provider.allCompanyRequests
          .where((r) => r.employeeId == 'be_worker_1')
          .toList();
      expect(requests, isNotEmpty);
      final req = requests.first;

      // Must be directly Approved without supervisor or second HR step
      expect(req.status, equals('Approved'));
      expect(req.actionBy, equals('be_hr_1'));
      expect(req.hrActionBy, equals('be_hr_1'));
      expect(req.hrStatus, equals('Approved'));
      expect(req.supervisorStatus, equals('Approved'));
      expect(req.companyCode, equals('bestenergy'));

      // Worker received direct approval notification message
      final msgs = provider.getMessagesWith('be_worker_1');
      expect(msgs, isNotEmpty);
      expect(msgs.last.text, contains('submitted and directly approved by HR Management'));
    });

    test('When Company Admin fills out request for an employee, it is directly Approved', () async {
      final provider = AttendanceProvider(initialCompanyCode: 'lazo');
      await Future.delayed(const Duration(milliseconds: 50));

      final empWorker = CompanyEmployee(
        id: 'lazo_emp_1',
        name: 'Lazo Worker',
        email: 'worker@lazo.com',
        position: 'Technician',
        role: 'employee',
        companyCode: 'lazo',
      );
      final defaultAdmin = CompanyEmployee(
        id: 'lazo_admin',
        name: 'Lazo Admin',
        email: 'admin@lazo.com',
        position: 'Company Administrator',
        role: 'admin',
        companyCode: 'lazo',
      );

      await provider.addEmployee(empWorker);
      await provider.addEmployee(defaultAdmin);

      // Login as Admin
      await provider.loginAsEmployee(defaultAdmin);

      // Admin fills out request for worker
      await provider.submitRequest(
        'Sick Leave',
        'November 26, 2026',
        '2 Days',
        employeeId: 'lazo_emp_1',
        note: 'Medical certificate verified by management',
      );

      final reqs = provider.allCompanyRequests
          .where((r) => r.employeeId == 'lazo_emp_1')
          .toList();
      expect(reqs, isNotEmpty);
      final req = reqs.first;

      expect(req.status, equals('Approved'));
      expect(req.actionBy, equals('lazo_admin'));
      expect(req.hrActionBy, equals('lazo_admin'));
      expect(req.hrStatus, equals('Approved'));
    });

    test('When regular employee submits request for themselves, it stays Pending', () async {
      final provider = AttendanceProvider(initialCompanyCode: 'lazo');
      await Future.delayed(const Duration(milliseconds: 50));

      final empSupervisor = CompanyEmployee(
        id: 'lazo_sup_1',
        name: 'Supervisor',
        email: 'sup@lazo.com',
        position: 'Supervisor',
        role: 'supervisor',
        companyCode: 'lazo',
      );
      final empWorker = CompanyEmployee(
        id: 'lazo_emp_2',
        name: 'Regular Worker',
        email: 'worker2@lazo.com',
        position: 'Staff',
        role: 'employee',
        companyCode: 'lazo',
        structureId: 'struct_1',
      );
      final empHR = CompanyEmployee(
        id: 'lazo_hr',
        name: 'HR',
        email: 'hr@lazo.com',
        position: 'HR',
        role: 'hr',
        companyCode: 'lazo',
      );

      await provider.addEmployee(empSupervisor);
      await provider.addEmployee(empWorker);
      await provider.addEmployee(empHR);

      // Add structure with supervisor
      await provider.addStructure(OrgStructure(
        id: 'struct_1',
        name: 'Engineering',
        location: 'HQ',
        capacity: 10,
        supervisorId: 'lazo_sup_1',
      ));

      // Login as worker
      await provider.loginAsEmployee(empWorker);

      // Worker submits request for themselves
      await provider.submitRequest(
        'Annual Leave',
        'December 10, 2026',
        '1 Day',
        employeeId: 'lazo_emp_2',
      );

      final reqs = provider.allCompanyRequests
          .where((r) => r.employeeId == 'lazo_emp_2')
          .toList();
      expect(reqs, isNotEmpty);
      final req = reqs.first;

      // Regular employee request must be Pending Supervisor
      expect(req.status, equals('Pending Supervisor'));
      expect(req.actionBy, isNull);
    });

    test('When HR Manager (Bilal) submits request for THEMSELVES, it is directly Approved', () async {
      final provider = AttendanceProvider(initialCompanyCode: 'bestenergy');
      await Future.delayed(const Duration(milliseconds: 50));

      final bilalHR = CompanyEmployee(
        id: 'be_bilal',
        name: 'Bilal',
        email: 'bilal@bestenergy.com',
        position: 'System Administrator',
        role: 'hr',
        companyCode: 'bestenergy',
      );

      await provider.addEmployee(bilalHR);

      // Login as Bilal
      await provider.loginAsEmployee(bilalHR);
      expect(provider.isHRManager, isTrue);

      // Bilal submits Annual Leave request for himself
      await provider.submitRequest(
        'Annual Leave',
        'November 7, 2026',
        '1 Day',
        employeeId: 'be_bilal',
        note: 'Personal vacation',
      );

      final reqs = provider.allCompanyRequests
          .where((r) => r.employeeId == 'be_bilal')
          .toList();
      expect(reqs, isNotEmpty);
      final req = reqs.first;

      // Must be directly Approved without waiting for anyone
      expect(req.status, equals('Approved'));
      expect(req.actionBy, equals('be_bilal'));
      expect(req.hrActionBy, equals('be_bilal'));
      expect(req.hrStatus, equals('Approved'));
      expect(req.supervisorStatus, equals('Approved'));
    });

    test('When employee with Kurdish position "بەڕێوەبەری کارگێڕی" submits request, it is recognized as HR and auto-approved', () async {
      final provider = AttendanceProvider(initialCompanyCode: 'bestenergy');
      await Future.delayed(const Duration(milliseconds: 50));

      final bilalKurdishHR = CompanyEmployee(
        id: 'be_bilal_ku',
        name: 'بیلال',
        email: 'bilal@bestenergy.com',
        position: 'بەڕێوەبەری کارگێڕی',
        role: 'employee', // even if role is employee in database, position gives full HR status
        companyCode: 'bestenergy',
      );

      await provider.addEmployee(bilalKurdishHR);

      // Login as Bilal
      await provider.loginAsEmployee(bilalKurdishHR);
      expect(AttendanceProvider.isEmployeeHROrAdmin(bilalKurdishHR), isTrue);
      expect(provider.isHRManager, isTrue);

      // Bilal submits Annual Leave request for himself
      await provider.submitRequest(
        'Annual Leave',
        'November 15 - November 18, 2026',
        '4 Days',
        employeeId: 'be_bilal_ku',
        note: 'Annual leave',
      );

      final reqs = provider.allCompanyRequests
          .where((r) => r.employeeId == 'be_bilal_ku')
          .toList();
      expect(reqs, isNotEmpty);
      final req = reqs.first;

      // Must be auto approved!
      expect(req.status, equals('Approved'));
      expect(req.hrStatus, equals('Approved'));
      expect(req.supervisorStatus, equals('Approved'));
    });
  });
}
