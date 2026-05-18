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
      requestBody: true,
      responseBody: true,
      error: true,
      // ignore: avoid_print
      logPrint: (o) => print('[DIO] $o'),
    ),
  ]);

  return dio;
}
