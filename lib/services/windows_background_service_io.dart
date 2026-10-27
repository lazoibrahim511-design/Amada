import 'dart:io';
import 'package:flutter/foundation.dart';

class BackgroundServiceStatus {
  final bool isSupported;
  final bool isRunning;
  final bool isAutoStartEnabled;
  final List<int> runningPids;

  const BackgroundServiceStatus({
    this.isSupported = true,
    this.isRunning = false,
    this.isAutoStartEnabled = false,
    this.runningPids = const [],
  });
}

class WindowsBackgroundService {
  static const String _registryKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _appValueName = 'AmadaZkBackgroundSync';

  static bool get isSupported => !kIsWeb && Platform.isWindows;

  /// Check whether a background sync process is running, and if auto-start on boot is enabled
  static Future<BackgroundServiceStatus> getStatus() async {
    if (!isSupported) {
      return const BackgroundServiceStatus(isSupported: false);
    }

    bool isAutoStart = false;
    try {
      final regResult = await Process.run('reg', ['query', _registryKey, '/v', _appValueName]);
      if (regResult.exitCode == 0 && regResult.stdout.toString().contains(_appValueName)) {
        isAutoStart = true;
      }
    } catch (e) {
      debugPrint('Error checking auto-start registry: $e');
    }

    final runningPids = <int>[];
    try {
      final currentPid = pid;
      final taskResult = await Process.run('tasklist', [
        '/fi', 'imagename eq attendance_app.exe',
        '/fo', 'csv',
        '/nh',
      ]);
      if (taskResult.exitCode == 0) {
        final lines = taskResult.stdout.toString().split(RegExp(r'\r?\n'));
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          // CSV format: "attendance_app.exe","33268","Console","2","263,504 K"
          final parts = line.split(',');
          if (parts.length >= 2) {
            final pidStr = parts[1].replaceAll('"', '').trim();
            final procPid = int.tryParse(pidStr);
            if (procPid != null && procPid != currentPid) {
              runningPids.add(procPid);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking running background tasks: $e');
    }

    return BackgroundServiceStatus(
      isSupported: true,
      isRunning: runningPids.isNotEmpty,
      isAutoStartEnabled: isAutoStart,
      runningPids: runningPids,
    );
  }

  /// Launch the app silently in background as an independent detached process
  static Future<bool> startBackgroundService() async {
    if (!isSupported) return false;
    try {
      final exePath = Platform.resolvedExecutable;
      await Process.start(
        exePath,
        ['--silent'],
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to start background service: $e');
      return false;
    }
  }

  /// Terminate all running background instances of attendance_app.exe (preserving current GUI)
  static Future<int> stopBackgroundService() async {
    if (!isSupported) return 0;
    int stoppedCount = 0;
    try {
      final status = await getStatus();
      for (final procPid in status.runningPids) {
        final res = await Process.run('taskkill', ['/f', '/pid', procPid.toString()]);
        if (res.exitCode == 0) stoppedCount++;
      }
    } catch (e) {
      debugPrint('Error stopping background service: $e');
    }
    return stoppedCount;
  }

  /// Enable auto-start on Windows boot / logon via HKCU Run registry
  static Future<bool> enableAutoStart() async {
    if (!isSupported) return false;
    try {
      final exePath = Platform.resolvedExecutable;
      final command = '"$exePath" --silent';
      final res = await Process.run('reg', [
        'add',
        _registryKey,
        '/v',
        _appValueName,
        '/t',
        'REG_SZ',
        '/d',
        command,
        '/f',
      ]);
      return res.exitCode == 0;
    } catch (e) {
      debugPrint('Failed to enable auto-start in registry: $e');
      return false;
    }
  }

  /// Disable auto-start on Windows boot / logon
  static Future<bool> disableAutoStart() async {
    if (!isSupported) return false;
    try {
      final res = await Process.run('reg', [
        'delete',
        _registryKey,
        '/v',
        _appValueName,
        '/f',
      ]);
      return res.exitCode == 0;
    } catch (e) {
      debugPrint('Failed to disable auto-start in registry: $e');
      return false;
    }
  }
}
