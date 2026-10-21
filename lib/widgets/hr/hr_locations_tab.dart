import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';
import '../neu_button.dart';

class HrLocationsTab extends StatefulWidget {
  final String searchQuery;
  final Function(WorkLocation location)? onEdit;
  final Function(String id)? onDelete;

  const HrLocationsTab({
    super.key,
    required this.searchQuery,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<HrLocationsTab> createState() => _HrLocationsTabState();
}

class _HrLocationsTabState extends State<HrLocationsTab> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final locations = provider.locations;

    if (locations.isEmpty) {
      return _buildEmptyState(context);
    }

    final filtered = widget.searchQuery.isEmpty
        ? locations
        : locations
            .where((l) => l.name.toLowerCase().contains(widget.searchQuery.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1400
            ? 4
            : constraints.maxWidth > 950
                ? 3
                : constraints.maxWidth > 650
                    ? 2
                    : 1;

        if (crossAxisCount == 1) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              return _buildLocationCard(context, filtered[index], provider);
            },
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 2 ? 1.75 : 1.9,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildLocationCard(context, filtered[index], provider);
          },
        );
      },
    );
  }

  Widget _buildLocationCard(BuildContext context, WorkLocation location, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF8B5CF6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${provider.translate('radius_label')}: ${location.radius.toInt()}m',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: provider.translate('edit_location'),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onEdit != null) {
                          widget.onEdit!(location);
                        } else {
                          showLocationDialog(context, location: location);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: '${provider.translate('delete')} ${provider.translate('locations')}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onDelete != null) {
                          widget.onDelete!(location.id);
                        } else {
                          _showDeleteConfirm(context, location.id, provider);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          Divider(
            height: 16,
            thickness: 1,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${location.radius.toInt()}m ${provider.translate('geofence_suffix')}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if ((location.wifiSsid != null && location.wifiSsid!.isNotEmpty) ||
              (location.wifiBssid != null && location.wifiBssid!.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: location.requireWifi
                    ? const Color(0xFF00CBB4).withValues(alpha: 0.1)
                    : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: location.requireWifi
                      ? const Color(0xFF00CBB4).withValues(alpha: 0.3)
                      : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_rounded,
                    size: 14,
                    color: location.requireWifi ? const Color(0xFF00CBB4) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${location.wifiSsid?.isNotEmpty == true ? location.wifiSsid : 'Wi-Fi'}${location.wifiBssid?.isNotEmpty == true ? ' (${location.wifiBssid})' : ''}${location.requireWifi ? ' • ${provider.translate('require_wifi')}' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: location.requireWifi
                            ? const Color(0xFF00CBB4)
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Work Locations Found',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String id, AttendanceProvider provider) {
    showGlassDialog(
      context: context,
      title: '${provider.translate('delete')} ${provider.translate('locations')}',
      subtitle: provider.translate('delete_confirm_title'),
      icon: Icons.delete_outline,
      content: Text(provider.translate('delete_confirm_desc')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(provider.translate('cancel')),
        ),
        NeuButton(
          label: provider.translate('delete'),
          variant: NeuButtonVariant.danger,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: () {
            provider.deleteLocation(id);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

void showLocationDialog(BuildContext context, {WorkLocation? location}) {
  final nameController = TextEditingController(text: location?.name ?? '');
  final latController = TextEditingController(text: (location?.latitude ?? 0.0).toString());
  final lngController = TextEditingController(text: (location?.longitude ?? 0.0).toString());
  final radiusController = TextEditingController(text: (location?.radius ?? 100.0).toString());
  final bssidController = TextEditingController(text: location?.wifiBssid ?? '');
  final ssidController = TextEditingController(text: location?.wifiSsid ?? '');
  bool requireWifiVal = location?.requireWifi ?? false;
  bool isDetectingWifi = false;
  final provider = Provider.of<AttendanceProvider>(context, listen: false);

  showGlassDialog(
    context: context,
    title: location == null ? provider.translate('add_new_location') : provider.translate('edit_location'),
    subtitle: provider.translate('fill_details_below'),
    icon: Icons.location_on_outlined,
    content: StatefulBuilder(
      builder: (context, setDialogState) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: provider.translate('location_name_label'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: provider.translate('latitude_label'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: provider.translate('longitude_label'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: radiusController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${provider.translate('radius')} (${provider.translate('meters')})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00CBB4).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF00CBB4).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wifi_rounded, size: 18, color: Color(0xFF00CBB4)),
                        const SizedBox(width: 8),
                        Text(
                          provider.translate('office_wifi_verification'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00CBB4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.translate('wifi_bssid_help'),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ssidController,
                      decoration: InputDecoration(
                        labelText: provider.translate('wifi_ssid'),
                        hintText: 'e.g. Office_WiFi',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bssidController,
                      decoration: InputDecoration(
                        labelText: provider.translate('wifi_bssid'),
                        hintText: 'e.g. 00:11:22:33:44:55',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        NeuButton(
                          label: provider.translate('detect_current_wifi'),
                          variant: NeuButtonVariant.primary,
                          isLoading: isDetectingWifi,
                          icon: const Icon(Icons.wifi_find_rounded, size: 15),
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed: isDetectingWifi
                              ? null
                              : () async {
                                  setDialogState(() => isDetectingWifi = true);
                                  try {
                                    final wifi = await provider.getCurrentWifiDetails();
                                    setDialogState(() {
                                      isDetectingWifi = false;
                                      if (wifi['bssid'] != null) bssidController.text = wifi['bssid']!;
                                      if (wifi['ssid'] != null) ssidController.text = wifi['ssid']!;
                                    });
                                    if (context.mounted) {
                                      if (wifi['bssid'] != null || wifi['ssid'] != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              provider.translate('wifi_detected', params: {
                                                'ssid': wifi['ssid'] ?? 'Wi-Fi',
                                                'bssid': wifi['bssid'] ?? '',
                                              }),
                                            ),
                                            backgroundColor: const Color(0xFF00CBB4),
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(wifi['error'] ?? provider.translate('no_wifi_detected')),
                                            backgroundColor: Colors.redAccent,
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    setDialogState(() => isDetectingWifi = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: requireWifiVal,
                              activeThumbColor: const Color(0xFF00CBB4),
                              onChanged: (val) {
                                setDialogState(() {
                                  requireWifiVal = val;
                                });
                              },
                            ),
                            Text(
                              provider.translate('require_wifi'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(provider.translate('cancel')),
      ),
      NeuButton(
        label: provider.translate('save_changes'),
        variant: NeuButtonVariant.primary,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        onPressed: () {
          final targetCompany = provider.currentCompanyCode == 'all' ? '' : provider.currentCompanyCode;
          final newLoc = WorkLocation(
            id: location?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameController.text.trim(),
            latitude: double.tryParse(latController.text) ?? 0.0,
            longitude: double.tryParse(lngController.text) ?? 0.0,
            radius: double.tryParse(radiusController.text) ?? 100.0,
            companyCode: (location != null && location.companyCode.isNotEmpty)
                ? location.companyCode
                : targetCompany,
            wifiBssid: bssidController.text.trim().isNotEmpty ? bssidController.text.trim() : null,
            wifiSsid: ssidController.text.trim().isNotEmpty ? ssidController.text.trim() : null,
            requireWifi: requireWifiVal,
          );
          if (location == null) {
            provider.addLocation(newLoc);
          } else {
            provider.updateLocation(newLoc);
          }
          Navigator.pop(context);
        },
      ),
    ],
  );
}
