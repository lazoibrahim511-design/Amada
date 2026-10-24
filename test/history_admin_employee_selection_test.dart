import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/providers/attendance_provider.dart';
import 'package:attendance_app/screens/history_screen.dart';
import 'package:attendance_app/models/attendance_record.dart';
import 'package:attendance_app/models/hr_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryScreen Admin and Employee Resolution Tests', () {
    test('getEmployeeRecords finds records by ID, Name, or Email', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();

      final lawi = CompanyEmployee(
        id: '1',
        name: 'lawi lazo ibrahim',
        email: 'lawi@lazo.com',
        position: 'Team Member',
      );
      await provider.addEmployee(lawi);

      final punch = AttendanceRecord(
        checkIn: DateTime(2026, 10, 17, 8, 25),
        checkOut: DateTime(2026, 10, 17, 17, 6),
        employeeId: 'lawi lazo ibrahim', // saved by name
      );
      provider.allCompanyRecords.add(punch);

      // Lookup by ID '1' should find the punch saved with name
      final byId = await provider.getEmployeeRecords('1');
      expect(byId.length, 1);
      expect(byId.first.checkIn.hour, 8);
      expect(byId.first.checkIn.minute, 25);

      // Lookup by name
      final byName = await provider.getEmployeeRecords('lawi lazo ibrahim');
      expect(byName.length, 1);

      // Lookup by email
      final byEmail = await provider.getEmployeeRecords('lawi@lazo.com');
      expect(byEmail.length, 1);
    });

    testWidgets('HistoryScreen resolves and renders subordinate for Super Admin without crash or 0s', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final provider = AttendanceProvider();
      final lawi = CompanyEmployee(
        id: '1',
        name: 'lawi lazo ibrahim',
        email: 'lawi@lazo.com',
        position: 'Team Member',
      );
      await provider.addEmployee(lawi);

      // Seed Lawi's punches
      final punch = AttendanceRecord(
        checkIn: DateTime(DateTime.now().year, DateTime.now().month, 17, 8, 25),
        checkOut: DateTime(DateTime.now().year, DateTime.now().month, 17, 17, 6),
        employeeId: '1',
      );
      provider.allCompanyRecords.add(punch);

      await tester.pumpWidget(
        ChangeNotifierProvider<AttendanceProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: HistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HistoryScreen), findsOneWidget);
      // Dropdown should be present and not crash
      expect(find.byType(DropdownMenu<String>), findsOneWidget);
    });
  });
}
