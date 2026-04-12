class RteApplicationData {
  final String applicationNumber;
  final String statusMessage;
  final Map<String, Map<String, String>> sections;
  final List<List<String>> schools;
  final List<List<String>> documents;

  RteApplicationData({
    required this.applicationNumber,
    required this.statusMessage,
    required this.sections,
    required this.schools,
    required this.documents,
  });
}
