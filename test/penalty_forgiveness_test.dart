import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/translation_keys.dart';

void main() {
  group('EmployeeGroup Forgiveness Tests', () {
    test('EmployeeGroup defaults forgiveness to 0', () {
      final group = EmployeeGroup(id: 'g1', name: 'Standard Group', shiftId: 's1');
      expect(group.delayTier1Forgiveness, 0);
      expect(group.delayTier2Forgiveness, 0);
      expect(group.delayTier3Forgiveness, 0);
      expect(group.earlyExitTier1Forgiveness, 0);
      expect(group.earlyExitTier2Forgiveness, 0);
      expect(group.earlyExitTier3Forgiveness, 0);
    });

    test('EmployeeGroup serialization and copyWith preserves forgiveness', () {
      final group = EmployeeGroup(
        id: 'g1',
        name: 'Flexible Group',
        shiftId: 's1',
        delayTier1Min: 6,
        delayTier1Max: 15,
        delayTier1Penalty: 5000,
        delayTier1Forgiveness: 1,
        delayTier2Min: 16,
        delayTier2Max: 30,
        delayTier2Penalty: 20000,
        delayTier2Forgiveness: 0,
        delayTier3Min: 31,
        delayTier3Penalty: 30000,
        delayTier3Forgiveness: 0,
        earlyExitTier1Min: 5,
        earlyExitTier1Max: 15,
        earlyExitTier1Penalty: 4000,
        earlyExitTier1Forgiveness: 2,
        earlyExitTier2Min: 16,
        earlyExitTier2Max: 30,
        earlyExitTier2Penalty: 15000,
        earlyExitTier2Forgiveness: 1,
        earlyExitTier3Min: 31,
        earlyExitTier3Penalty: 25000,
        earlyExitTier3Forgiveness: 0,
      );

      final map = group.toMap();
      expect(map['delayTier1Forgiveness'], 1);
      expect(map['delayTier2Forgiveness'], 0);
      expect(map['earlyExitTier1Forgiveness'], 2);
      expect(map['earlyExitTier2Forgiveness'], 1);

      final fromMap = EmployeeGroup.fromMap(map, 'g1');
      expect(fromMap.delayTier1Forgiveness, 1);
      expect(fromMap.delayTier2Forgiveness, 0);
      expect(fromMap.earlyExitTier1Forgiveness, 2);
      expect(fromMap.earlyExitTier2Forgiveness, 1);

      final copied = fromMap.copyWith(delayTier1Forgiveness: 3);
      expect(copied.delayTier1Forgiveness, 3);
      expect(copied.earlyExitTier1Forgiveness, 2);
    });

    test('First-time forgiveness calculation simulation', () {
      final group = EmployeeGroup(
        id: 'g1',
        name: 'Group with 1st time forgiveness',
        shiftId: 's1',
        delayPenaltiesEnabled: true,
        delayTier1Min: 6,
        delayTier1Max: 15,
        delayTier1Penalty: 5000.0,
        delayTier1Forgiveness: 1, // First time forgiven!
        delayTier2Min: 16,
        delayTier2Max: 30,
        delayTier2Penalty: 20000.0,
        delayTier2Forgiveness: 0, // No forgiveness
      );

      // Day 1: 10 mins late (Tier 1) -> 1st occurrence -> Forgiven (0 IQD)
      int delayTier1Occurrences = 0;
      int dayDelay = 10;
      double penalty = 0.0;

      if (dayDelay >= group.delayTier1Min && dayDelay <= group.delayTier1Max) {
        delayTier1Occurrences++;
        if (delayTier1Occurrences > group.delayTier1Forgiveness) {
          penalty = group.delayTier1Penalty;
        }
      }
      expect(delayTier1Occurrences, 1);
      expect(penalty, 0.0); // FORGIVEN!

      // Day 5: 12 mins late (Tier 1) -> 2nd occurrence -> Penalty works!
      dayDelay = 12;
      penalty = 0.0;
      if (dayDelay >= group.delayTier1Min && dayDelay <= group.delayTier1Max) {
        delayTier1Occurrences++;
        if (delayTier1Occurrences > group.delayTier1Forgiveness) {
          penalty = group.delayTier1Penalty;
        }
      }
      expect(delayTier1Occurrences, 2);
      expect(penalty, 5000.0); // PENALTY APPLIED!

      // Day 12: 14 mins late (Tier 1) -> 3rd occurrence -> Penalty works!
      dayDelay = 14;
      penalty = 0.0;
      if (dayDelay >= group.delayTier1Min && dayDelay <= group.delayTier1Max) {
        delayTier1Occurrences++;
        if (delayTier1Occurrences > group.delayTier1Forgiveness) {
          penalty = group.delayTier1Penalty;
        }
      }
      expect(delayTier1Occurrences, 3);
      expect(penalty, 5000.0); // PENALTY APPLIED!

      // Day 15: 20 mins late (Tier 2) -> 1st occurrence but forgiveness is 0 -> Penalty works immediately!
      int delayTier2Occurrences = 0;
      dayDelay = 20;
      penalty = 0.0;
      if (dayDelay >= group.delayTier2Min && dayDelay <= group.delayTier2Max) {
        delayTier2Occurrences++;
        if (delayTier2Occurrences > group.delayTier2Forgiveness) {
          penalty = group.delayTier2Penalty;
        }
      }
      expect(delayTier2Occurrences, 1);
      expect(penalty, 20000.0); // PENALTY APPLIED IMMEDIATELY!
    });

    test('Translation keys exist across EN, AR, and KU', () {
      final en = TranslationKeys.translations['en']!;
      final ar = TranslationKeys.translations['ar']!;
      final ku = TranslationKeys.translations['ku']!;

      expect(en['forgiveness_times'], isNotNull);
      expect(ar['forgiveness_times'], isNotNull);
      expect(ku['forgiveness_times'], isNotNull);

      expect(en['forgiveness_hint'], isNotNull);
      expect(ar['forgiveness_hint'], isNotNull);
      expect(ku['forgiveness_hint'], isNotNull);

      expect(en['early_exit_penalties_levels'], isNotNull);
      expect(ar['early_exit_penalties_levels'], isNotNull);
      expect(ku['early_exit_penalties_levels'], isNotNull);
    });
  });
}
