import 'package:dio/dio.dart';
import 'auth_interceptor.dart';
import '../storage/secure_storage.dart';

Dio createDio({required String baseUrl, required SecureStorage storage}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(storage),
    LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (_) {}, // в prod отключаем вывод в консоль
    ),
  ]);

  return dio;
}
