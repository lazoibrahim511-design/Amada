import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/services/wifi_detector_service.dart';

void main() {
  test('WifiDetectorService detectCurrentWifi returns valid map structure', () async {
    final result = await WifiDetectorService.detectCurrentWifi();
    expect(result, isA<Map<String, String?>>());
    expect(result.containsKey('bssid'), isTrue);
    expect(result.containsKey('ssid'), isTrue);
    expect(result.containsKey('status'), isTrue);
    // If running on a Windows PC with active Wi-Fi, bssid should be detected
    if (result['status'] == 'success') {
      expect(result['bssid'], isNotNull);
      expect(result['bssid']!.length, equals(17));
    }
  });
}
