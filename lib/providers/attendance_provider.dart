import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_record.dart';
import '../models/hr_models.dart';
import '../models/request_model.dart';
import '../models/translation_keys.dart';
import '../services/firebase_service.dart';
import '../models/company_license.dart';
import '../models/chat_message.dart';
import '../models/app_notification.dart';
import '../services/web_notification_helper.dart';
import '../widgets/web_notification_toast.dart';
import '../main.dart';
import '../screens/chat_room_screen.dart';
import '../services/face_recognition_service.dart';
import '../services/fcm_push_service.dart';
import '../models/deleted_punch_model.dart';
import '../services/wifi_detector_service.dart';

class AttendanceProvider with ChangeNotifier {
  // User Profile Data
  String _userName = 'Jane Smith';
  String _userTitle = 'HR Manager';
  String _employeeId =
      'emp_2'; // Aligned to emp_2 (HR Manager) to match Firestore seed
  String _email = 'jane.smith@company.com';
  String _department = 'Human Resources';
  String _position = 'HR Manager';
  String? _avatarPath;

  String _role = 'hr';

  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, List<Request>> _allRequestsMap = {};
  String _currentLanguage = 'en';
  String _themePreference = 'light';
  bool _isLoading = false;
  bool _isLoggedIn = false;
  final List<StreamSubscription> _subscriptions = [];

  bool get isLoggedIn => _isLoggedIn;

