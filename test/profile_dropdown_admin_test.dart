import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/providers/attendance_provider.dart';
import 'package:attendance_app/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CompanyEmployee Equality & fromMap Tests', () {
    test('CompanyEmployee operator == and hashCode are based on id', () {
      final empA = CompanyEmployee(
        id: 'lazo_admin',
        name: 'Lazo Admin',
        email: 'admin@lazo.com',
        position: 'Admin',
      );
      final empB = CompanyEmployee(
        id: 'lazo_admin',
        name: 'Different Name',
        email: 'different@lazo.com',
        position: 'Different',
      );
      final empC = CompanyEmployee(
        id: 'jane',
        name: 'Jane Doe',
        email: 'jane@lazo.com',
        position: 'Staff',
      );

      expect(empA, equals(empB));
      expect(empA.hashCode, equals(empB.hashCode));
      expect(empA, isNot(equals(empC)));
    });

    test('CompanyEmployee.fromMap properly resolves companyCode and docId for lazo_admin', () {
      final mapWithLeadingUnderscore = {
        'name': 'Lazo Admin',
        'email': 'admin@lazo.com',
        'position': 'Company Administrator',
        'role': 'admin',
      };
      final emp = CompanyEmployee.fromMap(mapWithLeadingUnderscore, '_lazo_admin');

      expect(emp.id, 'lazo_admin');
      expect(emp.companyCode, 'lazo');
      expect(emp.role, 'admin');
    });
  });

  group('ProfileScreen DropdownButton lazo_admin Safety Tests', () {
    testWidgets('ProfileScreen renders without crash when logged in as lazo_admin not in provider.employees', (tester) async {
      final provider = AttendanceProvider();
      await provider.loadCompanyLicense('lazo');

      // Add a non-admin employee
      await provider.addEmployee(CompanyEmployee(
        id: 'jane',
        name: 'Jane Staff',
        email: 'jane@lazo.com',
        position: 'Staff',
        companyCode: 'lazo',
      ));

      // Simulate logged in as lazo_admin (who is not in provider.employees)
      await provider.switchProfile('lazo_admin');

      await tester.pumpWidget(
        ChangeNotifierProvider<AttendanceProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify ProfileScreen rendered without assertion error
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });

    testWidgets('ProfileScreen renders safely even if duplicate employee IDs exist in list', (tester) async {
      final provider = AttendanceProvider();
      await provider.loadCompanyLicense('lazo');

      // Simulate state with duplicate IDs in provider
      await provider.switchProfile('lazo_admin');

      await tester.pumpWidget(
        ChangeNotifierProvider<AttendanceProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ProfileScreen), findsOneWidget);
      final dropdown = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      expect(dropdown.value, 'lazo_admin');

      // Verify that dropdown items have no duplicates
      final values = dropdown.items!.map((i) => i.value).toList();
      final distinctValues = values.toSet().toList();
      expect(values.length, equals(distinctValues.length));

      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  });
}
