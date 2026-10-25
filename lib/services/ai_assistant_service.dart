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
  
  static String? _cachedModel;
  static String? _cachedApiVersion;

  static void resetModelCache() {
    _cachedModel = null;
    _cachedApiVersion = null;
  }

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
    resetModelCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key.trim());
  }

  /// Dynamically queries Google Gemini ModelService.ListModels to detect candidate models
  /// supported by the user's specific API key, ordered by stability and speed.
  static Future<List<Map<String, String>>> resolveCandidateModels(String apiKey) async {
    final candidates = <Map<String, String>>[];

    if (_cachedModel != null && _cachedApiVersion != null) {
      candidates.add({'model': _cachedModel!, 'version': _cachedApiVersion!});
    }

    // Standard high-reliability models that Google AI Studio provides for all free keys
    const stablePreferences = [
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-flash-latest',
      'gemini-2.0-flash-exp',
      'gemini-1.5-flash-001',
      'gemini-1.5-flash-002',
      'gemini-1.5-flash-8b',
      'gemini-1.5-pro',
      'gemini-1.5-pro-latest',
      'gemini-pro',
    ];

    // 1. Query v1beta ListModels
    try {
      final listUrl = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final resp = await http.get(listUrl).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final models = (data['models'] as List?) ?? [];
        final supported = <String>[];

        for (final m in models) {
          final methods = (m['supportedGenerationMethods'] as List?) ?? [];
          if (methods.contains('generateContent')) {
            final name = m['name']?.toString() ?? '';
            final cleanName = name.replaceFirst('models/', '');
            supported.add(cleanName);
          }
        }

        // Add stable preferences first if present in the user's supported models
        for (final pref in stablePreferences) {
          if (supported.contains(pref)) {
            if (!candidates.any((c) => c['model'] == pref && c['version'] == 'v1beta')) {
              candidates.add({'model': pref, 'version': 'v1beta'});
            }
          }
        }

        // Then add any other discovered models (e.g. gemini-2.5-flash, etc.)
        for (final s in supported) {
          if (!candidates.any((c) => c['model'] == s)) {
            candidates.add({'model': s, 'version': 'v1beta'});
          }
        }
      } else {
        final errorJson = jsonDecode(utf8.decode(resp.bodyBytes));
        final msg = errorJson['error']?['message']?.toString() ?? '';

        if (resp.statusCode == 400 && msg.contains('API key not valid')) {
          throw Exception(
            'The provided Gemini API key is invalid. Please get a free API key directly from Google AI Studio (https://aistudio.google.com/app/apikey).',
          );
        } else if (msg.contains('has not been used in project') || msg.contains('is disabled')) {
          throw Exception(
            'Generative Language API is not enabled for this project. Please generate a free key from Google AI Studio (https://aistudio.google.com/app/apikey) or enable the Generative Language API in Google Cloud Console.',
          );
        }
      }
    } catch (e) {
      if (e is Exception &&
          (e.toString().contains('Google AI Studio') || e.toString().contains('Generative Language API'))) {
        rethrow;
      }
      debugPrint('v1beta ListModels note: $e');
    }

    // 2. Query v1 ListModels as backup
    try {
      final listUrlV1 = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models?key=$apiKey',
      );
      final resp = await http.get(listUrlV1).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final models = (data['models'] as List?) ?? [];
        for (final m in models) {
          final methods = (m['supportedGenerationMethods'] as List?) ?? [];
          if (methods.contains('generateContent')) {
            final name = m['name']?.toString() ?? '';
            final cleanName = name.replaceFirst('models/', '');
            if (!candidates.any((c) => c['model'] == cleanName && c['version'] == 'v1')) {
              candidates.add({'model': cleanName, 'version': 'v1'});
            }
          }
        }
      }
    } catch (e) {
      debugPrint('v1 ListModels note: $e');
    }

    // 3. Fallback candidates (in case ListModels fails or is blocked by CORS on web)
    const fallbackList = [
      {'model': 'gemini-2.0-flash', 'version': 'v1beta'},
      {'model': 'gemini-1.5-flash', 'version': 'v1beta'},
      {'model': 'gemini-1.5-flash-latest', 'version': 'v1beta'},
      {'model': 'gemini-2.0-flash', 'version': 'v1'},
      {'model': 'gemini-1.5-flash', 'version': 'v1'},
      {'model': 'gemini-pro', 'version': 'v1beta'},
    ];

    for (final fb in fallbackList) {
      if (!candidates.any((c) => c['model'] == fb['model'] && c['version'] == fb['version'])) {
        candidates.add(fb);
      }
    }

    return candidates;
  }

  /// Convenience method to resolve the top candidate model.
  static Future<Map<String, String>> resolveWorkingModel(String apiKey) async {
    final list = await resolveCandidateModels(apiKey);
    return list.first;
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

  /// Sends a conversational prompt to Gemini with dynamic model discovery,
  /// full company context, and chat history.
  static Future<String> sendMessage({
    required String prompt,
    required List<AiMessage> history,
    required String companyContext,
    required String apiKey,
    String language = 'en',
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw Exception('Missing Gemini API key.');
    }

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

    final candidates = await resolveCandidateModels(cleanKey);

    Exception? lastException;
    for (final candidate in candidates) {
      final modelName = candidate['model']!;
      final apiVersion = candidate['version']!;

      try {
        final reply = await _executeGenerateContent(
          prompt: prompt,
          history: history,
          systemInstruction: systemInstruction,
          apiKey: cleanKey,
          modelName: modelName,
          apiVersion: apiVersion,
        );

        // Cache the verified working model for rapid future calls
        _cachedModel = modelName;
        _cachedApiVersion = apiVersion;
        debugPrint('Gemini response generated successfully using $modelName ($apiVersion)');
        return reply;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        final errText = e.toString().toLowerCase();

        // If this model is not found, not supported, or 404, smoothly try next candidate
        if (errText.contains('not found') || errText.contains('404') || errText.contains('not supported')) {
          resetModelCache();
          debugPrint('Model $modelName ($apiVersion) returned 404/not found. Trying next candidate...');
          continue;
        }

        // If key is invalid or quota is exceeded, fail immediately
        rethrow;
      }
    }

    throw lastException ??
        Exception(
          'Failed to connect to any Gemini model with this key. Please verify that your API key is created from Google AI Studio (https://aistudio.google.com/app/apikey).',
        );
  }

  static Future<String> _executeGenerateContent({
    required String prompt,
    required List<AiMessage> history,
    required String systemInstruction,
    required String apiKey,
    required String modelName,
    required String apiVersion,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/$apiVersion/models/$modelName:generateContent?key=$apiKey',
    );

    final List<Map<String, dynamic>> contents = [];

    if (apiVersion == 'v1') {
      // v1 does not support top-level system_instruction, prepend to context
      contents.add({
        'role': 'user',
        'parts': [
          {'text': '$systemInstruction\n\nUser Question: $prompt'}
        ],
      });
    } else {
      // v1beta supports conversational history and system_instruction natively
      final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;
      for (final msg in recentHistory) {
        contents.add(msg.toGeminiPart());
      }
      contents.add({
        'role': 'user',
        'parts': [
          {'text': prompt}
        ],
      });
    }

    final Map<String, dynamic> bodyMap = {
      'contents': contents,
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
        'topP': 0.95,
      },
    };

    if (apiVersion == 'v1beta') {
      bodyMap['system_instruction'] = {
        'parts': [
          {'text': systemInstruction}
        ]
      };
    }

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(bodyMap),
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
        final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMessage = errorJson['error']?['message']?.toString() ?? 'Status ${response.statusCode}';
        debugPrint('Gemini API Error ($modelName / $apiVersion): $errorMessage');

        // If the model was not found or not supported on this endpoint
        if (response.statusCode == 404 || errorMessage.contains('is not found') || errorMessage.contains('not supported')) {
          resetModelCache();
          throw Exception(
            'The model "$modelName" was not found or is not supported for API version $apiVersion: $errorMessage',
          );
        } else if (response.statusCode == 400 && errorMessage.contains('API key not valid')) {
          throw Exception(
            'The provided Gemini API Key is invalid. Please get a free key from Google AI Studio (https://aistudio.google.com/app/apikey).',
          );
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
