import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/translation_keys.dart';

void main() {
  group('EmployeeGroup Night Overtime Configuration & Serialization', () {
    test('Default values for night overtime', () {
      final group = EmployeeGroup(id: 'g1', name: 'Engineering', shiftId: 's1');
      expect(group.nightOvertimeAllowed, false);
      expect(group.nightOvertimeStart, '22:00');
      expect(group.nightOvertimeEnd, '06:00');
      expect(group.nightOvertimeRatio, 1.5);
    });

    test('Serialization toMap and fromMap preserves night overtime', () {
      final group = EmployeeGroup(
        id: 'g1',
        name: 'Night Shift Crew',
        shiftId: 's1',
        overtimeAllowed: true,
        minOvertimeMinutes: 30,
        maxOvertimeMinutes: 360,
        holidayOvertimeRatio: 2.0,
        weekendOvertimeRatio: 1.5,
        nightOvertimeAllowed: true,
        nightOvertimeStart: '21:00',
        nightOvertimeEnd: '05:00',
        nightOvertimeRatio: 2.0,
      );

      final map = group.toMap();
      expect(map['nightOvertimeAllowed'], true);
      expect(map['nightOvertimeStart'], '21:00');
      expect(map['nightOvertimeEnd'], '05:00');
      expect(map['nightOvertimeRatio'], 2.0);

      final fromMap = EmployeeGroup.fromMap(map, 'g1');
      expect(fromMap.nightOvertimeAllowed, true);
      expect(fromMap.nightOvertimeStart, '21:00');
      expect(fromMap.nightOvertimeEnd, '05:00');
      expect(fromMap.nightOvertimeRatio, 2.0);

      final copied = fromMap.copyWith(
        nightOvertimeRatio: 3.0,
        nightOvertimeEnd: '07:00',
      );
      expect(copied.nightOvertimeRatio, 3.0);
      expect(copied.nightOvertimeEnd, '07:00');
      expect(copied.nightOvertimeStart, '21:00');
      expect(copied.nightOvertimeAllowed, true);
    });
  });

  group('Night Overlap Minutes Calculation', () {
    test('Cross-midnight window (22:00 to 06:00)', () {
      // Daytime only: 10:00 to 18:00
      final dt1 = DateTime(2026, 10, 12, 10, 0);
      final dt2 = DateTime(2026, 10, 12, 18, 0);
      expect(calculateNightOverlapMinutes(dt1, dt2, '22:00', '06:00'), 0);

      // Evening crossing into night: 20:00 to 23:00 (night from 22:00 to 23:00 = 60 mins)
      final dt3 = DateTime(2026, 10, 12, 20, 0);
      final dt4 = DateTime(2026, 10, 12, 23, 0);
      expect(calculateNightOverlapMinutes(dt3, dt4, '22:00', '06:00'), 60);

      // Night spanning across midnight: 23:00 to 03:00 next day (all 240 mins)
      final dt5 = DateTime(2026, 10, 12, 23, 0);
      final dt6 = DateTime(2026, 10, 13, 3, 0);
      expect(calculateNightOverlapMinutes(dt5, dt6, '22:00', '06:00'), 240);

      // Morning crossing out of night: 04:00 to 08:00 (night from 04:00 to 06:00 = 120 mins)
      final dt7 = DateTime(2026, 10, 13, 4, 0);
      final dt8 = DateTime(2026, 10, 13, 8, 0);
      expect(calculateNightOverlapMinutes(dt7, dt8, '22:00', '06:00'), 120);

      // Full night window: 22:00 to 06:00 next day = 480 mins
      final dt9 = DateTime(2026, 10, 12, 22, 0);
      final dt10 = DateTime(2026, 10, 13, 6, 0);
      expect(calculateNightOverlapMinutes(dt9, dt10, '22:00', '06:00'), 480);
    });

    test('Non-cross-midnight window (18:00 to 22:00)', () {
      final dt1 = DateTime(2026, 10, 12, 17, 0);
      final dt2 = DateTime(2026, 10, 12, 21, 0);
      // Overlap: 18:00 to 21:00 = 180 mins
      expect(calculateNightOverlapMinutes(dt1, dt2, '18:00', '22:00'), 180);

      // Outside window: 22:00 to 23:00
      final dt3 = DateTime(2026, 10, 12, 22, 0);
      final dt4 = DateTime(2026, 10, 12, 23, 0);
      expect(calculateNightOverlapMinutes(dt3, dt4, '18:00', '22:00'), 0);
    });

    test('Edge cases: invalid dates or empty times', () {
      final dt1 = DateTime(2026, 10, 12, 10, 0);
      final dt2 = DateTime(2026, 10, 12, 9, 0);
      expect(calculateNightOverlapMinutes(dt1, dt2, '22:00', '06:00'), 0);
      expect(calculateNightOverlapMinutes(dt2, dt1, '', ''), 0);
      expect(calculateNightOverlapMinutes(dt2, dt1, '12:00', '12:00'), 0);
    });
  });

  group('EmployeeGroup calculateOvertimeMinutes weighted calculation', () {
    final baseGroup = EmployeeGroup(
      id: 'g1',
      name: 'Shift Alpha',
      shiftId: 's1',
      overtimeAllowed: true,
      minOvertimeMinutes: 30,
      maxOvertimeMinutes: 480,
      holidayOvertimeRatio: 2.0,
      weekendOvertimeRatio: 1.5,
      nightOvertimeAllowed: true,
      nightOvertimeStart: '22:00',
      nightOvertimeEnd: '06:00',
      nightOvertimeRatio: 2.0,
    );

    test('Normal working day with night overtime: 120m day + 60m night (2x)', () {
      final result = baseGroup.calculateOvertimeMinutes(
        dayExtraMinutes: 180,
        nightExtraMinutes: 60,
        isWeekend: false,
        isHoliday: false,
      );
      // 120m day * 1.0 = 120
      // 60m night * 2.0 = 120
      // Total = 240 mins
      expect(result, 240);
    });

    test('Weekend with night overtime: 120m day (1.5x) + 60m night (2x)', () {
      final result = baseGroup.calculateOvertimeMinutes(
        dayExtraMinutes: 180,
        nightExtraMinutes: 60,
        isWeekend: true,
        isHoliday: false,
      );
      // 120m day * 1.5 = 180
      // 60m night * 2.0 = 120
      // Total = 300 mins
      expect(result, 300);
    });

    test('Holiday with night overtime: 120m day (2x) + 60m night (2x)', () {
      final result = baseGroup.calculateOvertimeMinutes(
        dayExtraMinutes: 180,
        nightExtraMinutes: 60,
        isWeekend: false,
        isHoliday: true,
      );
      // 120m day * 2.0 = 240
      // 60m night * 2.0 = 120
      // Total = 360 mins
      expect(result, 360);
    });

    test('Night overtime disabled falls back to standard single multiplier', () {
      final standardGroup = baseGroup.copyWith(nightOvertimeAllowed: false);
      final normalResult = standardGroup.calculateOvertimeMinutes(
        dayExtraMinutes: 180,
        nightExtraMinutes: 60,
        isWeekend: false,
        isHoliday: false,
      );
      expect(normalResult, 180); // 180 * 1.0

      final weekendResult = standardGroup.calculateOvertimeMinutes(
        dayExtraMinutes: 180,
        nightExtraMinutes: 60,
        isWeekend: true,
        isHoliday: false,
      );
      expect(weekendResult, (180 * 1.5).toInt()); // 270
    });

    test('Capped by maxOvertimeMinutes proportionally splits day and night', () {
      final cappedGroup = baseGroup.copyWith(maxOvertimeMinutes: 200);
      final result = cappedGroup.calculateOvertimeMinutes(
        dayExtraMinutes: 300, // 240 day, 60 night (20% night)
        nightExtraMinutes: 60,
        isWeekend: false,
        isHoliday: false,
      );
      // baseOt = 200
      // nightPart = round(200 * (60 / 300)) = 40
      // dayPart = 200 - 40 = 160
      // Total = 160 * 1.0 + 40 * 2.0 = 160 + 80 = 240
      expect(result, 240);
    });

    test('Overtime not allowed or below minimum returns 0', () {
      final disabledGroup = baseGroup.copyWith(overtimeAllowed: false);
      expect(
        disabledGroup.calculateOvertimeMinutes(
          dayExtraMinutes: 180,
          nightExtraMinutes: 60,
          isWeekend: false,
          isHoliday: false,
        ),
        0,
      );

      expect(
        baseGroup.calculateOvertimeMinutes(
          dayExtraMinutes: 20, // min is 30
          nightExtraMinutes: 20,
          isWeekend: false,
          isHoliday: false,
        ),
        0,
      );
    });
  });

  group('Night Overtime Translation Keys', () {
    test('Translation keys exist across EN, AR, and KU', () {
      final keys = [
        'enable_night_overtime',
        'night_start_time',
        'night_end_time',
        'night_overtime_multiplier',
      ];

      for (final key in keys) {
        expect(
          TranslationKeys.translations['en']!.containsKey(key),
          true,
          reason: 'Key "$key" missing in English translations',
        );
        expect(
          TranslationKeys.translations['ar']!.containsKey(key),
          true,
          reason: 'Key "$key" missing in Arabic translations',
        );
        expect(
          TranslationKeys.translations['ku']!.containsKey(key),
          true,
          reason: 'Key "$key" missing in Kurdish translations',
        );
      }
    });
  });
}
