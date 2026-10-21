import 'wifi_detector_stub.dart'
    if (dart.library.io) 'wifi_detector_io.dart';

class WifiDetectorService {
  /// Detects the current Wi-Fi network's BSSID and SSID cross-platform.
  /// 
  /// Supports:
  /// - Windows Desktop: Queries WLAN interface via native `netsh`
  /// - Android & iOS: Handles Location Permission / GPS prerequisites and queries `network_info_plus`
  /// - Web: Gracefully handles sandbox restrictions and returns informative status
  static Future<Map<String, String?>> detectCurrentWifi() async {
    return await getWifiDetailsPlatform();
  }
}
