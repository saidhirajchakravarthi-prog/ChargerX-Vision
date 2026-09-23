import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/demo_repository.dart';

final demoRepositoryProvider = Provider<DemoRepository>((ref) {
  return const DemoRepository();
});
