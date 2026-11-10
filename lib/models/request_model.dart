import 'package:flutter/material.dart';

class Request {
  final String id;
  final String type;
  final String date;
  final String duration;
  final String status; // 'Approved', 'Pending', 'Rejected'
  final String? targetShiftId;
  final String? employeeId;
  final String? companyCode;
  final String? note;
  final String? createdAt;
  final String? actionBy;
  final String? actionDate;

  final String? supervisorActionBy;
  final String? supervisorActionDate;
  final String? supervisorStatus;
  final String? hrActionBy;
  final String? hrActionDate;
  final String? hrStatus;

  Request({
    required this.id,
    required this.type,
    required this.date,
    required this.duration,
    required this.status,
    this.targetShiftId,
    this.employeeId,
    this.companyCode,
    this.note,
    this.createdAt,
    this.actionBy,
    this.actionDate,
    this.supervisorActionBy,
    this.supervisorActionDate,
    this.supervisorStatus,
    this.hrActionBy,
    this.hrActionDate,
    this.hrStatus,
  });

  Color get statusColor {
    switch (status) {
      case 'Approved':
        return const Color(0xFF2EBD96);
      case 'Rejected':
        return const Color(0xFFEF4444);
      case 'Pending Supervisor':
        return const Color(0xFFF59E0B);
      case 'Pending HR':
        return const Color(0xFF8B5CF6);
      case 'Pending':
      default:
        return const Color(0xFF2E65FF);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'date': date,
      'duration': duration,
      'status': status,
      'targetShiftId': targetShiftId,
      'employeeId': employeeId,
      'companyCode': companyCode,
      'note': note,
      'createdAt': createdAt,
      'actionBy': actionBy,
      'actionDate': actionDate,
      'supervisorActionBy': supervisorActionBy,
      'supervisorActionDate': supervisorActionDate,
      'supervisorStatus': supervisorStatus,
      'hrActionBy': hrActionBy,
      'hrActionDate': hrActionDate,
      'hrStatus': hrStatus,
    };
  }

  factory Request.fromMap(Map<String, dynamic> map, String docId) {
    return Request(
      id: map['id'] ?? docId,
      type: map['type'] ?? '',
      date: map['date'] ?? '',
      duration: map['duration'] ?? '',
      status: map['status'] ?? 'Pending',
      targetShiftId: map['targetShiftId'],
      employeeId: map['employeeId'],
      companyCode: map['companyCode'],
      note: map['note'],
      createdAt: map['createdAt'],
      actionBy: map['actionBy'],
      actionDate: map['actionDate'],
      supervisorActionBy: map['supervisorActionBy'],
      supervisorActionDate: map['supervisorActionDate'],
      supervisorStatus: map['supervisorStatus'],
      hrActionBy: map['hrActionBy'],
      hrActionDate: map['hrActionDate'],
      hrStatus: map['hrStatus'],
    );
  }

  Request copyWith({
    String? id,
    String? type,
    String? date,
    String? duration,
    String? status,
    String? targetShiftId,
    String? employeeId,
    String? companyCode,
    String? note,
    String? createdAt,
    String? actionBy,
    String? actionDate,
    String? supervisorActionBy,
    String? supervisorActionDate,
    String? supervisorStatus,
    String? hrActionBy,
    String? hrActionDate,
    String? hrStatus,
    bool overrideTargetShiftId = false,
  }) {
    return Request(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      targetShiftId: overrideTargetShiftId
          ? targetShiftId
          : (targetShiftId ?? this.targetShiftId),
      employeeId: employeeId ?? this.employeeId,
      companyCode: companyCode ?? this.companyCode,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      actionBy: actionBy ?? this.actionBy,
      actionDate: actionDate ?? this.actionDate,
      supervisorActionBy: supervisorActionBy ?? this.supervisorActionBy,
      supervisorActionDate: supervisorActionDate ?? this.supervisorActionDate,
      supervisorStatus: supervisorStatus ?? this.supervisorStatus,
      hrActionBy: hrActionBy ?? this.hrActionBy,
      hrActionDate: hrActionDate ?? this.hrActionDate,
      hrStatus: hrStatus ?? this.hrStatus,
    );
  }
}
