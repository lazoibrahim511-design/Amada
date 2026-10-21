import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Employee Company Scoping & Duplicate ID Tests', () {
    test('Employee added while scoped to lazo gets companyCode lazo and avoids collision with other companies', () async {
      final provider = AttendanceProvider();
      
      // Load 'lazo' company
      provider.loadCompanyLicense('lazo');
      expect(provider.currentCompanyCode, 'lazo');

      // 1. Add employee with ID '1' to lazo
      final emp1Lazo = CompanyEmployee(
        id: '1',
        name: 'zilan taha ali',
        email: 'zilan@lazo.com',
        position: 'Staff',
        role: 'employee',
      );
      final added1 = await provider.addEmployee(emp1Lazo);
      expect(added1, isTrue);

      // Verify it has companyCode 'lazo'
      final foundInLazo = provider.employees.where((e) => e.id == '1').firstOrNull;
      expect(foundInLazo, isNotNull);
      expect(foundInLazo!.name, 'zilan taha ali');
      expect(foundInLazo.companyCode, 'lazo');

      // 2. Try to add duplicate employee with ID '1' into lazo again -> MUST FAIL
      final empDuplicate = CompanyEmployee(
        id: '1',
        name: 'Another Person',
        email: 'another@lazo.com',
        position: 'Staff',
        role: 'employee',
      );
      final addedDuplicate = await provider.addEmployee(empDuplicate);
      expect(addedDuplicate, isFalse); // rejected!

      // 3. Switch to 'amada' company
      provider.loadCompanyLicense('amada');
      expect(provider.currentCompanyCode, 'amada');

      // In amada, zilan taha ali is NOT visible
      expect(provider.employees.any((e) => e.id == '1'), isFalse);

      // In amada, adding ID '1' for an amada employee IS permitted (IDs are scoped per company)
      final emp1Amada = CompanyEmployee(
        id: '1',
        name: 'Amada Worker',
        email: 'worker@amada.com',
        position: 'Staff',
        role: 'employee',
      );
      final addedAmada = await provider.addEmployee(emp1Amada);
      expect(addedAmada, isTrue);

      // 4. Try duplicate ID '1' in amada again -> MUST FAIL
      final empDuplicateAmada = CompanyEmployee(
        id: '1',
        name: 'Another Amada Worker',
        email: 'another@amada.com',
        position: 'Staff',
        role: 'employee',
      );
      final addedDuplicateAmada = await provider.addEmployee(empDuplicateAmada);
      expect(addedDuplicateAmada, isFalse);

      // 5. In 'all' (Master View), both exist independently
      provider.loadCompanyLicense('all');
      expect(provider.employees.where((e) => e.id == '1').length, 2);
    });

    test('getNextEmployeeId increments properly per company', () async {
      final provider = AttendanceProvider();
      
      provider.loadCompanyLicense('lazo');
      final nextLazo = provider.getNextEmployeeId();
      expect(nextLazo, '1');

      await provider.addEmployee(CompanyEmployee(id: '1', name: 'Zilan', email: 'z@l.com', position: 'Staff'));
      final nextLazoAfter = provider.getNextEmployeeId();
      expect(nextLazoAfter, '2');

      // Amada next ID shouldn't be affected by Lazo
      provider.loadCompanyLicense('amada');
      final nextAmada = provider.getNextEmployeeId();
      expect(nextAmada, '1');
    });

    test('Employee in company with no locations cannot clock in (verifyLocation returns outside zone)', () async {
      final provider = AttendanceProvider();
      provider.loadCompanyLicense('lazo');

      final empLawi = CompanyEmployee(
        id: '99',
        name: 'lawi lazo ibrahim',
        email: 'lawi@lazo.com',
        position: 'CEO',
        role: 'employee',
        companyCode: 'lazo',
      );
      await provider.addEmployee(empLawi);
      await provider.loginAsEmployee(empLawi);

      // Verify that no allowed zones exist for this employee/company
      final zones = provider.getAllowedZones(empLawi);
      expect(zones, isEmpty);

      // verifyLocation must fail with location_outside_range error and NOT return null
      final locError = await provider.verifyLocation();
      expect(locError, isNotNull);
      expect(locError, provider.translate('location_outside_range'));
    });

    test('Automatic message sent upon request approval is bilingual in English and Kurdish', () async {
      final provider = AttendanceProvider();
      provider.loadCompanyLicense('lazo');

      // Add regular employee
      final empWorker = CompanyEmployee(
        id: 'worker_1',
        name: 'Worker Lawi',
        email: 'worker@lazo.com',
        position: 'Engineer',
        role: 'employee',
        companyCode: 'lazo',
      );
      await provider.addEmployee(empWorker);

      // Add HR employee
      final empHR = CompanyEmployee(
        id: 'hr_1',
        name: 'HR Manager',
        email: 'hr@lazo.com',
        position: 'HR',
        role: 'hr',
        companyCode: 'lazo',
      );
      await provider.addEmployee(empHR);

      // Create a request for worker_1
      provider.submitRequest(
        'Annual Leave',
        'October 20, 2026',
        '1 day',
        employeeId: 'worker_1',
      );
      final workerReqs = provider.allCompanyRequests.where((r) => r.employeeId == 'worker_1').toList();
      expect(workerReqs, isNotEmpty);
      final reqId = workerReqs.first.id;

      // Login as HR
      await provider.loginAsEmployee(empHR);

      // Approve the request
      await provider.updateRequestStatus('worker_1', reqId, 'Approved');

      // Check messages sent to worker_1
      final messages = provider.getMessagesWith('worker_1');
      expect(messages, isNotEmpty);
      final lastMsg = messages.last.text;

      // English verification
      expect(lastMsg, contains('Your request for Annual Leave on October 20, 2026 has been approved by HR Management.'));
      // Kurdish verification
      expect(lastMsg, contains('داواکارییەکەت بۆ مۆڵەتی ساڵانە لە ڕێکەوتی October 20, 2026 لەلایەن بەڕێوەبەرایەتی سەرچاوە مرۆییەکان (HR) پەسەندکرا.'));
    });

    test('deleteEmployee properly removes scoped company employee and cleans up records and requests', () async {
      final provider = AttendanceProvider();
      provider.loadCompanyLicense('lazo');

      final empJane = CompanyEmployee(
        id: '3',
        name: 'Jane Smith',
        email: 'jane.smith@company.com',
        position: 'HR Manager',
        role: 'hr',
        companyCode: 'lazo',
      );
      await provider.addEmployee(empJane);
      expect(provider.employees.any((e) => e.id == '3' && e.companyCode == 'lazo'), isTrue);

      // Submit request for Jane
      provider.submitRequest(
        'Annual Leave',
        'October 20, 2026',
        '1 day',
        employeeId: '3',
      );
      expect(provider.allCompanyRequests.where((r) => r.employeeId == '3').toList(), isNotEmpty);

      // Now delete employee Jane (ID: 3, Company: lazo)
      await provider.deleteEmployee('3', companyCode: 'lazo');

      // Verify removed from provider.employees
      expect(provider.employees.any((e) => e.id == '3' && e.companyCode == 'lazo'), isFalse);
      // Verify requests cleaned up
      expect(provider.allCompanyRequests.where((r) => r.employeeId == '3').toList(), isEmpty);
    });
  });
}
