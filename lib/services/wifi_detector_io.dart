import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';

Future<Map<String, String?>> getWifiDetailsPlatform() async {
  // 1. Windows Desktop: Run native netsh command to query Wi-Fi adapter
  if (Platform.isWindows) {
    try {
      final result = await Process.run('netsh', ['wlan', 'show', 'interfaces']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        String? ssid;
        String? bssid;

        final ssidMatch = RegExp(
          r'^\s*SSID\s*:\s*(.+)$',
          multiLine: true,
        ).firstMatch(output);
        if (ssidMatch != null) {
          final rawSsid = ssidMatch.group(1)?.trim();
          if (rawSsid != null && rawSsid.isNotEmpty) {
            ssid = rawSsid;
          }
        }

        final bssidMatch = RegExp(
          r'^\s*(?:AP\s+)?BSSID\s*:\s*([0-9a-fA-F:]{17})',
          multiLine: true,
        ).firstMatch(output);
        if (bssidMatch != null) {
          final rawBssid = bssidMatch.group(1)?.trim();
          if (rawBssid != null && rawBssid.isNotEmpty) {
            bssid = rawBssid.toLowerCase();
          }
        }

        if (bssid != null && bssid.isNotEmpty) {
          return {
            'bssid': bssid,
            'ssid': ssid,
            'status': 'success',
          };
        }

        // Check if Wi-Fi interface is disconnected or not present
        if (output.contains('disconnected') || output.contains('There is no wireless interface')) {
          return {
            'bssid': null,
            'ssid': null,
            'status': 'not_connected',
            'error': 'Windows Wi-Fi is disconnected or PC is connected via Ethernet cable.',
          };
        }
      }
    } catch (e) {
      debugPrint('Windows netsh Wi-Fi detection error: $e');
    }
  }

  // 2. Android & iOS: Android strictly requires runtime Location Permission and GPS to be enabled
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'bssid': null,
          'ssid': null,
          'status': 'location_service_disabled',
          'error': 'Location / GPS service is turned off. Please turn on Location in your device settings to detect Wi-Fi.',
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'bssid': null,
            'ssid': null,
            'status': 'permission_denied',
            'error': 'Location permission is required by mobile OS to detect Wi-Fi BSSID.',
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'bssid': null,
          'ssid': null,
          'status': 'permission_denied_forever',
          'error': 'Location permission is permanently denied. Please allow Location in device App Settings.',
        };
      }
    } catch (e) {
      debugPrint('Geolocator check for Wi-Fi error: $e');
    }
  }

  // 3. Query network_info_plus (Android, iOS, macOS, Linux)
  try {
    final netInfo = NetworkInfo();
    String? bssid;
    String? ssid;

    try {
      bssid = await netInfo.getWifiBSSID();
    } catch (e) {
      debugPrint('getWifiBSSID error: $e');
    }

    try {
      ssid = await netInfo.getWifiName();
    } catch (e) {
      debugPrint('getWifiName error: $e');
    }

    if (bssid != null) {
      bssid = bssid.replaceAll('"', '').trim().toLowerCase();
    }
    if (ssid != null) {
      ssid = ssid.replaceAll('"', '').trim();
    }

    // Filter dummy Android MAC address (02:00:00:00:00:00) and unknown SSID
    if (bssid == '02:00:00:00:00:00' || bssid == '00:00:00:00:00:00') {
      bssid = null;
    }
    if (ssid == '<unknown ssid>' || ssid == 'unknown') {
      ssid = null;
    }

    if (bssid != null || ssid != null) {
      return {
        'bssid': bssid,
        'ssid': ssid,
        'status': 'success',
      };
    }
  } catch (e) {
    debugPrint('network_info_plus detection error: $e');
  }

  return {
    'bssid': null,
    'ssid': null,
    'status': 'not_detected',
    'error': 'No connected Wi-Fi detected. Please ensure Wi-Fi and Location/GPS are active on this device.',
  };
}
