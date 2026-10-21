Future<Map<String, String?>> getWifiDetailsPlatform() async {
  return {
    'bssid': null,
    'ssid': null,
    'status': 'web_unsupported',
    'error': 'Web browsers cannot access Wi-Fi hardware directly due to browser security. Please enter the router BSSID/SSID manually or use the mobile/desktop app to detect it automatically.',
  };
}
