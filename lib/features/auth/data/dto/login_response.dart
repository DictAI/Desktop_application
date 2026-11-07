class LoginResponse {
  final String token;

  const LoginResponse({required this.token});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    if (token is! String || token.trim().isEmpty) {
      throw const FormatException('Invalid login response');
    }
    return LoginResponse(token: token);
  }
}
