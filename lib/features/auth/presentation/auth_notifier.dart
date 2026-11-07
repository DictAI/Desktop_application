import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/providers/providers.dart';
import '../data/auth_api.dart';
import '../data/dto/login_request.dart';
import '../data/dto/register_request.dart';

enum AuthStatus { idle, loading, success, error, expired }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({this.status = AuthStatus.idle, this.errorMessage});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api, this._storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const AuthState());

  final AuthApi _api;
  final SecureStorage _storage;
  final DateTime Function() _now;
  Timer? _renewal;
  Timer? _expiration;
  int? _scheduledRevision;
  int _operation = 0;
  bool _locallySignedOut = false;
  bool _refreshing = false;
  static const _lead = Duration(minutes: 5);
  static const _expired = AuthState(
    status: AuthStatus.expired,
    errorMessage: 'Срок действия сессии истёк. Войдите снова.',
  );

  bool _current(int operation) => mounted && _operation == operation;

  Future<bool> hasValidSession() async {
    if (_locallySignedOut) return false;
    final operation = _operation;
    try {
      final credential = await _storage.readCredential();
      if (!_current(operation) || _locallySignedOut || credential == null) {
        return false;
      }
      final claims = _claims(credential.token);
      if (claims == null || !claims.expiration.isAfter(_now())) {
        unawaited(_expire(credential));
        return false;
      }
      _schedule(credential, claims.expiration);
      return true;
    } on AppException {
      return false;
    }
  }

  Future<void> login({
    required String email,
    required String password,
    required VoidCallback onSuccess,
  }) async {
    if (state.status == AuthStatus.loading) return;
    final operation = ++_operation;
    state = const AuthState(status: AuthStatus.loading);
    try {
      final response = await _api.login(
        LoginRequest(email: email.trim(), password: password),
      );
      if (!_current(operation)) return;
      final claims = _claims(response.token);
      if (claims == null || !claims.expiration.isAfter(_now())) {
        throw const ValidationException(
          'Сервер выдал недействительную сессию.',
        );
      }
      await _storage.saveEmail(email.trim());
      if (!_current(operation)) return;
      await _storage.saveToken(response.token);
    } on AppException catch (error) {
      if (_current(operation)) {
        final rejected =
            error is ApiFailure &&
            {
              ApiFailureKind.unauthorized,
              ApiFailureKind.notFound,
            }.contains(error.kind);
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: rejected
              ? 'Не удалось войти. Проверьте email и пароль.'
              : error.message,
        );
      }
      return;
    }
    if (!_current(operation)) return;
    _locallySignedOut = false;
    state = const AuthState(status: AuthStatus.success);
    onSuccess();
  }

  Future<void> register({
    required String email,
    required String password,
    required VoidCallback onSuccess,
  }) async {
    if (state.status == AuthStatus.loading) return;
    final operation = ++_operation;
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _api.register(
        RegisterRequest(email: email.trim(), password: password),
      );
    } on AppException catch (error) {
      if (_current(operation)) {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: error.message,
        );
      }
      return;
    }
    if (!_current(operation)) return;
    state = const AuthState();
    onSuccess();
  }

  Future<void> logout() async {
    final operation = ++_operation;
    _locallySignedOut = true;
    _clearTimers();
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _storage.deleteToken();
      if (_current(operation)) state = const AuthState();
    } on AppException catch (error) {
      if (_current(operation)) {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: error.message,
        );
      }
    }
  }

  // A matched 401 already deleted the credential. A newer login may have won
  // while this notification was being delivered.
  Future<void> sessionExpired() async {
    final operation = _operation;
    try {
      if (await _storage.readCredential() != null) return;
    } on AppException {
      return;
    }
    if (_current(operation) &&
        !_locallySignedOut &&
        state.status != AuthStatus.loading) {
      _locallySignedOut = true;
      _clearTimers();
      state = _storage.credentialCleanupPending
          ? const AuthState(
              status: AuthStatus.expired,
              errorMessage:
                  'Сессия закрыта. Проверьте доступ к защищённому хранилищу, чтобы очистить сохранённые данные.',
            )
          : _expired;
    }
  }

  Future<void> _expire(SessionCredential credential) async {
    final operation = _operation;
    try {
      if (await _storage.deleteCredentialIfCurrent(credential) &&
          _current(operation) &&
          !_locallySignedOut &&
          state.status != AuthStatus.loading) {
        _locallySignedOut = true;
        _clearTimers();
        state = _expired;
      }
    } on AppException catch (error) {
      if (_current(operation) &&
          !_locallySignedOut &&
          state.status != AuthStatus.loading) {
        _locallySignedOut = true;
        _clearTimers();
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: error.message,
        );
      }
    }
  }

  void _schedule(SessionCredential credential, DateTime expiresAt) {
    if (_scheduledRevision == credential.revision) return;
    _clearTimers();
    _scheduledRevision = credential.revision;
    final remaining = expiresAt.difference(_now());
    _expiration = Timer(remaining, () => unawaited(_expire(credential)));
    _renewal = Timer(
      remaining > _lead ? remaining - _lead : Duration.zero,
      () => unawaited(refreshSession()),
    );
  }

  /// Single proactive attempt while the token remains valid. The expiry timer
  /// still applies when refresh fails. A 401 never launches a refresh or retry.
  Future<void> refreshSession() async {
    if (_refreshing ||
        _locallySignedOut ||
        state.status == AuthStatus.loading) {
      return;
    }
    _refreshing = true;
    final operation = _operation;
    try {
      final credential = await _storage.readCredential();
      if (!_current(operation) || credential == null) return;
      final claims = _claims(credential.token);
      if (claims == null || !claims.expiration.isAfter(_now())) return;
      final response = await _api.refresh();
      if (!_current(operation) || !claims.expiration.isAfter(_now())) return;
      final replacement = _claims(response.token);
      if (replacement == null ||
          replacement.userId != claims.userId ||
          !replacement.expiration.isAfter(claims.expiration) ||
          !replacement.expiration.isAfter(_now().add(_lead))) {
        return;
      }
      if (await _storage.replaceCredentialIfCurrent(
            credential,
            response.token,
          ) &&
          _current(operation)) {
        await hasValidSession();
      }
    } on AppException catch (error) {
      // A confirmed unchanged credential retains its expiry timer.
      if (_current(operation) && _storage.credentialCleanupPending) {
        _locallySignedOut = true;
        _clearTimers();
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: error.message,
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  void clearError() {
    if (state.status != AuthStatus.loading && state.errorMessage != null) {
      state = const AuthState();
    }
  }

  void _clearTimers() {
    _renewal?.cancel();
    _expiration?.cancel();
    _scheduledRevision = null;
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }
}

/// Unverified local hints for routing and renewal. The gateway verifies JWTs.
({String userId, DateTime expiration})? _claims(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) return null;
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (claims is! Map || claims['iss'] != 'dictai-auth-v2') return null;
    final audience = claims['aud'];
    if (audience != 'dictai-user' &&
        !(audience is List && audience.contains('dictai-user'))) {
      return null;
    }
    final userId = claims['user_id'];
    final expiration = claims['exp'];
    if (userId is! String ||
        userId.trim().isEmpty ||
        expiration is! int ||
        expiration < 0 ||
        expiration > 8640000000000) {
      return null;
    }
    return (
      userId: userId,
      expiration: DateTime.fromMillisecondsSinceEpoch(
        expiration * 1000,
        isUtc: true,
      ),
    );
  } on FormatException {
    return null;
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final notifier = AuthNotifier(
    ref.read(authApiProvider),
    ref.read(secureStorageProvider),
  );
  ref.listen(
    sessionNotifierProvider,
    (_, _) => unawaited(notifier.sessionExpired()),
  );
  return notifier;
});
