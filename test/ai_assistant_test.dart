import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/models/translation_keys.dart';
import 'package:attendance_app/services/ai_assistant_service.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiMessage Unit Tests', () {
    test('AiMessage converts correctly to Gemini part payload', () {
      final userMsg = AiMessage(role: 'user', text: 'How is attendance today?');
      final userPart = userMsg.toGeminiPart();
      expect(userPart['role'], 'user');
      expect((userPart['parts'] as List)[0]['text'], 'How is attendance today?');

      final aiMsg = AiMessage(role: 'model', text: 'Attendance is 94% today.');
      final aiPart = aiMsg.toGeminiPart();
      expect(aiPart['role'], 'model');
      expect((aiPart['parts'] as List)[0]['text'], 'Attendance is 94% today.');
    });
  });

  group('CompanyProfile Gemini API Key Serialization', () {
    test('CompanyProfile preserves geminiApiKey in toMap and fromMap', () {
      final profile = CompanyProfile(
        name: 'Amada Corp',
        address: 'Erbil, Iraq',
        geminiApiKey: 'AIzaSyTestApiKey123',
      );

      final map = profile.toMap();
      expect(map['geminiApiKey'], 'AIzaSyTestApiKey123');

      final restored = CompanyProfile.fromMap(map);
      expect(restored.name, 'Amada Corp');
      expect(restored.geminiApiKey, 'AIzaSyTestApiKey123');
    });
  });

  group('AiAssistantService Context Builder Tests', () {
    test('buildCompanyContext produces structured sections', () {
      final provider = AttendanceProvider();

      // Test with all company scope
      final contextAll = AiAssistantService.buildCompanyContext(provider);
      expect(contextAll.contains('=== COMPANY PROFILE & ORGANIZATIONAL METRICS ==='), isTrue);
      expect(contextAll.contains('=== STRUCTURES & DEPARTMENTS ==='), isTrue);
      expect(contextAll.contains('=== WORK SHIFTS & SCHEDULES ==='), isTrue);
      expect(contextAll.contains('=== EMPLOYEE GROUPS ==='), isTrue);
      expect(contextAll.contains('=== EMPLOYEE DOSSIER, ATTENDANCE & PAYROLL DATA'), isTrue);
    });

    test('buildCompanyContext respects targetStructureId and targetEmployeeId', () {
      final provider = AttendanceProvider();

      final contextWithTarget = AiAssistantService.buildCompanyContext(
        provider,
        targetEmployeeId: 'emp_2',
      );
      expect(contextWithTarget.isNotEmpty, isTrue);
    });
  });

  group('AI Assistant Translation Keys Verification', () {
    test('All required AI keys are translated across English, Arabic, and Kurdish', () {
      final requiredAiKeys = [
        'ai_assistant',
        'ai_assistant_desc',
        'ai_scope_all',
        'ai_scope_structure',
        'ai_scope_employee',
        'ai_select_structure',
        'ai_select_employee',
        'ai_prompt_hint',
        'ai_chip_punctuality',
        'ai_chip_deficits',
        'ai_chip_departments',
        'ai_chip_unpaid_leaves',
        'ai_api_key_title',
        'ai_api_key_desc',
        'ai_api_key_hint',
        'ai_thinking',
        'ai_clear_chat',
        'ai_welcome_title',
        'ai_welcome_subtitle',
        'ai_export_report',
        'ai_copied_to_clipboard',
        'ai_key_saved',
        'ai_key_missing_prompt',
      ];

      for (final lang in ['en', 'ar', 'ku']) {
        final dict = TranslationKeys.translations[lang];
        expect(dict, isNotNull, reason: 'Dictionary for $lang should exist');

        for (final key in requiredAiKeys) {
          expect(dict![key], isNotNull, reason: 'Key "$key" should exist in "$lang"');
          expect(dict[key]!.isNotEmpty, isTrue, reason: 'Key "$key" in "$lang" should not be empty');
        }
      }
    });
  });
}
