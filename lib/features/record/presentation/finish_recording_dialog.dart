import 'package:flutter/material.dart';

class FinishRecordingDialog extends StatelessWidget {
  const FinishRecordingDialog({super.key});

  void _close(BuildContext context, bool confirmed) {
    if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context, confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Завершить запись?'),
      content: const Text('Готовый WAV будет отправлен на обработку.'),
      actions: [
        TextButton(
          onPressed: () => _close(context, false),
          child: const Text('Продолжить запись'),
        ),
        FilledButton(
          onPressed: () => _close(context, true),
          child: const Text('Завершить и отправить'),
        ),
      ],
    );
  }
}
