# Phase 14 — Backend API Contracts and Integration Readiness

**Status: design proposals pending backend approval.** This document records
what the Flutter client currently does and proposes API shapes for review. It
does not establish that a service exists, that the examples are production
responses, or that any endpoint is deployed. All values in JSON examples are
schema placeholders. No live requests were made for this audit.

## Current integration inventory

| Area | Current implementation | Current endpoint/configuration | Current data source/status |
| --- | --- | --- | --- |
| AI recognition | `AiRecognitionRepository` uploads a multipart image and reads recognition fields. | Previously hard-coded to a `.local` host; Phase 14 changes it to an empty-by-default `CHARGEX_AI_RECOGNITION_API_URL`. | No configured service is confirmed. Unconfigured state returns unavailable without a request. |
| Fault analysis / inspection | `FaultAnalysisRepository` posts JSON or multipart evidence; `BackendInspectionAnalysisAdapter` maps typed outcomes into inspection states. | `CHARGEX_FAULT_API_BASE_URL` plus `/v1/fault-analysis`. | Client integration exists; no deployed endpoint is confirmed. Firebase ID-token use is controlled by `CHARGEX_FAULT_API_REQUIRE_FIREBASE_AUTH` and defaults off. |
| Digital Twin registry | `DigitalTwinRepository` loads a typed model; the existing viewer renders its component list and overlays app-held faults. | Previously hard-coded to a `.local` host; Phase 14 changes it to an empty-by-default `CHARGEX_DIGITAL_TWIN_API_URL`. | No configured registry or live twin asset is confirmed. Unconfigured state returns unavailable without a request. |
| Health | `HealthAssessmentCalculator` deterministically derives status from the selected charger's inspection and scoped faults. | No endpoint. | Current in-memory app data only; not a sensor or telemetry health service. |
| RUL | `DioRulRepository` posts available charger, inspection, and fault context and validates a typed result. | `CHARGEX_RUL_API_BASE_URL` plus `CHARGEX_RUL_API_PATH` (default `/v1/rul-analysis`). | Readiness boundary only until explicitly configured; no live RUL service or prediction is confirmed. Firebase ID-token use is optional and defaults off. |
| Maintenance | `DioMaintenanceRepository` fetches charger records and validates their charger identity. | `CHARGEX_MAINTENANCE_API_BASE_URL` plus `CHARGEX_MAINTENANCE_API_PATH` (default `/v1/maintenance-records`). | Readiness boundary only; no live service, schedule, or maintenance history is confirmed. Firebase ID-token use is optional and defaults off. |
| Current-snapshot reports | `CurrentReportComposer` combines current selected-charger inspection, faults, health, and returned maintenance records. | No report endpoint. | Generated locally from current in-memory state. It is not historical, trend, or PDF reporting. RUL remains unavailable in the snapshot. |

### Existing model and transport facts

- `ChargerModel` has optional `serialNumber` and `rawQrIdentifier`. `chargerIdentityKey` prefers the serial and otherwise uses the QR value; manufacturer/model alone are not a unique charger identity.
- `DigitalTwinComponent.componentId` is the component identifier. Current fault state is indexed by component ID and accompanied by a selected-charger key in the inspection provider. The API proposal requires the server to scope component identity under a twin/model and charger identity where the result concerns a specific unit.
- Fault requests currently serialize `schema_version`, optional charger metadata, a snake-case `component` object, and evidence metadata. A local image is multipart `evidence_file`; JSON is multipart field `request`. Device-local paths are omitted from JSON.
- Fault response parsing requires `status`; `fault_detected` requires a `fault` object. The adapter checks that the returned fault component ID equals the requested component ID. The current response does **not** echo or validate a charger identifier.
- RUL requests contain an `identifier`, optional component/inspection context, and available faults. Available RUL responses must echo the exact charger identifier; a requested component ID must match. Value must be finite and non-negative, and a unit is required.
- Maintenance uses `GET` with query key `chargerIdentifier`; its body must echo the exact requested identifier and includes `status` plus records for available/empty responses.
- Fault, RUL, and maintenance repositories use 20-second default timeouts. AI recognition and Digital Twin used 5-second send/receive timeouts. None of these clients implements automatic retries.
- The current authentication flags default to false. When enabled for fault/RUL/maintenance, the client obtains the signed-in Firebase user's ID token and sends `Authorization: Bearer <token>`. The AI and Digital Twin clients have no auth integration today. This does not establish the backend's authorization policy.
- Health and report logic is client-side. It must not be represented as a live server measurement or persistent record.
- No backend response cache or offline service cache was found in these feature implementations. A successful validated response would be the response to that request; without a configured service, on failure, or on malformed data the feature exposes unavailable/error state. The AI screen has a short UI progress delay, which is not model execution or a successful result.

