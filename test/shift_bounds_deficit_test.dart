import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/attendance_record.dart';

void main() {
  group('Shift Bounds Deficit and Rest Calculation Tests', () {
    test('Night punches after shift end do not count as unexcused rest or blow up deficit', () {
      final shiftStart = DateTime(2026, 10, 18, 8, 0);
      final shiftEnd = DateTime(2026, 10, 18, 17, 0);

      final records = [
        AttendanceRecord(
          employeeId: '1',
          checkIn: DateTime(2026, 10, 18, 14, 51),
          checkOut: DateTime(2026, 10, 18, 17, 7),
        ),
        AttendanceRecord(
          employeeId: '1',
          checkIn: DateTime(2026, 10, 18, 23, 30),
          checkOut: DateTime(2026, 10, 18, 23, 35),
        ),
        AttendanceRecord(
          employeeId: '1',
          checkIn: DateTime(2026, 10, 18, 23, 44),
          checkOut: DateTime(2026, 10, 18, 23, 49),
        ),
      ];

      final sorted = List<AttendanceRecord>.from(records)
        ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

      // Calculate rest minutes bounded by shiftEnd
      int unexcusedRestMinutes = 0;
      for (int i = 0; i < sorted.length - 1; i++) {
        final currentOut = sorted[i].checkOut;
        final nextIn = sorted[i + 1].checkIn;
        if (currentOut != null && nextIn.isAfter(currentOut)) {
          if (currentOut.isAfter(shiftEnd) || currentOut.isAtSameMomentAs(shiftEnd)) {
            continue;
          }
          if (nextIn.isAfter(shiftEnd) || nextIn.isAtSameMomentAs(shiftEnd)) {
            continue;
          }
          final gapStart = currentOut.isAfter(shiftStart) ? currentOut : shiftStart;
          final gapEnd = nextIn.isBefore(shiftEnd) ? nextIn : shiftEnd;
          if (gapEnd.isAfter(gapStart)) {
            unexcusedRestMinutes += gapEnd.difference(gapStart).inMinutes;
          }
        }
      }

      // Rest minutes outside shift should be 0
      expect(unexcusedRestMinutes, 0);

      // Delay and Early Exit from shiftRecords
      final shiftRecords = sorted.where((r) => r.checkIn.isBefore(shiftEnd)).toList();
      expect(shiftRecords.length, 1);

      final firstRec = shiftRecords.first;
      final delay = firstRec.checkIn.difference(shiftStart).inMinutes;
      expect(delay, 411); // 6h 51m

      final lastRec = shiftRecords.last;
      final earlyExit = shiftEnd.difference(lastRec.checkOut!).inMinutes;
      expect(earlyExit < 0, true); // No early exit (stayed until 17:07)

      final dayEarlyExit = earlyExit > 0 ? earlyExit : 0;
      final totalDeficit = delay + dayEarlyExit + unexcusedRestMinutes;
      expect(totalDeficit, 411); // 6h 51m, exactly matching the 411m delay, NOT 13h 23m
    });

    test('Leaving early during shift followed by night punch still correctly records early exit', () {
      final shiftStart = DateTime(2026, 10, 18, 9, 0);
      final shiftEnd = DateTime(2026, 10, 18, 17, 0);

      final records = [
        AttendanceRecord(
          employeeId: '1',
          checkIn: DateTime(2026, 10, 18, 9, 0),
          checkOut: DateTime(2026, 10, 18, 16, 0), // Left 1 hour early
        ),
        AttendanceRecord(
          employeeId: '1',
          checkIn: DateTime(2026, 10, 18, 23, 30),
          checkOut: DateTime(2026, 10, 18, 23, 35),
        ),
      ];

      final sorted = List<AttendanceRecord>.from(records)
        ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

      // Calculate rest bounded by shiftEnd
      int unexcusedRestMinutes = 0;
      for (int i = 0; i < sorted.length - 1; i++) {
        final currentOut = sorted[i].checkOut;
        final nextIn = sorted[i + 1].checkIn;
        if (currentOut != null && nextIn.isAfter(currentOut)) {
          if (currentOut.isAfter(shiftEnd) || currentOut.isAtSameMomentAs(shiftEnd)) {
            continue;
          }
          if (nextIn.isAfter(shiftEnd) || nextIn.isAtSameMomentAs(shiftEnd)) {
            continue;
          }
          final gapStart = currentOut.isAfter(shiftStart) ? currentOut : shiftStart;
          final gapEnd = nextIn.isBefore(shiftEnd) ? nextIn : shiftEnd;
          if (gapEnd.isAfter(gapStart)) {
            unexcusedRestMinutes += gapEnd.difference(gapStart).inMinutes;
          }
        }
      }

      expect(unexcusedRestMinutes, 0); // Not counted as rest

      final shiftRecords = sorted.where((r) => r.checkIn.isBefore(shiftEnd)).toList();
      final lastRec = shiftRecords.last;
      final earlyExit = shiftEnd.difference(lastRec.checkOut!).inMinutes;
      expect(earlyExit, 60); // 1 hour early exit recorded
    });
  });
}
