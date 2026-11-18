import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Explicit platform double for Flutter unit/widget tests only.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  FlutterSecureStorage.setMockInitialValues({});
  await testMain();
}
