import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../services/export_service.dart';

Future<void> showPayslipDialog({
  required BuildContext context,
  required PayrollReport report,
  required DateTime month,
  String? structureName,
  String? groupName,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Payslip',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
    pageBuilder: (ctx, anim, secondAnim) {
      return PayslipDialogContent(
        report: report,
        month: month,
        structureName: structureName,
        groupName: groupName,
      );
    },
  );
}

class PayslipDialogContent extends StatefulWidget {
  final PayrollReport report;
  final DateTime month;
  final String? structureName;
  final String? groupName;

  const PayslipDialogContent({
    super.key,
    required this.report,
    required this.month,
    this.structureName,
    this.groupName,
  });

  @override
  State<PayslipDialogContent> createState() => _PayslipDialogContentState();
}

class _PayslipDialogContentState extends State<PayslipDialogContent> {
  bool _isExporting = false;

  String _formatAmount(double amount, String currency) {
    if (currency == 'USD') {
      return '\$${NumberFormat('#,##0.00').format(amount)}';
    } else {
      return '${NumberFormat('#,##0').format(amount)} $currency';
    }
  }

  Future<void> _downloadPdf(AttendanceProvider provider) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      await ExportService.exportSinglePayslipToPdf(
        report: widget.report,
        month: widget.month,
        profile: provider.companyProfile,
        structureName: widget.structureName,
        groupName: widget.groupName,
        languageCode: provider.currentLanguage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    provider.translate('payslip_downloaded'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF4B4B),
            content: Text('${provider.translate('export_failed')}: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = provider.companyProfile;
    final r = widget.report;
    final emp = r.employee;
    final textDir = provider.currentLanguageDirection;

    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 640;

    final cardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.98);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F0);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    Widget? logoWidget;
    if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
      try {
        logoWidget = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(profile.logoBase64!),
            width: 48,
            height: 48,
            fit: BoxFit.contain,
          ),
        );
      } catch (_) {}
    }

    return Directionality(
      textDirection: textDir,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 14.0 : 28.0,
            vertical: isSmallScreen ? 20.0 : 36.0,
          ),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 720,
                  constraints: BoxConstraints(
                    maxHeight: mediaQuery.size.height * 0.9,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF8FAFC),
                          border: Border(bottom: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF102B94).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF102B94),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.translate('salary_payslip'),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${provider.translate('pay_period')}: ${provider.translate('month_${widget.month.month}')} ${widget.month.year}',
                                    style: TextStyle(color: subtextColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: provider.translate('close'),
                              icon: Icon(Icons.close_rounded, color: subtextColor),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),

                      // Content Area (Scrollable)
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Company Identity & Status
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (logoWidget != null) ...[
                                    logoWidget,
                                    const SizedBox(width: 14),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile?.name.isNotEmpty == true
                                              ? profile!.name
                                              : provider.translate('app_title'),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (profile?.address.isNotEmpty == true)
                                          Text(
                                            profile!.address,
                                            style: TextStyle(color: subtextColor, fontSize: 11),
                                          ),
                                        if (profile?.email != null && profile!.email!.isNotEmpty)
                                          Text(
                                            profile.email!,
                                            style: TextStyle(color: subtextColor, fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          provider.translate('payment_date'),
                                          style: TextStyle(
                                            color: subtextColor,
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('yyyy-MM-dd').format(DateTime.now()),
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Employee Details Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.translate('employee_details'),
                                      style: TextStyle(
                                        color: subtextColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 24,
                                      runSpacing: 12,
                                      children: [
                                        _buildInfoField(
                                          context,
                                          label: provider.translate('name_label'),
                                          value: emp.name,
                                          isBold: true,
                                        ),
                                        _buildInfoField(
                                          context,
                                          label: provider.translate('id_label'),
                                          value: emp.id,
                                        ),
                                        _buildInfoField(
                                          context,
                                          label: provider.translate('position'),
                                          value: emp.position.isNotEmpty ? emp.position : '-',
                                        ),
                                        _buildInfoField(
                                          context,
                                          label: provider.translate('department'),
                                          value: widget.structureName ?? '-',
                                        ),
                                        _buildInfoField(
                                          context,
                                          label: provider.translate('group'),
                                          value: widget.groupName ?? '-',
                                        ),
                                        _buildInfoField(
                                          context,
                                          label: provider.translate('currency_label'),
                                          value: r.currency,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Attendance & Work Metrics Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricTile(
                                      context,
                                      label: provider.translate('days_worked'),
                                      value: '${r.daysWorked} ${provider.translate('unit_days')}',
                                      icon: Icons.calendar_today_outlined,
                                      color: const Color(0xFF5B9BFF),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildMetricTile(
                                      context,
                                      label: provider.translate('working_hrs'),
                                      value: '${r.workingHours.toStringAsFixed(1)} ${provider.translate('unit_hrs')}',
                                      icon: Icons.access_time_rounded,
                                      color: const Color(0xFF00E5CE),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildMetricTile(
                                      context,
                                      label: provider.translate('overtime_hrs'),
                                      value: '${r.overtimeHours.toStringAsFixed(1)} ${provider.translate('unit_hrs')}',
                                      icon: Icons.trending_up_rounded,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildMetricTile(
                                      context,
                                      label: provider.translate('deficit_hrs'),
                                      value: '${r.attendanceDeficitHours.toStringAsFixed(1)} ${provider.translate('unit_hrs')}',
                                      icon: Icons.trending_down_rounded,
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Two Columns: Earnings vs Deductions
                              isSmallScreen
                                  ? Column(
                                      children: [
                                        _buildEarningsTable(context, provider),
                                        const SizedBox(height: 16),
                                        _buildDeductionsTable(context, provider),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildEarningsTable(context, provider)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _buildDeductionsTable(context, provider)),
                                      ],
                                    ),

                              // Social Insurance Box (if active)
                              if (r.hasInsurance) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.shield_outlined, color: Color(0xFF0284C7), size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            provider.translate('social_insurance_title'),
                                            style: const TextStyle(
                                              color: Color(0xFF0284C7),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${provider.translate('insurance_salary_label')}: ${_formatAmount(r.insuranceSalary, r.currency)}',
                                            style: const TextStyle(
                                              color: Color(0xFF0284C7),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '• ${provider.translate('insurance_deduction_5')}: -${_formatAmount(r.insuranceEmployee, r.currency)}',
                                            style: const TextStyle(
                                              color: Color(0xFFFF5C5C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '• ${provider.translate('insurance_company_12')}: ${_formatAmount(r.insuranceCompany, r.currency)} (${provider.translate('employer_contributions')})',
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Net Payable Salary Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [const Color(0xFF065F46), const Color(0xFF047857)]
                                        : [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          provider.translate('net_payable_salary'),
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF065F46),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${provider.translate('total_earnings')} - ${provider.translate('total_deductions')}',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.7)
                                                : const Color(0xFF047857),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _formatAmount(r.netEarnings, r.currency),
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF064E3B),
                                        fontWeight: FontWeight.w900,
                                        fontSize: isSmallScreen ? 20 : 26,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 28),

                              // Signatures Block
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.translate('employee_signature'),
                                        style: TextStyle(color: subtextColor, fontSize: 11),
                                      ),
                                      const SizedBox(height: 32),
                                      Container(
                                        width: 140,
                                        height: 1,
                                        color: isDark ? Colors.white24 : Colors.black26,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        emp.name,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        provider.translate('authorized_signature'),
                                        style: TextStyle(color: subtextColor, fontSize: 11),
                                      ),
                                      const SizedBox(height: 32),
                                      Container(
                                        width: 160,
                                        height: 1,
                                        color: isDark ? Colors.white24 : Colors.black26,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        profile?.name.isNotEmpty == true
                                            ? profile!.name
                                            : provider.translate('administration_title'),
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Computer Generated Footer Note
                              Center(
                                child: Text(
                                  provider.translate('computer_generated_note'),
                                  style: TextStyle(
                                    color: subtextColor.withValues(alpha: 0.7),
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer Actions Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : const Color(0xFFF8FAFC),
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: subtextColor,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(provider.translate('close')),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF102B94),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                              label: Text(
                                _isExporting
                                    ? provider.translate('generating_payslip')
                                    : provider.translate('download_payslip'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isExporting ? null : () => _downloadPdf(provider),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoField(
    BuildContext context, {
    required String label,
    required String value,
    bool isBold = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsTable(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.report;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Text(
                  provider.translate('earnings'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildRow(
                  context,
                  label: '${provider.translate('basic_salary')} / ${provider.translate('salary_by_day')}',
                  value: _formatAmount(r.salaryCalcByDay > 0 ? r.salaryCalcByDay : r.basicSalary, r.currency),
                ),
                if (r.overtimeValue > 0)
                  _buildRow(
                    context,
                    label: provider.translate('overtime'),
                    value: _formatAmount(r.overtimeValue, r.currency),
                    color: const Color(0xFF10B981),
                  ),
                if (r.foodAllowance > 0)
                  _buildRow(
                    context,
                    label: provider.translate('food_allowance'),
                    value: _formatAmount(r.foodAllowance, r.currency),
                  ),
                if (r.transportationAllowance > 0)
                  _buildRow(
                    context,
                    label: provider.translate('transportation_allowance'),
                    value: _formatAmount(r.transportationAllowance, r.currency),
                  ),
                if (r.otherAllowance > 0)
                  _buildRow(
                    context,
                    label: provider.translate('other_allowance'),
                    value: _formatAmount(r.otherAllowance, r.currency),
                  ),
                if (r.monthlyAdditions > 0)
                  _buildRow(
                    context,
                    label: provider.translate('additions'),
                    value: '+${_formatAmount(r.monthlyAdditions, r.currency)}',
                    color: const Color(0xFF10B981),
                  ),
                const SizedBox(height: 8),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 8),
                _buildRow(
                  context,
                  label: provider.translate('total_earnings'),
                  value: _formatAmount(r.incrementalSalary, r.currency),
                  isBold: true,
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionsTable(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.report;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFFF5C5C), size: 16),
                const SizedBox(width: 8),
                Text(
                  provider.translate('deductions_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (r.attendanceDeficit > 0)
                  _buildRow(
                    context,
                    label: provider.translate('attendance_deficit'),
                    value: '-${_formatAmount(r.attendanceDeficit, r.currency)}',
                    color: const Color(0xFFFF5C5C),
                  ),
                if (r.monthlyPenalties > 0)
                  _buildRow(
                    context,
                    label: provider.translate('penalties'),
                    value: '-${_formatAmount(r.monthlyPenalties, r.currency)}',
                    color: const Color(0xFFFF5C5C),
                  ),
                if (r.monthlyDeductions > 0)
                  _buildRow(
                    context,
                    label: provider.translate('loans_deductions_desc'),
                    value: '-${_formatAmount(r.monthlyDeductions, r.currency)}',
                    color: const Color(0xFFFF5C5C),
                  ),
                if (r.hasInsurance)
                  _buildRow(
                    context,
                    label: '${provider.translate('social_insurance_title')} (5%)',
                    value: '-${_formatAmount(r.insuranceEmployee, r.currency)}',
                    color: const Color(0xFFFF5C5C),
                  ),
                if (r.unpaidLeaveDeduction > 0)
                  _buildRow(
                    context,
                    label: '${provider.translate('unpaid_leave_deduction')} (${r.unpaidLeaveHours.toStringAsFixed(1)} ${provider.translate('unit_hrs')})',
                    value: '-${_formatAmount(r.unpaidLeaveDeduction, r.currency)}',
                    color: const Color(0xFFFF5C5C),
                  ),
                if (r.attendanceDeficit == 0 && r.monthlyPenalties == 0 && r.monthlyDeductions == 0 && !r.hasInsurance && r.unpaidLeaveDeduction == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '-',
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 8),
                _buildRow(
                  context,
                  label: provider.translate('total_deductions'),
                  value: '-${_formatAmount(r.decrementalSalary, r.currency)}',
                  isBold: true,
                  color: const Color(0xFFFF5C5C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isBold = false,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isBold
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
