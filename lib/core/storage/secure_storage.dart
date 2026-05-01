import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class SecureStorage {
  static const _tokenKey = 'jwt_token';

  final FlutterSecureStorage _storage;
  const SecureStorage(this._storage);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<bool> hasToken() async => (await getToken()) != null;
}
