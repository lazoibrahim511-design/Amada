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
  // Check if Firebase is initialized
  bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // --- OrgStructure CRUD (Tenant-isolated) ---
  Future<List<OrgStructure>> getStructures({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('structures').get();
      final list = <OrgStructure>[];
      final cleanFilter = companyCode?.trim().toLowerCase();
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
      return list;
    } catch (e) {
      debugPrint('Error getting structures: $e');
      return [];
    }
  }

  Stream<List<OrgStructure>> streamStructures({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    return _firestore.collection('structures').snapshots().map((snapshot) {
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
      return list;
    });
  }

  Future<void> saveStructure(OrgStructure structure) async {
    if (!isAvailable) return;
    try {
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
      await _firestore.collection('structures').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting structure: $e');
    }
  }

  // --- WorkShift CRUD (Tenant-isolated) ---
  Future<List<WorkShift>> getShifts({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('shifts').get();
      final list = <WorkShift>[];
      final cleanFilter = companyCode?.trim().toLowerCase();
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
      return list;
    } catch (e) {
      debugPrint('Error getting shifts: $e');
      return [];
    }
  }

  Stream<List<WorkShift>> streamShifts({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    return _firestore.collection('shifts').snapshots().map((snapshot) {
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
      return list;
    });
  }

  Future<void> saveShift(WorkShift shift) async {
    if (!isAvailable) return;
    try {
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
      await _firestore.collection('shifts').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting shift: $e');
    }
  }

  // --- EmployeeGroup CRUD (Tenant-isolated) ---
  Future<List<EmployeeGroup>> getGroups({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('groups').get();
      final list = <EmployeeGroup>[];
      final cleanFilter = companyCode?.trim().toLowerCase();
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
      return list;
    } catch (e) {
      debugPrint('Error getting groups: $e');
      return [];
    }
  }

  Stream<List<EmployeeGroup>> streamGroups({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    return _firestore.collection('groups').snapshots().map((snapshot) {
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
      return list;
    });
  }

  Future<void> saveGroup(EmployeeGroup group) async {
    if (!isAvailable) return;
    try {
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
      await _firestore.collection('groups').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting group: $e');
    }
  }

  // --- WorkLocation CRUD (Tenant-isolated) ---
  Future<List<WorkLocation>> getLocations({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('locations').get();
      final list = <WorkLocation>[];
      final cleanFilter = companyCode?.trim().toLowerCase();
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
      return list;
    } catch (e) {
      debugPrint('Error getting locations: $e');
      return [];
    }
  }

  Stream<List<WorkLocation>> streamLocations({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    return _firestore.collection('locations').snapshots().map((snapshot) {
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
      return list;
    });
  }

  Future<void> saveLocation(WorkLocation location) async {
    if (!isAvailable) return;
    try {
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
      await _firestore.collection('locations').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting location: $e');
    }
  }

  // --- ZkDeviceConfig CRUD (Tenant-isolated) ---
  Future<List<ZkDeviceConfig>> getDevices({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('devices').get();
      final list = <ZkDeviceConfig>[];
      final cleanFilter = companyCode?.trim().toLowerCase();
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
    return _firestore.collection('devices').snapshots().map((snapshot) {
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

  // --- Holiday CRUD (Tenant-isolated) ---
  Future<List<Holiday>> getHolidays({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('holidays').get();
      final list = <Holiday>[];
      final cleanFilter = companyCode?.trim().toLowerCase();
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
      return list;
    } catch (e) {
      debugPrint('Error getting holidays: $e');
      return [];
    }
  }

  Stream<List<Holiday>> streamHolidays({String? companyCode}) {
    if (!isAvailable) return Stream.value([]);
    final cleanFilter = companyCode?.trim().toLowerCase();
    return _firestore.collection('holidays').snapshots().map((snapshot) {
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
      return list;
    });
  }

  Future<void> saveHoliday(Holiday holiday) async {
    if (!isAvailable) return;
    try {
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
      await _firestore.collection('holidays').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting holiday: $e');
    }
  }

  // --- CompanyEmployee CRUD (Tenant-isolated) ---
  Future<List<CompanyEmployee>> getEmployees({String? companyCode}) async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('employees').get();
      final list = <CompanyEmployee>[];
      final cleanFilter = companyCode?.trim().toLowerCase();
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
    return _firestore.collection('employees').snapshots().map((snapshot) {
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

  // --- AttendanceRecord CRUD ---
  Future<List<AttendanceRecord>> getUserRecords(String employeeId) async {
    if (!isAvailable) return [];
    try {
      final trimmedId = employeeId.trim();
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('attendance_records')
            .doc(trimmedId)
            .collection('user_records')
            .get();
      } catch (e) {
        debugPrint('Error getting user_records for $trimmedId: $e');
        return [];
      }

      // If direct doc lookup is empty, try case-insensitive doc match in attendance_records
      if (snapshot.docs.isEmpty) {
        try {
          final parentSnap = await _firestore.collection('attendance_records').get();
          for (var pDoc in parentSnap.docs) {
            if (pDoc.id.toLowerCase() == trimmedId.toLowerCase()) {
              snapshot = await pDoc.reference.collection('user_records').get();
              if (snapshot.docs.isNotEmpty) break;
            }
          }
        } catch (_) {}
      }

      final list = <AttendanceRecord>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(AttendanceRecord.fromMap(doc.data(), trimmedId));
        } catch (e) {
          debugPrint('Error parsing AttendanceRecord ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    } catch (e) {
      debugPrint('Error getting user records: $e');
      return [];
    }
  }

  Stream<List<AttendanceRecord>> streamUserRecords(String employeeId) {
    if (!isAvailable) return Stream.value([]);
    final trimmedId = employeeId.trim();
    return _firestore
        .collection('attendance_records')
        .doc(trimmedId)
        .collection('user_records')
        .snapshots()
        .map((snapshot) {
      final list = <AttendanceRecord>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(AttendanceRecord.fromMap(doc.data(), trimmedId));
        } catch (e) {
          debugPrint('Error parsing AttendanceRecord ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    }).handleError((e) {
      debugPrint('Error in streamUserRecords for $trimmedId: $e');
      return <AttendanceRecord>[];
    });
  }

  Stream<List<AttendanceRecord>> streamAllRecords() {
    if (!isAvailable) return Stream.value([]);
    try {
      return _firestore.collectionGroup('user_records').snapshots().map((snapshot) {
        final list = <AttendanceRecord>[];
        for (var doc in snapshot.docs) {
          try {
            final empId = doc.data()['employeeId']?.toString() ??
                doc.reference.parent.parent?.id;
            list.add(AttendanceRecord.fromMap(doc.data(), empId));
          } catch (e) {
            debugPrint('Error parsing collectionGroup AttendanceRecord ${doc.id}: $e');
          }
        }
        list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
        return list;
      }).handleError((e) {
        debugPrint('collectionGroup user_records stream error (likely missing index): $e');
        return <AttendanceRecord>[];
      });
    } catch (e) {
      debugPrint('Error starting streamAllRecords: $e');
      return Stream.value([]);
    }
  }

  Future<void> saveRecord(String employeeId, AttendanceRecord record) async {
    if (!isAvailable) return;
    try {
      // Use CheckIn timestamp as document ID to uniquely identify day session
      final docId = record.checkIn.toIso8601String().replaceAll(':', '-');
      final data = record.toMap();
      data['employeeId'] = employeeId;
      await _firestore
          .collection('attendance_records')
          .doc(employeeId)
          .collection('user_records')
          .doc(docId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving attendance record: $e');
      rethrow;
    }
  }

  Future<void> deleteRecord(String employeeId, AttendanceRecord record) async {
    if (!isAvailable) return;
    try {
      final docId = record.checkIn.toIso8601String().replaceAll(':', '-');
      await _firestore
          .collection('attendance_records')
          .doc(employeeId)
          .collection('user_records')
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting attendance record: $e');
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

  Stream<List<DeletedPunch>> streamDeletedPunches() {
    if (!isAvailable) return Stream.value([]);
    try {
      return _firestore
          .collection('deleted_punches')
          .snapshots()
          .map((snapshot) {
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
  Future<List<Request>> getUserRequests(String employeeId) async {
    if (!isAvailable) return [];
    try {
      final trimmedId = employeeId.trim();
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('requests')
            .doc(trimmedId)
            .collection('user_requests')
            .get();
      } catch (e) {
        debugPrint('Error getting user_requests for $trimmedId: $e');
        return [];
      }

      if (snapshot.docs.isEmpty) {
        try {
          final parentSnap = await _firestore.collection('requests').get();
          for (var pDoc in parentSnap.docs) {
            if (pDoc.id.toLowerCase() == trimmedId.toLowerCase()) {
              snapshot = await pDoc.reference.collection('user_requests').get();
              if (snapshot.docs.isNotEmpty) break;
            }
          }
        } catch (_) {}
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final req = Request.fromMap(data, doc.id);
        return req.copyWith(
          employeeId: req.employeeId ?? trimmedId,
          overrideTargetShiftId: false,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting user requests: $e');
      return [];
    }
  }

  Stream<List<Request>> streamUserRequests(String employeeId) {
    if (!isAvailable) return Stream.value([]);
    return _firestore
        .collection('requests')
        .doc(employeeId)
        .collection('user_requests')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final req = Request.fromMap(data, doc.id);
        return req.copyWith(
          employeeId: req.employeeId ?? employeeId,
          overrideTargetShiftId: false,
        );
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
          String? empId = data['employeeId'];
          if (empId == null || empId.isEmpty) {
            try {
              empId = doc.reference.parent.parent?.id;
            } catch (_) {}
          }
          final req = Request.fromMap(data, doc.id);
          list.add(req.copyWith(
            employeeId: empId ?? req.employeeId,
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

  Stream<List<Request>> streamAllRequests() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collectionGroup('user_requests').snapshots().map((snapshot) {
      final list = <Request>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          String? empId = data['employeeId'];
          if (empId == null || empId.isEmpty) {
            try {
              empId = doc.reference.parent.parent?.id;
            } catch (_) {}
          }
          final req = Request.fromMap(data, doc.id);
          list.add(req.copyWith(
            employeeId: empId ?? req.employeeId,
            overrideTargetShiftId: false,
          ));
        } catch (e) {
          debugPrint('Error parsing request doc ${doc.id} in stream: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveRequest(String employeeId, Request request) async {
    if (!isAvailable) return;
    try {
      await _firestore
          .collection('requests')
          .doc(employeeId)
          .collection('user_requests')
          .doc(request.id)
          .set(request.toMap());
    } catch (e) {
      debugPrint('Error saving request: $e');
    }
  }

  Future<void> deleteRequest(String employeeId, String requestId) async {
    if (!isAvailable) return;
    try {
      await _firestore
          .collection('requests')
          .doc(employeeId)
          .collection('user_requests')
          .doc(requestId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting request: $e');
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
      if (recordSnap.docs.isEmpty) {
        debugPrint(
          'Seeding attendance records for $testUserId in Firestore...',
        );
        for (var r in userRecords) {
          await saveRecord(testUserId, r);
        }
      }

      // 6. Seed Requests for testUserId
      if (reqSnap.docs.isEmpty) {
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
}

