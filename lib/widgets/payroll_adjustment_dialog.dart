import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';
import '../widgets/neu_button.dart';
import 'compact_date_picker_dialog.dart';

Future<void> showPayrollAdjustmentDialog({
  required BuildContext context,
  CompanyEmployee? employee,
  String initialType = 'addition',
  DateTime? initialMonth,
}) async {
  final provider = Provider.of<AttendanceProvider>(context, listen: false);
  final currentUser = provider.currentEmployee;
  final isAllowed = currentUser != null && (
    currentUser.role == 'hr' ||
    currentUser.role == 'admin' ||
    currentUser.email == 'admin@company.com' ||
    provider.isHRManager
  );
  if (!isAllowed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.translate('access_denied_adjustments')),
      ),
    );
    return;
  }

  if (initialMonth != null && provider.isMonthClosed(initialMonth)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.translate('cannot_modify_closed_month')),
        backgroundColor: Colors.amber.shade800,
      ),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: provider.translate('payroll_adjustment'),
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return _PayrollAdjustmentDialogContent(
        initialEmployee: employee,
        initialType: initialType,
        initialMonth: initialMonth ?? DateTime.now(),
      );
    },
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

String getLocalizedPayrollCategory(String category, AttendanceProvider provider) {
  switch (category) {
    case 'Bonus':
      return provider.translate('cat_bonus');
    case 'Commission / Incentive':
      return provider.translate('cat_commission_incentive');
    case 'Overtime Adjustment':
      return provider.translate('cat_overtime_adjustment');
    case 'Special Allowance':
      return provider.translate('cat_special_allowance');
    case 'Housing Allowance':
      return provider.translate('cat_housing_allowance');
    case 'Food Allowance':
      return provider.translate('cat_food_allowance');
    case 'Other Addition':
      return provider.translate('cat_other_addition');
    case 'Loan Repayment':
      return provider.translate('cat_loan_repayment');
    case 'Fine / Penalty':
      return provider.translate('cat_fine_penalty');
    case 'Salary Advance':
      return provider.translate('cat_salary_advance');
    case 'Equipment / Damage':
      return provider.translate('cat_equipment_damage');
    case 'Absence / Deficit Adjustment':
      return provider.translate('cat_absence_deficit');
    case 'Insurance / Tax':
      return provider.translate('cat_insurance_tax');
    case 'Other Deduction':
      return provider.translate('cat_other_deduction');
    default:
      return category;
  }
}

String formatLocalizedPayrollDate(DateTime date, AttendanceProvider provider) {
  final monthName = provider.translate('month_${date.month}');
  return '$monthName ${date.day}, ${date.year}';
}

class _PayrollAdjustmentDialogContent extends StatefulWidget {
  final CompanyEmployee? initialEmployee;
  final String initialType;
  final DateTime initialMonth;

  const _PayrollAdjustmentDialogContent({
    this.initialEmployee,
    required this.initialType,
    required this.initialMonth,
  });

  @override
  State<_PayrollAdjustmentDialogContent> createState() =>
      _PayrollAdjustmentDialogContentState();
}

