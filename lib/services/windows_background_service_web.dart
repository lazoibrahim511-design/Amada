class BackgroundServiceStatus {
  final bool isSupported;
  final bool isRunning;
  final bool isAutoStartEnabled;
  final List<int> runningPids;

  const BackgroundServiceStatus({
    this.isSupported = false,
    this.isRunning = false,
    this.isAutoStartEnabled = false,
    this.runningPids = const [],
  });
}

class WindowsBackgroundService {
  static bool get isSupported => false;
  static Future<BackgroundServiceStatus> getStatus() async =>
      const BackgroundServiceStatus(isSupported: false);
  static Future<bool> startBackgroundService() async => false;
  static Future<int> stopBackgroundService() async => 0;
  static Future<bool> enableAutoStart() async => false;
  static Future<bool> disableAutoStart() async => false;
}
