import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finish_recording_dialog.dart';
import 'record_notifier.dart';

final recordExitGuardProvider = Provider<RecordExitGuard>(RecordExitGuard.new);

class RecordExitGuard {
  RecordExitGuard(this._ref);

  final Ref _ref;
  Object? _confirmingRecording;

  bool canLeave(BuildContext context) {
    if (!_ref.exists(recordNotifierProvider)) return true;
    final state = _ref.read(recordNotifierProvider);
    if (state.status == RecordStatus.starting) return false;
    if (!state.isActive) return true;

    // Keep Record visible for finalization and upload errors. The same Stop
    // flow handles acceptance, while later navigation during upload is allowed.
    scheduleMicrotask(() {
      if (context.mounted) unawaited(confirmFinish(context));
    });
    return false;
  }

  Future<void> confirmFinish(BuildContext context) async {
    if (!context.mounted || !_ref.read(recordNotifierProvider).isActive) return;
    final notifier = _ref.read(recordNotifierProvider.notifier);
    final identity = notifier.recordingIdentity;
    if (identity == null || identical(_confirmingRecording, identity)) return;

    _confirmingRecording = identity;
    try {
      final confirmed = await _showConfirmation(context);
      if (confirmed == true &&
          context.mounted &&
          notifier.mounted &&
          identical(identity, notifier.recordingIdentity)) {
        await notifier.finishRecording(confirmed: true);
      }
    } finally {
      if (identical(_confirmingRecording, identity)) {
        _confirmingRecording = null;
      }
    }
  }

  Future<bool?> _showConfirmation(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<bool>(
      context: context,
      builder: (_) => const FinishRecordingDialog(),
    );
    final subscription = _ref.listen(recordNotifierProvider, (_, next) {
      if (!next.isActive) {
        // Logout or a capture failure can invalidate the dialog while it is
        // on the root Navigator. Dismiss only this particular route.
        scheduleMicrotask(() {
          if (navigator.mounted && route.isActive) {
            navigator.removeRoute(route, false);
          }
        });
      }
    });
    try {
      return await navigator.push(route);
    } finally {
      subscription.close();
    }
  }
}
