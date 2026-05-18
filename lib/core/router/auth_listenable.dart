import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_notifier.dart';

/// Bridges Riverpod [authNotifierProvider] to GoRouter's [refreshListenable].
/// GoRouter calls redirect() every time this notifier fires.
class AuthListenable extends ChangeNotifier {
  AuthListenable(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, __) => notifyListeners());
  }
}
