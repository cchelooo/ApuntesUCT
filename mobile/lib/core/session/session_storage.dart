import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

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

/// One atomic value, scoped to the Gateway, never SharedPreferences or a file.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage, String? gatewayUrl})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          ),
      key =
          'apuntesuct.session.v1.${base64Url.encode(utf8.encode((gatewayUrl ?? ApiConfig.gatewayBaseUrl).replaceFirst(RegExp(r'/$'), ''))).replaceAll('=', '')}';
  final FlutterSecureStorage _storage;
  final String key;
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) async {
    await _storage.write(key: key, value: value);
    if (await read() != value) {
      throw StateError('No se pudo confirmar el guardado seguro.');
    }
  }

  @override
  Future<void> delete() async {
    await _storage.delete(key: key);
    if (await read() != null) {
      throw StateError('No se pudo confirmar el borrado seguro.');
    }
  }
}

/// Browser demos keep credentials only in memory; native apps use secure storage.
final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => kIsWeb ? MemorySessionStorage() : SecureSessionStorage(),
);
