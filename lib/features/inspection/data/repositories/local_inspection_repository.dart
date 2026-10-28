import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import '../../../chargers/domain/models/charger_model.dart';
import '../../../digital_twin/domain/models/digital_twin_model.dart';
import '../../domain/models/component_inspection.dart';
import '../../domain/models/evidence_source.dart';
import '../../domain/models/fault_result.dart';
import '../../domain/models/inspection_history_record.dart';

class ChargerIdentityConflict implements Exception {
  const ChargerIdentityConflict();
  @override
  String toString() =>
      'The scanned serial and QR identifiers map to different chargers.';
}

class LocalInspectionRepository {
  LocalInspectionRepository({
    required this.directory,
    DatabaseFactory? databaseFactory,
    String Function()? idGenerator,
  }) : _factory = databaseFactory ?? databaseFactoryIo,
       _idGenerator = idGenerator ?? _randomId;

  final Directory directory;
  final DatabaseFactory _factory;
  final String Function() _idGenerator;
  Database? _database;

  static Future<LocalInspectionRepository> forApplication() async {
    final directory = await getApplicationSupportDirectory();
    return LocalInspectionRepository(
      directory: Directory(p.join(directory.path, 'chargex_vision')),
    );
  }

  String generateRecordId() => _idGenerator();

  static final _records = stringMapStoreFactory.store('inspection_history');
  static final _aliases = stringMapStoreFactory.store(
    'charger_identity_aliases',
  );
  static final _pendingDeletes = stringMapStoreFactory.store(
    'pending_evidence_deletes',
  );

  Future<Database> _db() async {
    final existing = _database;
    if (existing != null) return existing;
    await directory.create(recursive: true);
    final opened = await _factory.openDatabase(
      p.join(directory.path, 'inspection_history.db'),
      version: 1,
    );
    _database = opened;
    return opened;
  }

  Map<String, String> _identifiers(ChargerModel charger) {
    final serial = charger.serialNumber?.trim();
    final qr = charger.rawQrIdentifier?.trim();
    return {
      if (serial != null && serial.isNotEmpty) 'serial': serial,
      if (qr != null && qr.isNotEmpty)
        'qr': 'sha256:${sha256.convert(utf8.encode(qr)).toString()}',
    };
  }

  String _aliasKey(String type, String value) => '$type:$value';

  InspectionHistoryRecord _decodeStored(Map<String, Object?> json) {
    final record = InspectionHistoryRecord.fromJson(json);
    if (record.provenance == InspectionProvenance.verifiedBackend ||
        record.provenance == InspectionProvenance.verifiedDevice) {
      return record.copyWith(provenance: InspectionProvenance.unknown);
    }
    return record;
  }

  Future<String> resolveCanonicalChargerId(ChargerModel charger) async {
    final identifiers = _identifiers(charger);
    if (identifiers.isEmpty) {
      throw ArgumentError('A serial number or QR identifier is required.');
    }
    final db = await _db();
    return db.transaction((transaction) async {
      final found = <String>{};
      for (final entry in identifiers.entries) {
        final value = await _aliases
            .record(_aliasKey(entry.key, entry.value))
            .get(transaction);
        if (value?['canonicalChargerId'] case final String id) {
          found.add(id);
        }
      }
      if (found.length > 1) throw const ChargerIdentityConflict();
      final canonical = found.isEmpty ? _idGenerator() : found.single;
      for (final entry in identifiers.entries) {
        final key = _aliasKey(entry.key, entry.value);
        final old = await _aliases.record(key).get(transaction);
        if (old != null && old['canonicalChargerId'] != canonical) {
          throw const ChargerIdentityConflict();
        }
        await _aliases.record(key).put(transaction, {
          'canonicalChargerId': canonical,
          'type': entry.key,
          'value': entry.value,
        });
      }
      return canonical;
    });
  }