## Proposed shared conventions

**These are design proposals pending backend approval.** Agree on them before
connecting production services.

1. Use HTTPS outside local development. A deployment supplies the service URL; Flutter source contains no production URL, API key, service-account credential, or static bearer token.
2. Use an opaque canonical charger identifier plus an identifier type (`serial` or `qr`). The backend must resolve and authorize the authenticated user for that charger. Do not use manufacturer/model as a unit identity. Do not log raw QR content unless its format and sensitivity have been reviewed.
3. Treat a component identifier as scoped to a twin/model and charger. A response about a specific unit must echo the exact requested charger identifier and component ID. Reject mismatches before storing, highlighting, or reporting data.
4. Use ISO 8601 timestamps with an explicit UTC offset. Omit unavailable optional values; do not fabricate confidence, severity, timestamps, evidence, or model outputs.
5. Proposed error body for non-2xx responses:

   ```json
   {
     "error": {
       "code": "<stable machine-readable code>",
       "message": "<safe user-independent message>",
       "requestId": "<server correlation id>",
       "retryable": "<boolean>"
     }
   }
   ```

   Do not put stack traces, tokens, file paths, or sensitive evidence in the
   error body. Existing Flutter clients mostly map HTTP status and do not yet
   consume this common error envelope; adopting it requires an agreed client
   update.
6. Do not retry image/fault/RUL POST operations automatically until the backend
   defines idempotency and duplicate-work behavior. A user-triggered retry may
   be offered after an explicit failure. Maintenance GET can be manually
   refreshed; no offline cache or stale-data behavior is currently defined.
7. Suggested status mapping: malformed request `400`/`422`, unauthenticated
   `401`, unauthorized `403`, missing resource `404`, rate-limited `429`, and
   service failure `5xx`. Exact statuses and whether insufficient data is a
   typed `200` outcome or `422` must be agreed per service; existing clients
   currently handle some of these differently.

## Service contract proposals

Every endpoint/path and schema below is a **design proposal pending backend
approval**, not a claim that an API exists.

### 1. AI image recognition

- **Purpose/method:** `POST /v1/recognize`; multipart field `file` contains the selected image. This path aligns with the prior client intent but is not a confirmed endpoint.
- **Current behavior:** `CHARGEX_AI_RECOGNITION_API_URL` must contain the complete endpoint URL. No default is configured; without it, the client makes no request. Existing client timeout is 5 seconds for send and receive. No retry. No Firebase auth is currently attached. With an explicitly configured URL, a successfully validated response is current response data, not cached data.
- **Proposed success body:**

  ```json
  {
    "recognized": "<boolean>",
    "manufacturer": "<string or null>",
    "model": "<string or null>",
    "type": "<string or null>",
    "confidence": "<finite number in agreed scale, or null>"
  }
  ```

- **Validation proposal:** `recognized` is required and boolean. If true, at least one agreed identity field is non-empty; optional confidence range/meaning must be documented. This result identifies a charger model only unless the backend explicitly returns a separately validated unique unit identifier. It must not manufacture serial/QR identity.
- **Auth proposal:** backend team must decide whether this endpoint is public, Firebase-authenticated, or otherwise protected. If Firebase auth is selected, define project/audience, claims, roles, and image privacy/retention before adding client token handling.
- **Acceptance tests:** valid recognition and explicit no-match are distinguishable; malformed JSON/types are rejected; timeout/unconfigured URL makes no request or shows unavailable; upload field and content type are accepted; image size/type limits and retention are enforced; responses contain no fabricated serial/QR.

