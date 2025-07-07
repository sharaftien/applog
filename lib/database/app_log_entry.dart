import 'package:flutter/material.dart';

class AppLogEntry {
  final int? id;
  final String packageName;
  final String appName;
  final String versionName;
  final int installDate;
  final int updateDate;
  final List<int>? icon;
  final int? deletionDate;
  final String? notes;
  final bool isFavorite;

  AppLogEntry({
    this.id,
    required this.packageName,
    required this.appName,
    required this.versionName,
    required this.installDate,
    required this.updateDate,
    this.icon,
    this.deletionDate,
    this.notes,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package_name': packageName,
      'app_name': appName,
      'version_name': versionName,
      'install_date': installDate,
      'update_date': updateDate,
      'icon': icon,
      'deletion_date': deletionDate,
      'notes': notes,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory AppLogEntry.fromMap(Map<String, dynamic> map) {
    return AppLogEntry(
      id: map['id'] as int?,
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String,
      versionName: map['version_name'] as String,
      installDate: map['install_date'] as int,
      updateDate: map['update_date'] as int,
      icon: map['icon'] != null ? List<int>.from(map['icon']) : null,
      deletionDate: map['deletion_date'] as int?,
      notes: map['notes'] as String?,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
    );
  }
}
