# chargex_vision

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Fault analysis backend (Phase 8)

The fault inspection flow uses the existing `InspectionAnalysisAdapter` and Dio. The backend is intentionally unavailable until an endpoint is configured; no demo or fallback fault results are generated.

Configure the API base URL at build time:

```sh
flutter run --dart-define=CHARGEX_FAULT_API_BASE_URL=https://your-host
```

The client posts to `/v1/fault-analysis` relative to that base URL. When Firebase-authenticated access is required, enable the existing Firebase user's ID token:

```sh
flutter run --dart-define=CHARGEX_FAULT_API_BASE_URL=https://your-host --dart-define=CHARGEX_FAULT_API_REQUIRE_FIREBASE_AUTH=true
```

The JSON request includes known charger and component fields plus evidence metadata. A selected local image is sent as multipart field `evidence_file`, alongside JSON field `request`; its device-local path is never sent. The service should return a JSON object with `status` set to `fault_detected`, `no_fault_detected`, `unavailable`, `backend_unavailable`, `invalid_request`, or `backend_error`. A `fault_detected` response must include a `fault` object using the existing `FaultResult` JSON field names, including the requested `componentId`. Optional fault details such as location, confidence, severity, and timestamp must be omitted when the service does not have them.

## Health assessment (Phase 9)

Health is calculated from an explicitly available no-fault inspection or charger-scoped `FaultResult` data. The current selected charger must have the same serial number or QR identifier as the inspection context. A charger identified only by manufacturer/model, missing inspection data, an unavailable backend, or an unrecognized fault severity produces `Unknown / Unavailable`; it is never treated as healthy.

Severity mapping uses the existing `FaultResult.severity` string: `Critical`, `High`, `Severe`, and `Emergency` map to Critical; `Warning`, `Medium`, `Low`, and `Minor` map to Warning. With multiple faults, the highest recognized severity determines the status. A healthy result requires an explicit no-fault inspection and no charger-associated active faults. No health percentage or sensor metric is calculated.

## RUL readiness (Phase 10)

The app now provides a typed request/response boundary and a readiness screen for a future Remaining Useful Life service. Actual RUL prediction is not performed. The proposed default endpoint is `/v1/rul-analysis`, configurable with `CHARGEX_RUL_API_PATH`; set `CHARGEX_RUL_API_BASE_URL` at build time to configure a backend. Firebase ID-token authentication can be enabled with `CHARGEX_RUL_API_REQUIRE_FIREBASE_AUTH=true` when the service requires it.

The request contract contains the selected charger's existing serial/QR identifier and optional component, inspection, and fault context already stored in the app. It contains no fabricated operating history. A valid `available` response must contain a finite, non-negative `remainingUsefulLife`, a non-empty `unit`, and a `chargerIdentifier` matching the request; a requested component ID must also match. Optional assessment/horizon timestamps, model details, and confidence are displayed only when returned by the service. `insufficient_data`, `unavailable`, backend errors, and malformed responses never become an RUL value.

RUL status remains unavailable until real support is configured. A production estimate requires timestamped operational history, degradation measurements, relevant operating hours/cycles, maintenance or replacement history where available, reliable charger/component association, and a validated prediction method/model. This phase adds readiness architecture only; real RUL prediction is future work.

## Maintenance readiness (Phase 11)

Phase 11 adds a Maintenance Backend/Data Readiness Foundation only. Production maintenance functionality is not available yet: the app does not schedule service, create work orders, persist maintenance history, or generate due dates or maintenance recommendations. The proposed endpoint is `GET /v1/maintenance-records?chargerIdentifier={id}`; it is a future contract and does not currently exist. Configure a future service with `CHARGEX_MAINTENANCE_API_BASE_URL`; optionally set `CHARGEX_MAINTENANCE_API_PATH` and `CHARGEX_MAINTENANCE_API_REQUIRE_FIREBASE_AUTH=true` when appropriate for that backend.

The proposed response is a JSON object containing `status` (`available`, `empty`, `unavailable`, `backend_unavailable`, `error`, or `backend_error`), the exact `chargerIdentifier`, and a `records` array for available/empty responses. Each real record requires `recordId` and `recordType`; optional component, status, description, service date, work order, repair, and replacement fields are shown only when supplied. Missing or mismatched charger identity, malformed fields, network failures, and timeouts never create maintenance records.

A future production service must provide real charger identity, component association where relevant, maintenance/service records, service dates only when available, work-order information and status only when available, and repair/replacement information when available. Any maintenance recommendation rules and service-interval policy must be documented and supplied by the backend/domain. The app does not infer intervals or dates.

An explicit `FaultResult.recommendation` from a real fault-analysis response may appear separately as a fault-analysis recommendation. It is not maintenance history, scheduled work, or an app-generated maintenance action. Fault severity alone does not generate a recommendation.

## Current-snapshot reports (Phase 12)

Phase 12 provides a current-snapshot reporting foundation. It can show selected charger identity, the current charger-associated inspection, current charger-scoped active faults, and the current derived health assessment when those values are available. Missing timestamps and unavailable sections remain unavailable; reports do not create dates or convert missing data to zero.

The Reports screen remains a current snapshot; it is not a historical report, trend report, or operational telemetry. Phase 19 adds local inspection history, but does not archive reports, create trends, or persist maintenance/RUL history. PDF generation, CSV export, sharing, and download are not provided. Phase 11 maintenance records remain unavailable unless a configured service returns charger-matched records; Phase 10 RUL readiness is not presented as a prediction. Fault recommendations remain fault-analysis context, not maintenance history.

Historical reporting requires a separately approved report archive contract or feature. No such backend is currently claimed or assumed. Legacy demo data and dashboard aggregate values are not used as report content.

## Local inspection history (Phase 19)

Inspection history and evidence are retained in app-private local storage until the user deletes them. The implementation and limitations are documented in [`docs/persistence-requirements-phase19.md`](docs/persistence-requirements-phase19.md). This is not encrypted storage or cloud synchronization, and no backend result is marked verified without a trusted-source verifier.

## Backend API contracts (Phase 14)

Phase 14 records the existing client boundaries and proposed backend schemas in [`docs/backend-api-contracts-phase14.md`](docs/backend-api-contracts-phase14.md). All proposed endpoints are pending backend approval. AI recognition and Digital Twin registry URLs are empty by default; no production service is claimed or contacted without explicit configuration.

## Offline test readiness (Phase 16)

[`docs/integration-readiness-phase16.md`](docs/integration-readiness-phase16.md) lists offline service-test coverage, known gaps, and the checklist for a future authorized non-production integration. Passing mocked/offline tests does not prove a live backend integration works.
