import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bidi/bidi.dart' as bidi;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../models/translation_keys.dart';

class ExportService {
  static Future<void> exportPayrollToExcel(
    List<PayrollReport> reports,
    DateTime month,
    CompanyProfile? profile,
  ) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Payroll ${DateFormat('MMM_yyyy').format(month)}';

    int rowOffset = 1;

    // Add Company Profile info if available
    if (profile != null) {
      if (profile.logoBase64 != null && profile.logoBase64!.isNotEmpty) {
        try {
          final Uint8List imageBytes = base64Decode(profile.logoBase64!);
          final picture = sheet.pictures.addStream(rowOffset, 1, imageBytes);
          picture.height = 60;
          picture.width = 60;
          // Just shift row offset down a bit more
          rowOffset += 3;
        } catch (e) {
          debugPrint('Could not add image to excel: $e');
        }
      }
      sheet.getRangeByIndex(rowOffset, 1).setText(profile.name);
      sheet.getRangeByIndex(rowOffset, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(rowOffset, 1).cellStyle.fontSize = 14;
      rowOffset++;

      if (profile.address.isNotEmpty) {
        sheet.getRangeByIndex(rowOffset, 1).setText(profile.address);
        rowOffset++;
      }

      if (profile.email != null && profile.email!.isNotEmpty) {
        sheet.getRangeByIndex(rowOffset, 1).setText('Email: ${profile.email}');
        rowOffset++;
      }

      if (profile.phone != null && profile.phone!.isNotEmpty) {
        sheet.getRangeByIndex(rowOffset, 1).setText('Phone: ${profile.phone}');
        rowOffset++;
      }

      rowOffset++; // empty row
    }

    // Headers
    final headers = [
      'Employee',
      'Basic Salary',
      'Salary by Day',
      'Days Worked',
      'Working Hrs',
      'Overtime (Hrs)',
      'Overtime (Val)',
      'Deficit (Hrs)',
      'Deficit (Val)',
      'Unpaid Leave (Hrs)',
      'Unpaid Leave (Val)',
      'Food Allow.',
      'Trans. Allow.',
      'Other Allow.',
      'Ins. Salary',
      'Ins. 5% (Emp)',
      'Ins. 12% (Comp)',
      'Additions',
      'Penalties',
      'Other Deduct.',
      'Gross Salary',
      'Deductions',
      'Net Earnings',
      'Currency',
    ];

    for (int col = 0; col < headers.length; col++) {
      sheet.getRangeByIndex(rowOffset, col + 1).setText(headers[col]);
      sheet.getRangeByIndex(rowOffset, col + 1).cellStyle.bold = true;
    }

    // Rows
    for (int i = 0; i < reports.length; i++) {
      final r = reports[i];
      final row = rowOffset + i + 1;
      sheet.getRangeByIndex(row, 1).setText(r.employee.name);
      sheet.getRangeByIndex(row, 2).setNumber(r.basicSalary);
      sheet.getRangeByIndex(row, 3).setNumber(r.salaryCalcByDay);
      sheet.getRangeByIndex(row, 4).setNumber(r.daysWorked.toDouble());
      sheet.getRangeByIndex(row, 5).setNumber(r.workingHours);
      sheet.getRangeByIndex(row, 6).setNumber(r.overtimeHours);
      sheet.getRangeByIndex(row, 7).setNumber(r.overtimeValue);
      sheet.getRangeByIndex(row, 8).setNumber(r.attendanceDeficitHours);
      sheet.getRangeByIndex(row, 9).setNumber(r.attendanceDeficit);
      sheet.getRangeByIndex(row, 10).setNumber(r.unpaidLeaveHours);
      sheet.getRangeByIndex(row, 11).setNumber(r.unpaidLeaveDeduction);
      sheet.getRangeByIndex(row, 12).setNumber(r.foodAllowance);
      sheet.getRangeByIndex(row, 13).setNumber(r.transportationAllowance);
      sheet.getRangeByIndex(row, 14).setNumber(r.otherAllowance);
      sheet
          .getRangeByIndex(row, 15)
          .setNumber(r.hasInsurance ? r.insuranceSalary : 0.0);
      sheet
          .getRangeByIndex(row, 16)
          .setNumber(r.hasInsurance ? r.insuranceEmployee : 0.0);
      sheet
          .getRangeByIndex(row, 17)
          .setNumber(r.hasInsurance ? r.insuranceCompany : 0.0);
      sheet.getRangeByIndex(row, 18).setNumber(r.monthlyAdditions);
      sheet.getRangeByIndex(row, 19).setNumber(r.monthlyPenalties);
      sheet.getRangeByIndex(row, 20).setNumber(r.monthlyDeductions);
      sheet.getRangeByIndex(row, 21).setNumber(r.incrementalSalary);
      sheet.getRangeByIndex(row, 22).setNumber(r.decrementalSalary);
      sheet.getRangeByIndex(row, 23).setNumber(r.netEarnings);
      sheet.getRangeByIndex(row, 24).setText(r.currency);
    }

    // Total row
    if (reports.isNotEmpty) {
      final totalRow = rowOffset + reports.length + 1;
      final totalBasicSalary = reports.fold(
        0.0,
        (sum, r) => sum + r.basicSalary,
      );
      final totalSalaryCalcByDay = reports.fold(
        0.0,
        (sum, r) => sum + r.salaryCalcByDay,
      );
      final totalDaysWorked = reports.fold(0, (sum, r) => sum + r.daysWorked);
      final totalWorkingHours = reports.fold(
        0.0,
        (sum, r) => sum + r.workingHours,
      );
      final totalOvertimeHours = reports.fold(
        0.0,
        (sum, r) => sum + r.overtimeHours,
      );
      final totalOvertimeValue = reports.fold(
        0.0,
        (sum, r) => sum + r.overtimeValue,
      );
      final totalDeficitHours = reports.fold(
        0.0,
        (sum, r) => sum + r.attendanceDeficitHours,
      );
      final totalDeficitValue = reports.fold(
        0.0,
        (sum, r) => sum + r.attendanceDeficit,
      );
      final totalUnpaidLeaveHours = reports.fold(
        0.0,
        (sum, r) => sum + r.unpaidLeaveHours,
      );
      final totalUnpaidLeaveValue = reports.fold(
        0.0,
        (sum, r) => sum + r.unpaidLeaveDeduction,
      );
      final totalMonthlyAdditions = reports.fold(
        0.0,
        (sum, r) => sum + r.monthlyAdditions,
      );
      final totalMonthlyDeductions = reports.fold(
        0.0,
        (sum, r) => sum + r.monthlyDeductions,
      );
      final totalFoodAllowance = reports.fold(
        0.0,
        (sum, r) => sum + r.foodAllowance,
      );
      final totalTransportationAllowance = reports.fold(
        0.0,
        (sum, r) => sum + r.transportationAllowance,
      );
      final totalOtherAllowance = reports.fold(
        0.0,
        (sum, r) => sum + r.otherAllowance,
      );
      final totalInsuranceSalary = reports
          .where((r) => r.hasInsurance)
          .fold(0.0, (sum, r) => sum + r.insuranceSalary);
      final totalInsurance5 = reports.fold(
        0.0,
        (sum, r) => sum + r.insuranceEmployee,
      );
      final totalInsurance12 = reports.fold(
        0.0,
        (sum, r) => sum + r.insuranceCompany,
      );
      final totalPenalties = reports.fold(
        0.0,
        (sum, r) => sum + r.monthlyPenalties,
      );
      final totalGrossSalary = reports.fold(
        0.0,
        (sum, r) => sum + r.incrementalSalary,
      );
      final totalDeductions = reports.fold(
        0.0,
        (sum, r) => sum + r.decrementalSalary,
      );
      final totalNetEarnings = reports.fold(
        0.0,
        (sum, r) => sum + r.netEarnings,
      );

      sheet.getRangeByIndex(totalRow, 1).setText('Total');
      sheet.getRangeByIndex(totalRow, 2).setNumber(totalBasicSalary);
      sheet.getRangeByIndex(totalRow, 3).setNumber(totalSalaryCalcByDay);
      sheet.getRangeByIndex(totalRow, 4).setNumber(totalDaysWorked.toDouble());
      sheet.getRangeByIndex(totalRow, 5).setNumber(totalWorkingHours);
      sheet.getRangeByIndex(totalRow, 6).setNumber(totalOvertimeHours);
      sheet.getRangeByIndex(totalRow, 7).setNumber(totalOvertimeValue);
      sheet.getRangeByIndex(totalRow, 8).setNumber(totalDeficitHours);
      sheet.getRangeByIndex(totalRow, 9).setNumber(totalDeficitValue);
      sheet.getRangeByIndex(totalRow, 10).setNumber(totalUnpaidLeaveHours);
      sheet.getRangeByIndex(totalRow, 11).setNumber(totalUnpaidLeaveValue);
      sheet.getRangeByIndex(totalRow, 12).setNumber(totalFoodAllowance);
      sheet
          .getRangeByIndex(totalRow, 13)
          .setNumber(totalTransportationAllowance);
      sheet.getRangeByIndex(totalRow, 14).setNumber(totalOtherAllowance);
      sheet.getRangeByIndex(totalRow, 15).setNumber(totalInsuranceSalary);
      sheet.getRangeByIndex(totalRow, 16).setNumber(totalInsurance5);
      sheet.getRangeByIndex(totalRow, 17).setNumber(totalInsurance12);
      sheet.getRangeByIndex(totalRow, 18).setNumber(totalMonthlyAdditions);
      sheet.getRangeByIndex(totalRow, 19).setNumber(totalPenalties);
      sheet.getRangeByIndex(totalRow, 20).setNumber(totalMonthlyDeductions);
      sheet.getRangeByIndex(totalRow, 21).setNumber(totalGrossSalary);
      sheet.getRangeByIndex(totalRow, 22).setNumber(totalDeductions);
      sheet.getRangeByIndex(totalRow, 23).setNumber(totalNetEarnings);
      sheet.getRangeByIndex(totalRow, 24).setText('');

      for (int col = 1; col <= 24; col++) {
        sheet.getRangeByIndex(totalRow, col).cellStyle.bold = true;
      }
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final fileName = 'Payroll_${DateFormat('MMM_yyyy').format(month)}';
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<void> exportPayrollToPdf(
    List<PayrollReport> reports,
    DateTime month,
    CompanyProfile? profile, [
    String? languageCode,
  ]) async {
    final lang = languageCode ?? 'en';
    final fonts = await _loadPdfFonts(lang);
    final pw.Font? baseFont = fonts['base'];
    final pw.Font? boldFont = fonts['bold'];
    final List<pw.Font> fallbacks = List<pw.Font>.from(
      fonts['fallbacks'] ?? [],
    );

    final pdfTheme = pw.ThemeData.withFont(
      base: baseFont ?? pw.Font.helvetica(),
      bold: boldFont ?? baseFont ?? pw.Font.helveticaBold(),
      fontFallback: fallbacks,
    );
    final pdf = pw.Document(theme: pdfTheme);

    final headers = [
      'Emp',
      'Basic',
      'Sal/Day',
      'Days',
      'Hrs',
      'OT Hrs',
      'OT Val',
      'Def Hrs',
      'Def Val',
      'Food',
      'Trans.',
      'Other',
      'Ins.Sal',
      'Ins.5%',
      'Ins.12%',
      'Add.',
      'Penal.',
      'Other Ded.',
      'Gross',
      'Ded.',
      'Net',
      'Cur.',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginLeft: 10,
          marginRight: 10,
          marginTop: 20,
          marginBottom: 20,
        ),
        build: (pw.Context context) {
          pw.Widget? logoWidget;
          if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
            try {
              final image = pw.MemoryImage(base64Decode(profile.logoBase64!));
              logoWidget = pw.Image(image, width: 50, height: 50);
            } catch (e) {
              debugPrint('Could not decode pdf logo: $e');
            }
          }

          final List<List<String>> tableData = reports
              .map(
                (r) => [
                  r.employee.name,
                  r.basicSalary.toStringAsFixed(0),
                  r.salaryCalcByDay.toStringAsFixed(0),
                  r.daysWorked.toString(),
                  r.workingHours.toStringAsFixed(1),
                  r.overtimeHours.toStringAsFixed(1),
                  r.overtimeValue.toStringAsFixed(0),
                  r.attendanceDeficitHours.toStringAsFixed(1),
                  r.attendanceDeficit.toStringAsFixed(0),
                  r.foodAllowance.toStringAsFixed(0),
                  r.transportationAllowance.toStringAsFixed(0),
                  r.otherAllowance.toStringAsFixed(0),
                  r.hasInsurance ? r.insuranceSalary.toStringAsFixed(0) : '-',
                  r.hasInsurance ? r.insuranceEmployee.toStringAsFixed(0) : '-',
                  r.hasInsurance ? r.insuranceCompany.toStringAsFixed(0) : '-',
                  r.monthlyAdditions.toStringAsFixed(0),
                  r.monthlyPenalties.toStringAsFixed(0),
                  r.monthlyDeductions.toStringAsFixed(0),
                  r.incrementalSalary.toStringAsFixed(0),
                  r.decrementalSalary.toStringAsFixed(0),
                  r.netEarnings.toStringAsFixed(0),
                  r.currency,
                ],
              )
              .toList();

          if (reports.isNotEmpty) {
            final totalBasicSalary = reports.fold(
              0.0,
              (sum, r) => sum + r.basicSalary,
            );
            final totalSalaryCalcByDay = reports.fold(
              0.0,
              (sum, r) => sum + r.salaryCalcByDay,
            );
            final totalDaysWorked = reports.fold(
              0,
              (sum, r) => sum + r.daysWorked,
            );
            final totalWorkingHours = reports.fold(
              0.0,
              (sum, r) => sum + r.workingHours,
            );
            final totalOvertimeHours = reports.fold(
              0.0,
              (sum, r) => sum + r.overtimeHours,
            );
            final totalOvertimeValue = reports.fold(
              0.0,
              (sum, r) => sum + r.overtimeValue,
            );
            final totalDeficitHours = reports.fold(
              0.0,
              (sum, r) => sum + r.attendanceDeficitHours,
            );
            final totalDeficitValue = reports.fold(
              0.0,
              (sum, r) => sum + r.attendanceDeficit,
            );
            final totalMonthlyAdditions = reports.fold(
              0.0,
              (sum, r) => sum + r.monthlyAdditions,
            );
            final totalMonthlyDeductions = reports.fold(
              0.0,
              (sum, r) => sum + r.monthlyDeductions,
            );
            final totalFoodAllowance = reports.fold(
              0.0,
              (sum, r) => sum + r.foodAllowance,
            );
            final totalTransportationAllowance = reports.fold(
              0.0,
              (sum, r) => sum + r.transportationAllowance,
            );
            final totalOtherAllowance = reports.fold(
              0.0,
              (sum, r) => sum + r.otherAllowance,
            );
            final totalInsuranceSalary = reports
                .where((r) => r.hasInsurance)
                .fold(0.0, (sum, r) => sum + r.insuranceSalary);
            final totalInsurance5 = reports.fold(
              0.0,
              (sum, r) => sum + r.insuranceEmployee,
            );
            final totalInsurance12 = reports.fold(
              0.0,
              (sum, r) => sum + r.insuranceCompany,
            );
            final totalPenalties = reports.fold(
              0.0,
              (sum, r) => sum + r.monthlyPenalties,
            );
            final totalGrossSalary = reports.fold(
              0.0,
              (sum, r) => sum + r.incrementalSalary,
            );
            final totalDeductions = reports.fold(
              0.0,
              (sum, r) => sum + r.decrementalSalary,
            );
            final totalNetEarnings = reports.fold(
              0.0,
              (sum, r) => sum + r.netEarnings,
            );

            tableData.add([
              'Total',
              totalBasicSalary.toStringAsFixed(0),
              totalSalaryCalcByDay.toStringAsFixed(0),
              totalDaysWorked.toString(),
              totalWorkingHours.toStringAsFixed(1),
              totalOvertimeHours.toStringAsFixed(1),
              totalOvertimeValue.toStringAsFixed(0),
              totalDeficitHours.toStringAsFixed(1),
              totalDeficitValue.toStringAsFixed(0),
              totalFoodAllowance.toStringAsFixed(0),
              totalTransportationAllowance.toStringAsFixed(0),
              totalOtherAllowance.toStringAsFixed(0),
              totalInsuranceSalary.toStringAsFixed(0),
              totalInsurance5.toStringAsFixed(0),
              totalInsurance12.toStringAsFixed(0),
              totalMonthlyAdditions.toStringAsFixed(0),
              totalPenalties.toStringAsFixed(0),
              totalMonthlyDeductions.toStringAsFixed(0),
              totalGrossSalary.toStringAsFixed(0),
              totalDeductions.toStringAsFixed(0),
              totalNetEarnings.toStringAsFixed(0),
              '',
            ]);
          }

          return [
            // Company Header
            if (profile != null)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoWidget != null) ...[
                      logoWidget,
                      pw.SizedBox(width: 15),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          profile.name,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (profile.address.isNotEmpty)
                          pw.Text(
                            profile.address,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        if (profile.email != null && profile.email!.isNotEmpty)
                          pw.Text(
                            'Email: ${profile.email}',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        if (profile.phone != null && profile.phone!.isNotEmpty)
                          pw.Text(
                            'Phone: ${profile.phone}',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            pw.Header(
              level: 0,
              child: pw.Text(
                'Payroll Report - ${DateFormat('MMMM yyyy').format(month)}',
              ),
            ),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: tableData,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.center,
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'Payroll_${DateFormat('MM_yyyy').format(month)}.pdf';

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    } else {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    }
  }

  static Future<void> exportHistoryToPdf({
    required List<Map<String, dynamic>> records,
    required CompanyEmployee employee,
    required DateTime month,
    required CompanyProfile? profile,
    String? languageCode,
  }) async {
    final lang = languageCode ?? 'en';
    final fonts = await _loadPdfFonts(lang);
    final pw.Font? baseFont = fonts['base'];
    final pw.Font? boldFont = fonts['bold'];
    final List<pw.Font> fallbacks = List<pw.Font>.from(
      fonts['fallbacks'] ?? [],
    );

    final pdfTheme = pw.ThemeData.withFont(
      base: baseFont ?? pw.Font.helvetica(),
      bold: boldFont ?? baseFont ?? pw.Font.helveticaBold(),
      fontFallback: fallbacks,
    );
    final pdf = pw.Document(theme: pdfTheme);

    final headers = [
      'Date',
      'Shift',
      'Clock Time',
      'Attendance',
      'Duty',
      'Delay',
      'Early Exit',
      'Deficit',
      'Extra Time',
      'Overtime',
      'Penalty',
    ];

    String formatMins(int mins) {
      if (mins == 0) return '0m';
      final h = mins ~/ 60;
      final m = mins % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    pdf.addPage(
      pw.MultiPage(
        maxPages: 1,
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 16,
          marginRight: 16,
          marginTop: 14,
          marginBottom: 14,
        ),
        build: (pw.Context context) {
          pw.Widget? logoWidget;
          if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
            try {
              final image = pw.MemoryImage(base64Decode(profile.logoBase64!));
              logoWidget = pw.Image(image, width: 42, height: 42);
            } catch (e) {
              debugPrint('Could not decode pdf logo: $e');
            }
          }

          return [
            // Top Header: Company Info (Left) & Report/Employee Info (Right)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Company Info
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoWidget != null) ...[
                      logoWidget,
                      pw.SizedBox(width: 10),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          profile?.name ?? 'Company',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (profile != null && profile.address.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            profile.address,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Right: Attendance History Report Details
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Attendance History Report',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Employee: ${employee.name}${employee.position.isNotEmpty ? " (${employee.position})" : ""}',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Month: ${DateFormat('MMMM yyyy').format(month)}',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Export Date: ${DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.8, color: PdfColors.grey400),
            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              headers: headers,
              data: records.map((r) {
                final date = r['date'] as DateTime;
                final shiftName = (r['shiftName'] as String?) ?? '';
                final shiftWorkHours = (r['shiftWorkHours'] as String?) ?? '';
                final shiftCell = shiftName.isNotEmpty
                    ? (shiftWorkHours.isNotEmpty
                          ? '$shiftName\n($shiftWorkHours)'
                          : shiftName)
                    : '-';

                return [
                  DateFormat('dd MMM').format(date),
                  shiftCell,
                  r['clockTime'].toString().replaceAll('\n', ' / '),
                  formatMins(r['attendance'] as int),
                  formatMins(r['duty'] as int),
                  formatMins(r['delay'] as int),
                  formatMins(r['earlyExit'] as int),
                  formatMins((r['deficit'] ?? 0) as int),
                  formatMins(r['extraTime'] as int),
                  formatMins(r['overtime'] as int),
                  (r['penalty'] as double) > 0
                      ? '${NumberFormat('#,##0').format(r['penalty'] as double)} IQD'
                      : '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8.5,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 2.5,
                vertical: 2.8,
              ),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FlexColumnWidth(1.1), // Date
                1: const pw.FlexColumnWidth(1.3), // Shift
                2: const pw.FlexColumnWidth(1.5), // Clock Time
                3: const pw.FlexColumnWidth(1.1), // Attendance
                4: const pw.FlexColumnWidth(1.0), // Duty
                5: const pw.FlexColumnWidth(0.9), // Delay
                6: const pw.FlexColumnWidth(1.0), // Early Exit
                7: const pw.FlexColumnWidth(1.0), // Deficit
                8: const pw.FlexColumnWidth(1.1), // Extra Time
                9: const pw.FlexColumnWidth(1.1), // Overtime
                10: const pw.FlexColumnWidth(1.2), // Penalty
              },
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName =
        'Attendance_${employee.name.replaceAll(" ", "_")}_${DateFormat('MM_yyyy').format(month)}.pdf';

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    } else {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    }
  }

  static Future<void> exportDailyReportToPdf({
    required List<Map<String, dynamic>> records,
    required DateTime date,
    required CompanyProfile? profile,
    String? languageCode,
  }) async {
    final lang = languageCode ?? 'en';
    final fonts = await _loadPdfFonts(lang);
    final pw.Font? baseFont = fonts['base'];
    final pw.Font? boldFont = fonts['bold'];
    final List<pw.Font> fallbacks = List<pw.Font>.from(
      fonts['fallbacks'] ?? [],
    );

    final pdfTheme = pw.ThemeData.withFont(
      base: baseFont ?? pw.Font.helvetica(),
      bold: boldFont ?? baseFont ?? pw.Font.helveticaBold(),
      fontFallback: fallbacks,
    );
    final pdf = pw.Document(theme: pdfTheme);

    final headers = [
      'Employee',
      'Branch/Structure',
      'Shift',
      'Group',
      'Clock Time',
      'Attendance',
      'Duty',
      'Delay',
      'Early Exit',
      'Overtime',
      'Status',
    ];

    String formatMins(int mins) {
      if (mins <= 0) return '-';
      final h = mins ~/ 60;
      final m = mins % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    final dateFormatted = DateFormat('EEEE, MMMM d, yyyy').format(date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginLeft: 16,
          marginRight: 16,
          marginTop: 14,
          marginBottom: 14,
        ),
        build: (pw.Context context) {
          pw.Widget? logoWidget;
          if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
            try {
              final image = pw.MemoryImage(base64Decode(profile.logoBase64!));
              logoWidget = pw.Image(image, width: 40, height: 40);
            } catch (e) {
              debugPrint('Could not decode pdf logo: $e');
            }
          }

          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoWidget != null) ...[
                      logoWidget,
                      pw.SizedBox(width: 10),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          profile?.name ?? 'Company',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (profile != null && profile.address.isNotEmpty)
                          pw.Text(
                            profile.address,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'DAILY ATTENDANCE REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      dateFormatted,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.8, color: PdfColors.grey400),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: records.map((r) {
                final emp = r['employee'] as CompanyEmployee;
                return [
                  '${emp.name}\n(${emp.position})',
                  r['structureName']?.toString() ?? '-',
                  r['shiftName']?.toString() ?? '-',
                  r['groupName']?.toString() ?? '-',
                  r['clockTime']?.toString().replaceAll('\n', ' / ') ?? '-',
                  formatMins(r['attendance'] as int? ?? 0),
                  formatMins(r['duty'] as int? ?? 0),
                  formatMins(r['delay'] as int? ?? 0),
                  formatMins(r['earlyExit'] as int? ?? 0),
                  formatMins(r['overtime'] as int? ?? 0),
                  r['status']?.toString() ?? '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3.5,
              ),
              cellAlignment: pw.Alignment.center,
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName =
        'Daily_Report_${DateFormat('yyyy_MM_dd').format(date)}.pdf';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<void> exportDailyReportToExcel({
    required List<Map<String, dynamic>> records,
    required DateTime date,
    required CompanyProfile? profile,
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Daily ${DateFormat('yyyy_MM_dd').format(date)}';

    int row = 1;
    if (profile != null) {
      sheet.getRangeByIndex(row, 1).setText(profile.name);
      sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(row, 1).cellStyle.fontSize = 13;
      row++;
    }

    sheet
        .getRangeByIndex(row, 1)
        .setText(
          'Daily Attendance Report - ${DateFormat('yyyy-MM-dd').format(date)}',
        );
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 1).cellStyle.fontSize = 11;
    row += 2;

    final headers = [
      'Employee Name',
      'Position',
      'Structure',
      'Shift',
      'Group',
      'Clock Time',
      'Attendance (Minutes)',
      'Duty (Minutes)',
      'Delay (Minutes)',
      'Early Exit (Minutes)',
      'Overtime (Minutes)',
      'Status',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(row, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
    }
    row++;

    for (var r in records) {
      final emp = r['employee'] as CompanyEmployee;
      sheet.getRangeByIndex(row, 1).setText(emp.name);
      sheet.getRangeByIndex(row, 2).setText(emp.position);
      sheet
          .getRangeByIndex(row, 3)
          .setText(r['structureName']?.toString() ?? '-');
      sheet.getRangeByIndex(row, 4).setText(r['shiftName']?.toString() ?? '-');
      sheet.getRangeByIndex(row, 5).setText(r['groupName']?.toString() ?? '-');
      sheet
          .getRangeByIndex(row, 6)
          .setText(r['clockTime']?.toString().replaceAll('\n', ' / ') ?? '-');
      sheet
          .getRangeByIndex(row, 7)
          .setNumber((r['attendance'] as int? ?? 0).toDouble());
      sheet
          .getRangeByIndex(row, 8)
          .setNumber((r['duty'] as int? ?? 0).toDouble());
      sheet
          .getRangeByIndex(row, 9)
          .setNumber((r['delay'] as int? ?? 0).toDouble());
      sheet
          .getRangeByIndex(row, 10)
          .setNumber((r['earlyExit'] as int? ?? 0).toDouble());
      sheet
          .getRangeByIndex(row, 11)
          .setNumber((r['overtime'] as int? ?? 0).toDouble());
      sheet.getRangeByIndex(row, 12).setText(r['status']?.toString() ?? '-');
      row++;
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final fileName =
        'Daily_Report_${DateFormat('yyyy_MM_dd').format(date)}.xlsx';
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<Map<String, dynamic>> _loadPdfFonts([String? languageCode]) async {
    pw.Font? baseFont;
    pw.Font? boldFont;
    final List<pw.Font> fallbacks = [];
    final bool isKurdish = languageCode == 'ku';

    try {
      if (isKurdish) {
        // Authentic Kurdish typography: UniQaidar as primary base & bold font
        final fontDataUni = await rootBundle.load(
          'assets/fonts/UniQAIDAR_NewsHeadLine_025.ttf',
        );
        final uniFont = pw.Font.ttf(fontDataUni);
        baseFont = uniFont;
        boldFont = uniFont;

        // Classic Kurdish secondary fallback: Speda
        try {
          final fontDataSpeda = await rootBundle.load(
            'assets/fonts/Speda.ttf',
          );
          fallbacks.add(pw.Font.ttf(fontDataSpeda));
        } catch (_) {}

        // Fallbacks for Arabic Presentation Forms and Latin characters
        final fontDataArabic = await rootBundle.load(
          'assets/fonts/NotoSansArabic-Regular.ttf',
        );
        final fontDataArabicBold = await rootBundle.load(
          'assets/fonts/NotoSansArabic-Bold.ttf',
        );
        fallbacks.add(pw.Font.ttf(fontDataArabic));
        fallbacks.add(pw.Font.ttf(fontDataArabicBold));

        final fontDataLatin = await rootBundle.load(
          'assets/fonts/NotoSans-Regular.ttf',
        );
        final fontDataLatinBold = await rootBundle.load(
          'assets/fonts/NotoSans-Bold.ttf',
        );
        fallbacks.add(pw.Font.ttf(fontDataLatin));
        fallbacks.add(pw.Font.ttf(fontDataLatinBold));
      } else {
        final fontDataArabic = await rootBundle.load(
          'assets/fonts/NotoSansArabic-Regular.ttf',
        );
        final fontDataArabicBold = await rootBundle.load(
          'assets/fonts/NotoSansArabic-Bold.ttf',
        );
        baseFont = pw.Font.ttf(fontDataArabic);
        boldFont = pw.Font.ttf(fontDataArabicBold);

        try {
          final fontDataUni = await rootBundle.load(
            'assets/fonts/UniQAIDAR_NewsHeadLine_025.ttf',
          );
          fallbacks.add(pw.Font.ttf(fontDataUni));
        } catch (_) {}

        try {
          final fontDataSpeda = await rootBundle.load(
            'assets/fonts/Speda.ttf',
          );
          fallbacks.add(pw.Font.ttf(fontDataSpeda));
        } catch (_) {}

        final fontDataLatin = await rootBundle.load(
          'assets/fonts/NotoSans-Regular.ttf',
        );
        final fontDataLatinBold = await rootBundle.load(
          'assets/fonts/NotoSans-Bold.ttf',
        );
        fallbacks.add(pw.Font.ttf(fontDataLatin));
        fallbacks.add(pw.Font.ttf(fontDataLatinBold));
      }
    } catch (e) {
      debugPrint(
        'Could not load custom fonts for PDF: $e',
      );
      try {
        final fontDataUni = await rootBundle.load(
          'assets/fonts/UniQAIDAR_NewsHeadLine_025.ttf',
        );
        final uniFont = pw.Font.ttf(fontDataUni);
        baseFont ??= uniFont;
        boldFont ??= uniFont;
      } catch (_) {}
    }
    return {'base': baseFont, 'bold': boldFont, 'fallbacks': fallbacks};
  }

  static Future<void> exportSinglePayslipToPdf({
    required PayrollReport report,
    required DateTime month,
    required CompanyProfile? profile,
    String? structureName,
    String? groupName,
    String? languageCode,
  }) async {
    final lang = languageCode ?? 'en';
    final bool isRtl = lang == 'ar' || lang == 'ku';
    final fonts = await _loadPdfFonts(lang);
    final pw.Font? baseFont = fonts['base'];
    final pw.Font? boldFont = fonts['bold'];
    final List<pw.Font> fallbacks = List<pw.Font>.from(
      fonts['fallbacks'] ?? [],
    );

    final pdfTheme = pw.ThemeData.withFont(
      base: baseFont ?? pw.Font.helvetica(),
      bold: boldFont ?? baseFont ?? pw.Font.helveticaBold(),
      fontFallback: fallbacks,
    );
    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pdfTheme,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: _buildPayslipPdfPage(
              report: report,
              month: month,
              profile: profile,
              structureName: structureName,
              groupName: groupName,
              languageCode: lang,
              baseFont: baseFont,
              boldFont: boldFont,
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final cleanName = report.employee.name.trim().replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    final fileName =
        'Payslip_${cleanName}_${DateFormat('MM_yyyy').format(month)}.pdf';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<void> exportAllPayslipsToPdf({
    required List<PayrollReport> reports,
    required DateTime month,
    required CompanyProfile? profile,
    required List<OrgStructure> structures,
    required List<EmployeeGroup> groups,
    String? languageCode,
  }) async {
    final lang = languageCode ?? 'en';
    final bool isRtl = lang == 'ar' || lang == 'ku';
    final fonts = await _loadPdfFonts(lang);
    final pw.Font? baseFont = fonts['base'];
    final pw.Font? boldFont = fonts['bold'];
    final List<pw.Font> fallbacks = List<pw.Font>.from(
      fonts['fallbacks'] ?? [],
    );

    final pdfTheme = pw.ThemeData.withFont(
      base: baseFont ?? pw.Font.helvetica(),
      bold: boldFont ?? baseFont ?? pw.Font.helveticaBold(),
      fontFallback: fallbacks,
    );
    final pdf = pw.Document(theme: pdfTheme);

    for (final report in reports) {
      final struct = structures
          .where((s) => s.id == report.employee.structureId)
          .firstOrNull;
      final group = groups
          .where((g) => g.id == report.employee.groupId)
          .firstOrNull;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          theme: pdfTheme,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: isRtl
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              child: _buildPayslipPdfPage(
                report: report,
                month: month,
                profile: profile,
                structureName: struct?.name,
                groupName: group?.name,
                languageCode: lang,
                baseFont: baseFont,
                boldFont: boldFont,
              ),
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    final fileName = 'All_Payslips_${DateFormat('MMM_yyyy').format(month)}.pdf';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static pw.Widget _buildPayslipPdfPage({
    required PayrollReport report,
    required DateTime month,
    required CompanyProfile? profile,
    String? structureName,
    String? groupName,
    String? languageCode,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) {
    final lang = languageCode ?? 'en';
    final bool isRtl = lang == 'ar' || lang == 'ku';
    final dict =
        TranslationKeys.translations[lang] ??
        TranslationKeys.translations['en']!;
    String t(String key, [String fallback = '']) {
      return dict[key] ?? TranslationKeys.translations['en']?[key] ?? fallback;
    }

    final monthName = t(
      'month_${month.month}',
      DateFormat('MMMM').format(month),
    );
    final monthStr = '$monthName ${month.year}';

    String formatPdfAmount(double amount, String currency) {
      if (currency == 'USD') {
        return '\$${NumberFormat('#,##0.00').format(amount)}';
      } else {
        return '${NumberFormat('#,##0').format(amount)} $currency';
      }
    }

    pw.Widget? logoWidget;
    if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
      try {
        final image = pw.MemoryImage(base64Decode(profile.logoBase64!));
        logoWidget = pw.Image(image, width: 44, height: 44);
      } catch (e) {
        debugPrint('Could not decode pdf logo: $e');
      }
    }

    bool hasArabicOrKurdish(String text) {
      for (final rune in text.runes) {
        if ((rune >= 0x0600 && rune <= 0x06FF) ||
            (rune >= 0x0750 && rune <= 0x077F) ||
            (rune >= 0x08A0 && rune <= 0x08FF) ||
            (rune >= 0xFB50 && rune <= 0xFDFF) ||
            (rune >= 0xFE70 && rune <= 0xFEFF)) {
          return true;
        }
      }
      return false;
    }

    String toVisualRtl(String input) {
      if (input.isEmpty) return input;
      final b = bidi.BidiString.fromLogical(input);
      final buffer = StringBuffer();
      for (final p in b.paragraphs) {
        final endsWithNewLine = p.separator == 10;
        final endIndex = p.bidiText.length - (endsWithNewLine ? 1 : 0);
        buffer.write(String.fromCharCodes(p.bidiText, 0, endIndex));
        if (endsWithNewLine) buffer.writeln();
      }
      return buffer.toString();
    }

    pw.Widget smartText(
      String text, {
      pw.TextStyle? style,
      pw.TextAlign? textAlign,
      pw.TextDirection? textDirection,
      int? maxLines,
      pw.TextOverflow? overflow,
    }) {
      if (text.isEmpty) return pw.SizedBox();

      final bool isExplicitLtr = textDirection == pw.TextDirection.ltr;
      if (isExplicitLtr) {
        return pw.Text(
          text,
          style: style,
          textAlign: textAlign ?? pw.TextAlign.left,
          textDirection: pw.TextDirection.ltr,
          maxLines: maxLines,
          overflow: overflow,
        );
      }

      if (hasArabicOrKurdish(text)) {
        final visualText = toVisualRtl(text);
        return pw.Text(
          visualText,
          style: style,
          textAlign:
              textAlign ?? (isRtl ? pw.TextAlign.right : pw.TextAlign.left),
          textDirection: pw.TextDirection.ltr,
          maxLines: maxLines,
          overflow: overflow,
        );
      }

      return pw.Text(
        text,
        style: style,
        textAlign:
            textAlign ?? (isRtl ? pw.TextAlign.right : pw.TextAlign.left),
        textDirection: pw.TextDirection.ltr,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    pw.Widget buildTableRow(
      String label,
      String value, {
      bool isBold = false,
      PdfColor? color,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            smartText(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: isBold ? PdfColors.black : PdfColors.grey800,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            smartText(
              value,
              textDirection: pw.TextDirection.ltr,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: color ?? (isBold ? PdfColors.black : PdfColors.grey900),
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Company & Document Header
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoWidget != null) ...[logoWidget, pw.SizedBox(width: 10)],
                pw.Column(
                  crossAxisAlignment: isRtl
                      ? pw.CrossAxisAlignment.end
                      : pw.CrossAxisAlignment.start,
                  children: [
                    smartText(
                      profile?.name.isNotEmpty == true
                          ? profile!.name
                          : t('app_title', 'COMPANY NAME'),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F172A'),
                      ),
                    ),
                    if (profile?.address.isNotEmpty == true)
                      smartText(
                        profile!.address,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    if (profile?.email != null && profile!.email!.isNotEmpty)
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          smartText(
                            '${t('email', 'Email')}: ',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                          smartText(
                            profile.email!,
                            textDirection: pw.TextDirection.ltr,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    if (profile?.phone != null && profile!.phone!.isNotEmpty)
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          smartText(
                            '${t('phone', 'Phone')}: ',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                          smartText(
                            profile.phone!,
                            textDirection: pw.TextDirection.ltr,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(
                  color: PdfColor.fromHex('#CBD5E1'),
                  width: 1,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: isRtl
                    ? pw.CrossAxisAlignment.start
                    : pw.CrossAxisAlignment.end,
                children: [
                  smartText(
                    t('salary_payslip', 'PAYSLIP'),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1E3A8A'),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      smartText(
                        '${t('pay_period', 'Period')}: ',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      smartText(
                        monthStr,
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      smartText(
                        '${t('payment_date', 'Date')}: ',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey600,
                        ),
                      ),
                      smartText(
                        DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        textDirection: pw.TextDirection.ltr,
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 12),
        pw.Divider(thickness: 1, color: PdfColor.fromHex('#E2E8F0')),
        pw.SizedBox(height: 8),

        // Employee Info Box
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFC'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    smartText(
                      t('employee_details', 'EMPLOYEE DETAILS'),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#64748B'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 80,
                          child: smartText(
                            '${t('name_label', 'Name')}:',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: smartText(
                            report.employee.name,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 80,
                          child: smartText(
                            '${t('id_label', 'Employee ID')}:',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: smartText(
                            report.employee.id,
                            textDirection: pw.TextDirection.ltr,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 80,
                          child: smartText(
                            '${t('position', 'Position')}:',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: smartText(
                            report.employee.position.isNotEmpty
                                ? report.employee.position
                                : '-',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 80,
                          child: smartText(
                            '${t('department', 'Department')}:',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: smartText(
                            structureName ?? '-',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    smartText(
                      t('attendance_summary', 'ATTENDANCE & SUMMARY'),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#64748B'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 85,
                          child: smartText(
                            '${t('group', 'Group')}:',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: smartText(
                            groupName ?? '-',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 85,
                          child: smartText(
                            '${t('currency_label', 'Currency')}:',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: smartText(
                            report.currency,
                            textDirection: pw.TextDirection.ltr,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 85,
                          child: smartText(
                            '${t('days_worked', 'Days Worked')}:',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              smartText(
                                '${report.daysWorked} ',
                                textDirection: pw.TextDirection.ltr,
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              smartText(
                                t('unit_days', 'days'),
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 85,
                          child: smartText(
                            '${t('working_hrs', 'Hours')}:',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: isRtl
                                ? pw.CrossAxisAlignment.end
                                : pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  smartText(
                                    '${report.workingHours.toStringAsFixed(1)} ',
                                    textDirection: pw.TextDirection.ltr,
                                    style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  smartText(
                                    t('unit_hrs', 'h'),
                                    style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (report.overtimeHours > 0 ||
                                  report.attendanceDeficitHours > 0) ...[
                                pw.SizedBox(height: 1),
                                pw.Row(
                                  mainAxisSize: pw.MainAxisSize.min,
                                  children: [
                                    smartText(
                                      '${t('overtime', 'OT')}: ',
                                      style: const pw.TextStyle(
                                        fontSize: 7.5,
                                        color: PdfColors.grey600,
                                      ),
                                    ),
                                    smartText(
                                      '${report.overtimeHours.toStringAsFixed(1)}h',
                                      textDirection: pw.TextDirection.ltr,
                                      style: const pw.TextStyle(
                                        fontSize: 7.5,
                                        color: PdfColors.grey600,
                                      ),
                                    ),
                                    smartText(
                                      '  |  ',
                                      style: const pw.TextStyle(
                                        fontSize: 7.5,
                                        color: PdfColors.grey400,
                                      ),
                                    ),
                                    smartText(
                                      '${t('deficit', 'Def')}: ',
                                      style: const pw.TextStyle(
                                        fontSize: 7.5,
                                        color: PdfColors.grey600,
                                      ),
                                    ),
                                    smartText(
                                      '${report.attendanceDeficitHours.toStringAsFixed(1)}h',
                                      textDirection: pw.TextDirection.ltr,
                                      style: const pw.TextStyle(
                                        fontSize: 7.5,
                                        color: PdfColors.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 12),

        // Earnings and Deductions Columns
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // EARNINGS
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F1F5F9'),
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(7),
                          topRight: pw.Radius.circular(7),
                        ),
                      ),
                      child: smartText(
                        t('earnings', 'EARNINGS & ADDITIONS'),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        children: [
                          buildTableRow(
                            t(
                              'base_salary_calc_by_day',
                              'Base Salary / Calc by Day',
                            ),
                            formatPdfAmount(
                              report.salaryCalcByDay > 0
                                  ? report.salaryCalcByDay
                                  : report.basicSalary,
                              report.currency,
                            ),
                          ),
                          buildTableRow(
                            t('overtime_pay', 'Overtime Pay'),
                            report.overtimeValue > 0
                                ? formatPdfAmount(
                                    report.overtimeValue,
                                    report.currency,
                                  )
                                : '-',
                          ),
                          buildTableRow(
                            t('food_allowance', 'Food Allowance'),
                            report.foodAllowance > 0
                                ? formatPdfAmount(
                                    report.foodAllowance,
                                    report.currency,
                                  )
                                : '-',
                          ),
                          buildTableRow(
                            t(
                              'transportation_allowance',
                              'Transportation Allowance',
                            ),
                            report.transportationAllowance > 0
                                ? formatPdfAmount(
                                    report.transportationAllowance,
                                    report.currency,
                                  )
                                : '-',
                          ),
                          buildTableRow(
                            t('other_allowance', 'Other Allowance'),
                            report.otherAllowance > 0
                                ? formatPdfAmount(
                                    report.otherAllowance,
                                    report.currency,
                                  )
                                : '-',
                          ),
                          buildTableRow(
                            t(
                              'monthly_additions_bonuses',
                              'Monthly Additions / Bonuses',
                            ),
                            report.monthlyAdditions > 0
                                ? formatPdfAmount(
                                    report.monthlyAdditions,
                                    report.currency,
                                  )
                                : '-',
                          ),
                          pw.SizedBox(height: 6),
                          pw.Divider(
                            thickness: 0.8,
                            color: PdfColor.fromHex('#E2E8F0'),
                          ),
                          pw.SizedBox(height: 4),
                          buildTableRow(
                            t('total_gross_earnings', 'TOTAL GROSS EARNINGS'),
                            formatPdfAmount(
                              report.incrementalSalary,
                              report.currency,
                            ),
                            isBold: true,
                            color: PdfColor.fromHex('#059669'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 12),

            // DEDUCTIONS
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F1F5F9'),
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(7),
                          topRight: pw.Radius.circular(7),
                        ),
                      ),
                      child: smartText(
                        t('deductions_title', 'DEDUCTIONS'),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        children: [
                          buildTableRow(
                            t(
                              'attendance_deficit_deduction',
                              'Attendance Deficit',
                            ),
                            report.attendanceDeficit > 0
                                ? '-${formatPdfAmount(report.attendanceDeficit, report.currency)}'
                                : '-',
                          ),
                          buildTableRow(
                            t(
                              'penalties_delay_early_exit',
                              'Penalties (Delay/Early Exit)',
                            ),
                            report.monthlyPenalties > 0
                                ? '-${formatPdfAmount(report.monthlyPenalties, report.currency)}'
                                : '-',
                          ),
                          buildTableRow(
                            t(
                              'loans_other_deductions',
                              'Loans / Other Deductions',
                            ),
                            report.monthlyDeductions > 0
                                ? '-${formatPdfAmount(report.monthlyDeductions, report.currency)}'
                                : '-',
                          ),
                          buildTableRow(
                            t(
                              'social_insurance_5_employee',
                              'Social Insurance (5% Employee)',
                            ),
                            report.hasInsurance
                                ? '-${formatPdfAmount(report.insuranceEmployee, report.currency)}'
                                : '-',
                            color: report.hasInsurance
                                ? PdfColor.fromHex('#DC2626')
                                : null,
                          ),
                          if (report.unpaidLeaveDeduction > 0)
                            buildTableRow(
                              '${t('unpaid_leave_deduction', 'Unpaid Leave Deduction')} (${report.unpaidLeaveHours.toStringAsFixed(1)}${t('unit_hrs', 'h')})',
                              '-${formatPdfAmount(report.unpaidLeaveDeduction, report.currency)}',
                              color: PdfColor.fromHex('#DC2626'),
                            ),
                          pw.SizedBox(height: 6),
                          pw.Divider(
                            thickness: 0.8,
                            color: PdfColor.fromHex('#E2E8F0'),
                          ),
                          pw.SizedBox(height: 4),
                          buildTableRow(
                            t('total_deductions', 'TOTAL DEDUCTIONS'),
                            '-${formatPdfAmount(report.decrementalSalary, report.currency)}',
                            isBold: true,
                            color: PdfColor.fromHex('#DC2626'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Social Insurance Section (if active)
        if (report.hasInsurance) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F0F9FF'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(
                color: PdfColor.fromHex('#BAE6FD'),
                width: 1,
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    smartText(
                      t(
                        'social_insurance_box_title',
                        'SOCIAL INSURANCE (SOCIAL SECURITY)',
                      ),
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0369A1'),
                      ),
                    ),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        smartText(
                          '${t('ins_base_label', 'Ins. Base')}: ',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0369A1'),
                          ),
                        ),
                        smartText(
                          formatPdfAmount(
                            report.insuranceSalary,
                            report.currency,
                          ),
                          textDirection: pw.TextDirection.ltr,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0369A1'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        smartText(
                          '• ${t('ins_emp_contrib_5_desc', 'Employee Contribution (5%): Deducted from salary')}: ',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey800,
                          ),
                        ),
                        smartText(
                          '-${formatPdfAmount(report.insuranceEmployee, report.currency)}',
                          textDirection: pw.TextDirection.ltr,
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        smartText(
                          '• ${t('ins_comp_contrib_12_desc', 'Company Contribution (12%): Employer Paid (Informational)')}: ',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColor.fromHex('#0284C7'),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        smartText(
                          formatPdfAmount(
                            report.insuranceCompany,
                            report.currency,
                          ),
                          textDirection: pw.TextDirection.ltr,
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColor.fromHex('#0284C7'),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        pw.SizedBox(height: 12),

        // Net Payable Banner
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#ECFDF5'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(
              color: PdfColor.fromHex('#10B981'),
              width: 1.2,
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  smartText(
                    t('net_payable_salary', 'NET PAYABLE SALARY'),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#047857'),
                    ),
                  ),
                  smartText(
                    t(
                      'gross_minus_deductions_desc',
                      'Gross Earnings - Total Deductions',
                    ),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              smartText(
                formatPdfAmount(report.netEarnings, report.currency),
                textDirection: pw.TextDirection.ltr,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#065F46'),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 24),

        // Signatures
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                smartText(
                  t('employee_signature', 'Employee Signature'),
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 3),
                smartText(
                  report.employee.name,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                smartText(
                  t('official_stamp_title', 'Authorized HR / Management Stamp'),
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Container(width: 160, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 3),
                smartText(
                  profile?.name.isNotEmpty == true
                      ? profile!.name
                      : t('administration_title', 'Administration'),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),

        pw.Spacer(),

        // Footer note
        pw.Center(
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              smartText(
                '${t('computer_generated_note', 'This is an official computer-generated payslip.')} - ',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey500,
                ),
              ),
              smartText(
                DateFormat('yyyy-MM-dd - hh:mm a').format(DateTime.now()),
                textDirection: pw.TextDirection.ltr,
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> exportPeriodicReportToExcel({
    required List<PeriodicReportRow> rows,
    required DateTime startDate,
    required DateTime endDate,
    required CompanyProfile? profile,
    String? languageCode,
  }) async {
    final lang = languageCode ?? 'en';
    final bool isRtl = lang == 'ar' || lang == 'ku';
    final dict =
        TranslationKeys.translations[lang] ??
        TranslationKeys.translations['en']!;
    String t(String key, [String fallback = '']) => dict[key] ?? fallback;

    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = t('periodic_report', 'Periodic Report');
    if (isRtl) {
      sheet.isRightToLeft = true;
    }

    int row = 1;
    if (profile != null && profile.name.isNotEmpty) {
      sheet.getRangeByIndex(row, 1).setText(profile.name);
      sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(row, 1).cellStyle.fontSize = 14;
      row++;
    }

    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);
    final reportTitle = t(
      'periodic_report_title',
      'Periodic Attendance & Deficit Report',
    );
    final toWord = t('date_to', isRtl ? (lang == 'ku' ? 'بۆ' : 'إلى') : 'to');
    sheet.getRangeByIndex(row, 1).setText('$reportTitle: $startStr $toWord $endStr');
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 1).cellStyle.fontSize = 11;
    row += 2;

    final countStr = t('count_col', lang == 'ar' ? 'العدد' : lang == 'ku' ? 'ژمارە' : 'Count');
    final headers = [
      t('id_label', 'ID'),
      t('employee_col', 'Employee Name'),
      t('dept_col', 'Department'),
      t('group_policy_col', 'Group Policy'),
      t('req_hrs_col', 'Required (Hrs)'),
      t('actual_hrs_col', 'Actual (Hrs)'),
      t('deficit_shortage_col', 'Deficit (Hrs)'),
      t('delay_m_col', 'Delay (Mins)'),
      '${t('delay_col', 'Delay')} ($countStr)',
      t('early_exit_m_col', 'Early Exit (Mins)'),
      '${t('early_exit_col', 'Early Exit')} ($countStr)',
      t('penalties_col', 'Penalties'),
      t('overtime_hrs_col', 'Overtime (Hrs)'),
      t('daily_leaves_col', 'Daily Leaves'),
      t('hourly_perm_col', 'Hourly Leaves (Hrs)'),
      t('remaining_annual_col', 'Remaining Annual (Days)'),
      t('absences_col', 'Absences'),
      t('present_days_col', isRtl ? (lang == 'ku' ? 'ڕۆژانی ئامادەبوون' : 'أيام الحضور') : 'Present Days'),
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(row, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#1E293B';
      cell.cellStyle.fontColor = '#FFFFFF';
    }
    row++;

    double totalReq = 0;
    double totalAct = 0;
    double totalDef = 0;
    int totalDelM = 0;
    int totalDelC = 0;
    int totalEarM = 0;
    int totalEarC = 0;
    double totalPen = 0;
    double totalOt = 0;
    int totalDailyL = 0;
    double totalHourL = 0;
    int totalAbs = 0;
    int totalPres = 0;

    for (var r in rows) {
      sheet.getRangeByIndex(row, 1).setText(r.employee.id);
      sheet.getRangeByIndex(row, 2).setText(r.employee.name);
      sheet.getRangeByIndex(row, 3).setText(r.structureName);
      sheet.getRangeByIndex(row, 4).setText(r.groupName);
      sheet
          .getRangeByIndex(row, 5)
          .setNumber(double.parse(r.requiredHours.toStringAsFixed(1)));
      sheet
          .getRangeByIndex(row, 6)
          .setNumber(double.parse(r.actualWorkedHours.toStringAsFixed(1)));
      sheet
          .getRangeByIndex(row, 7)
          .setNumber(double.parse(r.deficitHours.toStringAsFixed(1)));
      sheet.getRangeByIndex(row, 8).setNumber(r.delayMinutes.toDouble());
      sheet.getRangeByIndex(row, 9).setNumber(r.delayCount.toDouble());
      sheet.getRangeByIndex(row, 10).setNumber(r.earlyExitMinutes.toDouble());
      sheet.getRangeByIndex(row, 11).setNumber(r.earlyExitCount.toDouble());
      sheet
          .getRangeByIndex(row, 12)
          .setNumber(double.parse(r.penaltyDeductions.toStringAsFixed(1)));
      sheet
          .getRangeByIndex(row, 13)
          .setNumber(double.parse(r.totalOvertimeHours.toStringAsFixed(1)));
      sheet.getRangeByIndex(row, 14).setNumber(r.dailyLeaveDays.toDouble());
      sheet
          .getRangeByIndex(row, 15)
          .setNumber(double.parse(r.hourlyLeaveHours.toStringAsFixed(1)));
      sheet
          .getRangeByIndex(row, 16)
          .setNumber(double.parse(r.remainingAnnualDays.toStringAsFixed(1)));
      sheet.getRangeByIndex(row, 17).setNumber(r.absentDays.toDouble());
      sheet.getRangeByIndex(row, 18).setNumber(r.presentDays.toDouble());

      totalReq += r.requiredHours;
      totalAct += r.actualWorkedHours;
      totalDef += r.deficitHours;
      totalDelM += r.delayMinutes;
      totalDelC += r.delayCount;
      totalEarM += r.earlyExitMinutes;
      totalEarC += r.earlyExitCount;
      totalPen += r.penaltyDeductions;
      totalOt += r.totalOvertimeHours;
      totalDailyL += r.dailyLeaveDays;
      totalHourL += r.hourlyLeaveHours;
      totalAbs += r.absentDays;
      totalPres += r.presentDays;

      row++;
    }

    // Totals row
    sheet.getRangeByIndex(row, 1).setText(t('total', 'TOTAL'));
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    sheet
        .getRangeByIndex(row, 5)
        .setNumber(double.parse(totalReq.toStringAsFixed(1)));
    sheet.getRangeByIndex(row, 5).cellStyle.bold = true;
    sheet
        .getRangeByIndex(row, 6)
        .setNumber(double.parse(totalAct.toStringAsFixed(1)));
    sheet.getRangeByIndex(row, 6).cellStyle.bold = true;
    sheet
        .getRangeByIndex(row, 7)
        .setNumber(double.parse(totalDef.toStringAsFixed(1)));
    sheet.getRangeByIndex(row, 7).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 8).setNumber(totalDelM.toDouble());
    sheet.getRangeByIndex(row, 9).setNumber(totalDelC.toDouble());
    sheet.getRangeByIndex(row, 10).setNumber(totalEarM.toDouble());
    sheet.getRangeByIndex(row, 11).setNumber(totalEarC.toDouble());
    sheet
        .getRangeByIndex(row, 12)
        .setNumber(double.parse(totalPen.toStringAsFixed(1)));
    sheet.getRangeByIndex(row, 12).cellStyle.bold = true;
    sheet
        .getRangeByIndex(row, 13)
        .setNumber(double.parse(totalOt.toStringAsFixed(1)));
    sheet.getRangeByIndex(row, 13).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 14).setNumber(totalDailyL.toDouble());
    sheet
        .getRangeByIndex(row, 15)
        .setNumber(double.parse(totalHourL.toStringAsFixed(1)));
    sheet.getRangeByIndex(row, 17).setNumber(totalAbs.toDouble());
    sheet.getRangeByIndex(row, 17).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 18).setNumber(totalPres.toDouble());
    sheet.getRangeByIndex(row, 18).cellStyle.bold = true;

    for (int col = 1; col <= headers.length; col++) {
      sheet.autoFitColumn(col);
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final fileName = 'Periodic_Report_${startStr}_to_$endStr.xlsx';
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<void> exportPeriodicReportToPdf({
    required List<PeriodicReportRow> rows,
    required DateTime startDate,
    required DateTime endDate,
    required CompanyProfile? profile,
    String? languageCode,
  }) async {
    final lang = languageCode ?? 'en';
    final bool isRtl = lang == 'ar' || lang == 'ku';
    final dict =
        TranslationKeys.translations[lang] ??
        TranslationKeys.translations['en']!;
    String t(String key, [String fallback = '']) => dict[key] ?? fallback;

    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);

    final fontMap = await _loadPdfFonts(lang);
    final pw.Font? arabicFont = fontMap['base'];
    final pw.Font? boldArabicFont = fontMap['bold'];
    final List<pw.Font> fontFallbacks = List<pw.Font>.from(fontMap['fallbacks'] ?? []);

    final pdfTheme = pw.ThemeData.withFont(
      base: arabicFont ?? pw.Font.helvetica(),
      bold: boldArabicFont ?? arabicFont ?? pw.Font.helveticaBold(),
      fontFallback: fontFallbacks,
    );
    final pdf = pw.Document(theme: pdfTheme);

    bool hasArabicOrKurdish(String text) {
      for (final rune in text.runes) {
        if ((rune >= 0x0600 && rune <= 0x06FF) ||
            (rune >= 0x0750 && rune <= 0x077F) ||
            (rune >= 0x08A0 && rune <= 0x08FF) ||
            (rune >= 0xFB50 && rune <= 0xFDFF) ||
            (rune >= 0xFE70 && rune <= 0xFEFF)) {
          return true;
        }
      }
      return false;
    }

    String toVisualRtl(String input) {
      if (input.isEmpty) return input;
      final b = bidi.BidiString.fromLogical(input);
      final buffer = StringBuffer();
      for (final p in b.paragraphs) {
        final endsWithNewLine = p.separator == 10;
        final endIndex = p.bidiText.length - (endsWithNewLine ? 1 : 0);
        buffer.write(String.fromCharCodes(p.bidiText, 0, endIndex));
        if (endsWithNewLine) buffer.writeln();
      }
      return buffer.toString();
    }

    pw.Widget smartText(
      String text, {
      pw.TextStyle? style,
      pw.TextAlign? textAlign,
      pw.TextDirection? textDirection,
      int? maxLines,
      pw.TextOverflow? overflow,
    }) {
      if (text.isEmpty) return pw.SizedBox();

      final bool isExplicitLtr = textDirection == pw.TextDirection.ltr;
      if (isExplicitLtr) {
        return pw.Text(
          text,
          style: style,
          textAlign: textAlign ?? pw.TextAlign.left,
          textDirection: pw.TextDirection.ltr,
          maxLines: maxLines,
          overflow: overflow,
        );
      }

      final hasRtl = hasArabicOrKurdish(text);
      if (hasRtl) {
        final processedText = toVisualRtl(text);
        return pw.Text(
          processedText,
          textAlign: textAlign ?? pw.TextAlign.left,
          textDirection: pw.TextDirection.ltr,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
        );
      }

      return pw.Text(
        text,
        style: style,
        textAlign: textAlign ?? pw.TextAlign.left,
        textDirection: pw.TextDirection.ltr,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    pw.Widget? logoWidget;
    if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
      try {
        final image = pw.MemoryImage(base64Decode(profile.logoBase64!));
        logoWidget = pw.Image(image, width: 36, height: 36);
      } catch (_) {}
    }

    final toWord = t('date_to', isRtl ? (lang == 'ku' ? 'بۆ' : 'إلى') : 'to');
    final reportTitle = t(
      'periodic_report_title',
      'Periodic Attendance & Deficit Report',
    );
    final genDateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final genLabel = t('generated_date', isRtl ? (lang == 'ku' ? 'بەرواری دەرچوون' : 'تاريخ الإنشاء') : 'Generated');

    final headers = [
      t('id_label', 'Employee ID'),
      t('employee_col', 'Employee'),
      t('dept_col', 'Department'),
      t('req_hrs_col', 'Req. (hrs)'),
      t('actual_hrs_col', 'Actual (hrs)'),
      t('deficit_shortage_col', 'Deficit (Shortage)'),
      t('delay_m_col', 'Delay (m)'),
      t('early_exit_m_col', 'Early Exit (m)'),
      t('penalties_col', 'Penalties'),
      t('overtime_hrs_col', 'Overtime (hrs)'),
      t('leaves_filter', 'Leaves'),
      t('absences_col', 'Absences'),
    ];

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.2), // ID
      1: const pw.FlexColumnWidth(2.2), // Name
      2: const pw.FlexColumnWidth(1.6), // Dept
      3: const pw.FlexColumnWidth(1.1), // Req
      4: const pw.FlexColumnWidth(1.1), // Act
      5: const pw.FlexColumnWidth(1.1), // Deficit
      6: const pw.FlexColumnWidth(1.2), // Delay
      7: const pw.FlexColumnWidth(1.2), // Early
      8: const pw.FlexColumnWidth(1.0), // Penalties
      9: const pw.FlexColumnWidth(1.1), // OT
      10: const pw.FlexColumnWidth(1.0), // Leaves
      11: const pw.FlexColumnWidth(1.0), // Absences
    };

    double totalReq = 0;
    double totalAct = 0;
    double totalDef = 0;
    int totalDelM = 0;
    int totalDelC = 0;
    int totalEarM = 0;
    int totalEarC = 0;
    double totalPen = 0;
    double totalOt = 0;
    int totalDailyL = 0;
    int totalAbs = 0;

    for (final r in rows) {
      totalReq += r.requiredHours;
      totalAct += r.actualWorkedHours;
      totalDef += r.deficitHours;
      totalDelM += r.delayMinutes;
      totalDelC += r.delayCount;
      totalEarM += r.earlyExitMinutes;
      totalEarC += r.earlyExitCount;
      totalPen += r.penaltyDeductions;
      totalOt += r.totalOvertimeHours;
      totalDailyL += r.dailyLeaveDays;
      totalAbs += r.absentDays;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginLeft: 16,
          marginRight: 16,
          marginTop: 14,
          marginBottom: 14,
        ),
        textDirection: pw.TextDirection.ltr,
        theme: pdfTheme,
        build: (pw.Context context) {
          return [
            // Top Header: Company Info (Left) & Generated Info (Right)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoWidget != null) ...[
                      logoWidget,
                      pw.SizedBox(width: 8),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        smartText(
                          profile?.name.isNotEmpty == true ? profile!.name : 'Amada',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        smartText(
                          '$reportTitle ($startStr $toWord $endStr)',
                          style: const pw.TextStyle(
                            fontSize: 9.5,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                smartText(
                  '$genLabel: $genDateStr',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Report Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: columnWidths,
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey900,
                  ),
                  children: headers
                      .map(
                        (h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: smartText(
                            h,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),

                // Data Rows
                ...rows.map(
                  (r) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: rows.indexOf(r) % 2 == 0
                          ? PdfColors.white
                          : PdfColors.grey100,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.employee.id,
                          textAlign: pw.TextAlign.center,
                          textDirection: pw.TextDirection.ltr,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.employee.name,
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.structureName,
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.requiredHours.toStringAsFixed(1),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.actualWorkedHours.toStringAsFixed(1),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.deficitHours > 0
                              ? '-${r.deficitHours.toStringAsFixed(1)}'
                              : '0.0',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            color: r.deficitHours > 0
                                ? PdfColors.red800
                                : PdfColors.green800,
                            fontWeight: r.deficitHours > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.delayMinutes > 0 ? '${r.delayMinutes} (${r.delayCount})' : '-',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.earlyExitMinutes > 0 ? '${r.earlyExitMinutes} (${r.earlyExitCount})' : '-',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.penaltyDeductions > 0
                              ? r.penaltyDeductions.toStringAsFixed(1)
                              : '0',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.totalOvertimeHours > 0 ? r.totalOvertimeHours.toStringAsFixed(1) : '0.0',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontWeight: r.totalOvertimeHours > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: r.totalOvertimeHours > 0 ? PdfColors.blue800 : PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.dailyLeaveDays > 0 ? '${r.dailyLeaveDays}' : '0',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: smartText(
                          r.absentDays > 0 ? '${r.absentDays}' : '0',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            color: r.absentDays > 0
                                ? PdfColors.red900
                                : PdfColors.grey700,
                            fontWeight: r.absentDays > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Totals Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey100,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        t('total', 'TOTAL'),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText('-', textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText('-', textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        totalReq.toStringAsFixed(1),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        totalAct.toStringAsFixed(1),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        totalDef > 0 ? '-${totalDef.toStringAsFixed(1)}' : '0.0',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: totalDef > 0 ? PdfColors.red800 : PdfColors.green800,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        totalDelM > 0 ? '$totalDelM ($totalDelC)' : '-',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        totalEarM > 0 ? '$totalEarM ($totalEarC)' : '-',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        totalPen > 0 ? totalPen.toStringAsFixed(1) : '0',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        totalOt > 0 ? totalOt.toStringAsFixed(1) : '0.0',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        totalDailyL > 0 ? '$totalDailyL' : '0',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3.5),
                      child: smartText(
                        totalAbs > 0 ? '$totalAbs' : '0',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: totalAbs > 0 ? PdfColors.red900 : PdfColors.grey700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // Signatures Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    smartText(
                      '${t('prepared_by_label', 'Prepared By')}: ___________________',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 4),
                    smartText(
                      t('hr_department_label', 'HR Department'),
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    smartText(
                      '${t('approved_by_label', 'Approved By')}: ___________________',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 4),
                    smartText(
                      t('general_manager_label', 'General Manager'),
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final List<int> bytes = await pdf.save();
    final fileName = 'Periodic_Report_${startStr}_to_$endStr.pdf';
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
