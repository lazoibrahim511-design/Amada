import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/attendance_provider.dart';
import 'services/firebase_service.dart';
import 'services/zkteco_service.dart';
import 'widgets/neu_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('en', null);
  } catch (_) {}

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  } catch (e) {
    debugPrint('Firebase init error in ZK Bridge: $e');
  }

  final attendanceProvider = AttendanceProvider(
    initialThemePreference: 'dark',
    initialLanguage: 'en',
    initialLoggedIn: true,
    initialRole: 'hr',
  );

  final firebaseService = FirebaseService();
  await ZkTecoService.instance.init(attendanceProvider, firebaseService);

  runApp(AmadaZkBridgeApp(
    attendanceProvider: attendanceProvider,
    firebaseService: firebaseService,
  ));
}

class AmadaZkBridgeApp extends StatelessWidget {
  final AttendanceProvider attendanceProvider;
  final FirebaseService firebaseService;

  const AmadaZkBridgeApp({
    super.key,
    required this.attendanceProvider,
    required this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: attendanceProvider),
        ChangeNotifierProvider.value(value: ZkTecoService.instance),
      ],
      child: MaterialApp(
        title: 'Amada ZKTeco Cloud Bridge',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0A0E1A),
          cardColor: const Color(0xFF131B2E),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2E65FF),
            secondary: Color(0xFF00E5CE),
            surface: Color(0xFF131B2E),
          ),
          dividerColor: Colors.white.withValues(alpha: 0.08),
        ),
        home: ZkBridgeDashboardScreen(
          provider: attendanceProvider,
          firebase: firebaseService,
        ),
      ),
    );
  }
}

class ZkBridgeDashboardScreen extends StatefulWidget {
  final AttendanceProvider provider;
  final FirebaseService firebase;

  const ZkBridgeDashboardScreen({
    super.key,
    required this.provider,
    required this.firebase,
  });

  @override
  State<ZkBridgeDashboardScreen> createState() => _ZkBridgeDashboardScreenState();
}

class _ZkBridgeDashboardScreenState extends State<ZkBridgeDashboardScreen> {
  final ZkTecoService _zkService = ZkTecoService.instance;
  late int _syncInterval;
  late int _cooldown;
  late bool _autoSync;

  bool _isTestingAll = false;
  bool _isSyncingAll = false;
  String? _syncingDeviceId;
  String? _testingDeviceId;

  Timer? _countdownTimer;
  int _secondsUntilNextSync = 0;