  void _syncCurrentEmployeeInfo() {
    if (_employees.isNotEmpty && _employeeId.isNotEmpty) {
      CompanyEmployee? match;
      for (var e in _employees) {
        if (e.id == _employeeId) {
          match = e;
          break;
        }
      }
      if (match != null) {
        _userName = match.name;
        _userTitle = match.position;
        _position = match.position;
        _email = match.email;
        _role = match.role;
        _department = match.structureId ?? match.position;
        if (match.avatarUrl != null && match.avatarUrl!.isNotEmpty) {
          _avatarPath = match.avatarUrl;
        }
        final langPref = match.languagePreference;
        if (langPref.isNotEmpty && _currentLanguage != langPref) {
          _currentLanguage = langPref;
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('app_language', langPref);
          });
        }
        final themePref = match.themePreference;
        if (themePref.isNotEmpty && _themePreference != themePref) {
          _themePreference = themePref;
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('app_theme_preference', themePref);
          });
        }
        if (_isLoggedIn) {
          _saveAuthSession(
            true,
            match.id,
            name: match.name,
            email: match.email,
            position: match.position,
            role: match.role,
            department: match.structureId ?? match.position,
            avatarUrl: match.avatarUrl,
            themePreference: match.themePreference,
          );
        }
      }
      // Note: If match is null (e.g. employee list still streaming from Firestore),
      // we purposefully preserve _employeeId so it is not hijacked or replaced.
    }
  }

  Future<void> _saveAuthSession(
    bool loggedIn,
    String empId, {
    String? name,
    String? email,
    String? position,
    String? role,
    String? department,
    String? avatarUrl,
    String? themePreference,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', loggedIn);
      await prefs.setString('app_language', _currentLanguage);
      await prefs.setString('app_theme_preference', _themePreference);
      if (loggedIn) {
        await prefs.setString('loggedInEmployeeId', empId);
        if (name != null) await prefs.setString('loggedInUserName', name);
        if (email != null) await prefs.setString('loggedInEmail', email);
        if (position != null) {
          await prefs.setString('loggedInPosition', position);
        }
        if (role != null) {
          await prefs.setString('loggedInRole', role);
        }
        if (department != null) {
          await prefs.setString('loggedInDepartment', department);
        }
        if (avatarUrl != null) {
          await prefs.setString('user_avatar_$empId', avatarUrl);
        }
        if (themePreference != null && themePreference.isNotEmpty) {
          await prefs.setString('app_theme_preference', themePreference);
          _themePreference = themePreference;
        }
      } else {
        await prefs.remove('loggedInEmployeeId');
        await prefs.remove('loggedInUserName');
        await prefs.remove('loggedInEmail');
        await prefs.remove('loggedInPosition');
        await prefs.remove('loggedInRole');
        await prefs.remove('loggedInDepartment');
      }
    } catch (e) {
      debugPrint('Error saving auth session: $e');
    }
  }

  Future<void> _loadAuthSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('app_language');
      if (savedLang != null && savedLang.isNotEmpty) {
        _currentLanguage = savedLang;
      }
      final savedTheme = prefs.getString('app_theme_preference');
      if (savedTheme != null && savedTheme.isNotEmpty) {
        _themePreference = savedTheme;
      }
      final savedCompany = prefs.getString('app_company_code');
      if (savedCompany != null && savedCompany.isNotEmpty) {
        _currentCompanyCode = savedCompany;
      }
      await loadCompanyLicense(_currentCompanyCode);
      final isLoggedInSaved = prefs.getBool('isLoggedIn') ?? false;
      final savedEmployeeId = prefs.getString('loggedInEmployeeId');
      final savedName = prefs.getString('loggedInUserName');
      final savedEmail = prefs.getString('loggedInEmail');
      final savedPosition = prefs.getString('loggedInPosition');
      final savedRole = prefs.getString('loggedInRole');
      final savedDepartment = prefs.getString('loggedInDepartment');

      if (isLoggedInSaved) {
        _isLoggedIn = true;
        if (savedEmployeeId != null && savedEmployeeId.isNotEmpty) {
          _employeeId = savedEmployeeId;
        }
        if (savedName != null && savedName.isNotEmpty) {
          _userName = savedName;
        }
        if (savedEmail != null && savedEmail.isNotEmpty) {
          _email = savedEmail;
        }
        if (savedPosition != null && savedPosition.isNotEmpty) {
          _position = savedPosition;
          _userTitle = savedPosition;
        }
        if (savedRole != null && savedRole.isNotEmpty) {
          _role = savedRole;
        }
        if (savedDepartment != null && savedDepartment.isNotEmpty) {
          _department = savedDepartment;
        }
        final savedAvatar = prefs.getString('user_avatar_$_employeeId');
        if (savedAvatar != null && savedAvatar.isNotEmpty) {
          _avatarPath = savedAvatar;
        }
        _syncCurrentEmployeeInfo();
        notifyListeners();
      } else if ((savedLang != null && savedLang.isNotEmpty) || (savedTheme != null && savedTheme.isNotEmpty)) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading auth session: $e');
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
    String? companyCode,
  }) async {
    final err = await loginWithResult(
      identifier: identifier,
      password: password,
      companyCode: companyCode,
    );
    return err == null;
  }

  Future<String?> loginWithResult({
    required String identifier,
    required String password,
    String? companyCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final code = (companyCode ?? _currentCompanyCode).trim().toLowerCase();
      if (code.isNotEmpty && code != _currentCompanyCode) {
        await setCompanyCode(code);
      }

      // Check license validity
      if (_currentLicense != null) {
        if (!_currentLicense!.isActive) {
          _isLoading = false;
          notifyListeners();
          return translate('account_suspended');
        }
        if (_currentLicense!.isHardLocked) {
          final expStr = DateFormat('yyyy-MM-dd').format(_currentLicense!.subscriptionExpiresAt);
          _isLoading = false;
          notifyListeners();
          return translate('subscription_expired').replaceAll('{date}', expStr);
        }
      }

      final input = identifier.trim().toLowerCase();
      int matchIndex = _employees.indexWhere(
        (e) =>
            (e.email.toLowerCase() == input ||
                e.id.toLowerCase() == input ||
                e.name.toLowerCase() == input) &&
            (e.password == null || e.password == password),
      );

      // Default Admin Auto-Provisioning for newly created client companies
      if (matchIndex == -1 &&
          password == 'admin123' &&
          (input == 'admin' ||
              input == 'admin@$code.com' ||
              input == '${code}_admin' ||
              input == 'admin@company.com')) {
        final compName = _currentLicense?.companyName ?? code.toUpperCase();
        final autoAdmin = CompanyEmployee(
          id: '${code}_admin',
          name: '$compName Admin',
          email: 'admin@$code.com',
          position: 'Company Administrator',
          role: 'admin',
          password: 'admin123',
          companyCode: code,
          startDate: DateTime.now().toIso8601String().split('T')[0],
          positionStartDate: DateTime.now().toIso8601String().split('T')[0],
          groupStartDate: DateTime.now().toIso8601String().split('T')[0],
          positionHistory: [],
          groupHistory: [],
          salaryHistory: [],
        );
        _employees.add(autoAdmin);
        if (_firebaseService.isAvailable) {
          _firebaseService.saveEmployee(autoAdmin);
        }
        matchIndex = _employees.length - 1;
      }

      if (matchIndex != -1) {
        final match = _employees[matchIndex];
        if (match.disabled) {
          _isLoading = false;
          notifyListeners();
          return translate('prevent_login_clocking');
        }

        _employeeId = match.id;
        _userName = match.name;
        _userTitle = match.position;
        _position = match.position;
        _email = match.email;
        if (match.languagePreference.isNotEmpty) {
          _currentLanguage = match.languagePreference;
        }
        if (match.themePreference.isNotEmpty) {
          _themePreference = match.themePreference;
        }
        _role = match.role;
        _department = match.structureId ?? match.position;
        if (match.avatarUrl != null && match.avatarUrl!.isNotEmpty) {
          _avatarPath = match.avatarUrl;
        }
        _isLoggedIn = true;
        _isLoading = false;
        await _saveAuthSession(
          true,
          _employeeId,
          name: _userName,
          email: _email,
          position: _position,
          role: match.role,
          department: match.structureId ?? match.position,
          avatarUrl: match.avatarUrl,
          themePreference: match.themePreference,
        );

        _records.clear();
        await _setupFirestoreListeners();
        recalculateAllStats();
        notifyListeners();
        return null; // Success!
      }

      // If no exact match, login fails
      _isLoading = false;
      notifyListeners();
      return 'Invalid email or password. Please try again.';
    } catch (e) {
      debugPrint('Login error: $e');
      _isLoading = false;
      notifyListeners();
      return 'Login error: $e';
    }
  }

  Future<void> loginAsEmployee(CompanyEmployee employee) async {
    _employeeId = employee.id;
    _userName = employee.name;
    _userTitle = employee.position;
    _position = employee.position;
    _email = employee.email;
    _role = employee.role;
    _department = employee.structureId ?? employee.position;
    if (employee.avatarUrl != null && employee.avatarUrl!.isNotEmpty) {
      _avatarPath = employee.avatarUrl;
    }
    if (employee.languagePreference.isNotEmpty) {
      _currentLanguage = employee.languagePreference;
    }
    if (employee.themePreference.isNotEmpty) {
      _themePreference = employee.themePreference;
    }
    _isLoggedIn = true;
    await _saveAuthSession(
      true,
      _employeeId,
      name: _userName,
      email: _email,
      position: _position,
      role: employee.role,
      department: employee.structureId ?? employee.position,
      avatarUrl: employee.avatarUrl,
      themePreference: employee.themePreference,
    );

    _records.clear();
    await _setupFirestoreListeners();
    recalculateAllStats();
    notifyListeners();
  }

  Future<void> logout() async {
    final current = currentEmployee;
    if (current != null && current.fcmToken != null && current.fcmToken!.isNotEmpty) {
      try {
        final clearedEmp = current.copyWith(
          fcmToken: '',
          overrideFcmToken: true,
        );
        await updateEmployee(clearedEmp);
      } catch (e) {
        debugPrint('Error clearing FCM token on logout: $e');
      }
    }
    for (var sub in _chatSubscriptionsMap.values) {
      sub.cancel();
    }
    _chatSubscriptionsMap.clear();
    _chatMessagesMap.clear();
    _chatRoomContactIds.clear();

    _isLoggedIn = false;
    _saveAuthSession(false, '');
    notifyListeners();
  }

  // Chat state
  final Map<String, List<ChatMessage>> _chatMessagesMap = {};
  final Map<String, StreamSubscription> _chatSubscriptionsMap = {};
  final Set<String> _chatRoomContactIds = {};

  String? _activeChatContactId;
  String? get activeChatContactId => _activeChatContactId;
  void setActiveChatContactId(String? contactId) {
    _activeChatContactId = contactId;
  }

  String? _currentDeviceFcmToken;
  String? get currentDeviceFcmToken => _currentDeviceFcmToken;

  // In-app Notifications
  List<AppNotification>? _notifications;
  List<AppNotification> get notifications => _notifications ??= [];

  int get unreadNotificationCount {
    _notifications ??= [];
    int count = _notifications!.where((n) => !n.isRead).length;
    final myId = _employeeId.trim().toLowerCase();
    if (myId.isNotEmpty) {
      for (var messages in _chatMessagesMap.values) {
        if (messages.any((m) => m.receiverId.trim().toLowerCase() == myId && !m.isRead)) {
          count++;
        }
      }
    }
    return count;
  }

  void markNotificationAsRead(String id) {
    _notifications ??= [];
    final index = _notifications!.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications![index].isRead = true;
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    _notifications ??= [];
    for (var n in _notifications!) {
      n.isRead = true;
    }
    notifyListeners();
  }

  bool get hasUnreadMessages {
    final myId = _employeeId.trim().toLowerCase();
    if (myId.isEmpty) return false;
    for (var messages in _chatMessagesMap.values) {
      if (messages.any((m) => m.receiverId.trim().toLowerCase() == myId && !m.isRead)) {
        return true;
      }
    }
    return false;
  }

  int getUnreadCountForContact(dynamic contactId) {
    final cId = contactId.toString().trim().toLowerCase();
    final myId = _employeeId.trim().toLowerCase();
    if (cId.isEmpty || myId.isEmpty) return 0;
    
    // Look up in chat messages map by exact key or case-insensitive match
    List<ChatMessage>? messages = _chatMessagesMap[contactId.toString()];
    if (messages == null) {
      for (var entry in _chatMessagesMap.entries) {
        if (entry.key.trim().toLowerCase() == cId) {
          messages = entry.value;
          break;
        }
      }
    }
    if (messages == null) return 0;
    return messages.where((m) => m.receiverId.trim().toLowerCase() == myId && !m.isRead).length;
  }

  // Clock State
  bool _isClockedIn = false;
  AttendanceRecord? _activeRecord;
  final List<AttendanceRecord> _records = [];

  final List<AttendanceRecord> _allCompanyRecords = [];
  final List<Request> _allCompanyRequests = [];
  final Set<String> _deletedPunchSignatures = {};

  bool isPunchDeleted(String employeeId, DateTime punchTime) {
    final key = '${employeeId.trim().toLowerCase()}_${punchTime.year}_${punchTime.month}_${punchTime.day}_${punchTime.hour}_${punchTime.minute}';
    return _deletedPunchSignatures.contains(key);
  }

  void recordDeletedPunchSignature(String employeeId, DateTime punchTime) {
    final key = '${employeeId.trim().toLowerCase()}_${punchTime.year}_${punchTime.month}_${punchTime.day}_${punchTime.hour}_${punchTime.minute}';
    _deletedPunchSignatures.add(key);
  }

  // Selected Month for Payroll/History
  DateTime _selectedMonth = DateTime.now();

  // Statistics Baseline (from screenshots)
  double _weeklyHours = 38.5;
  double _monthlyEarnings = 3240.0;
  int _daysWorked = 18;
  double _overtimeHours = 4.5;
  double _monthlyPenalties = 0.0;
  double _incrementalSalary = 0.0;
  double _decrementalSalary = 0.0;
  double _salaryCalcByDay = 0.0;
  double _overtimeValue = 0.0;
  double _attendanceDeficit = 0.0;
  double _attendanceDeficitHours = 0.0;
  double _hourlyRate = 0.0;

  double _foodAllowance = 0.0;
  double _transportationAllowance = 0.0;
  double _otherAllowance = 0.0;
  bool _hasInsurance = false;
  double _insuranceSalary = 0.0;
  double _insuranceEmployee = 0.0;
  double _insuranceCompany = 0.0;

  // HR System Lists
  final List<OrgStructure> _structures = [];
  final List<WorkShift> _shifts = [];
  final List<EmployeeGroup> _groups = [];
  final List<CompanyEmployee> _employees = [];
  final List<Holiday> _holidays = [];
  final List<WorkLocation> _locations = [];
  final List<PayrollAdjustment> _payrollAdjustments = [];
  final List<PayrollMonthClosure> _payrollClosures = [];
  CompanyProfile? _companyProfile;

  // --- SaaS Multi-Tenancy & Licensing ---
  String _currentCompanyCode = 'amada';
  CompanyLicense? _currentLicense;
  StreamSubscription<CompanyLicense?>? _licenseSubscription;
  StreamSubscription<List<PayrollMonthClosure>>? _payrollClosuresSubscription;

  final List<CompanyLicense> _allCompanies = [];
  List<CompanyLicense> get allCompanies => List.unmodifiable(_allCompanies);

  String get currentCompanyCode => _currentCompanyCode;
  CompanyLicense? get currentLicense => _currentLicense;
  int get activeEmployeesCount => employees.where((e) => !e.disabled).length;
  int get maxActiveUsers => _currentLicense?.maxActiveUsers ?? 50;

  bool get canAddActiveEmployee {
    if (_currentLicense == null) return true;
    if (_currentLicense!.maxActiveUsers <= 0) return true;
    return activeEmployeesCount < _currentLicense!.maxActiveUsers;
  }

  bool get isCompanySubscriptionValid =>
      _currentLicense == null || !_currentLicense!.isHardLocked;

  // Getters
  List<PayrollAdjustment> get payrollAdjustments => _payrollAdjustments;
  List<PayrollMonthClosure> get payrollClosures => List.unmodifiable(
        _payrollClosures.where((c) =>
            _currentCompanyCode == 'all' ||
            c.companyCode.isEmpty ||
            c.companyCode.toLowerCase() == _currentCompanyCode.toLowerCase()),
      );

  PayrollMonthClosure? getClosureForMonthStr(String yearMonth) {
    return _payrollClosures
        .where((c) =>
            c.yearMonth == yearMonth &&
            (_currentCompanyCode == 'all' ||
                c.companyCode.isEmpty ||
                c.companyCode.toLowerCase() == _currentCompanyCode.toLowerCase()))
        .firstOrNull;
  }

  PayrollMonthClosure? getClosureForMonth(DateTime date) {
    final ym = DateFormat('yyyy-MM').format(date);
    return getClosureForMonthStr(ym);
  }

  bool isMonthClosedStr(String yearMonth) {
    final c = getClosureForMonthStr(yearMonth);
    return c != null && c.isClosed;
  }

  bool isMonthClosed(DateTime date) {
    final ym = DateFormat('yyyy-MM').format(date);
    return isMonthClosedStr(ym);
  }

  DateTime? parseFlexibleDate(dynamic dateInput) {
    if (dateInput == null) return null;
    if (dateInput is DateTime) return dateInput;
    final str = dateInput.toString().trim();
    if (str.isEmpty) return null;

    final iso = DateTime.tryParse(str);
    if (iso != null) return iso;

    final patterns = [
      'MMMM d, yyyy',
      'MMMM dd, yyyy',
      'd MMMM yyyy',
      'dd MMMM yyyy',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'MMMM yyyy',
      'yyyy-MM',
      'MMM d, yyyy',
      'd MMM yyyy',
    ];
    for (final pattern in patterns) {
      try {
        return DateFormat(pattern, 'en_US').parseLoose(str);
      } catch (_) {}
      try {
        return DateFormat(pattern).parseLoose(str);
      } catch (_) {}
    }

    final monthMap = {
      'january': 1, 'jan': 1,
      'february': 2, 'feb': 2,
      'march': 3, 'mar': 3,
      'april': 4, 'apr': 4,
      'may': 5,
      'june': 6, 'jun': 6,
      'july': 7, 'jul': 7,
      'august': 8, 'aug': 8,
      'september': 9, 'sep': 9, 'sept': 9,
      'october': 10, 'oct': 10,
      'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
    };
    final lower = str.toLowerCase();
    int? foundMonth;
    for (final entry in monthMap.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(lower)) {
        foundMonth = entry.value;
        break;
      }
    }
    if (foundMonth != null) {
      final yearMatch = RegExp(r'\b(20\d\d)\b').firstMatch(str);
      final year = yearMatch != null ? int.parse(yearMatch.group(1)!) : _selectedMonth.year;
      final dayMatches = RegExp(r'\b(\d{1,2})\b').allMatches(str);
      int day = 1;
      for (final m in dayMatches) {
        if (m.group(1) != yearMatch?.group(1)) {
          day = int.tryParse(m.group(1)!) ?? 1;
          break;
        }
      }
      return DateTime(year, foundMonth, day.clamp(1, 28));
    }

    return null;
  }

  bool isDateStringInClosedMonth(dynamic dateInput) {
    if (dateInput == null) return false;
    final str = dateInput.toString().trim();
    if (str.isEmpty) return false;

    if (str.contains(' - ')) {
      final parts = str.split(' - ');
      final startPart = parts.first.trim();
      final endPart = parts.last.trim();

      final startDate = parseFlexibleDate(startPart);
      final endDate = parseFlexibleDate(endPart);

      if (startDate != null && isMonthClosed(startDate)) return true;
      if (endDate != null && isMonthClosed(endDate)) return true;

      if (startDate != null && endDate != null && endDate.isAfter(startDate)) {
        var cur = DateTime(startDate.year, startDate.month, 1);
        final endMonth = DateTime(endDate.year, endDate.month, 1);
        while (!cur.isAfter(endMonth)) {
          if (isMonthClosed(cur)) return true;
          cur = DateTime(cur.year, cur.month + 1, 1);
        }
      }

      final ymMatches = RegExp(r'(\d{4})[/-](\d{2})').allMatches(str);
      for (final m in ymMatches) {
        final ym = '${m.group(1)}-${m.group(2)}';
        if (isMonthClosedStr(ym)) return true;
      }

      return false;
    }

    final dt = parseFlexibleDate(str);
    if (dt != null) {
      return isMonthClosed(dt);
    }

    final ymMatch = RegExp(r'(\d{4})[/-](\d{2})').firstMatch(str);
    if (ymMatch != null) {
      final ym = '${ymMatch.group(1)}-${ymMatch.group(2)}';
      return isMonthClosedStr(ym);
    }

    return false;
  }

  String get userName => _userName;
  String get userTitle => _userTitle;
  String get employeeId => _employeeId;
  String get email => _email;
  String get department {
    if (_department.isNotEmpty) {
      final struct = _structures.where((s) => s.id == _department).firstOrNull;
      if (struct != null) return struct.name;
      if (!_department.startsWith('struct_')) return _department;
    }
    final emp = currentEmployee;
    if (emp?.structureId != null && emp!.structureId!.isNotEmpty) {
      final struct = _structures.where((s) => s.id == emp.structureId).firstOrNull;
      if (struct != null) return struct.name;
    }
    return _position.isNotEmpty ? _position : 'General';
  }
  String get position => _position;
  String? get avatarPath => _avatarPath ?? currentEmployee?.avatarUrl;

  bool get isClockedIn => _isClockedIn;
  AttendanceRecord? get activeRecord => _activeRecord;
  List<AttendanceRecord> get records => _records;
  List<AttendanceRecord> get allCompanyRecords => _allCompanyRecords;
  List<Request> get allCompanyRequests => _allCompanyRequests;
  DateTime get selectedMonth => _selectedMonth;

  void setSelectedMonth(DateTime month) {
    _selectedMonth = month;
    recalculateAllStats();
    notifyListeners();
  }

  double get weeklyHours => _weeklyHours;
  double get monthlyEarnings => _monthlyEarnings;
  int get daysWorked => _daysWorked;
  double get overtimeHours => _overtimeHours;
  double get monthlyPenalties => _monthlyPenalties;

  double get incrementalSalary => _incrementalSalary;
  double get decrementalSalary => _decrementalSalary;
  double get salaryCalcByDay => _salaryCalcByDay;
  double get overtimeValue => _overtimeValue;
  double get attendanceDeficit => _attendanceDeficit;
  double get attendanceDeficitHours => _attendanceDeficitHours;
  double get hourlyRate => _hourlyRate;
  double get foodAllowance => _foodAllowance;
  double get transportationAllowance => _transportationAllowance;
  double get otherAllowance => _otherAllowance;
  bool get hasInsurance => _hasInsurance;
  double get insuranceSalary => _insuranceSalary;
  double get insuranceEmployee => _insuranceEmployee;
  double get insuranceCompany => _insuranceCompany;

  static bool isSuperAdminUser(CompanyEmployee? emp) {
    if (emp == null) return false;
    final id = emp.id.toLowerCase().trim();
    final email = emp.email.toLowerCase().trim();
    final role = emp.role.toLowerCase().trim();
    final pos = emp.position.toLowerCase().trim();
    return id == 'admin_super_account' ||
        email == 'admin@company.com' ||
        role == 'super_admin' ||
        role == 'superadmin' ||
        pos == 'super administrator' ||
        pos == 'super admin';
  }

  List<OrgStructure> get structures => List.unmodifiable(
        _structures.where((s) =>
            _currentCompanyCode == 'all' ||
            s.companyCode.isEmpty ||
            s.companyCode.toLowerCase() == _currentCompanyCode.toLowerCase()),
      );
  List<WorkShift> get shifts => List.unmodifiable(
        _shifts.where((s) =>
            _currentCompanyCode == 'all' ||
            s.companyCode.isEmpty ||
            s.companyCode.toLowerCase() == _currentCompanyCode.toLowerCase()),
      );
  List<EmployeeGroup> get groups => List.unmodifiable(
        _groups.where((g) =>
            _currentCompanyCode == 'all' ||
            g.companyCode.isEmpty ||
            g.companyCode.toLowerCase() == _currentCompanyCode.toLowerCase()),
      );
  List<CompanyEmployee> get allEmployees => List.unmodifiable(_employees);
  List<CompanyEmployee> get employees => List.unmodifiable(
        _employees.where((e) {
          if (isSuperAdminUser(e)) return false;
          if (_currentCompanyCode == 'all') return true;
          return e.companyCode.isEmpty ||
              e.companyCode.toLowerCase() == _currentCompanyCode.toLowerCase();
        }),
      );
  List<Holiday> get holidays => List.unmodifiable(
        _holidays.where((h) =>
            _currentCompanyCode == 'all' ||
            h.companyCode.isEmpty ||
            h.companyCode.toLowerCase() == _currentCompanyCode.toLowerCase()),
      );
  List<WorkLocation> get locations => List.unmodifiable(
        _locations.where((l) =>
            _currentCompanyCode == 'all' ||
            l.companyCode.isEmpty ||
            l.companyCode.toLowerCase() == _currentCompanyCode.toLowerCase()),
      );
  List<Request> get requests => _allRequestsMap[_employeeId] ?? [];
  String get currentLanguage => _currentLanguage;
  bool get isLoading => _isLoading;
  FirebaseService get firebaseService => _firebaseService;
  CompanyProfile? get companyProfile => _companyProfile;

  Future<void> loadCompanyLicense(String companyCode) async {
    final clean = companyCode.trim().toLowerCase();
    _currentCompanyCode = clean.isEmpty ? 'amada' : clean;
    if (_currentCompanyCode == 'all') {
      _licenseSubscription?.cancel();
      _currentLicense = CompanyLicense.defaultLicense(
        code: 'all',
        name: 'All Companies (Master View)',
        maxUsers: 99999,
      );
      _companyProfile = CompanyProfile(
        name: 'All Companies',
        address: 'Master Multi-Tenant Network',
        email: 'admin@company.com',
        phone: '',
      );
      notifyListeners();
      return;
    }
    if (_firebaseService.isAvailable) {
      final lic = await _firebaseService.getCompanyLicense(_currentCompanyCode);
      if (lic != null) {
        _currentLicense = lic;
        _syncProfileFromLicense(lic);
      } else {
        final defaultLic = CompanyLicense.defaultLicense(code: _currentCompanyCode);
        await _firebaseService.saveCompanyLicense(defaultLic);
        _currentLicense = defaultLic;
      }
      _listenToCompanyLicense(_currentCompanyCode);
    } else {
      _currentLicense ??= CompanyLicense.defaultLicense(code: _currentCompanyCode);
      if (_currentLicense != null) {
        _syncProfileFromLicense(_currentLicense!);
      }
    }
    notifyListeners();
  }

  void _listenToCompanyLicense(String companyCode) {
    _licenseSubscription?.cancel();
    _licenseSubscription = _firebaseService.streamCompanyLicense(companyCode).listen((lic) {
      if (lic != null) {
        _currentLicense = lic;
        _syncProfileFromLicense(lic);
        notifyListeners();
      }
    });
  }

  void _syncProfileFromLicense(CompanyLicense lic) {
    if ((lic.logoBase64 != null && lic.logoBase64!.isNotEmpty) || lic.companyName.isNotEmpty) {
      _companyProfile = CompanyProfile(
        name: lic.companyName.isNotEmpty ? lic.companyName : (_companyProfile?.name ?? 'Company'),
        address: lic.address ?? _companyProfile?.address ?? '',
        email: lic.ownerEmail ?? _companyProfile?.email,
        phone: lic.ownerPhone ?? _companyProfile?.phone,
        logoBase64: lic.logoBase64 ?? _companyProfile?.logoBase64,
      );
    }
  }

  Future<void> setCompanyCode(String code) async {
    final clean = code.trim().toLowerCase();
    if (clean.isEmpty) return;
    final bool changed = _currentCompanyCode != clean;
    _currentCompanyCode = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_company_code', clean);
    } catch (_) {}
    await loadCompanyLicense(clean);
    if (changed) {
      await _loadPayrollClosuresFromPrefs();
      _listenToPayrollClosures();
      await _setupFirestoreListeners();
    }
  }

  void _listenToPayrollClosures() {
    _payrollClosuresSubscription?.cancel();
    if (_firebaseService.isAvailable) {
      final code = _currentCompanyCode == 'all' ? null : _currentCompanyCode;
      _payrollClosuresSubscription = _firebaseService
          .streamPayrollClosures(companyCode: code)
          .listen((data) {
        _payrollClosures.clear();
        _payrollClosures.addAll(data);
        _savePayrollClosuresToPrefs();
        recalculateAllStats();
        notifyListeners();
      });
    }
  }

  Future<void> saveCompanyLicense(CompanyLicense license) async {
    await _firebaseService.saveCompanyLicense(license);
    if (license.companyCode.toLowerCase() == _currentCompanyCode.toLowerCase()) {
      _currentLicense = license;
      _syncProfileFromLicense(license);
      if (_firebaseService.isAvailable && _companyProfile != null) {
        await _firebaseService.saveCompanyProfile(_companyProfile!);
      }
      notifyListeners();
    }
  }

  CompanyEmployee? get currentEmployee {
    for (var e in _employees) {
      if (e.id == _employeeId) return e;
    }
    if (_employeeId.isNotEmpty) {
      return CompanyEmployee(
        id: _employeeId,
        name: _userName,
        email: _email,
        position: _position,
        role: _role,
        structureId: _department,
        avatarUrl: _avatarPath,
        themePreference: _themePreference,
        languagePreference: _currentLanguage,
      );
    }
    return null;
  }

  List<CompanyEmployee> getSubordinates(CompanyEmployee supervisor) {
    List<CompanyEmployee> subordinates = [];
    final Set<String> subordinateIds = {};

    // Direct supervised structures
    final supervisedStructures = _structures
        .where((s) => s.supervisorId == supervisor.id)
        .map((s) => s.id)
        .toList();

    for (var structId in supervisedStructures) {
      final emps = employees.where(
        (e) => e.id != supervisor.id && e.structureId == structId,
      );
      for (var e in emps) {
        if (subordinateIds.add(e.id)) {
          subordinates.add(e);
        }
      }
    }

    // Co-workers in same structure if supervisor is just regular employee
    if (supervisor.structureId != null && supervisor.structureId!.isNotEmpty) {
      final emps = employees.where(
        (e) =>
            e.id != supervisor.id &&
            e.structureId == supervisor.structureId &&
            e.role == 'employee',
      );
      for (var e in emps) {
        if (subordinateIds.add(e.id)) {
          subordinates.add(e);
        }
      }
    }

    return subordinates;
  }

  String get userRole => _role;

  bool get isSuperAdmin {
    if (isSuperAdminUser(currentEmployee)) return true;
    final r = _role.toLowerCase().trim();
    final e = _email.toLowerCase().trim();
    final id = _employeeId.toLowerCase().trim();
    final pos = _position.toLowerCase().trim();
    return r == 'super_admin' ||
        r == 'superadmin' ||
        e == 'admin@company.com' ||
        id == 'admin_super_account' ||
        pos == 'super administrator' ||
        pos == 'super admin';
  }

  bool get canEditCompanyInfo {
    return isSuperAdmin;
  }

  /// Whether the logged-in user is an HR manager/admin who can register/delete Face ID
  bool get isHRManager {
    final emp = currentEmployee;
    if (emp == null) return false;
    final role = emp.role.toLowerCase().trim();
    if (role == 'hr' || role == 'admin' || role == 'super_admin' || role == 'superadmin' || emp.email.toLowerCase() == 'admin@company.com') return true;
    final pos = emp.position.toLowerCase();
    if (pos.contains('hr') || pos.contains('human resource')) return true;
    return isSuperAdmin;
  }

  bool get isDarkMode {
    if (currentEmployee != null && currentEmployee!.themePreference.isNotEmpty) {
      return currentEmployee!.themePreference == 'dark';
    }
    return _themePreference == 'dark';
  }

  TextDirection get currentLanguageDirection {
    return (_currentLanguage == 'ar' || _currentLanguage == 'ku')
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  String translate(String key, {Map<String, String>? params}) {
    final dictionary =
        TranslationKeys.translations[_currentLanguage] ??
        TranslationKeys.translations['en']!;
    String val = dictionary[key] ?? key;
    if (params != null && params.isNotEmpty) {
      params.forEach((paramKey, paramVal) {
        val = val.replaceAll('{$paramKey}', paramVal);
      });
    }
    return val;
  }

  Future<void> setLanguage(String langCode) async {
    _currentLanguage = langCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', langCode);

      final emp = currentEmployee;
      if (emp != null) {
        final updatedEmp = emp.copyWith(languagePreference: langCode);
        final index = _employees.indexWhere((e) => e.id == emp.id);
        if (index != -1) {
          _employees[index] = updatedEmp;
        }
        await _firebaseService.saveEmployee(updatedEmp);
      }
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  Future<void> toggleTheme() async {
    final newPreference = isDarkMode ? 'light' : 'dark';
    _themePreference = newPreference;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_preference', newPreference);

      final emp = currentEmployee;
      if (emp != null) {
        final updatedEmp = emp.copyWith(themePreference: newPreference);
        final index = _employees.indexWhere((e) => e.id == emp.id);
        if (index != -1) {
          _employees[index] = updatedEmp;
        }
        await _firebaseService.saveEmployee(updatedEmp);
      }
    } catch (e) {
      debugPrint('Error persisting theme preference: $e');
    }
  }

  AttendanceProvider({
    String initialThemePreference = 'light',
    String initialLanguage = 'en',
    bool initialLoggedIn = false,
    String? initialEmployeeId,
    String? initialUserName,
    String? initialEmail,
    String? initialPosition,
    String? initialRole,
    String? initialDepartment,
    String? initialAvatarPath,
  }) {
    _themePreference = initialThemePreference;
    if (initialLanguage.isNotEmpty) {
      _currentLanguage = initialLanguage;
    }
    _isLoggedIn = initialLoggedIn;
    if (initialEmployeeId != null && initialEmployeeId.isNotEmpty) {
      _employeeId = initialEmployeeId;
    }
    if (initialUserName != null && initialUserName.isNotEmpty) {
      _userName = initialUserName;
    }
    if (initialEmail != null && initialEmail.isNotEmpty) {
      _email = initialEmail;
    }
    if (initialPosition != null && initialPosition.isNotEmpty) {
      _position = initialPosition;
      _userTitle = initialPosition;
    }
    if (initialRole != null && initialRole.isNotEmpty) {
      _role = initialRole;
    }
    if (initialDepartment != null && initialDepartment.isNotEmpty) {
      _department = initialDepartment;
    }
    if (initialAvatarPath != null && initialAvatarPath.isNotEmpty) {
      _avatarPath = initialAvatarPath;
    }
    _isLoading = _firebaseService.isAvailable;
    _initializeMockData();
    _initializeHRMockData();
    _initializeMockChats();
    _loadAuthSession();
    _loadPayrollClosuresFromPrefs();
    _initializeFirebaseAndSync();
    recalculateAllStats();
  }

  @override
  void dispose() {
    _licenseSubscription?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    for (var sub in _chatSubscriptionsMap.values) {
      sub.cancel();
    }
    _chatSubscriptionsMap.clear();
    super.dispose();
  }

  Future<void> _initializeFirebaseAndSync() async {
    await _loadAuthSession();
    if (!_firebaseService.isAvailable) {
      debugPrint('Firebase is not available. Using local mock data fallback.');
      _initializeMockRequests();
      _isLoading = false;
      notifyListeners();
      return;
    }

    debugPrint('Firebase is available. Syncing database...');
    _isLoading = true;

    // 1. Prepare default requests to seed if empty
    final defaultRequests = [
      Request(
        id: 'req_1',
        type: 'Sick Leave',
        date: 'May 14, 2026',
        duration: '1 Day',
        status: 'Approved',
      ),
      Request(
        id: 'req_2',
        type: 'Annual Leave',
        date: 'June 15 - June 18, 2026',
        duration: '4 Days',
        status: 'Pending',
      ),
      Request(
        id: 'req_3',
        type: 'Overtime Approval',
        date: 'May 28, 2026',
        duration: '2.5 Hours',
        status: 'Approved',
      ),
      Request(
        id: 'req_4',
        type: 'Forgot to Clock Out',
        date: 'May 08, 2026',
        duration: 'Correction',
        status: 'Approved',
      ),
    ];

    // Always ensure Super Admin is available in seed list if database needs initial seeding
    final seedEmployees = List<CompanyEmployee>.from(_employees);
    if (!seedEmployees.any((e) => e.email == 'admin@company.com')) {
      seedEmployees.add(
        CompanyEmployee(
          id: 'admin_super_account',
          name: 'Super Admin',
          email: 'admin@company.com',
          position: 'Super Administrator',
          role: 'admin',
          startDate: DateTime.now().toIso8601String().split('T')[0],
          positionStartDate: DateTime.now().toIso8601String().split('T')[0],
          groupStartDate: DateTime.now().toIso8601String().split('T')[0],
          positionHistory: [],
          groupHistory: [],
          salaryHistory: [],
        ),
      );
    }

    // 2. Query Firestore and update state immediately for fast, smooth startup
    try {
      await _setupFirestoreListeners();
    } catch (e) {
      debugPrint('Error loading data from Firestore: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // 3. Seed empty Firestore tables asynchronously in background without blocking startup
    unawaited(
      _firebaseService
          .seedDefaultMockData(
            structures: _structures,
            shifts: _shifts,
            groups: _groups,
            employees: seedEmployees,
            userRecords: _records,
            testUserId: _employeeId,
            userRequests: defaultRequests,
            locations: _locations,
          )
          .catchError((e) {
            debugPrint('Background seeding Firestore database completed/handled: $e');
          }),
    );
  }

  Future<void> _setupFirestoreListeners() async {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    try {
      final filterCode = _currentCompanyCode == 'all' ? null : _currentCompanyCode;

      _subscriptions.add(
        _firebaseService.streamCompanyProfile().listen((data) {
          _companyProfile = data;
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamCompanyLicenses().listen((data) {
          _allCompanies.clear();
          _allCompanies.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamStructures(companyCode: filterCode).listen((data) {
          _structures.clear();
          _structures.addAll(data);
          loadChatsForCurrentUser();
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamShifts(companyCode: filterCode).listen((data) {
          _shifts.clear();
          _shifts.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamGroups(companyCode: filterCode).listen((data) {
          _groups.clear();
          _groups.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamEmployees(companyCode: filterCode).listen((data) {
          _employees.clear();
          for (var emp in data) {
            // Auto-heal: If employee has basicSalary configured but empty salaryHistory, synthesize initial entry and persist
            if ((emp.basicSalary > 0 || emp.workingHours > 0) && emp.salaryHistory.isEmpty) {
              final initialEntry = SalaryHistoryEntry(
                basicSalary: emp.basicSalary,
                workingHours: emp.workingHours > 0 ? emp.workingHours : 160.0,
                currency: emp.salaryCurrency.isNotEmpty ? emp.salaryCurrency : 'USD',
                startDate: emp.startDate.isNotEmpty ? emp.startDate : '2024-01-01',
                endDate: null,
                foodAllowance: emp.foodAllowance,
                transportationAllowance: emp.transportationAllowance,
                otherAllowance: emp.otherAllowance,
                hasInsurance: emp.hasInsurance,
                insuranceSalary: emp.insuranceSalary,
              );
              final healedEmp = emp.copyWith(
                workingHours: emp.workingHours > 0 ? emp.workingHours : 160.0,
                salaryHistory: [initialEntry],
              );
              _employees.add(healedEmp);
              _firebaseService.saveEmployee(healedEmp);
            } else {
              _employees.add(emp);
            }
          }

          // --- ENSURE SUPER ADMIN REMAINS PERMANENTLY ---
          if (!_employees.any((e) => e.email == 'admin@company.com')) {
            final superAdmin = CompanyEmployee(
              id: 'admin_super_account',
              name: 'Super Admin',
              email: 'admin@company.com',
              position: 'Super Administrator',
              role: 'super_admin',
              password: 'admin123',
              startDate: DateTime.now().toIso8601String().split('T')[0],
              positionStartDate: DateTime.now().toIso8601String().split('T')[0],
              groupStartDate: DateTime.now().toIso8601String().split('T')[0],
              positionHistory: [],
              groupHistory: [],
              salaryHistory: [],
              companyCode: '',
            );
            _employees.add(superAdmin);
            _firebaseService.saveEmployee(superAdmin);
          }

          // --- ENSURE CLIENT COMPANY ADMIN REMAINS ---
          final code = (filterCode ?? '').trim().toLowerCase();
          if (code.isNotEmpty && code != 'all' && code != 'amada') {
            final clientAdminId = '${code}_admin';
            if (!_employees.any((e) => e.id == clientAdminId || e.email == 'admin@$code.com')) {
              final compName = _currentLicense?.companyName ?? code.toUpperCase();
              final clientAdmin = CompanyEmployee(
                id: clientAdminId,
                name: '$compName Admin',
                email: 'admin@$code.com',
                position: 'Company Administrator',
                role: 'admin',
                password: 'admin123',
                companyCode: code,
                startDate: DateTime.now().toIso8601String().split('T')[0],
                positionStartDate: DateTime.now().toIso8601String().split('T')[0],
                groupStartDate: DateTime.now().toIso8601String().split('T')[0],
                positionHistory: [],
                groupHistory: [],
                salaryHistory: [],
              );
              _employees.add(clientAdmin);
              _firebaseService.saveEmployee(clientAdmin);
            }
          }

          _syncCurrentEmployeeInfo();
          _avatarPath = currentEmployee?.avatarUrl;
          loadChatsForCurrentUser();
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamHolidays(companyCode: filterCode).listen((data) {
          _holidays.clear();
          _holidays.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamLocations(companyCode: filterCode).listen((data) {
          _locations.clear();
          _locations.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamPayrollAdjustments().listen((data) {
          _payrollAdjustments.clear();
          _payrollAdjustments.addAll(data);
          recalculateAllStats();
          notifyListeners();
        }),
      );

      _listenToPayrollClosures();

      _subscriptions.add(
        _firebaseService.streamUserRecords(_employeeId).listen((data) {
          _records.clear();
          _records.addAll(data);
          _restoreActiveRecordFromRecords();
          recalculateAllStats();
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamUserRequests(_employeeId).listen((data) {
          _allRequestsMap[_employeeId] = data;
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamAllRecords().listen((data) {
          _allCompanyRecords.clear();
          _allCompanyRecords.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamDeletedPunches().listen((punches) {
          _deletedPunchSignatures.clear();
          for (var p in punches) {
            final key = '${p.employeeId.trim().toLowerCase()}_${p.punchTime.year}_${p.punchTime.month}_${p.punchTime.day}_${p.punchTime.hour}_${p.punchTime.minute}';
            _deletedPunchSignatures.add(key);
          }
        }),
      );

      try {
        final initialRequests = await _firebaseService.getAllRequests();
        if (initialRequests.isNotEmpty) {
          _allCompanyRequests.clear();
          _allCompanyRequests.addAll(initialRequests);
          for (var req in initialRequests) {
            if (req.employeeId != null) {
              _allRequestsMap[req.employeeId!] ??= [];
              final existingIdx = _allRequestsMap[req.employeeId!]!.indexWhere(
                (r) => r.id == req.id,
              );
              if (existingIdx != -1) {
                _allRequestsMap[req.employeeId!]![existingIdx] = req;
              } else {
                _allRequestsMap[req.employeeId!]!.add(req);
              }
            }
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error getting initial requests: $e');
      }

      _subscriptions.add(
        _firebaseService.streamAllRequests().listen((data) {
          _allCompanyRequests.clear();
          _allCompanyRequests.addAll(data);
          for (var req in data) {
            if (req.employeeId != null) {
              _allRequestsMap[req.employeeId!] ??= [];
              final existingIdx = _allRequestsMap[req.employeeId!]!.indexWhere(
                (r) => r.id == req.id,
              );
              if (existingIdx != -1) {
                _allRequestsMap[req.employeeId!]![existingIdx] = req;
              } else {
                _allRequestsMap[req.employeeId!]!.add(req);
              }
            }
          }
          notifyListeners();
        }),
      );

      if (_employeeId.isNotEmpty) {
        _subscriptions.add(
          _firebaseService.streamUserChatContactIds(_employeeId).listen((contactIds) {
            bool hasNew = false;
            for (var cid in contactIds) {
              if (_chatRoomContactIds.add(cid)) {
                hasNew = true;
                ensureChatLoaded(cid);
              }
            }
            if (hasNew) {
              notifyListeners();
            }
          }),
        );
      }

      await loadChatsForCurrentUser();
      if (!kIsWeb) {
        await _setupPushNotifications();
      }
    } catch (e) {
      debugPrint('Error setting up Firestore listeners: $e');
      rethrow;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _setupPushNotifications() async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // On iOS, configure foreground notification presentation options
      try {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}

      // Initialize local notifications for foreground and register high-priority notification channel
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );
      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationPayload(payload);
          }
        },
      );

      // Check if app was launched via local notification tap from killed state
      try {
        final launchDetails = await _localNotificationsPlugin.getNotificationAppLaunchDetails();
        if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
          final payload = launchDetails.notificationResponse?.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationPayload(payload);
          }
        }
      } catch (e) {
        debugPrint('Error checking local notification launch details: $e');
      }

      // Create high-priority notification channel for Android system tray
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'chat_channel_id',
        'Chat Messages',
        description: 'Notifications for new messages and attendance alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _currentDeviceFcmToken = await messaging.getToken();
      String? token = _currentDeviceFcmToken;
      if (token != null && currentEmployee != null) {
        // Disassociate this hardware token from any other employee who previously used this device
        for (var emp in _employees) {
          if (emp.id != currentEmployee!.id && emp.fcmToken == token) {
            try {
              await updateEmployee(emp.copyWith(fcmToken: '', overrideFcmToken: true));
            } catch (e) {
              debugPrint('Error unbinding token from previous employee ${emp.id}: $e');
            }
          }
        }

        if (currentEmployee!.fcmToken != token) {
          final updatedEmp = currentEmployee!.copyWith(
            fcmToken: token,
            overrideFcmToken: true,
          );
          await updateEmployee(updatedEmp);
        }
      }

      // Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        _currentDeviceFcmToken = newToken;
        if (currentEmployee != null) {
          for (var emp in _employees) {
            if (emp.id != currentEmployee!.id && emp.fcmToken == newToken) {
              try {
                await updateEmployee(emp.copyWith(fcmToken: '', overrideFcmToken: true));
              } catch (_) {}
            }
          }

          if (currentEmployee!.fcmToken != newToken) {
            final updatedEmp = currentEmployee!.copyWith(
              fcmToken: newToken,
              overrideFcmToken: true,
            );
            await updateEmployee(updatedEmp);
          }
        }
      });

      // Handle notification clicks when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification clicked while app in background: ${message.data}');
        final senderId = message.data['senderId']?.toString();
        final senderName = message.data['senderName']?.toString();
        final text = message.data['body']?.toString() ?? message.data['text']?.toString();
        _openChatWithSender(senderId, senderName: senderName, initialText: text);
      });

      // Handle notification click when app was terminated
      messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('Notification opened app from terminated state: ${message.data}');
          final senderId = message.data['senderId']?.toString();
          final senderName = message.data['senderName']?.toString();
          final text = message.data['body']?.toString() ?? message.data['text']?.toString();
          _openChatWithSender(senderId, senderName: senderName, initialText: text);
        }
      });

      // Setup foreground Cloud Messaging listener:
      // When the user is ON THE APP, Android suppresses system tray display.
      // We show 1 heads-up notification so the user is immediately alerted while inside the app.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Cloud FCM message received in foreground: ${message.data}');

        final senderId = message.data['senderId']?.toString();
        // If the user currently has this contact's chat open, skip notification popup
        if (_activeChatContactId != null && _activeChatContactId == senderId) {
          return;
        }

        final title = message.notification?.title ??
            message.data['title'] ??
            'Message from ${message.data['senderName'] ?? 'Contact'}';
        final body = message.notification?.body ??
            message.data['body'] ??
            message.data['text'] ??
            '';

        // 1. Add to in-app notification center (the bell icon)
        _notifications ??= [];
        _notifications!.insert(
          0,
          AppNotification(
            id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            body: body,
            timestamp: DateTime.now(),
            type: NotificationType.chat,
            relatedId: senderId,
            isRead: false,
          ),
        );
        notifyListeners();

        // 2. Show heads-up notification on Mobile so user gets notified while in-app
        if (!kIsWeb) {
          final msgId = message.data['messageId']?.toString() ??
              message.messageId ??
              '${title}_$body';
          final notifId = msgId.hashCode.abs() % 100000;

          const AndroidNotificationDetails androidDetails =
              AndroidNotificationDetails(
                'chat_channel_id',
                'Chat Messages',
                channelDescription:
                    'Notifications for new messages and attendance alerts',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
              );
          const DarwinNotificationDetails darwinDetails =
              DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              );
          const NotificationDetails platformDetails = NotificationDetails(
            android: androidDetails,
            iOS: darwinDetails,
          );

          final payloadData = jsonEncode({
            'senderId': senderId,
            'senderName': message.data['senderName'] ?? title.replaceFirst('Message from ', ''),
            'body': body,
          });

          await _localNotificationsPlugin.show(
            id: notifId,
            title: title,
            body: body,
            notificationDetails: platformDetails,
            payload: payloadData,
          );
        }
      });
    } catch (e) {
      debugPrint('Error setting up push notifications: $e');
    }
  }

  void _handleNotificationPayload(String payload) {
    try {
      if (payload.trim().startsWith('{')) {
        final map = jsonDecode(payload) as Map<String, dynamic>;
        final senderId = map['senderId']?.toString();
        final senderName = map['senderName']?.toString();
        final text = map['body']?.toString() ?? map['text']?.toString();
        _openChatWithSender(senderId, senderName: senderName, initialText: text);
      } else {
        _openChatWithSender(payload);
      }
    } catch (_) {
      _openChatWithSender(payload);
    }
  }

  Future<void> _openChatWithSender(
    String? senderId, {
    String? senderName,
    String? initialText,
  }) async {
    if (senderId == null || senderId.trim().isEmpty) return;
    final cleanId = senderId.trim();

    // 1. Wait for navigator key to be mounted (e.g. cold start)
    int attempts = 0;
    while (rootNavigatorKey.currentState == null && attempts < 25) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }

    final navState = rootNavigatorKey.currentState;
    if (navState == null) {
      debugPrint('[_openChatWithSender] NavigatorState is null after waiting.');
      return;
    }

    // 2. Wait briefly if initial data sync is still actively populating
    if (_isLoading && _employees.isEmpty) {
      int dataAttempts = 0;
      while (_isLoading && _employees.isEmpty && dataAttempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        dataAttempts++;
      }
    }

    // 3. Resolve the Contact employee
    CompanyEmployee? contact;
    try {
      contact = _employees.firstWhere(
        (e) =>
            e.id.trim().toLowerCase() == cleanId.toLowerCase() ||
            e.email.trim().toLowerCase() == cleanId.toLowerCase(),
      );
    } catch (_) {}

    // 4. Try fetching from Firebase if not in local memory
    if (contact == null && _firebaseService.isAvailable) {
      try {
        contact = await _firebaseService.getEmployee(cleanId);
      } catch (_) {}
    }

    // 5. Fallback contact so navigation never fails
    contact ??= CompanyEmployee(
      id: cleanId,
      name: (senderName != null && senderName.isNotEmpty) ? senderName : 'Management',
      email: '',
      position: 'HR / Supervisor',
      role: 'hr',
      companyCode: _currentCompanyCode,
    );

    // 6. Check if chat with this contact is already open
    final isAlreadyOpen = _activeChatContactId == contact.id;

    // 7. Ensure chat messages are loaded and set active contact
    ensureChatLoaded(contact.id);
    setActiveChatContactId(contact.id);

    if (isAlreadyOpen) {
      return;
    }

    // 8. Open ChatRoomScreen
    await navState.push(
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(contact: contact!),
      ),
    );
  }

  Future<void> _showLocalChatNotification(
    String senderName,
    String messageText, {
    String? senderId,
  }) async {
    // Mobile uses purely Cloud Messaging (FCM from Cloud Function).
    // Local notifications are strictly for Web browsers.
    if (!kIsWeb) return;

    // If the user currently has this contact's chat open, skip notification
    if (_activeChatContactId != null && _activeChatContactId == senderId) {
      return;
    }

    showBrowserNotification('Message from $senderName', messageText);

    _notifications ??= [];
    _notifications!.insert(
      0,
      AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Message from $senderName',
        body: messageText,
        timestamp: DateTime.now(),
        type: NotificationType.chat,
        relatedId: senderId,
        isRead: false,
      ),
    );

    // Show redesigned compact floating toast at top-right on Web
    showWebNotificationToast(
      senderName: senderName,
      messageText: messageText,
      senderId: senderId,
      onReply: () {
        if (senderId != null) {
          _openChatWithSender(senderId, senderName: senderName, initialText: messageText);
        }
      },
    );

    notifyListeners();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _setupFirestoreListeners();
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _restoreActiveRecordFromRecords() {
    final now = DateTime.now();
    try {
      final active = _records.firstWhere(
        (r) =>
            r.checkOut == null &&
            now.difference(r.checkIn).inHours.abs() < 24 &&
            r.checkIn.isBefore(now.add(const Duration(minutes: 5))),
      );
      _isClockedIn = true;
      _activeRecord = active;
      debugPrint(
        'Restored active clock-in session from Firestore: ${active.checkIn}',
      );
    } catch (_) {
      _isClockedIn = false;
      _activeRecord = null;
    }
  }

  SalaryHistoryEntry getActiveSalaryConfig(CompanyEmployee emp, DateTime date) {
    // 1. Check history for a matching date range
    final sortedHistory = List<SalaryHistoryEntry>.from(emp.salaryHistory)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    for (var entry in sortedHistory) {
      DateTime start = DateTime.parse(entry.startDate);
      DateTime? end = entry.endDate != null
          ? DateTime.parse(entry.endDate!)
          : null;

      if (date.isAtSameMomentAs(start) || date.isAfter(start)) {
        if (end == null || date.isBefore(end) || date.isAtSameMomentAs(end)) {
          return entry;
        }
      }
    }
    // 2. If history exists but no match is found (e.g., date is before the first entry), salary is 0
    if (emp.salaryHistory.isNotEmpty) {
      return SalaryHistoryEntry(
        basicSalary: 0.0,
        workingHours: 0.0,
        currency: emp.salaryCurrency,
        startDate: '',
        foodAllowance: 0.0,
        transportationAllowance: 0.0,
        otherAllowance: 0.0,
        hasInsurance: false,
        insuranceSalary: 0.0,
      );
    }

    // 3. Fallback to base configuration if no history matches
    return SalaryHistoryEntry(
      basicSalary: emp.basicSalary,
      workingHours: emp.workingHours > 0 ? emp.workingHours : 160.0,
      currency: emp.salaryCurrency.isNotEmpty ? emp.salaryCurrency : 'USD',
      startDate: '',
      foodAllowance: emp.foodAllowance,
      transportationAllowance: emp.transportationAllowance,
      otherAllowance: emp.otherAllowance,
      hasInsurance: emp.hasInsurance,
      insuranceSalary: emp.insuranceSalary,
    );
  }

  DateTime? _parseFlexibleDateOnly(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final s = dateStr.trim();
    try {
      final dt = DateTime.parse(s);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {}

    if (s.contains('/')) {
      final parts = s.split('/');
      if (parts.length == 3) {
        final p0 = int.tryParse(parts[0]);
        final p1 = int.tryParse(parts[1]);
        final p2 = int.tryParse(parts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          if (parts[2].length == 4) {
            return DateTime(p2, p1, p0);
          } else if (parts[0].length == 4) {
            return DateTime(p0, p1, p2);
          }
        }
      }
    }

    final formats = [
      'MMMM d, yyyy',
      'MMM d, yyyy',
      'yyyy-MM-dd',
      'd MMMM yyyy',
      'd MMM yyyy',
      'dd-MM-yyyy',
    ];
    for (var f in formats) {
      try {
        final dt = DateFormat(f).parse(s);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {}
    }
    return null;
  }

  WorkShift getShiftForDate(CompanyEmployee emp, DateTime date) {
    final target = DateTime(date.year, date.month, date.day);

    // 1. Check if there's an approved Change Shift request for this employee covering this date
    final approvedShiftRequests = _allCompanyRequests.where(
      (r) =>
          (r.employeeId == emp.id ||
              (_employeeId == emp.id && r.employeeId == null)) &&
          r.status == 'Approved' &&
          r.type == 'Change Shift' &&
          r.targetShiftId != null &&
          r.targetShiftId!.isNotEmpty,
    );

    for (var req in approvedShiftRequests) {
      final dateStr = req.date.trim();
      DateTime? start;
      DateTime? end;

      if (dateStr.contains(' - ')) {
        final parts = dateStr.split(' - ');
        end = _parseFlexibleDateOnly(parts[1].trim());
        String startStr = parts[0].trim();
        if (!startStr.contains(',') && end != null) {
          startStr = '$startStr, ${end.year}';
        }
        start = _parseFlexibleDateOnly(startStr);
      } else {
        start = _parseFlexibleDateOnly(dateStr);
        end = start;
      }

      if (start != null && end != null) {
        if ((target.isAtSameMomentAs(start) || target.isAfter(start)) &&
            (target.isAtSameMomentAs(end) || target.isBefore(end))) {
          final foundShift =
              _shifts.where((s) => s.id == req.targetShiftId).firstOrNull;
          if (foundShift != null) {
            return foundShift;
          }
        }
      }
    }

    // 2. Resolve via active group for date
    final activeGroupId = getGroupIdForDate(emp, date);
    final group = _groups.firstWhere(
      (g) => g.id == activeGroupId,
      orElse: () => EmployeeGroup(
        id: '',
        name: 'None',
        shiftId: '',
        overtimeAllowed: false,
        minOvertimeMinutes: 0,
        maxOvertimeMinutes: 0,
      ),
    );
    return _shifts.firstWhere(
      (s) => s.id == group.shiftId,
      orElse: () => WorkShift(
        id: '',
        name: 'Default Shift',
        startTime: '09:00',
        endTime: '17:00',
      ),
    );
  }

  DateTime getEffectiveDateForRecord(AttendanceRecord rec, CompanyEmployee emp) {
    final checkIn = rec.checkIn;
    final dayOfCheckIn = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final prevDay = dayOfCheckIn.subtract(const Duration(days: 1));
    final prevShift = getShiftForDate(emp, prevDay);
    if (prevShift.isOvernightForDate(prevDay)) {
      final cutoffStr = prevShift.getCrossMidnightCutoffForDate(prevDay);
      final cParts = cutoffStr.split(':');
      if (cParts.length >= 2) {
        final cH = int.tryParse(cParts[0]) ?? 3;
        final cM = int.tryParse(cParts[1]) ?? 0;
        final cutoffDateTime = DateTime(dayOfCheckIn.year, dayOfCheckIn.month, dayOfCheckIn.day, cH, cM);
        if (checkIn.isBefore(cutoffDateTime)) {
          return prevDay;
        }
      }
    }
    return dayOfCheckIn;
  }

  List<AttendanceRecord> getRecordsForDate(
    DateTime date, {
    required CompanyEmployee emp,
    List<AttendanceRecord>? recordsPool,
    List<Request>? requestsPool,
  }) {
    final pool = recordsPool ??
        ((emp.id == _employeeId)
            ? _records
            : _allCompanyRecords
                .where((r) =>
                    r.employeeId != null &&
                    (r.employeeId!.trim().toLowerCase() == emp.id.trim().toLowerCase() ||
                     r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                     r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
                .toList());

    return pool.where((rec) {
      final effDate = getEffectiveDateForRecord(rec, emp);
      return effDate.year == date.year &&
          effDate.month == date.month &&
          effDate.day == date.day;
    }).toList();
  }

  PayrollReport generatePayrollReport(
    CompanyEmployee emp,
    DateTime targetMonth, {
    List<AttendanceRecord>? customRecords,
    bool bypassSnapshot = false,
  }) {
    final yearMonth = DateFormat('yyyy-MM').format(targetMonth);
    if (!bypassSnapshot && isMonthClosedStr(yearMonth)) {
      final closure = getClosureForMonthStr(yearMonth);
      if (closure != null && closure.snapshots.containsKey(emp.id)) {
        final snap = closure.snapshots[emp.id]!;
        final empAdjustments = _payrollAdjustments.where((adj) {
          final matchesEmp = adj.employeeId.trim().toLowerCase() == emp.id.trim().toLowerCase() ||
              adj.employeeId.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
              adj.employeeId.trim().toLowerCase() == emp.email.trim().toLowerCase();
          final matchesMonth = adj.month == yearMonth ||
              (adj.date.length >= 7 && adj.date.substring(0, 7) == yearMonth);
          return matchesEmp && matchesMonth;
        }).toList();
        return snap.toPayrollReport(emp, empAdjustments);
      }
    }

    final config = getActiveSalaryConfig(emp, targetMonth);
    final basicSalary = config.basicSalary;
    final configWorkingHours = config.workingHours > 0
        ? config.workingHours
        : 160.0;
    final hourlyRate = configWorkingHours > 0
        ? (basicSalary / configWorkingHours)
        : 0.0;
    final currency = config.currency;

    final foodAllowance = config.foodAllowance;
    final transportationAllowance = config.transportationAllowance;
    final otherAllowance = config.otherAllowance;
    final totalAllowances =
        foodAllowance + transportationAllowance + otherAllowance;

    // We will look up the group & shift per-day inside the loop.

    // Records for this employee
    final employeeRecords =
        customRecords ??
        ((emp.id == _employeeId)
            ? _records
            : _allCompanyRecords
                .where((r) =>
                    r.employeeId != null &&
                    (r.employeeId!.trim().toLowerCase() == emp.id.trim().toLowerCase() ||
                     r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                     r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
                .toList());
    final employeeRequests = _allRequestsMap[emp.id] ??
        _allCompanyRequests
            .where((r) =>
                r.employeeId != null &&
                (r.employeeId!.trim().toLowerCase() == emp.id.trim().toLowerCase() ||
                 r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                 r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
            .toList();

    final daysInMonth = DateUtils.getDaysInMonth(
      targetMonth.year,
      targetMonth.month,
    );

    int totalDutyMinutes = 0;
    int totalOvertimeMinutes = 0;
    int totalDeficitMinutes = 0;
    double totalPenalties = 0.0;
    int daysWorked = 0;

    int delayTier1Occurrences = 0;
    int delayTier2Occurrences = 0;
    int delayTier3Occurrences = 0;
    int earlyExitTier1Occurrences = 0;
    int earlyExitTier2Occurrences = 0;
    int earlyExitTier3Occurrences = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(targetMonth.year, targetMonth.month, day);
      final activeGroupId = getGroupIdForDate(emp, date);
      final group = _groups.firstWhere(
        (g) => g.id == activeGroupId,
        orElse: () => EmployeeGroup(
          id: '',
          name: 'None',
          shiftId: '',
          overtimeAllowed: false,
          minOvertimeMinutes: 0,
          maxOvertimeMinutes: 0,
        ),
      );
      final shift = getShiftForDate(emp, date);

      final isWorkingDay = shift.isWorkingDay(date);

      // Get records on this day
      final dayRecords = getRecordsForDate(
        date,
        emp: emp,
        recordsPool: employeeRecords,
      );

      final hasRecord = dayRecords.isNotEmpty;

      // Approved requests on this day
      final dateStr = DateFormat('MMMM d, yyyy').format(date);
      final dayApprovedRequests = employeeRequests
          .where(
            (req) =>
                req.status == 'Approved' &&
                (req.date == dateStr ||
                    req.date.contains(DateFormat('MMMM d').format(date))),
          )
          .toList();

      final hasFullDayLeave = dayApprovedRequests.any(
        (r) =>
            r.type == 'Annual Leave' ||
            r.type == 'Sick Leave' ||
            (r.type.contains('Leave') &&
                r.type != 'Hourly Leave' &&
                !r.type.toLowerCase().contains('hourly')),
      );
      int approvedHourlyMinutes = 0;
      int approvedOtMinutes = 0;
      bool hasApprovedOt = false;
      for (var r in dayApprovedRequests) {
        if (r.type == 'Hourly Leave' || r.type.toLowerCase().contains('hourly')) {
          final m = parseHourlyLeaveDurationMinutes(r.duration);
          approvedHourlyMinutes += m > 0 ? m : 60;
        } else if (r.type == 'Overtime Approval') {
          hasApprovedOt = true;
          final m = parseOvertimeApprovalDurationMinutes(r.duration);
          approvedOtMinutes += m > 0 ? m : 0;
        }
      }

      final holiday = _holidays.firstWhere(
        (h) {
          final isForGroup =
              h.groupIds.isEmpty ||
              (activeGroupId != null && h.groupIds.contains(activeGroupId));
          if (!isForGroup) return false;
          try {
            final from = DateTime.parse(
              h.fromDate,
            ).subtract(const Duration(days: 1));
            final to = DateTime.parse(h.toDate).add(const Duration(days: 1));
            return date.isAfter(from) && date.isBefore(to);
          } catch (_) {
            return false;
          }
        },
        orElse: () => Holiday(
          id: '',
          name: '',
          fromDate: '2099-01-01',
          toDate: '2099-01-01',
        ),
      );
      final isHoliday = holiday.id.isNotEmpty;

      final hasApprovedMissingPunch = dayApprovedRequests.any(
        (r) =>
            r.type == 'Missing Punch' ||
            r.type == 'Forgot to Clock In' ||
            r.type == 'Forgot to Clock Out',
      );

      final startTimeStr = shift.getStartTimeForDate(date);
      final endTimeStr = shift.getEndTimeForDate(date);
      final sParts = startTimeStr.split(':');
      final eParts = endTimeStr.split(':');
      final shiftStartMins = sParts.length >= 2
          ? int.parse(sParts[0]) * 60 + int.parse(sParts[1])
          : 540;
      final shiftEndMins = eParts.length >= 2
          ? int.parse(eParts[0]) * 60 + int.parse(eParts[1])
          : 1020;

      final shiftStart = DateTime(
        date.year,
        date.month,
        date.day,
        shiftStartMins ~/ 60,
        shiftStartMins % 60,
      );
      var shiftEnd = DateTime(
        date.year,
        date.month,
        date.day,
        shiftEndMins ~/ 60,
        shiftEndMins % 60,
      );
      if (shiftEnd.isBefore(shiftStart) || shiftEnd.isAtSameMomentAs(shiftStart) || shift.isOvernightForDate(date)) {
        shiftEnd = shiftEnd.add(const Duration(days: 1));
      }

      final isToday = DateUtils.isSameDay(date, DateTime.now());
      final hasUnexcusedMissedPunch = !hasApprovedMissingPunch &&
          hasRecord &&
          dayRecords.any((rec) {
            if (rec.checkIn == rec.checkOut) return true;
            if (rec.checkOut == null) {
              if (!isToday) return true;
              if (DateTime.now().isAfter(shiftEnd)) return true;
            }
            return false;
          });

      if (hasRecord && !hasUnexcusedMissedPunch) {
        daysWorked++;
        int dayDuty = 0;
        int dayExtra = 0;
        int dayNightExtra = 0;
        int dayActualMinutes = 0;

        for (var rec in dayRecords) {
          final rawIn = rec.checkIn;
          final rawOut = rec.checkOut ?? rawIn;
          final cIn = DateTime(
            rawIn.year,
            rawIn.month,
            rawIn.day,
            rawIn.hour,
            rawIn.minute,
          );
          final cOut = DateTime(
            rawOut.year,
            rawOut.month,
            rawOut.day,
            rawOut.hour,
            rawOut.minute,
          );

          final intStart = cIn.isAfter(shiftStart) ? cIn : shiftStart;
          final intEnd = cOut.isBefore(shiftEnd) ? cOut : shiftEnd;
          if (intEnd.isAfter(intStart)) {
            dayDuty += intEnd.difference(intStart).inMinutes;
          }

          if (!isWorkingDay) {
            dayExtra += cOut.difference(cIn).inMinutes;
            if (group.nightOvertimeAllowed) {
              dayNightExtra += group.calculateNightMinutes(cIn, cOut);
            }
          } else {
            if (cIn.isBefore(shiftStart)) {
              final eBefore = cOut.isBefore(shiftStart) ? cOut : shiftStart;
              dayExtra += eBefore.difference(cIn).inMinutes;
              if (group.nightOvertimeAllowed) {
                dayNightExtra += group.calculateNightMinutes(cIn, eBefore);
              }
            }
            if (cOut.isAfter(shiftEnd)) {
              final sAfter = cIn.isAfter(shiftEnd) ? cIn : shiftEnd;
              dayExtra += cOut.difference(sAfter).inMinutes;
              if (group.nightOvertimeAllowed) {
                dayNightExtra += group.calculateNightMinutes(sAfter, cOut);
              }
            }
          }
          dayActualMinutes += cOut.difference(cIn).inMinutes;
        }

        totalDutyMinutes += dayDuty;

        // Delay & Early Exit
        final isSpecial = shift.isSpecialShiftForDate(date);
        final shiftDur = shift.getShiftDurationMinutesForDate(date);

        int dayDelay = 0;
        int dayEarlyExit = 0;
        int unexcusedRestMinutes = 0;

        if (isSpecial) {
          dayDelay = 0;
          dayEarlyExit = 0;
          dayDuty = dayActualMinutes > shiftDur ? shiftDur : dayActualMinutes;
          dayExtra = dayActualMinutes > shiftDur ? (dayActualMinutes - shiftDur) : 0;
          if (group.nightOvertimeAllowed && dayExtra > 0 && dayRecords.isNotEmpty) {
            final lastRec = dayRecords.last;
            final lastOut = lastRec.checkOut ?? lastRec.checkIn;
            final extraStart = lastOut.subtract(Duration(minutes: dayExtra));
            dayNightExtra = group.calculateNightMinutes(extraStart, lastOut);
          }
        } else if (isWorkingDay && !hasFullDayLeave && !isHoliday) {
          final sorted = List<AttendanceRecord>.from(dayRecords)
            ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

          final shiftRecords = sorted.where((r) => r.checkIn.isBefore(shiftEnd)).toList();
          if (shiftRecords.isNotEmpty) {
            final firstRec = shiftRecords.first;
            final delay = firstRec.checkIn.difference(shiftStart).inMinutes;
            if (delay > shift.forgivenessOfDelay) {
              dayDelay = delay;
            }

            final lastRec = shiftRecords.last;
            if (lastRec.checkOut != null) {
              final earlyExit = shiftEnd.difference(lastRec.checkOut!).inMinutes;
              if (earlyExit > shift.earlyExit) {
                dayEarlyExit = earlyExit;
              }
            }

            if (approvedHourlyMinutes > 0) {
              int remainingHourly = approvedHourlyMinutes;
              if (dayDelay > 0) {
                final excused = math.min(dayDelay, remainingHourly);
                dayDelay -= excused;
                remainingHourly -= excused;
              }
              if (dayEarlyExit > 0 && remainingHourly > 0) {
                final excused = math.min(dayEarlyExit, remainingHourly);
                dayEarlyExit -= excused;
                remainingHourly -= excused;
              }
            }
          }

          // Calculate Unexcused Rest Time (within shift bounds)
          int totalExcusedRestMinutes = 0;

          final breakStartStr = shift.getBreakStartForDate(date);
          final breakEndStr = shift.getBreakEndForDate(date);
          final allowedBreakDuration = shift.getBreakDurationForDate(date);

          DateTime? bStart;
          DateTime? bEnd;
          if (breakStartStr.isNotEmpty &&
              breakEndStr.isNotEmpty &&
              allowedBreakDuration > 0) {
            final bsParts = breakStartStr.split(':');
            final beParts = breakEndStr.split(':');
            if (bsParts.length >= 2 && beParts.length >= 2) {
              bStart = DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(bsParts[0]),
                int.parse(bsParts[1]),
              );
              bEnd = DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(beParts[0]),
                int.parse(beParts[1]),
              );
              if (bEnd.isBefore(bStart)) {
                bEnd = bEnd.add(const Duration(days: 1));
              }
            }
          }

          if (sorted.length > 1) {
            for (int i = 0; i < sorted.length - 1; i++) {
              final currentOut = sorted[i].checkOut;
              final nextIn = sorted[i + 1].checkIn;
              if (currentOut != null && nextIn.isAfter(currentOut)) {
                // If the gap starts at or after shiftEnd, it's outside shift hours (e.g. night overtime gap)
                if (currentOut.isAfter(shiftEnd) || currentOut.isAtSameMomentAs(shiftEnd)) {
                  continue;
                }
                // If the employee does not return before shiftEnd, their departure is handled by Early Exit
                if (nextIn.isAfter(shiftEnd) || nextIn.isAtSameMomentAs(shiftEnd)) {
                  continue;
                }

                final gapStart = currentOut.isAfter(shiftStart) ? currentOut : shiftStart;
                final gapEnd = nextIn.isBefore(shiftEnd) ? nextIn : shiftEnd;
                if (!gapEnd.isAfter(gapStart)) continue;

                final gapDuration = gapEnd.difference(gapStart).inMinutes;

                if (bStart != null && bEnd != null) {
                  final intersectStart = gapStart.isAfter(bStart)
                      ? gapStart
                      : bStart;
                  final intersectEnd = gapEnd.isBefore(bEnd) ? gapEnd : bEnd;

                  int excusedInGap = 0;
                  if (intersectEnd.isAfter(intersectStart)) {
                    excusedInGap = intersectEnd
                        .difference(intersectStart)
                        .inMinutes;
                  }

                  if (totalExcusedRestMinutes + excusedInGap >
                      allowedBreakDuration) {
                    excusedInGap =
                        allowedBreakDuration - totalExcusedRestMinutes;
                    if (excusedInGap < 0) excusedInGap = 0;
                  }

                  totalExcusedRestMinutes += excusedInGap;
                  unexcusedRestMinutes += (gapDuration - excusedInGap);
                } else {
                  unexcusedRestMinutes += gapDuration;
                }
              }
            }
          }
        }

        // Removed unused delay & early exit accumulators

        // Penalties (with forgiveness evaluation per tier)
        double delayPenalty = 0.0;
        if (dayDelay > 0 && group.delayPenaltiesEnabled) {
          if (dayDelay >= group.delayTier1Min &&
              dayDelay <= group.delayTier1Max) {
            delayTier1Occurrences++;
            if (delayTier1Occurrences > group.delayTier1Forgiveness) {
              delayPenalty = group.delayTier1Penalty;
            }
          } else if (dayDelay >= group.delayTier2Min &&
              dayDelay <= group.delayTier2Max) {
            delayTier2Occurrences++;
            if (delayTier2Occurrences > group.delayTier2Forgiveness) {
              delayPenalty = group.delayTier2Penalty;
            }
          } else if (dayDelay >= group.delayTier3Min) {
            delayTier3Occurrences++;
            if (delayTier3Occurrences > group.delayTier3Forgiveness) {
              delayPenalty = group.delayTier3Penalty;
            }
          }
        }

        double earlyExitPenalty = 0.0;
        if (dayEarlyExit > 0 && group.earlyExitPenaltiesEnabled) {
          if (dayEarlyExit >= group.earlyExitTier1Min &&
              dayEarlyExit <= group.earlyExitTier1Max) {
            earlyExitTier1Occurrences++;
            if (earlyExitTier1Occurrences > group.earlyExitTier1Forgiveness) {
              earlyExitPenalty = group.earlyExitTier1Penalty;
            }
          } else if (dayEarlyExit >= group.earlyExitTier2Min &&
              dayEarlyExit <= group.earlyExitTier2Max) {
            earlyExitTier2Occurrences++;
            if (earlyExitTier2Occurrences > group.earlyExitTier2Forgiveness) {
              earlyExitPenalty = group.earlyExitTier2Penalty;
            }
          } else if (dayEarlyExit >= group.earlyExitTier3Min) {
            earlyExitTier3Occurrences++;
            if (earlyExitTier3Occurrences > group.earlyExitTier3Forgiveness) {
              earlyExitPenalty = group.earlyExitTier3Penalty;
            }
          }
        }

        totalPenalties += (delayPenalty + earlyExitPenalty);

        // Overtime
        if (dayExtra > 0 && hasApprovedOt && group.overtimeAllowed) {
          final effectiveOtExtra = approvedOtMinutes > 0
              ? math.min(dayExtra, approvedOtMinutes)
              : dayExtra;

          if (effectiveOtExtra > 0) {
            final effNight = dayExtra > 0
                ? (dayNightExtra * (effectiveOtExtra / dayExtra)).round()
                : 0;

            totalOvertimeMinutes += group.calculateOvertimeMinutes(
              dayExtraMinutes: effectiveOtExtra,
              nightExtraMinutes: effNight,
              isWeekend: !isWorkingDay,
              isHoliday: isHoliday,
            );
          }
        }

        // Deficit on active day
        int dayDeficit = 0;
        if (isSpecial) {
          if (isWorkingDay && !hasFullDayLeave && !isHoliday) {
            final effShiftDur = math.max(0, shiftDur - approvedHourlyMinutes);
            if (dayActualMinutes < effShiftDur) {
              dayDeficit = effShiftDur - dayActualMinutes;
            }
          }
        } else if (isWorkingDay && !hasFullDayLeave && !isHoliday) {
          final shiftRecords = dayRecords.where((r) => r.checkIn.isBefore(shiftEnd)).toList();
          if (shiftRecords.isEmpty && dayRecords.isNotEmpty) {
            // Employee only had punches after shift hours, full shift was missed
            dayDeficit = shiftDur;
          } else {
            int remainingHourly = approvedHourlyMinutes;
            int effDelay = dayDelay;
            int effEarly = dayEarlyExit;
            if (effDelay > 0 && remainingHourly > 0) {
              final excused = math.min(effDelay, remainingHourly);
              effDelay -= excused;
              remainingHourly -= excused;
            }
            if (effEarly > 0 && remainingHourly > 0) {
              final excused = math.min(effEarly, remainingHourly);
              effEarly -= excused;
              remainingHourly -= excused;
            }
            dayDeficit = effDelay + effEarly + unexcusedRestMinutes;
            if (remainingHourly > 0 && dayDeficit > 0) {
              dayDeficit = math.max(0, dayDeficit - remainingHourly);
            }
          }
          if (dayDeficit > shiftDur) {
            dayDeficit = shiftDur;
          }
        }
        totalDeficitMinutes += dayDeficit;
      } else if (hasRecord && hasUnexcusedMissedPunch) {
        // Missed punch: do not calculate attendance, deficit is full shift time
        if (isWorkingDay && !hasFullDayLeave && !isHoliday && !date.isAfter(DateTime.now())) {
          final shiftDur = shift.getShiftDurationMinutesForDate(date);
          int dayDeficit = shiftDur;
          if (approvedHourlyMinutes > 0) {
            dayDeficit = math.max(0, dayDeficit - approvedHourlyMinutes);
          }
          totalDeficitMinutes += dayDeficit;
        }
      } else {
        // No record on this day
        // Since Gross Salary is based on Days Worked (salaryCalcByDay),
        // completely missing a day naturally reduces the gross.
        // We do not add the missing shift to the deficit to avoid double-deduction.
      }
    }

    final double workingHours = totalDutyMinutes / 60.0;
    final double overtimeHours = totalOvertimeMinutes / 60.0;
    final double overtimeValue = overtimeHours * hourlyRate * 1.5;
    final double attendanceDeficitHours = totalDeficitMinutes / 60.0;
    final double attendanceDeficit = attendanceDeficitHours * hourlyRate;

    // Salary calculation by day / attendance
    // Standard HR practice: calculate daily rate based on 30 days regardless of the actual month length
    final double dailyRate = basicSalary / 30.0;
    final double salaryCalcByDay = daysWorked * dailyRate;

    // Monthly additions & deductions for this employee in this target month
    final targetMonthStr = DateFormat('yyyy-MM').format(targetMonth);
    final empAdjustments = _payrollAdjustments.where((adj) {
      final matchesEmp = adj.employeeId.trim().toLowerCase() == emp.id.trim().toLowerCase() ||
          adj.employeeId.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
          adj.employeeId.trim().toLowerCase() == emp.email.trim().toLowerCase();
      final matchesMonth = adj.month == targetMonthStr ||
          (adj.date.length >= 7 && adj.date.substring(0, 7) == targetMonthStr);
      return matchesEmp && matchesMonth;
    }).toList();

    final double monthlyAdditions = empAdjustments
        .where((adj) => adj.type.toLowerCase() == 'addition')
        .fold(0.0, (sum, adj) => sum + adj.amount);

    final double monthlyDeductions = empAdjustments
        .where((adj) => adj.type.toLowerCase() == 'deduction')
        .fold(0.0, (sum, adj) => sum + adj.amount);

    final hasInsurance = config.hasInsurance;
    final double insuranceSalary = hasInsurance
        ? (config.insuranceSalary > 0 ? config.insuranceSalary : basicSalary)
        : 0.0;
    // 5% employee deduction, 12% employer contribution (only for show)
    final double insuranceEmployee = hasInsurance ? (insuranceSalary * 0.05) : 0.0;
    final double insuranceCompany = hasInsurance ? (insuranceSalary * 0.12) : 0.0;

    final double incrementalSalary =
        salaryCalcByDay +
        overtimeValue +
        (daysWorked > 0 ? totalAllowances : 0.0) +
        monthlyAdditions;

    // 5% insurance deduction decreases final net salary
    final double employeeInsuranceDeduction = (daysWorked > 0 || salaryCalcByDay > 0) ? insuranceEmployee : 0.0;
    final double decrementalSalary = attendanceDeficit + totalPenalties + monthlyDeductions + employeeInsuranceDeduction;
    final double netEarnings = (incrementalSalary - decrementalSalary).clamp(
      0.0,
      double.infinity,
    );

    return PayrollReport(
      employee: emp,
      basicSalary: basicSalary,
      salaryCalcByDay: salaryCalcByDay,
      workingHours: workingHours,
      daysWorked: daysWorked,
      overtimeHours: overtimeHours,
      overtimeValue: overtimeValue,
      attendanceDeficitHours: attendanceDeficitHours,
      attendanceDeficit: attendanceDeficit,
      monthlyPenalties: totalPenalties,
      foodAllowance: foodAllowance,
      transportationAllowance: transportationAllowance,
      otherAllowance: otherAllowance,
      monthlyAdditions: monthlyAdditions,
      monthlyDeductions: monthlyDeductions,
      hasInsurance: hasInsurance,
      insuranceSalary: insuranceSalary,
      insuranceEmployee: insuranceEmployee,
      insuranceCompany: insuranceCompany,
      adjustments: empAdjustments,
      incrementalSalary: incrementalSalary,
      decrementalSalary: decrementalSalary,
      netEarnings: netEarnings,
      currency: currency,
    );
  }

  Future<void> _loadPayrollClosuresFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = _currentCompanyCode.toLowerCase();
      var str = prefs.getString('payroll_closures_cache_$code');
      if ((str == null || str.isEmpty) && code == 'amada') {
        str = prefs.getString('payroll_closures');
      }
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        _payrollClosures.clear();
        for (var item in list) {
          if (item is Map<String, dynamic>) {
            final c = PayrollMonthClosure.fromMap(
                item, item['id']?.toString() ?? '');
            if (c.companyCode.isEmpty || c.companyCode.toLowerCase() == code) {
              _payrollClosures.add(c);
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading payroll closures from prefs: $e');
    }
  }

  Future<void> _savePayrollClosuresToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = _currentCompanyCode.toLowerCase();
      final list = _payrollClosures
          .where((c) =>
              c.companyCode.isEmpty || c.companyCode.toLowerCase() == code)
          .map((c) => c.toMap())
          .toList();
      await prefs.setString('payroll_closures_cache_$code', jsonEncode(list));
      if (code == 'amada') {
        await prefs.setString('payroll_closures', jsonEncode(list));
      }
    } catch (e) {
      debugPrint('Error saving payroll closures to prefs: $e');
    }
  }

  Future<bool> closeMonth({
    required DateTime month,
    required String closedBy,
    String? closedByEmail,
  }) async {
    final ym = DateFormat('yyyy-MM').format(month);
    final code = _currentCompanyCode.toLowerCase();
    final closureId = '${code}_$ym';

    final snapshots = <String, PayrollReportSnapshot>{};
    double totalPayout = 0.0;
    String currency = 'USD';

    for (var emp in employees) {
      final report = generatePayrollReport(emp, month, bypassSnapshot: true);
      snapshots[emp.id] = report.toSnapshot();
      totalPayout += report.netEarnings;
      currency = report.currency;
    }

    final closure = PayrollMonthClosure(
      id: closureId,
      yearMonth: ym,
      companyCode: code,
      isClosed: true,
      closedAt: DateTime.now(),
      closedBy: closedBy,
      closedByEmail: closedByEmail,
      totalPayout: totalPayout,
      totalEmployees: snapshots.length,
      currency: currency,
      snapshots: snapshots,
    );

    final idx = _payrollClosures.indexWhere(
      (c) =>
          c.yearMonth == ym &&
          (c.companyCode.isEmpty || c.companyCode.toLowerCase() == code),
    );
    if (idx != -1) {
      _payrollClosures[idx] = closure;
    } else {
      _payrollClosures.add(closure);
    }

    await _savePayrollClosuresToPrefs();
    recalculateAllStats();
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.savePayrollClosure(closure);
    }

    return true;
  }

  Future<bool> reopenMonth({
    required DateTime month,
    required String reopenedBy,
    required String reason,
  }) async {
    final ym = DateFormat('yyyy-MM').format(month);
    final code = _currentCompanyCode.toLowerCase();
    final existing = getClosureForMonthStr(ym);
    if (existing == null) return false;

    final updated = PayrollMonthClosure(
      id: existing.id.contains('_') ? existing.id : '${code}_$ym',
      yearMonth: existing.yearMonth,
      companyCode:
          existing.companyCode.isNotEmpty ? existing.companyCode : code,
      isClosed: false,
      closedAt: existing.closedAt,
      closedBy: existing.closedBy,
      closedByEmail: existing.closedByEmail,
      reopenedAt: DateTime.now(),
      reopenedBy: reopenedBy,
      reopenReason: reason,
      totalPayout: existing.totalPayout,
      totalEmployees: existing.totalEmployees,
      currency: existing.currency,
      snapshots: existing.snapshots,
    );

    final idx = _payrollClosures.indexWhere(
      (c) =>
          c.yearMonth == ym &&
          (c.companyCode.isEmpty || c.companyCode.toLowerCase() == code),
    );
    if (idx != -1) {
      _payrollClosures[idx] = updated;
    } else {
      _payrollClosures.add(updated);
    }

    await _savePayrollClosuresToPrefs();
    recalculateAllStats();
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.savePayrollClosure(updated);
    }

    return true;
  }

  Future<void> addPayrollAdjustment(PayrollAdjustment adjustment) async {
    final m = adjustment.month.isNotEmpty
        ? adjustment.month
        : (adjustment.date.length >= 7 ? adjustment.date.substring(0, 7) : '');
    if (isMonthClosedStr(m)) {
      debugPrint('Cannot add or edit payroll adjustment for closed month $m');
      return;
    }

    final existingIdx = _payrollAdjustments.indexWhere((a) => a.id == adjustment.id);
    if (existingIdx != -1) {
      _payrollAdjustments[existingIdx] = adjustment;
    } else {
      _payrollAdjustments.add(adjustment);
    }
    recalculateAllStats();
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.savePayrollAdjustment(adjustment);
    }
  }

  Future<void> deletePayrollAdjustment(String id) async {
    final adj = _payrollAdjustments.where((a) => a.id == id).firstOrNull;
    if (adj != null && isMonthClosedStr(adj.month)) {
      debugPrint('Cannot delete payroll adjustment for closed month ${adj.month}');
      return;
    }

    _payrollAdjustments.removeWhere((a) => a.id == id);
    recalculateAllStats();
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.deletePayrollAdjustment(id);
    }
  }

  List<PayrollAdjustment> getAdjustmentsForEmployee(String empId, DateTime targetMonth) {
    final targetMonthStr = DateFormat('yyyy-MM').format(targetMonth);
    return _payrollAdjustments.where((adj) {
      final matchesEmp = adj.employeeId.trim().toLowerCase() == empId.trim().toLowerCase();
      final matchesMonth = adj.month == targetMonthStr ||
          (adj.date.length >= 7 && adj.date.substring(0, 7) == targetMonthStr);
      return matchesEmp && matchesMonth;
    }).toList();
  }

  void recalculateAllStats() {
    final emp = currentEmployee;
    if (emp == null) return;
    final report = generatePayrollReport(emp, selectedMonth);
    _weeklyHours = report.workingHours;
    _daysWorked = report.daysWorked;
    _overtimeHours = report.overtimeHours;
    _overtimeValue = report.overtimeValue;
    _attendanceDeficitHours = report.attendanceDeficitHours;
    _attendanceDeficit = report.attendanceDeficit;
    _monthlyPenalties = report.monthlyPenalties;
    _salaryCalcByDay = report.salaryCalcByDay;
    _foodAllowance = report.foodAllowance;
    _transportationAllowance = report.transportationAllowance;
    _otherAllowance = report.otherAllowance;
    _hasInsurance = report.hasInsurance;
    _insuranceSalary = report.insuranceSalary;
    _insuranceEmployee = report.insuranceEmployee;
    _insuranceCompany = report.insuranceCompany;
    _incrementalSalary = report.incrementalSalary;
    _decrementalSalary = report.decrementalSalary;
    _monthlyEarnings = report.netEarnings;
    final config = getActiveSalaryConfig(emp, selectedMonth);
    _hourlyRate = config.workingHours > 0
        ? (config.basicSalary / config.workingHours)
        : 0.0;
  }

  void _initializeMockData() {}
  void _initializeHRMockData() {}
  void _initializeMockChats() {}
  void _initializeMockRequests() {}
  List<CompanyEmployee> getChatContacts(CompanyEmployee currentUser) {
    List<CompanyEmployee> contacts = [];
    final Set<String> contactIds = {};

    final userRole = currentUser.role.trim().toLowerCase();
    if (userRole == 'hr' || userRole == 'admin' || userRole == 'super_admin' || userRole == 'superadmin') {
      contacts = _employees.where((e) => e.id != currentUser.id).toList();
      for (var c in contacts) {
        contactIds.add(c.id);
      }
    } else if (userRole == 'supervisor') {
      final supervisedStructures = _structures
          .where((s) => s.supervisorId == currentUser.id)
          .map((s) => s.id)
          .toList();

      for (var structId in supervisedStructures) {
        final emps = _employees.where(
          (e) => e.id != currentUser.id && e.structureId == structId,
        );
        for (var e in emps) {
          if (contactIds.add(e.id)) {
            contacts.add(e);
          }
        }
      }

      if (currentUser.structureId != null &&
          currentUser.structureId!.isNotEmpty) {
        final emps = _employees.where(
          (e) =>
              e.id != currentUser.id &&
              e.structureId == currentUser.structureId &&
              e.role == 'employee',
        );
        for (var e in emps) {
          if (contactIds.add(e.id)) {
            contacts.add(e);
          }
        }
      }

      // Include HR managers & admins so supervisors can communicate with them
      final hrEmps = _employees.where(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != currentUser.id,
      );
      for (var hr in hrEmps) {
        if (contactIds.add(hr.id)) {
          contacts.add(hr);
        }
      }
    } else {
      // Regular employee: supervisors
      final sups = getSupervisorsFor(currentUser.id);
      for (var sup in sups) {
        if (contactIds.add(sup.id)) {
          contacts.add(sup);
        }
      }

      // Plus HR managers and Admins
      final hrEmps = _employees.where(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != currentUser.id,
      );
      for (var hr in hrEmps) {
        if (contactIds.add(hr.id)) {
          contacts.add(hr);
        }
      }
    }

    // Always include any employee discovered from Firestore chat rooms
    for (var otherId in _chatRoomContactIds) {
      if (contactIds.add(otherId)) {
        try {
          final emp = _employees.firstWhere((e) => e.id == otherId);
          contacts.add(emp);
        } catch (_) {}
      }
    }

    // Always include any employee with existing messages in the conversation history
    for (var otherId in _chatMessagesMap.keys) {
      if (_chatMessagesMap[otherId]?.isNotEmpty ?? false) {
        if (contactIds.add(otherId)) {
          try {
            final emp = _employees.firstWhere((e) => e.id == otherId);
            contacts.add(emp);
          } catch (_) {}
        }
      }
    }

    return contacts;
  }

  void ensureChatLoaded(dynamic contactId) {
    if (!_firebaseService.isAvailable) return;
    final cId = contactId.toString().trim();
    if (cId.isEmpty) return;
    final currentUser = currentEmployee;
    if (currentUser == null) return;
    if (_chatSubscriptionsMap.containsKey(cId)) return;

    // Fast one-time async get so existing messages appear immediately
    _firebaseService.getChatMessages(currentUser.id, cId).then((initial) {
      if (initial.isNotEmpty) {
        final existing = _chatMessagesMap[cId] ?? [];
        if (existing.length < initial.length) {
          _chatMessagesMap[cId] = initial;
          notifyListeners();
        }
      }
    }).catchError((_) {});

    _chatSubscriptionsMap[cId] = _firebaseService
        .streamChatMessages(currentUser.id, cId)
        .listen(
          (messages) {
            final previousMessages = _chatMessagesMap[cId] ?? [];
            _chatMessagesMap[cId] = messages;

            // Check for new incoming messages for local and web notifications
            if (previousMessages.isNotEmpty &&
                messages.length > previousMessages.length) {
              final newMsg = messages.last;
              if (newMsg.senderId != currentUser.id) {
                String contactName = 'Colleague';
                try {
                  final contactEmp = _employees.firstWhere((e) => e.id == cId);
                  contactName = contactEmp.name;
                } catch (_) {}
                _showLocalChatNotification(
                  contactName,
                  newMsg.text,
                  senderId: cId,
                );
              }
            }

            notifyListeners();
          },
          onError: (e) {
            debugPrint('Error streaming chat messages with $cId: $e');
          },
        );
  }

  Future<void> loadChatsForCurrentUser() async {
    final currentUser = currentEmployee;
    if (currentUser == null) return;

    if (_firebaseService.isAvailable) {
      try {
        final existingRoomContacts =
            await _firebaseService.getUserChatContactIds(currentUser.id);
        for (var cId in existingRoomContacts) {
          _chatRoomContactIds.add(cId);
          ensureChatLoaded(cId);
        }
      } catch (e) {
        debugPrint('Error loading user chat rooms: $e');
      }
    }

    final contacts = getChatContacts(currentUser);
    for (var contact in contacts) {
      ensureChatLoaded(contact.id);
    }
  }

  Future<List<AttendanceRecord>> getEmployeeRecords(String empId) async {
    final cleanId = empId.trim();
    if (cleanId.isEmpty) return [];

    // Find matching employee to check all identifier variants (id, name, email)
    final match = _employees.firstWhere(
      (e) =>
          e.id.toLowerCase() == cleanId.toLowerCase() ||
          e.email.toLowerCase() == cleanId.toLowerCase() ||
          e.name.toLowerCase() == cleanId.toLowerCase(),
      orElse: () => CompanyEmployee(id: '', name: '', email: '', position: ''),
    );

    final candidateIds = <String>{cleanId.toLowerCase()};
    if (match.id.isNotEmpty) candidateIds.add(match.id.toLowerCase());
    if (match.name.isNotEmpty) candidateIds.add(match.name.toLowerCase());
    if (match.email.isNotEmpty) candidateIds.add(match.email.toLowerCase());

    // 1. If requesting current user and in-memory records are present
    if (candidateIds.contains(_employeeId.toLowerCase()) && _records.isNotEmpty) {
      return _records;
    }

    // 2. Direct Firestore query across candidate identifiers
    if (_firebaseService.isAvailable) {
      for (final idToTry in candidateIds) {
        final fetched = await _firebaseService.getUserRecords(idToTry);
        if (fetched.isNotEmpty) {
          return fetched;
        }
      }
    }

    // 3. Check in-memory company records
    final fromAll = _allCompanyRecords
        .where((r) =>
            r.employeeId != null &&
            candidateIds.contains(r.employeeId!.trim().toLowerCase()))
        .toList();
    if (fromAll.isNotEmpty) {
      return fromAll;
    }

    // 4. Fallback if candidate matches current employee
    if (candidateIds.contains(_employeeId.toLowerCase())) {
      return _records;
    }
    return [];
  }

  int get pendingApprovalsCount {
    if (currentEmployee?.role == 'hr' ||
        currentEmployee?.role == 'admin' ||
        canEditCompanyInfo) {
      return _allCompanyRequests
          .where(
            (r) =>
                (r.status == 'Pending' || r.status == 'Pending HR') &&
                r.employeeId != _employeeId,
          )
          .length;
    }
    if (currentEmployee?.role == 'supervisor') {
      final subordinateIds = _structures
          .where((s) => s.supervisorId == _employeeId)
          .expand(
            (s) =>
                _employees.where((e) => e.structureId == s.id).map((e) => e.id),
          )
          .toSet();
      return _allCompanyRequests
          .where(
            (r) =>
                (r.status == 'Pending' || r.status == 'Pending Supervisor') &&
                subordinateIds.contains(r.employeeId),
          )
          .length;
    }
    return 0;
  }

  Future<List<Request>> getEmployeeRequests(String empId) async {
    final cleanId = empId.trim();
    if (cleanId.isEmpty) return [];

    final match = _employees.firstWhere(
      (e) =>
          e.id.toLowerCase() == cleanId.toLowerCase() ||
          e.email.toLowerCase() == cleanId.toLowerCase() ||
          e.name.toLowerCase() == cleanId.toLowerCase(),
      orElse: () => CompanyEmployee(id: '', name: '', email: '', position: ''),
    );

    final candidateIds = <String>{cleanId.toLowerCase()};
    if (match.id.isNotEmpty) candidateIds.add(match.id.toLowerCase());
    if (match.name.isNotEmpty) candidateIds.add(match.name.toLowerCase());
    if (match.email.isNotEmpty) candidateIds.add(match.email.toLowerCase());

    if (_firebaseService.isAvailable) {
      for (final idToTry in candidateIds) {
        final fetched = await _firebaseService.getUserRequests(idToTry);
        if (fetched.isNotEmpty) {
          _allRequestsMap[cleanId] = fetched;
          return fetched;
        }
      }
    }

    final fromAll = _allCompanyRequests
        .where((r) =>
            r.employeeId != null &&
            candidateIds.contains(r.employeeId!.trim().toLowerCase()))
        .toList();
    if (fromAll.isNotEmpty) {
      _allRequestsMap[cleanId] = fromAll;
      return fromAll;
    }
    return _allRequestsMap[cleanId] ?? [];
  }

  List<Request> getRequestsForEmployee(String empId) =>
      _allRequestsMap[empId] ?? [];

  // Profile image management
  Future<void> updateProfileImage(dynamic file) async {
    String? base64OrUrl;
    if (file is String?) {
      base64OrUrl = file;
    }

    _avatarPath = base64OrUrl;

    // 1. Update in-memory employee list and current employee
    final empIndex = _employees.indexWhere((e) => e.id == _employeeId);
    if (empIndex != -1) {
      final updatedEmp = _employees[empIndex].copyWith(
        avatarUrl: base64OrUrl,
        overrideAvatarUrl: true,
      );
      _employees[empIndex] = updatedEmp;

      // 2. Persist to Firestore
      if (_firebaseService.isAvailable) {
        await _firebaseService.saveEmployee(updatedEmp);
      }
    }

    // 3. Persist to SharedPreferences so it survives restarts/offline
    try {
      final prefs = await SharedPreferences.getInstance();
      if (base64OrUrl != null && base64OrUrl.isNotEmpty) {
        await prefs.setString('user_avatar_$_employeeId', base64OrUrl);
      } else {
        await prefs.remove('user_avatar_$_employeeId');
      }
    } catch (e) {
      debugPrint('Error saving user avatar to prefs: $e');
    }

    notifyListeners();
  }

  Future<void> switchProfile(String userId) async {
    final emp = _employees.firstWhere(
      (e) => e.id == userId,
      orElse: () => _employees.isNotEmpty
          ? _employees.first
          : CompanyEmployee(
              id: userId,
              name: _userName.isNotEmpty ? _userName : userId,
              email: _email,
              position: _position,
              companyCode: _currentCompanyCode,
              role: _role,
            ),
    );
    _employeeId = emp.id;
    _userName = emp.name;
    _userTitle = emp.position;
    _email = emp.email;
    _department = emp.structureId ?? '';
    _position = emp.position;
    _avatarPath = emp.avatarUrl;

    _records.clear();
    _isClockedIn = false;
    _activeRecord = null;

    for (var sub in _chatSubscriptionsMap.values) {
      sub.cancel();
    }
    _chatSubscriptionsMap.clear();
    _chatMessagesMap.clear();

    await _saveAuthSession(
      true,
      _employeeId,
      name: _userName,
      email: _email,
      position: _position,
    );

    // Restart listeners
    await _setupFirestoreListeners();
    recalculateAllStats();
    notifyListeners();
  }

  Future<void> updatePassword(dynamic oldOrNew, [dynamic newPass]) async {
    final newPassword = (newPass != null ? newPass.toString() : oldOrNew.toString()).trim();
    final emp = currentEmployee;
    if (emp != null && newPassword.isNotEmpty) {
      final updated = emp.copyWith(password: newPassword);
      await updateEmployee(updated);
    }
  }

  // Group resolution with accurate date ranges
  String? getGroupIdForDate(dynamic emp, DateTime date) {
    if (emp is! CompanyEmployee) return null;
    final target = DateTime(date.year, date.month, date.day);

    if (emp.groupHistory.isNotEmpty) {
      final validEntries = emp.groupHistory
          .where((e) => e.groupId.isNotEmpty && e.startDate.isNotEmpty)
          .toList();

      // 1. Check specific bounded periods (has both start and end date)
      for (var entry in validEntries) {
        if (entry.endDate.isNotEmpty) {
          final start = _parseFlexibleDateOnly(entry.startDate);
          final end = _parseFlexibleDateOnly(entry.endDate);
          if (start != null && end != null) {
            if ((target.isAtSameMomentAs(start) || target.isAfter(start)) &&
                (target.isAtSameMomentAs(end) || target.isBefore(end))) {
              return entry.groupId;
            }
          }
        }
      }

      // 2. Check ongoing periods (endDate is empty), sorted newest start date first
      final ongoing = validEntries.where((e) => e.endDate.isEmpty).toList()
        ..sort((a, b) {
          final da = _parseFlexibleDateOnly(a.startDate) ?? DateTime(1900);
          final db = _parseFlexibleDateOnly(b.startDate) ?? DateTime(1900);
          return db.compareTo(da);
        });

      for (var entry in ongoing) {
        final start = _parseFlexibleDateOnly(entry.startDate);
        if (start != null) {
          if (target.isAtSameMomentAs(start) || target.isAfter(start)) {
            return entry.groupId;
          }
        }
      }

      // 3. Fallback: check all valid entries where start <= target
      for (var entry in validEntries) {
        final start = _parseFlexibleDateOnly(entry.startDate);
        final end = _parseFlexibleDateOnly(entry.endDate);
        if (start != null) {
          if (target.isAtSameMomentAs(start) || target.isAfter(start)) {
            if (end == null ||
                target.isAtSameMomentAs(end) ||
                target.isBefore(end)) {
              return entry.groupId;
            }
          }
        }
      }

      // 4. If target is BEFORE all entries in groupHistory:
      // Return the group of the earliest recorded period (employee was in that shift before the change)
      final sortedAsc = List<GroupHistoryEntry>.from(validEntries)
        ..sort((a, b) {
          final da = _parseFlexibleDateOnly(a.startDate) ?? DateTime(2100);
          final db = _parseFlexibleDateOnly(b.startDate) ?? DateTime(2100);
          return da.compareTo(db);
        });
      if (sortedAsc.isNotEmpty) {
        final earliestStart = _parseFlexibleDateOnly(sortedAsc.first.startDate);
        if (earliestStart != null && target.isBefore(earliestStart)) {
          return sortedAsc.first.groupId;
        }
      }
    }

    return emp.groupId;
  }

  /// Calculates the hours deducted for an approved leave request
  double calculateRequestLeaveHours(Request req, CompanyEmployee emp) {
    if (req.type != 'Annual Leave') return 0.0;

    final durStr = req.duration.trim().toLowerCase();

    // 1. Direct hours check: e.g. "4 hours", "8 hrs", "8h"
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hour|hr|h\b)').firstMatch(durStr);
    if (hourMatch != null) {
      final h = double.tryParse(hourMatch.group(1)!);
      if (h != null && h > 0) return h;
    }

    // 2. Day count check: e.g. "1 Day", "2 Days", "3 days"
    double days = 1.0;
    final dayMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:day)').firstMatch(durStr);
    if (dayMatch != null) {
      days = double.tryParse(dayMatch.group(1)!) ?? 1.0;
    } else if (RegExp(r'^\d+(\.\d+)?$').hasMatch(durStr)) {
      days = double.tryParse(durStr) ?? 1.0;
    } else if (durStr.contains('half')) {
      days = 0.5;
    } else if (req.date.contains(' - ')) {
      final parts = req.date.split(' - ');
      try {
        DateTime? d1;
        DateTime? d2;
        try {
          d1 = DateFormat('yyyy-MM-dd').parse(parts[0].trim());
        } catch (_) {
          try {
            d1 = DateFormat('MMMM d, yyyy').parse(parts[0].trim());
          } catch (_) {}
        }
        try {
          d2 = DateFormat('yyyy-MM-dd').parse(parts[1].trim());
        } catch (_) {
          try {
            d2 = DateFormat('MMMM d, yyyy').parse(parts[1].trim());
          } catch (_) {}
        }
        if (d1 != null && d2 != null) {
          final diff = d2.difference(d1).inDays + 1;
          if (diff > 0) days = diff.toDouble();
        }
      } catch (_) {}
    }

    DateTime reqDate = DateTime.now();
    try {
      final cleanDateStr = req.date.split(' - ').first.trim();
      reqDate = DateFormat('yyyy-MM-dd').parse(cleanDateStr);
    } catch (_) {
      try {
        final cleanDateStr = req.date.split(' - ').first.trim();
        reqDate = DateFormat('MMMM d, yyyy').parse(cleanDateStr);
      } catch (_) {}
    }

    final groupId = getGroupIdForDate(emp, reqDate);
    final group = _groups.where((g) => g.id == groupId).firstOrNull;
    final shift = _shifts.where((s) => s.id == group?.shiftId).firstOrNull;

    double hoursPerDay = 8.0;
    if (shift != null) {
      final shiftMins = shift.getShiftDurationMinutesForDate(reqDate);
      if (shiftMins > 0) {
        hoursPerDay = shiftMins / 60.0;
      }
    } else if (emp.workingHours > 0) {
      hoursPerDay = (emp.workingHours / 20.0).clamp(4.0, 12.0);
    }

    return days * hoursPerDay;
  }

  /// Adjusts employee's annual leave balance when a request is approved or un-approved
  Future<void> _adjustAnnualLeaveBalance({
    required Request request,
    required String empId,
    required bool isApproval, // true to deduct, false to refund
  }) async {
    if (request.type != 'Annual Leave') return;

    final empIndex = _employees.indexWhere((e) => e.id == empId);
    if (empIndex == -1) return;

    final emp = _employees[empIndex];
    final hours = calculateRequestLeaveHours(request, emp);
    if (hours <= 0) return;

    double newBalance = emp.annualLeaveBalance;
    if (isApproval) {
      newBalance = (newBalance - hours).clamp(0.0, 9999.0);
    } else {
      newBalance = (newBalance + hours).clamp(0.0, 9999.0);
    }

    // Only update if balance actually changed
    if ((newBalance - emp.annualLeaveBalance).abs() > 0.001) {
      final updatedEmp = emp.copyWith(annualLeaveBalance: newBalance);
      _employees[empIndex] = updatedEmp;
      notifyListeners();
      if (_firebaseService.isAvailable) {
        try {
          await _firebaseService.saveEmployee(updatedEmp);
        } catch (e) {
          debugPrint('Error updating annual leave balance in Firebase: $e');
        }
      }
    }
  }

  Future<void> submitRequest(
    dynamic type,
    dynamic date,
    dynamic duration, {
    dynamic targetShiftId,
    String? employeeId,
    String? note,
  }) async {
    if (isDateStringInClosedMonth(date)) {
      debugPrint('Cannot submit request for closed month: $date');
      return;
    }

    final empId = employeeId ?? _employeeId;

    // Auto-approve if the employee is the top of the structure and manager of it
    String status = 'Pending Supervisor';
    bool isTopManager = false;
    try {
      isTopManager = _structures.any(
        (s) =>
            s.supervisorId == empId &&
            (s.parentId == null || s.parentId!.isEmpty),
      );
      if (isTopManager) {
        status = 'Approved';
      }
    } catch (_) {}

    if (!isTopManager) {
      // Find employee to check their structure supervisor
      final emp = _employees.where((e) => e.id == empId).firstOrNull ?? currentEmployee;
      String? structureSupervisorId;
      if (emp?.structureId != null && emp!.structureId!.isNotEmpty) {
        final struct = _structures.where((s) => s.id == emp.structureId).firstOrNull;
        structureSupervisorId = struct?.supervisorId;
      }

      // Check if structure has an active supervisor who is not the submitter
      final hasSupervisor = structureSupervisorId != null &&
          structureSupervisorId.isNotEmpty &&
          structureSupervisorId != empId &&
          _employees.any((e) => e.id == structureSupervisorId) &&
          emp?.role != 'hr' &&
          emp?.role != 'admin';

      // Check if company has an HR Manager
      final hasHRManager = _employees.any(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != empId,
      );

      if (hasSupervisor) {
        // Starts with Supervisor
        status = 'Pending Supervisor';
      } else if (hasHRManager) {
        // Structure does not have a supervisor -> pass supervisor review, go to HR Manager
        status = 'Pending HR';
      } else {
        // Neither supervisor nor HR Manager -> pass both directly to Approved!
        status = 'Approved';
      }
    }

    final newReq = Request(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      type: type.toString(),
      date: date.toString(),
      duration: duration.toString(),
      status: status,
      targetShiftId: targetShiftId?.toString(),
      employeeId: empId,
      note: note,
      createdAt: DateTime.now().toIso8601String(),
      actionBy: (isTopManager || status == 'Approved') ? empId : null,
      actionDate: (isTopManager || status == 'Approved') ? DateTime.now().toIso8601String() : null,
    );
    if (_allRequestsMap[empId] == null) {
      _allRequestsMap[empId] = [];
    }
    _allRequestsMap[empId]!.insert(0, newReq);
    _allCompanyRequests.removeWhere((r) => r.id == newReq.id);
    _allCompanyRequests.insert(0, newReq);
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.saveRequest(empId, newReq);
    }

    if (status == 'Approved') {
      await _adjustAnnualLeaveBalance(request: newReq, empId: empId, isApproval: true);
    }
  }

  Future<void> deleteRequest(dynamic a, [dynamic b]) async {
    String empId = b != null ? a.toString() : _employeeId;
    final rId = (b ?? a).toString();
    if (empId == _employeeId) {
      final found = _allCompanyRequests.where((r) => r.id == rId).firstOrNull;
      if (found != null && found.employeeId != null) {
        empId = found.employeeId!;
      }
    }
    final targetReq = _allCompanyRequests.where((r) => r.id == rId).firstOrNull ??
        _allRequestsMap[empId]?.where((r) => r.id == rId).firstOrNull;

    if (targetReq != null && isDateStringInClosedMonth(targetReq.date)) {
      debugPrint('Cannot delete request for closed month: ${targetReq.date}');
      return;
    }

    _allRequestsMap[empId]?.removeWhere((r) => r.id == rId);
    _allCompanyRequests.removeWhere((r) => r.id == rId);
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteRequest(empId, rId);
    }

    if (targetReq != null && targetReq.status == 'Approved') {
      await _adjustAnnualLeaveBalance(request: targetReq, empId: empId, isApproval: false);
    }
  }

  Future<void> updateRequestStatus(dynamic a, dynamic b, [dynamic c]) async {
    String empId = _employeeId;
    String reqId = '';
    String targetStatus = '';
    if (c != null) {
      empId = a.toString();
      reqId = b.toString();
      targetStatus = c.toString();
    } else {
      reqId = a.toString();
      targetStatus = b.toString();
    }

    if (empId == _employeeId) {
      final found = _allCompanyRequests.where((r) => r.id == reqId).firstOrNull;
      if (found != null && found.employeeId != null) {
        empId = found.employeeId!;
      }
    }

    final isHR = currentEmployee?.role == 'hr' ||
        currentEmployee?.role == 'admin' ||
        canEditCompanyInfo;
    final isSupervisor = currentEmployee?.role == 'supervisor';

    final existing = _allCompanyRequests.where((r) => r.id == reqId).firstOrNull ??
        _allRequestsMap[empId]?.where((r) => r.id == reqId).firstOrNull;

    if (existing != null && isDateStringInClosedMonth(existing.date)) {
      debugPrint('Cannot update request status for closed month: ${existing.date}');
      return;
    }
    final oldStatus = existing?.status;

    String finalStatus = targetStatus;
    String? supBy = existing?.supervisorActionBy;
    String? supDate = existing?.supervisorActionDate;
    String? supStatus = existing?.supervisorStatus;
    String? hrBy = existing?.hrActionBy;
    String? hrDate = existing?.hrActionDate;
    String? hrStatus = existing?.hrStatus;
    String? actBy = existing?.actionBy;
    String? actDate = existing?.actionDate;

    final nowIso = DateTime.now().toIso8601String();

    if (targetStatus == 'Rejected') {
      finalStatus = 'Rejected';
      if (isHR) {
        hrBy = _employeeId;
        hrDate = nowIso;
        hrStatus = 'Rejected';
      } else {
        supBy = _employeeId;
        supDate = nowIso;
        supStatus = 'Rejected';
      }
      actBy = _employeeId;
      actDate = nowIso;
    } else if (targetStatus == 'Approved') {
      // Check if the organization has an HR Manager
      final hasHRManager = _employees.any(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != empId,
      );

      // If supervisor approves a request in 'Pending Supervisor' (or 'Pending')
      if (isSupervisor && !isHR && (existing?.status == 'Pending Supervisor' || existing?.status == 'Pending')) {
        if (hasHRManager) {
          finalStatus = 'Pending HR';
          supBy = _employeeId;
          supDate = nowIso;
          supStatus = 'Approved';
        } else {
          // If no HR Manager, just pass HR and approve directly!
          finalStatus = 'Approved';
          supBy = _employeeId;
          supDate = nowIso;
          supStatus = 'Approved';
          actBy = _employeeId;
          actDate = nowIso;
        }
      } else {
        // HR approves or final approval
        finalStatus = 'Approved';
        hrBy = _employeeId;
        hrDate = nowIso;
        hrStatus = 'Approved';
        actBy = _employeeId;
        actDate = nowIso;
      }
    } else if (targetStatus == 'Pending HR') {
      finalStatus = 'Pending HR';
      supBy = _employeeId;
      supDate = nowIso;
      supStatus = 'Approved';
    }

    Request? updatedReq;
    final reqs = _allRequestsMap[empId];
    if (reqs != null) {
      final idx = reqs.indexWhere((r) => r.id == reqId);
      if (idx != -1) {
        final old = reqs[idx];
        updatedReq = old.copyWith(
          status: finalStatus,
          employeeId: empId,
          actionBy: actBy,
          actionDate: actDate,
          supervisorActionBy: supBy,
          supervisorActionDate: supDate,
          supervisorStatus: supStatus,
          hrActionBy: hrBy,
          hrActionDate: hrDate,
          hrStatus: hrStatus,
        );
        reqs[idx] = updatedReq;
      }
    }

    final cIdx = _allCompanyRequests.indexWhere((r) => r.id == reqId);
    if (cIdx != -1) {
      final old = _allCompanyRequests[cIdx];
      updatedReq = old.copyWith(
        status: finalStatus,
        employeeId: empId,
        actionBy: actBy,
        actionDate: actDate,
        supervisorActionBy: supBy,
        supervisorActionDate: supDate,
        supervisorStatus: supStatus,
        hrActionBy: hrBy,
        hrActionDate: hrDate,
        hrStatus: hrStatus,
      );
      _allCompanyRequests[cIdx] = updatedReq;
    }

    notifyListeners();

    final reqForBalance = updatedReq ?? existing;
    if (reqForBalance != null) {
      if (finalStatus == 'Approved' && oldStatus != 'Approved') {
        await _adjustAnnualLeaveBalance(request: reqForBalance, empId: empId, isApproval: true);
      } else if (oldStatus == 'Approved' && finalStatus != 'Approved') {
        await _adjustAnnualLeaveBalance(request: reqForBalance, empId: empId, isApproval: false);
      }
    }

    if (updatedReq != null) {
      if (_firebaseService.isAvailable) {
        await _firebaseService.saveRequest(empId, updatedReq);
      }

      // Automated messages to the employee who registered the request (bilingual English + Kurdish):
      if (empId != _employeeId) {
        final kuType = _kurdishRequestType(updatedReq.type);

        if (finalStatus == 'Approved') {
          // When request gets final approval
          final approvedByLabelEn = hrBy != null ? 'HR Management' : 'your Supervisor';
          final approvedByLabelKu = hrBy != null
              ? 'بەڕێوەبەرایەتی سەرچاوە مرۆییەکان (HR)'
              : 'سەرپەرشتیارەکەت';

          String enText =
              'Your request for ${updatedReq.type} on ${updatedReq.date} has been approved by $approvedByLabelEn.';
          String kuText =
              'داواکارییەکەت بۆ $kuType لە ڕێکەوتی ${updatedReq.date} لەلایەن $approvedByLabelKu پەسەندکرا.';

          if (updatedReq.type == 'Annual Leave') {
            final emp = _employees.where((e) => e.id == empId).firstOrNull;
            if (emp != null) {
              final bal = emp.annualLeaveBalance.toStringAsFixed(1);
              enText += ' Remaining annual leave balance: $bal hours.';
              kuText += ' باڵانسی مۆڵەتی ساڵانەی ماوەت: $bal کاتژمێر.';
            }
          }

          final messageText = '$enText\n\n$kuText';
          await sendChatMessage(empId, messageText);
        } else if (finalStatus == 'Pending HR') {
          // When Supervisor approves and it moves to HR Manager
          final enText =
              'Your request for ${updatedReq.type} on ${updatedReq.date} has been approved by your Supervisor and forwarded to HR Manager for review.';
          final kuText =
              'داواکارییەکەت بۆ $kuType لە ڕێکەوتی ${updatedReq.date} لەلایەن سەرپەرشتیارەکەت پەسەندکرا و ڕەوانەی بەڕێوەبەری سەرچاوە مرۆییەکان (HR) کرا بۆ پێداچوونەوە.';
          final messageText = '$enText\n\n$kuText';
          await sendChatMessage(empId, messageText);
        } else if (finalStatus == 'Rejected') {
          final rejecterEn = isHR ? 'HR Management' : 'your Supervisor';
          final rejecterKu = isHR
              ? 'بەڕێوەبەرایەتی سەرچاوە مرۆییەکان (HR)'
              : 'سەرپەرشتیارەکەت';
          final enText =
              'Your request for ${updatedReq.type} on ${updatedReq.date} has been rejected by $rejecterEn.';
          final kuText =
              'داواکارییەکەت بۆ $kuType لە ڕێکەوتی ${updatedReq.date} لەلایەن $rejecterKu ڕەتکرایەوە.';
          final messageText = '$enText\n\n$kuText';
          await sendChatMessage(empId, messageText);
        }
      }
    }
  }

  String _kurdishRequestType(String rawType) {
    switch (rawType.trim()) {
      case 'Annual Leave':
        return 'مۆڵەتی ساڵانە';
      case 'Sick Leave':
        return 'مۆڵەتی نەخۆشی';
      case 'Hourly Leave':
        return 'مۆڵەتی کاتی (کاتژمێری)';
      case 'Permission':
        return 'مۆڵەتی کاتی';
      case 'Overtime Approval':
      case 'Overtime':
        return 'کاتی زیادە (ئۆڤەرتایم)';
      case 'Forgot to Clock Out':
        return 'لەبیرکردنی تۆماری چوونەدەرەوە';
      case 'Change Shift':
        return 'گۆڕینی شێفت';
      case 'Missing Punch':
        return 'تۆمارکردنی لەبیرچوو';
      case 'Expense':
        return 'خەرجی';
      default:
        return rawType;
    }
  }

  /// Returns the authorized geographical work zones (coordinates and radius)
  /// applicable to the employee based on structure or company work locations.
  List<Map<String, dynamic>> getAllowedZones([CompanyEmployee? targetEmp]) {
    final emp = targetEmp ?? currentEmployee;
    if (emp == null) return [];

    final List<Map<String, dynamic>> allowedZones = [];

    // 1. Structure location
    if (emp.structureId != null) {
      final struct = _structures.where((s) => s.id == emp.structureId).firstOrNull;
      if (struct != null &&
          struct.latitude != null &&
          struct.longitude != null &&
          struct.radius != null) {
        allowedZones.add({
          'id': struct.id,
          'lat': struct.latitude!,
          'lng': struct.longitude!,
          'radius': struct.radius!,
          'name': struct.name,
        });
      }
    }

    // 2. Work locations for employee's company
    final empCompany = emp.companyCode.trim().toLowerCase();
    final companyLocs = _locations.where((l) {
      final locComp = l.companyCode.trim().toLowerCase();
      return locComp == empCompany || (empCompany.isEmpty && (locComp.isEmpty || locComp == 'amada'));
    }).toList();

    final String? groupId = getGroupIdForDate(emp, DateTime.now()) ?? emp.groupId;
    final bool anyLocationHasGroups = companyLocs.any((l) => l.groupIds.isNotEmpty);

    for (var loc in companyLocs) {
      final zoneData = {
        'id': loc.id,
        'lat': loc.latitude,
        'lng': loc.longitude,
        'radius': loc.radius,
        'name': loc.name,
        'wifiBssid': loc.wifiBssid,
        'wifiSsid': loc.wifiSsid,
        'requireWifi': loc.requireWifi,
      };
      if (groupId != null && groupId.isNotEmpty) {
        // If employee belongs to a group, they can only access locations explicitly
        // assigned to their group (or general locations if no group-specific locations exist)
        if (loc.groupIds.contains(groupId) || (!anyLocationHasGroups && loc.groupIds.isEmpty)) {
          allowedZones.add(zoneData);
        }
      } else {
        if (!anyLocationHasGroups || loc.groupIds.isEmpty) {
          allowedZones.add(zoneData);
        }
      }
    }

    return allowedZones;
  }

  // Clock & Attendance stubs
  Future<String?> verifyLocation() async {
    final emp = currentEmployee;
    if (emp == null) return 'No employee found.';

    final allowedZones = getAllowedZones(emp);

    if (allowedZones.isEmpty) {
      return translate('location_outside_range');
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return translate('loc_service_disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return translate('loc_permission_denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return translate('loc_permission_denied_forever');
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return '${translate('loc_error')}: $e';
    }

    // 1. Anti-Cheat: Reject Fake GPS / Mock Location
    if (position.isMocked) {
      return translate('fake_gps_detected');
    }

    // 2. Read connected Wi-Fi BSSID and SSID (cross-platform)
    String? currentBssid;
    String? currentSsid;
    if (!kIsWeb) {
      try {
        final wifiDetails = await WifiDetectorService.detectCurrentWifi();
        currentBssid = wifiDetails['bssid'];
        currentSsid = wifiDetails['ssid'];
      } catch (e) {
        debugPrint('Error getting Wi-Fi info: $e');
      }
    }

    // 3. Verify allowed zones with GPS and Office Wi-Fi BSSID
    String? wifiMismatchError;

    for (var zone in allowedZones) {
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone['lat'] as double,
        zone['lng'] as double,
      );
      final inGpsRadius = distanceInMeters <= (zone['radius'] as double);

      final String? expectedBssid = (zone['wifiBssid'] as String?)?.trim().toLowerCase();
      final String? expectedSsid = (zone['wifiSsid'] as String?)?.trim();
      final bool requireWifi = zone['requireWifi'] == true;

      bool wifiMatches = false;
      if (expectedBssid != null && expectedBssid.isNotEmpty && currentBssid != null) {
        final allowedList = expectedBssid.split(',').map((b) => b.trim().toLowerCase()).toList();
        if (allowedList.contains(currentBssid)) {
          wifiMatches = true;
        }
      } else if (expectedSsid != null && expectedSsid.isNotEmpty && currentSsid != null) {
        if (currentSsid.toLowerCase() == expectedSsid.toLowerCase()) {
          wifiMatches = true;
        }
      }

      if (requireWifi) {
        // Strict mode: Must be within GPS radius AND connected to the office Wi-Fi
        if (inGpsRadius && (wifiMatches || kIsWeb)) {
          return null; // Both GPS & Wi-Fi verified!
        } else if (inGpsRadius && !wifiMatches) {
          wifiMismatchError = translate('wifi_not_matched', params: {
            'wifi': expectedSsid?.isNotEmpty == true ? expectedSsid! : (expectedBssid ?? 'Office Wi-Fi'),
          });
        }
      } else {
        // Flexible mode: Validated if inside GPS radius OR connected to the office Wi-Fi
        if (inGpsRadius || (wifiMatches && !position.isMocked)) {
          return null;
        }
      }
    }

    if (wifiMismatchError != null) {
      return wifiMismatchError;
    }

    return translate('location_outside_range');
  }

  /// Helper for HR/Admins to detect the current office Wi-Fi BSSID and SSID
  Future<Map<String, String?>> getCurrentWifiDetails() async {
    return await WifiDetectorService.detectCurrentWifi();
  }

  Future<String?> clockIn([dynamic a, dynamic b]) async {
    _isClockedIn = true;
    _activeRecord = AttendanceRecord(
      checkIn: DateTime.now(),
      employeeId: _employeeId,
    );
    // Add to local records list at the beginning (sorted newest first)
    _records.removeWhere(
      (r) =>
          r.checkIn.year == _activeRecord!.checkIn.year &&
          r.checkIn.month == _activeRecord!.checkIn.month &&
          r.checkIn.day == _activeRecord!.checkIn.day &&
          r.checkIn.hour == _activeRecord!.checkIn.hour &&
          r.checkIn.minute == _activeRecord!.checkIn.minute,
    );
    _records.insert(0, _activeRecord!);

    if (_firebaseService.isAvailable) {
      try {
        await _firebaseService.saveRecord(_employeeId, _activeRecord!);
      } catch (e) {
        debugPrint('Error saving clock in record to Firebase: $e');
      }
    }
    recalculateAllStats();
    notifyListeners();
    return null;
  }

  Future<String?> clockOut([dynamic a, dynamic b]) async {
    final now = DateTime.now();

    // If _activeRecord is null, locate the latest open record
    if (_activeRecord == null) {
      final openIdx = _records.indexWhere((r) => r.checkOut == null);
      if (openIdx != -1) {
        _activeRecord = _records[openIdx];
      }
    }

    if (_activeRecord != null) {
      _activeRecord = _activeRecord!.copyWith(
        checkOut: now,
        employeeId: _employeeId,
      );
      // Update it in the records list
      final idx = _records.indexWhere(
        (r) =>
            r.checkIn.year == _activeRecord!.checkIn.year &&
            r.checkIn.month == _activeRecord!.checkIn.month &&
            r.checkIn.day == _activeRecord!.checkIn.day &&
            r.checkIn.hour == _activeRecord!.checkIn.hour &&
            r.checkIn.minute == _activeRecord!.checkIn.minute,
      );
      if (idx != -1) {
        _records[idx] = _activeRecord!;
      } else {
        _records.insert(0, _activeRecord!);
      }
      if (_firebaseService.isAvailable) {
        try {
          await _firebaseService.saveRecord(_employeeId, _activeRecord!);
        } catch (e) {
          debugPrint('Error saving clock out record to Firebase: $e');
        }
      }
    } else {
      // Create a completed session for today
      _activeRecord = AttendanceRecord(
        checkIn: now.subtract(const Duration(hours: 1)),
        checkOut: now,
        employeeId: _employeeId,
      );
      _records.insert(0, _activeRecord!);
      if (_firebaseService.isAvailable) {
        try {
          await _firebaseService.saveRecord(_employeeId, _activeRecord!);
        } catch (e) {
          debugPrint('Error saving fallback clock out to Firebase: $e');
        }
      }
    }
    _isClockedIn = false;
    _activeRecord = null;
    recalculateAllStats();
    notifyListeners();
    return null;
  }

  /// Upsert an AttendanceRecord directly into local state for immediate reactivity
  void upsertRecordLocally(AttendanceRecord record) {
    if (isMonthClosed(record.checkIn)) {
      debugPrint('Cannot add or edit attendance record for closed month');
      return;
    }

    final cleanEmpId = record.employeeId?.trim().toLowerCase();

    // 1. Update in _allCompanyRecords
    final idxAll = _allCompanyRecords.indexWhere((r) =>
        r.employeeId?.trim().toLowerCase() == cleanEmpId &&
        r.checkIn.year == record.checkIn.year &&
        r.checkIn.month == record.checkIn.month &&
        r.checkIn.day == record.checkIn.day &&
        r.checkIn.hour == record.checkIn.hour &&
        r.checkIn.minute == record.checkIn.minute);
    if (idxAll != -1) {
      _allCompanyRecords[idxAll] = record;
    } else {
      _allCompanyRecords.insert(0, record);
    }

    // 2. If for currently logged-in user, also update _records
    if (cleanEmpId != null && cleanEmpId == _employeeId.trim().toLowerCase()) {
      final idx = _records.indexWhere((r) =>
          r.checkIn.year == record.checkIn.year &&
          r.checkIn.month == record.checkIn.month &&
          r.checkIn.day == record.checkIn.day &&
          r.checkIn.hour == record.checkIn.hour &&
          r.checkIn.minute == record.checkIn.minute);
      if (idx != -1) {
        _records[idx] = record;
      } else {
        _records.insert(0, record);
      }
    }

    recalculateAllStats();
    notifyListeners();
  }

  /// Delete a punch session from local state and remote Firebase
  Future<void> deletePunchSession({
    required String employeeId,
    required AttendanceRecord record,
    String? reason,
  }) async {
    if (isMonthClosed(record.checkIn)) {
      debugPrint('Cannot delete punch session for closed month');
      return;
    }

    final cleanEmpId = employeeId.trim().toLowerCase();

    // 1. Remove from _allCompanyRecords
    _allCompanyRecords.removeWhere((r) =>
        (r.employeeId?.trim().toLowerCase() == cleanEmpId) &&
        r.checkIn.year == record.checkIn.year &&
        r.checkIn.month == record.checkIn.month &&
        r.checkIn.day == record.checkIn.day &&
        r.checkIn.hour == record.checkIn.hour &&
        r.checkIn.minute == record.checkIn.minute);

    // 2. Remove from _records if currently logged-in user
    if (cleanEmpId == _employeeId.trim().toLowerCase()) {
      _records.removeWhere((r) =>
          r.checkIn.year == record.checkIn.year &&
          r.checkIn.month == record.checkIn.month &&
          r.checkIn.day == record.checkIn.day &&
          r.checkIn.hour == record.checkIn.hour &&
          r.checkIn.minute == record.checkIn.minute);
    }

    recalculateAllStats();
    notifyListeners();

    // 3. Delete from Firebase and persist to deleted_punches
    recordDeletedPunchSignature(cleanEmpId, record.checkIn);
    if (record.checkOut != null) {
      recordDeletedPunchSignature(cleanEmpId, record.checkOut!);
    }

    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteRecord(employeeId, record);
      try {
        await _firebaseService.saveDeletedPunch(DeletedPunch(
          id: '${cleanEmpId}_${record.checkIn.millisecondsSinceEpoch}',
          employeeId: cleanEmpId,
          punchTime: record.checkIn,
          punchType: 'checkIn',
          reason: reason,
        ));
        if (record.checkOut != null) {
          await _firebaseService.saveDeletedPunch(DeletedPunch(
            id: '${cleanEmpId}_${record.checkOut!.millisecondsSinceEpoch}',
            employeeId: cleanEmpId,
            punchTime: record.checkOut!,
            punchType: 'checkOut',
            reason: reason,
          ));
        }
      } catch (e) {
        debugPrint('Error saving deleted punch tombstone: $e');
      }
    }
  }

  // HR Management
  List<CompanyEmployee> getEmployeesInStructure(dynamic structId) {
    return employees.where((e) => e.structureId == structId).toList();
  }

  Future<void> deleteStructure(dynamic id) async {
    final strId = id.toString();
    _structures.removeWhere((s) => s.id == strId);
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteStructure(strId);
    }
  }

  Future<void> addStructure(dynamic struct) async {
    final OrgStructure item = (struct is OrgStructure)
        ? ((struct.companyCode.isEmpty || struct.companyCode == 'all') && _currentCompanyCode.isNotEmpty && _currentCompanyCode != 'all'
            ? struct.copyWith(companyCode: _currentCompanyCode)
            : struct)
        : struct;
    final idx = _structures.indexWhere((s) => s.id == item.id);
    if (idx != -1) {
      _structures[idx] = item;
    } else {
      _structures.add(item);
    }
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.saveStructure(item);
    }
  }

  Future<void> updateStructure(dynamic struct) async => await addStructure(struct);

  Future<void> deleteShift(dynamic id) async {
    final strId = id.toString();
    _shifts.removeWhere((s) => s.id == strId);
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteShift(strId);
    }
  }

  Future<void> addShift(dynamic shift) async {
    final WorkShift item = (shift is WorkShift)
        ? ((shift.companyCode.isEmpty || shift.companyCode == 'all') && _currentCompanyCode.isNotEmpty && _currentCompanyCode != 'all'
            ? shift.copyWith(companyCode: _currentCompanyCode)
            : shift)
        : shift;
    final idx = _shifts.indexWhere((s) => s.id == item.id);
    if (idx != -1) {
      _shifts[idx] = item;
    } else {
      _shifts.add(item);
    }
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.saveShift(item);
    }
  }

  Future<void> updateShift(dynamic shift) async => await addShift(shift);

  Future<void> deleteGroup(dynamic id) async {
    final strId = id.toString();
    _groups.removeWhere((g) => g.id == strId);
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteGroup(strId);
    }
  }

  Future<void> addGroup(dynamic group) async {
    final EmployeeGroup item = (group is EmployeeGroup)
        ? ((group.companyCode.isEmpty || group.companyCode == 'all') && _currentCompanyCode.isNotEmpty && _currentCompanyCode != 'all'
            ? group.copyWith(companyCode: _currentCompanyCode)
            : group)
        : group;
    final idx = _groups.indexWhere((g) => g.id == item.id);
    if (idx != -1) {
      _groups[idx] = item;
    } else {
      _groups.add(item);
    }
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.saveGroup(item);
    }
  }

  Future<void> updateGroup(dynamic group) async => await addGroup(group);

  Future<void> deleteEmployee(dynamic id, {String? companyCode}) async {
    final strId = id.toString().trim();
    final targetCode = (companyCode ?? _currentCompanyCode).trim().toLowerCase();

    // Find the employee before removing to determine exact companyCode, email, and ID
    CompanyEmployee? emp;
    for (final e in _employees) {
      if (e.id.trim().toLowerCase() == strId.toLowerCase()) {
        if (targetCode == 'all' || targetCode.isEmpty || e.companyCode.trim().toLowerCase() == targetCode) {
          emp = e;
          break;
        }
      }
    }
    emp ??= _employees.where((e) => e.id.trim().toLowerCase() == strId.toLowerCase()).firstOrNull;

    final effectiveCode = emp?.companyCode.isNotEmpty == true 
        ? emp!.companyCode.trim().toLowerCase() 
        : (targetCode == 'all' ? '' : targetCode);

    _employees.removeWhere((e) =>
        e.id.trim().toLowerCase() == strId.toLowerCase() &&
        (effectiveCode.isEmpty || e.companyCode.trim().toLowerCase() == effectiveCode));

    // Clear local attendance records and requests
    _records.removeWhere((r) => r.employeeId == strId || (emp != null && r.employeeId == emp.id));
    _allRequestsMap.remove(strId);
    if (emp != null) _allRequestsMap.remove(emp.id);
    _allCompanyRequests.removeWhere((r) => r.employeeId == strId || (emp != null && r.employeeId == emp.id));

    notifyListeners();
    await _firebaseService.deleteEmployee(
      strId,
      companyCode: effectiveCode,
      email: emp?.email,
    );
  }

  /// Checks whether an employee ID is already taken in the target company
  bool isEmployeeIdTaken(String id, {String? companyCode, String? excludeEmpId}) {
    return getEmployeeConflict(id, companyCode: companyCode, excludeEmpId: excludeEmpId) != null;
  }

  CompanyEmployee? getEmployeeConflict(String id, {String? companyCode, String? excludeEmpId}) {
    final cleanId = id.trim().toLowerCase();
    if (cleanId.isEmpty) return null;
    final targetCode = (companyCode ?? _currentCompanyCode).trim().toLowerCase();
    return _employees.where((e) {
      if (excludeEmpId != null && e.id.trim().toLowerCase() == excludeEmpId.trim().toLowerCase()) {
        return false;
      }
      if (e.id.trim().toLowerCase() != cleanId) return false;
      if (targetCode == 'all' || targetCode.isEmpty) return true;
      return e.companyCode.trim().toLowerCase() == targetCode;
    }).firstOrNull;
  }

  /// Generates the next sequential numeric user ID ('1', '2', '3', ...) for the target company.
  String getNextEmployeeId({String? companyCode}) {
    final target = (companyCode ?? _currentCompanyCode).trim().toLowerCase();
    int maxId = 0;
    final list = (target == 'all' || target.isEmpty)
        ? _employees
        : _employees.where((e) => e.companyCode.trim().toLowerCase() == target);
    for (final emp in list) {
      final cleanId = emp.id.trim();
      // 1. Direct integer parse
      final directNum = int.tryParse(cleanId);
      if (directNum != null) {
        if (directNum > maxId && directNum < 1000000) {
          maxId = directNum;
        }
        continue;
      }

      // 2. Prefixed integer parse like emp_1, emp_2, USR_3
      final matches = RegExp(r'\d+').allMatches(cleanId);
      for (final m in matches) {
        final val = int.tryParse(m.group(0)!);
        if (val != null && val > maxId && val < 1000000) {
          maxId = val;
        }
      }
    }
    return (maxId + 1).toString();
  }

  Future<void> updateEmployee(dynamic emp, {String? oldId}) async {
    if (emp is CompanyEmployee) {
      var item = emp;
      if (item.companyCode.trim().isEmpty) {
        item = item.copyWith(
          companyCode: _currentCompanyCode == 'all' ? 'amada' : _currentCompanyCode,
        );
      }
      final targetOldId = (oldId != null && oldId.trim().isNotEmpty) ? oldId.trim() : item.id;
      final isIdChanged = targetOldId != item.id;

      if (isIdChanged) {
        // Remove old entry
        _employees.removeWhere((e) =>
            e.id == targetOldId &&
            (e.companyCode.isEmpty || e.companyCode.toLowerCase() == item.companyCode.toLowerCase()));
        final newIndex = _employees.indexWhere((e) =>
            e.id == item.id &&
            (e.companyCode.isEmpty || e.companyCode.toLowerCase() == item.companyCode.toLowerCase()));
        if (newIndex != -1) {
          _employees[newIndex] = item;
        } else {
          _employees.add(item);
        }

        // Update current employeeId and avatar if this was the logged-in user
        if (_employeeId == targetOldId) {
          _employeeId = item.id;
          _avatarPath = item.avatarUrl;
        }

        // Migrate local requests map
        final oldReqs = _allRequestsMap.remove(targetOldId);
        if (oldReqs != null) {
          _allRequestsMap[item.id] = oldReqs.map((r) => r.copyWith(employeeId: item.id)).toList();
        }

        // Migrate local records if active
        final updatedList = _records.map((r) {
          if (r.employeeId == targetOldId) {
            return r.copyWith(employeeId: item.id);
          }
          return r;
        }).toList();
        _records.clear();
        _records.addAll(updatedList);

        notifyListeners();

        // Migrate remote Firebase data
        await _firebaseService.migrateEmployeeId(targetOldId, item.id);
        await _firebaseService.deleteEmployee(targetOldId, companyCode: item.companyCode);
        await _firebaseService.saveEmployee(item);
      } else {
        final index = _employees.indexWhere((e) =>
            e.id == item.id &&
            (e.companyCode.isEmpty || e.companyCode.toLowerCase() == item.companyCode.toLowerCase()));
        if (index != -1) {
          _employees[index] = item;
        } else {
          _employees.add(item);
        }
        if (item.id == _employeeId) {
          _avatarPath = item.avatarUrl;
        }
        notifyListeners();
        await _firebaseService.saveEmployee(item);
      }
    }
  }

  Future<bool> addEmployee(dynamic emp) async {
    if (emp is CompanyEmployee) {
      var toAdd = emp;
      // Ensure companyCode is assigned if not explicitly provided
      if (toAdd.companyCode.trim().isEmpty) {
        if (_currentCompanyCode.isNotEmpty && _currentCompanyCode != 'all') {
          toAdd = toAdd.copyWith(companyCode: _currentCompanyCode);
        } else {
          toAdd = toAdd.copyWith(companyCode: 'amada');
        }
      }

      // If no ID or auto-generated epoch timestamp ID, assign sequential simple number
      if (toAdd.id.trim().isEmpty ||
          (toAdd.id.startsWith('emp_') && toAdd.id.length > 10) ||
          (toAdd.id.startsWith('USR_') && toAdd.id.length > 10)) {
        toAdd = toAdd.copyWith(id: getNextEmployeeId(companyCode: toAdd.companyCode));
      }

      // STRICT DUPLICATE CHECK: Never allow duplicate user ID within company
      final duplicate = getEmployeeConflict(toAdd.id, companyCode: toAdd.companyCode);
      if (duplicate != null) {
        debugPrint(
          'Duplicate employee ID rejected: ID ${toAdd.id} already exists for ${duplicate.name} in company ${toAdd.companyCode}',
        );
        return false;
      }

      _employees.add(toAdd);
      notifyListeners();
      await _firebaseService.saveEmployee(toAdd);
      return true;
    }
    return false;
  }

  /// Re-sequences all employee IDs to simple numbers 1, 2, 3... in sequence.
  Future<void> resequenceEmployeeIds() async {
    // Sort employees: keep order of existing numeric IDs or startDate
    final sorted = List<CompanyEmployee>.from(_employees);
    sorted.sort((a, b) {
      final numA = int.tryParse(a.id) ?? int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
      final numB = int.tryParse(b.id) ?? int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
      if (numA != numB) return numA.compareTo(numB);
      return a.startDate.compareTo(b.startDate);
    });

    int sequence = 1;
    for (final emp in sorted) {
      // Don't modify super admin account if present
      if (emp.id == 'admin_super_account') continue;

      final newId = sequence.toString();
      sequence++;

      if (emp.id != newId) {
        final oldId = emp.id;
        final updatedEmp = emp.copyWith(id: newId);
        await updateEmployee(updatedEmp, oldId: oldId);
      }
    }
  }

  Future<void> restoreSuperAdminUser() async {
    final superAdmin = CompanyEmployee(
      id: 'admin_super_account',
      name: 'Super Admin',
      email: 'admin@company.com',
      position: 'Super Administrator',
      role: 'admin',
      password: 'admin123',
      startDate: DateTime.now().toIso8601String().split('T')[0],
      positionStartDate: DateTime.now().toIso8601String().split('T')[0],
      groupStartDate: DateTime.now().toIso8601String().split('T')[0],
      positionHistory: [],
      groupHistory: [],
      salaryHistory: [],
    );
    await addEmployee(superAdmin);
  }

  Future<void> deleteHoliday(dynamic id) async {
    final strId = id.toString();
    _holidays.removeWhere((h) => h.id == strId);
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteHoliday(strId);
    }
  }

  Future<void> updateHoliday(dynamic holiday) async {
    final Holiday item = (holiday is Holiday)
        ? (holiday.companyCode != _currentCompanyCode
            ? holiday.copyWith(companyCode: _currentCompanyCode)
            : holiday)
        : holiday;
    final idx = _holidays.indexWhere((h) => h.id == item.id);
    if (idx != -1) {
      _holidays[idx] = item;
    } else {
      _holidays.add(item);
    }
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.saveHoliday(item);
    }
  }

  Future<void> addHoliday(dynamic holiday) async => await updateHoliday(holiday);

  Future<void> deleteLocation(dynamic id) async {
    final strId = id.toString();
    _locations.removeWhere((l) => l.id == strId);
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteLocation(strId);
    }
  }

  Future<void> updateLocation(dynamic loc) async {
    final WorkLocation item = (loc is WorkLocation)
        ? (loc.companyCode.isEmpty && _currentCompanyCode.isNotEmpty && _currentCompanyCode != 'all'
            ? loc.copyWith(companyCode: _currentCompanyCode)
            : loc)
        : loc;
    final idx = _locations.indexWhere((l) => l.id == item.id);
    if (idx != -1) {
      _locations[idx] = item;
    } else {
      _locations.add(item);
    }
    notifyListeners();
    if (_firebaseService.isAvailable) {
      await _firebaseService.saveLocation(item);
    }
  }

  Future<void> addLocation(dynamic loc) async => await updateLocation(loc);

  final FaceRecognitionService _faceService = FaceRecognitionService();

  /// Check if the provided face embedding matches any other employee
  CompanyEmployee? findDuplicateFaceEmployee(
    List<double> embedding, {
    String? excludeEmployeeId,
    double threshold = 1.05,
  }) {
    final cleanExclude = excludeEmployeeId?.toString().trim();
    for (final emp in _employees) {
      if (cleanExclude != null && cleanExclude.isNotEmpty && emp.id == cleanExclude) {
        continue;
      }
      if (emp.faceEmbedding == null || emp.faceEmbedding!.isEmpty) {
        continue;
      }
      final dist = _faceService.calculateEuclideanDistance(emp.faceEmbedding!, embedding);
      if (dist < threshold) {
        return emp;
      }
    }
    return null;
  }

  Future<void> updateEmployeeFaceEmbedding(
    dynamic empId,
    List<double>? embedding,
  ) async {
    if (!isHRManager) {
      throw Exception('PERMISSION_DENIED: Only HR Managers can register or delete Face ID.');
    }
    final strId = empId.toString().trim();
    if (embedding != null && embedding.isNotEmpty) {
      final duplicate = findDuplicateFaceEmployee(embedding, excludeEmployeeId: strId);
      if (duplicate != null) {
        throw Exception('DUPLICATE_FACE:${duplicate.name}');
      }
    }

    final index = _employees.indexWhere((e) => e.id == strId);
    if (index != -1) {
      final updated = _employees[index].copyWith(
        faceEmbedding: embedding,
        overrideFaceEmbedding: true,
      );
      await updateEmployee(updated);
    }
  }
  Holiday? getHolidayForEmployee(dynamic arg1, dynamic arg2) {
    DateTime? date;
    String? groupId;
    if (arg1 is DateTime) {
      date = arg1;
      groupId = arg2?.toString();
    } else if (arg2 is DateTime) {
      date = arg2;
      groupId = arg1?.toString();
    }
    if (date == null) return null;
    try {
      return _holidays.firstWhere((h) {
        final isForGroup = h.groupIds.isEmpty || (groupId != null && h.groupIds.contains(groupId));
        if (!isForGroup) return false;
        try {
          final from = DateTime.parse(h.fromDate).subtract(const Duration(days: 1));
          final to = DateTime.parse(h.toDate).add(const Duration(days: 1));
          return date!.isAfter(from) && date.isBefore(to);
        } catch (_) {
          return false;
        }
      });
    } catch (_) {
      return null;
    }
  }
  dynamic getApprovedLeaveForDate(dynamic date, {dynamic employeeId}) => null;

  // Chat implementation
  List<CompanyEmployee> getSupervisorsFor(dynamic empId) {
    try {
      final emp = _employees.firstWhere((e) => e.id == empId);
      if (emp.structureId == null) return [];

      final struct = _structures.firstWhere((s) => s.id == emp.structureId);
      if (struct.supervisorId == null) return [];

      return _employees.where((e) => e.id == struct.supervisorId).toList();
    } catch (_) {
      return [];
    }
  }

  List<ChatMessage> getMessagesWith(dynamic otherId) {
    final cId = otherId.toString();
    ensureChatLoaded(cId);
    return _chatMessagesMap[cId] ?? [];
  }

  Future<void> markMessagesAsRead(dynamic otherId) async {
    final cId = otherId.toString().trim().toLowerCase();
    final myId = _employeeId.trim().toLowerCase();
    if (cId.isEmpty || myId.isEmpty) return;

    // Find the relevant message list
    String? matchedKey;
    List<ChatMessage>? messages = _chatMessagesMap[otherId.toString()];
    if (messages != null) {
      matchedKey = otherId.toString();
    } else {
      for (var entry in _chatMessagesMap.entries) {
        if (entry.key.trim().toLowerCase() == cId) {
          messages = entry.value;
          matchedKey = entry.key;
          break;
        }
      }
    }

    if (messages == null || matchedKey == null) return;

    final unreadMessages = messages
        .where((m) => m.receiverId.trim().toLowerCase() == myId && !m.isRead)
        .toList();
    if (unreadMessages.isEmpty) return;

    // Update in-memory first to avoid infinite callback loop
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].receiverId.trim().toLowerCase() == myId && !messages[i].isRead) {
        messages[i] = messages[i].copyWith(isRead: true);
      }
    }
    notifyListeners();

    if (_firebaseService.isAvailable) {
      for (var m in unreadMessages) {
        await _firebaseService.saveChatMessage(m.copyWith(isRead: true));
      }
    }
  }

  Future<void> markAllChatMessagesAsRead() async {
    final myId = _employeeId.trim().toLowerCase();
    if (myId.isEmpty) return;

    final List<ChatMessage> toUpdateInFirestore = [];
    for (var list in _chatMessagesMap.values) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].receiverId.trim().toLowerCase() == myId && !list[i].isRead) {
          final updated = list[i].copyWith(isRead: true);
          list[i] = updated;
          toUpdateInFirestore.add(updated);
        }
      }
    }

    if (toUpdateInFirestore.isNotEmpty) {
      notifyListeners();
      if (_firebaseService.isAvailable) {
        for (var m in toUpdateInFirestore) {
          await _firebaseService.saveChatMessage(m);
        }
      }
    }
  }

  Request? getRequestById(dynamic reqId, [dynamic b]) => null;

  Future<void> sendChatMessage(
    dynamic receiverId, [
    dynamic text,
    dynamic c,
  ]) async {
    final msgStr = text?.toString() ?? '';
    if (msgStr.isEmpty) return;

    final rId = receiverId.toString();
    final effectiveCompanyCode = (currentEmployee?.companyCode.isNotEmpty == true)
        ? currentEmployee!.companyCode
        : _currentCompanyCode;
    final effectiveSenderName = _userName.isNotEmpty ? _userName : 'Colleague';

    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _employeeId,
      receiverId: rId,
      text: msgStr,
      timestamp: DateTime.now(),
      companyCode: effectiveCompanyCode,
      senderName: effectiveSenderName,
    );

    if (_chatMessagesMap[rId] == null) {
      _chatMessagesMap[rId] = [];
    }
    if (!_chatMessagesMap[rId]!.any((m) => m.id == newMsg.id)) {
      _chatMessagesMap[rId]!.add(newMsg);
      notifyListeners();
    }

    if (_firebaseService.isAvailable) {
      await _firebaseService.saveChatMessage(newMsg);

      // Trigger push notification to receiver's device
      try {
        CompanyEmployee? receiverEmp;
        try {
          receiverEmp = _employees.firstWhere(
            (e) => e.id.trim().toLowerCase() == rId.trim().toLowerCase(),
          );
        } catch (_) {}

        if (receiverEmp != null && receiverEmp.fcmToken != null && receiverEmp.fcmToken!.isNotEmpty) {
          final senderName = _userName.isNotEmpty ? _userName : 'Colleague';
          FcmPushService.sendNotification(
            targetFcmToken: receiverEmp.fcmToken!,
            title: 'Message from $senderName',
            body: msgStr,
            data: {
              'type': 'chat_message',
              'senderId': _employeeId,
              'senderName': senderName,
              'receiverId': rId,
            },
          );
        }
      } catch (e) {
        debugPrint('Error triggering direct FCM push for chat: $e');
      }
    }
  }
}

