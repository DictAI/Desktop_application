import 'dart:convert';
import 'dart:io';

import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/auth/data/auth_api.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/workspace/data/workspace_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Explicit native test target only. Never launched by the production entrypoint.
const _phases = {
  'write',
  'restart',
  'legacy_delete',
  'empty',
  'https_untrusted',
  'https',
  'auth_register_login',
  'auth_restart',
  'auth_logout',
};
const _fixtures = {
  'jwt_token': 'synthetic-ios-session-token',
  'user_email': 'ios-smoke@example.invalid',
  'anthropic_api_key': 'synthetic-ios-session-provider',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('DictAI session verification')),
    ),
  );
  late final _SmokeConfiguration configuration;
  try {
    configuration = await _SmokeConfiguration.load().timeout(
      const Duration(seconds: 10),
    );
  } catch (_) {
    stdout.writeln(
      'DICTAI_IOS_SESSION FAIL invalid_configuration source_unavailable',
    );
    exit(2);
  }
  final phase = configuration.phase;
  final namespace = configuration.namespace;
  final phaseSupported = _phases.contains(phase);
  final namespaceValid = RegExp(
    r'^dictai\.ios\.session\.smoke\.[A-Za-z0-9_.-]{1,64}$',
  ).hasMatch(namespace);
  if (!Platform.isIOS || !phaseSupported || !namespaceValid) {
    stdout.writeln(
      'DICTAI_IOS_SESSION FAIL invalid_configuration '
      'ios=${Platform.isIOS} phase_present=${phase.isNotEmpty} '
      'phase_supported=$phaseSupported namespace_present=${namespace.isNotEmpty} '
      'namespace_valid=$namespaceValid',
    );
    exit(2);
  }

  final smoke = _SessionSmoke(
    namespace,
    credentialsPath: configuration.credentialsPath,
  );
  stdout.writeln('DICTAI_IOS_SESSION START $phase');
  try {
    await smoke.run(phase).timeout(const Duration(seconds: 90));
    stdout.writeln('DICTAI_IOS_SESSION PASS $phase');
    exit(0);
  } catch (_) {
    // Never print exceptions, response bodies, file paths or credentials.
    stdout.writeln(
      'DICTAI_IOS_SESSION FAIL $phase checkpoint=${smoke.checkpoint}',
    );
    exit(1);
  }
}

final class _SessionSmoke {
  _SessionSmoke(this.namespace, {this.credentialsPath});

  final String namespace;
  final String? credentialsPath;
  String checkpoint = 'configuration';
  SecureStorage get storage => SecureStorage(namespace: namespace);

  Future<void> run(String phase) async {
    if (phase.startsWith('auth_')) {
      await _auth(phase);
      return;
    }
    if (phase == 'https' || phase == 'https_untrusted') {
      await _https(expectUntrusted: phase == 'https_untrusted');
      return;
    }

    checkpoint = 'preferences';
    final prefs = await SharedPreferences.getInstance();
    checkpoint = 'keychain';
    if (phase == 'write') {
      await storage.deleteToken();
      for (final entry in _fixtures.entries) {
        _require(await prefs.setString(_key(entry.key), entry.value));
      }
      await _expectFixtures(prefs);
    } else if (phase == 'restart') {
      await _expectFixtures(prefs);
    } else if (phase == 'legacy_delete') {
      await storage.deleteToken();
      const oldStorage = FlutterSecureStorage();
      for (final entry in _fixtures.entries) {
        await oldStorage.write(key: _key(entry.key), value: entry.value);
      }
      // Reads in the pinned plugin intentionally ignore accessibility.
      await _expectFixtures(prefs);
      await storage.deleteToken();
      await _expectEmpty(storage, prefs, namespace);
    } else if (phase == 'empty') {
      await _expectEmpty(storage, prefs, namespace);
    }
  }

  String _key(String name) => '$namespace::$name';

  Future<void> _expectFixtures(SharedPreferences prefs) async {
    _require(await storage.getToken() == _fixtures['jwt_token']);
    _require(await storage.getEmail() == _fixtures['user_email']);
    _require(await storage.getAnthropicKey() == _fixtures['anthropic_api_key']);
    _require(_fixtures.keys.every((name) => !prefs.containsKey(_key(name))));
  }

  Future<void> _expectEmpty(
    SecureStorage target,
    SharedPreferences prefs,
    String targetNamespace,
  ) async {
    _require(await target.getToken() == null);
    _require(await target.getEmail() == null);
    _require(await target.getAnthropicKey() == null);
    for (final name in _fixtures.keys) {
      _require(!prefs.containsKey('$targetNamespace::$name'));
      _require(
        await const FlutterSecureStorage().read(
              key: '$targetNamespace::$name',
            ) ==
            null,
      );
    }
  }

