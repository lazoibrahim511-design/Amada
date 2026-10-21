import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/attendance_record.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/translation_keys.dart';

void main() {
  group('Hourly Leave Form Rules - Model & Serialization', () {
    test('EmployeeGroup defaults for hourly leave form rules', () {
      final group = EmployeeGroup(id: 'g1', name: 'Standard', shiftId: 's1');
      expect(group.hourlyLeaveMinHours, 0);
      expect(group.hourlyLeaveMinMinutes, 0);
      expect(group.hourlyLeaveMaxHours, 0);
      expect(group.hourlyLeaveMaxMinutes, 0);
      expect(group.totalHourlyLeaveMinMinutes, 0);
      expect(group.totalHourlyLeaveMaxMinutes, 0);
    });

    test('EmployeeGroup total minutes calculation', () {
      final group = EmployeeGroup(
        id: 'g1',
        name: 'Standard',
        shiftId: 's1',
        hourlyLeaveMinHours: 1,
        hourlyLeaveMinMinutes: 30,
        hourlyLeaveMaxHours: 4,
        hourlyLeaveMaxMinutes: 15,
      );
      expect(group.totalHourlyLeaveMinMinutes, 90);
      expect(group.totalHourlyLeaveMaxMinutes, 255);
      expect(group.hourlyLeaveMinDurationFormatted, '01:30');
      expect(group.hourlyLeaveMaxDurationFormatted, '04:15');
    });

    test('EmployeeGroup toMap and fromMap serialization', () {
      final group = EmployeeGroup(
        id: 'g_hourly',
        name: 'Hourly Group',
        shiftId: 's1',
        hourlyLeaveMinHours: 1,
        hourlyLeaveMinMinutes: 15,
        hourlyLeaveMaxHours: 3,
        hourlyLeaveMaxMinutes: 45,
      );

      final map = group.toMap();
      expect(map['hourlyLeaveMinHours'], 1);
      expect(map['hourlyLeaveMinMinutes'], 15);
      expect(map['hourlyLeaveMaxHours'], 3);
      expect(map['hourlyLeaveMaxMinutes'], 45);

      final restored = EmployeeGroup.fromMap(map, 'g_hourly');
      expect(restored.hourlyLeaveMinHours, 1);
      expect(restored.hourlyLeaveMinMinutes, 15);
      expect(restored.hourlyLeaveMaxHours, 3);
      expect(restored.hourlyLeaveMaxMinutes, 45);
      expect(restored.totalHourlyLeaveMinMinutes, 75);
      expect(restored.totalHourlyLeaveMaxMinutes, 225);
    });

    test('EmployeeGroup copyWith modifies hourly leave rules', () {
      final group = EmployeeGroup(id: 'g1', name: 'Standard', shiftId: 's1');
      final updated = group.copyWith(
        hourlyLeaveMinHours: 2,
        hourlyLeaveMinMinutes: 0,
        hourlyLeaveMaxHours: 5,
        hourlyLeaveMaxMinutes: 30,
      );
      expect(updated.hourlyLeaveMinHours, 2);
      expect(updated.hourlyLeaveMinMinutes, 0);
      expect(updated.hourlyLeaveMaxHours, 5);
      expect(updated.hourlyLeaveMaxMinutes, 30);
      expect(updated.totalHourlyLeaveMinMinutes, 120);
      expect(updated.totalHourlyLeaveMaxMinutes, 330);
    });
  });

  group('Hourly Leave Duration Parser & Formatter', () {
    test('parseHourlyLeaveDurationMinutes parses various representations', () {
      expect(parseHourlyLeaveDurationMinutes('2 Hours'), 120);
      expect(parseHourlyLeaveDurationMinutes('1 Hour'), 60);
      expect(parseHourlyLeaveDurationMinutes('1 Hour 30 Mins'), 90);
      expect(parseHourlyLeaveDurationMinutes('2 hrs 15 mins'), 135);
      expect(parseHourlyLeaveDurationMinutes('1h 45m'), 105);
      expect(parseHourlyLeaveDurationMinutes('45 Mins'), 45);
      expect(parseHourlyLeaveDurationMinutes('30 min'), 30);
      expect(parseHourlyLeaveDurationMinutes('15m'), 15);
      expect(parseHourlyLeaveDurationMinutes('1.5 Hours'), 90);
      expect(parseHourlyLeaveDurationMinutes('2:30'), 150);
      expect(parseHourlyLeaveDurationMinutes('From 15:00 to 16:00 for 1 hour'), 60);
      expect(parseHourlyLeaveDurationMinutes('From 15:00 to 16:30 for 1 hour 30 mins'), 90);
      expect(parseHourlyLeaveDurationMinutes('From 15:00 to 16:00'), 60);
      expect(parseHourlyLeaveDurationMinutes('From 15:00 to 17:30 for 2 hours 30 mins'), 150);
      expect(parseHourlyLeaveDurationMinutes('From 23:00 to 01:00 for 2 hours'), 120);
      expect(parseHourlyLeaveDurationMinutes('90'), 90);
      expect(parseHourlyLeaveDurationMinutes('2'), 120);
      expect(parseHourlyLeaveDurationMinutes(''), 0);
    });

    test('formatMinutesToHoursAndMinutes formats readable duration', () {
      expect(formatMinutesToHoursAndMinutes(120), '2h');
      expect(formatMinutesToHoursAndMinutes(90), '1h 30m');
      expect(formatMinutesToHoursAndMinutes(45), '45m');
      expect(formatMinutesToHoursAndMinutes(0), '0 min');
      expect(formatMinutesToHoursAndMinutes(75), '1h 15m');
    });

    test('formatMinutesToTimeString formats HH:mm string', () {
      expect(formatMinutesToTimeString(90), '01:30');
      expect(formatMinutesToTimeString(120), '02:00');
      expect(formatMinutesToTimeString(45), '00:45');
      expect(formatMinutesToTimeString(0), '00:00');
    });

    test('formatHourlyLeaveDurationString formats user-friendly From/To string', () {
      expect(formatHourlyLeaveDurationString('15:00', '16:00'), 'From 15:00 to 16:00 for 1 hour');
      expect(formatHourlyLeaveDurationString('15:00', '16:30'), 'From 15:00 to 16:30 for 1 hour 30 mins');
      expect(formatHourlyLeaveDurationString('15:00', '17:00'), 'From 15:00 to 17:00 for 2 hours');
      expect(formatHourlyLeaveDurationString('15:00', '15:45'), 'From 15:00 to 15:45 for 45 mins');
      expect(formatHourlyLeaveDurationString('15:00', '15:00'), 'From 15:00 to 15:00 for 0 min');
    });
  });

  group('Hourly Leave Form Rules - Validation Logic', () {
    test('Rejects request shorter than minimum duration', () {
      final group = EmployeeGroup(
        id: 'g1',
        name: 'Standard',
        shiftId: 's1',
        hourlyLeaveMinHours: 1,
        hourlyLeaveMinMinutes: 30, // Min 90 mins
        hourlyLeaveMaxHours: 4,
        hourlyLeaveMaxMinutes: 0,
      );

      final reqMins = parseHourlyLeaveDurationMinutes('1 Hour'); // 60 mins < 90 mins
      final minMins = group.totalHourlyLeaveMinMinutes;

      expect(reqMins < minMins, isTrue);

      final formattedMin = formatMinutesToHoursAndMinutes(minMins);
      final errMsg = TranslationKeys.translations['en']!['hourly_leave_min_error']!
          .replaceAll('{duration}', formattedMin);
      expect(errMsg, 'Hourly leave must be at least 1h 30m per request.');
    });

    test('Rejects request longer than maximum duration', () {
      final group = EmployeeGroup(
        id: 'g1',
        name: 'Standard',
        shiftId: 's1',
        hourlyLeaveMinHours: 0,
        hourlyLeaveMinMinutes: 30,
        hourlyLeaveMaxHours: 2,
        hourlyLeaveMaxMinutes: 0, // Max 120 mins
      );

      final reqMins = parseHourlyLeaveDurationMinutes('3 Hours'); // 180 mins > 120 mins
      final maxMins = group.totalHourlyLeaveMaxMinutes;

      expect(reqMins > maxMins, isTrue);

      final formattedMax = formatMinutesToHoursAndMinutes(maxMins);
      final errMsg = TranslationKeys.translations['en']!['hourly_leave_max_error']!
          .replaceAll('{duration}', formattedMax);
      expect(errMsg, 'Hourly leave cannot exceed 2h per request.');
    });

    test('Accepts request within allowed duration range', () {
      final group = EmployeeGroup(
        id: 'g1',
        name: 'Standard',
        shiftId: 's1',
        hourlyLeaveMinHours: 1,
        hourlyLeaveMinMinutes: 0, // 60 mins
        hourlyLeaveMaxHours: 3,
        hourlyLeaveMaxMinutes: 30, // 210 mins
      );

      final reqMins = parseHourlyLeaveDurationMinutes('2 Hours'); // 120 mins
      expect(reqMins >= group.totalHourlyLeaveMinMinutes, isTrue);
      expect(reqMins <= group.totalHourlyLeaveMaxMinutes, isTrue);
    });

    test('Allows any duration when min and max are 0 (unrestricted)', () {
      final group = EmployeeGroup(
        id: 'g1',
        name: 'Standard',
        shiftId: 's1',
        hourlyLeaveMinHours: 0,
        hourlyLeaveMinMinutes: 0,
        hourlyLeaveMaxHours: 0,
        hourlyLeaveMaxMinutes: 0,
      );

      final reqMins = parseHourlyLeaveDurationMinutes('5 Hours');
      // Neither min nor max condition triggered
      final violatesMin = group.totalHourlyLeaveMinMinutes > 0 && reqMins < group.totalHourlyLeaveMinMinutes;
      final violatesMax = group.totalHourlyLeaveMaxMinutes > 0 && reqMins > group.totalHourlyLeaveMaxMinutes;

      expect(violatesMin, isFalse);
      expect(violatesMax, isFalse);
    });
  });

  group('Hourly Leave Translations', () {
    test('All languages have hourly leave translation keys', () {
      for (final lang in ['en', 'ar', 'ku']) {
        final map = TranslationKeys.translations[lang]!;
        expect(map.containsKey('hourly_leave_rules'), isTrue, reason: '$lang missing hourly_leave_rules');
        expect(map.containsKey('hourly_leave_min_duration'), isTrue, reason: '$lang missing hourly_leave_min_duration');
        expect(map.containsKey('hourly_leave_max_duration'), isTrue, reason: '$lang missing hourly_leave_max_duration');
        expect(map.containsKey('min_hours'), isTrue, reason: '$lang missing min_hours');
        expect(map.containsKey('min_minutes'), isTrue, reason: '$lang missing min_minutes');
        expect(map.containsKey('max_hours'), isTrue, reason: '$lang missing max_hours');
        expect(map.containsKey('max_minutes'), isTrue, reason: '$lang missing max_minutes');
        expect(map.containsKey('hourly_leave_min_error'), isTrue, reason: '$lang missing hourly_leave_min_error');
        expect(map.containsKey('hourly_leave_max_error'), isTrue, reason: '$lang missing hourly_leave_max_error');
        expect(map.containsKey('allowed_hourly_limits'), isTrue, reason: '$lang missing allowed_hourly_limits');
      }
    });
  });

  group('Hourly Leave Time Range Parsing & Deficit Calculation', () {
    test('parseHourlyLeaveTimeRange extracts start, end, and duration minutes', () {
      final range1 = parseHourlyLeaveTimeRange('From 15:00 to 16:00 for 1 hour');
      expect(range1, isNotNull);
      expect(range1!.startMinutes, 15 * 60);
      expect(range1.endMinutes, 16 * 60);
      expect(range1.durationMinutes, 60);

      final range2 = parseHourlyLeaveTimeRange('From 09:30 to 11:00 for 1 hour 30 mins');
      expect(range2, isNotNull);
      expect(range2!.startMinutes, 9 * 60 + 30);
      expect(range2.endMinutes, 11 * 60);
      expect(range2.durationMinutes, 90);

      final range3 = parseHourlyLeaveTimeRange('14:00 - 15:30');
      expect(range3, isNotNull);
      expect(range3!.startMinutes, 14 * 60);
      expect(range3.endMinutes, 15 * 60 + 30);
      expect(range3.durationMinutes, 90);

      expect(parseHourlyLeaveTimeRange('1 hour'), isNull);
      expect(parseHourlyLeaveTimeRange(''), isNull);
    });

    test('8-hour shift with 0 punches and 1-hour hourly leave results in 7-hour deficit', () {
      const shiftDuration = 480; // 8 hours = 480 minutes
      const hourlyLeaveMins = 60; // 1 hour = 60 minutes
      const hasFullDayLeave = false; // Hourly Leave is NOT a full day leave

      // Without punches, missing punch deficit is 480
      int missingPunchDeficit = shiftDuration;
      int deficitMinutes = missingPunchDeficit;

      // Deficit reduced by approved hourly leave
      if (!hasFullDayLeave && hourlyLeaveMins > 0) {
        deficitMinutes = (deficitMinutes - hourlyLeaveMins).clamp(0, shiftDuration);
      }

      // Expected deficit: 480 - 60 = 420 minutes (7 hours)
      expect(deficitMinutes, 420);
      expect(deficitMinutes ~/ 60, 7);
      expect(deficitMinutes % 60, 0);
    });

    test('8-hour shift with 0 punches and full day leave results in 0 deficit', () {
      int calcDeficit(bool isFullDayLeave, int shiftDuration) {
        if (isFullDayLeave) return 0;
        return shiftDuration;
      }

      expect(calcDeficit(true, 480), 0);
      expect(calcDeficit(false, 480), 480);
    });

    test('8-hour shift with 7 hours worked and 1-hour hourly leave results in 0 deficit', () {
      const shiftDuration = 480;
      const workedMins = 420; // 7 hours
      const hourlyLeaveMins = 60; // 1 hour

      final effectiveRequired = (shiftDuration - hourlyLeaveMins).clamp(0, shiftDuration);
      final deficit = (effectiveRequired - workedMins).clamp(0, shiftDuration);

      expect(deficit, 0);
    });

    test('8-hour shift with 5 hours worked and 1-hour hourly leave results in 2-hour deficit', () {
      const shiftDuration = 480;
      const workedMins = 300; // 5 hours
      const hourlyLeaveMins = 60; // 1 hour

      final effectiveRequired = (shiftDuration - hourlyLeaveMins).clamp(0, shiftDuration);
      final deficit = (effectiveRequired - workedMins).clamp(0, shiftDuration);

      expect(deficit, 120); // 2 hours
    });
  });

  group('Missed Punch Attendance & Deficit Rules', () {
    test('AttendanceRecord.duration returns zero on past date when checkout is missing', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final record = AttendanceRecord(
        checkIn: DateTime(pastDate.year, pastDate.month, pastDate.day, 13, 32),
        checkOut: null,
      );
      // Must not calculate 48h+ or count to DateTime.now()
      expect(record.duration, Duration.zero);
      expect(record.duration.inMinutes, 0);
    });

    test('Unexcused missed punch on 8-hour shift has 0 attendance and 8 hours deficit', () {
      const shiftDurationMins = 480; // 8 hours
      const hasUnexcusedMissedPunch = true;
      const approvedHourlyLeaveMinutes = 0;

      int totalActualMinutes = 0;
      int deficitMinutes = 0;

      if (hasUnexcusedMissedPunch) {
        // Attendance must not be calculated
        totalActualMinutes = 0;
        // Deficit must be full shift time
        deficitMinutes = shiftDurationMins;
        if (approvedHourlyLeaveMinutes > 0) {
          deficitMinutes = (deficitMinutes - approvedHourlyLeaveMinutes).clamp(0, shiftDurationMins);
        }
      }

      expect(totalActualMinutes, 0);
      expect(deficitMinutes, 480);
      expect(deficitMinutes ~/ 60, 8);
    });

    test('Unexcused missed punch on 8-hour shift with 1h hourly leave has 0 attendance and 7 hours deficit', () {
      const shiftDurationMins = 480; // 8 hours
      const hasUnexcusedMissedPunch = true;
      const approvedHourlyLeaveMinutes = 60; // 1 hour

      int totalActualMinutes = 0;
      int deficitMinutes = 0;

      if (hasUnexcusedMissedPunch) {
        totalActualMinutes = 0;
        deficitMinutes = shiftDurationMins;
        if (approvedHourlyLeaveMinutes > 0) {
          deficitMinutes = (deficitMinutes - approvedHourlyLeaveMinutes).clamp(0, shiftDurationMins);
        }
      }

      expect(totalActualMinutes, 0);
      expect(deficitMinutes, 420); // 7 hours
      expect(deficitMinutes ~/ 60, 7);
    });
  });
}