### 2. Fault analysis and component inspection

- **Purpose/method:** `POST /v1/fault-analysis`; JSON when there is no image, multipart otherwise (`request` JSON and `evidence_file`). The base URL is `CHARGEX_FAULT_API_BASE_URL`; current path is `/v1/fault-analysis`.
- **Current behavior:** 20-second timeout; no automatic retry. Optional Firebase ID-token auth is configured by `CHARGEX_FAULT_API_REQUIRE_FIREBASE_AUTH`, default false. The current client validates status/fault shape and component ID but not a response charger ID.
- **Illustrative request shape (field names reflect current serializer; identity addition is proposed):**

  ```json
  {
    "schema_version": 1,
    "charger": {
      "identifier": "<opaque unique charger id>",
      "identifier_type": "<serial or qr>"
    },
    "component": {
      "component_id": "<component id scoped by twin/model>",
      "type": "<component type>"
    },
    "evidence": "<available evidence metadata or null>"
  }
  ```

- **Proposed success bodies:**

  ```json
  {
    "status": "fault_detected",
    "chargerIdentifier": "<exact requested id>",
    "fault": {
      "faultType": "<backend result>",
      "componentId": "<exact requested component id>",
      "severity": "<backend value or omitted>",
      "confidence": "<backend value or omitted>",
      "detectedAt": "<backend timestamp or omitted>"
    }
  }
  ```

  ```json
  {
    "status": "no_fault_detected",
    "chargerIdentifier": "<exact requested id>",
    "componentId": "<exact requested component id>"
  }
  ```

- **Validation proposal:** require unique charger identity and component ID. Echo and match both on every outcome. A detected fault must have a real backend/sensor analysis result; optional severity/confidence/time/evidence are omitted if unknown. No match must not be interpreted as a measurement-based diagnosis.
- **Auth proposal:** agree on Firebase token validation, charger-level access control, technician/admin authorization, and whether image upload needs separate consent/retention controls. Client's optional bearer header is not server authorization by itself.
- **Acceptance tests:** JSON and multipart request parsing; correct identity/component echo; cross-charger and cross-component response rejected; explicit fault/no-fault/unavailable states; malformed response, 401/403, 429, 5xx, timeout, duplicate/idempotency behavior; evidence is never logged or persisted beyond agreed policy.

### 3. Digital Twin registry

- **Purpose/method:** proposed `GET /v1/twins` to return model structure and asset references. **The backend must decide lookup semantics.** Current client query keys are `manufacturer`, `model`, and optional `raw_qr`; these do not establish unique model or unit matching.
- **Configuration/current behavior:** `CHARGEX_DIGITAL_TWIN_API_URL` must contain the complete registry URL. It is empty by default and makes no request until configured. Prior timeout was 5 seconds. No automatic retry, response cache, or auth integration exists. A loaded twin would be the registry response for that request, not evidence of unit telemetry.
- **Proposed request:** use an agreed stable `twinId` or model/variant key; if resolving through a specific unit, send its canonical charger identifier and let the service authorize and resolve the model. Decide whether raw QR is permitted; avoid sending it if it contains unnecessary personal/operational data.
- **Illustrative response matching the current model fields:**

  ```json
  {
    "twinId": "<stable twin/model id>",
    "manufacturer": "<manufacturer>",
    "chargerModel": "<model/variant>",
    "chargerType": "<type>",
    "assetReference": "<approved asset reference>",
    "version": "<asset version>",
    "components": [
      {
        "componentId": "<stable id unique within twinId>",
        "componentType": "<type>",
        "displayName": "<display label>",
        "assetNodeIdentifier": "<node id>",
        "description": "<description>"
      }
    ]
  }
  ```

