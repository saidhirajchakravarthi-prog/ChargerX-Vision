import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';
import 'package:chargex_vision/features/chargers/domain/models/charger_model.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_component.dart';
import 'package:chargex_vision/features/digital_twin/domain/models/digital_twin_model.dart';
import 'package:chargex_vision/features/inspection/data/repositories/local_inspection_repository.dart';
import 'package:chargex_vision/features/inspection/domain/models/component_inspection.dart';
import 'package:chargex_vision/features/inspection/domain/models/evidence_source.dart';
import 'package:chargex_vision/features/inspection/domain/models/fault_result.dart';
import 'package:chargex_vision/features/inspection/domain/models/inspection_history_record.dart';

void main() {
  late Directory root;
  var nextId = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('chargex-persistence-test-');
    nextId = 0;
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  LocalInspectionRepository repository() => LocalInspectionRepository(
    directory: root,
    idGenerator: () => 'canonical-${nextId++}',
  );

  const component = DigitalTwinComponent(
    componentId: 'fan-1',
    componentType: 'fan',
    displayName: 'Cooling fan',
    assetNodeIdentifier: 'node-1',
    description: 'Cooling fan assembly',
  );
  const twin = DigitalTwinModel(
    twinId: 'twin-7',
    manufacturer: 'Example',
    chargerModel: 'Model X',
    chargerType: 'DC',
    assetReference: 'asset-x',
    version: 'v2',
    components: [component],
  );

  ComponentInspection inspection({
    EvidenceSourceData evidence = EvidenceSourceData.none,
    String status = 'fan overheating',
  }) => ComponentInspection.completed(
    component: component,
    evidenceSource: evidence,
    detectedCondition: status,
    timestamp: DateTime.utc(2026, 1, 1),
  );

  test(
    'canonical charger mapping links QR and serial and rejects conflicts',
    () async {
      final repo = repository();
      const serialOnly = ChargerModel(serialNumber: ' SN-1 ');
      const both = ChargerModel(serialNumber: 'SN-1', rawQrIdentifier: 'QR-1');
      const otherSerial = ChargerModel(
        serialNumber: 'SN-2',
        rawQrIdentifier: 'QR-2',
      );
      const conflicting = ChargerModel(
        serialNumber: 'SN-1',
        rawQrIdentifier: 'QR-2',
      );
      final first = await repo.resolveCanonicalChargerId(serialOnly);
      expect(await repo.resolveCanonicalChargerId(both), first);
      await repo.resolveCanonicalChargerId(otherSerial);
      await expectLater(
        repo.resolveCanonicalChargerId(conflicting),
        throwsA(isA<ChargerIdentityConflict>()),
      );
      await repo.close();
    },
  );

  test('history reloads after reopening and is ordered newest first', () async {
    var repo = repository();
    const charger = ChargerModel(serialNumber: 'S-1');
    final older = await repo.saveInspection(
      recordId: 'record-old',
      charger: charger,
      twin: twin,
      inspection: inspection(status: 'older'),
      provenance: InspectionProvenance.unknown,
      createdAt: DateTime.utc(2025),
    );
    await repo.saveInspection(
      recordId: 'record-new',
      charger: charger,
      twin: twin,
      inspection: inspection(status: 'newer'),
      fault: const FaultResult(faultType: 'overheating', componentId: 'fan-1'),
      provenance: InspectionProvenance.unknown,
      createdAt: DateTime.utc(2026),
    );
    await repo.close();

    repo = repository();
    final history = await repo.getHistory(
      canonicalChargerId: older.canonicalChargerId,
    );
    expect(history.map((record) => record.id), ['record-new', 'record-old']);
    expect(history.first.twinId, 'twin-7');
    expect(history.first.twinVersion, 'v2');
    expect(history.first.provenance, InspectionProvenance.unknown);
    expect(
      (await repo.getDetail('record-new'))?.fault?.faultType,
      'overheating',
    );
    await repo.close();
  });

  test(
    'repeated save with same ID does not duplicate or replace the record',
    () async {
      final repo = repository();
      const charger = ChargerModel(serialNumber: 'S-1');
      final first = await repo.saveInspection(
        recordId: 'same-id',
        charger: charger,
        twin: twin,
        inspection: inspection(status: 'first'),
      );
      final retry = await repo.saveInspection(
        recordId: 'same-id',
        charger: charger,
        twin: twin,
        inspection: inspection(status: 'retry'),
      );
      expect(retry.inspection.detectedCondition, 'first');
      expect((await repo.getHistory()).length, 1);
      expect(first.id, retry.id);
      await repo.close();
    },
  );

  test(
    'same component ID remains isolated between canonical chargers',
    () async {
      final repo = repository();
      final first = await repo.saveInspection(
        recordId: 'charger-a',
        charger: const ChargerModel(serialNumber: 'S-A'),
        twin: twin,
        inspection: inspection(status: 'fault A'),
      );
      final second = await repo.saveInspection(
        recordId: 'charger-b',
        charger: const ChargerModel(serialNumber: 'S-B'),
        twin: twin,
        inspection: inspection(status: 'no fault B'),
      );
      expect(first.canonicalChargerId, isNot(second.canonicalChargerId));
      expect(
        (await repo.getHistory(
          canonicalChargerId: first.canonicalChargerId,
        )).map((record) => record.inspection.detectedCondition),
        ['fault A'],
      );
      expect(
        (await repo.getHistory(
          canonicalChargerId: second.canonicalChargerId,
        )).map((record) => record.inspection.detectedCondition),
        ['no fault B'],
      );
      await repo.close();
    },
  );

  test(
    'copies evidence durably, shares duplicate bytes, and deletes safely',
    () async {
      final repo = repository();
      const charger = ChargerModel(serialNumber: 'S-1');
      final image = File('${root.path}${Platform.pathSeparator}picked.jpg');
      await image.writeAsBytes([1, 2, 3, 4]);
      final source = EvidenceSourceData(
        type: EvidenceSourceType.cameraImage,
        label: 'Camera image',
        metadata: {'path': image.path},
      );
      final first = await repo.saveInspection(
        recordId: 'image-one',
        charger: charger,
        twin: twin,
        inspection: inspection(evidence: source),
      );
      final second = await repo.saveInspection(
        recordId: 'image-two',
        charger: charger,
        twin: twin,
        inspection: inspection(evidence: source),
      );
      expect(first.evidenceFiles.single.path, isNot(image.path));
      expect(await repo.evidenceExists(first.evidenceFiles.single), isTrue);
      expect(
        first.evidenceFiles.single.sha256,
        second.evidenceFiles.single.sha256,
      );
      await repo.deleteInspection(first.id);
      expect(await repo.evidenceExists(second.evidenceFiles.single), isTrue);
      await repo.deleteInspection(second.id);
      expect(await repo.evidenceExists(second.evidenceFiles.single), isFalse);
      await repo.close();
    },
  );

  test(
    'missing identity, Twin identity and incomplete result are rejected',
    () async {
      final repo = repository();
      await expectLater(
        repo.saveInspection(
          recordId: 'missing-charger',
          charger: const ChargerModel(model: 'M'),
          twin: twin,
          inspection: inspection(),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.saveInspection(
          recordId: 'missing-twin',
          charger: const ChargerModel(serialNumber: 'S'),
          twin: const DigitalTwinModel(
            twinId: '',
            manufacturer: '',
            chargerModel: '',
            chargerType: '',
            assetReference: '',
            version: '',
          ),
          inspection: inspection(),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.saveInspection(
          recordId: 'pending',
          charger: const ChargerModel(serialNumber: 'S'),
          twin: twin,
          inspection: ComponentInspection(
            component: component,
            status: InspectionStatus.pending,
            statusMessage: 'pending',
          ),
        ),
        throwsArgumentError,
      );
      await repo.close();
    },
  );

  test(
    'future schema records are omitted and missing evidence is detectable',
    () async {
      final repo = repository();
      final image = File(p.join(root.path, 'evidence.jpg'));
      await image.writeAsBytes([9, 8, 7]);
      final record = await repo.saveInspection(
        recordId: 'with-image',
        charger: const ChargerModel(serialNumber: 'S-1'),
        twin: twin,
        inspection: inspection(
          evidence: EvidenceSourceData(
            type: EvidenceSourceType.cameraImage,
            label: 'Selected image',
            metadata: {'path': image.path},
          ),
        ),
      );
      await repo.close();

      final db = await databaseFactoryIo.openDatabase(
        p.join(root.path, 'inspection_history.db'),
      );
      await stringMapStoreFactory
          .store('inspection_history')
          .record('future')
          .put(db, {'schemaVersion': 999, 'id': 'future'});
      final modified = record.toJson()..['id'] = 'modified-verified';
      modified['provenance'] = InspectionProvenance.verifiedBackend.name;
      await stringMapStoreFactory
          .store('inspection_history')
          .record('modified-verified')
          .put(db, modified);
      await db.close();

      final reopened = repository();
      final history = await reopened.getHistory();
      expect(history.map((item) => item.id).toSet(), {
        'with-image',
        'modified-verified',
      });
      expect(
        history.firstWhere((item) => item.id == 'modified-verified').provenance,
        InspectionProvenance.unknown,
      );
      final savedImage = record.evidenceFiles.single;
      await File(savedImage.path).delete();
      expect(await reopened.evidenceExists(savedImage), isFalse);
      expect(await reopened.getDetail(record.id), isNotNull);
      await reopened.close();
    },
  );

  test(
    'verified provenance is rejected without trusted-source verification',
    () async {
      final repo = repository();
      await expectLater(
        repo.saveInspection(
          recordId: 'unverified-claim',
          charger: const ChargerModel(serialNumber: 'S-1'),
          twin: twin,
          inspection: inspection(),
          provenance: InspectionProvenance.verifiedBackend,
        ),
        throwsStateError,
      );
      await repo.close();
    },
  );

  test(
    'storage and missing-image failures do not create incomplete records',
    () async {
      final blocker = File(p.join(root.path, 'not-a-directory'));
      await blocker.writeAsString('block');
      final brokenRepository = LocalInspectionRepository(
        directory: Directory(blocker.path),
      );
      await expectLater(
        brokenRepository.saveInspection(
          recordId: 'storage-failure',
          charger: const ChargerModel(serialNumber: 'S-1'),
          twin: twin,
          inspection: inspection(),
        ),
        throwsA(isA<FileSystemException>()),
      );

      final repo = repository();
      await expectLater(
        repo.saveInspection(
          recordId: 'missing-image',
          charger: const ChargerModel(serialNumber: 'S-1'),
          twin: twin,
          inspection: inspection(
            evidence: const EvidenceSourceData(
              type: EvidenceSourceType.cameraImage,
              label: 'Selected photo',
              metadata: {'path': 'missing-image.jpg'},
            ),
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await repo.getHistory(), isEmpty);
      await repo.close();
    },
  );
}
