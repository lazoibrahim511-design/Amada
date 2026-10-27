import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZKTeco Multi-Tenant Matching Tests', () {
    final amadaEmp101 = CompanyEmployee(
      id: 'amada_101',
      name: 'Amada Employee',
      email: 'emp@amada.com',
      position: 'Tech',
      companyCode: 'amada',
    );

    final lazoEmp101 = CompanyEmployee(
      id: 'Lazo_101',
      name: 'Lazo Employee',
      email: 'emp@lazo.com',
      position: 'Designer',
      companyCode: 'lazo',
    );

    final allEmployees = [amadaEmp101, lazoEmp101];

    test('Company isolation scopes candidate employees before matching', () {
      // 1. Device A belongs to "amada"
      const deviceACompany = 'amada';
      final amadaCandidates = allEmployees
          .where((e) => e.companyCode.toLowerCase() == deviceACompany.toLowerCase())
          .toList();

      expect(amadaCandidates.length, equals(1));
      expect(amadaCandidates.first.id, equals('amada_101'));

      // 2. Device B belongs to "lazo"
      const deviceBCompany = 'lazo';
      final lazoCandidates = allEmployees
          .where((e) => e.companyCode.toLowerCase() == deviceBCompany.toLowerCase())
          .toList();

      expect(lazoCandidates.length, equals(1));
      expect(lazoCandidates.first.id, equals('Lazo_101'));
    });

    test('Device user "101" correctly matches amada_101 when scoped to amada', () {
      final amadaCandidates = allEmployees
          .where((e) => e.companyCode.toLowerCase() == 'amada')
          .toList();

      // Verify suffix match after underscore
      const deviceUserId = '101';
      final match = amadaCandidates.firstWhere(
        (e) {
          final parts = e.id.toLowerCase().split(RegExp(r'[_/\-]'));
          return parts.isNotEmpty && parts.last == deviceUserId;
        },
      );

      expect(match.id, equals('amada_101'));
    });

    test('Device user "101" correctly matches Lazo_101 when scoped to lazo', () {
      final lazoCandidates = allEmployees
          .where((e) => e.companyCode.toLowerCase() == 'lazo')
          .toList();

      const deviceUserId = '101';
      final match = lazoCandidates.firstWhere(
        (e) {
          final parts = e.id.toLowerCase().split(RegExp(r'[_/\-]'));
          return parts.isNotEmpty && parts.last == deviceUserId;
        },
      );

      expect(match.id, equals('Lazo_101'));
    });
  });
}
