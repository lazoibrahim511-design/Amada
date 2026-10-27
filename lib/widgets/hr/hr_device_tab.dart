import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/hr_models.dart';
import '../../providers/attendance_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/zkteco_service.dart';
import '../glass_container.dart';
import '../neu_button.dart';

class HrDeviceTab extends StatefulWidget {
  const HrDeviceTab({super.key});

  @override
  State<HrDeviceTab> createState() => _HrDeviceTabState();
}

class _HrDeviceTabState extends State<HrDeviceTab> {
  final ZkTecoService _zkService = ZkTecoService.instance;
  late int _syncInterval;
  late int _cooldown;
  late bool _autoSync;

  bool _isTestingAll = false;
  bool _isSyncingAll = false;
  String? _syncingDeviceId;
  String? _testingDeviceId;
  bool _isFetchingUsers = false;
  String? _selectedDeviceForUsers;

  @override
  void initState() {
    super.initState();
    _syncInterval = _zkService.autoSyncIntervalMinutes;
    _cooldown = _zkService.cooldownMinutes;
    _autoSync = _zkService.autoSyncEnabled;

    _zkService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _zkService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  Future<void> _handleSaveGlobalSettings(AttendanceProvider provider, FirebaseService firebase) async {
    await _zkService.saveSettings(
      autoSync: _autoSync,
      intervalMinutes: _syncInterval,
      cooldownMinutes: _cooldown,
      provider: provider,
      firebase: firebase,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.translate('global_settings_saved')),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handleTestAllDevices(AttendanceProvider provider) async {
    setState(() => _isTestingAll = true);
    final results = await _zkService.testAllConnections();
    setState(() => _isTestingAll = false);

    if (!mounted) return;
    final onlineCount = results.values.where((info) => info.isConnected).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.translate('connection_check_result', params: {
          'online': '$onlineCount',
          'total': '${results.length}',
        })),
        backgroundColor: onlineCount > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _handleSyncAllDevices(AttendanceProvider provider, FirebaseService firebase) async {
    setState(() => _isSyncingAll = true);
    final summary = await _zkService.syncAllDevices(
      provider: provider,
      firebase: firebase,
    );
    setState(() => _isSyncingAll = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary.message),
        backgroundColor: summary.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _handleSyncSingleDevice(ZkDeviceConfig dev, AttendanceProvider provider, FirebaseService firebase) async {
    setState(() => _syncingDeviceId = dev.id);
    final summary = await _zkService.syncDevice(
      dev,
      provider: provider,
      firebase: firebase,
    );
    setState(() => _syncingDeviceId = null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary.message),
        backgroundColor: summary.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _handleTestSingleDevice(ZkDeviceConfig dev, AttendanceProvider provider) async {
    setState(() => _testingDeviceId = dev.id);
    final info = await _zkService.testDeviceConnection(dev);
    setState(() => _testingDeviceId = null);

    if (!mounted) return;
    if (info.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.translate('device_connected_msg', params: {
            'name': dev.name,
            'devName': info.deviceName,
            'sn': info.serialNumber,
          })),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.translate('device_connect_failed_msg', params: {
            'name': dev.name,
            'error': info.errorMessage ?? 'Unreachable',
          })),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleFetchUsers(ZkDeviceConfig? dev, AttendanceProvider provider) async {
    setState(() => _isFetchingUsers = true);
    try {
      final users = await _zkService.fetchUsers(device: dev);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.translate('fetched_users_success', params: {
              'count': '${users.length}',
              'name': dev?.name ?? 'device',
            })),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.translate('failed_fetch_users', params: {'error': '$e'})),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingUsers = false);
    }
  }

  void _showAddEditDeviceDialog(BuildContext context, {ZkDeviceConfig? device}) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final isEditing = device != null;
    final nameCtrl = TextEditingController(text: device?.name ?? 'Terminal ${_zkService.devices.length + 1}');
    final ipCtrl = TextEditingController(text: device?.ip ?? '192.168.1.${200 + _zkService.devices.length + 1}');
    final portCtrl = TextEditingController(text: device?.port.toString() ?? '4370');
    final pwdCtrl = TextEditingController(text: device?.password.toString() ?? '0');
    bool isEnabled = device?.isEnabled ?? true;
    String selectedCompany = (device?.companyCode.isNotEmpty == true)
        ? device!.companyCode
        : (provider.currentCompanyCode != 'all'
            ? provider.currentCompanyCode
            : (provider.allCompanies.isNotEmpty ? provider.allCompanies.first.companyCode : ''));

    bool isTestingModal = false;
    ZkDeviceInfo? testResult;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.fingerprint, color: Color(0xFF2E65FF), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? provider.translate('edit_device_dialog_title') : provider.translate('add_device_dialog_title'),
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                ),
                                Text(
                                  provider.translate('zk_dialog_subtitle'),
                                  style: TextStyle(fontSize: 12, color: subtextColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: provider.translate('device_name_label'),
                          hintText: provider.translate('device_name_hint'),
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      if (provider.allCompanies.length > 1) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: provider.allCompanies.any((c) => c.companyCode.toLowerCase() == selectedCompany.toLowerCase())
                              ? provider.allCompanies.firstWhere((c) => c.companyCode.toLowerCase() == selectedCompany.toLowerCase()).companyCode
                              : (provider.allCompanies.isNotEmpty ? provider.allCompanies.first.companyCode : null),
                          decoration: InputDecoration(
                            labelText: provider.translate('company'),
                            prefixIcon: const Icon(Icons.business_outlined, size: 20),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: provider.allCompanies.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.companyCode,
                              child: Text(c.companyName.isNotEmpty ? c.companyName : c.companyCode),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCompany = val);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: ipCtrl,
                        decoration: InputDecoration(
                          labelText: provider.translate('ip_address_label'),
                          hintText: '192.168.1.201',
                          prefixIcon: const Icon(Icons.router_outlined, size: 20),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: portCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: provider.translate('port_label'),
                                hintText: '4370',
                                prefixIcon: const Icon(Icons.numbers, size: 20),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: pwdCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: provider.translate('comm_key_label'),
                                hintText: '0',
                                prefixIcon: const Icon(Icons.key_outlined, size: 20),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(provider.translate('enable_auto_sync_switch'), style: const TextStyle(fontSize: 14)),
                        value: isEnabled,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) => setDialogState(() => isEnabled = val),
                      ),
                      if (testResult != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: testResult!.isConnected
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: testResult!.isConnected
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                testResult!.isConnected ? Icons.check_circle : Icons.error_outline,
                                color: testResult!.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  testResult!.isConnected
                                      ? provider.translate('device_online_status', params: {'name': '${testResult!.deviceName} (${testResult!.serialNumber})'})
                                      : provider.translate('device_offline_status', params: {'error': testResult!.errorMessage ?? 'Unreachable'}),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: testResult!.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          NeuButton(
                            onPressed: isTestingModal
                                ? null
                                : () async {
                                    final ip = ipCtrl.text.trim();
                                    final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
                                    final pwd = int.tryParse(pwdCtrl.text.trim()) ?? 0;
                                    if (ip.isEmpty) return;

                                    setDialogState(() => isTestingModal = true);
                                    final info = await _zkService.testConnection(ip: ip, port: port, password: pwd);
                                    setDialogState(() {
                                      isTestingModal = false;
                                      testResult = info;
                                    });
                                  },
                            isLoading: isTestingModal,
                            icon: const Icon(Icons.cable, size: 16),
                            label: provider.translate('test_connection_btn'),
                            variant: NeuButtonVariant.whitePill,
                            height: 38,
                            fontSize: 12,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: Text(provider.translate('cancel')),
                              ),
                              const SizedBox(width: 8),
                              NeuButton(
                                onPressed: () async {
                                  final name = nameCtrl.text.trim();
                                  final ip = ipCtrl.text.trim();
                                  final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
                                  final pwd = int.tryParse(pwdCtrl.text.trim()) ?? 0;

                                  if (name.isEmpty || ip.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(provider.translate('device_name_ip_required'))),
                                    );
                                    return;
                                  }

                                  if (device != null) {
                                    final updated = device.copyWith(
                                      name: name,
                                      ip: ip,
                                      port: port,
                                      password: pwd,
                                      isEnabled: isEnabled,
                                      cachedInfo: testResult ?? device.cachedInfo,
                                      companyCode: selectedCompany.trim().toLowerCase(),
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
                                      cachedInfo: testResult,
                                      companyCode: selectedCompany.trim().toLowerCase(),
                                    );
                                    await _zkService.addDevice(newDev);
                                  }

                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                },
                                label: isEditing ? provider.translate('save_changes_btn') : provider.translate('add_device_btn'),
                                variant: NeuButtonVariant.primary,
                                height: 38,
                                fontSize: 13,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteDevice(BuildContext context, ZkDeviceConfig dev) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.translate('delete_device_title', params: {'name': dev.name})),
        content: Text(provider.translate('delete_device_confirm', params: {'ip': dev.ip, 'port': '${dev.port}'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(provider.translate('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _zkService.deleteDevice(dev.id);
            },
            child: Text(provider.translate('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final firebase = FirebaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    final currentCompany = provider.currentCompanyCode.trim().toLowerCase();
    final devices = _zkService.devices
        .where((d) => d.companyCode.trim().toLowerCase() == currentCompany || d.companyCode.isEmpty)
        .toList();
    final onlineCount = devices.where((d) => d.cachedInfo?.isConnected == true).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2E65FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2E65FF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hub_outlined, color: Color(0xFF2E65FF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      provider.translate('zk_web_bridge_hint'),
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: textColor),
                    ),
                  ),
                ],
              ),
            ),

          // 1. Multi-Device Header Card
          _buildMultiDeviceHeaderCard(context, textColor, subtextColor, devices, onlineCount, provider, firebase),
          const SizedBox(height: 16),

          // 2. Devices Grid / List
          _buildDevicesList(context, textColor, subtextColor, devices, provider, firebase),
          const SizedBox(height: 16),

          // 3. Smart Auto-Sync & Multi-Device Settings
          _buildSmartSyncCard(context, textColor, subtextColor, provider, firebase),
          const SizedBox(height: 16),

          // 4. Device Users & Employee Mapping
          _buildUserMappingCard(context, textColor, subtextColor, provider, devices),
          const SizedBox(height: 16),

          // 5. Live Sync Activity Log
          _buildSyncLogsCard(context, textColor, subtextColor),
        ],
      ),
    );
  }

  Widget _buildMultiDeviceHeaderCard(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    List<ZkDeviceConfig> devices,
    int onlineCount,
    AttendanceProvider provider,
    FirebaseService firebase,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    final headerInfo = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2E65FF).withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.hub_rounded, color: Color(0xFF2E65FF), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    provider.translate('zk_devices_title'),
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      provider.translate('zk_configured_online', params: {
                        'total': '${devices.length}',
                        'online': '$onlineCount',
                      }),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                provider.translate('zk_devices_subtitle'),
                style: TextStyle(fontSize: 11.5, color: subtextColor, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );

    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        NeuButton(
          onPressed: () => _showAddEditDeviceDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: provider.translate('add_device_btn'),
          variant: NeuButtonVariant.primary,
          height: 38,
          fontSize: 12.5,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        NeuButton(
          onPressed: _isTestingAll ? null : () => _handleTestAllDevices(provider),
          isLoading: _isTestingAll,
          icon: const Icon(Icons.cable_rounded, size: 18),
          label: provider.translate('test_all_btn'),
          variant: NeuButtonVariant.whitePill,
          height: 38,
          fontSize: 12.5,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        NeuButton(
          onPressed: _isSyncingAll ? null : () => _handleSyncAllDevices(provider, firebase),
          isLoading: _isSyncingAll,
          icon: const Icon(Icons.sync_rounded, size: 18),
          label: provider.translate('sync_all_devices_btn'),
          variant: NeuButtonVariant.navy,
          height: 38,
          fontSize: 12.5,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ],
    );

    return GlassContainer(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerInfo,
                const SizedBox(height: 14),
                actionButtons,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: headerInfo),
                const SizedBox(width: 16),
                actionButtons,
              ],
            ),
    );
  }

  Widget _buildDevicesList(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    List<ZkDeviceConfig> devices,
    AttendanceProvider provider,
    FirebaseService firebase,
  ) {
    if (devices.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            const Icon(Icons.devices_other_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              provider.translate('no_zk_devices_title'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 6),
            Text(
              provider.translate('no_zk_devices_subtitle'),
              style: TextStyle(fontSize: 12, color: subtextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            NeuButton(
              onPressed: () => _showAddEditDeviceDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: provider.translate('add_first_device_btn'),
              variant: NeuButtonVariant.primary,
              height: 38,
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: devices.map((dev) {
        final info = dev.cachedInfo;
        final isConnected = info?.isConnected ?? false;
        final isSyncingThis = _syncingDeviceId == dev.id;
        final isTestingThis = _testingDeviceId == dev.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isRowLayout = constraints.maxWidth >= 760;

                    final deviceIdentity = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : (isDark ? Colors.white10 : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isConnected
                                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            Icons.fingerprint,
                            color: isConnected ? const Color(0xFF10B981) : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    dev.name,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white12 : Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${dev.ip}:${dev.port}',
                                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: subtextColor),
                                    ),
                                  ),
                                  if (dev.password > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        provider.translate('key_prefix', params: {'key': '${dev.password}'}),
                                        style: const TextStyle(fontSize: 10, color: Colors.amber),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: isConnected
                                              ? const Color(0xFF10B981)
                                              : (info != null ? const Color(0xFFEF4444) : Colors.grey),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          isConnected
                                              ? provider.translate('device_online_status', params: {'name': info!.deviceName.isNotEmpty ? info.deviceName : 'ZKTeco Terminal'})
                                              : (info != null
                                                  ? provider.translate('device_offline_status', params: {'error': info.errorMessage ?? 'Unreachable'})
                                                  : provider.translate('device_ready_connect')),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isConnected
                                                ? const Color(0xFF10B981)
                                                : (info != null ? const Color(0xFFEF4444) : subtextColor),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '• ${provider.translate('device_last_sync', params: {'status': dev.lastSyncStatus})}',
                                    style: TextStyle(fontSize: 11, color: subtextColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final deviceActions = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NeuButton(
                          onPressed: isTestingThis ? null : () => _handleTestSingleDevice(dev, provider),
                          isLoading: isTestingThis,
                          icon: const Icon(Icons.cable, size: 14),
                          label: provider.translate('test_connection_btn'),
                          variant: NeuButtonVariant.whitePill,
                          height: 32,
                          fontSize: 11.5,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        const SizedBox(width: 6),
                        NeuButton(
                          onPressed: () => _handleFetchUsers(dev, provider),
                          icon: const Icon(Icons.people_outline, size: 14),
                          label: provider.translate('device_users_btn'),
                          variant: NeuButtonVariant.whitePill,
                          height: 32,
                          fontSize: 11.5,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        const SizedBox(width: 6),
                        NeuButton(
                          onPressed: isSyncingThis ? null : () => _handleSyncSingleDevice(dev, provider, firebase),
                          isLoading: isSyncingThis,
                          icon: const Icon(Icons.sync, size: 14),
                          label: provider.translate('sync_this_btn'),
                          variant: NeuButtonVariant.primary,
                          height: 32,
                          fontSize: 11.5,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: provider.translate('edit_device_tooltip'),
                          onPressed: () => _showAddEditDeviceDialog(context, device: dev),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          tooltip: provider.translate('delete_device_tooltip'),
                          onPressed: () => _confirmDeleteDevice(context, dev),
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: dev.isEnabled,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) => _zkService.toggleDevice(dev.id, val),
                        ),
                      ],
                    );

                    if (isRowLayout) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: deviceIdentity),
                          const SizedBox(width: 16),
                          deviceActions,
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: deviceIdentity),
                              Switch(
                                value: dev.isEnabled,
                                activeThumbColor: const Color(0xFF10B981),
                                onChanged: (val) => _zkService.toggleDevice(dev.id, val),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.start,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              NeuButton(
                                onPressed: isTestingThis ? null : () => _handleTestSingleDevice(dev, provider),
                                isLoading: isTestingThis,
                                icon: const Icon(Icons.cable, size: 14),
                                label: provider.translate('test_connection_btn'),
                                variant: NeuButtonVariant.whitePill,
                                height: 32,
                                fontSize: 11.5,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              NeuButton(
                                onPressed: () => _handleFetchUsers(dev, provider),
                                icon: const Icon(Icons.people_outline, size: 14),
                                label: provider.translate('device_users_btn'),
                                variant: NeuButtonVariant.whitePill,
                                height: 32,
                                fontSize: 11.5,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              NeuButton(
                                onPressed: isSyncingThis ? null : () => _handleSyncSingleDevice(dev, provider, firebase),
                                isLoading: isSyncingThis,
                                icon: const Icon(Icons.sync, size: 14),
                                label: provider.translate('sync_this_btn'),
                                variant: NeuButtonVariant.primary,
                                height: 32,
                                fontSize: 11.5,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: provider.translate('edit_device_tooltip'),
                                onPressed: () => _showAddEditDeviceDialog(context, device: dev),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                tooltip: provider.translate('delete_device_tooltip'),
                                onPressed: () => _confirmDeleteDevice(context, dev),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                ),
                if (isConnected && info != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _buildMiniBadge(provider.translate('device_serial_badge'), info.serialNumber.isNotEmpty ? info.serialNumber : 'N/A', textColor, subtextColor),
                      _buildMiniBadge(provider.translate('device_firmware_badge'), info.firmwareVersion.isNotEmpty ? info.firmwareVersion : 'N/A', textColor, subtextColor),
                      _buildMiniBadge(provider.translate('device_users_badge'), '${info.userCount}', textColor, subtextColor),
                      _buildMiniBadge(provider.translate('device_logs_badge'), '${info.logCount}', textColor, subtextColor),
                      if (info.deviceTime != null)
                        _buildMiniBadge(provider.translate('device_clock_badge'), info.deviceTime.toString().substring(0, 16), textColor, subtextColor),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniBadge(String label, String value, Color textColor, Color subtextColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 11, color: subtextColor)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }

  Widget _buildSmartSyncCard(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    AttendanceProvider provider,
    FirebaseService firebase,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    final syncIntervalField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(provider.translate('auto_sync_interval_label'), style: TextStyle(fontSize: 12, color: subtextColor)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          initialValue: _syncInterval,
          isDense: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          items: [
            DropdownMenuItem(value: 1, child: Text(provider.translate('every_1_min'))),
            DropdownMenuItem(value: 5, child: Text(provider.translate('every_mins', params: {'mins': '5'}))),
            DropdownMenuItem(value: 10, child: Text(provider.translate('every_mins', params: {'mins': '10'}))),
            DropdownMenuItem(value: 15, child: Text('${provider.translate('every_mins', params: {'mins': '15'})} ${provider.translate('default_suffix')}')),
            DropdownMenuItem(value: 30, child: Text(provider.translate('every_mins', params: {'mins': '30'}))),
            DropdownMenuItem(value: 60, child: Text(provider.translate('every_1_hour'))),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _syncInterval = val);
              _handleSaveGlobalSettings(provider, firebase);
            }
          },
        ),
      ],
    );

    final cooldownField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(provider.translate('duplicate_cooldown_label'), style: TextStyle(fontSize: 12, color: subtextColor)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          initialValue: _cooldown,
          isDense: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          items: [
            DropdownMenuItem(value: 1, child: Text(provider.translate('cooldown_1_min'))),
            DropdownMenuItem(value: 2, child: Text(provider.translate('cooldown_mins', params: {'mins': '2'}))),
            DropdownMenuItem(value: 3, child: Text('${provider.translate('cooldown_mins', params: {'mins': '3'})} ${provider.translate('default_suffix')}')),
            DropdownMenuItem(value: 5, child: Text(provider.translate('cooldown_mins', params: {'mins': '5'}))),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _cooldown = val);
              _handleSaveGlobalSettings(provider, firebase);
            }
          },
        ),
      ],
    );

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.translate('smart_pairing_title'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              provider.translate('auto_sync_title'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
            ),
            subtitle: Text(
              provider.translate('auto_sync_subtitle'),
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
            value: _autoSync,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (val) {
              setState(() => _autoSync = val);
              _handleSaveGlobalSettings(provider, firebase);
            },
          ),
          const Divider(height: 16),
          if (isMobile) ...[
            syncIntervalField,
            const SizedBox(height: 12),
            cooldownField,
          ] else ...[
            Row(
              children: [
                Expanded(child: syncIntervalField),
                const SizedBox(width: 12),
                Expanded(child: cooldownField),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E65FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2E65FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF2E65FF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.translate('cross_terminal_pairing_desc'),
                    style: TextStyle(fontSize: 12, color: textColor, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.desktop_windows_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '24/7 Unattended Office Sync: Run "start_amada_zk_bridge.bat" on your office Windows PC to sync punches continuously to Firebase without keeping mobile phones open.',
                    style: TextStyle(fontSize: 12, color: textColor, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMappingCard(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    AttendanceProvider provider,
    List<ZkDeviceConfig> devices,
  ) {
    final deviceUsers = _zkService.cachedUsers;
    final employees = provider.employees;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    final headerTitle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.badge_outlined, color: Color(0xFF8B5CF6), size: 20),
        const SizedBox(width: 8),
        Text(
          provider.translate('user_mapping_title'),
          style: TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.bold, color: textColor),
        ),
      ],
    );

    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (devices.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: subtextColor.withValues(alpha: 0.25)),
            ),
            child: DropdownButton<String>(
              value: _selectedDeviceForUsers ?? devices.first.id,
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(fontSize: 12, color: textColor),
              items: devices.map((d) {
                return DropdownMenuItem(value: d.id, child: Text(d.name));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDeviceForUsers = val);
              },
            ),
          ),
        NeuButton(
          onPressed: _isFetchingUsers
              ? null
              : () {
                  final dev = devices.cast<ZkDeviceConfig?>().firstWhere(
                        (d) => d != null && d.id == _selectedDeviceForUsers,
                        orElse: () => devices.isNotEmpty ? devices.first : null,
                      );
                  _handleFetchUsers(dev, provider);
                },
          isLoading: _isFetchingUsers,
          icon: const Icon(Icons.download, size: 16),
          label: provider.translate('fetch_users_btn'),
          variant: NeuButtonVariant.whitePill,
          height: 34,
          fontSize: 12,
        ),
      ],
    );

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            headerTitle,
            const SizedBox(height: 12),
            controls,
          ] else ...[
            Row(
              children: [
                Expanded(child: headerTitle),
                const SizedBox(width: 8),
                controls,
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (deviceUsers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                provider.translate('fetch_users_hint'),
                style: TextStyle(fontSize: 13, color: subtextColor),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: deviceUsers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final u = deviceUsers[index];
                final matched = employees.cast<CompanyEmployee?>().firstWhere(
                      (e) {
                        if (e == null) return false;
                        if (e.id.trim().toLowerCase() == u.userId.trim().toLowerCase()) return true;
                        if (e.name.trim().toLowerCase() == u.name.trim().toLowerCase()) return true;
                        final eDigits = e.id.replaceAll(RegExp(r'[^0-9]'), '');
                        final uDigits = u.userId.replaceAll(RegExp(r'[^0-9]'), '');
                        if (eDigits.isNotEmpty && uDigits.isNotEmpty && int.tryParse(eDigits) == int.tryParse(uDigits)) {
                          return true;
                        }
                        return false;
                      },
                      orElse: () => null,
                    );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          u.userId,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.name.isNotEmpty ? u.name : 'User ${u.userId}',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                            ),
                            Text(
                              'Device UID: ${u.uid} • Card: ${u.card > 0 ? u.card : "None"}',
                              style: TextStyle(fontSize: 11, color: subtextColor),
                            ),
                          ],
                        ),
                      ),
                      if (matched != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                provider.translate('user_matched_badge', params: {
                                  'name': matched.name,
                                  'position': matched.position,
                                }),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 4),
                              Text(
                                provider.translate('user_not_matched_badge'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSyncLogsCard(BuildContext context, Color textColor, Color subtextColor) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final logs = _zkService.syncLogs;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: Color(0xFF06B6D4), size: 20),
              const SizedBox(width: 8),
              Text(
                provider.translate('activity_log_title'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              const Spacer(),
              if (logs.isNotEmpty)
                Text(
                  provider.translate('events_count', params: {'count': '${logs.length}'}),
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: subtextColor.withValues(alpha: 0.2)),
            ),
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      provider.translate('no_activity_log'),
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, idx) {
                      final log = logs[idx];
                      final isError = log.contains('failed') || log.contains('error') || log.contains('Error') || log.contains('✗');
                      final isSuccess = log.contains('success') || log.contains('Synced') || log.contains('Connected') || log.contains('✓');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: isError
                                ? const Color(0xFFEF4444)
                                : isSuccess
                                    ? const Color(0xFF10B981)
                                    : textColor.withValues(alpha: 0.85),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
