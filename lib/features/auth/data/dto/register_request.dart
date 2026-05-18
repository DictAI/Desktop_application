class RegisterRequest {
  final String email;
  final String password;

  const RegisterRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}
