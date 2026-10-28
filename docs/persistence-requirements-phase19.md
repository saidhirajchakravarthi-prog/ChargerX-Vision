# Phase 19 — Persistence Requirements and Implementation Plan

## Status

This document records the Phase 19 decisions and implemented local persistence
design. Inspection history is device-owned and local. This does not add cloud
synchronization or historical reports.

## Confirmed Phase 19 product decisions

- Inspection records must provide history (not only a latest snapshot).
- Ownership is device-based. Firebase sign-out must retain locally stored
  records; records are not scoped to a Firebase UID.
- Charger and Digital Twin identities must be canonical and consistently
  linked.
- Evidence images must be retained with persisted records.
- Storage and data handling must remain local; cloud synchronization and
  server-side persistence are out of scope.

Implementation choices made to satisfy these decisions are recorded below.

## Baseline behavior before Phase 19 implementation

- `ComponentInspectionNotifier` owns `faultsByChargerComponent` and
  `inspectionsByChargerComponent` in Riverpod memory. The maps are keyed by
  `(chargerKey, componentId)`. `build()` starts with empty state, so records do
  not survive process/app restart.
- `chargerIdentityKey` prefers a trimmed serial (`serial:<value>`) and falls
  back to a trimmed raw QR value (`qr:<value>`). A model name is not used as
  identity; absent serial and QR produce no key. The code does not establish
  that serial and QR values are canonical, immutable, globally unique, or
  interchangeable across scans.
- `DigitalTwinComponent` has a component ID but no registry/twin ID or model
  version. The Phase 17 key therefore does not distinguish component namespace
  changes when a twin/model definition changes.
- `ComponentInspection` and `FaultResult` provide JSON conversion. An
  inspection serializes the component ID and status/result fields but not the
  full twin component; deserialization requires a caller-supplied component.
  Fault and evidence JSON includes optional evidence metadata and timestamps.
  Neither record currently carries an explicit live/mock/cached provenance
  marker or persistence timestamp.
- The inspection provider stores completed/no-fault outcomes in memory when it
  has a charger key. A real no-fault result removes the active fault only for
  that charger/component key. Failed, pending, unavailable, and service-not-
  connected outcomes are not eligible as completed fault snapshots, though
  the current in-memory display state can hold them.
- `selectedChargerProvider` starts as `null`; selection is not restored.
- Firebase Authentication is accessed through `FirebaseAuth.instance`. The
  service supports registration, login, sign-out, reset email, and verification
  flows. No account deletion flow or persistence cleanup policy is present.
- `CurrentReportComposer` and `currentChargerReportProvider` compose a current
  snapshot from current in-memory providers. There is no report archive,
  generated snapshot ID, historical report, or persisted snapshot. After app
  restart, inspection/fault state is empty and the report cannot restore the
  prior snapshot.
- `pubspec.yaml` currently includes Flutter/Riverpod, Firebase Core/Auth, Dio,
  scanner and image picker dependencies; no local database, preferences, or
  secure-storage package is present. Phase 14/16 documentation says no
  application cache or backend persistence contract has been confirmed.

## Implemented local persistence

- `sembast` stores versioned JSON-like history records and charger alias
  mappings in one database. `path_provider` resolves the application support
  directory on Android, iOS, Windows, macOS, and Linux. Sembast's IO database
  factory uses a durable filesystem file on these native platforms.
- Database path: `<application support>/chargex_vision/inspection_history.db`.
  Evidence path: `<application support>/chargex_vision/evidence/`.
- There is no web implementation; the selected IO database and file APIs are
  native-only. No platform build/device verification is claimed yet.
- Storage is inside the OS app-private application support area. This phase
  adds no custom encryption and makes no at-rest encryption claim. OS backup
  behavior is platform-controlled and has not been disabled; depending on
  device/platform settings, local data may be included in backups. Files are
  not uploaded or synchronized by this feature.
- Inspection history is retained until explicit record deletion. No automatic
  age/count pruning is implemented. The History screen provides detail display
  and deletion; shared content-addressed evidence is removed only after the
  last referencing inspection is deleted.
- Each record stores a random local canonical charger ID, identifier mapping,
  Digital Twin ID/version, complete component metadata, inspection and optional
  fault result, provenance, source timestamp in the model, local creation and
  update timestamps, and evidence metadata/references.
- Serial and QR inputs are trimmed and case-preserved. Alias keys are
  type-separated; raw QR values are represented by SHA-256 digests in stored
  alias/record mappings rather than persisted as full QR payloads. When both
  aliases already point to different canonical IDs, resolution fails with an
  explicit conflict; the app does not merge them. A previously unseen alias
  can be linked to an existing canonical ID only when another supplied alias
  resolves unambiguously.
