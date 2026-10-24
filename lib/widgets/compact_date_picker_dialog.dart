import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';

enum _PickerView { days, months, years }

/// A compact, elegant calendar dialog styled with the app's teal/green branding.
/// Replaces Flutter's default full-screen DateRangePicker with a responsive,
/// floating dialog matching modern UI aesthetics.
class CompactDatePickerDialog extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? currentDate;
  final bool isSingleDateOnly;
  final String? title;

  const CompactDatePickerDialog({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.firstDate,
    required this.lastDate,
    this.currentDate,
    this.isSingleDateOnly = false,
    this.title,
  });

  @override
  State<CompactDatePickerDialog> createState() => _CompactDatePickerDialogState();
}

class _CompactDatePickerDialogState extends State<CompactDatePickerDialog> {
  late DateTime _currentMonth;
  late DateTime _firstDateOnly;
  late DateTime _lastDateOnly;
  late DateTime _today;

  DateTime? _startDate;
  DateTime? _endDate;

  _PickerView _view = _PickerView.days;
  late int _yearScrollAnchor;

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void initState() {
    super.initState();
    _firstDateOnly = _dateOnly(widget.firstDate);
    _lastDateOnly = _dateOnly(widget.lastDate);
    _today = _dateOnly(widget.currentDate ?? DateTime.now());

    if (widget.initialStartDate != null) {
      _startDate = _dateOnly(widget.initialStartDate!);
    }
    if (widget.initialEndDate != null) {
      _endDate = _dateOnly(widget.initialEndDate!);
    }

    if (widget.isSingleDateOnly && _startDate != null) {
      _endDate = _startDate;
    }

    final initialAnchor = _startDate ?? _today;
    if (initialAnchor.isBefore(_firstDateOnly)) {
      _currentMonth = DateTime(_firstDateOnly.year, _firstDateOnly.month, 1);
    } else if (initialAnchor.isAfter(_lastDateOnly)) {
      _currentMonth = DateTime(_lastDateOnly.year, _lastDateOnly.month, 1);
    } else {
      _currentMonth = DateTime(initialAnchor.year, initialAnchor.month, 1);
    }

    _yearScrollAnchor = _currentMonth.year;
  }

  void _onPrev() {
    setState(() {
      if (_view == _PickerView.days) {
        final prev = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
        if (prev.isAfter(DateTime(_firstDateOnly.year, _firstDateOnly.month - 1, 1))) {
          _currentMonth = prev;
        }
      } else if (_view == _PickerView.months) {
        if (_currentMonth.year > _firstDateOnly.year) {
          _currentMonth = DateTime(_currentMonth.year - 1, _currentMonth.month, 1);
        }
      } else {
        if (_yearScrollAnchor - 12 >= _firstDateOnly.year - 6) {
          _yearScrollAnchor -= 12;
        }
      }
    });
  }

  void _onNext() {
    setState(() {
      if (_view == _PickerView.days) {
        final next = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
        if (next.isBefore(DateTime(_lastDateOnly.year, _lastDateOnly.month + 1, 1))) {
          _currentMonth = next;
        }
      } else if (_view == _PickerView.months) {
        if (_currentMonth.year < _lastDateOnly.year) {
          _currentMonth = DateTime(_currentMonth.year + 1, _currentMonth.month, 1);
        }
      } else {
        if (_yearScrollAnchor + 12 <= _lastDateOnly.year + 6) {
          _yearScrollAnchor += 12;
        }
      }
    });
  }

  void _onDaySelected(DateTime day) {
    if (day.isBefore(_firstDateOnly) || day.isAfter(_lastDateOnly)) return;

    setState(() {
      // If clicking overflow day from another month, navigate to that month
      if (day.year != _currentMonth.year || day.month != _currentMonth.month) {
        _currentMonth = DateTime(day.year, day.month, 1);
      }

      if (widget.isSingleDateOnly) {
        _startDate = day;
        _endDate = day;
      } else {
        if (_startDate == null || (_startDate != null && _endDate != null)) {
          _startDate = day;
          _endDate = null;
        } else if (_startDate != null && _endDate == null) {
          if (day.isBefore(_startDate!)) {
            _startDate = day;
            _endDate = null;
          } else {
            _endDate = day;
          }
        }
      }
    });
  }

