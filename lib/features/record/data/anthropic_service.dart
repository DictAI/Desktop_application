import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/storage/secure_storage.dart';

class AnthropicService {
  static const _model = 'claude-opus-4-5';

  final SecureStorage _storage;
  AnthropicService(this._storage);

  Future<String?> getApiKey() => _storage.getAnthropicKey();
  Future<void> saveApiKey(String key) => _storage.saveAnthropicKey(key.trim());
  Future<void> deleteApiKey() => _storage.deleteAnthropicKey();

  Future<String> send(List<Map<String, String>> messages) async {
    final apiKey = await _storage.getAnthropicKey();
    if (apiKey == null || apiKey.isEmpty) {
      return '__NO_KEY__';
    }

    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.anthropic.com',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/v1/messages',
        data: jsonEncode({
          'model': _model,
          'max_tokens': 1024,
          'system':
              'You are a helpful AI assistant built into a meeting recording '
              'and transcription app. Be concise and helpful.',
          'messages': messages,
        }),
      );
      final content = response.data?['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) return 'No response.';
      return (content.first as Map<String, dynamic>)['text'] as String? ??
          'No response.';
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) return '__INVALID_KEY__';
      final msg = (e.response?.data as Map?)?['error']?['message'];
      return 'Error: ${msg ?? e.message ?? 'Unknown error'}';
    }
  }
}
