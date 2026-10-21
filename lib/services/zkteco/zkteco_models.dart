// Model definitions for ZKTeco integration

class ZkDeviceInfo {
  final bool isConnected;
  final String deviceName;
  final String serialNumber;
  final String firmwareVersion;
  final String platform;
  final String macAddress;
  final String ip;
  final int port;
  final int userCount;
  final int logCount;
  final DateTime? deviceTime;
  final String? errorMessage;

  const ZkDeviceInfo({
    this.isConnected = false,
    this.deviceName = '',
    this.serialNumber = '',
    this.firmwareVersion = '',
    this.platform = '',
    this.macAddress = '',
    this.ip = '',
    this.port = 4370,
    this.userCount = 0,
    this.logCount = 0,
    this.deviceTime,
    this.errorMessage,
  });

  ZkDeviceInfo copyWith({
    bool? isConnected,
    String? deviceName,
    String? serialNumber,
    String? firmwareVersion,
    String? platform,
    String? macAddress,
    String? ip,
    int? port,
    int? userCount,
    int? logCount,
    DateTime? deviceTime,
    String? errorMessage,
  }) {
    return ZkDeviceInfo(
      isConnected: isConnected ?? this.isConnected,
      deviceName: deviceName ?? this.deviceName,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      platform: platform ?? this.platform,
      macAddress: macAddress ?? this.macAddress,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      userCount: userCount ?? this.userCount,
      logCount: logCount ?? this.logCount,
      deviceTime: deviceTime ?? this.deviceTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ZkRawPunch {
  final String userId;
  final DateTime timestamp;
  final int status; // 0: Check-In, 1: Check-Out, etc.
  final int punchType; // 0: Finger, 1: Password, 2: Card

  const ZkRawPunch({
    required this.userId,
    required this.timestamp,
    this.status = 0,
    this.punchType = 0,
  });

  @override
  String toString() => 'Punch(user: $userId, time: $timestamp, status: $status)';
}

class ZkDeviceUser {
  final int uid;
  final String userId;
  final String name;
  final int privilege;
  final int card;

  const ZkDeviceUser({
    required this.uid,
    required this.userId,
    required this.name,
    this.privilege = 0,
    this.card = 0,
  });
}

class ZkSyncSummary {
  final bool success;
  final int totalPunchesFetched;
  final int newRecordsCreated;
  final int recordsUpdated;
  final DateTime syncTime;
  final String message;
  final List<String> details;

  const ZkSyncSummary({
    required this.success,
    this.totalPunchesFetched = 0,
    this.newRecordsCreated = 0,
    this.recordsUpdated = 0,
    required this.syncTime,
    required this.message,
    this.details = const [],
  });
}

class ZkDeviceConfig {
  final String id;
  final String name;
  final String ip;
  final int port;
  final int password;
  final bool isEnabled;
  final DateTime? lastSyncTime;
  final String lastSyncStatus;
  final ZkDeviceInfo? cachedInfo;
  final String companyCode;

  const ZkDeviceConfig({
    required this.id,
    required this.name,
    required this.ip,
    this.port = 4370,
    this.password = 0,
    this.isEnabled = true,
    this.lastSyncTime,
    this.lastSyncStatus = 'Not synced yet',
    this.cachedInfo,
    this.companyCode = '',
  });

  ZkDeviceConfig copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    int? password,
    bool? isEnabled,
    DateTime? lastSyncTime,
    String? lastSyncStatus,
    ZkDeviceInfo? cachedInfo,
    String? companyCode,
  }) {
    return ZkDeviceConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      password: password ?? this.password,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
      cachedInfo: cachedInfo ?? this.cachedInfo,
      companyCode: companyCode ?? this.companyCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'password': password,
      'isEnabled': isEnabled,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'lastSyncStatus': lastSyncStatus,
      'companyCode': companyCode.trim().toLowerCase(),
    };
  }

  factory ZkDeviceConfig.fromMap(Map<String, dynamic> map) {
    return ZkDeviceConfig(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'ZKTeco Device',
      ip: map['ip']?.toString() ?? '192.168.1.201',
      port: (map['port'] as num?)?.toInt() ?? 4370,
      password: (map['password'] as num?)?.toInt() ?? 0,
      isEnabled: map['isEnabled'] as bool? ?? true,
      lastSyncTime: map['lastSyncTime'] != null
          ? DateTime.tryParse(map['lastSyncTime'].toString())
          : null,
      lastSyncStatus: map['lastSyncStatus']?.toString() ?? 'Not synced yet',
      companyCode: map['companyCode']?.toString().trim().toLowerCase() ?? '',
    );
  }
}
