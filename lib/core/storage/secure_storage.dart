import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../error/app_exception.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

abstract interface class LegacyPreferences {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

typedef SessionCredential = ({String token, int revision});

class _PlatformSecrets implements SecretStore {
  const _PlatformSecrets();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _Preferences implements LegacyPreferences {
  const _Preferences();
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String key, String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Preference write failed');
    }
  }

  @override
  Future<void> delete(String key) async {
    if (!await (await SharedPreferences.getInstance()).remove(key)) {
      throw StateError('Preference removal failed');
    }
  }
}

/// OS credentials, with verified legacy migration and no plaintext fallback.
final class SecureStorage {
  const SecureStorage({
    SecretStore secrets = const _PlatformSecrets(),
    LegacyPreferences preferences = const _Preferences(),
    this.namespace = '',
  }) : _secrets = secrets,
       _preferences = preferences;

  final SecretStore _secrets;
  final LegacyPreferences _preferences;
  final String namespace;
  static const _keys = ['jwt_token', 'user_email', 'anthropic_api_key'];
  static final _tails = <String, Future<void>>{};
  static final _credentialRevisions = <String, int>{};
  static final _suppressedCredentials = <String>{};
  int get _credentialRevision => _credentialRevisions[namespace] ?? 0;
  bool get credentialCleanupPending =>
      _suppressedCredentials.contains(namespace);
  void _advanceCredential() {
    _credentialRevisions[namespace] = _credentialRevision + 1;
  }

  void _suppressCredential() {
    _advanceCredential();
    _suppressedCredentials.add(namespace);
  }

  static const _unavailable = ServerException(
    'Secure storage is unavailable. Unlock your keyring and try again.',
  );
  String _key(String key) => namespace.isEmpty ? key : '$namespace::$key';

  // Shared per-namespace queue prevents migration/login/logout races. A failed
  // operation never poisons the queue or leaks a platform exception's contents.
  Future<T> _run<T>(Future<T> Function() action) async {
    final previous = _tails[namespace] ?? Future<void>.value();
    final completed = Completer<void>();
    _tails[namespace] = completed.future;
    try {
      await previous;
      return await action();
    } catch (_) {
      throw _unavailable;
    } finally {
      completed.complete();
      if (identical(_tails[namespace], completed.future)) {
        _tails.remove(namespace);
      }
    }
  }

  Future<void> _removeLegacy(String key) async {
    await _preferences.delete(key);
    if (await _preferences.read(key) != null) {
      throw StateError('Legacy removal was not confirmed');
    }
  }

  Future<void> _writeVerified(String key, String value) async {
    await _secrets.write(key, value);
    if (await _secrets.read(key) != value) {
      throw StateError('Secure write was not confirmed');
    }
  }

  Future<void> _migrate() async {
    for (final name in _keys) {
      if (name == 'jwt_token' && credentialCleanupPending) continue;
      final key = _key(name);
      final current = await _secrets.read(key);
      final legacy = await _preferences.read(key);
      if (legacy == null) continue;
      if (current == null) await _writeVerified(key, legacy);
      // Verified OS value wins over stale plaintext after a lost response.
      await _removeLegacy(key);
    }
  }

  Future<String?> _read(String name) => _run(() async {
    if (name == 'jwt_token' && credentialCleanupPending) return null;
    await _migrate();
    return _secrets.read(_key(name));
  });
  Future<void> _saveValue(String name, String value) async {
    final key = _key(name);
    final isCredential = name == 'jwt_token';
    final previousToken = isCredential ? await _secrets.read(key) : null;
    try {
      await _writeVerified(key, value);
      await _removeLegacy(key);
      await _migrate();
      if (isCredential) {
        _advanceCredential();
        _suppressedCredentials.remove(namespace);
      }
    } catch (_) {
      // Keep an old session's revision only when its bytes are still readable
      // and unchanged. A partly published replacement must not authenticate.
      if (isCredential && !await _stillContains(key, previousToken)) {
        _suppressCredential();
      }
      rethrow;
    }
  }

  Future<bool> _stillContains(String key, String? expected) async {
    try {
      return await _secrets.read(key) == expected;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save(String name, String value) =>
      _run(() => _saveValue(name, value));
  Future<void> saveToken(String token) => _save('jwt_token', token);
  Future<String?> getToken() => _read('jwt_token');
  Future<bool> hasToken() async {
    try {
      final token = await getToken();
      return token != null && token.isNotEmpty;
    } on AppException {
      // Bool-only router probe fails closed. Explicit operations still throw a
      // safe AppException for login; an inaccessible plaintext JWT is not used.
      return false;
    }
  }

  Future<void> _deleteCredentials() async {
    _suppressCredential();
    // Verify legacy removal first: migration must never resurrect a logout.
    // Also clear the dormant provider credential on account logout.
    for (final name in _keys) {
      await _removeLegacy(_key(name));
    }
    for (final name in _keys) {
      final key = _key(name);
      await _secrets.delete(key);
      if (await _secrets.read(key) != null) {
        throw StateError('Secure deletion was not confirmed');
      }
    }
    _suppressedCredentials.remove(namespace);
  }

  Future<void> deleteToken() => _run(_deleteCredentials);

  Future<SessionCredential?> readCredential() => _run(() async {
    if (credentialCleanupPending) return null;
    await _migrate();
    final token = await _secrets.read(_key('jwt_token'));
    if (token == null || token.isEmpty) return null;
    return (token: token, revision: _credentialRevision);
  });

  Future<bool> _matches(SessionCredential expected) async =>
      !credentialCleanupPending &&
      expected.revision == _credentialRevision &&
      expected.token == await _secrets.read(_key('jwt_token'));

  /// The snapshot and mutation share the existing per-namespace queue.
  Future<bool> deleteCredentialIfCurrent(
    SessionCredential expected, {
    void Function()? onMatch,
  }) => _run(() async {
    try {
      if (!await _matches(expected)) return false;
    } catch (_) {
      // Revision matched, but the platform cannot confirm the token.
      // Close the current local session even if deletion must wait.
      _suppressCredential();
      onMatch?.call();
      rethrow;
    }
    onMatch?.call();
    await _deleteCredentials();
    return true;
  });

  Future<bool> replaceCredentialIfCurrent(
    SessionCredential expected,
    String token,
  ) => _run(() async {
    if (!await _matches(expected)) return false;
    await _saveValue('jwt_token', token);
    return true;
  });
  Future<void> saveEmail(String email) => _save('user_email', email);
  Future<String?> getEmail() => _read('user_email');
  Future<void> saveAnthropicKey(String key) => _save('anthropic_api_key', key);
  Future<String?> getAnthropicKey() => _read('anthropic_api_key');
  Future<void> deleteAnthropicKey() => _run(() async {
    final key = _key('anthropic_api_key');
    await _removeLegacy(key);
    await _secrets.delete(key);
    if (await _secrets.read(key) != null) {
      throw StateError('Secure deletion was not confirmed');
    }
  });
}
