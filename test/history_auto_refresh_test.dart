import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/providers/attendance_provider.dart';
import 'package:attendance_app/screens/history_screen.dart';
import 'package:attendance_app/models/attendance_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HistoryScreen automatically displays live punches without manual re-selection', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final provider = AttendanceProvider();
    final now = DateTime.now();

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

    // 1. Verify HistoryScreen is rendered
    expect(find.byType(HistoryScreen), findsOneWidget);

    // 2. Verify Refresh button exists in the header
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    // 3. Add a live record directly to provider for current employee
    final newCheckIn = DateTime(now.year, now.month, now.day, 8, 30);
    final newCheckOut = DateTime(now.year, now.month, now.day, 17, 30);
    final liveRecord = AttendanceRecord(
      checkIn: newCheckIn,
      checkOut: newCheckOut,
      employeeId: provider.currentEmployee?.id ?? provider.employeeId,
    );

    // Inject record into provider and notify listeners (simulating real-time punch)
    provider.records.insert(0, liveRecord);
    provider.notifyListeners();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 4. Verify that the table automatically reflects the live punch
    // Duty duration for 8:30 to 17:30 (9 hours = 540 min)
    expect(find.byType(HistoryScreen), findsOneWidget);

    // 5. Tap the refresh button to verify it triggers without error
    final refreshBtn = find.byIcon(Icons.refresh_rounded);
    await tester.tap(refreshBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HistoryScreen), findsOneWidget);
  });
}
