import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Company Code Persistence Tests', () {
    test('AttendanceProvider respects initialCompanyCode and preserves on logout', () async {
      SharedPreferences.setMockInitialValues({
        'app_company_code': 'lazo',
      });

      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('app_company_code') ?? 'amada';
      expect(savedCode, equals('lazo'));

      final provider = AttendanceProvider(
        initialCompanyCode: savedCode,
      );

      // Verify initial code is lazo, not amada
      expect(provider.currentCompanyCode, equals('lazo'));

      // Simulate logging out
      await provider.logout();

      // Verify company code remains lazo in provider and SharedPreferences
      expect(provider.currentCompanyCode, equals('lazo'));
      expect(prefs.getString('app_company_code'), equals('lazo'));
    });

    test('Switching company code updates SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final provider = AttendanceProvider(
        initialCompanyCode: 'amada',
      );
      expect(provider.currentCompanyCode, equals('amada'));

      await provider.setCompanyCode('lazo_corp');
      expect(provider.currentCompanyCode, equals('lazo_corp'));
      expect(prefs.getString('app_company_code'), equals('lazo_corp'));

      // If switched to 'all' master view, it does not wipe the specific company
      await provider.setCompanyCode('all');
      expect(provider.currentCompanyCode, equals('all'));
      expect(prefs.getString('app_company_code'), equals('lazo_corp'));
    });
  });
}