  Future<void> _https({required bool expectUntrusted}) async {
    checkpoint = 'https_configuration';
    final config = AppConfig.fromEnvironment();
    _require(config.gateway.scheme == 'https');
    final publicStorage = SecureStorage(namespace: '$namespace.https');
    // This namespace is only used for this credential-free root probe.
    await publicStorage.deleteToken();
    final dio = createDio(
      baseUrl: config.baseUrl,
      appConfig: config,
      storage: publicStorage,
    );
    try {
      checkpoint = 'https_request';
      try {
        final response = await dio.head<Object?>(
          '/',
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (status) =>
                status != null && status >= 100 && status < 600,
          ),
        );
        _require(!expectUntrusted && response.statusCode != null);
      } on DioException catch (error) {
        if (!expectUntrusted ||
            !(error.type == DioExceptionType.badCertificate ||
                error.error is HandshakeException)) {
          rethrow;
        }
      }
    } finally {
      dio.close(force: true);
    }
  }

  Future<void> _auth(String phase) async {
    checkpoint = 'auth_configuration';
    final config = AppConfig.fromEnvironment();
    _require(config.gateway.scheme == 'https');
    final credentials = await _Credentials.load(config, credentialsPath);
    final authStorage = SecureStorage(namespace: '$namespace.auth');
    late AuthNotifier auth;
    final dio = createDio(
      baseUrl: config.baseUrl,
      appConfig: config,
      storage: authStorage,
      onUnauthorized: () => auth.sessionExpired(),
    );
    auth = AuthNotifier(AuthApi(dio), authStorage);
    try {
      if (phase == 'auth_register_login') {
        await authStorage.deleteToken();
        checkpoint = 'register';
        var registered = false;
        await auth.register(
          email: credentials.email,
          password: credentials.password,
          onSuccess: () => registered = true,
        );
        _require(registered && auth.state.status == AuthStatus.idle);
        checkpoint = 'login';
        var loggedIn = false;
        await auth.login(
          email: credentials.email,
          password: credentials.password,
          onSuccess: () => loggedIn = true,
        );
        _require(loggedIn && auth.state.status == AuthStatus.success);
      }

      checkpoint = 'restored_session';
      _require(await auth.hasValidSession());
      _require(await authStorage.getEmail() == credentials.email);
      if (phase == 'auth_logout') {
        checkpoint = 'logout';
        await auth.logout();
        _require(auth.state.status == AuthStatus.idle);
        _require(!await auth.hasValidSession());
        await _expectEmpty(
          authStorage,
          await SharedPreferences.getInstance(),
          '$namespace.auth',
        );
        checkpoint = 'signed_out_request';
        var denied = false;
        try {
          await WorkspaceApi(dio).getWorkspaces();
        } on ApiFailure catch (error) {
          denied = error.kind == ApiFailureKind.unauthorized;
        }
        _require(denied);
      } else {
        checkpoint = 'protected_read';
        await WorkspaceApi(dio).getWorkspaces();
      }
    } finally {
      auth.dispose();
      dio.close(force: true);
    }
  }
}

final class _Credentials {
  const _Credentials(this.email, this.password);
  final String email;
  final String password;

  static Future<_Credentials> load(AppConfig config, String? path) async {
    _require(path != null && path.isNotEmpty);
    final bytes = await _readBoundedFile(File(path!));
    final data = jsonDecode(utf8.decode(bytes));
    _require(data is Map<String, dynamic>);
    final object = data as Map<String, dynamic>;
    final endpoint = object['endpoint'];
    final email = object['email'];
    final password = object['password'];
    _require(endpoint is String && email is String && password is String);
    _require(
      AppConfig.parse(apiBaseUrl: endpoint as String).gateway == config.gateway,
    );
    _require((email as String).isNotEmpty && email.trim() == email);
    _require((password as String).length >= 8);
    return _Credentials(email, password);
  }
}

final class _SmokeConfiguration {
  const _SmokeConfiguration(this.phase, this.namespace, this.credentialsPath);

  final String phase;
  final String namespace;
  final String? credentialsPath;

  static Future<_SmokeConfiguration> load() async {
    final phase = Platform.environment['DICTAI_IOS_SMOKE_PHASE'] ?? '';
    final namespace = Platform.environment['DICTAI_IOS_SMOKE_NAMESPACE'] ?? '';
    if (phase.isNotEmpty || namespace.isNotEmpty) {
      // A partial environment is an error, not a reason to use a stale file.
      _require(phase.isNotEmpty && namespace.isNotEmpty);
      return _SmokeConfiguration(
        phase,
        namespace,
        Platform.environment['DICTAI_IOS_SMOKE_CREDENTIALS_PATH'],
      );
    }

    final support = await getApplicationSupportDirectory();
    final bytes = await _readBoundedFile(
      File('${support.path}/dictai-ios-session-smoke.json'),
    );
    final data = jsonDecode(utf8.decode(bytes));
    _require(data is Map<String, dynamic>);
    final object = data as Map<String, dynamic>;
    final filePhase = object['phase'];
    final fileNamespace = object['namespace'];
    final credentialsPath = object['credentialsPath'];
    _require(filePhase is String && fileNamespace is String);
    _require(credentialsPath == null || credentialsPath is String);
    return _SmokeConfiguration(
      filePhase as String,
      fileNamespace as String,
      credentialsPath as String?,
    );
  }
}

Future<List<int>> _readBoundedFile(File file) async {
  final bytes = await file
      .openRead(0, 4097)
      .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk))
      .timeout(const Duration(seconds: 5));
  _require(bytes.isNotEmpty && bytes.length <= 4096);
  return bytes;
}

void _require(bool value) {
  if (!value) throw StateError('Smoke assertion failed');
}
