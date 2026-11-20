import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/hr_models.dart';
import '../models/attendance_record.dart';
import '../models/request_model.dart';
import '../models/chat_message.dart';
import '../models/deleted_punch_model.dart';
import '../models/company_license.dart';
import 'zkteco/zkteco_models.dart';

class FirebaseService {
  // --- In-Memory & Local Cache for static metadata (to minimize Firestore network reads) ---
  final Map<String, List<OrgStructure>> _cachedStructures = {};
  final Map<String, List<WorkShift>> _cachedShifts = {};
  final Map<String, List<EmployeeGroup>> _cachedGroups = {};
  final Map<String, List<WorkLocation>> _cachedLocations = {};
  final Map<String, List<Holiday>> _cachedHolidays = {};

  // Check if Firebase is initialized
  bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // --- OrgStructure CRUD (Tenant-isolated with Cache) ---
  Future<List<OrgStructure>> getStructures({String? companyCode, bool forceRefresh = false}) async {
    if (!isAvailable) return [];
    final cleanFilter = companyCode?.trim().toLowerCase();
    final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
    if (!forceRefresh && _cachedStructures.containsKey(cacheKey) && _cachedStructures[cacheKey]!.isNotEmpty) {
      return List.unmodifiable(_cachedStructures[cacheKey]!);
    }
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('structures');
      if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
        query = query.where('companyCode', isEqualTo: cleanFilter);
      }
      QuerySnapshot<Map<String, dynamic>>? snapshot;
      if (!forceRefresh) {
        try {
          snapshot = await query.get(const GetOptions(source: Source.cache));
        } catch (_) {}
      }
      if (snapshot == null || snapshot.docs.isEmpty) {
        snapshot = await query.get();
      }
      final list = <OrgStructure>[];
      for (var doc in snapshot.docs) {
        try {
          final s = OrgStructure.fromMap(doc.data(), doc.id);
          if (cleanFilter == null ||
              cleanFilter.isEmpty ||
              cleanFilter == 'all' ||
              s.companyCode.toLowerCase() == cleanFilter) {
            list.add(s);
          }
        } catch (e) {
          debugPrint('Error parsing OrgStructure ${doc.id}: $e');
        }
      }
      _cachedStructures[cacheKey] = list;
      return list;
    } catch (e) {
      debugPrint('Error getting structures: $e');
      return _cachedStructures[cacheKey] ?? [];
    }
  }

  Stream<List<OrgStructure>> streamStructures({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    Query<Map<String, dynamic>> query = _firestore.collection('structures');
    if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
      query = query.where('companyCode', isEqualTo: cleanFilter);
    }
    return query.snapshots().map((snapshot) {
      final list = <OrgStructure>[];
      for (var doc in snapshot.docs) {
        try {
          final s = OrgStructure.fromMap(doc.data(), doc.id);
          if (cleanFilter == null ||
              cleanFilter.isEmpty ||
              cleanFilter == 'all' ||
              s.companyCode.toLowerCase() == cleanFilter) {
            list.add(s);
          }
        } catch (e) {
          debugPrint('Error parsing OrgStructure ${doc.id}: $e');
        }
      }
      final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
      _cachedStructures[cacheKey] = list;
      return list;
    });
  }

  Future<void> saveStructure(OrgStructure structure) async {
    if (!isAvailable) return;
    try {
      _cachedStructures.clear();
      final code = structure.companyCode.trim().toLowerCase();
      final docId = (code != 'amada' && !structure.id.startsWith('${code}_'))
          ? '${code}_${structure.id}'
          : structure.id;
      await _firestore
          .collection('structures')
          .doc(docId)
          .set(structure.toMap());
    } catch (e) {
      debugPrint('Error saving structure: $e');
    }
  }

  Future<void> deleteStructure(String id) async {
    if (!isAvailable) return;
    try {
      _cachedStructures.clear();
      await _firestore.collection('structures').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting structure: $e');
    }
  }

  // --- WorkShift CRUD (Tenant-isolated with Cache) ---
  Future<List<WorkShift>> getShifts({String? companyCode, bool forceRefresh = false}) async {
    if (!isAvailable) return [];
    final cleanFilter = companyCode?.trim().toLowerCase();
    final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
    if (!forceRefresh && _cachedShifts.containsKey(cacheKey) && _cachedShifts[cacheKey]!.isNotEmpty) {
      return List.unmodifiable(_cachedShifts[cacheKey]!);
    }
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('shifts');
      if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
        query = query.where('companyCode', isEqualTo: cleanFilter);
      }
      QuerySnapshot<Map<String, dynamic>>? snapshot;
      if (!forceRefresh) {
        try {
          snapshot = await query.get(const GetOptions(source: Source.cache));
        } catch (_) {}
      }
      if (snapshot == null || snapshot.docs.isEmpty) {
        snapshot = await query.get();
      }
      final list = <WorkShift>[];
      for (var doc in snapshot.docs) {
        try {
          final s = WorkShift.fromMap(doc.data(), doc.id);
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || s.companyCode.toLowerCase() == cleanFilter) {
            list.add(s);
          }
        } catch (e) {
          debugPrint('Error parsing WorkShift ${doc.id}: $e');
        }
      }
      _cachedShifts[cacheKey] = list;
      return list;
    } catch (e) {
      debugPrint('Error getting shifts: $e');
      return _cachedShifts[cacheKey] ?? [];
    }
  }

  Stream<List<WorkShift>> streamShifts({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    Query<Map<String, dynamic>> query = _firestore.collection('shifts');
    if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
      query = query.where('companyCode', isEqualTo: cleanFilter);
    }
    return query.snapshots().map((snapshot) {
      final list = <WorkShift>[];
      for (var doc in snapshot.docs) {
        try {
          final s = WorkShift.fromMap(doc.data(), doc.id);
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || s.companyCode.toLowerCase() == cleanFilter) {
            list.add(s);
          }
        } catch (e) {
          debugPrint('Error parsing WorkShift ${doc.id}: $e');
        }
      }
      final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
      _cachedShifts[cacheKey] = list;
      return list;
    });
  }

  Future<void> saveShift(WorkShift shift) async {
    if (!isAvailable) return;
    try {
      _cachedShifts.clear();
      final code = shift.companyCode.trim().toLowerCase();
      final docId = (code != 'amada' && !shift.id.startsWith('${code}_'))
          ? '${code}_${shift.id}'
          : shift.id;
      await _firestore.collection('shifts').doc(docId).set(shift.toMap());
    } catch (e) {
      debugPrint('Error saving shift: $e');
    }
  }

  Future<void> deleteShift(String id) async {
    if (!isAvailable) return;
    try {
      _cachedShifts.clear();
      await _firestore.collection('shifts').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting shift: $e');
    }
  }

  // --- EmployeeGroup CRUD (Tenant-isolated with Cache) ---
  Future<List<EmployeeGroup>> getGroups({String? companyCode, bool forceRefresh = false}) async {
    if (!isAvailable) return [];
    final cleanFilter = companyCode?.trim().toLowerCase();
    final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
    if (!forceRefresh && _cachedGroups.containsKey(cacheKey) && _cachedGroups[cacheKey]!.isNotEmpty) {
      return List.unmodifiable(_cachedGroups[cacheKey]!);
    }
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('groups');
      if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
        query = query.where('companyCode', isEqualTo: cleanFilter);
      }
      QuerySnapshot<Map<String, dynamic>>? snapshot;
      if (!forceRefresh) {
        try {
          snapshot = await query.get(const GetOptions(source: Source.cache));
        } catch (_) {}
      }
      if (snapshot == null || snapshot.docs.isEmpty) {
        snapshot = await query.get();
      }
      final list = <EmployeeGroup>[];
      for (var doc in snapshot.docs) {
        try {
          final g = EmployeeGroup.fromMap(doc.data(), doc.id);
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || g.companyCode.toLowerCase() == cleanFilter) {
            list.add(g);
          }
        } catch (e) {
          debugPrint('Error parsing EmployeeGroup ${doc.id}: $e');
        }
      }
      _cachedGroups[cacheKey] = list;
      return list;
    } catch (e) {
      debugPrint('Error getting groups: $e');
      return _cachedGroups[cacheKey] ?? [];
    }
  }

  Stream<List<EmployeeGroup>> streamGroups({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    Query<Map<String, dynamic>> query = _firestore.collection('groups');
    if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
      query = query.where('companyCode', isEqualTo: cleanFilter);
    }
    return query.snapshots().map((snapshot) {
      final list = <EmployeeGroup>[];
      for (var doc in snapshot.docs) {
        try {
          final g = EmployeeGroup.fromMap(doc.data(), doc.id);
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || g.companyCode.toLowerCase() == cleanFilter) {
            list.add(g);
          }
        } catch (e) {
          debugPrint('Error parsing EmployeeGroup ${doc.id}: $e');
        }
      }
      final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
      _cachedGroups[cacheKey] = list;
      return list;
    });
  }

  Future<void> saveGroup(EmployeeGroup group) async {
    if (!isAvailable) return;
    try {
      _cachedGroups.clear();
      final code = group.companyCode.trim().toLowerCase();
      final docId = (code != 'amada' && !group.id.startsWith('${code}_'))
          ? '${code}_${group.id}'
          : group.id;
      await _firestore.collection('groups').doc(docId).set(group.toMap());
    } catch (e) {
      debugPrint('Error saving group: $e');
    }
  }

  Future<void> deleteGroup(String id) async {
    if (!isAvailable) return;
    try {
      _cachedGroups.clear();
      await _firestore.collection('groups').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting group: $e');
    }
  }

  // --- WorkLocation CRUD (Tenant-isolated with Cache) ---
  Future<List<WorkLocation>> getLocations({String? companyCode, bool forceRefresh = false}) async {
    if (!isAvailable) return [];
    final cleanFilter = companyCode?.trim().toLowerCase();
    final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
    if (!forceRefresh && _cachedLocations.containsKey(cacheKey) && _cachedLocations[cacheKey]!.isNotEmpty) {
      return List.unmodifiable(_cachedLocations[cacheKey]!);
    }
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('locations');
      if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
        query = query.where('companyCode', isEqualTo: cleanFilter);
      }
      QuerySnapshot<Map<String, dynamic>>? snapshot;
      if (!forceRefresh) {
        try {
          snapshot = await query.get(const GetOptions(source: Source.cache));
        } catch (_) {}
      }
      if (snapshot == null || snapshot.docs.isEmpty) {
        snapshot = await query.get();
      }
      final list = <WorkLocation>[];
      for (var doc in snapshot.docs) {
        try {
          final l = WorkLocation.fromMap(doc.data(), doc.id);
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || l.companyCode.toLowerCase() == cleanFilter) {
            list.add(l);
          }
        } catch (e) {
          debugPrint('Error parsing WorkLocation ${doc.id}: $e');
        }
      }
      _cachedLocations[cacheKey] = list;
      return list;
    } catch (e) {
      debugPrint('Error getting locations: $e');
      return _cachedLocations[cacheKey] ?? [];
    }
  }

  Stream<List<WorkLocation>> streamLocations({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    Query<Map<String, dynamic>> query = _firestore.collection('locations');
    if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
      query = query.where('companyCode', isEqualTo: cleanFilter);
    }
    return query.snapshots().map((snapshot) {
      final list = <WorkLocation>[];
      for (var doc in snapshot.docs) {
        try {
          final l = WorkLocation.fromMap(doc.data(), doc.id);
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || l.companyCode.toLowerCase() == cleanFilter) {
            list.add(l);
          }
        } catch (e) {
          debugPrint('Error parsing WorkLocation ${doc.id}: $e');
        }
      }
      final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
      _cachedLocations[cacheKey] = list;
      return list;
    });
  }

  Future<void> saveLocation(WorkLocation location) async {
    if (!isAvailable) return;
    try {
      _cachedLocations.clear();
      final code = location.companyCode.trim().toLowerCase();
      final docId = (code != 'amada' && !location.id.startsWith('${code}_'))
          ? '${code}_${location.id}'
          : location.id;
      await _firestore.collection('locations').doc(docId).set(location.toMap());
    } catch (e) {
      debugPrint('Error saving location: $e');
    }
  }

  Future<void> deleteLocation(String id) async {
    if (!isAvailable) return;
    try {
      _cachedLocations.clear();
      await _firestore.collection('locations').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting location: $e');
    }
  }

  // --- ZkDeviceConfig CRUD (Tenant-isolated) ---
  Future<List<ZkDeviceConfig>> getDevices({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final cleanFilter = companyCode?.trim().toLowerCase();
      Query<Map<String, dynamic>> query = _firestore.collection('devices');
      if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
        query = query.where('companyCode', isEqualTo: cleanFilter);
      }
      final snapshot = await query.get();
      final list = <ZkDeviceConfig>[];
      for (var doc in snapshot.docs) {
        try {
          final d = ZkDeviceConfig.fromMap(doc.data());
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || d.companyCode.toLowerCase() == cleanFilter) {
            list.add(d);
          }
        } catch (e) {
          debugPrint('Error parsing ZkDeviceConfig ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting devices: $e');
      return [];
    }
  }

  Stream<List<ZkDeviceConfig>> streamDevices({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    Query<Map<String, dynamic>> query = _firestore.collection('devices');
    if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
      query = query.where('companyCode', isEqualTo: cleanFilter);
    }
    return query.snapshots().map((snapshot) {
      final list = <ZkDeviceConfig>[];
      for (var doc in snapshot.docs) {
        try {
          final d = ZkDeviceConfig.fromMap(doc.data());
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || d.companyCode.toLowerCase() == cleanFilter) {
            list.add(d);
          }
        } catch (e) {
          debugPrint('Error parsing ZkDeviceConfig in stream: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveDevice(ZkDeviceConfig device) async {
    if (!isAvailable) return;
    try {
      final code = device.companyCode.trim().toLowerCase();
      final docId = device.id.startsWith('${code}_') ? device.id : '${code}_${device.id}';
      await _firestore.collection('devices').doc(docId).set(device.toMap());
    } catch (e) {
      debugPrint('Error saving device: $e');
    }
  }

  Future<void> deleteDevice(String id, {String? companyCode}) async {
    if (!isAvailable) return;
    try {
      final code = companyCode?.trim().toLowerCase() ?? '';
      final docId = (code.isNotEmpty && !id.startsWith('${code}_')) ? '${code}_$id' : id;
      await _firestore.collection('devices').doc(docId).delete();
    } catch (e) {
      debugPrint('Error deleting device: $e');
    }
  }

  // --- Holiday CRUD (Tenant-isolated with Cache) ---
  Future<List<Holiday>> getHolidays({String? companyCode, bool forceRefresh = false}) async {
    if (!isAvailable) return [];
    final cleanFilter = companyCode?.trim().toLowerCase();
    final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
    if (!forceRefresh && _cachedHolidays.containsKey(cacheKey) && _cachedHolidays[cacheKey]!.isNotEmpty) {
      return List.unmodifiable(_cachedHolidays[cacheKey]!);
    }
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('holidays');
      if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
        query = query.where('companyCode', isEqualTo: cleanFilter);
      }
      QuerySnapshot<Map<String, dynamic>>? snapshot;
      if (!forceRefresh) {
        try {
          snapshot = await query.get(const GetOptions(source: Source.cache));
        } catch (_) {}
      }
      if (snapshot == null || snapshot.docs.isEmpty) {
        snapshot = await query.get();
      }
      final list = <Holiday>[];
      for (var doc in snapshot.docs) {
        try {
          final h = Holiday.fromMap(doc.data(), doc.id);
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || h.companyCode.toLowerCase() == cleanFilter) {
            list.add(h);
          }
        } catch (e) {
          debugPrint('Error parsing Holiday ${doc.id}: $e');
        }
      }
      _cachedHolidays[cacheKey] = list;
      return list;
    } catch (e) {
      debugPrint('Error getting holidays: $e');
      return _cachedHolidays[cacheKey] ?? [];
    }
  }

  Stream<List<Holiday>> streamHolidays({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    Query<Map<String, dynamic>> query = _firestore.collection('holidays');
    if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
      query = query.where('companyCode', isEqualTo: cleanFilter);
    }
    return query.snapshots().map((snapshot) {
      final list = <Holiday>[];
      for (var doc in snapshot.docs) {
        try {
          final h = Holiday.fromMap(doc.data(), doc.id);
          if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || h.companyCode.toLowerCase() == cleanFilter) {
            list.add(h);
          }
        } catch (e) {
          debugPrint('Error parsing Holiday ${doc.id}: $e');
        }
      }
      final cacheKey = (cleanFilter == null || cleanFilter.isEmpty) ? 'all' : cleanFilter;
      _cachedHolidays[cacheKey] = list;
      return list;
    });
  }

  Future<void> saveHoliday(Holiday holiday) async {
    if (!isAvailable) return;
    try {
      _cachedHolidays.clear();
      final code = holiday.companyCode.trim().toLowerCase();
      final docId = (code != 'amada' && !holiday.id.startsWith('${code}_'))
          ? '${code}_${holiday.id}'
          : holiday.id;
      await _firestore.collection('holidays').doc(docId).set(holiday.toMap());
    } catch (e) {
      debugPrint('Error saving holiday: $e');
    }
  }

  Future<void> deleteHoliday(String id) async {
    if (!isAvailable) return;
    try {
      _cachedHolidays.clear();
      await _firestore.collection('holidays').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting holiday: $e');
    }
  }

  // --- CompanyEmployee CRUD (Tenant-isolated) ---
  Future<List<CompanyEmployee>> getEmployees({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final cleanFilter = companyCode?.trim().toLowerCase();
      Query<Map<String, dynamic>> query = _firestore.collection('employees');
      if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
        query = query.where('companyCode', isEqualTo: cleanFilter);
      }
      final snapshot = await query.get();
      final list = <CompanyEmployee>[];
      for (var doc in snapshot.docs) {
        try {
          final emp = CompanyEmployee.fromMap(doc.data(), doc.id);
          final empCode = emp.companyCode.trim().toLowerCase();
          final matchesCompany = cleanFilter == null ||
              cleanFilter.isEmpty ||
              cleanFilter == 'all' ||
              empCode == cleanFilter ||
              (empCode.isEmpty && (
                  emp.id.toLowerCase().startsWith('${cleanFilter}_') ||
                  emp.email.toLowerCase().endsWith('@$cleanFilter.com')
              ));
          if (matchesCompany || emp.email == 'admin@company.com') {
            list.add(emp.companyCode.isEmpty && cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all'
                ? emp.copyWith(companyCode: cleanFilter)
                : emp);
          }
        } catch (e) {
          debugPrint('Error parsing CompanyEmployee ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting employees: $e');
      return [];
    }
  }

  Future<CompanyEmployee?> getEmployee(String employeeId) async {
    if (!isAvailable) return null;
    try {
      final cleanId = employeeId.trim();
      final doc = await _firestore.collection('employees').doc(cleanId).get();
      if (doc.exists && doc.data() != null) {
        return CompanyEmployee.fromMap(doc.data()!, doc.id);
      }
      final all = await getEmployees();
      return all.where((e) =>
          e.id.trim().toLowerCase() == cleanId.toLowerCase() ||
          e.email.trim().toLowerCase() == cleanId.toLowerCase()
      ).firstOrNull;
    } catch (e) {
      debugPrint('Error getting employee $employeeId: $e');
      return null;
    }
  }

  Stream<List<CompanyEmployee>> streamEmployees({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    Query<Map<String, dynamic>> query = _firestore.collection('employees');
    if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
      query = query.where('companyCode', isEqualTo: cleanFilter);
    }
    return query.snapshots().map((snapshot) {
      final list = <CompanyEmployee>[];
      for (var doc in snapshot.docs) {
        try {
          final emp = CompanyEmployee.fromMap(doc.data(), doc.id);
          final empCode = emp.companyCode.trim().toLowerCase();
          final matchesCompany = cleanFilter == null ||
              cleanFilter.isEmpty ||
              cleanFilter == 'all' ||
              empCode == cleanFilter ||
              (empCode.isEmpty && (
                  emp.id.toLowerCase().startsWith('${cleanFilter}_') ||
                  emp.email.toLowerCase().endsWith('@$cleanFilter.com')
              ));
          if (matchesCompany || emp.email == 'admin@company.com') {
            list.add(emp.companyCode.isEmpty && cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all'
                ? emp.copyWith(companyCode: cleanFilter)
                : emp);
          }
        } catch (e) {
          debugPrint('Error parsing CompanyEmployee ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveEmployee(CompanyEmployee employee) async {
    if (!isAvailable) return;
    try {
      final code = employee.companyCode.trim().toLowerCase();
      final docId = (code == 'amada' || (code.isNotEmpty && employee.id.startsWith('${code}_')) || employee.email == 'admin@company.com')
          ? employee.id
          : (code.isNotEmpty ? '${code}_${employee.id}' : employee.id);
      await _firestore
          .collection('employees')
          .doc(docId)
          .set(employee.toMap());
    } catch (e) {
      debugPrint('Error saving employee: $e');
    }
  }

  Future<void> deleteEmployee(String id, {String? companyCode, String? email}) async {
    if (!isAvailable) return;
    try {
      final cleanId = id.trim();
      final code = (companyCode ?? '').trim().toLowerCase();
      final cleanEmail = (email ?? '').trim().toLowerCase();

      // Collect all potential doc IDs for this employee
      final candidateDocIds = <String>{cleanId};
      if (code.isNotEmpty) {
        candidateDocIds.add('${code}_$cleanId');
      }
      if (cleanId.contains('_')) {
        candidateDocIds.add(cleanId.split('_').last);
      }

      // 1. Delete employee document(s) by ID from 'employees'
      for (final docId in candidateDocIds) {
        try {
          await _firestore.collection('employees').doc(docId).delete();
        } catch (_) {}
      }

      // 2. Query 'employees' by field 'id' == cleanId (or matching company)
      try {
        final querySnap = await _firestore
            .collection('employees')
            .where('id', isEqualTo: cleanId)
            .get();
        for (var doc in querySnap.docs) {
          final docData = doc.data();
          final docCode = (docData['companyCode'] ?? '').toString().trim().toLowerCase();
          if (code.isEmpty || docCode.isEmpty || docCode == code) {
            await doc.reference.delete();
          }
        }
      } catch (e) {
        debugPrint('Error deleting employees by id query: $e');
      }

      // Also query if stored with prefixed id
      if (code.isNotEmpty) {
        try {
          final querySnap = await _firestore
              .collection('employees')
              .where('id', isEqualTo: '${code}_$cleanId')
              .get();
          for (var doc in querySnap.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      // Query by email if available to catch custom ID documents
      if (cleanEmail.isNotEmpty) {
        try {
          final emailSnap = await _firestore
              .collection('employees')
              .where('email', isEqualTo: cleanEmail)
              .get();
          for (var doc in emailSnap.docs) {
            final docData = doc.data();
            final docCode = (docData['companyCode'] ?? '').toString().trim().toLowerCase();
            if (code.isEmpty || docCode.isEmpty || docCode == code) {
              await doc.reference.delete();
            }
          }
        } catch (e) {
          debugPrint('Error deleting employees by email query: $e');
        }
      }

      // 3. Delete Attendance Records and their subcollections
      for (final candidateId in candidateDocIds) {
        try {
          final recordsSnap = await _firestore
              .collection('attendance_records')
              .doc(candidateId)
              .collection('user_records')
              .get();
          for (var doc in recordsSnap.docs) {
            await doc.reference.delete();
          }
          await _firestore.collection('attendance_records').doc(candidateId).delete();
        } catch (_) {}
      }
      try {
        final groupSnap = await _firestore
            .collectionGroup('user_records')
            .where('employeeId', isEqualTo: cleanId)
            .get();
        for (var doc in groupSnap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
      if (code.isNotEmpty) {
        try {
          final groupSnap = await _firestore
              .collectionGroup('user_records')
              .where('employeeId', isEqualTo: '${code}_$cleanId')
              .get();
          for (var doc in groupSnap.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      // 4. Delete Requests and their subcollections
      for (final candidateId in candidateDocIds) {
        try {
          final reqsSnap = await _firestore
              .collection('requests')
              .doc(candidateId)
              .collection('user_requests')
              .get();
          for (var doc in reqsSnap.docs) {
            await doc.reference.delete();
          }
          await _firestore.collection('requests').doc(candidateId).delete();
        } catch (_) {}
      }
      try {
        final groupReqs = await _firestore
            .collectionGroup('user_requests')
            .where('employeeId', isEqualTo: cleanId)
            .get();
        for (var doc in groupReqs.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
      if (code.isNotEmpty) {
        try {
          final groupReqs = await _firestore
              .collectionGroup('user_requests')
              .where('employeeId', isEqualTo: '${code}_$cleanId')
              .get();
          for (var doc in groupReqs.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      // 5. Delete Payroll Adjustments
      for (final candidateId in candidateDocIds) {
        try {
          final adjSnap = await _firestore
              .collection('payroll_adjustments')
              .where('employeeId', isEqualTo: candidateId)
              .get();
          for (var doc in adjSnap.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      // 6. Delete Deleted Punches
      for (final candidateId in candidateDocIds) {
        try {
          final punchSnap = await _firestore
              .collection('deleted_punches')
              .where('employeeId', isEqualTo: candidateId)
              .get();
          for (var doc in punchSnap.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      // 7. Delete Chat Rooms & Messages
      try {
        final allRooms = await _firestore.collection('chat_rooms').get();
        for (var roomDoc in allRooms.docs) {
          final rId = roomDoc.id;
          bool matches = false;
          for (final candidateId in candidateDocIds) {
            if (rId.startsWith('${candidateId}_') ||
                rId.endsWith('_$candidateId') ||
                rId.contains('_${candidateId}_')) {
              matches = true;
              break;
            }
          }
          if (matches) {
            final msgs = await roomDoc.reference.collection('messages').get();
            for (var m in msgs.docs) {
              await m.reference.delete();
            }
            await roomDoc.reference.delete();
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error deleting employee $id: $e');
    }
  }

  /// Migrates all attendance records, requests, and adjustments from oldId to newId
  Future<void> migrateEmployeeId(String oldId, String newId) async {
    if (!isAvailable || oldId.trim() == newId.trim()) return;
    final cleanOld = oldId.trim();
    final cleanNew = newId.trim();

    try {
      // 1. Migrate Attendance Records
      final recordsSnap = await _firestore
          .collection('attendance_records')
          .doc(cleanOld)
          .collection('user_records')
          .get();

      for (var doc in recordsSnap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['employeeId'] = cleanNew;
        await _firestore
            .collection('attendance_records')
            .doc(cleanNew)
            .collection('user_records')
            .doc(doc.id)
            .set(data);
        await doc.reference.delete();
      }
      try {
        await _firestore.collection('attendance_records').doc(cleanOld).delete();
      } catch (_) {}

      // 2. Migrate Requests
      final requestsSnap = await _firestore
          .collection('requests')
          .doc(cleanOld)
          .collection('user_requests')
          .get();

      for (var doc in requestsSnap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['employeeId'] = cleanNew;
        await _firestore
            .collection('requests')
            .doc(cleanNew)
            .collection('user_requests')
            .doc(doc.id)
            .set(data);
        await doc.reference.delete();
      }
      try {
        await _firestore.collection('requests').doc(cleanOld).delete();
      } catch (_) {}

      // 3. Migrate Payroll Adjustments
      final adjSnap = await _firestore
          .collection('payroll_adjustments')
          .where('employeeId', isEqualTo: cleanOld)
          .get();

      for (var doc in adjSnap.docs) {
        await doc.reference.update({'employeeId': cleanNew});
      }
    } catch (e) {
      debugPrint('Error migrating employee data from $cleanOld to $cleanNew: $e');
    }
  }

  // Helper to get company-scoped employee doc ID in Firestore
  String _getScopedEmployeeDocId(String employeeId, {String? companyCode}) {
    final cleanId = employeeId.trim();
    final comp = (companyCode ?? '').trim().toLowerCase();
    if (comp.isEmpty || comp == 'amada' || comp == 'all') {
      return cleanId;
    }
    if (cleanId.toLowerCase().startsWith('${comp}_')) {
      return cleanId;
    }
    return '${comp}_$cleanId';
  }

  // --- AttendanceRecord CRUD ---
  Future<List<AttendanceRecord>> getUserRecords(String employeeId, {String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final trimmedId = employeeId.trim();
      final comp = (companyCode ?? '').trim().toLowerCase();
      final scopedId = _getScopedEmployeeDocId(trimmedId, companyCode: comp);
      final candidateDocIds = <String>{};
      if (scopedId != trimmedId) candidateDocIds.add(scopedId);
      candidateDocIds.add(trimmedId);

      QuerySnapshot<Map<String, dynamic>>? snapshot;
      for (final docId in candidateDocIds) {
        try {
          final s = await _firestore
              .collection('attendance_records')
              .doc(docId)
              .collection('user_records')
              .get();
          if (s.docs.isNotEmpty) {
            snapshot = s;
            break;
          }
        } catch (e) {
          debugPrint('Error getting user_records for $docId: $e');
        }
      }

      // If direct doc lookup is empty, try case-insensitive doc match in attendance_records
      if (snapshot == null || snapshot.docs.isEmpty) {
        try {
          final parentSnap = await _firestore.collection('attendance_records').get();
          for (var pDoc in parentSnap.docs) {
            final pIdLower = pDoc.id.toLowerCase();
            if (candidateDocIds.any((cid) => cid.toLowerCase() == pIdLower)) {
              snapshot = await pDoc.reference.collection('user_records').get();
              if (snapshot.docs.isNotEmpty) break;
            }
          }
        } catch (_) {}
      }

      final list = <AttendanceRecord>[];
      if (snapshot != null) {
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final recComp = (data['companyCode'] ?? comp).toString().trim().toLowerCase();
            if (comp.isNotEmpty && comp != 'all' && recComp.isNotEmpty && recComp != comp) {
              continue;
            }
            list.add(AttendanceRecord.fromMap(data, trimmedId, recComp.isNotEmpty ? recComp : null));
          } catch (e) {
            debugPrint('Error parsing AttendanceRecord ${doc.id}: $e');
          }
        }
      }
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    } catch (e) {
      debugPrint('Error getting user records: $e');
      return [];
    }
  }

  Stream<List<AttendanceRecord>> streamUserRecords(String employeeId, {String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final trimmedId = employeeId.trim();
    final comp = (companyCode ?? '').trim().toLowerCase();
    final scopedId = _getScopedEmployeeDocId(trimmedId, companyCode: comp);
    return _firestore
        .collection('attendance_records')
        .doc(scopedId)
        .collection('user_records')
        .snapshots()
        .map((snapshot) {
      final list = <AttendanceRecord>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final recComp = (data['companyCode'] ?? comp).toString().trim().toLowerCase();
          if (comp.isNotEmpty && comp != 'all' && recComp.isNotEmpty && recComp != comp) {
            continue;
          }
          list.add(AttendanceRecord.fromMap(doc.data(), trimmedId, recComp.isNotEmpty ? recComp : null));
        } catch (e) {
          debugPrint('Error parsing AttendanceRecord ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    }).handleError((e) {
      debugPrint('Error in streamUserRecords for $scopedId: $e');
      return <AttendanceRecord>[];
    });
  }

  Stream<List<AttendanceRecord>> streamAllRecords({DateTime? since, String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final comp = (companyCode ?? '').trim().toLowerCase();

    List<AttendanceRecord> parseDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
      final list = <AttendanceRecord>[];
      for (var doc in docs) {
        try {
          final data = doc.data();
          final parentDocId = doc.reference.parent.parent?.id;
          String? empId = data['employeeId']?.toString() ?? parentDocId;
          String? c = data['companyCode']?.toString();
          if ((c == null || c.isEmpty) && parentDocId != null && parentDocId.contains('_')) {
            final prefix = parentDocId.split('_').first.toLowerCase();
            if (prefix.isNotEmpty && prefix != 'admin' && prefix != 'emp' && prefix != 'employee') {
              c = prefix;
              if (empId == parentDocId) {
                empId = parentDocId.substring(prefix.length + 1);
              }
            }
          }
          final rec = AttendanceRecord.fromMap(data, empId, c);
          if (since == null || !rec.checkIn.isBefore(since)) {
            if (comp.isEmpty || comp == 'all') {
              list.add(rec);
            } else if (rec.companyCode != null && rec.companyCode!.trim().toLowerCase() == comp) {
              list.add(rec);
            } else if ((rec.companyCode == null || rec.companyCode!.trim().isEmpty) && comp == 'amada') {
              // Legacy records without companyCode strictly belong to root company amada
              list.add(rec);
            }
          }
        } catch (e) {
          debugPrint('Error parsing collectionGroup AttendanceRecord ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    }

    try {
      Query<Map<String, dynamic>> query = _firestore.collectionGroup('user_records');
      bool hasServerFilters = false;
      if (comp.isNotEmpty && comp != 'all') {
        query = query.where('companyCode', isEqualTo: comp);
        hasServerFilters = true;
      }
      if (since != null) {
        query = query.where('checkIn', isGreaterThanOrEqualTo: since.toIso8601String());
        hasServerFilters = true;
      }

      if (!hasServerFilters) {
        return _firestore.collectionGroup('user_records').snapshots().map((snapshot) => parseDocs(snapshot.docs));
      }

      late StreamController<List<AttendanceRecord>> controller;
      StreamSubscription? sub;
      bool hasFallenBack = false;

      void fallbackToBroadQuery() {
        if (hasFallenBack) return;
        hasFallenBack = true;
        sub?.cancel();
        debugPrint('Falling back to broad collectionGroup query while index is building...');
        sub = _firestore.collectionGroup('user_records').snapshots().listen(
          (snapshot) {
            if (!controller.isClosed) controller.add(parseDocs(snapshot.docs));
          },
          onError: (err) {
            debugPrint('collectionGroup fallback stream error: $err');
            if (!controller.isClosed) controller.add([]);
          },
        );
      }

      controller = StreamController<List<AttendanceRecord>>.broadcast(
        onListen: () {
          sub = query.snapshots().listen(
            (snapshot) {
              if (!controller.isClosed) controller.add(parseDocs(snapshot.docs));
            },
            onError: (err) {
              debugPrint('Filtered user_records query error (index building?): $err');
              fallbackToBroadQuery();
            },
          );
        },
        onCancel: () {
          sub?.cancel();
        },
      );

      return controller.stream;
    } catch (e) {
      debugPrint('Error starting streamAllRecords: $e');
      return _firestore.collectionGroup('user_records').snapshots().map((s) => parseDocs(s.docs));
    }
  }

  /// On-demand historical records fetch for custom report date ranges
  Future<List<AttendanceRecord>> getRecordsForRange({
    required DateTime from,
    required DateTime to,
    String? companyCode,
  }) async {
    if (!isAvailable) return [];
    final comp = (companyCode ?? '').trim().toLowerCase();
    try {
      Query<Map<String, dynamic>> query = _firestore.collectionGroup('user_records');
      if (comp.isNotEmpty && comp != 'all') {
        query = query.where('companyCode', isEqualTo: comp);
      }
      query = query
          .where('checkIn', isGreaterThanOrEqualTo: from.toIso8601String())
          .where('checkIn', isLessThanOrEqualTo: to.toIso8601String());

      final snapshot = await query.get();
      final list = <AttendanceRecord>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final parentDocId = doc.reference.parent.parent?.id;
          String? empId = data['employeeId']?.toString() ?? parentDocId;
          String? c = data['companyCode']?.toString();
          if ((c == null || c.isEmpty) && parentDocId != null && parentDocId.contains('_')) {
            final prefix = parentDocId.split('_').first.toLowerCase();
            if (prefix.isNotEmpty && prefix != 'admin' && prefix != 'emp' && prefix != 'employee') {
              c = prefix;
              if (empId == parentDocId) {
                empId = parentDocId.substring(prefix.length + 1);
              }
            }
          }
          final rec = AttendanceRecord.fromMap(data, empId, c);
          if (comp.isEmpty || comp == 'all') {
            list.add(rec);
          } else if (rec.companyCode != null && rec.companyCode!.trim().toLowerCase() == comp) {
            list.add(rec);
          } else if ((rec.companyCode == null || rec.companyCode!.trim().isEmpty) && comp == 'amada') {
            list.add(rec);
          }
        } catch (_) {}
      }
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    } catch (e) {
      debugPrint('Optimized getRecordsForRange failed, trying broader fetch: $e');
      try {
        final snapshot = await _firestore.collectionGroup('user_records').get();
        final list = <AttendanceRecord>[];
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final parentDocId = doc.reference.parent.parent?.id;
            String? empId = data['employeeId']?.toString() ?? parentDocId;
            String? c = data['companyCode']?.toString();
            if ((c == null || c.isEmpty) && parentDocId != null && parentDocId.contains('_')) {
              final prefix = parentDocId.split('_').first.toLowerCase();
              if (prefix.isNotEmpty && prefix != 'admin' && prefix != 'emp' && prefix != 'employee') {
                c = prefix;
                if (empId == parentDocId) {
                  empId = parentDocId.substring(prefix.length + 1);
                }
              }
            }
            final rec = AttendanceRecord.fromMap(data, empId, c);
            if (!rec.checkIn.isBefore(from) && !rec.checkIn.isAfter(to)) {
              if (comp.isEmpty || comp == 'all' || rec.companyCode == null || rec.companyCode!.trim().toLowerCase() == comp) {
                list.add(rec);
              }
            }
          } catch (_) {}
        }
        list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
        return list;
      } catch (err2) {
        debugPrint('Error getting records for range: $err2');
        return [];
      }
    }
  }

  Future<void> saveRecord(String employeeId, AttendanceRecord record, {String? companyCode}) async {
    if (!isAvailable) return;
    try {
      // Use CheckIn timestamp as document ID to uniquely identify day session
      final docId = record.checkIn.toIso8601String().replaceAll(':', '-');
      final comp = (companyCode ?? record.companyCode ?? '').trim().toLowerCase();
      final scopedDocId = _getScopedEmployeeDocId(employeeId, companyCode: comp);
      final data = record.toMap();
      data['employeeId'] = employeeId;
      if (comp.isNotEmpty && comp != 'all') {
        data['companyCode'] = comp;
      }
      await _firestore
          .collection('attendance_records')
          .doc(scopedDocId)
          .collection('user_records')
          .doc(docId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving attendance record: $e');
      rethrow;
    }
  }

  Future<void> deleteRecord(String employeeId, AttendanceRecord record, {String? companyCode}) async {
    if (!isAvailable) return;
    try {
      final docId = record.checkIn.toIso8601String().replaceAll(':', '-');
      final comp = (companyCode ?? record.companyCode ?? '').trim().toLowerCase();
      final scopedDocId = _getScopedEmployeeDocId(employeeId, companyCode: comp);
      await _firestore
          .collection('attendance_records')
          .doc(scopedDocId)
          .collection('user_records')
          .doc(docId)
          .delete();
      if (scopedDocId != employeeId) {
        try {
          await _firestore
              .collection('attendance_records')
              .doc(employeeId)
              .collection('user_records')
              .doc(docId)
              .delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error deleting attendance record: $e');
    }
  }

  /// Clears only the checkOut timestamp from a record in Firestore, leaving checkIn intact
  Future<void> clearRecordCheckOut(String employeeId, AttendanceRecord record, {String? companyCode}) async {
    if (!isAvailable) return;
    try {
      final docId = record.checkIn.toIso8601String().replaceAll(':', '-');
      final comp = (companyCode ?? record.companyCode ?? '').trim().toLowerCase();
      final scopedDocId = _getScopedEmployeeDocId(employeeId, companyCode: comp);
      await _firestore
          .collection('attendance_records')
          .doc(scopedDocId)
          .collection('user_records')
          .doc(docId)
          .update({'checkOut': FieldValue.delete()});
      if (scopedDocId != employeeId) {
        try {
          await _firestore
              .collection('attendance_records')
              .doc(employeeId)
              .collection('user_records')
              .doc(docId)
              .update({'checkOut': FieldValue.delete()});
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error clearing attendance record checkOut: $e');
      // Fallback: saveRecord with cleared checkOut
      try {
        final cleared = record.copyWith(clearCheckOut: true);
        await saveRecord(employeeId, cleared, companyCode: companyCode);
      } catch (_) {}
    }
  }

  // --- Deleted Punches CRUD ---
  Future<List<DeletedPunch>> getDeletedPunches() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('deleted_punches').get();
      final list = <DeletedPunch>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(DeletedPunch.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing DeletedPunch ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return list;
    } catch (e) {
      debugPrint('Error getting deleted punches: $e');
      return [];
    }
  }

  Stream<List<DeletedPunch>> streamDeletedPunches({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('deleted_punches');
      if (cleanFilter != null && cleanFilter.isNotEmpty && cleanFilter != 'all') {
        query = query.where('companyCode', isEqualTo: cleanFilter);
      }
      return query
          .snapshots()
          .map((snapshot) {
        final list = <DeletedPunch>[];
        for (var doc in snapshot.docs) {
          try {
            final p = DeletedPunch.fromMap(doc.data(), doc.id);
            if (cleanFilter == null || cleanFilter.isEmpty || cleanFilter == 'all' || (p.companyCode != null && p.companyCode!.toLowerCase() == cleanFilter)) {
              list.add(p);
            }
          } catch (e) {
            debugPrint('Error parsing DeletedPunch ${doc.id}: $e');
          }
        }
        list.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
        return list;
      }).handleError((e) {
        debugPrint('Error streaming deleted punches: $e');
        return <DeletedPunch>[];
      });
    } catch (e) {
      debugPrint('Error starting streamDeletedPunches: $e');
      return Stream.value([]);
    }
  }

  Future<void> saveDeletedPunch(DeletedPunch punch) async {
    if (!isAvailable) return;
    try {
      await _firestore
          .collection('deleted_punches')
          .doc(punch.id)
          .set(punch.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving deleted punch: $e');
      rethrow;
    }
  }

  Future<void> removeDeletedPunch(String punchId) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('deleted_punches').doc(punchId).delete();
    } catch (e) {
      debugPrint('Error removing deleted punch: $e');
    }
  }

  // --- Request CRUD ---
  Future<List<Request>> getUserRequests(String employeeId, {String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final trimmedId = employeeId.trim();
      final comp = (companyCode ?? '').trim().toLowerCase();
      final scopedId = _getScopedEmployeeDocId(trimmedId, companyCode: comp);
      final candidateDocIds = <String>{};
      if (scopedId != trimmedId) candidateDocIds.add(scopedId);
      candidateDocIds.add(trimmedId);

      QuerySnapshot<Map<String, dynamic>>? snapshot;
      for (final docId in candidateDocIds) {
        try {
          final s = await _firestore
              .collection('requests')
              .doc(docId)
              .collection('user_requests')
              .get();
          if (s.docs.isNotEmpty) {
            snapshot = s;
            break;
          }
        } catch (e) {
          debugPrint('Error getting user_requests for $docId: $e');
        }
      }

      if (snapshot == null || snapshot.docs.isEmpty) {
        try {
          final parentSnap = await _firestore.collection('requests').get();
          for (var pDoc in parentSnap.docs) {
            final pIdLower = pDoc.id.toLowerCase();
            if (candidateDocIds.any((cid) => cid.toLowerCase() == pIdLower)) {
              snapshot = await pDoc.reference.collection('user_requests').get();
              if (snapshot.docs.isNotEmpty) break;
            }
          }
        } catch (_) {}
      }

      if (snapshot == null) return [];

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final reqComp = (data['companyCode'] ?? comp).toString().trim().toLowerCase();
        final req = Request.fromMap(data, doc.id);
        return req.copyWith(
          employeeId: req.employeeId ?? trimmedId,
          companyCode: reqComp.isNotEmpty ? reqComp : req.companyCode,
          overrideTargetShiftId: false,
        );
      }).where((r) {
        if (comp.isNotEmpty && comp != 'all' && r.companyCode != null && r.companyCode!.isNotEmpty) {
          return r.companyCode!.toLowerCase() == comp;
        }
        return true;
      }).toList();
    } catch (e) {
      debugPrint('Error getting user requests: $e');
      return [];
    }
  }

  Stream<List<Request>> streamUserRequests(String employeeId, {String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final trimmedId = employeeId.trim();
    final comp = (companyCode ?? '').trim().toLowerCase();
    final scopedId = _getScopedEmployeeDocId(trimmedId, companyCode: comp);
    return _firestore
        .collection('requests')
        .doc(scopedId)
        .collection('user_requests')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final reqComp = (data['companyCode'] ?? comp).toString().trim().toLowerCase();
        final req = Request.fromMap(data, doc.id);
        return req.copyWith(
          employeeId: req.employeeId ?? trimmedId,
          companyCode: reqComp.isNotEmpty ? reqComp : req.companyCode,
          overrideTargetShiftId: false,
        );
      }).where((r) {
        if (comp.isNotEmpty && comp != 'all' && r.companyCode != null && r.companyCode!.isNotEmpty) {
          return r.companyCode!.toLowerCase() == comp;
        }
        return true;
      }).toList();
    });
  }

  Future<List<Request>> getAllRequests() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collectionGroup('user_requests').get();
      final list = <Request>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final parentDocId = doc.reference.parent.parent?.id;
          String? empId = data['employeeId'];
          if (empId == null || empId.isEmpty) {
            empId = parentDocId;
          }
          String? comp = data['companyCode'];
          if ((comp == null || comp.isEmpty) && parentDocId != null && parentDocId.contains('_')) {
            final prefix = parentDocId.split('_').first.toLowerCase();
            if (prefix.isNotEmpty && prefix != 'admin' && prefix != 'emp' && prefix != 'employee') {
              comp = prefix;
              if (empId == parentDocId) {
                empId = parentDocId.substring(prefix.length + 1);
              }
            }
          }
          final req = Request.fromMap(data, doc.id);
          list.add(req.copyWith(
            employeeId: empId ?? req.employeeId,
            companyCode: comp ?? req.companyCode,
            overrideTargetShiftId: false,
          ));
        } catch (e) {
          debugPrint('Error parsing request doc ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting all requests: $e');
      return [];
    }
  }

  Stream<List<Request>> streamAllRequests({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final comp = (companyCode ?? '').trim().toLowerCase();
    return _firestore.collectionGroup('user_requests').snapshots().map((snapshot) {
      final list = <Request>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final parentDocId = doc.reference.parent.parent?.id;
          String? empId = data['employeeId'];
          if (empId == null || empId.isEmpty) {
            empId = parentDocId;
          }
          String? c = data['companyCode'];
          if ((c == null || c.isEmpty) && parentDocId != null && parentDocId.contains('_')) {
            final prefix = parentDocId.split('_').first.toLowerCase();
            if (prefix.isNotEmpty && prefix != 'admin' && prefix != 'emp' && prefix != 'employee') {
              c = prefix;
              if (empId == parentDocId) {
                empId = parentDocId.substring(prefix.length + 1);
              }
            }
          }
          if (comp.isNotEmpty && comp != 'all' && c != null && c.isNotEmpty && c.toLowerCase() != comp) {
            continue;
          }
          final req = Request.fromMap(data, doc.id);
          list.add(req.copyWith(
            employeeId: empId ?? req.employeeId,
            companyCode: c ?? req.companyCode,
            overrideTargetShiftId: false,
          ));
        } catch (e) {
          debugPrint('Error parsing request doc ${doc.id} in stream: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveRequest(String employeeId, Request request, {String? companyCode}) async {
    if (!isAvailable) return;
    try {
      final comp = (companyCode ?? request.companyCode ?? '').trim().toLowerCase();
      final scopedDocId = _getScopedEmployeeDocId(employeeId, companyCode: comp);
      final data = request.toMap();
      data['employeeId'] = employeeId;
      if (comp.isNotEmpty && comp != 'all') {
        data['companyCode'] = comp;
      }
      await _firestore
          .collection('requests')
          .doc(scopedDocId)
          .collection('user_requests')
          .doc(request.id)
          .set(data);
    } catch (e) {
      debugPrint('Error saving request: $e');
    }
  }

  Future<void> deleteRequest(String employeeId, String requestId, {String? companyCode}) async {
    if (!isAvailable) return;
    try {
      final comp = (companyCode ?? '').trim().toLowerCase();
      final scopedDocId = _getScopedEmployeeDocId(employeeId, companyCode: comp);
      await _firestore
          .collection('requests')
          .doc(scopedDocId)
          .collection('user_requests')
          .doc(requestId)
          .delete();
      if (scopedDocId != employeeId) {
        try {
          await _firestore
              .collection('requests')
              .doc(employeeId)
              .collection('user_requests')
              .doc(requestId)
              .delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error deleting request: $e');
    }
  }

  // --- Purge Legacy Mock/Dummy Requests ---
  Future<int> purgeLegacyMockRequests() async {
    if (!isAvailable) return 0;
    try {
      final snap = await _firestore.collectionGroup('user_requests').get();
      final batch = _firestore.batch();
      int deleteCount = 0;

      for (var doc in snap.docs) {
        final id = doc.id.trim().toLowerCase();
        final data = doc.data();
        final type = data['type']?.toString().trim() ?? '';
        final date = data['date']?.toString().trim() ?? '';

        final isMockId = id == 'req_1' ||
            id == 'req_2' ||
            id == 'req_3' ||
            id == 'req_4' ||
            (id.startsWith('req_') && id.length <= 8);

        final isMockContent = (date == 'May 14, 2026' && type == 'Sick Leave') ||
            (date == 'June 15 - June 18, 2026' && type == 'Annual Leave') ||
            (date == 'May 28, 2026' && type == 'Overtime Approval') ||
            (date == 'May 08, 2026' && type == 'Forgot to Clock Out');

        if (isMockId || isMockContent) {
          batch.delete(doc.reference);
          deleteCount++;
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
        debugPrint('Successfully purged $deleteCount legacy mock requests from Firestore.');
      }
      return deleteCount;
    } catch (e) {
      debugPrint('Error purging legacy mock requests: $e');
      return 0;
    }
  }

  // --- Database Initialization Seeding ---
  Future<void> seedDefaultMockData({
    required List<OrgStructure> structures,
    required List<WorkShift> shifts,
    required List<EmployeeGroup> groups,
    required List<CompanyEmployee> employees,
    required List<AttendanceRecord> userRecords,
    required String testUserId,
    required List<Request> userRequests,
    List<WorkLocation>? locations,
  }) async {
    if (!isAvailable) return;

    try {
      final snaps = await Future.wait([
        _firestore.collection('structures').limit(1).get(),
        _firestore.collection('shifts').limit(1).get(),
        _firestore.collection('groups').limit(1).get(),
        _firestore.collection('employees').limit(1).get(),
        _firestore.collection('attendance_records').doc(testUserId).collection('user_records').limit(1).get(),
        _firestore.collection('requests').doc(testUserId).collection('user_requests').limit(1).get(),
        _firestore.collection('locations').limit(1).get(),
      ]);

      final structSnap = snaps[0];
      final shiftSnap = snaps[1];
      final groupSnap = snaps[2];
      final empSnap = snaps[3];
      final recordSnap = snaps[4];
      final reqSnap = snaps[5];
      final locationSnap = snaps[6];

      // 1. Seed Structures
      if (structSnap.docs.isEmpty) {
        debugPrint('Seeding structures in Firestore...');
        for (var s in structures) {
          await saveStructure(s);
        }
      }

      // 2. Seed Shifts
      if (shiftSnap.docs.isEmpty) {
        debugPrint('Seeding shifts in Firestore...');
        for (var s in shifts) {
          await saveShift(s);
        }
      }

      // 3. Seed Groups
      if (groupSnap.docs.isEmpty) {
        debugPrint('Seeding groups in Firestore...');
        for (var g in groups) {
          await saveGroup(g);
        }
      }

      // 4. Seed Employees
      if (empSnap.docs.isEmpty) {
        debugPrint('Seeding employees in Firestore...');
        for (var e in employees) {
          await saveEmployee(e);
        }
      }

      // 5. Seed Attendance Records for testUserId
      if (recordSnap.docs.isEmpty && userRecords.isNotEmpty) {
        debugPrint(
          'Seeding attendance records for $testUserId in Firestore...',
        );
        for (var r in userRecords) {
          await saveRecord(testUserId, r);
        }
      }

      // 6. Seed Requests for testUserId (only if userRequests provided and non-empty)
      if (reqSnap.docs.isEmpty && userRequests.isNotEmpty) {
        debugPrint('Seeding requests for $testUserId in Firestore...');
        for (var req in userRequests) {
          await saveRequest(testUserId, req);
        }
      }

      // 7. Seed Locations
      if (locationSnap.docs.isEmpty && locations != null) {
        debugPrint('Seeding locations in Firestore...');
        for (var l in locations) {
          await saveLocation(l);
        }
      }
    } catch (e) {
      debugPrint('Error during Firestore database seeding: $e');
    }
  }

  // --- Chat Message CRUD ---
  Future<List<ChatMessage>> getChatMessages(String userA, String userB) async {
    if (!isAvailable) return [];
    try {
      final roomId = userA.compareTo(userB) < 0
          ? '${userA}_$userB'
          : '${userB}_$userA';
      final snapshot = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();
      final list = <ChatMessage>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(ChatMessage.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing ChatMessage ${doc.id}: $e');
        }
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    } catch (e) {
      debugPrint('Error getting chat messages: $e');
      return [];
    }
  }

  Stream<List<ChatMessage>> streamChatMessages(String userA, String userB) {
    if (!isAvailable) return Stream.value([]);
    final roomId = userA.compareTo(userB) < 0
        ? '${userA}_$userB'
        : '${userB}_$userA';
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          final list = <ChatMessage>[];
          for (var doc in snapshot.docs) {
            try {
              list.add(ChatMessage.fromMap(doc.data(), doc.id));
            } catch (e) {
              debugPrint('Error parsing ChatMessage in stream ${doc.id}: $e');
            }
          }
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return list;
        });
  }

  Future<List<String>> getUserChatContactIds(String userId) async {
    if (!isAvailable) return [];
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: cleanId)
          .get();
      final otherIds = <String>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participants = data['participants'];
        if (participants is List) {
          for (var p in participants) {
            final strP = p.toString().trim();
            if (strP.isNotEmpty && strP != cleanId && !otherIds.contains(strP)) {
              otherIds.add(strP);
            }
          }
        }
      }
      return otherIds;
    } catch (e) {
      debugPrint('Error getting user chat contact IDs: $e');
      return [];
    }
  }

  Stream<List<String>> streamUserChatContactIds(String userId) {
    if (!isAvailable) return Stream.value([]);
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: cleanId)
        .snapshots()
        .map((snapshot) {
          final otherIds = <String>[];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final participants = data['participants'];
            if (participants is List) {
              for (var p in participants) {
                final strP = p.toString().trim();
                if (strP.isNotEmpty && strP != cleanId && !otherIds.contains(strP)) {
                  otherIds.add(strP);
                }
              }
            }
          }
          return otherIds;
        });
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    if (!isAvailable) return;
    try {
      final userA = message.senderId;
      final userB = message.receiverId;
      final roomId = userA.compareTo(userB) < 0
          ? '${userA}_$userB'
          : '${userB}_$userA';
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(message.id)
          .set(message.toMap());

      final roomData = <String, dynamic>{
        'roomId': roomId,
        'userA': userA.compareTo(userB) < 0 ? userA : userB,
        'userB': userA.compareTo(userB) < 0 ? userB : userA,
        'participants': [userA, userB],
        'lastMessage': message.text,
        'lastTimestamp': message.timestamp.toUtc().toIso8601String(),
      };
      if (message.companyCode != null && message.companyCode!.isNotEmpty) {
        roomData['companyCode'] = message.companyCode;
      }

      await _firestore.collection('chat_rooms').doc(roomId).set(
        roomData,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error saving chat message: $e');
    }
  }

  // --- Company Profile ---
  Future<CompanyProfile?> getCompanyProfile() async {
    if (!isAvailable) return null;
    try {
      final doc = await _firestore.collection('settings').doc('company_profile').get();
      if (doc.exists && doc.data() != null) {
        return CompanyProfile.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('Error getting company profile: $e');
    }
    return null;
  }

  Stream<CompanyProfile?> streamCompanyProfile() {
    if (!isAvailable) return Stream.value(null);
    return _firestore.collection('settings').doc('company_profile').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return CompanyProfile.fromMap(doc.data()!);
      }
      return null;
    });
  }

    Future<void> saveCompanyProfile(CompanyProfile profile) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('settings').doc('company_profile').set(profile.toMap());
    } catch (e) {
      debugPrint('Error saving company profile: $e');
    }
  }

  // --- Payroll Adjustments (Additions & Deductions) CRUD ---
  Future<List<PayrollAdjustment>> getPayrollAdjustments() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('payroll_adjustments').get();
      final list = <PayrollAdjustment>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(PayrollAdjustment.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing PayrollAdjustment ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting payroll adjustments: $e');
      return [];
    }
  }

  Stream<List<PayrollAdjustment>> streamPayrollAdjustments() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collection('payroll_adjustments').snapshots().map((snapshot) {
      final list = <PayrollAdjustment>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(PayrollAdjustment.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing PayrollAdjustment ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  Future<void> savePayrollAdjustment(PayrollAdjustment adjustment) async {
    if (!isAvailable) return;
    try {
      await _firestore
          .collection('payroll_adjustments')
          .doc(adjustment.id)
          .set(adjustment.toMap());
    } catch (e) {
      debugPrint('Error saving payroll adjustment: $e');
    }
  }

  Future<void> deletePayrollAdjustment(String id) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('payroll_adjustments').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting payroll adjustment: $e');
    }
  }

  // --- Payroll Closures CRUD (Tenant-isolated) ---
  Future<List<PayrollMonthClosure>> getPayrollClosures({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('payroll_closures').get();
      final list = <PayrollMonthClosure>[];
      final cleanFilter = companyCode?.trim().toLowerCase();
      for (var doc in snapshot.docs) {
        try {
          final closure = PayrollMonthClosure.fromMap(doc.data(), doc.id);
          if (cleanFilter == null ||
              cleanFilter.isEmpty ||
              cleanFilter == 'all' ||
              closure.companyCode.toLowerCase() == cleanFilter) {
            list.add(closure);
          }
        } catch (e) {
          debugPrint('Error parsing PayrollMonthClosure ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting payroll closures: $e');
      return [];
    }
  }

  Stream<List<PayrollMonthClosure>> streamPayrollClosures({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    return _firestore.collection('payroll_closures').snapshots().map((snapshot) {
      final list = <PayrollMonthClosure>[];
      for (var doc in snapshot.docs) {
        try {
          final closure = PayrollMonthClosure.fromMap(doc.data(), doc.id);
          if (cleanFilter == null ||
              cleanFilter.isEmpty ||
              cleanFilter == 'all' ||
              closure.companyCode.toLowerCase() == cleanFilter) {
            list.add(closure);
          }
        } catch (e) {
          debugPrint('Error parsing PayrollMonthClosure ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  Future<void> savePayrollClosure(PayrollMonthClosure closure) async {
    if (!isAvailable) return;
    try {
      final docId = closure.id.contains('_')
          ? closure.id
          : '${closure.companyCode.toLowerCase()}_${closure.yearMonth}';
      await _firestore
          .collection('payroll_closures')
          .doc(docId)
          .set(closure.toMap());
    } catch (e) {
      debugPrint('Error saving payroll closure: $e');
    }
  }

  // --- Company License & Multi-Tenancy SaaS ---
  Future<CompanyLicense?> getCompanyLicense(String companyCode) async {
    if (!isAvailable) return null;
    final cleanCode = companyCode.trim().toLowerCase();
    if (cleanCode.isEmpty) return null;
    try {
      // 1. Try direct doc lookup by companyCode
      final doc = await _firestore.collection('companies').doc(cleanCode).get();
      if (doc.exists && doc.data() != null) {
        return CompanyLicense.fromMap(doc.data()!, doc.id);
      }
      // 2. Fallback query where companyCode == cleanCode
      final query = await _firestore
          .collection('companies')
          .where('companyCode', isEqualTo: cleanCode)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return CompanyLicense.fromMap(query.docs.first.data(), query.docs.first.id);
      }
    } catch (e) {
      debugPrint('Error getting company license: $e');
    }
    return null;
  }

  Stream<CompanyLicense?> streamCompanyLicense(String companyCode) {
    if (!isAvailable) return Stream.value(null);
    final cleanCode = companyCode.trim().toLowerCase();
    if (cleanCode.isEmpty) return Stream.value(null);
    return _firestore.collection('companies').doc(cleanCode).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return CompanyLicense.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<void> saveCompanyLicense(CompanyLicense license) async {
    if (!isAvailable) return;
    try {
      final docId = license.companyCode.trim().toLowerCase();
      await _firestore
          .collection('companies')
          .doc(docId)
          .set(license.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving company license: $e');
    }
  }

  Future<List<CompanyLicense>> getAllCompanyLicenses() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('companies').get();
      final list = <CompanyLicense>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(CompanyLicense.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing CompanyLicense ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting all company licenses: $e');
      return [];
    }
  }

  Stream<List<CompanyLicense>> streamCompanyLicenses() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collection('companies').snapshots().map((snapshot) {
      final list = <CompanyLicense>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(CompanyLicense.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing CompanyLicense in stream: $e');
        }
      }
      return list;
    });
  }

  Future<void> deleteCompanyLicense(String companyId) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('companies').doc(companyId).delete();
    } catch (e) {
      debugPrint('Error deleting company license: $e');
    }
  }

  /// Completely and permanently purges a company and ALL associated data from Firestore:
  /// - companies/{companyCode}
  /// - employees
  /// - shifts
  /// - structures
  /// - groups
  /// - locations
  /// - devices
  /// - holidays
  /// - deleted_punches
  /// - attendance_records (including user_records subcollection)
  /// - requests (including user_requests subcollection)
  /// - payroll_closures
  Future<void> purgeCompanyAndAllData(String companyCode) async {
    if (!isAvailable) return;
    final code = companyCode.trim().toLowerCase();
    if (code.isEmpty || code == 'amada') {
      debugPrint('Cannot purge root/master company "amada"');
      return;
    }

    try {
      // 1. Delete company document in companies collection
      try {
        await _firestore.collection('companies').doc(code).delete();
      } catch (e) {
        debugPrint('Error deleting company doc $code: $e');
      }

      // Helper function to safely delete documents matching companyCode or prefixed with code_
      Future<void> deleteFromCollection(String colName) async {
        try {
          final snap1 = await _firestore.collection(colName).where('companyCode', isEqualTo: code).get();
          for (var doc in snap1.docs) {
            try {
              await doc.reference.delete();
            } catch (_) {}
          }
          final snapAll = await _firestore.collection(colName).get();
          for (var doc in snapAll.docs) {
            final idLower = doc.id.toLowerCase();
            final docComp = (doc.data()['companyCode'] ?? '').toString().toLowerCase();
            if (idLower.startsWith('${code}_') || docComp == code) {
              try {
                await doc.reference.delete();
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('Error purging from collection $colName for $code: $e');
        }
      }

      // 2. Delete static metadata collections
      await deleteFromCollection('structures');
      await deleteFromCollection('shifts');
      await deleteFromCollection('groups');
      await deleteFromCollection('locations');
      await deleteFromCollection('devices');
      await deleteFromCollection('holidays');
      await deleteFromCollection('deleted_punches');
      await deleteFromCollection('payroll_closures');

      // 3. Delete attendance_records and their user_records subcollections
      try {
        final attSnap = await _firestore.collection('attendance_records').get();
        for (var doc in attSnap.docs) {
          final idLower = doc.id.toLowerCase();
          final data = doc.data();
          final docComp = (data['companyCode'] ?? '').toString().toLowerCase();
          if (idLower.startsWith('${code}_') || docComp == code) {
            try {
              final userRecs = await doc.reference.collection('user_records').get();
              for (var uDoc in userRecs.docs) {
                try {
                  await uDoc.reference.delete();
                } catch (_) {}
              }
              await doc.reference.delete();
            } catch (_) {}
          }
        }

        // Also sweep collectionGroup user_records with companyCode == code
        final groupRecords = await _firestore
            .collectionGroup('user_records')
            .where('companyCode', isEqualTo: code)
            .get();
        for (var doc in groupRecords.docs) {
          try {
            await doc.reference.delete();
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Error purging attendance_records for $code: $e');
      }

      // 4. Delete requests and their user_requests subcollections
      try {
        final reqSnap = await _firestore.collection('requests').get();
        for (var doc in reqSnap.docs) {
          final idLower = doc.id.toLowerCase();
          final data = doc.data();
          final docComp = (data['companyCode'] ?? '').toString().toLowerCase();
          if (idLower.startsWith('${code}_') || docComp == code) {
            try {
              final userReqs = await doc.reference.collection('user_requests').get();
              for (var uDoc in userReqs.docs) {
                try {
                  await uDoc.reference.delete();
                } catch (_) {}
              }
              await doc.reference.delete();
            } catch (_) {}
          }
        }

        // Also sweep collectionGroup user_requests with companyCode == code
        final groupRequests = await _firestore
            .collectionGroup('user_requests')
            .where('companyCode', isEqualTo: code)
            .get();
        for (var doc in groupRequests.docs) {
          try {
            await doc.reference.delete();
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Error purging requests for $code: $e');
      }

      // 5. Delete employees belonging to this company
      try {
        final empSnap = await _firestore.collection('employees').get();
        for (var doc in empSnap.docs) {
          final idLower = doc.id.toLowerCase();
          final data = doc.data();
          final empCode = (data['companyCode'] ?? '').toString().trim().toLowerCase();
          final email = (data['email'] ?? '').toString().trim().toLowerCase();
          final isTargetCompany = empCode == code ||
              idLower.startsWith('${code}_') ||
              (code.isNotEmpty && email.endsWith('@$code.com'));
          // Safety: Never delete the global super admin
          if (isTargetCompany && email != 'admin@company.com' && idLower != 'admin_super_account') {
            try {
              await doc.reference.delete();
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Error purging employees for $code: $e');
      }

      // 6. Invalidate all local caches
      _cachedStructures.clear();
      _cachedShifts.clear();
      _cachedGroups.clear();
      _cachedLocations.clear();
      _cachedHolidays.clear();

      debugPrint('Successfully purged company and all associated data: $code');
    } catch (e) {
      debugPrint('Fatal error purging company $code: $e');
      rethrow;
    }
  }
}