- **Validation/security proposal:** require a stable twin/model association; component IDs unique within that twin; validate/allowlist asset references and formats. Registry structure is model-level; do not put unit-specific faults or live telemetry in a shared model asset. Unit-specific fault highlighting remains charger-scoped app data. Define whether assets are public or require authenticated, signed access.
- **Acceptance tests:** matching model/twin response; no match; invalid/malformed structure; unavailable/timeout; asset reference safety; component ID uniqueness; authorization; ensure no unit-specific fault state leaks through a shared twin response.

### 4. Health assessment

- **Current implementation:** client-side deterministic calculation from current, identified charger inspection/fault data. No endpoint, remote measurement, or health percentage exists.
- **Endpoint proposal:** none required for the current feature. If the domain later requires centralized health, propose a versioned calculation endpoint only after the backend supplies metric definitions, units, timestamps, provenance, charger/component association, and a validated health policy. Do not send the current derived status as if it were a measurement.
- **Acceptance tests:** current unit tests cover explicit no-fault, recognized severities, unavailable input, missing identity, and cross-charger state. Any later server calculation requires parity tests against the agreed domain rules.

### 5. Remaining Useful Life (RUL)

- **Purpose/method:** current proposed `POST /v1/rul-analysis`; base `CHARGEX_RUL_API_BASE_URL`, path `CHARGEX_RUL_API_PATH` (default `/v1/rul-analysis`).
- **Current behavior:** 20-second timeout; no automatic retry; optional Firebase ID-token auth defaults off. The client sends only real currently available charger/inspection/fault context. No operating history is synthesized.
- **Illustrative request:**

  ```json
  {
    "charger": {
      "identifier": "<opaque unique charger id>",
      "serialNumber": "<if available>",
      "rawQrIdentifier": "<if required and approved>"
    },
    "component": {
      "componentId": "<component id or omitted for charger-level result>"
    },
    "inspection": "<available inspection context or omitted>",
    "faults": "<available charger-scoped faults or omitted>"
  }
  ```

- **Illustrative available response:**

  ```json
  {
    "status": "available",
    "result": {
      "chargerIdentifier": "<exact requested id>",
      "componentId": "<exact requested component id, if component-level>",
      "remainingUsefulLife": "<finite non-negative number from validated model>",
      "unit": "<agreed unit>",
      "assessedAt": "<actual model assessment time, if available>",
      "modelName": "<model provenance, if available>",
      "modelVersion": "<model version, if available>"
    }
  }
  ```

- **Validation proposal:** preserve current exact charger/component matching and numeric/unit checks. Backend must define prediction target, units, confidence semantics, horizon semantics, training/validation evidence, freshness, and insufficient-data criteria. A typed `insufficient_data` response carries no RUL number. The application must not infer an estimate from health severity.
- **Auth proposal:** agree on Firebase token audience/claims and per-charger access. Decide whether model provenance can be exposed to clients.
- **Acceptance tests:** known schema/type validation; identity mismatch rejected; component mismatch rejected; finite/non-negative value and unit; insufficient-data has no value; model/time fields only from actual backend output; timeout/5xx/401/403/rate limit; model version and traceability.

### 6. Maintenance readiness

- **Purpose/method:** current proposed `GET /v1/maintenance-records?chargerIdentifier=<id>`; base `CHARGEX_MAINTENANCE_API_BASE_URL`, path `CHARGEX_MAINTENANCE_API_PATH` (default `/v1/maintenance-records`).
- **Current behavior:** 20-second timeout; no automatic retry; optional Firebase ID-token auth defaults off. Client verifies response charger ID and only renders fields actually returned. Recommendations can only be passed through from a real fault result when present; no schedule is created.
- **Illustrative response:**

  ```json
  {
    "status": "available",
    "chargerIdentifier": "<exact requested id>",
    "records": [
      {
        "recordId": "<stable record id>",
        "recordType": "<backend-defined type>",
        "componentId": "<scoped component id or omitted>",
        "serviceDate": "<actual date or omitted>",
        "status": "<backend status or omitted>"
      }
    ]
  }
  ```

