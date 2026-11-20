import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/attendance_record.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Overnight Shift Cutoff Tests (Attribution to Prev Day vs Current Day)', () {
    late AttendanceProvider provider;
    late CompanyEmployee emp;
    late WorkShift shift;

    setUp(() async {
      provider = AttendanceProvider();
      shift = WorkShift(
        id: 'shift_amada',
        name: 'Normal Shift (09:00 - 17:00)',
        startTime: '09:00',
        endTime: '17:00',
        isOvernight: true,
        crossMidnightCutoff: '03:00',
        workingDays: [1, 2, 3, 4, 5, 6, 7],
      );

      final group = EmployeeGroup(
        id: 'grp_default',
        name: 'General Group',
        shiftId: shift.id,
      );

      emp = CompanyEmployee(
        id: 'emp_kale',
        name: 'کاڵێ جەلال محمد',
        email: 'kale@company.com',
        position: 'Team Member',
        companyCode: 'amada',
        groupId: group.id,
      );

      await provider.addShift(shift);
      await provider.addGroup(group);
      await provider.addEmployee(emp);
    });

    test('Punch after 03:00 cutoff (e.g. 07:03) calculates as check-in of that day, NOT check-out of day before', () {
      final wednesday = DateTime(2026, 11, 11);
      final thursday = DateTime(2026, 11, 12);

      // Simulating the user scenario from screenshots:
      // A record existed with checkIn Wednesday 07:03 and wrongly paired checkOut Thursday 07:03,
      // and Thursday 14:03 as open punch.
      final records = [
        AttendanceRecord(
          checkIn: DateTime(2026, 11, 11, 7, 3),
          checkOut: DateTime(2026, 11, 12, 7, 3),
          employeeId: emp.id,
          companyCode: 'amada',
        ),
        AttendanceRecord(
          checkIn: DateTime(2026, 11, 12, 14, 3),
          checkOut: null,
          employeeId: emp.id,
          companyCode: 'amada',
        ),
      ];

      // 1. Wednesday: Thursday 07:03 exceeds 03:00 cutoff, so it must NOT count as Wednesday checkout.
      // Wednesday must be 07:03 - Missing!
      final wedRecords = provider.getRecordsForDate(
        wednesday,
        emp: emp,
        recordsPool: records,
      );
      expect(wedRecords.length, 1);
      expect(wedRecords.first.checkIn, DateTime(2026, 11, 11, 7, 3));
      expect(wedRecords.first.checkOut, isNull, reason: 'Thursday 07:03 is past 03:00 cutoff so Wednesday has missing checkout');

      // 2. Thursday: Thursday 07:03 punch belongs to Thursday as check-in, paired with Thursday 14:03 checkout!
      final thuRecords = provider.getRecordsForDate(
        thursday,
        emp: emp,
        recordsPool: records,
      );
      expect(thuRecords.length, 1);
      expect(thuRecords.first.checkIn, DateTime(2026, 11, 12, 7, 3), reason: 'Thursday 07:03 is Thursday check-in');
      expect(thuRecords.first.checkOut, DateTime(2026, 11, 12, 14, 3), reason: 'Thursday 14:03 is Thursday check-out');
      expect(thuRecords.first.duration.inMinutes, 7 * 60, reason: 'Thursday duration is 7 hours (07:03 to 14:03)');
    });

    test('Checkout up until 03:00 (e.g. 02:30 or 03:00) counts as checkout of previous day', () {
      final wednesday = DateTime(2026, 11, 11);
      final thursday = DateTime(2026, 11, 12);

      final records = [
        AttendanceRecord(
          checkIn: DateTime(2026, 11, 11, 20, 0),
          checkOut: DateTime(2026, 11, 12, 2, 30),
          employeeId: emp.id,
          companyCode: 'amada',
        ),
      ];

      final wedRecords = provider.getRecordsForDate(
        wednesday,
        emp: emp,
        recordsPool: records,
      );
      expect(wedRecords.length, 1);
      expect(wedRecords.first.checkIn, DateTime(2026, 11, 11, 20, 0));
      expect(wedRecords.first.checkOut, DateTime(2026, 11, 12, 2, 30));

      final thuRecords = provider.getRecordsForDate(
        thursday,
        emp: emp,
        recordsPool: records,
      );
      expect(thuRecords.isEmpty, isTrue, reason: 'Thursday has no records because 02:30 belongs to Wednesday');
    });

    test('Punch exactly at 03:00 cutoff belongs to previous day, punch at 03:01 belongs to current day', () {
      final punchAt300 = DateTime(2026, 11, 12, 3, 0);
      final punchAt301 = DateTime(2026, 11, 12, 3, 1);

      final eff300 = provider.getEffectiveDateForPunch(punchAt300, emp);
      final eff301 = provider.getEffectiveDateForPunch(punchAt301, emp);

      expect(eff300, DateTime(2026, 11, 11), reason: '03:00 counts for Wednesday (day before)');
      expect(eff301, DateTime(2026, 11, 12), reason: '03:01 counts for Thursday (that day)');
    });

    test('Active session restoration checks cutoff: active before 03:00, expired after 03:00', () {
      final openRecordWednesdayNight = AttendanceRecord(
        checkIn: DateTime(2026, 11, 11, 22, 0),
        checkOut: null,
        employeeId: emp.id,
      );

      // Next day at 02:00 AM (before 03:00 cutoff) -> still active
      final nowAt2AM = DateTime(2026, 11, 12, 2, 0);
      expect(provider.isRecordStillActive(openRecordWednesdayNight, nowAt2AM, emp), isTrue);

      // Next day at 03:05 AM (after 03:00 cutoff) -> expired!
      final nowAt305AM = DateTime(2026, 11, 12, 3, 5);
      expect(provider.isRecordStillActive(openRecordWednesdayNight, nowAt305AM, emp), isFalse);

      // Next day at 07:03 AM -> expired!
      final nowAt703AM = DateTime(2026, 11, 12, 7, 3);
      expect(provider.isRecordStillActive(openRecordWednesdayNight, nowAt703AM, emp), isFalse);
    });

    test('Daytime shift (09:00 - 17:00) with overnight cutoff enabled calculates Early Exit on same day (2h 57m, NOT 26h 57m)', () {
      final date = DateTime(2026, 11, 12);
      final startTimeStr = shift.getStartTimeForDate(date);
      final endTimeStr = shift.getEndTimeForDate(date);
      final partsStart = startTimeStr.split(':');
      final partsEnd = endTimeStr.split(':');
      final shiftStartMinutes = int.parse(partsStart[0]) * 60 + int.parse(partsStart[1]);
      final shiftEndMinutes = int.parse(partsEnd[0]) * 60 + int.parse(partsEnd[1]);

      final shiftStart = DateTime(date.year, date.month, date.day, shiftStartMinutes ~/ 60, shiftStartMinutes % 60);
      var shiftEnd = DateTime(date.year, date.month, date.day, shiftEndMinutes ~/ 60, shiftEndMinutes % 60);
      if (shiftEnd.isBefore(shiftStart) || shiftEnd.isAtSameMomentAs(shiftStart)) {
        shiftEnd = shiftEnd.add(const Duration(days: 1));
      }

      expect(shiftEnd, DateTime(2026, 11, 12, 17, 0), reason: 'Shift ends on same day at 17:00, NOT next day');

      final checkOut = DateTime(2026, 11, 12, 14, 3);
      final earlyExit = shiftEnd.difference(checkOut).inMinutes;
      expect(earlyExit, 177, reason: '17:00 - 14:03 = 177 minutes = 2 hours and 57 minutes');
    });
  });

  group('24-Hour Special Rotating Shift Tests (Best Energy Scenario)', () {
    late AttendanceProvider provider;
    late CompanyEmployee emp;
    late WorkShift shift24h;

    setUp(() async {
      provider = AttendanceProvider();
      // Setup the exact shift from screenshots:
      // "C قەپان و تاقیکە"
      // 3-Day Rotation: Day 1 Off, Day 2 Off, Day 3 Working (08:00 - 08:00, 24-Hour Shift)
      // Cycle Anchor Date: 2026-11-11
      shift24h = WorkShift(
        id: 'shift_best_energy_24h',
        name: 'C قەپان و تاقیکە',
        startTime: '08:00',
        endTime: '08:00',
        isRotation: true,
        rotationDays: 3,
        rotationStartDate: '2026-11-11',
        isSpecialShift: true,
        rotationSchedule: {
          1: DayShiftConfig(isWorkingDay: false),
          2: DayShiftConfig(isWorkingDay: false),
          3: DayShiftConfig(
            isWorkingDay: true,
            startTime: '08:00',
            endTime: '08:00',
            isOvernight: true,
            crossMidnightCutoff: '09:30',
            isSpecialShift: true,
          ),
        },
      );

      final group = EmployeeGroup(
        id: 'grp_best_energy',
        name: 'Best Energy Team',
        shiftId: shift24h.id,
      );

      emp = CompanyEmployee(
        id: 'emp_miran',
        name: 'ميران عوسمان سيدكاكل',
        email: 'miran@bestenergy.com',
        position: 'کارمەند',
        companyCode: 'best_energy',
        groupId: group.id,
      );

      await provider.addShift(shift24h);
      await provider.addGroup(group);
      await provider.addEmployee(emp);
    });

    test('Cycle calculation matches: Nov 11 (Day 1 Off), Nov 12 (Day 2 Off), Nov 13 (Day 3 Work 24h), Nov 16 (Day 3 Work 24h)', () {
      final nov11 = DateTime(2026, 11, 11);
      final nov12 = DateTime(2026, 11, 12);
      final nov13 = DateTime(2026, 11, 13);
      final nov14 = DateTime(2026, 11, 14);
      final nov15 = DateTime(2026, 11, 15);
      final nov16 = DateTime(2026, 11, 16);
      final nov17 = DateTime(2026, 11, 17);

      expect(shift24h.getRotationDayForDate(nov11), 1);
      expect(shift24h.isWorkingDay(nov11), isFalse);

      expect(shift24h.getRotationDayForDate(nov12), 2);
      expect(shift24h.isWorkingDay(nov12), isFalse);

      expect(shift24h.getRotationDayForDate(nov13), 3);
      expect(shift24h.isWorkingDay(nov13), isTrue);
      expect(shift24h.getShiftDurationMinutesForDate(nov13), 24 * 60);

      expect(shift24h.getRotationDayForDate(nov14), 1);
      expect(shift24h.isWorkingDay(nov14), isFalse);

      expect(shift24h.getRotationDayForDate(nov15), 2);
      expect(shift24h.isWorkingDay(nov15), isFalse);

      // Monday 16 Nov is Day 3 (24h working day)
      expect(shift24h.getRotationDayForDate(nov16), 3);
      expect(shift24h.isWorkingDay(nov16), isTrue);
      expect(shift24h.getShiftDurationMinutesForDate(nov16), 24 * 60);

      // Tuesday 17 Nov is Day 1 (Day Off)
      expect(shift24h.getRotationDayForDate(nov17), 1);
      expect(shift24h.isWorkingDay(nov17), isFalse);
    });

    test('24-Hour Shift: Clock-in on Monday 08:15 and Clock-out on Tuesday 08:15 pairs cleanly to Monday with 24 hours', () {
      final monday = DateTime(2026, 11, 16);
      final tuesday = DateTime(2026, 11, 17);

      final record = AttendanceRecord(
        checkIn: DateTime(2026, 11, 16, 8, 15),
        checkOut: DateTime(2026, 11, 17, 8, 15),
        employeeId: emp.id,
        companyCode: 'best_energy',
      );

      // 1. Monday 16 Nov: The 24h record must be attributed to Monday
      final mondayRecords = provider.getRecordsForDate(
        monday,
        emp: emp,
        recordsPool: [record],
      );
      expect(mondayRecords.length, 1);
      expect(mondayRecords.first.checkIn, DateTime(2026, 11, 16, 8, 15));
      expect(mondayRecords.first.checkOut, DateTime(2026, 11, 17, 8, 15));
      expect(mondayRecords.first.duration.inMinutes, 24 * 60, reason: 'Record spans 24 hours');

      // 2. Tuesday 17 Nov (Day Off): Must have ZERO records (no ghost punches)
      final tuesdayRecords = provider.getRecordsForDate(
        tuesday,
        emp: emp,
        recordsPool: [record],
      );
      expect(tuesdayRecords.isEmpty, isTrue, reason: 'Tuesday is Day Off; Tuesday checkout was paired with Monday');
    });

    test('24-Hour Shift: Active record stays active next morning up to user-configured Cutoff (09:30) & max hours (26h)', () {
      final openRecordMondayMorning = AttendanceRecord(
        checkIn: DateTime(2026, 11, 16, 8, 15),
        checkOut: null,
        employeeId: emp.id,
        companyCode: 'best_energy',
      );

      // Tuesday at 08:00 AM (23h 45m elapsed, before 09:30 cutoff) -> still active!
      final nowTuesday800AM = DateTime(2026, 11, 17, 8, 0);
      expect(provider.isRecordStillActive(openRecordMondayMorning, nowTuesday800AM, emp), isTrue);

      // Tuesday at 08:30 AM (24h 15m elapsed, before 09:30 cutoff) -> still active!
      final nowTuesday830AM = DateTime(2026, 11, 17, 8, 30);
      expect(provider.isRecordStillActive(openRecordMondayMorning, nowTuesday830AM, emp), isTrue);

      // Tuesday at 09:29 AM (before 09:30 cutoff) -> still active!
      final nowTuesday929AM = DateTime(2026, 11, 17, 9, 29);
      expect(provider.isRecordStillActive(openRecordMondayMorning, nowTuesday929AM, emp), isTrue);

      // Tuesday at 09:35 AM (past 09:30 user cutoff) -> EXPIRED!
      final nowTuesday935AM = DateTime(2026, 11, 17, 9, 35);
      expect(provider.isRecordStillActive(openRecordMondayMorning, nowTuesday935AM, emp), isFalse, reason: 'Exceeded user cutoff 09:30');

      // Tuesday at 12:00 PM (past 09:30 user cutoff & past 26h) -> EXPIRED!
      final nowTuesday1200PM = DateTime(2026, 11, 17, 12, 0);
      expect(provider.isRecordStillActive(openRecordMondayMorning, nowTuesday1200PM, emp), isFalse, reason: 'Exceeded user cutoff & max hours');
    });

    test('24-Hour Shift: Punch before user cutoff (09:15) attributes to Monday, punch after cutoff (09:45) attributes to Tuesday', () {
      final punchBeforeCutoff = DateTime(2026, 11, 17, 9, 15);
      final punchAfterCutoff = DateTime(2026, 11, 17, 9, 45);

      final effBefore = provider.getEffectiveDateForPunch(punchBeforeCutoff, emp);
      final effAfter = provider.getEffectiveDateForPunch(punchAfterCutoff, emp);

      expect(effBefore, DateTime(2026, 11, 16), reason: 'Punch before 09:30 cutoff belongs to Monday 24h shift');
      expect(effAfter, DateTime(2026, 11, 17), reason: 'Punch after 09:30 cutoff belongs to Tuesday (current day)');
    });

    test('24-Hour Shift: Checkout after cutoff (e.g. 09:45) does not close Monday; Monday is Missing, Tuesday is new check-in', () {
      final monday = DateTime(2026, 11, 16);
      final tuesday = DateTime(2026, 11, 17);

      final lateCheckoutRecord = AttendanceRecord(
        checkIn: DateTime(2026, 11, 16, 8, 15),
        checkOut: DateTime(2026, 11, 17, 9, 45), // 09:45 is after 09:30 cutoff!
        employeeId: emp.id,
        companyCode: 'best_energy',
      );

      final monRecords = provider.getRecordsForDate(
        monday,
        emp: emp,
        recordsPool: [lateCheckoutRecord],
      );
      expect(monRecords.length, 1);
      expect(monRecords.first.checkIn, DateTime(2026, 11, 16, 8, 15));
      expect(monRecords.first.checkOut, isNull, reason: 'Monday has missing checkout because Tuesday 09:45 punch is past cutoff');

      final tueRecords = provider.getRecordsForDate(
        tuesday,
        emp: emp,
        recordsPool: [lateCheckoutRecord],
      );
      expect(tueRecords.length, 1);
      expect(tueRecords.first.checkIn, DateTime(2026, 11, 17, 9, 45), reason: '09:45 becomes Tuesday check-in');
    });

    test('User can set custom maxContinuousHours (e.g. 30h) with extended cutoff (14:00)', () {
      final updatedSchedule = Map<int, DayShiftConfig>.from(shift24h.rotationSchedule);
      updatedSchedule[3] = DayShiftConfig(
        isWorkingDay: true,
        startTime: '08:00',
        endTime: '08:00',
        isOvernight: true,
        crossMidnightCutoff: '14:00',
        maxContinuousHours: 30,
      );

      final customShift = shift24h.copyWith(
        rotationSchedule: updatedSchedule,
        crossMidnightCutoff: '14:00',
        maxContinuousHours: 30,
      );

      expect(customShift.getMaxContinuousHoursForDate(DateTime(2026, 11, 16)), 30);
      expect(customShift.getCrossMidnightCutoffForDate(DateTime(2026, 11, 16)), '14:00');
    });
  });
}
