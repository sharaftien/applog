class AppLogEntry {
  final int? id;
  final String packageName;
  final String appName;
  final String versionName;
  final int installDate; // Unix timestamp in milliseconds

  AppLogEntry({
    this.id,
    required this.packageName,
    required this.appName,
    required this.versionName,
    required this.installDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package_name': packageName,
      'app_name': appName,
      'version_name': versionName,
      'install_date': installDate,
    };
  }

  factory AppLogEntry.fromMap(Map<String, dynamic> map) {
    return AppLogEntry(
      id: map['id'],
      packageName: map['package_name'],
      appName: map['app_name'],
      versionName: map['version_name'],
      installDate: map['install_date'],
    );
  }
}
