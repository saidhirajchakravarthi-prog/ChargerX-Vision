import '../models/charger_model.dart';
import '../models/fault_model.dart';
import '../models/inspection_summary_model.dart';

class DemoRepository {
  const DemoRepository();

  List<ChargerModel> getChargers() {
    return [
      ChargerModel(
        id: 'CX-001',
        manufacturer: 'ABB',
        model: 'Terra 54',
        location: 'North Bay Hub',
        health: 94,
        status: 'Healthy',
      ),
      ChargerModel(
        id: 'CX-014',
        manufacturer: 'Schneider',
        model: 'EVlink Pro',
        location: 'Warehouse Row B',
        health: 82,
        status: 'Warning',
      ),
      ChargerModel(
        id: 'CX-029',
        manufacturer: 'Tesla',
        model: 'Destination',
        location: 'Transit Plaza',
        health: 68,
        status: 'Critical',
      ),
    ];
  }

  List<InspectionSummaryModel> getRecentInspections() {
    return [
      InspectionSummaryModel(
        id: 'INSP-1042',
        title: 'Quarterly visual inspection',
        date: '2026-08-20',
        status: 'Complete',
      ),
      InspectionSummaryModel(
        id: 'INSP-1031',
        title: 'Cable integrity review',
        date: '2026-08-12',
        status: 'Needs review',
      ),
    ];
  }

  List<FaultModel> getRecentFaults() {
    return [
      FaultModel(
        id: 'FLT-220',
        title: 'Cable insulation wear',
        severity: 'Warning',
        location: 'Connector panel',
      ),
      FaultModel(
        id: 'FLT-188',
        title: 'Thermal stress indication',
        severity: 'Critical',
        location: 'Power module',
      ),
    ];
  }
}
