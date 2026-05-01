import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/providers/providers.dart';
import '../data/auth_api.dart';
import '../data/dto/login_request.dart';
import '../data/dto/register_request.dart';

// ─── State ───────────────────────────────────────────────────────────────────

enum AuthStatus { idle, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({this.status = AuthStatus.idle, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) => AuthState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApi _api;
  final SecureStorage _storage;

  AuthNotifier(this._api, this._storage) : super(const AuthState());

  Future<void> login({
    required String email,
    required String password,
    required VoidCallback onSuccess,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _api.login(
        LoginRequest(email: email.trim(), password: password),
      );
      await _storage.saveToken(response.token);
      state = state.copyWith(status: AuthStatus.success);
      onSuccess();
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required VoidCallback onSuccess,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _api.register(RegisterRequest(email: email.trim(), password: password));
      state = state.copyWith(status: AuthStatus.idle);
      onSuccess();
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    }
  }

  Future<void> logout() async {
    await _storage.deleteToken();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(status: AuthStatus.idle, errorMessage: null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authApiProvider),
    ref.read(secureStorageProvider),
  );
});
