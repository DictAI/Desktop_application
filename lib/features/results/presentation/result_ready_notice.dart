import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/providers.dart';
import '../data/pending_job_store.dart';
import 'processing_notifier.dart';
import 'result_detail_notifier.dart';
import 'result_detail_screen.dart';

/// A session-local view of the existing tracker, with no requests or timers.
/// Reading a result or dismissing its notice acknowledges only that exact job.
final class ResultReadyNoticeController
    extends StateNotifier<List<ProcessingJob>> {
  ResultReadyNoticeController({
    required ProcessingNotifier tracker,
    required String ownerId,
    required bool Function() isCurrentSession,
    required bool Function(ProcessingKey) isDeleted,
  }) : _ownerId = ownerId,
       _isCurrentSession = isCurrentSession,
       _isDeleted = isDeleted,
       super(const []) {
    _removeTrackerListener = tracker.addListener(_progressChanged);
  }

  final String _ownerId;
  final bool Function() _isCurrentSession;
  final bool Function(ProcessingKey) _isDeleted;
  late final void Function() _removeTrackerListener;
  final _acknowledged = <ProcessingKey>{};
  Map<ProcessingKey, ProcessingJob> _ready = const {};
  bool _closed = false;

  bool get _current => mounted && !_closed && _isCurrentSession();

  void _progressChanged(Map<ProcessingKey, JobProgress> jobs) {
    if (!_current) {
      stopSession();
      return;
    }
    _ready = {
      for (final entry in jobs.entries)
        if (entry.value.canonicalReady &&
            entry.value.job.ownerId == _ownerId &&
            !_isDeleted(entry.key))
          entry.key: entry.value.job,
    };
    _publish();
  }

  void _publish() {
    final next = [
      for (final entry in _ready.entries)
        if (!_acknowledged.contains(entry.key)) entry.value,
    ];
    if (next.length == state.length &&
        Iterable<int>.generate(
          next.length,
        ).every((index) => next[index].key == state[index].key)) {
      return;
    }
    state = List.unmodifiable(next);
  }

  bool canOpen(ProcessingKey key) =>
      _current && _ready.containsKey(key) && !_isDeleted(key);

  void acknowledge(ProcessingKey key) {
    if (!canOpen(key)) return;
    _acknowledged.add(key);
    _publish();
  }

  void stopSession() {
    if (_closed) return;
    _closed = true;
    _ready = const {};
    _acknowledged.clear();
    if (mounted) state = const [];
  }

  @override
  void dispose() {
    _removeTrackerListener();
    stopSession();
    super.dispose();
  }
}

/// Kept inside the authenticated iOS shell. Its action uses the normal router,
/// so cancelling the recording exit guard leaves the notice available.
class ResultReadyNoticeHost extends ConsumerWidget {
  const ResultReadyNoticeHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(batchSessionProvider).asData?.value;
    final router = GoRouter.of(context);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      child: child,
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.hasBoundedHeight
                    ? constraints.maxHeight / 2
                    : double.infinity,
              ),
              child: SingleChildScrollView(
                child: session == null || !session.isCurrent
                    ? const SizedBox.shrink()
                    : _SessionReadyNotice(
                        key: ValueKey(session),
                        session: session,
                        uri: router.routerDelegate.currentConfiguration.uri,
                      ),
              ),
            ),
            // Keep this element in the same slot as notices/session change.
            // RecordScreen owns an elapsed clock and must never be remounted
            // merely because another job finished.
            Expanded(child: child!),
          ],
        ),
      ),
    );
  }
}

class _SessionReadyNotice extends ConsumerWidget {
  const _SessionReadyNotice({
    super.key,
    required this.session,
    required this.uri,
  });
  final BatchSession session;
  final Uri uri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = resultReadyNoticeProvider(session);
    final notices = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ProcessingKey? viewed;
    final path = uri.pathSegments;
    if (path.length == 2 && path.first == 'results') {
      final audioId = path[1];
      final requestedJob = uri.queryParameters['job_id'];
      // The detail provider resolves a URL without job_id once. Share that
      // resolved identity rather than hiding every job of the same recording.
      final detail = ref.watch(
        resultDetailNotifierProvider((
          session: session,
          audioId: audioId,
          jobId: requestedJob,
        )),
      );
      final jobId = detail.jobId ?? requestedJob;
      if (jobId != null) viewed = (audioId: audioId, jobId: jobId);
    }
    if (viewed != null && notices.any((job) => job.key == viewed)) {
      final key = viewed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.acknowledge(key);
      });
    }
    ProcessingJob? notice;
    for (final job in notices) {
      if (job.key != viewed && controller.canOpen(job.key)) {
        notice = job;
        break;
      }
    }
    if (notice == null || !session.isCurrent) return const SizedBox.shrink();
    final ready = notice;
    return Material(
      key: const Key('result-ready-notice'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: TextButton.icon(
                  onPressed: () {
                    if (!session.isCurrent || !controller.canOpen(ready.key)) {
                      return;
                    }
                    context.go(
                      resultDetailLocation(ready.audioId, jobId: ready.jobId),
                    );
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Транскрипт готов. Открыть'),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Скрыть уведомление о транскрипте',
              onPressed: () => controller.acknowledge(ready.key),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