  Future<InspectionHistoryRecord> saveInspection({
    required String recordId,
    required ChargerModel charger,
    required DigitalTwinModel twin,
    required ComponentInspection inspection,
    FaultResult? fault,
    InspectionProvenance provenance = InspectionProvenance.unknown,
    DateTime? createdAt,
  }) async {
    if (recordId.trim().isEmpty) throw ArgumentError('recordId is required.');
    if (twin.twinId.trim().isEmpty || twin.version.trim().isEmpty) {
      throw ArgumentError('A Digital Twin ID and version are required.');
    }
    if (inspection.status != InspectionStatus.completed &&
        inspection.status != InspectionStatus.noFaultDetected) {
      throw ArgumentError('Only completed inspection results can be saved.');
    }
    if (provenance == InspectionProvenance.verifiedBackend ||
        provenance == InspectionProvenance.verifiedDevice) {
      throw StateError(
        'This client has no configured trusted-source verifier; verified provenance cannot be assigned.',
      );
    }
    if (fault != null &&
        fault.componentId != inspection.component.componentId) {
      throw ArgumentError('Fault and inspection component IDs must match.');
    }

    final canonicalId = await resolveCanonicalChargerId(charger);
    final db = await _db();
    final existing = await _records.record(recordId).get(db);
    if (existing != null) {
      final old = _decodeStored(existing);
      if (old.canonicalChargerId != canonicalId ||
          old.component.componentId != inspection.component.componentId ||
          old.twinId != twin.twinId ||
          old.twinVersion != twin.version) {
        throw StateError(
          'The record ID is already used by a different inspection.',
        );
      }
      return old;
    }

    final now = DateTime.now().toUtc();
    final timestamp = (createdAt ?? now).toUtc();
    final evidenceFiles = <InspectionEvidenceFile>[];
    final durablePaths = <String, String>{};
    final evidenceSources = [
      inspection.evidenceSource,
      ...?fault?.evidenceSources,
    ];
    for (final sourceEvidence in evidenceSources) {
      if (sourceEvidence.type != EvidenceSourceType.cameraImage) continue;
      final sourcePath = sourceEvidence.metadata['path'];
      if (sourcePath is! String || sourcePath.trim().isEmpty) {
        throw ArgumentError(
          'Camera evidence must reference a readable local image.',
        );
      }
      if (durablePaths.containsKey(sourcePath)) continue;
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw FileSystemException(
          'Selected evidence image is missing.',
          sourcePath,
        );
      }
      final bytes = await source.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      final evidenceDirectory = Directory(p.join(directory.path, 'evidence'));
      await evidenceDirectory.create(recursive: true);
      final target = File(p.join(evidenceDirectory.path, hash));
      if (!await target.exists()) {
        await target.writeAsBytes(bytes, flush: true);
      }
      durablePaths[sourcePath] = target.path;
      if (!evidenceFiles.any((file) => file.sha256 == hash)) {
        evidenceFiles.add(
          InspectionEvidenceFile(
            sha256: hash,
            path: target.path,
            originalName: p.basename(source.path),
            byteLength: bytes.length,
          ),
        );
      }
    }

    EvidenceSourceData retainSource(EvidenceSourceData value) {
      final metadata = Map<String, dynamic>.from(value.metadata);
      final sourcePath = metadata['path'];
      if (sourcePath is String) {
        final durablePath = durablePaths[sourcePath];
        if (durablePath == null) {
          metadata.remove('path');
        } else {
          metadata['path'] = durablePath;
        }
      }
      return value.copyWith(metadata: metadata);
    }

    final storedInspection = inspection.copyWith(
      evidenceSource: retainSource(inspection.evidenceSource),
    );
    final storedFault = fault?.copyWith(
      evidenceSources: fault.evidenceSources.map(retainSource).toList(),
    );

