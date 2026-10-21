import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Employee in a specific group only receives locations assigned to that group', () async {
    final provider = AttendanceProvider();
    provider.loadCompanyLicense('lazo');

    // Add WorkLocations:
    // 1. "Home": unassigned / no groups (groupIds is empty)
    final homeLoc = WorkLocation(
      id: 'loc_home',
      name: 'Home',
      latitude: 35.5256,
      longitude: 45.4654,
      radius: 100.0,
      companyCode: 'lazo',
      groupIds: [],
    );
    // 2. "office wifi": assigned to group 'group_09_17'
    final officeLoc = WorkLocation(
      id: 'loc_office',
      name: 'office wifi',
      latitude: 35.5467,
      longitude: 45.4590,
      radius: 170.0,
      companyCode: 'lazo',
      groupIds: ['group_09_17'],
      wifiSsid: 'iQ yourguard 5G',
      wifiBssid: 'E0:8F:4C:32:B7:6B',
    );

    await provider.addLocation(homeLoc);
    await provider.addLocation(officeLoc);

    // Employee Lawi Lazo assigned to group_09_17
    final empLawi = CompanyEmployee(
      id: 'emp_lawi',
      name: 'Lawi Lazo',
      email: 'lawi@lazo.com',
      position: 'Manager',
      role: 'employee',
      companyCode: 'lazo',
      groupId: 'group_09_17',
    );
    await provider.addEmployee(empLawi);

    // Allowed zones for Lawi Lazo must include "office wifi" and exclude "Home"
    final zones = provider.getAllowedZones(empLawi);
    expect(zones.length, equals(1));
    expect(zones.first['name'], equals('office wifi'));
    expect(zones.first['wifiSsid'], equals('iQ yourguard 5G'));
    expect(zones.first['wifiBssid'], equals('E0:8F:4C:32:B7:6B'));
    expect(zones.any((z) => z['name'] == 'Home'), isFalse);
  });
}
