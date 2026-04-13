class MaintenanceModel {
  final bool centralMaintenance;
  final bool officeMaintenance;
  final bool parentMaintenance;

  MaintenanceModel({
    required this.centralMaintenance,
    required this.officeMaintenance,
    required this.parentMaintenance,
  });

  factory MaintenanceModel.fromFirestore(Map<String, dynamic> data) {
    return MaintenanceModel(
      centralMaintenance: data['central_level_maintenance'] ?? false,
      officeMaintenance: data['office_level_maintenance'] ?? false,
      parentMaintenance: data['parent_level_maintenance'] ?? false,
    );
  }

  // Default — no maintenance
  factory MaintenanceModel.defaults() {
    return MaintenanceModel(
      centralMaintenance: false,
      officeMaintenance: false,
      parentMaintenance: false,
    );
  }
}
