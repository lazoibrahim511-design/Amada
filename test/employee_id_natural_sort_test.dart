import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';

void main() {
  group('Employee Natural ID Sorting Tests', () {
    test('Pure numeric IDs sort naturally (1, 2, 3 ... 10, 11)', () {
      final ids = ['1', '10', '11', '12', '13', '14', '2', '3', '20', '21'];
      ids.sort(CompanyEmployee.compareIds);
      expect(ids, ['1', '2', '3', '10', '11', '12', '13', '14', '20', '21']);
    });

    test('CompanyEmployee list sorts by natural numeric ID', () {
      final employees = [
        CompanyEmployee(id: '1', name: 'عیماد', email: 'emad@gmail.com', position: 'Staff'),
        CompanyEmployee(id: '10', name: 'پێشەنگ', email: 'peshang@gmail.com', position: 'Staff'),
        CompanyEmployee(id: '11', name: 'ئاکۆ', email: 'ako@gmail.com', position: 'Staff'),
        CompanyEmployee(id: '2', name: 'کارمەند ٢', email: 'user2@gmail.com', position: 'Staff'),
        CompanyEmployee(id: '3', name: 'کارمەند ٣', email: 'user3@gmail.com', position: 'Staff'),
      ];

      employees.sort(CompanyEmployee.compareById);

      expect(employees.map((e) => e.id).toList(), ['1', '2', '3', '10', '11']);
    });

    test('Arabic / Kurdish Eastern digits sort naturally (١, ٢, ٣ ... ١٠)', () {
      final ids = ['١', '١٠', '١١', '٢', '٣'];
      ids.sort(CompanyEmployee.compareIds);
      expect(ids, ['١', '٢', '٣', '١٠', '١١']);
    });

    test('Prefixed numeric IDs sort naturally (emp_1, emp_2, emp_10)', () {
      final ids = ['emp_10', 'emp_1', 'emp_2', 'emp_20', 'emp_11'];
      ids.sort(CompanyEmployee.compareIds);
      expect(ids, ['emp_1', 'emp_2', 'emp_10', 'emp_11', 'emp_20']);
    });

    test('Pure numeric IDs appear before non-numeric IDs', () {
      final ids = ['admin', '10', '1', 'super_admin', '2'];
      ids.sort(CompanyEmployee.compareIds);
      expect(ids, ['1', '2', '10', 'admin', 'super_admin']);
    });
  });
}

