import 'package:flutter/widgets.dart';

/// Foreground availability for network/UI work. This observer never changes
/// capture state: an active iOS recording may continue while the app is hidden.
class IosLifecycleObserver extends ChangeNotifier with WidgetsBindingObserver {
  IosLifecycleObserver({WidgetsBinding? binding})
    : _binding = binding ?? WidgetsBinding.instance {
    _isForeground =
        _binding.lifecycleState == null ||
        _binding.lifecycleState == AppLifecycleState.resumed;
    _binding.addObserver(this);
  }

  final WidgetsBinding _binding;
  late bool _isForeground;
  bool _disposed = false;

  bool get isForeground => _isForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isForeground) return;
    _isForeground = foreground;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _binding.removeObserver(this);
    super.dispose();
  }
}
