# Phase 16 — Offline Integration Simulation and End-to-End Readiness

## Scope and status

This document describes the current local test setup and its limits. Offline
tests exercise client logic with deterministic fixtures/interceptors; passing
them does **not** prove that a live backend exists, is reachable, authorized,
or compatible with the proposed contracts. No live requests or production
credentials are used by this test plan.

## Service status and offline coverage

| Service | Current status | Offline coverage | Gaps/limits |
| --- | --- | --- | --- |
| Firebase Authentication | `FirebaseAuthService` calls `FirebaseAuth.instance`; route redirects use Firebase auth state. | No account-backed test; the app widget test uses a small test router and splash/login widgets. | Auth client is not injected, so isolated repository tests need an auth seam or Firebase Emulator configuration. Do not use real user accounts in unit tests. |
| AI recognition | Configured URL required; otherwise unavailable without a request. Not a confirmed backend. | Repository tests cover unconfigured/no-request, recognized, explicit no-match, and malformed success response. | Timeout and server failure UI are not comprehensive. No auth contract is established. |
| Component inspection / fault analysis | Configurable client boundary; no backend confirmed. | Intercepted Dio tests cover JSON/multipart request formation, fault/no-fault, malformed data, wrong component, timeout, unavailable server, and auth/server error mapping. Provider tests cover loading/duplicate requests and clearing stale highlighting on errors. | Fixtures are synthetic test inputs; they do not validate a real server schema or authorization rules. Current fault API contract still lacks a charger identity echo/check. |
| Digital Twin | Configured URL required; otherwise unavailable without a request. No live registry confirmed. | Tests cover typed model JSON parsing, intercepted repository success/query, unavailable/no-request, provider state, and charger-scoped fault highlighting. | Repository errors and backend asset hosting are not validated against a service. Model component IDs are not server-confirmed stable. |
| Health | Derived locally from current charger-associated inspection and fault state; no remote measurement. | Calculator/provider/widget tests cover no-fault, severity mapping, unavailable/missing identity, timestamps only when supplied, and another-charger isolation. | No time-series, sensor, or persistence testing because those data sources do not exist in this client. |
| RUL | Readiness/API boundary only; no live prediction service confirmed. | Contract/repository/provider/widget tests cover request shape, matching charger/component, unavailable/insufficient data, malformed values, timeout, missing auth token, and unauthorized/server errors. | No prediction quality, model, operational history, or production freshness can be tested offline. |
| Maintenance | Readiness/API boundary only; no live maintenance service confirmed. | Model/repository/provider/widget tests cover records/empty/unconfigured/malformed/timeout/network failure, charger matching, and unauthorized/server errors. | No schedules, work orders, dates, or recommendation policy are generated or tested as production behavior. |
| Current-snapshot reports | Composed locally from currently available app state; no report backend/cache/history. | Composer/widget tests cover unavailable sections, actual optional fields, timestamps not invented, and charger-scoped inspection/fault/health/maintenance data. | There is no historical snapshot or source cache. Test fixtures remain test-only and do not feed runtime report providers. |

Legacy `DemoRepository` and `*.demo()` model factories are present in the
repository. Source reference search found no use of them from feature screens,
providers, repositories, or the current-report composer; they are not part of
these integration tests or the current report path. HTTP fixtures are
constructed inside `test/` and injected through Dio interceptors/adapters.
No application response cache was found.

## Running offline tests

Run the full suite:

```sh
flutter test
```

Run service/reliability-focused tests:

```sh
flutter test test/features/ai_recognition test/features/inspection test/features/health test/features/maintenance test/features/reports test/features/rul test/digital_twin_test.dart
```

The HTTP-related tests return responses from in-process Dio interceptors or
`HttpClientAdapter` implementations. They do not contact the example hostnames
used as test configuration. Firebase tests must remain isolated from real
accounts; use a fakeable auth boundary or an explicitly configured Firebase
Emulator suite if auth behavior needs to be exercised.

## UI/data provenance rules

- A repository test fixture is mock data and stays in test code. It is never a
  runtime fallback or a current report source.
- A current response from a configured endpoint is not a cache. This app has no
  service response cache or offline synchronization storage in the audited
  service paths.
- Unconfigured/error/unavailable data must continue to render as unavailable;
  a failed request must not become no-fault, healthy, a report value, or a Twin
  fault highlight.
- The current UI does not display cache provenance because no cache exists.
  Current screens distinguish their documented unavailable/loading/error
  states; only add live/simulated badges if the runtime gains an explicit
  provenance value that can support that claim.
- Reports are labeled as current snapshots and are not historical reports or
  measurements.

## Known limitations

- Phase 14 endpoints and schemas remain design proposals pending backend
  approval. No service endpoint, backend capability, or account authorization
  policy has been confirmed.
- AI recognition and Digital Twin URLs are empty by default. Fault analysis,
  RUL, and maintenance also remain unavailable without supplied configuration.
- Firebase auth is coupled to the Firebase singleton in the service/router;
  unit tests do not sign in with real accounts and no emulator suite is
  configured here.
- Repository mock tests validate client branches, not TLS, DNS, deployment,
  Firebase token verification, charger access control, evidence retention,
  backend latency, or production data correctness.
- Offline tests passing does **not** prove a live backend integration works.

## Backend prerequisites before Phase 15 resumes

- An approved contract for one selected service, including identifier rules,
  exact request/response schemas, status/error behavior, and versioning.
- An authorized non-production endpoint supplied by its owner; do not use
  proposed/example URLs as if deployed.
- Documented Firebase token audience/claims and charger/component authorization
  requirements, or explicit confirmation that the endpoint is unauthenticated.
- Safe test identities or a documented emulator/non-production auth setup;
  never commit credentials or put private API keys in the Flutter client.
- Agreed timeout, retry/idempotency, rate-limit, evidence privacy/retention,
  and data provenance policies.
- A way to verify success and error cases and a backend owner/contact.

## Non-production integration checklist

- [ ] Backend owner has approved the selected service contract and schema.
- [ ] Non-production URL and TLS certificate are supplied through environment
      build configuration; no secret is embedded in the app.
- [ ] Auth policy and test-account/emulator setup are documented and authorized.
- [ ] Request includes a unique charger identity; component-level data includes
      stable component identity and the backend enforces access scope.
- [ ] Success responses echo and validate the requested charger/component IDs.
- [ ] No-fault, empty, insufficient-data, unavailable, malformed, 401/403,
      rate-limit, 5xx, timeout, and network-error cases are verified.
- [ ] Evidence upload privacy, size/type validation, and retention are checked
      without logging credentials or local file paths.
- [ ] Cache/live provenance and freshness behavior are explicitly defined;
      absent cache support is not described as cached data.
- [ ] Mocked unit tests pass separately from the explicitly identified real
      non-production integration checks.
- [ ] `flutter analyze` and the full `flutter test` suite pass after changes.
- [ ] Report results state exactly which checks were mocked and which reached
      the authorized non-production service.
