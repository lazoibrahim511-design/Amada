import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/providers/attendance_provider.dart';
import 'package:attendance_app/screens/main_navigation_screen.dart';
import 'package:attendance_app/screens/home_screen.dart';
import 'package:attendance_app/screens/clock_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Mobile app enables smooth sliding PageView between Home and Clock screens', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // Ignore test-font rendering overflow warnings in smoke test
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final provider = AttendanceProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AttendanceProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: MainNavigationScreen(initialTab: 0),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Verify PageView is present on mobile
    final pageViewFinder = find.byType(PageView);
    expect(pageViewFinder, findsOneWidget);

    // 2. Verify HomeScreen is rendered initially
    expect(find.byType(HomeScreen), findsOneWidget);

    // 3. Perform a drag / swipe to slide to the Clock screen (page 1)
    await tester.drag(pageViewFinder, const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 4. Verify ClockScreen is now rendered
    expect(find.byType(ClockScreen), findsOneWidget);

    // 5. Swipe back to Home screen
    await tester.drag(pageViewFinder, const Offset(500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 6. Verify back on HomeScreen
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
