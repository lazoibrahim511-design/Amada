// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

bool isWebNotificationPermissionGranted() {
  try {
    return html.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

String getWebNotificationPermissionStatus() {
  try {
    return html.Notification.permission ?? 'default';
  } catch (_) {
    return 'default';
  }
}

Future<String> requestWebNotificationPermission() async {
  try {
    if (html.Notification.permission != 'granted') {
      return await html.Notification.requestPermission();
    }
    return 'granted';
  } catch (_) {
    return 'denied';
  }
}

void showBrowserNotification(String title, String body) {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(
        title,
        body: body,
        icon: 'favicon.png',
      );
    }
  } catch (_) {}
}
