sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkException extends AppException {
  const NetworkException(super.message);
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException()
      : super('Session expired. Please log in again.');
}

final class ValidationException extends AppException {
  const ValidationException(super.message);
}

final class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

final class ServerException extends AppException {
  const ServerException(super.message);
}

/// Выбрасывается методами, для которых backend-эндпоинт ещё не реализован.
/// UI должен показывать информационный баннер, а не crash.
final class StubException extends AppException {
  const StubException(super.message);
}