class PayrollReport {
  final CompanyEmployee employee;
  final double basicSalary;
  final double salaryCalcByDay;
  final double workingHours;
  final int daysWorked;
  final double incrementalSalary;
  final double decrementalSalary;
  final double overtimeHours;
  final double overtimeValue;
  final double attendanceDeficitHours;
  final double attendanceDeficit;
  final double monthlyPenalties;
  final double foodAllowance;
  final double transportationAllowance;
  final double otherAllowance;
  final double monthlyAdditions;
  final double monthlyDeductions;
  final bool hasInsurance;
  final double insuranceSalary;
  final double insuranceEmployee;
  final double insuranceCompany;
  final List<PayrollAdjustment> adjustments;
  final double netEarnings;
  final String currency;

  PayrollReport({
    required this.employee,
    required this.basicSalary,
    this.salaryCalcByDay = 0.0,
    required this.workingHours,
    required this.daysWorked,
    required this.incrementalSalary,
    required this.decrementalSalary,
    this.overtimeHours = 0.0,
    required this.overtimeValue,
    this.attendanceDeficitHours = 0.0,
    required this.attendanceDeficit,
    required this.monthlyPenalties,
    required this.foodAllowance,
    required this.transportationAllowance,
    required this.otherAllowance,
    this.monthlyAdditions = 0.0,
    this.monthlyDeductions = 0.0,
    this.hasInsurance = false,
    this.insuranceSalary = 0.0,
    this.insuranceEmployee = 0.0,
    this.insuranceCompany = 0.0,
    this.adjustments = const [],
    required this.netEarnings,
    required this.currency,
  });
}

