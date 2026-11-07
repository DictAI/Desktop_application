import 'package:flutter/foundation.dart';

/// Only public settings; credentials never belong in compiled defines.
final class AppConfig {
  AppConfig._(this.gateway, this.networkDiagnostics);
  factory AppConfig.fromEnvironment() => AppConfig.parse(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    allowInsecureLocalhost: const bool.fromEnvironment(
      'ALLOW_INSECURE_LOCALHOST',
    ),
    enableNetworkDiagnostics: const bool.fromEnvironment('HTTP_DIAGNOSTICS'),
  );
  factory AppConfig.parse({
    required String apiBaseUrl,
    bool allowInsecureLocalhost = false,
    bool enableNetworkDiagnostics = false,
    bool isDebugBuild = kDebugMode,
  }) {
    final uri = Uri.tryParse(apiBaseUrl);
    if (apiBaseUrl.isEmpty ||
        apiBaseUrl.trim() != apiBaseUrl ||
        uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const FormatException(
        'Set API_BASE_URL to a gateway origin without credentials, path, query or fragment.',
      );
    }
    final local = {'localhost', '127.0.0.1', '::1', '[::1]'}.contains(uri.host);
    if (uri.scheme != 'https' &&
        !(kDebugMode && isDebugBuild && allowInsecureLocalhost && local)) {
      throw const FormatException(
        'HTTPS is required. HTTP is allowed only for explicit debug loopback development.',
      );
    }
    return AppConfig._(
      Uri.parse(uri.origin),
      kDebugMode && isDebugBuild && enableNetworkDiagnostics,
    );
  }
  final Uri gateway;
  final bool networkDiagnostics;
  String get baseUrl => gateway.origin;
  static const connectTimeout = Duration(seconds: 10);
  static const requestTimeout = Duration(seconds: 30);
  static const uploadTimeout = Duration(minutes: 15);
  static const downloadTimeout = Duration(minutes: 15);
  void checkTarget(Uri target) {
    if (target.userInfo.isNotEmpty ||
        target.hasFragment ||
        target.scheme != gateway.scheme ||
        target.host != gateway.host ||
        target.port != gateway.port) {
      throw const GatewayPolicyException();
    }
  }
}

final class GatewayPolicyException implements Exception {
  const GatewayPolicyException();
  String get message => 'The request must use the configured gateway origin.';
  @override
  String toString() => message;
}
