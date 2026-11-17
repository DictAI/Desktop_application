import 'package:flutter/material.dart';

/// A separate confirmation page; opening it does not alter capture state.
class DiscardRecordingScreen extends StatelessWidget {
  const DiscardRecordingScreen({super.key});

  void _close(BuildContext context, bool confirmed) {
    if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context, confirmed);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => _close(context, false)),
      title: const Text('Отменить запись?'),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Чтобы выйти, отмените текущую запись. Она будет удалена без отправки.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _close(context, false),
                  child: const Text('Остаться'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: Colors.red.shade300,
                  ),
                  onPressed: () => _close(context, true),
                  child: const Text(
                    'Отменить запись и выйти',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