extension PayrollReportSnapshotExt on PayrollReportSnapshot {
  PayrollReport toPayrollReport(
    CompanyEmployee emp, [
    List<PayrollAdjustment> adjustments = const [],
  ]) {
    return PayrollReport(
      employee: emp,
      basicSalary: basicSalary,
      salaryCalcByDay: salaryCalcByDay,
      workingHours: workingHours,
      daysWorked: daysWorked,
      incrementalSalary: incrementalSalary,
      decrementalSalary: decrementalSalary,
      overtimeHours: overtimeHours,
      overtimeValue: overtimeValue,
      attendanceDeficitHours: attendanceDeficitHours,
      attendanceDeficit: attendanceDeficit,
      monthlyPenalties: monthlyPenalties,
      foodAllowance: foodAllowance,
      transportationAllowance: transportationAllowance,
      otherAllowance: otherAllowance,
      monthlyAdditions: monthlyAdditions,
      monthlyDeductions: monthlyDeductions,
      hasInsurance: hasInsurance,
      insuranceSalary: insuranceSalary,
      insuranceEmployee: insuranceEmployee,
      insuranceCompany: insuranceCompany,
      adjustments: adjustments,
      netEarnings: netEarnings,
      currency: currency,
    );
  }
}

extension PayrollReportExt on PayrollReport {
  PayrollReportSnapshot toSnapshot() {
    return PayrollReportSnapshot(
      employeeId: employee.id,
      employeeName: employee.name,
      position: employee.position,
      structureId: employee.structureId,
      basicSalary: basicSalary,
      salaryCalcByDay: salaryCalcByDay,
      workingHours: workingHours,
      daysWorked: daysWorked,
      incrementalSalary: incrementalSalary,
      decrementalSalary: decrementalSalary,
      overtimeHours: overtimeHours,
      overtimeValue: overtimeValue,
      attendanceDeficitHours: attendanceDeficitHours,
      attendanceDeficit: attendanceDeficit,
      monthlyPenalties: monthlyPenalties,
      foodAllowance: foodAllowance,
      transportationAllowance: transportationAllowance,
      otherAllowance: otherAllowance,
      monthlyAdditions: monthlyAdditions,
      monthlyDeductions: monthlyDeductions,
      hasInsurance: hasInsurance,
      insuranceSalary: insuranceSalary,
      insuranceEmployee: insuranceEmployee,
      insuranceCompany: insuranceCompany,
      netEarnings: netEarnings,
      currency: currency,
    );
  }
}
