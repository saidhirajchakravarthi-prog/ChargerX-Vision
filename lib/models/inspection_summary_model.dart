class InspectionSummaryModel {
  InspectionSummaryModel({
    required this.id,
    required this.title,
    required this.date,
    required this.status,
  });

  final String id;
  final String title;
  final String date;
  final String status;

  factory InspectionSummaryModel.demo() {
    return InspectionSummaryModel(
      id: 'INSP-1042',
      title: 'Quarterly visual inspection',
      date: '2026-08-20',
      status: 'Complete',
    );
  }
}
