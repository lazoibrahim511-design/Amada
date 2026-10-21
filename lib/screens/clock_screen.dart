import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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

    // 1. Verify location constraints
    final locError = await provider.verifyLocation();
    if (locError != null && mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.location_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  locError,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF5C5C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
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
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.face_retouching_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    provider.translate('face_auth_failed'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF5C5C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
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
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isClockIn
                      ? provider.translate('success_clock_in')
                      : provider.translate('success_clock_out'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2EBD96),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (result == 'missed_checkin') {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  provider.translate('missed_check_in_msg'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF5C5C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
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

    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(_currentTime);

    // Resolve Today's Shift if available
    String? shiftScheduleInfo;
    if (emp != null) {
      final shift = provider.getShiftForDate(emp, _currentTime);
      final startTime = shift.getStartTimeForDate(_currentTime);
      final endTime = shift.getEndTimeForDate(_currentTime);
      shiftScheduleInfo = '${shift.name} • $startTime - $endTime';
    }

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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.translate('clock'),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          // Live Shift Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: provider.isClockedIn
                                  ? const Color(0xFF2EBD96).withValues(alpha: isDark ? 0.2 : 0.12)
                                  : (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: provider.isClockedIn
                                    ? const Color(0xFF2EBD96).withValues(alpha: 0.35)
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
                                        ? const Color(0xFF2EBD96)
                                        : const Color(0xFF94A3B8),
                                    boxShadow: provider.isClockedIn
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF2EBD96).withValues(alpha: 0.6),
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
                                        ? const Color(0xFF2EBD96)
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

                    // 2. Real-Time Digital Clock & Schedule Card
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 24,
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isDark
                                  ? const Color(0xFF00E5CE).withValues(alpha: 0.15)
                                  : const Color(0xFF00E5CE).withValues(alpha: 0.12),
                              border: Border.all(
                                color: const Color(0xFF00E5CE).withValues(alpha: isDark ? 0.3 : 0.25),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.access_time_filled_rounded,
                              color: Color(0xFF00CBB4),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  shiftScheduleInfo ?? dateStr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status Badge matching Home Screen
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.25)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  provider.translate('current_status'),
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  provider.isClockedIn
                                      ? provider.translate('clocked_in')
                                      : provider.translate('clocked_out'),
                                  style: TextStyle(
                                    color: provider.isClockedIn
                                        ? const Color(0xFF2EBD96)
                                        : textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Polished Interactive Map Card
                    GlassContainer(
                      padding: EdgeInsets.zero,
                      borderRadius: 24,
                      child: SizedBox(
                        height: 230,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
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
                                          ? const Color(0xFF2EBD96)
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
                                                  color: const Color(0xFF00E5CE)
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
                                                  color: Color(0xFF00CBB4),
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
                                        ? const Color(0xFF2EBD96).withValues(alpha: 0.45)
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
                                          ? const Color(0xFF2EBD96)
                                          : const Color(0xFFFF5C5C),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isInsideZone
                                          ? provider.translate('in_zone')
                                          : provider.translate('out_of_zone'),
                                      style: TextStyle(
                                        color: isInsideZone
                                            ? const Color(0xFF2EBD96)
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
                                            ? const Color(0xFF00E5CE)
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
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00CBB4),
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            // Location error floating banner
                            if (_locationError != null && !_isLoadingLocation)
                              Positioned(
                                bottom: 14,
                                left: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
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
                                            fontSize: 12.5,
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
                    ),
                    const SizedBox(height: 16),

                    // 4. Assigned Work Location Info Card
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 22,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isInsideZone
                                  ? const Color(0xFF2EBD96).withValues(alpha: isDark ? 0.2 : 0.12)
                                  : const Color(0xFFFF5C5C).withValues(alpha: isDark ? 0.2 : 0.12),
                            ),
                            child: Icon(
                              isInsideZone
                                  ? Icons.location_on_rounded
                                  : Icons.location_off_rounded,
                              color: isInsideZone
                                  ? const Color(0xFF2EBD96)
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
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
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
                                    fontSize: 12.5,
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
                                        color: Color(0xFF00CBB4),
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
                                            color: Color(0xFF00CBB4),
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
                                            color: const Color(0xFF00CBB4)
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            provider.translate('require_wifi'),
                                            style: const TextStyle(
                                              color: Color(0xFF00CBB4),
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
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isInsideZone
                                  ? const Color(0xFF2EBD96).withValues(alpha: 0.15)
                                  : const Color(0xFFFF5C5C).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              isInsideZone
                                  ? provider.translate('in_zone')
                                  : provider.translate('out_of_zone'),
                              style: TextStyle(
                                color: isInsideZone
                                    ? const Color(0xFF2EBD96)
                                    : const Color(0xFFFF5C5C),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Shift & Working Status Card
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      borderRadius: 22,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: provider.isClockedIn
                                  ? const Color(0xFF00E5CE).withValues(alpha: isDark ? 0.2 : 0.12)
                                  : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                            ),
                            child: Icon(
                              provider.isClockedIn
                                  ? Icons.work_outline_rounded
                                  : Icons.work_history_outlined,
                              color: provider.isClockedIn
                                  ? const Color(0xFF00CBB4)
                                  : subTextColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.isClockedIn
                                      ? provider.translate('status_working')
                                      : provider.translate('status_ready_to_work'),
                                  style: TextStyle(
                                    color: provider.isClockedIn
                                        ? const Color(0xFF00CBB4)
                                        : subTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  provider.isClockedIn
                                      ? provider.translate('clocked_in_msg')
                                      : provider.translate('not_clocked_in_msg'),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. Modern Hero Action Buttons (Clock In & Clock Out)
                    _buildClockButtons(provider, isDark),
                    const SizedBox(height: 16),

                    // 7. Helpful Attendance Zone Guidance Note
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
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: subTextColor,
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

                    // Safe spacing for floating bottom navigation bar
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

  Widget _buildClockButtons(AttendanceProvider provider, bool isDark) {
    final bool isClockedIn = provider.isClockedIn;
    final canClockIn = !_isLoadingLocation && !isClockedIn;
    final canClockOut = !_isLoadingLocation && isClockedIn;

    return Row(
      children: [
        // Clock In (Vibrant Aqua Cyan hero button)
        Expanded(
          child: MouseRegion(
            cursor: canClockIn ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: canClockIn ? () => _handleAction(provider, true) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 115,
                decoration: BoxDecoration(
                  gradient: canClockIn
                      ? LinearGradient(
                          colors: isDark
                              ? const [Color(0xFF00F0D8), Color(0xFF00CBB4)]
                              : const [Color(0xFF00E5CE), Color(0xFF00BFA5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF161F2E)]
                              : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: canClockIn
                        ? const Color(0xFF80FFF3).withValues(alpha: isDark ? 0.6 : 0.45)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    width: 1.5,
                  ),
                  boxShadow: canClockIn
                      ? [
                          BoxShadow(
                            color: isDark
                                ? const Color(0xFF00F0D8).withValues(alpha: 0.35)
                                : const Color(0xFF00E5CE).withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
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
                            : (isDark ? Colors.white38 : Colors.black38),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                                : (isDark ? Colors.white38 : Colors.black38),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          provider.translate('start_shift'),
                          maxLines: 1,
                          style: TextStyle(
                            color: canClockIn
                                ? const Color(0xFF0A2342).withValues(alpha: 0.75)
                                : (isDark ? Colors.white24 : Colors.black26),
                            fontSize: 11.5,
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

        // Clock Out (Vibrant Coral Red hero button)
        Expanded(
          child: MouseRegion(
            cursor: canClockOut ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: canClockOut ? () => _handleAction(provider, false) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 115,
                decoration: BoxDecoration(
                  gradient: canClockOut
                      ? const LinearGradient(
                          colors: [Color(0xFFFF4B4B), Color(0xFFE11D48)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF161F2E)]
                              : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: canClockOut
                        ? const Color(0xFFFDA4AF).withValues(alpha: 0.45)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    width: 1.5,
                  ),
                  boxShadow: canClockOut
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
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
                            : (isDark ? Colors.white38 : Colors.black38),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                                : (isDark ? Colors.white38 : Colors.black38),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          provider.translate('end_shift'),
                          maxLines: 1,
                          style: TextStyle(
                            color: canClockOut
                                ? Colors.white.withValues(alpha: 0.85)
                                : (isDark ? Colors.white24 : Colors.black26),
                            fontSize: 11.5,
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
