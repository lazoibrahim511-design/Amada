import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';
import '../services/ai_assistant_service.dart';

class AiAssistantScreen extends StatefulWidget {
  final bool isEmbedded;
  const AiAssistantScreen({super.key, this.isEmbedded = false});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiMessage> _messages = [];
  bool _isLoading = false;
  String? _apiKey;

  // Selected Scope
  String _selectedScope = 'all'; // 'all', 'structure', 'employee'
  String? _selectedStructureId;
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final userId = provider.currentEmployee?.id ?? provider.currentEmployee?.email;
    final key = await AiAssistantService.getApiKey(
      profileKey: provider.companyProfile?.geminiApiKey,
      userId: userId,
    );
    if (mounted) {
      setState(() => _apiKey = key);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _promptController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (_apiKey == null || _apiKey!.trim().isEmpty) {
      _showApiKeyDialog(requiredPrompt: true);
      return;
    }

    _promptController.clear();
    setState(() {
      _messages.add(AiMessage(role: 'user', text: text));
      _isLoading = true;
    });
    _scrollToBottom();

    final provider = Provider.of<AttendanceProvider>(context, listen: false);

    try {
      final contextData = AiAssistantService.buildCompanyContext(
        provider,
        targetStructureId: _selectedScope == 'structure' ? _selectedStructureId : null,
        targetEmployeeId: _selectedScope == 'employee' ? _selectedEmployeeId : null,
      );

      final reply = await AiAssistantService.sendMessage(
        prompt: text,
        history: _messages,
        companyContext: contextData,
        apiKey: _apiKey!,
        language: provider.currentLanguage,
      );

      if (mounted) {
        setState(() {
          _messages.add(AiMessage(role: 'model', text: reply));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF4B4B),
            content: Text(errMsg),
            action: SnackBarAction(
              label: 'Configure Key',
              textColor: Colors.white,
              onPressed: () => _showApiKeyDialog(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _showApiKeyDialog({bool requiredPrompt = false}) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final keyController = TextEditingController(text: _apiKey ?? '');
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.key_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    provider.translate('ai_api_key_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.translate('ai_api_key_desc'),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keyController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: provider.translate('ai_api_key_hint'),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Get a free Gemini API key from Google AI Studio (aistudio.google.com/app/apikey). Do NOT use Firebase Web API keys.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(provider.translate('cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final newKey = keyController.text.trim();
                  if (newKey.isNotEmpty) {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(ctx);
                    final userId = provider.currentEmployee?.id ?? provider.currentEmployee?.email;
                    // Save locally and tied to the user who added it
                    await AiAssistantService.saveApiKey(newKey, userId: userId);
                    // Also sync with CompanyProfile in Firestore so it persists across sessions
                    try {
                      CompanyProfile updatedProfile;
                      if (provider.companyProfile != null) {
                        updatedProfile = provider.companyProfile!.copyWith(geminiApiKey: newKey);
                      } else {
                        updatedProfile = CompanyProfile(
                          name: 'Company',
                          address: '',
                          geminiApiKey: newKey,
                        );
                      }
                      await provider.firebaseService.saveCompanyProfile(updatedProfile);
                    } catch (_) {}
                    if (!mounted) return;
                    setState(() => _apiKey = newKey);
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text(provider.translate('ai_key_saved')),
                      ),
                    );
                  }
                },
                child: Text(provider.translate('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textDir = provider.currentLanguageDirection;

    return Directionality(
      textDirection: textDir,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: widget.isEmbedded ? null : _buildAppBar(context, provider, isDark),
        body: Column(
          children: [
            if (widget.isEmbedded) _buildEmbeddedHeader(context, provider, isDark),
            _buildScopeSelector(context, provider, isDark),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(context, provider, isDark)
                  : _buildMessageList(context, provider, isDark),
            ),
            if (_isLoading) _buildLoadingIndicator(context, provider, isDark),
            _buildQuickPromptChips(context, provider, isDark),
            _buildInputArea(context, provider, isDark),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.translate('ai_assistant'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${DateFormat('MMMM yyyy').format(provider.selectedMonth)} Analytics',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: provider.translate('ai_api_key_title'),
          icon: Icon(
            _apiKey == null || _apiKey!.isEmpty ? Icons.key_off_rounded : Icons.key_rounded,
            color: _apiKey == null || _apiKey!.isEmpty ? const Color(0xFFFF5C5C) : const Color(0xFF10B981),
          ),
          onPressed: () => _showApiKeyDialog(),
        ),
        if (_messages.isNotEmpty)
          IconButton(
            tooltip: provider.translate('ai_clear_chat'),
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () {
              setState(() => _messages.clear());
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.85) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.translate('ai_assistant'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  provider.translate('ai_assistant_desc'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: provider.translate('ai_api_key_title'),
            icon: Icon(
              _apiKey == null || _apiKey!.isEmpty ? Icons.key_off_rounded : Icons.key_rounded,
              color: _apiKey == null || _apiKey!.isEmpty ? const Color(0xFFFF5C5C) : const Color(0xFF10B981),
            ),
            onPressed: () => _showApiKeyDialog(),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: provider.translate('ai_clear_chat'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () {
                setState(() => _messages.clear());
              },
            ),
        ],
      ),
    );
  }

  Widget _buildScopeSelector(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final structures = provider.structures;
    final employees = provider.employees;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Scope Chips
            _buildScopePill(
              title: provider.translate('ai_scope_all'),
              isSelected: _selectedScope == 'all',
              icon: Icons.domain_rounded,
              onTap: () {
                setState(() {
                  _selectedScope = 'all';
                  _selectedStructureId = null;
                  _selectedEmployeeId = null;
                });
              },
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildScopePill(
              title: provider.translate('ai_scope_structure'),
              isSelected: _selectedScope == 'structure',
              icon: Icons.account_tree_outlined,
              onTap: () {
                setState(() {
                  _selectedScope = 'structure';
                  if (structures.isNotEmpty && _selectedStructureId == null) {
                    _selectedStructureId = structures.first.id;
                  }
                  _selectedEmployeeId = null;
                });
              },
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildScopePill(
              title: provider.translate('ai_scope_employee'),
              isSelected: _selectedScope == 'employee',
              icon: Icons.person_outline_rounded,
              onTap: () {
                setState(() {
                  _selectedScope = 'employee';
                  if (employees.isNotEmpty && _selectedEmployeeId == null) {
                    _selectedEmployeeId = employees.first.id;
                  }
                  _selectedStructureId = null;
                });
              },
              isDark: isDark,
            ),

            if (_selectedScope == 'structure' && structures.isNotEmpty) ...[
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStructureId ?? structures.first.id,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: structures
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStructureId = val);
                    },
                  ),
                ),
              ),
            ],

            if (_selectedScope == 'employee' && employees.isNotEmpty) ...[
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEmployeeId ?? employees.first.id,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: employees
                        .map((e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.name),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedEmployeeId = val);
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScopePill({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 38,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              provider.translate('ai_welcome_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                provider.translate('ai_welcome_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Starter Question Cards
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  _buildStarterCard(
                    title: provider.translate('ai_chip_punctuality'),
                    subtitle: provider.currentLanguage == 'ku'
                        ? 'هەڵسەنگاندنی ئاستی پابەندبوون بە کات و دۆزینەوەی شێوازی دواکەوتن بەپێی دەوامەکان.'
                        : (provider.currentLanguage == 'ar'
                            ? 'تقييم الالتزام بالمواعيد واكتشاف أنماط التأخير عبر الورديات.'
                            : 'Evaluate top punctuality and identify recurring delay patterns across shifts.'),
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () {
                      if (provider.currentLanguage == 'ku') {
                        _sendMessage('شیکاری پابەندبوونی کات و ڕێژەی دواکەوتنی کارمەندان بکە بۆ ئەم مانگە.');
                      } else if (provider.currentLanguage == 'ar') {
                        _sendMessage('قدم تحليلاً مفصلاً لالتزام الموظفين بالمواعيد ونسب التأخير لهذا الشهر.');
                      } else {
                        _sendMessage('Give me a detailed attendance punctuality analysis for this month. Highlight top performers and employees with recurring delay patterns.');
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildStarterCard(
                    title: provider.translate('ai_chip_deficits'),
                    subtitle: provider.currentLanguage == 'ku'
                        ? 'دەستنیشانکردنی زۆرترین کەمی کاتژمێری ئامادەبوون، سزاکان، و هۆکارە بنەڕەتییەکان.'
                        : (provider.currentLanguage == 'ar'
                            ? 'تحديد أعلى نسب عجز الحضور والجزاءات والأسباب الكامنة.'
                            : 'Identify highest attendance deficits, penalties, and underlying causes.'),
                    icon: Icons.trending_down_rounded,
                    color: const Color(0xFFFF5C5C),
                    onTap: () {
                      if (provider.currentLanguage == 'ku') {
                        _sendMessage('کێ زۆرترین کەمی کاتژمێری ئامادەبوونی هەیە لەم مانگەدا و هۆکارە سەرەکییەکان چین؟');
                      } else if (provider.currentLanguage == 'ar') {
                        _sendMessage('من هم الموظفون الأكثر عجزاً في ساعات الحضور أو الأكثر تعرضاً للخصومات هذا الشهر؟');
                      } else {
                        _sendMessage('Which employees have the highest attendance deficit hours or penalties this month? Break down the exact reasons and deductions.');
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildStarterCard(
                    title: provider.translate('ai_chip_departments'),
                    subtitle: provider.currentLanguage == 'ku'
                        ? 'پشکنینی دابەشبوونی کارمەندان، دەوامی کار، و ڕێژەی ئامادەبوون بەپێی بەشەکان.'
                        : (provider.currentLanguage == 'ar'
                            ? 'فحص توزيع الكادر وورديات العمل ونسب الحضور لكل قسم.'
                            : 'Examine staffing balance, working shifts, and attendance rates per structure.'),
                    icon: Icons.account_tree_rounded,
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      if (provider.currentLanguage == 'ku') {
                        _sendMessage('شیکاری ئامادەبوون و ژمارەی کارمەندان بەپێی بەش و پێکهاتەکانی کۆمپانیا ڕوون بکەرەوە.');
                      } else if (provider.currentLanguage == 'ar') {
                        _sendMessage('قدم تقريراً شاملاً عن توزيع الموظفين ونسب الحضور في كل قسم وهيكل إداري.');
                      } else {
                        _sendMessage('Give me an executive breakdown of all company structures and departments. How are employees distributed and which department is most active?');
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildStarterCard(
                    title: provider.translate('ai_chip_unpaid_leaves'),
                    subtitle: provider.currentLanguage == 'ku'
                        ? 'وردبینیکردنی داواکاری مۆڵەتی بێ مووچەی کاتژمێری و ڕۆژانە و لێبڕینەکانی مووچە.'
                        : (provider.currentLanguage == 'ar'
                            ? 'تدقيق طلبات الإجازات غير مدفوعة الأجر (الساعية واليومية) وخصوماتها.'
                            : 'Audit hourly and daily unpaid leave requests and their payroll deductions.'),
                    icon: Icons.event_busy_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      if (provider.currentLanguage == 'ku') {
                        _sendMessage('کورتەیەک لەسەر کاتژمێرەکانی مۆڵەتی بێ مووچە و بڕی لێبڕینەکانی ئەم مانگە بدە.');
                      } else if (provider.currentLanguage == 'ar') {
                        _sendMessage('لخص إجازات بدون راتب (اليومية والساعية) والمبالغ المخصومة لهذا الشهر.');
                      } else {
                        _sendMessage('Review all unpaid leave records (both daily and hourly) for this month. Summarize total hours and the deducted amounts.');
                      }
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarterCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      physics: const BouncingScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg.role == 'user';
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 720),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF6366F1)
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isUser)
                        Text(
                          msg.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            height: 1.45,
                          ),
                        )
                      else
                        _FormattedAiText(
                          rawText: msg.text,
                          isDark: isDark,
                        ),
                      if (!isUser) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: msg.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(provider.translate('ai_copied_to_clipboard')),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 13,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      provider.translate('ai_export_report'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 12),
          Text(
            provider.translate('ai_thinking'),
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptChips(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final chips = [
      provider.translate('ai_chip_punctuality'),
      provider.translate('ai_chip_deficits'),
      provider.translate('ai_chip_departments'),
      provider.translate('ai_chip_unpaid_leaves'),
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = chips[index];
          return ActionChip(
            label: Text(label),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () {
              if (index == 0) {
                if (provider.currentLanguage == 'ku') {
                  _sendMessage('شیکاری پابەندبوونی کات و ڕێژەی دواکەوتنی کارمەندان بکە بۆ ئەم مانگە.');
                } else if (provider.currentLanguage == 'ar') {
                  _sendMessage('قدم تحليلاً مفصلاً لالتزام الموظفين بالمواعيد ونسب التأخير لهذا الشهر.');
                } else {
                  _sendMessage('Analyze employee punctuality and tardiness trends for this month.');
                }
              } else if (index == 1) {
                if (provider.currentLanguage == 'ku') {
                  _sendMessage('کێ زۆرترین کەمی کاتژمێری ئامادەبوونی هەیە لەم مانگەدا و هۆکارە سەرەکییەکان چین؟');
                } else if (provider.currentLanguage == 'ar') {
                  _sendMessage('من هم الموظفون الأكثر عجزاً في ساعات الحضور أو الأكثر تعرضاً للخصومات هذا الشهر؟');
                } else {
                  _sendMessage('Who has the largest attendance deficit this month and what are the main reasons?');
                }
              } else if (index == 2) {
                if (provider.currentLanguage == 'ku') {
                  _sendMessage('شیکاری ئامادەبوون و ژمارەی کارمەندان بەپێی بەش و پێکهاتەکانی کۆمپانیا ڕوون بکەرەوە.');
                } else if (provider.currentLanguage == 'ar') {
                  _sendMessage('قدم تقريراً شاملاً عن توزيع الموظفين ونسب الحضور في كل قسم وهيكل إداري.');
                } else {
                  _sendMessage('Break down the attendance and staffing performance across each company structure/department.');
                }
              } else if (index == 3) {
                if (provider.currentLanguage == 'ku') {
                  _sendMessage('کورتەیەک لەسەر کاتژمێرەکانی مۆڵەتی بێ مووچە و بڕی لێبڕینەکانی ئەم مانگە بدە.');
                } else if (provider.currentLanguage == 'ar') {
                  _sendMessage('لخص إجازات بدون راتب (اليومية والساعية) والمبالغ المخصومة لهذا الشهر.');
                } else {
                  _sendMessage('Give me an overview of all unpaid leave deductions and taken hours this month.');
                }
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildInputArea(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: provider.translate('ai_prompt_hint'),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                onPressed: _isLoading ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lightweight, robust formatted markdown/text renderer for AI responses.
class _FormattedAiText extends StatelessWidget {
  final String rawText;
  final bool isDark;

  const _FormattedAiText({
    required this.rawText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final lines = rawText.split('\n');
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Headers (e.g. ### Header or ## Header)
      if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            line.substring(4),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6366F1),
            ),
          ),
        ));
      } else if (line.startsWith('## ') || line.startsWith('# ')) {
        final title = line.startsWith('## ') ? line.substring(3) : line.substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ));
      } else if (line.startsWith('• ') || line.startsWith('- ') || line.startsWith('* ')) {
        // Bullet list item
        final bulletText = line.substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ',
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Expanded(
                child: _buildRichInline(bulletText, textColor),
              ),
            ],
          ),
        ));
      } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        // Numbered list item
        final match = RegExp(r'^(\d+\.)\s(.*)').firstMatch(line);
        final numPrefix = match?.group(1) ?? '•';
        final restText = match?.group(2) ?? line;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$numPrefix ',
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: _buildRichInline(restText, textColor),
              ),
            ],
          ),
        ));
      } else {
        // Standard body paragraph
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildRichInline(line, textColor),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildRichInline(String text, Color baseColor) {
    // Regex for bold text **word**
    final parts = text.split('**');
    if (parts.length == 1) {
      return Text(
        text,
        style: TextStyle(fontSize: 13.5, height: 1.45, color: baseColor),
      );
    }

    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isBold ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)) : baseColor,
          fontSize: 13.5,
          height: 1.45,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
