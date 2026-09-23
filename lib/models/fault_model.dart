class FaultModel {
  FaultModel({
    required this.id,
    required this.title,
    required this.severity,
    required this.location,
  });

  final String id;
  final String title;
  final String severity;
  final String location;

  factory FaultModel.demo() {
    return FaultModel(
      id: 'FLT-220',
      title: 'Cable insulation wear',
      severity: 'Warning',
      location: 'Connector panel',
    );
  }
}
