import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finish_recording_dialog.dart';
import 'discard_recording_dialog.dart';
import 'discard_recording_screen.dart';
import 'record_notifier.dart';

final recordExitGuardProvider = Provider<RecordExitGuard>(RecordExitGuard.new);

class RecordExitGuard {
  RecordExitGuard(this._ref);

  final Ref _ref;
  Object? _confirmingRecording;

  FutureOr<bool> canLeave(BuildContext context) {
    if (!_ref.exists(recordNotifierProvider)) return true;
    final state = _ref.read(recordNotifierProvider);
    if (state.status == RecordStatus.starting) return false;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      if (state.status == RecordStatus.preparing) return false;
      if (state.discardPending || state.isActive) {
        return confirmDiscard(context, leaving: true);
      }
      return true;
    }
    if (!state.isActive) return true;

    // Keep Record visible for finalization and upload errors. The same Stop
    // flow handles acceptance, while later navigation during upload is allowed.
    scheduleMicrotask(() {
      if (context.mounted) unawaited(confirmFinish(context));
    });
    return false;
  }

  /// Returns true only for the first, still-current intention after cleanup.
  /// GoRouter keeps that caller's original route/query/extra while awaiting it.
  Future<bool> confirmDiscard(
    BuildContext context, {
    bool leaving = false,
  }) async {
    if (!context.mounted || !_ref.exists(recordNotifierProvider)) return false;
    final notifier = _ref.read(recordNotifierProvider.notifier);
    final identity = notifier.recordingIdentity;
    final revision = notifier.recordingRevision;
    if (!notifier.canDiscard ||
        identity == null ||
        _confirmingRecording != null) {
      return false;
    }
    _confirmingRecording = identity;
    try {
      final confirmed = await _showDiscardConfirmation(
        context,
        identity,
        leaving,
      );
      if (confirmed != true ||
          !context.mounted ||
          !notifier.mounted ||
          !identical(identity, notifier.recordingIdentity)) {
        return false;
      }
      final discarded = await notifier.discardRecording(confirmed: true);
      return discarded &&
          notifier.mounted &&
          revision == notifier.recordingRevision;
    } finally {
      if (identical(_confirmingRecording, identity)) {
        _confirmingRecording = null;
      }
    }
  }

  Future<bool?> _showDiscardConfirmation(
    BuildContext context,
    Object identity,
    bool leaving,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final Route<bool> route = leaving
        ? MaterialPageRoute<bool>(
            fullscreenDialog: true,
            builder: (_) => const DiscardRecordingScreen(),
          )
        : DialogRoute<bool>(
            context: context,
            builder: (_) => const DiscardRecordingDialog(),
          );
    final subscription = _ref.listen(recordNotifierProvider, (_, __) {
      final notifier = _ref.read(recordNotifierProvider.notifier);
      if (!identical(identity, notifier.recordingIdentity) ||
          !notifier.canDiscard) {
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
