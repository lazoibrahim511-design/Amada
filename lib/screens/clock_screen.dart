import '../utils/app_snackbar.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_container.dart';
import 'face_auth_screen.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  String? _locationError;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          final p = Provider.of<AttendanceProvider>(context, listen: false);
          setState(() {
            _locationError = p.translate('loc_service_disabled');
            _isLoadingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            final p = Provider.of<AttendanceProvider>(context, listen: false);
            setState(() {
              _locationError = p.translate('loc_permission_denied');
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          final p = Provider.of<AttendanceProvider>(context, listen: false);
          setState(() {
            _locationError = p.translate('loc_permission_denied_forever');
            _isLoadingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (position.isMocked) {
        if (mounted) {
          final p = Provider.of<AttendanceProvider>(context, listen: false);
          setState(() {
            _locationError = p.translate('fake_gps_detected');
            _isLoadingLocation = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        _mapController.move(_currentLocation!, 15.0);
      }

      // Continuous position stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (Position position) {
          if (mounted) {
            if (position.isMocked) {
              final p = Provider.of<AttendanceProvider>(context, listen: false);
              setState(() {
                _locationError = p.translate('fake_gps_detected');
              });
              return;
            }
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
              _isLoadingLocation = false;
            });
          }
        },
        onError: (e) {
          if (mounted) {
            final p = Provider.of<AttendanceProvider>(context, listen: false);
            setState(() {
              _locationError = '${p.translate('loc_stream_error')}: $e';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        final p = Provider.of<AttendanceProvider>(context, listen: false);
        setState(() {
          _locationError = '${p.translate('loc_error')}: $e';
          _isLoadingLocation = false;
        });
      }
    }
  }

  // Generates geographical polygon for geofence radius
  List<LatLng> _createCirclePolygon(LatLng center, double radiusInMeters) {
    const int points = 64;
    const double earthRadius = 6378137.0;
    final List<LatLng> polygon = [];

    final double lat = center.latitude * math.pi / 180.0;
    final double lng = center.longitude * math.pi / 180.0;
    final double d = radiusInMeters / earthRadius;

    for (int i = 0; i <= points; i++) {
      final double bearing = 2 * math.pi * i / points;
      final double circleLat = math.asin(math.sin(lat) * math.cos(d) +
          math.cos(lat) * math.sin(d) * math.cos(bearing));
      final double circleLng = lng +
          math.atan2(math.sin(bearing) * math.sin(d) * math.cos(lat),
              math.cos(d) - math.sin(lat) * math.sin(circleLat));
      polygon.add(LatLng(circleLat * 180.0 / math.pi, circleLng * 180.0 / math.pi));
    }
    return polygon;
  }

  Future<void> _handleAction(AttendanceProvider provider, bool isClockIn) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 0. Cooldown check for Clock Out (minimum 3 minutes)
    if (!isClockIn) {
      final cooldownError = provider.getClockOutCooldownError();
      if (cooldownError != null && mounted) {
        HapticFeedback.heavyImpact();
        AppSnackBar.show(
          scaffoldMessenger,
          message: cooldownError,
          type: AppSnackBarType.error,
          icon: Icons.timer_outlined,
        );
        return;
      }
    }

    // 1. Verify location constraints
    final locError = await provider.verifyLocation();
    if (locError != null && mounted) {
      AppSnackBar.show(
        scaffoldMessenger,
        message: locError,
        type: AppSnackBarType.error,
        icon: Icons.location_off_rounded,
      );
      return;
    }

    // 2. Face Authentication if registered
    if (provider.currentEmployee?.faceEmbedding != null) {
      if (!mounted) return;
      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceAuthScreen(
            targetEmbedding: provider.currentEmployee!.faceEmbedding,
          ),
        ),
      );

      if (success != true) {
        AppSnackBar.show(
          scaffoldMessenger,
          message: provider.translate('face_auth_failed'),
          type: AppSnackBarType.error,
          icon: Icons.face_retouching_off_rounded,
        );
        return;
      }
    }

    // 3. Show smooth loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              color: Color(0xFF00CBB4),
              strokeWidth: 3,
            ),
          ),
        );
      },
    );

    final String? result;
    if (isClockIn) {
      result = await provider.clockIn();
    } else {
      result = await provider.clockOut();
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (result == null) {
      AppSnackBar.success(
        scaffoldMessenger,
        isClockIn
            ? provider.translate('success_clock_in')
            : provider.translate('success_clock_out'),
      );
    } else if (result == 'missed_checkin') {
      AppSnackBar.warning(
        scaffoldMessenger,
        provider.translate('missed_check_in_msg'),
      );
    } else {
      AppSnackBar.error(
        scaffoldMessenger,
        result,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final emp = provider.currentEmployee;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final allowedZones = provider.getAllowedZones(emp);

    final Distance distance = const Distance();
    bool isInsideZone = false;
    double? distanceInMeters;
    Map<String, dynamic>? activeZone;

    if (_currentLocation != null && allowedZones.isNotEmpty) {
      for (final zone in allowedZones) {
        final d = distance.distance(
          _currentLocation!,
          LatLng(zone['lat'] as double, zone['lng'] as double),
        );
        if (d <= (zone['radius'] as double)) {
          isInsideZone = true;
          distanceInMeters = d;
          activeZone = zone;
          break;
        }
      }
      if (!isInsideZone) {
        double minDistance = double.infinity;
        for (final zone in allowedZones) {
          final d = distance.distance(
            _currentLocation!,
            LatLng(zone['lat'] as double, zone['lng'] as double),
          );
          if (d < minDistance) {
            minDistance = d;
            activeZone = zone;
            distanceInMeters = d;
          }
        }
      }
    }

    final primaryZone = activeZone ?? (allowedZones.isNotEmpty ? allowedZones.first : null);

    final timeHoursMinutes = DateFormat('hh:mm').format(_currentTime);
    final timeSeconds = DateFormat(':ss').format(_currentTime);
    final amPm = DateFormat('a').format(_currentTime);
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(_currentTime);

    // Resolve Today's Shift if available
    String? shiftScheduleInfo;
    if (emp != null) {
      final shift = provider.getShiftForDate(emp, _currentTime);
      final startTime = shift.getStartTimeForDate(_currentTime);
      final endTime = shift.getEndTimeForDate(_currentTime);
      shiftScheduleInfo = '${shift.name} • $startTime - $endTime';
    }

    // Calculate Today's Punch Metrics
    DateTime? firstIn;
    DateTime? lastOut;
    Duration totalDurationToday = Duration.zero;

    final today = DateTime(_currentTime.year, _currentTime.month, _currentTime.day);
    final todayPunches = provider.records.where((r) {
      return r.checkIn.year == today.year &&
          r.checkIn.month == today.month &&
          r.checkIn.day == today.day;
    }).toList()
      ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

    if (todayPunches.isNotEmpty) {
      firstIn = todayPunches.first.checkIn;
      final lastRecord = todayPunches.last;
      if (lastRecord.checkOut != null) {
        lastOut = lastRecord.checkOut;
      }
      for (final r in todayPunches) {
        totalDurationToday += r.duration;
      }
    }

    final totalHours = totalDurationToday.inHours;
    final totalMinutes = totalDurationToday.inMinutes.remainder(60);
    final totalTodayStr = totalHours > 0 ? '${totalHours}h ${totalMinutes}m' : '${totalMinutes}m';
    final firstInStr = firstIn != null ? DateFormat('hh:mm a').format(firstIn) : '--:--';
    final lastOutStr = provider.isClockedIn
        ? provider.translate('active_now')
        : (lastOut != null ? DateFormat('hh:mm a').format(lastOut) : '--:--');

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: kIsWeb ? 800 : double.infinity,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Page Header (Modern title + Live Shift status badge)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4.0, 16.0, 4.0, 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.translate('clock'),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  dateStr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Live Shift Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: provider.isClockedIn
                                  ? const Color(0xFF00BD96).withValues(alpha: isDark ? 0.20 : 0.12)
                                  : (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: provider.isClockedIn
                                    ? const Color(0xFF00BD96).withValues(alpha: 0.40)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: provider.isClockedIn
                                        ? const Color(0xFF00BD96)
                                        : const Color(0xFF94A3B8),
                                    boxShadow: provider.isClockedIn
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF00BD96).withValues(alpha: 0.6),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  provider.isClockedIn
                                      ? provider.translate('on_shift')
                                      : provider.translate('off_shift'),
                                  style: TextStyle(
                                    color: provider.isClockedIn
                                        ? const Color(0xFF00BD96)
                                        : subTextColor,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Real-Time Digital Clock & Work Session Hub
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                      borderRadius: 26,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                flex: 3,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        timeHoursMinutes,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      Text(
                                        timeSeconds,
                                        style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.5,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          amPm,
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Current Status Badge
                              Flexible(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: provider.isClockedIn
                                        ? const Color(0xFF00BD96).withValues(alpha: isDark ? 0.2 : 0.12)
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: provider.isClockedIn
                                          ? const Color(0xFF00BD96).withValues(alpha: 0.35)
                                          : (isDark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : const Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        provider.isClockedIn
                                            ? Icons.check_circle_rounded
                                            : Icons.pause_circle_outline_rounded,
                                        size: 14,
                                        color: provider.isClockedIn
                                            ? const Color(0xFF00BD96)
                                            : subTextColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            provider.isClockedIn
                                                ? provider.translate('clocked_in')
                                                : provider.translate('clocked_out'),
                                            maxLines: 1,
                                            style: TextStyle(
                                              color: provider.isClockedIn
                                                  ? const Color(0xFF00BD96)
                                                  : subTextColor,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BD96).withValues(alpha: isDark ? 0.18 : 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: Color(0xFF00BD96),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shiftScheduleInfo ?? dateStr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.isClockedIn
                                          ? provider.translate('clocked_in_msg')
                                          : provider.translate('not_clocked_in_msg'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (provider.isClockedIn)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    totalTodayStr,
                                    style: const TextStyle(
                                      color: Color(0xFF0A2342),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Hero Action Buttons (Clock In & Clock Out)
                    _buildClockButtons(provider, isDark),
                    const SizedBox(height: 16),

                    // 4. Unified Interactive Geofence & Location Hub (Map + Location Info)
                    GlassContainer(
                      padding: EdgeInsets.zero,
                      borderRadius: 26,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Interactive Map with Beacon
                          SizedBox(
                            height: 215,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                                  child: FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: _currentLocation ??
                                          (primaryZone != null
                                              ? LatLng(primaryZone['lat'] as double,
                                                  primaryZone['lng'] as double)
                                              : const LatLng(33.3152, 44.3661)),
                                      initialZoom: 15.0,
                                      minZoom: 3.0,
                                      maxZoom: 19.0,
                                      interactionOptions: const InteractionOptions(
                                        flags: InteractiveFlag.all,
                                      ),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                            'com.didam.attendance_app',
                                        maxZoom: 19,
                                      ),
                                      PolygonLayer(
                                        polygons: allowedZones.map((zone) {
                                          final isPrimary = primaryZone != null &&
                                              zone['name'] == primaryZone['name'];
                                          final zoneColor = isInsideZone
                                              ? const Color(0xFF00BD96)
                                              : const Color(0xFF3B82F6);
                                          return Polygon(
                                            points: _createCirclePolygon(
                                              LatLng(zone['lat'] as double,
                                                  zone['lng'] as double),
                                              zone['radius'] as double,
                                            ),
                                            color: zoneColor.withValues(
                                                alpha: isPrimary ? 0.22 : 0.12),
                                            borderColor: zoneColor,
                                            borderStrokeWidth: isPrimary ? 2.5 : 1.5,
                                          );
                                        }).toList(),
                                      ),
                                      if (_currentLocation != null)
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: _currentLocation!,
                                              width: 50,
                                              height: 50,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  // Outer pulse ring
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: const Color(0xFF00F0D8)
                                                          .withValues(alpha: 0.25),
                                                    ),
                                                  ),
                                                  // White border ring
                                                  Container(
                                                    width: 22,
                                                    height: 22,
                                                    decoration: const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.white,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black26,
                                                          blurRadius: 6,
                                                          offset: Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Core beacon dot
                                                  Container(
                                                    width: 14,
                                                    height: 14,
                                                    decoration: const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Color(0xFF00BD96),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                // Floating Top-Start Pill (Live Zone status on map)
                                PositionedDirectional(
                                  top: 14,
                                  start: 14,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF0F172A).withValues(alpha: 0.88)
                                          : Colors.white.withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isInsideZone
                                            ? const Color(0xFF00BD96).withValues(alpha: 0.45)
                                            : const Color(0xFFFF5C5C).withValues(alpha: 0.45),
                                        width: 1,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 10,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isInsideZone
                                              ? Icons.check_circle_rounded
                                              : Icons.location_off_rounded,
                                          size: 15,
                                          color: isInsideZone
                                              ? const Color(0xFF00BD96)
                                              : const Color(0xFFFF5C5C),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isInsideZone
                                              ? provider.translate('in_zone')
                                              : provider.translate('out_of_zone'),
                                          style: TextStyle(
                                            color: isInsideZone
                                              ? const Color(0xFF00BD96)
                                              : const Color(0xFFFF5C5C),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Floating Top-End Action (Re-center FAB)
                                PositionedDirectional(
                                  top: 14,
                                  end: 14,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B).withValues(alpha: 0.9)
                                          : Colors.white.withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          if (_currentLocation != null) {
                                            _mapController.move(_currentLocation!, 15.5);
                                          } else {
                                            _determinePosition();
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(9),
                                          child: Icon(
                                            Icons.my_location_rounded,
                                            color: isDark
                                                ? const Color(0xFF00F0D8)
                                                : const Color(0xFF0F172A),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Loading location indicator overlay
                                if (_isLoadingLocation)
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF00BD96),
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  ),
                                // Location error floating banner
                                if (_locationError != null && !_isLoadingLocation)
                                  Positioned(
                                    bottom: 12,
                                    left: 14,
                                    right: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF5C5C),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded,
                                              color: Colors.white, size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _locationError!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Integrated Location Info Bar (Bottom segment of the Card)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isInsideZone
                                        ? const Color(0xFF00BD96).withValues(alpha: isDark ? 0.2 : 0.12)
                                        : const Color(0xFFFF5C5C).withValues(alpha: isDark ? 0.2 : 0.12),
                                  ),
                                  child: Icon(
                                    isInsideZone
                                        ? Icons.location_on_rounded
                                        : Icons.location_off_rounded,
                                    color: isInsideZone
                                        ? const Color(0xFF00BD96)
                                        : const Color(0xFFFF5C5C),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        primaryZone != null
                                            ? (primaryZone['name'] as String)
                                            : provider.translate('no_location_set'),
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        distanceInMeters != null
                                            ? provider.translate('distance_away', params: {
                                                'distance': '${distanceInMeters.toInt()}',
                                                'radius':
                                                    '${primaryZone != null ? (primaryZone['radius'] as double).toInt() : 0}',
                                              })
                                            : (primaryZone != null
                                                ? '${(primaryZone['lat'] as double).toStringAsFixed(4)}, ${(primaryZone['lng'] as double).toStringAsFixed(4)}'
                                                : provider.translate('location_outside_range')),
                                        style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (primaryZone != null &&
                                          ((primaryZone['wifiSsid'] as String?)?.isNotEmpty == true ||
                                              (primaryZone['wifiBssid'] as String?)?.isNotEmpty == true)) ...[
                                        const SizedBox(height: 5),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.wifi_rounded,
                                              size: 13,
                                              color: Color(0xFF00BD96),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                (primaryZone['wifiSsid'] as String?)?.isNotEmpty == true
                                                    ? (primaryZone['wifiSsid'] as String)
                                                    : (primaryZone['wifiBssid'] as String),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFF00BD96),
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (primaryZone['requireWifi'] == true) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00BD96)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  provider.translate('require_wifi'),
                                                  style: const TextStyle(
                                                    color: Color(0xFF00BD96),
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isInsideZone
                                        ? const Color(0xFF00BD96).withValues(alpha: 0.15)
                                        : const Color(0xFFFF5C5C).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    isInsideZone
                                        ? provider.translate('in_zone')
                                        : provider.translate('out_of_zone'),
                                    style: TextStyle(
                                      color: isInsideZone
                                          ? const Color(0xFF00BD96)
                                          : const Color(0xFFFF5C5C),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Today's Activity & Punch Summary Card
                    GlassContainer(
                      padding: const EdgeInsets.all(18),
                      borderRadius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.bar_chart_rounded,
                                      size: 17,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    provider.translate('today'),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${provider.translate('total_hours')}: ',
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      totalTodayStr,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // First In
                                _buildMetricItem(
                                  title: provider.translate('check_in'),
                                  value: firstInStr,
                                  icon: Icons.login_rounded,
                                  iconColor: const Color(0xFF00BD96),
                                  isDark: isDark,
                                  textColor: textColor,
                                  subTextColor: subTextColor,
                                ),
                                Container(
                                  height: 28,
                                  width: 1,
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                ),
                                // Last Out
                                _buildMetricItem(
                                  title: provider.translate('check_out'),
                                  value: lastOutStr,
                                  icon: Icons.logout_rounded,
                                  iconColor: provider.isClockedIn ? const Color(0xFF00BD96) : const Color(0xFFFF5C5C),
                                  isDark: isDark,
                                  textColor: textColor,
                                  subTextColor: subTextColor,
                                ),
                                Container(
                                  height: 28,
                                  width: 1,
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                ),
                                // Total Duty
                                _buildMetricItem(
                                  title: provider.translate('total_hours'),
                                  value: totalTodayStr,
                                  icon: Icons.timer_outlined,
                                  iconColor: const Color(0xFF3B82F6),
                                  isDark: isDark,
                                  textColor: textColor,
                                  subTextColor: subTextColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. Helpful Attendance Guidance Note
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: Color(0xFF00BD96),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              provider.translate('ensure_inside_zone'),
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Safe spacing for bottom navigation bar
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockButtons(AttendanceProvider provider, bool isDark) {
    final bool isClockedIn = provider.isClockedIn;
    final canClockIn = !_isLoadingLocation && !isClockedIn;
    final canClockOut = !_isLoadingLocation && isClockedIn;
    final int cooldownSec = isClockedIn ? provider.clockOutRemainingSeconds : 0;
    final String clockOutSubtitle;
    if (cooldownSec > 0) {
      final remM = cooldownSec ~/ 60;
      final remS = cooldownSec % 60;
      final timeFormatted = '${remM.toString().padLeft(2, '0')}:${remS.toString().padLeft(2, '0')}';
      clockOutSubtitle = provider.translate('wait_cooldown').replaceAll('{time}', timeFormatted);
    } else {
      clockOutSubtitle = provider.translate('end_shift');
    }

    return Row(
      children: [
        // Clock In (Signature Aqua/Emerald Hero Button)
        Expanded(
          child: MouseRegion(
            cursor: canClockIn ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: canClockIn
                  ? () {
                      HapticFeedback.mediumImpact();
                      _handleAction(provider, true);
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 110,
                decoration: BoxDecoration(
                  gradient: canClockIn
                      ? const LinearGradient(
                          colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF161F2E)]
                              : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: canClockIn
                        ? Colors.white.withValues(alpha: 0.45)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: 1.5,
                  ),
                  boxShadow: canClockIn
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00BD96).withValues(alpha: isDark ? 0.40 : 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 2,
                            offset: const Offset(0, -1),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: canClockIn
                            ? const Color(0xFF0A2342).withValues(alpha: 0.12)
                            : (isDark ? Colors.white10 : Colors.black12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.login_rounded,
                        color: canClockIn
                            ? const Color(0xFF0A2342)
                            : (isDark ? Colors.white24 : Colors.black26),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          provider.translate('clock_in_btn'),
                          maxLines: 1,
                          style: TextStyle(
                            color: canClockIn
                                ? const Color(0xFF0A2342)
                                : (isDark ? Colors.white30 : Colors.black38),
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          canClockIn
                              ? provider.translate('start_shift')
                              : (isClockedIn ? provider.translate('on_shift') : provider.translate('start_shift')),
                          maxLines: 1,
                          style: TextStyle(
                            color: canClockIn
                                ? const Color(0xFF0A2342).withValues(alpha: 0.75)
                                : (isDark ? Colors.white24 : Colors.black26),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Clock Out (Vibrant Coral/Crimson Hero Button)
        Expanded(
          child: MouseRegion(
            cursor: canClockOut ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: canClockOut
                  ? () {
                      HapticFeedback.mediumImpact();
                      _handleAction(provider, false);
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 110,
                decoration: BoxDecoration(
                  gradient: canClockOut
                      ? const LinearGradient(
                          colors: [Color(0xFFFF4D4D), Color(0xFFE11D48)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF161F2E)]
                              : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: canClockOut
                        ? const Color(0xFFFDA4AF).withValues(alpha: 0.5)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: 1.5,
                  ),
                  boxShadow: canClockOut
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE11D48).withValues(alpha: isDark ? 0.40 : 0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.25),
                            blurRadius: 2,
                            offset: const Offset(0, -1),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: canClockOut
                            ? Colors.white.withValues(alpha: 0.22)
                            : (isDark ? Colors.white10 : Colors.black12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: canClockOut
                            ? Colors.white
                            : (isDark ? Colors.white24 : Colors.black26),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          provider.translate('clock_out_btn'),
                          maxLines: 1,
                          style: TextStyle(
                            color: canClockOut
                                ? Colors.white
                                : (isDark ? Colors.white30 : Colors.black38),
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          clockOutSubtitle,
                          maxLines: 1,
                          style: TextStyle(
                            color: canClockOut
                                ? Colors.white.withValues(alpha: 0.85)
                                : (isDark ? Colors.white24 : Colors.black26),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
