class AppLogEntry {
  final int? id;
  final String packageName;
  final String appName;
  final String versionName;
  final int installDate; // Unix timestamp in milliseconds (first install)
  final int updateDate; // Unix timestamp in milliseconds (last update)

  AppLogEntry({
    this.id,
    required this.packageName,
    required this.appName,
    required this.versionName,
    required this.installDate,
    required this.updateDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package_name': packageName,
      'app_name': appName,
      'version_name': versionName,
      'install_date': installDate,
      'update_date': updateDate,
    };
  }

  factory AppLogEntry.fromMap(Map<String, dynamic> map) {
    return AppLogEntry(
      id: map['id'],
      packageName: map['package_name'],
      appName: map['app_name'],
      versionName: map['version_name'],
      installDate: map['install_date'],
      updateDate: map['update_date'],
    );
  }
}
