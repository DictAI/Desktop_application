import 'dart:io';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs in the real macOS Runner, then exits. Never uses production key names.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Give the desktop engine a frame while asynchronous plugin calls run.
  runApp(const SizedBox.shrink());
  const namespace = String.fromEnvironment(
    'DICTAI_SMOKE_NAMESPACE',
    defaultValue: 'dictai.fe04.smoke.manual',
  );
  final phase =
      Platform.environment['DICTAI_SMOKE_PHASE'] ??
      const String.fromEnvironment('DICTAI_SMOKE_PHASE', defaultValue: 'write');
  if (!namespace.startsWith('dictai.fe04.smoke.')) {
    stdout.writeln('DICTAI_KEYCHAIN_SMOKE FAIL invalid namespace');
    exit(2);
  }
  const storage = SecureStorage(namespace: namespace);
  SharedPreferences? loadedPreferences;
  var checkpoint = 'preferences';
  const fixtures = {
    'jwt_token': 'synthetic-smoke-token',
    'user_email': 'smoke@example.invalid',
    'anthropic_api_key': 'synthetic-smoke-provider',
  };
  try {
    stdout.writeln('DICTAI_KEYCHAIN_SMOKE START $phase');
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 5),
    );
    loadedPreferences = prefs;
    checkpoint = 'keychain';
    if (phase == 'write' || phase == 'denied' || phase == 'stale') {
      for (final entry in fixtures.entries) {
        final value = phase == 'stale' ? 'synthetic-stale' : entry.value;
        if (!await prefs.setString('$namespace::${entry.key}', value)) {
          throw StateError('Fixture preparation failed');
        }
      }
    }
    if (phase == 'denied') {
      final denied = _DeniedWrites();
      final migration = SecureStorage(secrets: denied, namespace: namespace);
      var rejected = false;
      try {
        await migration.getToken();
      } on AppException {
        rejected = true;
      }
      if (!rejected ||
          !denied.sawNativeAccessDenial ||
          !fixtures.entries.every(
            (e) => prefs.getString('$namespace::${e.key}') == e.value,
          ) ||
          await const FlutterSecureStorage().read(
                key: '$namespace::jwt_token',
              ) !=
              null) {
        throw StateError('Native denial did not preserve legacy credentials');
      }
      // Keep only our synthetic plaintext fixtures for a separate-process retry.
    } else if (phase == 'write' || phase == 'restart' || phase == 'stale') {
      if (await storage.getToken() != fixtures['jwt_token'] ||
          await storage.getEmail() != fixtures['user_email'] ||
          await storage.getAnthropicKey() != fixtures['anthropic_api_key'] ||
          fixtures.keys.any((key) => prefs.containsKey('$namespace::$key'))) {
        throw StateError('Smoke verification failed');
      }
    } else if (phase == 'delete' || phase == 'empty') {
      if (phase == 'delete') await storage.deleteToken();
      if (await storage.getToken() != null ||
          await storage.getEmail() != null ||
          await storage.getAnthropicKey() != null ||
          fixtures.keys.any((key) => prefs.containsKey('$namespace::$key'))) {
        throw StateError('Smoke cleanup failed');
      }
    } else {
      throw StateError('Unknown smoke phase');
    }
    stdout.writeln('DICTAI_KEYCHAIN_SMOKE PASS $phase');
    exit(0);
  } catch (_) {
    final prefs = loadedPreferences;
    final expectsLegacy = {'write', 'denied', 'stale'}.contains(phase);
    final preserved = expectsLegacy && prefs != null
        ? fixtures.entries.every(
            (e) =>
                prefs.getString('$namespace::${e.key}') ==
                (phase == 'stale' ? 'synthetic-stale' : e.value),
          )
        : null;
    stdout.writeln(
      'DICTAI_KEYCHAIN_SMOKE FAIL $phase '
      'checkpoint=$checkpoint legacy_preserved=${preserved ?? 'not_applicable'}',
    );
    // Cleanup only our synthetic namespace, never any user key/preferences.
    for (final key in fixtures.keys) {
      await prefs?.remove('$namespace::$key');
    }
    try {
      await storage.deleteToken().timeout(const Duration(seconds: 5));
    } catch (_) {}
    exit(1);
  }
}

/// Real OS calls: read uses the normal group; write requests a group absent
/// from this app's entitlements. No keychain is locked or user data modified.
final class _DeniedWrites implements SecretStore {
  static const _normal = FlutterSecureStorage();
  static const _unentitled = FlutterSecureStorage(
    mOptions: MacOsOptions(groupId: 'dictai.fe04.smoke.unentitled'),
  );
  bool sawNativeAccessDenial = false;

  @override
  Future<String?> read(String key) => _normal.read(key: key);

  @override
  Future<void> write(String key, String value) async {
    try {
      await _unentitled.write(key: key, value: value);
    } on PlatformException catch (error) {
      // Pinned macOS plugin forwards OSStatus as details. -34018 is
      // errSecMissingEntitlement; never print raw platform exception contents.
      sawNativeAccessDenial = error.details == -34018;
      rethrow;
    }
  }

  @override
  Future<void> delete(String key) => _normal.delete(key: key);
}