    final record = InspectionHistoryRecord(
      id: recordId,
      canonicalChargerId: canonicalId,
      chargerIdentifiers: _identifiers(charger),
      twinId: twin.twinId,
      twinVersion: twin.version,
      component: inspection.component,
      inspection: storedInspection,
      fault: storedFault,
      provenance: provenance,
      createdAt: timestamp,
      updatedAt: now,
      evidenceFiles: evidenceFiles,
    );
    try {
      await _records.record(recordId).put(db, record.toJson());
    } catch (_) {
      // Content-addressed image files are safe to leave as recoverable orphans.
      rethrow;
    }
    return record;
  }

  Future<List<InspectionHistoryRecord>> getHistory({
    String? canonicalChargerId,
  }) async {
    final db = await _db();
    await _retryPendingDeletes(db);
    final snapshots = await _records.find(
      db,
      finder: Finder(
        sortOrders: [SortOrder('createdAt', false), SortOrder('id')],
      ),
    );
    final result = <InspectionHistoryRecord>[];
    for (final snapshot in snapshots) {
      try {
        final record = _decodeStored(snapshot.value);
        if (canonicalChargerId == null ||
            record.canonicalChargerId == canonicalChargerId) {
          result.add(record);
        }
      } on Object {
        // Malformed records are omitted instead of being treated as verified data.
      }
    }
    return result;
  }

  Future<InspectionHistoryRecord?> getDetail(String recordId) async {
    final db = await _db();
    final raw = await _records.record(recordId).get(db);
    if (raw == null) return null;
    try {
      return _decodeStored(raw);
    } on Object {
      return null;
    }
  }

  Future<bool> evidenceExists(InspectionEvidenceFile evidence) =>
      File(evidence.path).exists();

  Future<void> deleteInspection(String recordId) async {
    final db = await _db();
    final existing = await _records.record(recordId).get(db);
    if (existing == null) return;
    final record = _decodeStored(existing);
    final filesToDelete = <InspectionEvidenceFile>[];
    for (final evidence in record.evidenceFiles) {
      final all = await _records.find(db);
      final referenced = all.any((snapshot) {
        if (snapshot.key == recordId) return false;
        final rawFiles = snapshot.value['evidenceFiles'];
        return rawFiles is List &&
            rawFiles.any(
              (item) => item is Map && item['sha256'] == evidence.sha256,
            );
      });
      if (!referenced) filesToDelete.add(evidence);
    }
    await db.transaction((transaction) async {
      await _records.record(recordId).delete(transaction);
      for (final evidence in filesToDelete) {
        await _pendingDeletes
            .record(evidence.sha256)
            .put(transaction, evidence.toJson());
      }
    });
    final failedDeletes = await _retryPendingDeletes(db);
    if (filesToDelete.any((file) => failedDeletes.contains(file.sha256))) {
      throw FileSystemException(
        'Inspection removed, but evidence cleanup is pending and will be retried.',
        p.join(directory.path, 'evidence'),
      );
    }
  }

  Future<Set<String>> _retryPendingDeletes(Database db) async {
    final pending = await _pendingDeletes.find(db);
    final failed = <String>{};
    for (final entry in pending) {
      try {
        final evidence = InspectionEvidenceFile.fromJson(entry.value);
        final file = File(evidence.path);
        if (await file.exists()) await file.delete();
        await _pendingDeletes.record(entry.key).delete(db);
      } on FileSystemException {
        // Keep the pending row so a later load/delete can retry cleanup.
        failed.add(entry.key);
      } on Object {
        // A malformed queue entry is retained for diagnosis, not guessed at.
      }
    }
    return failed;
  }

  Future<void> updateInspection(InspectionHistoryRecord record) async {
    final db = await _db();
    final existing = await _records.record(record.id).get(db);
    if (existing == null) throw StateError('Inspection record not found.');
    final previous = _decodeStored(existing);
    if (record.provenance == InspectionProvenance.verifiedBackend ||
        record.provenance == InspectionProvenance.verifiedDevice) {
      throw StateError('No trusted-source verifier is configured.');
    }
    if (previous.canonicalChargerId != record.canonicalChargerId ||
        previous.component.componentId != record.component.componentId ||
        previous.twinId != record.twinId ||
        previous.twinVersion != record.twinVersion) {
      throw StateError('Inspection identity cannot be changed during update.');
    }
    final updated = InspectionHistoryRecord(
      id: record.id,
      canonicalChargerId: record.canonicalChargerId,
      chargerIdentifiers: record.chargerIdentifiers,
      twinId: record.twinId,
      twinVersion: record.twinVersion,
      component: record.component,
      inspection: record.inspection,
      fault: record.fault,
      provenance: record.provenance,
      createdAt: record.createdAt,
      updatedAt: DateTime.now().toUtc(),
      evidenceFiles: record.evidenceFiles,
    );
    final newHashes = updated.evidenceFiles.map((file) => file.sha256).toSet();
    final removed = <InspectionEvidenceFile>[];
    for (final evidence in previous.evidenceFiles) {
      if (newHashes.contains(evidence.sha256)) continue;
      final snapshots = await _records.find(db);
      final shared = snapshots.any((snapshot) {
        if (snapshot.key == record.id) return false;
        final files = snapshot.value['evidenceFiles'];
        return files is List &&
            files.any(
              (item) => item is Map && item['sha256'] == evidence.sha256,
            );
      });
      if (!shared) removed.add(evidence);
    }
    await db.transaction((transaction) async {
      await _records.record(record.id).put(transaction, updated.toJson());
      for (final evidence in removed) {
        await _pendingDeletes
            .record(evidence.sha256)
            .put(transaction, evidence.toJson());
      }
    });
    final failedDeletes = await _retryPendingDeletes(db);
    if (removed.any((file) => failedDeletes.contains(file.sha256))) {
      throw FileSystemException(
        'Inspection updated, but prior evidence cleanup is pending.',
        p.join(directory.path, 'evidence'),
      );
    }
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  static String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

final localInspectionRepositoryProvider =
    FutureProvider<LocalInspectionRepository>((ref) async {
      final repository = await LocalInspectionRepository.forApplication();
      ref.onDispose(repository.close);
      return repository;
    });
