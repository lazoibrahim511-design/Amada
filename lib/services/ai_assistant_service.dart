import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';

class AiMessage {
  final String role; // 'user' or 'model'
  final String text;
  final DateTime timestamp;

  AiMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toGeminiPart() {
    return {
      'role': role == 'model' ? 'model' : 'user',
      'parts': [
        {'text': text}
      ],
    };
  }
}

class AiAssistantService {
  static const String _prefApiKey = 'gemini_api_key';
  static const String _defaultModel = 'gemini-1.5-flash';

  /// Retrieves the API key from SharedPreferences, falling back to CompanyProfile key if available.
  static Future<String?> getApiKey({String? profileKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localKey = prefs.getString(_prefApiKey);
      if (localKey != null && localKey.trim().isNotEmpty) {
        return localKey.trim();
      }
    } catch (e) {
      debugPrint('Error reading AI API key from prefs: $e');
    }

    if (profileKey != null && profileKey.trim().isNotEmpty) {
      return profileKey.trim();
    }
    return null;
  }

  /// Saves the Gemini API key locally.
  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key.trim());
  }

  /// Builds a rich, sanitized snapshot of the company data from AttendanceProvider.
  static String buildCompanyContext(
    AttendanceProvider provider, {
    String? targetStructureId,
    String? targetEmployeeId,
  }) {
    final buffer = StringBuffer();
    final profile = provider.companyProfile;
    final companyName = profile?.name.isNotEmpty == true ? profile!.name : provider.currentCompanyCode;
    final month = provider.selectedMonth;
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    buffer.writeln('=== COMPANY PROFILE & ORGANIZATIONAL METRICS ===');
    buffer.writeln('Company: $companyName (Code: ${provider.currentCompanyCode})');
    buffer.writeln('Active Month Under Review: $monthStr');
    buffer.writeln('Total Employees: ${provider.employees.length}');
    buffer.writeln('Total Structures/Departments: ${provider.structures.length}');
    buffer.writeln('Total Shifts: ${provider.shifts.length}');
    buffer.writeln('Total Employee Groups: ${provider.groups.length}');
    buffer.writeln();

    // 1. Structures / Departments
    buffer.writeln('=== STRUCTURES & DEPARTMENTS ===');
    for (final s in provider.structures) {
      final empsInStruct = provider.employees.where((e) => e.structureId == s.id).toList();
      buffer.writeln('• Department ID: ${s.id} | Name: "${s.name}" | Location: "${s.location}" | Capacity: ${s.capacity}');
      buffer.writeln('  Staff Count: ${empsInStruct.length}');
      if (empsInStruct.isNotEmpty) {
        final names = empsInStruct.map((e) => '${e.name} (${e.position.isNotEmpty ? e.position : e.role})').take(12).join(', ');
        buffer.writeln('  Staff Members: $names${empsInStruct.length > 12 ? ' and more...' : ''}');
      }
    }
    buffer.writeln();

    // 2. Shifts & Schedules
    buffer.writeln('=== WORK SHIFTS & SCHEDULES ===');
    for (final sh in provider.shifts) {
      buffer.writeln('• Shift ID: ${sh.id} | Name: "${sh.name}" | Time: ${sh.startTime} to ${sh.endTime} | Break: ${sh.breakDurationMinutes}m | Forgiveness: ${sh.forgivenessOfDelay}m');
    }
    buffer.writeln();

    // 3. Employee Groups
    buffer.writeln('=== EMPLOYEE GROUPS ===');
    for (final g in provider.groups) {
      final shift = provider.shifts.where((s) => s.id == g.shiftId).firstOrNull;
      final empsInGroup = provider.employees.where((e) => e.groupId == g.id).toList();
      buffer.writeln('• Group ID: ${g.id} | Name: "${g.name}" | Assigned Shift: "${shift?.name ?? 'Standard'}" | Member Count: ${empsInGroup.length}');
    }
    buffer.writeln();

    // 4. Employees & Attendance/Payroll Intelligence
    buffer.writeln('=== EMPLOYEE DOSSIER, ATTENDANCE & PAYROLL DATA ($monthStr) ===');

    List<CompanyEmployee> relevantEmployees = provider.employees;
    if (targetEmployeeId != null && targetEmployeeId.isNotEmpty) {
      relevantEmployees = provider.employees.where((e) => e.id == targetEmployeeId).toList();
      if (relevantEmployees.isEmpty) relevantEmployees = provider.employees;
    } else if (targetStructureId != null && targetStructureId.isNotEmpty) {
      relevantEmployees = provider.employees.where((e) => e.structureId == targetStructureId).toList();
      if (relevantEmployees.isEmpty) relevantEmployees = provider.employees;
    }

    // Pre-calculate payroll reports for high fidelity
    for (final emp in relevantEmployees) {
      final struct = provider.structures.where((s) => s.id == emp.structureId).firstOrNull;
      final group = provider.groups.where((g) => g.id == emp.groupId).firstOrNull;
      final shift = group != null ? provider.shifts.where((s) => s.id == group.shiftId).firstOrNull : null;
      final report = provider.generatePayrollReport(emp, month);

      buffer.writeln('• Employee: "${emp.name}" (ID: ${emp.id})');
      buffer.writeln('  Position: "${emp.position.isNotEmpty ? emp.position : '-'}" | Role: ${emp.role} | Phone: ${emp.phoneNumber.isNotEmpty ? emp.phoneNumber : '-'}');
      buffer.writeln('  Department: "${struct?.name ?? '-'}" | Group: "${group?.name ?? '-'}" | Shift: "${shift?.name ?? '-'}"');
      buffer.writeln('  Attendance Stats: Days Worked: ${report.daysWorked} | Working Hours: ${report.workingHours.toStringAsFixed(1)}h');
      buffer.writeln('  Overtime Hours: ${report.overtimeHours.toStringAsFixed(1)}h (Val: ${report.overtimeValue.toStringAsFixed(0)} ${report.currency})');
      buffer.writeln('  Attendance Deficit: ${report.attendanceDeficitHours.toStringAsFixed(1)}h (Deduct: ${report.attendanceDeficit.toStringAsFixed(0)} ${report.currency})');
      buffer.writeln('  Unpaid Leave Taken: ${report.unpaidLeaveHours.toStringAsFixed(1)}h (Deduct: ${report.unpaidLeaveDeduction.toStringAsFixed(0)} ${report.currency})');
      buffer.writeln('  Penalties: ${report.monthlyPenalties.toStringAsFixed(0)} ${report.currency} | Other Deductions: ${report.monthlyDeductions.toStringAsFixed(0)} ${report.currency}');
      buffer.writeln('  Additions/Bonuses: ${report.monthlyAdditions.toStringAsFixed(0)} ${report.currency}');
      buffer.writeln('  Financials: Basic Salary: ${report.basicSalary.toStringAsFixed(0)} ${report.currency} | Net Earnings: ${report.netEarnings.toStringAsFixed(0)} ${report.currency}');
      buffer.writeln('---');
    }

    // 5. Recent Leaves / Requests for Context
    final allRequests = provider.allRequests;
    if (allRequests.isNotEmpty) {
      buffer.writeln('=== RECENT LEAVE & WORK REQUESTS ===');
      for (final req in allRequests.take(20)) {
        final empName = provider.employees.where((e) => e.id == req.employeeId).firstOrNull?.name ?? req.employeeId;
        buffer.writeln('• [${req.status.toUpperCase()}] ${req.type} for $empName on ${req.date} (Dur: ${req.duration})');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Sends a conversational prompt to Gemini 1.5 Flash with the full company context and chat history.
  static Future<String> sendMessage({
    required String prompt,
    required List<AiMessage> history,
    required String companyContext,
    required String apiKey,
    String language = 'en',
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Missing Gemini API key.');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_defaultModel:generateContent?key=$apiKey',
    );

    final systemInstruction = '''
You are the Executive HR Intelligence Advisor and Chief People Analytics Officer for this company.
You have direct, comprehensive access to verified real-time data regarding company structures, shifts, groups, employee attendance records, leaves, and payroll metrics provided below.

=== LIVE COMPANY DATA CONTEXT ===
$companyContext
=================================

CRITICAL RULES:
1. Always respond in the EXACT language used by the user (English, Arabic, or Kurdish). If the user writes in Kurdish, respond in fluent Sorani Kurdish. If in Arabic, respond in professional Arabic.
2. Rely strictly on the real numbers, employees, departments, and shift data provided in the context above.
3. When answering about a specific employee, cite their exact department, days worked, overtime, deficit, leaves, and payroll deductions.
4. When answering about structures/departments, compare staff counts, punctuality, and overall health.
5. If the user asks for advice (e.g. dealing with repeated absence, cost optimization, shift adjustments), provide balanced, professional, constructive HR recommendations.
6. Format your responses with clean, modern markdown:
   - Use bold titles and key numbers.
   - Use concise bullet points.
   - Use markdown tables for side-by-side comparisons.
7. Be concise, polite, analytical, and executive-ready.
''';

    final List<Map<String, dynamic>> contents = [];

    // Add recent history for conversational flow (up to last 10 turns)
    final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;
    for (final msg in recentHistory) {
      contents.add(msg.toGeminiPart());
    }

    // Add the current user prompt
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
        'topP': 0.95,
      },
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final candidates = decoded['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text']?.toString().trim();
            if (text != null && text.isNotEmpty) {
              return text;
            }
          }
        }
        return 'No response generated by the AI.';
      } else {
        final errorJson = jsonDecode(response.body);
        final errorMessage = errorJson['error']?['message'] ?? 'Status ${response.statusCode}';
        debugPrint('Gemini API Error: $errorMessage');
        if (response.statusCode == 400 && errorMessage.contains('API key not valid')) {
          throw Exception('The provided Gemini API Key is invalid. Please verify your key.');
        } else if (response.statusCode == 429) {
          throw Exception('Gemini API quota exceeded or rate limited. Please try again shortly.');
        }
        throw Exception('AI request failed: $errorMessage');
      }
    } catch (e) {
      debugPrint('Exception in AiAssistantService: $e');
      rethrow;
    }
  }
}
