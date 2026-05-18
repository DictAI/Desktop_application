class LoginResponse {
  final String token;

  const LoginResponse({required this.token});

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      LoginResponse(token: json['token'] as String);
}
