import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/zkteco_service.dart';

void main() {
  testWidgets('Attendance App dashboard renders smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // Build our app and trigger frames
    await tester.pumpWidget(const MyApp(initialLoggedIn: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify that the greeting is rendered
    expect(
      find.byWidgetPredicate((w) =>
          w is Text &&
          (w.data == 'Welcome Back' || (w.data?.contains('Welcome') ?? false))),
      findsWidgets,
    );

    // Cancel background timers to cleanly dispose test
    ZkTecoService.instance.stopAutoSync();
  });
}
