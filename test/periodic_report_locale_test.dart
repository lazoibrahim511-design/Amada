import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/translation_keys.dart';

void main() {
  group('Periodic Report Translation Keys', () {
    test('Verify Periodic Report keys exist across EN, AR, and KU', () {
      final keys = [
        'periodic_report',
        'month_view',
        'custom_range',
        'previous_month',
        'next_month',
        'quick_pick_month',
        'all_structures_dropdown',
        'all_groups_dropdown',
        'search_periodic_employee_hint',
        'all_employees',
        'late_arrival',
        'unexcused_absence',
        'leaves_filter',
        'any_operator',
        'operator_gte',
        'operator_lte',
        'operator_gt',
        'operator_lt',
        'quick_values',
        'one_day',
        'n_days',
        'n_mins',
        'n_hours',
        'one_hour',
        'total_deficit_card',
        'missing_duty_hours_sub',
        'total_overtime_card',
        'payable_extra_hours_sub',
        'delays_early_exits_card',
        'lates_early_departs_sub',
        'penalties_deductions_card',
        'policy_deductions_sub',
        'absences_leaves_card',
        'for_n_employees_sub',
        'unit_hrs_short',
        'unit_days_short',
        'unit_absences_short',
        'unit_leaves_short',
        'group_policy_col',
        'req_hrs_col',
        'actual_hrs_col',
        'deficit_shortage_col',
        'delay_m_col',
        'early_exit_m_col',
        'daily_leaves_col',
        'hourly_perm_col',
        'remaining_annual_col',
        'absences_col',
        'daily_audit_col',
        'view_daily_audit_tooltip',
        'no_records_periodic',
        'daily_punch_audit_title',
        'worked_suffix',
        'ot_suffix',
        'excel_export_btn',
        'pdf_export_btn',
        'periodic_excel_success',
        'periodic_pdf_success',
        'periodic_excel_failed',
        'periodic_pdf_failed',
        'weekend_off_day',
        'holiday_status_prefix',
        'late_early_status',
        'late_status',
        'early_status',
      ];

      for (final lang in ['en', 'ar', 'ku']) {
        final dict = TranslationKeys.translations[lang]!;
        for (final key in keys) {
          expect(
            dict.containsKey(key),
            true,
            reason: 'Key "$key" is missing in $lang translations',
          );
          expect(
            dict[key]?.trim().isNotEmpty,
            true,
            reason: 'Key "$key" has empty value in $lang translations',
          );
        }
      }
    });

    test('Verify Kurdish column headers with parentheses format correctly', () {
      final kuDict = TranslationKeys.translations['ku']!;
      final parenthesisKeys = [
        'req_hrs_col',
        'actual_hrs_col',
        'delay_m_col',
        'early_exit_m_col',
        'overtime_hrs_col',
      ];

      for (final key in parenthesisKeys) {
        final val = kuDict[key]!;
        expect(val.contains('('), true, reason: '$key should have opening parenthesis');
        expect(val.contains(')'), true, reason: '$key should have closing parenthesis');
        expect(val.indexOf('(') < val.indexOf(')'), true, reason: '$key opening parenthesis should precede closing parenthesis');
      }
    });

    test('Verify updated Kurdish report terms match user request', () {
      final kuDict = TranslationKeys.translations['ku']!;
      expect(kuDict['id_label'], 'کۆد');
      expect(kuDict['employee_col'], 'فەرمانبەر');
      expect(kuDict['actual_hrs_col'], 'کردار (ک)');
      expect(kuDict['deficit_shortage_col'], 'کەمی ئامادەبوون');
      expect(kuDict['early_exit_m_col'], 'زوو دەرچوون (خ)');
      expect(kuDict['total_deficit_card'], 'کۆی کەمی ئامادەبوون');
      expect(kuDict['delays_early_exits_card'], 'دواکەوتن و زوو دەرچوون');
    });
  });
}