- Twin ID and version are required for saving and restoring a record. The
  current Digital Twin state is now associated with the charger key used to
  load it; an unrelated charger's Twin cannot be attached to a saved result.
- Camera images are copied from picker paths into durable app-support storage,
  named by SHA-256 content digest, and referenced from the record. Repeated
  identical image content shares one file. Missing source images fail the save
  instead of leaving a dangling “retained” reference. No image size limit or
  compression policy is currently applied.
- A stable record ID makes repository save retries idempotent. History sorts by
  creation time descending, then record ID. Update/delete APIs preserve
  identity; evidence deletion uses a pending-delete store so failed file cleanup
  can be retried. Missing evidence is surfaced in record details. Malformed or
  unsupported-schema records are omitted from history without altering stored
  bytes; database-open failures appear as unavailable history.
- Schema version is `1`; the database version is `1`. There are no pre-Phase-19
  persisted records to migrate. No automatic migration from a future/unknown
  schema is attempted. Future upgrades must add an explicit migration before
  changing the record schema.
- Firebase logout only signs out of Firebase and does not clear the local
  repository. The repository stores no Firebase credentials, passwords, ID
  tokens, or account-scoped cloud data.
- Provenance is stored as `verifiedBackend`, `verifiedDevice`, `simulated`, or
  `unknown`. Existing app paths do not prove that a configured endpoint is an
  approved/trusted source, and no trusted device source is integrated. The
  workflow therefore saves completed outcomes as `unknown`; repository writes
  reject verified provenance until a trusted-source verifier exists. History
  shows provenance explicitly. A local/demo result must not be promoted to
  verified by presentation code.
- Reports remain current-snapshot reports. They are not converted into
  historical reports by the inspection history store.

## Implementation policies and remaining limitations

- History is retained indefinitely until a user deletes a record. There is no
  bulk-delete control or age/count pruning. Individual deletion is available.
- Canonical charger IDs are random local IDs. Serial aliases are trimmed and
  case-preserved; raw QR aliases are trimmed and hashed before storage. The
  app links aliases only when provided together or when an alias already maps
  unambiguously. Conflicts fail with an error and are never merged. There is no
  UI for manually resolving an existing alias conflict.
- Digital Twin ID plus version is the component-history namespace. Records
  from older Twin versions remain in history but are not restored into the
  active inspection state for a different version.
- The target is Android, iOS, Windows, macOS, and Linux. Web is not supported
  by this persistence implementation. Storage uses OS app-private application
  support directories with no custom encryption. OS backup behavior is not
  configured by this phase.
- Selected image originals are copied without resizing or compression. There
  is no configured maximum size. QR alias hashes reduce plain-text exposure,
  but the local database still contains serial numbers and inspection data.
- Source/backend timestamps remain in the inspection/fault model when
  supplied. `createdAt` and `updatedAt` are local UTC persistence times. No
  clock-skew correction is implemented. No trusted source is currently
  configured, so completed results remain `unknown`; verified provenance is
  rejected by the repository.
- Unknown/corrupt individual records are omitted without being rewritten. The
  database is schema version 1 and has no migration from pre-existing
  persistence. Database-level corruption results in unavailable history; no
  automatic reset is performed.
- Cloud sync and historical report generation remain out of scope.

## Persistence API and recovery behavior

The `LocalInspectionRepository` is exposed through a Riverpod `FutureProvider`
and accepts an injected directory/database factory for isolated tests. Save
requires stable charger identifiers, a Twin ID/version, and a completed or
explicit no-fault result. Pending, unavailable, failed, and unscoped outcomes
are rejected. Records restored into inspection state are identified in the UI
as local history, not fresh backend results.

Record deletion commits the database change and queues unshared image files
for cleanup. If deleting a file fails, the inspection is gone but its cleanup
remains pending; the UI reports the partial failure and a later history load
retries. Corrupt individual rows are not activated. A corrupt database is
reported as unavailable and is not automatically reset or deleted.

## Verification and current limitations

Offline unit/widget tests verify local repository behavior, but they do not
verify platform encryption (none is implemented), operating-system backup
behavior, native plugin builds on all five platforms, or any live backend.
Passing tests cannot establish that a configured backend/device source is
trusted.

## Known limitations and next work

This implementation intentionally uses unencrypted app-private local files as
approved. Review OS backup settings and the platform threat model before
deployment. There is no image size/compression limit, no recovery UI for a
corrupt database beyond an unavailable message, and no migration from schemas
other than version 1. Verified provenance remains unavailable until a
documented trusted backend/device signal is integrated. Device-level manual
verification is still needed on Android, iOS, Windows, macOS, and Linux.