class _PayrollAdjustmentDialogContentState
    extends State<_PayrollAdjustmentDialogContent> {
  late String _type; // 'addition' or 'deduction'
  late String _category;
  CompanyEmployee? _selectedEmployee;
  late DateTime _selectedDate;
  late String _currency;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  static const List<String> _additionCategories = [
    'Bonus',
    'Commission / Incentive',
    'Overtime Adjustment',
    'Special Allowance',
    'Housing Allowance',
    'Food Allowance',
    'Other Addition',
  ];

  static const List<String> _deductionCategories = [
    'Loan Repayment',
    'Fine / Penalty',
    'Salary Advance',
    'Equipment / Damage',
    'Absence / Deficit Adjustment',
    'Insurance / Tax',
    'Other Deduction',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = _type == 'addition'
        ? _additionCategories.first
        : _deductionCategories.first;

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final seenInitIds = <String>{};
    final availableEmps = provider.employees
        .where((e) => e.id.trim().isNotEmpty && seenInitIds.add(e.id.trim().toLowerCase()))
        .toList();

    if (widget.initialEmployee != null) {
      _selectedEmployee = availableEmps.firstWhere(
        (e) => e.id.trim().toLowerCase() == widget.initialEmployee!.id.trim().toLowerCase(),
        orElse: () => widget.initialEmployee!,
      );
    } else if (availableEmps.isNotEmpty) {
      _selectedEmployee = availableEmps.first;
    }

    _currency = _selectedEmployee?.salaryCurrency ?? 'USD';

    // Default date within target month
    final now = DateTime.now();
    if (widget.initialMonth.year == now.year &&
        widget.initialMonth.month == now.month) {
      _selectedDate = now;
    } else {
      _selectedDate = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String newType) {
    if (_type == newType) return;
    setState(() {
      _type = newType;
      _category = _type == 'addition'
          ? _additionCategories.first
          : _deductionCategories.first;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showCompactDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.translate('select_employee_error'))),
      );
      return;
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.translate('valid_amount_error'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final monthStr = DateFormat('yyyy-MM').format(_selectedDate);

    if (provider.isMonthClosedStr(monthStr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber.shade800,
          content: Text(provider.translate('cannot_modify_closed_month')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final adjustment = PayrollAdjustment(
      id: 'adj_${DateTime.now().millisecondsSinceEpoch}',
      employeeId: _selectedEmployee!.id,
      type: _type,
      category: _category,
      amount: amount,
      currency: _currency,
      date: dateStr,
      month: monthStr,
      reason: _reasonController.text.trim(),
      createdBy: provider.currentEmployee?.name ?? 'Admin',
      createdAt: DateTime.now(),
    );

    await provider.addPayrollAdjustment(adjustment);

    if (mounted) {
      Navigator.of(context).pop();
      final typeLabel = provider.translate(_type == 'addition' ? 'addition' : 'deduction');
      final amountLabel = _currency == 'USD' ? '\$$amount' : '$amount $_currency';
      final msg = provider.translate('adjustment_recorded_msg')
          .replaceAll('{type}', typeLabel)
          .replaceAll('{amount}', amountLabel)
          .replaceAll('{name}', _selectedEmployee!.name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _type == 'addition'
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AttendanceProvider>(context);
    final seenIds = <String>{};
    final employees = provider.employees
        .where((e) => e.id.trim().isNotEmpty && seenIds.add(e.id.trim().toLowerCase()))
        .toList();

    if (_selectedEmployee != null &&
        !employees.any((e) => e.id.trim().toLowerCase() == _selectedEmployee!.id.trim().toLowerCase())) {
      _selectedEmployee = employees.isNotEmpty ? employees.first : null;
    } else if (_selectedEmployee == null && employees.isNotEmpty) {
      _selectedEmployee = employees.first;
    }

    final isAddition = _type == 'addition';
    final accentColor = isAddition
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final bgGlowColor = isAddition
        ? const Color(0xFF10B981).withValues(alpha: 0.15)
        : const Color(0xFFEF4444).withValues(alpha: 0.15);

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Center(
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: bgGlowColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Icon(
                                isAddition
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: accentColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAddition
                                        ? provider.translate('addition_bonus')
                                        : provider.translate('deduction_loan_fine'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAddition
                                        ? provider.translate('addition_desc')
                                        : provider.translate('deduction_desc'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            NeuIconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              size: 34,
                              variant: NeuButtonVariant.whitePill,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Type Switcher Tabs (Addition vs Deduction - Stadium Capsule)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF161F2E)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _onTypeChanged('addition'),
                                  borderRadius: BorderRadius.circular(50),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: isAddition
                                          ? const LinearGradient(
                                              colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(50),
                                      boxShadow: isAddition
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline_rounded,
                                            size: 15,
                                            color: isAddition
                                                ? const Color(0xFF0A2342)
                                                : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                provider.translate('addition_bonus'),
                                                style: TextStyle(
                                                  color: isAddition
                                                      ? const Color(0xFF0A2342)
                                                      : (isDark ? Colors.white70 : Colors.black87),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12.5,
                                                ),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _onTypeChanged('deduction'),
                                  borderRadius: BorderRadius.circular(50),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: !isAddition
                                          ? const LinearGradient(
                                              colors: [Color(0xFFFF758C), Color(0xFFFF5C5C)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(50),
                                      boxShadow: !isAddition
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFFF5C5C).withValues(alpha: 0.35),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.remove_circle_outline_rounded,
                                            size: 15,
                                            color: !isAddition
                                                ? Colors.white
                                                : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                provider.translate('deduction_loan_fine'),
                                                style: TextStyle(
                                                  color: !isAddition
                                                      ? Colors.white
                                                      : (isDark ? Colors.white70 : Colors.black87),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12.5,
                                                ),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Employee Selection Dropdown
                        Text(
                          provider.translate('employee'),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedEmployee != null &&
                                      employees.any((e) => e.id.trim().toLowerCase() == _selectedEmployee!.id.trim().toLowerCase())
                                  ? _selectedEmployee!.id
                                  : (employees.isNotEmpty ? employees.first.id : null),
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              hint: Text(provider.translate('select_employee')),
                              items: employees.map((emp) {
                                return DropdownMenuItem<String>(
                                  value: emp.id,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: accentColor.withValues(alpha: 0.2),
                                        child: Text(
                                          emp.name.isNotEmpty
                                              ? emp.name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: accentColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              emp.name,
                                              style: TextStyle(
                                                color: isDark ? Colors.white : Colors.black87,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              emp.position,
                                              style: TextStyle(
                                                color: isDark ? Colors.white54 : Colors.black54,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (empId) {
                                if (empId != null) {
                                  final matchingEmp = employees.firstWhere(
                                    (e) => e.id.trim().toLowerCase() == empId.trim().toLowerCase(),
                                    orElse: () => employees.first,
                                  );
                                  setState(() {
                                    _selectedEmployee = matchingEmp;
                                    _currency = matchingEmp.salaryCurrency.isNotEmpty
                                        ? matchingEmp.salaryCurrency
                                        : 'USD';
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Category Dropdown
                        Text(
                          isAddition
                              ? provider.translate('addition_type_reason')
                              : provider.translate('deduction_type_reason'),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _category,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              items: (isAddition ? _additionCategories : _deductionCategories)
                                  .map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getCategoryIcon(cat),
                                        size: 18,
                                        color: accentColor,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        getLocalizedPayrollCategory(cat, provider),
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (cat) {
                                if (cat != null) {
                                  setState(() {
                                    _category = cat;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Amount and Currency Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.translate('amount'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      prefixIcon: Icon(
                                        Icons.attach_money_rounded,
                                        color: accentColor,
                                        size: 20,
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: accentColor, width: 1.5),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return provider.translate('valid_amount_error');
                                      }
                                      final num = double.tryParse(val.trim());
                                      if (num == null || num <= 0) {
                                        return provider.translate('valid_amount_error');
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.translate('currency'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _currency,
                                        isExpanded: true,
                                        dropdownColor:
                                            isDark ? const Color(0xFF1E293B) : Colors.white,
                                        items: const [
                                          DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                          DropdownMenuItem(value: 'IQD', child: Text('IQD')),
                                        ],
                                        onChanged: (curr) {
                                          if (curr != null) {
                                            setState(() => _currency = curr);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Date Selector
                        Text(
                          provider.translate('effective_date'),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  formatLocalizedPayrollDate(_selectedDate, provider),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Description / Notes
                        Text(
                          provider.translate('notes_desc_optional'),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 2,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: isAddition
                                ? provider.translate('addition_notes_hint')
                                : provider.translate('deduction_notes_hint'),
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12.5,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                provider.translate('cancel'),
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            NeuButton(
                              onPressed: _isSaving ? null : _submit,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      isAddition
                                          ? Icons.add_circle_rounded
                                          : Icons.remove_circle_rounded,
                                      size: 18,
                                    ),
                              label: isAddition
                                  ? '${provider.translate('save')} ${provider.translate('addition')}'
                                  : '${provider.translate('save')} ${provider.translate('deduction')}',
                              variant: isAddition ? NeuButtonVariant.primary : NeuButtonVariant.danger,
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              fontSize: 13.5,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Bonus':
        return Icons.star_rounded;
      case 'Commission / Incentive':
        return Icons.paid_rounded;
      case 'Overtime Adjustment':
        return Icons.more_time_rounded;
      case 'Special Allowance':
      case 'Housing Allowance':
      case 'Food Allowance':
        return Icons.card_giftcard_rounded;
      case 'Loan Repayment':
        return Icons.account_balance_rounded;
      case 'Fine / Penalty':
        return Icons.gavel_rounded;
      case 'Salary Advance':
        return Icons.price_change_rounded;
      case 'Equipment / Damage':
        return Icons.handyman_rounded;
      case 'Absence / Deficit Adjustment':
        return Icons.event_busy_rounded;
      case 'Insurance / Tax':
        return Icons.shield_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }
}

/// Modal dialog to view and manage existing payroll adjustments for a month
Future<void> showManageAdjustmentsDialog({
  required BuildContext context,
  required DateTime targetMonth,
  CompanyEmployee? filterEmployee,
}) async {
  final provider = Provider.of<AttendanceProvider>(context, listen: false);
  final currentUser = provider.currentEmployee;
  final isAllowed = currentUser != null && (
    currentUser.role == 'hr' ||
    currentUser.role == 'admin' ||
    currentUser.email == 'admin@company.com'
  );
  if (!isAllowed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.translate('access_denied_adjustments')),
      ),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: provider.translate('monthly_adjustments'),
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return _ManageAdjustmentsDialogContent(
        targetMonth: targetMonth,
        filterEmployee: filterEmployee,
      );
    },
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class _ManageAdjustmentsDialogContent extends StatelessWidget {
  final DateTime targetMonth;
  final CompanyEmployee? filterEmployee;

  const _ManageAdjustmentsDialogContent({
    required this.targetMonth,
    this.filterEmployee,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AttendanceProvider>(context);
    final targetMonthStr = DateFormat('yyyy-MM').format(targetMonth);

    final monthAdjustments = provider.payrollAdjustments.where((adj) {
      final matchesMonth = adj.month == targetMonthStr ||
          (adj.date.length >= 7 && adj.date.substring(0, 7) == targetMonthStr);
      if (!matchesMonth) return false;
      if (filterEmployee != null) {
        return adj.employeeId.trim().toLowerCase() == filterEmployee!.id.trim().toLowerCase();
      }
      return true;
    }).toList();

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Center(
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E65FF), Color(0xFF8236FE)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${provider.translate('monthly_adjustments')} (${provider.translate('month_${targetMonth.month}')} ${targetMonth.year})',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                filterEmployee != null
                                    ? provider.translate('showing_adjustments_for').replaceAll('{name}', filterEmployee!.name)
                                    : provider.translate('records_found').replaceAll('{count}', monthAdjustments.length.toString()),
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        NeuIconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          size: 34,
                          variant: NeuButtonVariant.whitePill,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // List of adjustments
                  Expanded(
                    child: monthAdjustments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: (isDark ? Colors.white30 : Colors.black26),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  provider.translate('no_adjustments_month'),
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.translate('add_bonuses_loans_desc'),
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            itemCount: monthAdjustments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final adj = monthAdjustments[index];
                              final isAdd = adj.type == 'addition';
                              final color = isAdd
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444);
                              final emp = provider.employees.firstWhere(
                                (e) =>
                                    e.id == adj.employeeId ||
                                    e.name.toLowerCase() == adj.employeeId.toLowerCase(),
                                orElse: () => CompanyEmployee(
                                  id: adj.employeeId,
                                  name: adj.employeeId,
                                  email: '',
                                  position: 'Employee',
                                ),
                              );

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isAdd
                                            ? Icons.add_circle_outline_rounded
                                            : Icons.remove_circle_outline_rounded,
                                        color: color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                emp.name,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  getLocalizedPayrollCategory(adj.category, provider),
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (adj.reason.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              adj.reason,
                                              style: TextStyle(
                                                color: isDark ? Colors.white60 : Colors.black54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 3),
                                          Text(
                                            '${provider.translate('date')}: ${adj.date}',
                                            style: TextStyle(
                                              color: isDark ? Colors.white38 : Colors.black38,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${isAdd ? '+' : '-'}${adj.currency == 'USD' ? '\$${adj.amount.toStringAsFixed(2)}' : '${adj.amount.toStringAsFixed(0)} ${adj.currency}'}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        if (provider.isMonthClosedStr(adj.month)) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: Colors.amber.shade800,
                                              content: Text(provider.translate('cannot_modify_closed_month')),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          return;
                                        }
                                        final typeLabel = provider.translate(adj.type == 'addition' ? 'addition' : 'deduction');
                                        final catLabel = getLocalizedPayrollCategory(adj.category, provider);
                                        final amountStr = adj.currency == 'USD'
                                            ? '\$${adj.amount.toStringAsFixed(2)}'
                                            : '${adj.amount.toStringAsFixed(0)} ${adj.currency}';
                                        final confirmMsg = provider.translate('confirm_delete_adj_msg')
                                            .replaceAll('{type}', typeLabel)
                                            .replaceAll('{category}', catLabel)
                                            .replaceAll('{amount}', amountStr)
                                            .replaceAll('{name}', emp.name);
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: Text(provider.translate('delete_adjustment_title')),
                                            content: Text(confirmMsg),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(c).pop(false),
                                                child: Text(provider.translate('cancel')),
                                              ),
                                              NeuButton(
                                                onPressed: () => Navigator.of(c).pop(true),
                                                variant: NeuButtonVariant.danger,
                                                height: 36,
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                label: provider.translate('delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await provider.deletePayrollAdjustment(adj.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Action bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            provider.translate('close'),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        NeuButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            showPayrollAdjustmentDialog(
                              context: context,
                              employee: filterEmployee,
                              initialMonth: targetMonth,
                            );
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: provider.translate('add_adjustment'),
                          variant: NeuButtonVariant.primary,
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
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
  );
}
}