  @override
  void initState() {
    super.initState();
    _syncInterval = _zkService.autoSyncIntervalMinutes;
    _cooldown = _zkService.cooldownMinutes;
    _autoSync = _zkService.autoSyncEnabled;

    _secondsUntilNextSync = _syncInterval * 60;
    _startCountdownTimer();

    _zkService.addListener(_onServiceUpdate);
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_autoSync && !_zkService.isSyncing) {
        setState(() {
          if (_secondsUntilNextSync > 0) {
            _secondsUntilNextSync--;
          } else {
            _secondsUntilNextSync = _syncInterval * 60;
          }
        });
      }
    });
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _zkService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  Future<void> _handleSaveGlobalSettings() async {
    await _zkService.saveSettings(
      autoSync: _autoSync,
      intervalMinutes: _syncInterval,
      cooldownMinutes: _cooldown,
      provider: widget.provider,
      firebase: widget.firebase,
    );
    _secondsUntilNextSync = _syncInterval * 60;
  }

  Future<void> _handleSyncAll() async {
    setState(() => _isSyncingAll = true);
    final summary = await _zkService.syncAllDevices(
      provider: widget.provider,
      firebase: widget.firebase,
    );
    setState(() {
      _isSyncingAll = false;
      _secondsUntilNextSync = _syncInterval * 60;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary.message),
          backgroundColor: summary.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleTestAll() async {
    setState(() => _isTestingAll = true);
    final results = await _zkService.testAllConnections();
    setState(() => _isTestingAll = false);

    if (!mounted) return;
    final onlineCount = results.values.where((info) => info.isConnected).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Device Connectivity Check: $onlineCount / ${results.length} Online'),
        backgroundColor: onlineCount > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _handleSyncSingle(ZkDeviceConfig dev) async {
    setState(() => _syncingDeviceId = dev.id);
    final summary = await _zkService.syncDevice(
      dev,
      provider: widget.provider,
      firebase: widget.firebase,
    );
    setState(() => _syncingDeviceId = null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('[${dev.name}] ${summary.message}'),
          backgroundColor: summary.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleTestSingle(ZkDeviceConfig dev) async {
    setState(() => _testingDeviceId = dev.id);
    final info = await _zkService.testDeviceConnection(dev);
    setState(() => _testingDeviceId = null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            info.isConnected
                ? '✓ [${dev.name}] Connected: ${info.deviceName} (${info.serialNumber})'
                : '✗ [${dev.name}] Connection Failed: ${info.errorMessage ?? "Unreachable"}',
          ),
          backgroundColor: info.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _toggleWindowsStartup() async {
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData == null) {
        throw Exception('Cannot locate APPDATA environment variable.');
      }
      final startupDir = Directory('$appData\\Microsoft\\Windows\\Start Menu\\Programs\\Startup');
      if (!startupDir.existsSync()) {
        startupDir.createSync(recursive: true);
      }
      final shortcutFile = File('${startupDir.path}\\AmadaZkBridge.bat');

      if (shortcutFile.existsSync()) {
        shortcutFile.deleteSync();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed Amada ZK Bridge from Windows Startup.'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
      } else {
        final currentDir = Directory.current.path;
        final batContent = '@echo off\r\ncd /d "$currentDir"\r\ncall start_zk_bridge.bat\r\n';
        shortcutFile.writeAsStringSync(batContent);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Amada ZK Bridge registered to launch automatically on Windows boot!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update startup configuration: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  bool _isWindowsStartupEnabled() {
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData == null) return false;
      final file = File('$appData\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\AmadaZkBridge.bat');
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  void _showAddEditDeviceDialog({ZkDeviceConfig? device}) {
    final isEditing = device != null;
    final nameCtrl = TextEditingController(text: device?.name ?? 'Terminal ${_zkService.devices.length + 1}');
    final ipCtrl = TextEditingController(text: device?.ip ?? '192.168.1.201');
    final portCtrl = TextEditingController(text: device?.port.toString() ?? '4370');
    final pwdCtrl = TextEditingController(text: device?.password.toString() ?? '0');
    bool isEnabled = device?.isEnabled ?? true;
    String companyCode = device?.companyCode ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEditing ? 'Edit ZKTeco Terminal' : 'Add ZKTeco Terminal',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Device Name (e.g. Main Entrance)',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: ipCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'IP Address',
                            hintText: '192.168.1.201',
                            prefixIcon: Icon(Icons.settings_ethernet, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: portCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '4370',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pwdCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Device Comm Password (0 = None)',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: companyCode),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) => companyCode = val.trim(),
                    decoration: const InputDecoration(
                      labelText: 'Company Code / Tenant ID (Optional)',
                      prefixIcon: Icon(Icons.business_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Device for Sync', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: isEnabled,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) => setModalState(() => isEnabled = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E65FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final ip = ipCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
                final pwd = int.tryParse(pwdCtrl.text.trim()) ?? 0;

                if (name.isEmpty || ip.isEmpty) return;

                if (isEditing) {
                  final updated = device.copyWith(
                    name: name,
                    ip: ip,
                    port: port,
                    password: pwd,
                    isEnabled: isEnabled,
                    companyCode: companyCode,
                  );
                  await _zkService.updateDevice(updated);
                } else {
                  final newDev = ZkDeviceConfig(
                    id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    ip: ip,
                    port: port,
                    password: pwd,
                    isEnabled: isEnabled,
                    companyCode: companyCode,
                  );
                  await _zkService.addDevice(newDev);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Terminal', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = _zkService.devices;
    final enabledCount = devices.where((d) => d.isEnabled).length;
    final onlineCount = devices.where((d) => d.cachedInfo?.isConnected == true).length;
    final isSyncing = _zkService.isSyncing || _isSyncingAll;
    final startupActive = _isWindowsStartupEnabled();

    final mins = _secondsUntilNextSync ~/ 60;
    final secs = _secondsUntilNextSync % 60;
    final countdownStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF2E65FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hub_rounded, color: Color(0xFF2E65FF), size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amada ZKTeco Cloud Bridge',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Automatic 24/7 Biometric Sync to Firebase Cloud',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Windows Startup Toggle
          IconButton(
            tooltip: startupActive ? 'Runs automatically on Windows Startup (Click to disable)' : 'Enable Run on Windows Startup',
            icon: Icon(
              Icons.power_settings_new_rounded,
              color: startupActive ? const Color(0xFF10B981) : Colors.white38,
            ),
            onPressed: _toggleWindowsStartup,
          ),
          const SizedBox(width: 8),
          // Test All button
          IconButton(
            tooltip: 'Ping & Test All Devices',
            icon: _isTestingAll
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.network_check_rounded, color: Colors.white70),
            onPressed: _isTestingAll ? null : _handleTestAll,
          ),
          const SizedBox(width: 8),
          // Manual Sync Now Button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: NeuButton(
              onPressed: isSyncing ? null : _handleSyncAll,
              isLoading: isSyncing,
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: isSyncing ? 'Syncing...' : 'Sync Now',
              variant: NeuButtonVariant.primary,
              height: 34,
              fontSize: 12,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Pane: Controls & Devices (Flex 6)
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Status Banner
                  _buildStatusBanner(isSyncing, countdownStr, enabledCount, onlineCount),
                  const SizedBox(height: 18),

                  // 2. Metrics Row
                  _buildMetricsRow(devices, onlineCount),
                  const SizedBox(height: 18),

                  // 3. Settings Card
                  _buildAutoSyncSettingsCard(),
                  const SizedBox(height: 18),

                  // 4. Terminals Header & List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fingerprint_rounded, size: 20, color: Color(0xFF2E65FF)),
                          const SizedBox(width: 8),
                          Text(
                            'Configured Terminals (${devices.length})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddEditDeviceDialog(),
                        icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF2E65FF)),
                        label: const Text('Add Terminal', style: TextStyle(color: Color(0xFF2E65FF), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (devices.isEmpty)
                    _buildEmptyDevicesCard()
                  else
                    ...devices.map((dev) => _buildDeviceCard(dev)),
                ],
              ),
            ),
          ),

          // Divider
          Container(width: 1, color: Colors.white.withValues(alpha: 0.08)),

          // Right Pane: Live Activity Log & Punch Stream (Flex 5)
          Expanded(
            flex: 5,
            child: _buildLogPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool isSyncing, String countdownStr, int enabledCount, int onlineCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _autoSync ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSyncing
                  ? const Color(0xFF2E65FF)
                  : (_autoSync ? const Color(0xFF10B981) : Colors.orangeAccent),
              boxShadow: [
                BoxShadow(
                  color: (isSyncing
                          ? const Color(0xFF2E65FF)
                          : (_autoSync ? const Color(0xFF10B981) : Colors.orangeAccent))
                      .withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSyncing
                      ? 'SYNC IN PROGRESS'
                      : (_autoSync ? '24/7 AUTO-SYNC ACTIVE' : 'AUTO-SYNC PAUSED'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isSyncing
                        ? const Color(0xFF2E65FF)
                        : (_autoSync ? const Color(0xFF10B981) : Colors.orangeAccent),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _autoSync
                      ? 'Next scheduled sync in $countdownStr ($enabledCount devices enabled)'
                      : 'Auto-sync is disabled. Turn it on below to sync unattended.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                ),
              ],
            ),
          ),
          if (_zkService.lastSyncTime != null)
            Text(
              'Last sync: ${DateFormat('HH:mm:ss').format(_zkService.lastSyncTime!)}',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(List<ZkDeviceConfig> devices, int onlineCount) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            'ONLINE TERMINALS',
            '$onlineCount / ${devices.length}',
            Icons.wifi_rounded,
            onlineCount > 0 ? const Color(0xFF10B981) : Colors.redAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            'LAST SYNC RESULT',
            _zkService.lastSummary != null
                ? '${_zkService.lastSummary!.totalPunchesFetched} logs'
                : 'Ready',
            Icons.cloud_done_rounded,
            const Color(0xFF2E65FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            'AUTO-SYNC CADENCE',
            'Every $_syncInterval mins',
            Icons.timer_rounded,
            const Color(0xFF00E5CE),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.white38, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSyncSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '24/7 Unattended Sync Settings',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Runs continuously in background without needing mobile phones',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
              Switch(
                value: _autoSync,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) {
                  setState(() => _autoSync = val);
                  _handleSaveGlobalSettings();
                },
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sync Cadence', style: TextStyle(fontSize: 11, color: Colors.white60)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _syncInterval,
                      isDense: true,
                      dropdownColor: const Color(0xFF1A233A),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Every 1 minute (Fastest)')),
                        DropdownMenuItem(value: 2, child: Text('Every 2 minutes')),
                        DropdownMenuItem(value: 5, child: Text('Every 5 minutes (Recommended)')),
                        DropdownMenuItem(value: 10, child: Text('Every 10 minutes')),
                        DropdownMenuItem(value: 15, child: Text('Every 15 minutes')),
                        DropdownMenuItem(value: 30, child: Text('Every 30 minutes')),
                        DropdownMenuItem(value: 60, child: Text('Every 1 hour')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _syncInterval = val);
                          _handleSaveGlobalSettings();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Duplicate Punch Cooldown', style: TextStyle(fontSize: 11, color: Colors.white60)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _cooldown,
                      isDense: true,
                      dropdownColor: const Color(0xFF1A233A),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 minute bounce filter')),
                        DropdownMenuItem(value: 2, child: Text('2 minutes bounce filter')),
                        DropdownMenuItem(value: 3, child: Text('3 minutes (Default)')),
                        DropdownMenuItem(value: 5, child: Text('5 minutes bounce filter')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _cooldown = val);
                          _handleSaveGlobalSettings();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDevicesCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Icon(Icons.device_unknown_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          const Text('No ZKTeco Terminals Configured', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Click "Add Terminal" to enter your device local IP and port.', style: TextStyle(fontSize: 12, color: Colors.white38)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDeviceDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Terminal'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E65FF)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ZkDeviceConfig dev) {
    final info = dev.cachedInfo;
    final isConnected = info?.isConnected ?? false;
    final isSyncingThis = _syncingDeviceId == dev.id;
    final isTestingThis = _testingDeviceId == dev.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dev.isEnabled ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !dev.isEnabled
                  ? Colors.white24
                  : (isConnected ? const Color(0xFF10B981) : Colors.redAccent),
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
                      dev.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: dev.isEnabled ? Colors.white : Colors.white38,
                      ),
                    ),
                    if (dev.companyCode.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E65FF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dev.companyCode.toUpperCase(),
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF2E65FF), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${dev.ip}:${dev.port} • ${dev.lastSyncStatus.isNotEmpty ? dev.lastSyncStatus : "Idle"}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: isTestingThis ? null : () => _handleTestSingle(dev),
                icon: isTestingThis
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cable, size: 13),
                label: const Text('Test', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: isSyncingThis ? null : () => _handleSyncSingle(dev),
                icon: isSyncingThis
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync, size: 13),
                label: const Text('Sync', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFF2E65FF)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                onPressed: () => _showAddEditDeviceDialog(device: dev),
              ),
              Switch(
                value: dev.isEnabled,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) => _zkService.toggleDevice(dev.id, val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    final logs = _zkService.syncLogs;

    return Container(
      color: const Color(0xFF0D121F),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 18, color: Color(0xFF00E5CE)),
                  SizedBox(width: 8),
                  Text(
                    'Live Sync Console & Activity Stream',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Text(
                '${logs.length} events',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Listening for ZKTeco events...\nPunches will stream live here upon sync.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white24, height: 1.4),
                      ),
                    )
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, idx) {
                        final log = logs[idx];
                        final isSuccess = log.contains('✓') || log.contains('Synced');
                        final isError = log.contains('✗') || log.contains('Failed') || log.contains('Error');
                        Color logColor = Colors.white70;
                        if (isSuccess) logColor = const Color(0xFF10B981);
                        if (isError) logColor = const Color(0xFFEF4444);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 11.5,
                              color: logColor,
                              height: 1.3,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
