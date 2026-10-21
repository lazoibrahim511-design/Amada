import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';

void main() {
  group('Legacy Amada Backward Compatibility Tests', () {
    test('resolveCompanyCode correctly identifies legacy prefixes and defaults to amada', () {
      // Legacy document IDs with system prefixes or arbitrary names
      expect(resolveCompanyCode({}, 'struct_101'), 'amada');
      expect(resolveCompanyCode({}, 'structure_it'), 'amada');
      expect(resolveCompanyCode({}, 'shift_morning'), 'amada');
      expect(resolveCompanyCode({}, 'morning_shift'), 'amada');
      expect(resolveCompanyCode({}, 'grp_sales'), 'amada');
      expect(resolveCompanyCode({}, 'group_tech'), 'amada');
      expect(resolveCompanyCode({}, 'loc_headquarters'), 'amada');
      expect(resolveCompanyCode({}, 'location_factory'), 'amada');
      expect(resolveCompanyCode({}, 'emp_001'), 'amada');
      expect(resolveCompanyCode({}, 'employee_john'), 'amada');
      expect(resolveCompanyCode({}, 'user_55'), 'amada');
      expect(resolveCompanyCode({}, 'admin_super'), 'amada');
      expect(resolveCompanyCode({}, 'hol_eid_2026'), 'amada');
      expect(resolveCompanyCode({}, 'holiday_newyear'), 'amada');
      expect(resolveCompanyCode({}, 'closure_2026-09'), 'amada');
      expect(resolveCompanyCode({}, '2026_09'), 'amada');
      expect(resolveCompanyCode({}, 'raw_id_no_prefix'), 'amada');

      // Explicit companyCode in map takes precedence
      expect(resolveCompanyCode({'companyCode': 'lazo'}, 'shift_morning'), 'lazo');
      expect(resolveCompanyCode({'companyCode': 'amada'}, 'struct_1'), 'amada');
      expect(resolveCompanyCode({'companyCode': 'custom_co'}, 'emp_1'), 'custom_co');

      // Tenant prefixed IDs
      expect(resolveCompanyCode({}, 'lazo_shift_morning'), 'lazo');
      expect(resolveCompanyCode({}, 'amada_shift_morning'), 'amada');
    });

    test('OrgStructure fromMap resolves legacy documents to amada', () {
      final legacyDoc = OrgStructure.fromMap({
        'name': 'Information Technology',
        'location': 'HQ Floor 3',
        'capacity': 50,
      }, 'struct_it_department');

      expect(legacyDoc.companyCode, 'amada');
      expect(legacyDoc.id, 'struct_it_department');
      expect(legacyDoc.name, 'Information Technology');
    });

    test('WorkShift fromMap resolves legacy documents to amada', () {
      final legacyShift = WorkShift.fromMap({
        'name': 'Morning Regular Shift',
        'startTime': '08:00',
        'endTime': '16:00',
      }, 'shift_morning_01');

      expect(legacyShift.companyCode, 'amada');
      expect(legacyShift.name, 'Morning Regular Shift');
    });

    test('EmployeeGroup fromMap resolves legacy documents to amada', () {
      final legacyGroup = EmployeeGroup.fromMap({
        'name': 'Engineers Group',
        'shiftId': 'shift_morning_01',
      }, 'grp_engineers');

      expect(legacyGroup.companyCode, 'amada');
      expect(legacyGroup.name, 'Engineers Group');
    });

    test('CompanyEmployee fromMap maps personal email domains and legacy IDs to amada', () {
      // Employee with personal Gmail
      final empGmail = CompanyEmployee.fromMap({
        'name': 'Ahmad Karim',
        'email': 'ahmad.karim@gmail.com',
        'role': 'employee',
      }, 'emp_101');
      expect(empGmail.companyCode, 'amada');

      // Employee with Yahoo mail
      final empYahoo = CompanyEmployee.fromMap({
        'name': 'Sara Noor',
        'email': 'sara.noor@yahoo.com',
        'role': 'employee',
      }, 'emp_102');
      expect(empYahoo.companyCode, 'amada');

      // Employee with company email
      final empCompany = CompanyEmployee.fromMap({
        'name': 'Jane HR',
        'email': 'jane.hr@company.com',
        'role': 'admin',
      }, 'emp_103');
      expect(empCompany.companyCode, 'amada');

      // Employee belonging to lazo
      final empLazo = CompanyEmployee.fromMap({
        'name': 'Lazo Worker',
        'email': 'worker@lazo.com',
        'role': 'employee',
      }, 'lazo_emp_01');
      expect(empLazo.companyCode, 'lazo');
    });

    test('WorkLocation fromMap resolves legacy documents to amada', () {
      final legacyLocation = WorkLocation.fromMap({
        'name': 'Main Branch Baghdad',
        'latitude': 33.3152,
        'longitude': 44.3661,
        'radius': 100.0,
      }, 'loc_baghdad_main');

      expect(legacyLocation.companyCode, 'amada');
      expect(legacyLocation.name, 'Main Branch Baghdad');
    });

    test('Holiday fromMap resolves legacy documents to amada and preserves companyCode', () {
      final legacyHoliday = Holiday.fromMap({
        'name': 'Eid Al-Fitr',
        'fromDate': '2026-03-20',
        'toDate': '2026-03-24',
      }, 'hol_eid_2026');

      expect(legacyHoliday.companyCode, 'amada');
      expect(legacyHoliday.name, 'Eid Al-Fitr');

      final toMapData = legacyHoliday.toMap();
      expect(toMapData['companyCode'], 'amada');
    });

    test('PayrollMonthClosure fromMap resolves legacy closure IDs to amada with correct yearMonth', () {
      // Legacy document with closure_ prefix
      final legacyClosure1 = PayrollMonthClosure.fromMap({
        'isClosed': true,
        'totalPayout': 50000.0,
        'totalEmployees': 25,
        'currency': 'USD',
      }, 'closure_2026-09');

      expect(legacyClosure1.companyCode, 'amada');
      expect(legacyClosure1.yearMonth, '2026-09');

      // Legacy document with direct yearMonth ID
      final legacyClosure2 = PayrollMonthClosure.fromMap({
        'isClosed': true,
        'totalPayout': 48000.0,
        'totalEmployees': 24,
        'currency': 'USD',
      }, '2026-08');

      expect(legacyClosure2.companyCode, 'amada');
      expect(legacyClosure2.yearMonth, '2026-08');

      // New multi-tenant closure ID
      final tenantClosure = PayrollMonthClosure.fromMap({
        'isClosed': true,
        'totalPayout': 12000.0,
        'totalEmployees': 6,
        'currency': 'USD',
      }, 'lazo_2026-09');

      expect(tenantClosure.companyCode, 'lazo');
      expect(tenantClosure.yearMonth, '2026-09');
    });
  });
}
