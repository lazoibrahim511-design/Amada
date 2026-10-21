import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/translation_keys.dart';

void main() {
  test('Verify Kurdish payslip translations match app terminology', () {
    final ku = TranslationKeys.translations['ku']!;

    // 1. Employee vs Karmand
    expect(ku['employee'], 'فەرمانبەر');
    expect(ku['employee_details'], 'زانیاری فەرمانبەر');
    expect(ku['name_label'], 'ناوی فەرمانبەر');
    expect(ku['id_label'], 'کۆد');
    expect(ku['employee_signature'], 'واژۆی فەرمانبەر');

    // 2. Earnings & Additions
    expect(ku['earnings'], 'مووچە و زیادکراوەکان');
    expect(ku['total_earnings'], 'کۆی مووچە');
    expect(ku['total_gross_earnings'], 'کۆی مووچە');
    expect(ku['base_salary_calc_by_day'], 'مووچەی بنەڕەتی / ڕۆژانە');
    expect(ku['overtime_pay'], 'ئۆڤەرتایم');
    expect(ku['monthly_additions_bonuses'], 'زیادکراوەکان (پاداشت)');

    // 3. Deductions & Deficit
    expect(ku['deductions_title'], 'بڕینەکان');
    expect(ku['total_deductions'], 'کۆی بڕینەکان');
    expect(ku['attendance_deficit_deduction'], 'کەمی ئامادەبوون');
    expect(ku['loans_other_deductions'], 'قەرز و بڕینەکانی تر');
    expect(ku['penalties_delay_early_exit'], 'سزاکانی دواکەوتن و چوونەدەرەوە');

    // 4. Net Salary & Insurance
    expect(ku['net_payable_salary'], 'مووچەی سافی');
    expect(ku['gross_minus_deductions_desc'], 'کۆی مووچە - کۆی بڕینەکان');
    expect(ku['employer_contributions'], 'بەشی کۆمپانیا');
    expect(ku['ins_base_label'], 'مووچەی دەستەبەری');
    expect(ku['social_insurance_5_employee'], 'دەستەبەری (٥٪ فەرمانبەر)');

    // 5. Authority & Notes
    expect(ku['authorized_signature'], 'مۆر و واژۆی بەڕێوەبەرایەتی');
    expect(ku['official_stamp_title'], 'مۆر و واژۆی بەڕێوەبەرایەتی');
    expect(ku['administration_title'], 'بەڕێوەبەرایەتی');
  });
}