  static const _englishMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _englishShortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];
  static const _arabicShortMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  static const _kurdishMonths = [
    'کانوونی دووەم', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
    'تەمووز', 'ئاب', 'ئەیلوول', 'تشرینی یەکەم', 'تشرینی دووەم', 'کانوونی یەکەم'
  ];
  static const _kurdishShortMonths = [
    'کانوونی ۲', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
    'تەمووز', 'ئاب', 'ئەیلوول', 'تشرینی ۱', 'تشرینی ۲', 'کانوونی ۱'
  ];

  String _getMonthName(int month, String locale) {
    final idx = (month - 1).clamp(0, 11);
    if (locale == 'ar') return _arabicMonths[idx];
    if (locale == 'ku') return _kurdishMonths[idx];
    return _englishMonths[idx];
  }

  String _getShortMonthName(int month, String locale) {
    final idx = (month - 1).clamp(0, 11);
    if (locale == 'ar') return _arabicShortMonths[idx];
    if (locale == 'ku') return _kurdishShortMonths[idx];
    return _englishShortMonths[idx];
  }

  void _onConfirm() {
    if (_startDate == null) {
      Navigator.of(context).pop(null);
      return;
    }
    final start = _startDate!;
    final end = _endDate ?? start;
    Navigator.of(context).pop(DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = provider.currentLanguage;

    // Palette: Green brand color matching the app's action buttons
    const primaryGreen = Color(0xFF00E5CE);
    const secondaryGreen = Color(0xFF00BFA5);
    const onGreenNavy = Color(0xFF0A2342);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final headerBtnBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dayTileBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.45) : const Color(0xFFF8FAFC);
    final dayTileBorder = isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFF1F5F9);

    final monthName = _getMonthName(_currentMonth.month, locale);
    final yearString = _currentMonth.year.toString();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      elevation: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row (matching Image 2)
                _buildHeaderRow(
                  monthName: monthName,
                  yearString: yearString,
                  isDark: isDark,
                  headerBtnBg: headerBtnBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  primaryGreen: primaryGreen,
                ),
                const SizedBox(height: 16),

                // View Body: Days Grid, Months Grid, or Years Grid
                if (_view == _PickerView.days)
                  _buildDaysView(
                    locale: locale,
                    isDark: isDark,
                    textMuted: textMuted,
                    textPrimary: textPrimary,
                    dayTileBg: dayTileBg,
                    dayTileBorder: dayTileBorder,
                    primaryGreen: primaryGreen,
                    secondaryGreen: secondaryGreen,
                    onGreenNavy: onGreenNavy,
                  )
                else if (_view == _PickerView.months)
                  _buildMonthsView(
                    locale: locale,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    primaryGreen: primaryGreen,
                    onGreenNavy: onGreenNavy,
                  )
                else
                  _buildYearsView(
                    isDark: isDark,
                    textPrimary: textPrimary,
                    primaryGreen: primaryGreen,
                    onGreenNavy: onGreenNavy,
                  ),

                const SizedBox(height: 18),

                // Footer Row with Summary & Buttons
                _buildFooterRow(
                  provider: provider,
                  locale: locale,
                  isDark: isDark,
                  primaryGreen: primaryGreen,
                  secondaryGreen: secondaryGreen,
                  onGreenNavy: onGreenNavy,
                  textMuted: textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow({
    required String monthName,
    required String yearString,
    required bool isDark,
    required Color headerBtnBg,
    required Color borderColor,
    required Color textPrimary,
    required Color primaryGreen,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Chevron Nav Button
        Material(
          color: headerBtnBg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _onPrev,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.chevron_left_rounded, size: 22, color: textPrimary),
            ),
          ),
        ),

        // Center: Month ▾ and Year ▾ pills side by side
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month Selector Pill
            Material(
              color: _view == _PickerView.months
                  ? primaryGreen.withValues(alpha: 0.18)
                  : headerBtnBg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _view = _view == _PickerView.months ? _PickerView.days : _PickerView.months;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _view == _PickerView.months ? primaryGreen : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _view == _PickerView.months
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: primaryGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Year Selector Pill
            Material(
              color: _view == _PickerView.years
                  ? primaryGreen.withValues(alpha: 0.18)
                  : headerBtnBg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _yearScrollAnchor = _currentMonth.year;
                    _view = _view == _PickerView.years ? _PickerView.days : _PickerView.years;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _view == _PickerView.years ? primaryGreen : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        yearString,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _view == _PickerView.years
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: primaryGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Right Chevron Nav Button
        Material(
          color: headerBtnBg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _onNext,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.chevron_right_rounded, size: 22, color: textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysView({
    required String locale,
    required bool isDark,
    required Color textMuted,
    required Color textPrimary,
    required Color dayTileBg,
    required Color dayTileBorder,
    required Color primaryGreen,
    required Color secondaryGreen,
    required Color onGreenNavy,
  }) {
    // Weekday headers: Mo, Tu, We, Th, Fr, Sa, Su (matching Image 2)
    final weekdays = locale == 'ar'
        ? ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح']
        : locale == 'ku'
            ? ['دوو', 'سێ', 'چوار', 'پێنج', 'هەینی', 'شەم', 'یەک']
            : ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final daysInPrevMonth = DateTime(_currentMonth.year, _currentMonth.month, 0).day;

    // Monday is column 0 (weekday 1 => offset 0; Sunday 7 => offset 6)
    final firstDayOffset = (firstDayOfMonth.weekday - 1) % 7;

    final List<Widget> dayTiles = [];

    // Previous month overflow days
    for (int i = 0; i < firstDayOffset; i++) {
      final dayNum = daysInPrevMonth - firstDayOffset + 1 + i;
      final prevDate = DateTime(_currentMonth.year, _currentMonth.month - 1, dayNum);
      dayTiles.add(_buildDayCell(
        date: prevDate,
        dayNumber: dayNum,
        isCurrentMonth: false,
        isDark: isDark,
        textPrimary: textPrimary,
        dayTileBg: dayTileBg,
        dayTileBorder: dayTileBorder,
        primaryGreen: primaryGreen,
        secondaryGreen: secondaryGreen,
        onGreenNavy: onGreenNavy,
      ));
    }

    // Current month days
    for (int dayNum = 1; dayNum <= daysInMonth; dayNum++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
      dayTiles.add(_buildDayCell(
        date: date,
        dayNumber: dayNum,
        isCurrentMonth: true,
        isDark: isDark,
        textPrimary: textPrimary,
        dayTileBg: dayTileBg,
        dayTileBorder: dayTileBorder,
        primaryGreen: primaryGreen,
        secondaryGreen: secondaryGreen,
        onGreenNavy: onGreenNavy,
      ));
    }

    // Next month overflow days (fill grid to multiple of 7, at least 35 days)
    final totalCells = dayTiles.length;
    final targetCells = totalCells <= 35 ? 35 : 42;
    final remaining = targetCells - totalCells;
    for (int dayNum = 1; dayNum <= remaining; dayNum++) {
      final nextDate = DateTime(_currentMonth.year, _currentMonth.month + 1, dayNum);
      dayTiles.add(_buildDayCell(
        date: nextDate,
        dayNumber: dayNum,
        isCurrentMonth: false,
        isDark: isDark,
        textPrimary: textPrimary,
        dayTileBg: dayTileBg,
        dayTileBorder: dayTileBorder,
        primaryGreen: primaryGreen,
        secondaryGreen: secondaryGreen,
        onGreenNavy: onGreenNavy,
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Weekday row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((w) {
            return Expanded(
              child: Center(
                child: Text(
                  w,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // 7-Column Days Grid
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.0,
          children: dayTiles,
        ),
      ],
    );
  }

  Widget _buildDayCell({
    required DateTime date,
    required int dayNumber,
    required bool isCurrentMonth,
    required bool isDark,
    required Color textPrimary,
    required Color dayTileBg,
    required Color dayTileBorder,
    required Color primaryGreen,
    required Color secondaryGreen,
    required Color onGreenNavy,
  }) {
    final dOnly = _dateOnly(date);
    final isDisabled = dOnly.isBefore(_firstDateOnly) || dOnly.isAfter(_lastDateOnly);
    final isToday = dOnly == _today;

    final isStart = _startDate != null && dOnly == _startDate;
    final isEnd = _endDate != null && dOnly == _endDate;
    final isInRange = _startDate != null &&
        _endDate != null &&
        dOnly.isAfter(_startDate!) &&
        dOnly.isBefore(_endDate!);

    BoxDecoration decoration;
    Color textColor;
    FontWeight fontWeight = FontWeight.w600;

    if (isStart || isEnd) {
      // Solid green button appearance (matching Image 2, changed from blue to green)
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
      textColor = onGreenNavy;
      fontWeight = FontWeight.w800;
    } else if (isInRange) {
      // Soft green tint for in-between range days
      decoration = BoxDecoration(
        color: primaryGreen.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(6),
      );
      textColor = isDark ? Colors.white : const Color(0xFF0F172A);
      fontWeight = FontWeight.w700;
    } else if (isToday) {
      decoration = BoxDecoration(
        color: dayTileBg,
        border: Border.all(color: primaryGreen, width: 1.6),
        borderRadius: BorderRadius.circular(10),
      );
      textColor = isDark ? primaryGreen : const Color(0xFF00897B);
      fontWeight = FontWeight.w800;
    } else if (!isCurrentMonth) {
      decoration = BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      );
      textColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
      fontWeight = FontWeight.w500;
    } else {
      decoration = BoxDecoration(
        color: dayTileBg,
        border: Border.all(color: dayTileBorder, width: 1),
        borderRadius: BorderRadius.circular(10),
      );
      textColor = textPrimary;
      fontWeight = FontWeight.w600;
    }

    if (isDisabled) {
      textColor = isDark ? Colors.white24 : const Color(0xFFE2E8F0);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : () => _onDaySelected(dOnly),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: decoration,
          alignment: Alignment.center,
          child: Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthsView({
    required String locale,
    required bool isDark,
    required Color textPrimary,
    required Color primaryGreen,
    required Color onGreenNavy,
  }) {
    final months = List.generate(12, (i) => _getShortMonthName(i + 1, locale));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, idx) {
        final isSelected = _currentMonth.month == idx + 1;
        return Material(
          color: isSelected
              ? primaryGreen
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, idx + 1, 1);
                _view = _PickerView.days;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? primaryGreen
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Text(
                months[idx],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? onGreenNavy : textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearsView({
    required bool isDark,
    required Color textPrimary,
    required Color primaryGreen,
    required Color onGreenNavy,
  }) {
    final startYear = _yearScrollAnchor - 5;
    final years = List.generate(12, (i) => startYear + i);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, idx) {
        final yr = years[idx];
        final isSelected = _currentMonth.year == yr;
        final isDisabled = yr < _firstDateOnly.year || yr > _lastDateOnly.year;

        return Material(
          color: isSelected
              ? primaryGreen
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isDisabled
                ? null
                : () {
                    setState(() {
                      _currentMonth = DateTime(yr, _currentMonth.month, 1);
                      _view = _PickerView.days;
                    });
                  },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? primaryGreen
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Text(
                '$yr',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isDisabled
                      ? (isDark ? Colors.white24 : const Color(0xFFCBD5E1))
                      : isSelected
                          ? onGreenNavy
                          : textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooterRow({
    required AttendanceProvider provider,
    required String locale,
    required bool isDark,
    required Color primaryGreen,
    required Color secondaryGreen,
    required Color onGreenNavy,
    required Color textMuted,
  }) {
    String rangeSummary = '';
    if (_startDate != null) {
      if (_endDate != null && _endDate != _startDate) {
        final days = _endDate!.difference(_startDate!).inDays + 1;
        rangeSummary =
            '${_getShortMonthName(_startDate!.month, locale)} ${_startDate!.day} - ${_getShortMonthName(_endDate!.month, locale)} ${_endDate!.day}, ${_endDate!.year} ($days d)';
      } else {
        rangeSummary =
            '${_getMonthName(_startDate!.month, locale)} ${_startDate!.day}, ${_startDate!.year}';
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rangeSummary.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rangeSummary,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? primaryGreen : const Color(0xFF00897B),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: TextButton.styleFrom(
                foregroundColor: textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                provider.translate('cancel').isNotEmpty ? provider.translate('cancel') : 'Cancel',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryGreen, secondaryGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _startDate != null ? _onConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: onGreenNavy,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  provider.translate('save').isNotEmpty ? provider.translate('save') : 'Apply',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Displays a compact floating calendar dialog for selecting a single date
/// styled after modern sleek mobile/web designs using the app's teal/green branding.
Future<DateTime?> showCompactDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  DateTime? currentDate,
  String? title,
}) async {
  final now = DateTime.now();
  final fDate = firstDate ?? DateTime(now.year - 10, 1, 1);
  final lDate = lastDate ?? DateTime(now.year + 10, 12, 31);
  final init = initialDate ?? now;

  final picked = await showDialog<DateTimeRange>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CompactDatePickerDialog(
      initialStartDate: init,
      initialEndDate: init,
      firstDate: fDate,
      lastDate: lDate,
      currentDate: currentDate ?? now,
      isSingleDateOnly: true,
      title: title,
    ),
  );

  return picked?.start;
}

/// Displays a compact floating calendar dialog for selecting a date range
/// (or single date if requested) that NEVER goes full-screen, matching the
/// sleek floating card design with the app's teal/green brand colors.
Future<DateTimeRange?> showCompactDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  DateTime? initialStartDate,
  DateTime? initialEndDate,
  DateTime? firstDate,
  DateTime? lastDate,
  DateTime? currentDate,
  bool isSingleDateOnly = false,
  String? title,
}) async {
  final now = DateTime.now();
  final fDate = firstDate ?? DateTime(now.year - 5, 1, 1);
  final lDate = lastDate ?? DateTime(now.year + 5, 12, 31);

  return await showDialog<DateTimeRange>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CompactDatePickerDialog(
      initialStartDate: initialStartDate ?? initialDateRange?.start,
      initialEndDate: initialEndDate ?? initialDateRange?.end,
      firstDate: fDate,
      lastDate: lDate,
      currentDate: currentDate ?? now,
      isSingleDateOnly: isSingleDateOnly,
      title: title,
    ),
  );
}
