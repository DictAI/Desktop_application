import 'package:shared_preferences/shared_preferences.dart';

/// Stores the JWT token, user email and Anthropic API key in SharedPreferences.
final class SecureStorage {
  static const _tokenKey      = 'jwt_token';
  static const _emailKey      = 'user_email';
  static const _anthropicKey  = 'anthropic_api_key';

  const SecureStorage();

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
  }

  Future<bool> hasToken() async => (await getToken()) != null;

  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<void> saveAnthropicKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_anthropicKey, key);
  }

  Future<String?> getAnthropicKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_anthropicKey);
  }

  Future<void> deleteAnthropicKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_anthropicKey);
  }
}