- **Validation proposal:** `empty` has an empty record list; records belong to the echoed charger. Require stable record IDs and define allowed types/status transitions/date timezone. Scheduling, work orders, service intervals, and recommendations need separate approved methods/policies; this read endpoint does not imply them.
- **Auth proposal:** decide technician/customer/admin scopes and record-level authorization. Protect record data by charger ownership/assignment.
- **Acceptance tests:** exact charger echo; empty and records response; wrong charger rejected; malformed fields rejected; permissions; pagination/sort if history grows; timeout, 404, 429, and 5xx; no fabricated dates or records.

### 7. Current-snapshot reports

- **Current implementation:** composed locally; no HTTP method or endpoint. Source data are selected charger, current inspection/fault state, derived health, and real maintenance response when configured. It does not persist snapshots or claim historical values.
- **Endpoint proposal:** none for current client-side display. If export/archive is requested later, define a separate versioned report persistence/export API with snapshot timestamp provenance, owner, charger identity, included-source provenance, retention, and access policy. Do not treat a generated-at timestamp as a measurement timestamp.
- **Acceptance tests:** existing composer/widget tests verify selected-charger filtering and unavailable/omitted values. A later persistence API needs authorization, idempotency, snapshot immutability, and cross-charger access tests.

## Environment configuration proposal

Existing repositories read compile-time `--dart-define` values, which are
embedded in the built app. Use separate build-pipeline configuration for
development, staging, and production, supplying only public service base URLs
and non-secret feature/auth switches. Never put API keys, Firebase service
account credentials, private keys, or static access tokens in Dart defines or
the mobile app. Firebase client configuration is not a substitute for server
authorization. Keep all URL values empty until the service owner supplies and
approves them; a blank value must stay unavailable and must not trigger a
network request.

Current/proposed keys:

| Service | Compile-time URL/path keys | Default |
| --- | --- | --- |
| AI recognition | `CHARGEX_AI_RECOGNITION_API_URL` (complete endpoint URL) | Empty; Phase 14 makes no request. |
| Digital Twin | `CHARGEX_DIGITAL_TWIN_API_URL` (complete registry URL) | Empty; Phase 14 makes no request. |
| Fault analysis | `CHARGEX_FAULT_API_BASE_URL`; fixed client path `/v1/fault-analysis` | Empty base URL. |
| RUL | `CHARGEX_RUL_API_BASE_URL`, `CHARGEX_RUL_API_PATH` | Empty base URL; proposed path `/v1/rul-analysis`. |
| Maintenance | `CHARGEX_MAINTENANCE_API_BASE_URL`, `CHARGEX_MAINTENANCE_API_PATH` | Empty base URL; proposed path `/v1/maintenance-records`. |

Require HTTPS in staging/production deployment checks. The current fault, RUL,
and maintenance URL validators allow HTTP for development; deployment policy
must prevent production HTTP configuration. No environment values or secrets
were added to this repository.

## Backend-team decisions needed before live integration

1. Service owners, deployed environment URLs, API versioning, DNS/TLS, service availability/SLO, and support contacts.
2. Final request/response schemas, identifier canonicalization, error codes, status codes, pagination, idempotency, and rate limits.
3. Firebase token project/audience, role/claim mapping, charger authorization, token refresh/expiry handling, and whether all services require auth.
4. AI accepted image formats/sizes, privacy/consent, retention, recognized-field requirements, and confidence semantics.
5. Twin lookup identity, model/variant/version policy, asset hosting/signed URL policy, component ID stability, and cache invalidation.
6. Fault taxonomy/severity meanings, evidence provenance, timestamp source, deterministic no-fault semantics, and response correlation to charger and component.
7. RUL data prerequisites, validated model/method, units/horizon/confidence, freshness, provenance, and insufficient-data policy.
8. Maintenance record schema, ownership, dates/timezones, allowed statuses, pagination, and whether scheduling/recommendation APIs are in scope.
9. Health/report persistence requirements, if any; these features currently have no remote API contract.
10. Backend contract tests or OpenAPI documents plus a non-production environment and representative, explicitly synthetic test fixtures.

No live integration should be enabled until the relevant contract is approved,
the backend is deployed in a non-production environment, auth and identity
checks pass, and the client has contract-focused tests against that agreed
schema.
