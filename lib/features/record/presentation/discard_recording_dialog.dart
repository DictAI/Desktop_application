import 'package:flutter/material.dart';

class DiscardRecordingDialog extends StatelessWidget {
  const DiscardRecordingDialog({super.key});

  void _close(BuildContext context, bool confirmed) {
    if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context, confirmed);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    title: const Text('Удалить запись?'),
    content: const Text(
      'Текущая запись будет удалена без отправки. Восстановить её не получится.',
    ),
    actions: [
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => _close(context, false),
        child: const Text('Оставить запись'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          minimumSize: const Size(48, 48),
        ),
        onPressed: () => _close(context, true),
        child: const Text('Удалить'),
      ),
    ],
  );
}
