import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'providers/attendance_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/firebase_service.dart';
import 'services/zkteco_service.dart';
import 'widgets/picker_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling a background message via Cloud FCM: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('en', null);
  } catch (_) {}

  // Load cached preferences first for instantaneous 0-delay theme and UI rendering
  final prefs = await SharedPreferences.getInstance();
  final initialTheme = prefs.getString('app_theme_preference') ?? 'light';
  final initialLang = prefs.getString('app_language') ?? 'en';
  final initialLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final initialEmployeeId = prefs.getString('loggedInEmployeeId');
  final initialUserName = prefs.getString('loggedInUserName');
  final initialEmail = prefs.getString('loggedInEmail');
  final initialPosition = prefs.getString('loggedInPosition');
  final initialRole = prefs.getString('loggedInRole');
  final initialDepartment = prefs.getString('loggedInDepartment');
  final initialAvatar = initialEmployeeId != null ? prefs.getString('user_avatar_$initialEmployeeId') : null;

  final isLight = initialTheme != 'dark';
  // Set system UI overlay style matching initial theme immediately
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
  ));

  // Initialize Firebase with safe timeout so slow web/mobile connections or cold caches connect reliably
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('Firebase messaging background handler setup skipped: $e');
      }
    }
    debugPrint('Firebase initialized successfully.');
  } catch (e) {
    debugPrint('Firebase pre-init completed or timed out: $e. Background syncing will continue.');
  }

  runApp(MyApp(
    initialThemePreference: initialTheme,
    initialLanguage: initialLang,
    initialLoggedIn: initialLoggedIn,
    initialEmployeeId: initialEmployeeId,
    initialUserName: initialUserName,
    initialEmail: initialEmail,
    initialPosition: initialPosition,
    initialRole: initialRole,
    initialDepartment: initialDepartment,
    initialAvatarPath: initialAvatar,
  ));
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  final String initialThemePreference;
  final String initialLanguage;
  final bool initialLoggedIn;
  final String? initialEmployeeId;
  final String? initialUserName;
  final String? initialEmail;
  final String? initialPosition;
  final String? initialRole;
  final String? initialDepartment;
  final String? initialAvatarPath;

  const MyApp({
    super.key,
    this.initialThemePreference = 'light',
    this.initialLanguage = 'en',
    this.initialLoggedIn = false,
    this.initialEmployeeId,
    this.initialUserName,
    this.initialEmail,
    this.initialPosition,
    this.initialRole,
    this.initialDepartment,
    this.initialAvatarPath,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AttendanceProvider _attendanceProvider;

  @override
  void initState() {
    super.initState();
    _attendanceProvider = AttendanceProvider(
      initialThemePreference: widget.initialThemePreference,
      initialLanguage: widget.initialLanguage,
      initialLoggedIn: widget.initialLoggedIn,
      initialEmployeeId: widget.initialEmployeeId,
      initialUserName: widget.initialUserName,
      initialEmail: widget.initialEmail,
      initialPosition: widget.initialPosition,
      initialRole: widget.initialRole,
      initialDepartment: widget.initialDepartment,
      initialAvatarPath: widget.initialAvatarPath,
    );
    ZkTecoService.instance.init(_attendanceProvider, FirebaseService());
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _attendanceProvider),
        ChangeNotifierProvider.value(value: ZkTecoService.instance),
      ],
      child: Consumer<AttendanceProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            title: 'Amada',
            debugShowCheckedModeBanner: false,
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              fontFamily: provider.currentLanguage == 'ku'
                  ? 'UniQaidar'
                  : provider.currentLanguage == 'ar'
                      ? 'NotoSansArabic'
                      : 'Inter',
              fontFamilyFallback: const ['UniQaidar', 'Speda', 'NotoSansArabic', 'NotoSans'],
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF00E5CE),
                brightness: Brightness.light,
                surface: const Color(0xFFF8FAFC),
                onSurface: const Color(0xFF1E293B),
                primary: const Color(0xFF00E5CE),
                onPrimary: const Color(0xFF0A2342),
                secondary: const Color(0xFF1330A6),
                onSecondary: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: Color(0xFF1E293B)),
                titleTextStyle: TextStyle(color: Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.bold),
              ),
              iconTheme: const IconThemeData(color: Color(0xFF334155)),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Color(0xFF1E293B)),
                bodyMedium: TextStyle(color: Color(0xFF334155)),
                titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
              cardTheme: const CardThemeData(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
              ),
              dividerColor: const Color(0xFFE2E8F0),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5CE),
                  foregroundColor: const Color(0xFF0A2342),
                  elevation: 3,
                  shadowColor: const Color(0xFF00E5CE).withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF102B94),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF102B94),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              timePickerTheme: createAdaptiveTimePickerTheme(
                isDark: false,
                primaryColor: const Color(0xFF00E5CE),
                onPrimaryColor: const Color(0xFF0A2342),
              ),
              datePickerTheme: createAdaptiveDatePickerTheme(
                isDark: false,
                primaryColor: const Color(0xFF00E5CE),
                onPrimaryColor: const Color(0xFF0A2342),
              ),
            ),
            darkTheme: ThemeData(
              fontFamily: provider.currentLanguage == 'ku'
                  ? 'UniQaidar'
                  : provider.currentLanguage == 'ar'
                      ? 'NotoSansArabic'
                      : 'Inter',
              fontFamilyFallback: const ['UniQaidar', 'Speda', 'NotoSansArabic', 'NotoSans'],
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF00F0D8),
                brightness: Brightness.dark,
                surface: const Color(0xFF1E293B),
                onSurface: Colors.white,
                primary: const Color(0xFF00F0D8),
                onPrimary: const Color(0xFF0A2342),
                secondary: const Color(0xFF1E3DB8),
                onSecondary: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              iconTheme: const IconThemeData(color: Colors.white70),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white70),
                titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              dividerColor: Colors.white.withValues(alpha: 0.1),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0D8),
                  foregroundColor: const Color(0xFF0A2342),
                  elevation: 4,
                  shadowColor: const Color(0xFF00F0D8).withValues(alpha: 0.45),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00F0D8),
                  side: const BorderSide(color: Color(0xFF334155), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00F0D8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              timePickerTheme: createAdaptiveTimePickerTheme(
                isDark: true,
                primaryColor: const Color(0xFF00F0D8),
                onPrimaryColor: const Color(0xFF0A2342),
              ),
              datePickerTheme: createAdaptiveDatePickerTheme(
                isDark: true,
                primaryColor: const Color(0xFF00F0D8),
                onPrimaryColor: const Color(0xFF0A2342),
              ),
            ),
            locale: Locale(provider.currentLanguage),
            builder: (context, child) {
              return Directionality(
                textDirection: provider.currentLanguageDirection,
                child: child ?? const SizedBox(),
              );
            },
            home: provider.isLoggedIn ? const MainNavigationScreen() : const LoginScreen(),
          );
        },
      ),
    );
  }
}
