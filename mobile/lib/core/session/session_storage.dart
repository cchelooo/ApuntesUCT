import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The session controller only talks to this port; native persistence plugs in here.
abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class MemorySessionStorage implements SessionStorage {
  String? _value;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String value) async {
    _value = value;
  }

  @override
  Future<void> delete() async {
    _value = null;
  }
}

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => MemorySessionStorage(),
);
