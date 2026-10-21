import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/neu_button.dart';
import '../models/hr_models.dart';
import 'face_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyCodeController;
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoggingIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    _companyCodeController = TextEditingController(text: provider.currentCompanyCode);
  }

  @override
  void dispose() {
    _companyCodeController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final error = await provider.loginWithResult(
      identifier: _identifierController.text,
      password: _passwordController.text,
      companyCode: _companyCodeController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoggingIn = false;
        _errorMessage = error;
      });
    }
  }

  Future<void> _handleFaceAuth() async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);

    // 1. Check if any employee has Face ID enrolled
    final enrolledEmployees = provider.employees
        .where((e) => e.faceEmbedding != null && e.faceEmbedding!.isNotEmpty)
        .toList();

    if (enrolledEmployees.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.face_unlock_rounded, color: Color(0xFF00E5CE), size: 48),
          title: Text(
            provider.translate('face_id_not_configured'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            provider.translate('no_face_id_registered'),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(provider.translate('ok'), style: const TextStyle(color: Color(0xFF00E5CE))),
            ),
          ],
        ),
      );
      return;
    }

    // 2. If the user already typed their email or employee ID
    final idText = _identifierController.text.trim();
    if (idText.isNotEmpty) {
      CompanyEmployee? matchingEmp;
      for (final e in provider.employees) {
        if (e.email.trim().toLowerCase() == idText.toLowerCase() ||
            e.id.trim().toLowerCase() == idText.toLowerCase()) {
          matchingEmp = e;
          break;
        }
      }

      if (matchingEmp != null) {
        if (matchingEmp.faceEmbedding == null || matchingEmp.faceEmbedding!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.translate('no_face_id_enrolled_for_emp', params: {'name': matchingEmp.name})),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }

        // Verify single target employee
        final verified = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FaceAuthScreen(
              targetEmbedding: matchingEmp!.faceEmbedding,
              title: provider.translate('face_id_verification_title'),
            ),
          ),
        );

        if (verified == true && mounted) {
          setState(() => _isLoggingIn = true);
          await provider.loginAsEmployee(matchingEmp);
          if (mounted) setState(() => _isLoggingIn = false);
        }
        return;
      }
    }

    // 3. Identification Mode: Match against all enrolled employees
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceAuthScreen(
          matchEmployees: enrolledEmployees,
          title: provider.translate('face_id_sign_in_title'),
        ),
      ),
    );

    if (result != null && result is CompanyEmployee && mounted) {
      setState(() => _isLoggingIn = true);
      await provider.loginAsEmployee(result);
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Ambient Background Color
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
              ),
            ),

            // Top-Right Ambient Glow Blob
            Positioned(
              top: -120,
              right: -100,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E65FF).withValues(alpha: isDark ? 0.25 : 0.15),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom-Left Ambient Glow Blob
            Positioned(
              bottom: -120,
              left: -100,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.12),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),

            // 2. Main Center Content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight > 32 ? constraints.maxHeight - 32 : 0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // App Brand Logo & Title Header
                              _buildLogoHeader(provider, isDark),
                              const SizedBox(height: 18),

                              // Login Form Glassmorphic Card
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF131B2E).withValues(alpha: 0.95)
                                      : Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.4)
                                          : const Color(0xFF2E65FF).withValues(alpha: 0.08),
                                      blurRadius: 32,
                                      spreadRadius: -4,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row with "Welcome back" on the left and Language selector on top right
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    provider.translate('welcome_back'),
                                                    style: TextStyle(
                                                      fontSize: 23,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: -0.3,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    provider.translate('sign_in_subtitle'),
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      color: isDark ? Colors.white60 : Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildLanguageSelector(provider, isDark),
                                          ],
                                        ),
                                        const SizedBox(height: 22),

                                  // Error Banner
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                  ],

                                  // Company Code Field
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        provider.translate('company_code'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                      if (provider.currentLicense != null)
                                        Text(
                                          provider.currentLicense!.companyName,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2E65FF),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _companyCodeController,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    decoration: _buildInputDecoration(
                                      hintText: provider.translate('company_code_hint'),
                                      prefixIcon: Icons.domain_rounded,
                                      isDark: isDark,
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return provider.translate('enter_company_code');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),

                                  // Email Field
                                  Text(
                                    provider.translate('email'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _identifierController,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _buildInputDecoration(
                                      hintText: provider.translate('email_hint'),
                                      prefixIcon: Icons.email_outlined,
                                      isDark: isDark,
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return provider.translate('email_required');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Password Field
                                  Text(
                                    provider.translate('password'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    decoration: _buildInputDecoration(
                                      hintText: provider.translate('password_hint'),
                                      prefixIcon: Icons.lock_outline_rounded,
                                      isDark: isDark,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return provider.translate('password_required');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Remember Me & Forgot Password
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: Checkbox(
                                              value: _rememberMe,
                                              activeColor: const Color(0xFF2E65FF),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              onChanged: (val) {
                                                setState(() {
                                                  _rememberMe = val ?? true;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            provider.translate('remember_me'),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: isDark ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(provider.translate('reset_password_contact_hr')),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          provider.translate('forgot_password'),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF2E65FF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Default Admin quick autofill chip
                                  InkWell(
                                    onTap: () {
                                      final code = _companyCodeController.text.trim().toLowerCase();
                                      final effectiveCode = code.isEmpty ? 'lazo' : code;
                                      setState(() {
                                        _identifierController.text = 'admin@$effectiveCode.com';
                                        _passwordController.text = 'admin123';
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E65FF).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF2E65FF).withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.key_rounded, size: 15, color: Color(0xFF2E65FF)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              provider.translate(
                                                'default_admin_chip',
                                                params: {
                                                  'email': 'admin@${_companyCodeController.text.trim().isEmpty ? 'lazo' : _companyCodeController.text.trim()}.com',
                                                  'password': 'admin123',
                                                },
                                              ),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF2E65FF),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Primary Sign In Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: NeuButton(
                                      onPressed: _isLoggingIn ? null : _handleLogin,
                                      label: provider.translate('login'),
                                      variant: NeuButtonVariant.primary,
                                      height: 52,
                                      borderRadius: 50,
                                      fontSize: 16,
                                      isLoading: _isLoggingIn,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Secondary Face ID Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: NeuButton(
                                      onPressed: _handleFaceAuth,
                                      icon: const Icon(Icons.face_rounded),
                                      label: '${provider.translate('login')} (${provider.translate('face_verification')})',
                                      variant: NeuButtonVariant.whitePill,
                                      height: 50,
                                      borderRadius: 50,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoHeader(AttendanceProvider provider, bool isDark) {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF20B3A7).withValues(alpha: isDark ? 0.35 : 0.18),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              'assets/images/app_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          provider.translate('app_tagline'),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(AttendanceProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.currentLanguage,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: const Padding(
            padding: EdgeInsetsDirectional.only(start: 4),
            child: Icon(Icons.language_rounded, size: 16, color: Color(0xFF2E65FF)),
          ),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'ku', child: Text('Kurdî')),
            DropdownMenuItem(value: 'ar', child: Text('العربية')),
          ],
          onChanged: (lang) {
            if (lang != null) {
              provider.setLanguage(lang);
            }
          },
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
      prefixIcon: Icon(prefixIcon, size: 20, color: isDark ? Colors.white54 : Colors.black45),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2E65FF), width: 1.8),
      ),
    );
  }
}
