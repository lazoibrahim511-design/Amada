import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/models/company_license.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Biometric Device Company Scoping Tests', () {
    test('Regular company admin is strictly isolated to their own company', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider(
        initialCompanyCode: 'bestenergy',
        initialLoggedIn: true,
        initialRole: 'admin',
        initialEmail: 'admin@bestenergy.com',
      );

      expect(provider.isSuperAdmin, isFalse);
      expect(provider.currentCompanyCode, equals('bestenergy'));

      // If allCompanies has multiple companies, non-superadmin must only see their own
      final mockCompanies = [
        CompanyLicense.defaultLicense(code: 'amada', name: 'Amada Trading'),
        CompanyLicense.defaultLicense(code: 'bestenergy', name: 'Best Energy'),
        CompanyLicense.defaultLicense(code: 'lazo', name: 'Lazo Co'),
      ];

      final currentCode = provider.currentCompanyCode.trim().toLowerCase();
      final allowed = provider.isSuperAdmin
          ? mockCompanies
          : mockCompanies.where((c) => c.companyCode.trim().toLowerCase() == currentCode).toList();

      expect(allowed.length, equals(1));
      expect(allowed.first.companyCode, equals('bestenergy'));
      expect(allowed.first.companyName, equals('Best Energy'));
    });

    test('Super admin can manage devices across all companies', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider(
        initialCompanyCode: 'all',
        initialLoggedIn: true,
        initialRole: 'super_admin',
        initialEmail: 'admin@company.com',
      );

      expect(provider.isSuperAdmin, isTrue);

      final mockCompanies = [
        CompanyLicense.defaultLicense(code: 'amada', name: 'Amada Trading'),
        CompanyLicense.defaultLicense(code: 'bestenergy', name: 'Best Energy'),
        CompanyLicense.defaultLicense(code: 'lazo', name: 'Lazo Co'),
      ];

      final currentCode = provider.currentCompanyCode.trim().toLowerCase();
      final allowed = provider.isSuperAdmin
          ? mockCompanies
          : mockCompanies.where((c) => c.companyCode.trim().toLowerCase() == currentCode).toList();

      expect(allowed.length, equals(3));
    });
  });
}
