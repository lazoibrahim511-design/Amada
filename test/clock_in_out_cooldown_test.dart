import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/attendance_record.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('3-Minute Clock-In to Clock-Out Cooldown Tests', () {
    late AttendanceProvider provider;

    setUp(() {
      provider = AttendanceProvider();
    });

    test('Clock-out blocked at 09:02 when clocked in at 09:00, allowed at 09:03', () async {
      final clockInTime = DateTime.now().subtract(const Duration(minutes: 2)); // 2 minutes ago (e.g. 09:00 to 09:02)
      final record = AttendanceRecord(
        checkIn: clockInTime,
        employeeId: 'emp_cooldown_test',
      );

      provider.upsertRecordLocally(record);
      // Manually set internal active record & clocked in state for testing
      provider.restoreActiveRecordForTesting(record);

      expect(provider.isClockedIn, isTrue);
      expect(provider.clockOutRemainingSeconds, greaterThan(0));
      expect(provider.clockOutRemainingSeconds, lessThanOrEqualTo(60));

      // Attempting to clock out before 3 minutes must fail with cooldown error
      final result = await provider.clockOut();
      expect(result, isNotNull);
      expect(result, contains('3'));

      // Now simulate 3 minutes having passed (e.g. 09:00 to 09:03:05)
      final matureClockInTime = DateTime.now().subtract(const Duration(minutes: 3, seconds: 5));
      final matureRecord = AttendanceRecord(
        checkIn: matureClockInTime,
        employeeId: 'emp_cooldown_test',
      );
      provider.restoreActiveRecordForTesting(matureRecord);

      expect(provider.clockOutRemainingSeconds, equals(0));
      expect(provider.getClockOutCooldownError(), isNull);
    });
  });
}

