import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../../inspection/domain/models/inspection_history_record.dart';

final inspectionHistoryProvider = FutureProvider<List<InspectionHistoryRecord>>(
  (ref) async {
    final repository = await ref.watch(
      localInspectionRepositoryProvider.future,
    );
    return repository.getHistory();
  },
);
