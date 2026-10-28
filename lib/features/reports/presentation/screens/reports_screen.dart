import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../inspection/domain/models/component_inspection.dart';
import '../../../inspection/domain/models/fault_result.dart';
import '../../domain/models/current_charger_report.dart';
import '../providers/current_charger_report_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(currentChargerReportProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: report.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Preparing current snapshot...'),
              ],
            ),
          ),
          error: (error, stack) => _errorState(),
          data: _snapshot,
        ),
      ),
    );
  }

  Widget _snapshot(CurrentChargerReport report) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        color: Colors.blue.withValues(alpha: 0.08),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Charger Snapshot',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'This shows current application state only. It is not historical reporting, a trend report, or operational telemetry.',
              ),
            ],
          ),
        ),
      ),
      _section('Charger Identity', _chargerContent(report.charger)),
      _section('Current Inspection', _inspectionContent(report.inspection)),
      _section('Current Faults', _faultContent(report.faults)),
      _section('Current Health Assessment', _healthContent(report.health)),
      _section('Maintenance Data', _maintenanceContent(report.maintenance)),
      _section('RUL Data', _statusCard(report.rulMessage)),
    ],
  );

  Widget _chargerContent(ChargerIdentitySnapshot charger) {
    final metadata = [
      charger.manufacturer,
      charger.model,
      charger.type,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (charger.hasUniqueIdentity)
          _line(charger.identifier!)
        else
          const Text(
            'Charger identity unavailable; a serial number or QR identifier is required.',
          ),
        if (metadata.isNotEmpty) _line('Metadata: $metadata'),
      ],
    );
  }

  Widget _inspectionContent(InspectionReportSection section) {
    final inspection = section.inspection;
    if (section.status != ReportSectionStatus.available || inspection == null) {
      return _statusCard(
        section.message ?? 'Current inspection is unavailable.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(
          'Component: ${inspection.component.displayName} (${inspection.component.componentId})',
        ),
        _line('Result: ${inspection.status.displayName}'),
        if (inspection.detectedCondition != null)
          _line('Finding: ${inspection.detectedCondition}'),
        if (inspection.severity != null)
          _line('Severity: ${inspection.severity}'),
        if (inspection.timestamp != null)
          _line('Inspection timestamp: ${inspection.timestamp!.toLocal()}'),
        if (inspection.timestamp == null)
          const Text('Inspection timestamp unavailable.'),
      ],
    );
  }

  Widget _faultContent(FaultReportSection section) {
    if (section.status == ReportSectionStatus.available) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: section.faults.map(_fault).toList(growable: false),
      );
    }
    return _statusCard(section.message ?? 'Current fault data unavailable.');
  }

  Widget _fault(FaultResult fault) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line('Fault: ${fault.faultType}'),
        _line('Component: ${fault.componentDisplayName ?? fault.componentId}'),
        if (fault.severity != null) _line('Severity: ${fault.severity}'),
        if (fault.locationDescription != null)
          _line('Location: ${fault.locationDescription}'),
        if (fault.probableCause != null)
          _line('Probable cause: ${fault.probableCause}'),
        if (fault.recommendation != null)
          _line('Backend recommendation: ${fault.recommendation}'),
        if (fault.detectedAt != null)
          _line('Detected at: ${fault.detectedAt!.toLocal()}'),
      ],
    ),
  );

  Widget _healthContent(HealthReportSection section) {
    final assessment = section.assessment;
    if (section.status != ReportSectionStatus.available || assessment == null) {
      return _statusCard(
        section.message ?? 'Current health assessment unavailable.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(assessment.statusLabel),
        _line(assessment.reason),
        if (assessment.sourceTimestamp != null)
          _line('Source timestamp: ${assessment.sourceTimestamp!.toLocal()}'),
        const Text(
          'Derived from the current inspection/fault state; not live telemetry or a trend.',
        ),
      ],
    );
  }

  Widget _maintenanceContent(MaintenanceReportSection section) {
    if (section.status == MaintenanceReportStatus.unavailable) {
      return _statusCard(section.message ?? 'Maintenance data unavailable.');
    }
    if (section.status == MaintenanceReportStatus.noRecords) {
      return _statusCard(
        section.message ?? 'No maintenance records were returned.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: section.records
          .map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(record.recordType),
                  if (record.description != null) _line(record.description!),
                  if (record.componentId != null)
                    _line('Component: ${record.componentId}'),
                  if (record.status != null) _line('Status: ${record.status}'),
                  if (record.serviceDate != null)
                    _line('Service date: ${record.serviceDate!.toLocal()}'),
                  if (record.workOrderId != null)
                    _line('Work order: ${record.workOrderId}'),
                  if (record.workOrderStatus != null)
                    _line('Work order status: ${record.workOrderStatus}'),
                  if (record.repairDetails != null)
                    _line('Repair: ${record.repairDetails}'),
                  if (record.replacementDetails != null)
                    _line('Replacement: ${record.replacementDetails}'),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _section(String title, Widget content) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    ),
  );

  Widget _line(String text) =>
      Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(text));

  Widget _statusCard(String message) => Text(message);

  Widget _errorState() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Current charger snapshot is unavailable because report data could not be loaded.',
      ),
    ),
  );
}
