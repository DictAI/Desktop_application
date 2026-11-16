import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../record/data/dto/pending_upload.dart';
import '../data/dto/result_dto.dart';
import 'processing_notifier.dart';
import 'results_notifier.dart';

typedef OpenResult = void Function(String audioId, String jobId);

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, this.onOpen});

  /// The result detail route supplies this when it is registered.
  final OpenResult? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(batchSessionProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message(
          text: _safeMessage(error, 'Не удалось открыть результаты.'),
          onRetry: () => ref.invalidate(batchSessionProvider),
        ),
        data: (session) => session.isCurrent
            ? _Library(key: ValueKey(session), session: session, onOpen: onOpen)
            : const Center(child: CircularProgressIndicator()),
      );
}

class _Library extends ConsumerStatefulWidget {
  const _Library({super.key, required this.session, this.onOpen});

  final BatchSession session;
  final OpenResult? onOpen;

  @override
  ConsumerState<_Library> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<_Library>
    with WidgetsBindingObserver {
  bool _wasAway = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.session.isCurrent) {
        ref
            .read(resultsNotifierProvider(widget.session).notifier)
            .openLibrary();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _wasAway = true;
      return;
    }
    if (!_wasAway) return;
    _wasAway = false;
    if (mounted && widget.session.isCurrent) {
      final provider = resultsNotifierProvider(widget.session);
      if (!ref.read(provider).page.isLoading) {
        ref.read(provider.notifier).refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final onOpen = widget.onOpen;
    final provider = resultsNotifierProvider(session);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final jobs = ref.watch(
      processingNotifierProvider(session.processingSession),
    );
    final page = state.page.asData?.value;
    final dates = state.dates;
    final rows = page?.data ?? const <ResultDto>[];
    final uploads = state.uploads.asData?.value;
    final listedAudio = rows.map((row) => row.audioId).toSet();
    final local =
        uploads?.entries.where((entry) {
          final receipt = entry.accepted;
          if (receipt == null) return true;
          final key = (audioId: receipt.audioId, jobId: receipt.jobId);
          // Recovery receipts supplement the first unfiltered page. They are not
          // counted as server rows or proof that other pages lack the result.
          return state.pageNumber == 1 &&
              state.dates == null &&
              !listedAudio.contains(receipt.audioId) &&
              !session.jobs.isDeleted(key);
        }).toList() ??
        const <PendingUpload>[];

    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Results',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить результаты',
                  onPressed: state.page.isLoading ? null : notifier.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    dates == null
                        ? 'Выбрать период'
                        : '${_date(dates.start)} — ${_date(dates.end)}',
                    textAlign: TextAlign.center,
                  ),
                  onPressed: () => _chooseDates(context, notifier, dates),
                ),
                if (dates != null)
                  TextButton(
                    onPressed: () => notifier.setDates(null),
                    child: const Text('Сбросить период'),
                  ),
                TextButton.icon(
                  onPressed: () => context.go('/record'),
                  icon: const Icon(Icons.mic_none_rounded),
                  label: const Text('Новая запись'),
                ),
              ],
            ),
            if (state.actionMessage case final message?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: state.actionFailed ? AppColors.error : null,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть сообщение',
                      onPressed: notifier.clearAction,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (state.uploads.hasError)
              _Message(
                text: _safeMessage(
                  state.uploads.error,
                  'Не удалось прочитать сохранённые отправки.',
                ),
                onRetry: notifier.refresh,
              ),
            if ((uploads?.damagedEntries ?? 0) > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Некоторые сохранённые отправки повреждены и недоступны для восстановления.',
                ),
              ),
            if (local.isNotEmpty) ...[
              const Text('Сохранённые отправки с этого устройства'),
              const SizedBox(height: 8),
              for (final entry in local)
                _UploadCard(
                  entry: entry,
                  sending: state.sending.contains(entry.localId),
                  blockedReason: state.blockedReplays[entry.localId],
                  replay: () => notifier.replay(entry.localId),
                  progress: entry.accepted == null
                      ? null
                      : jobs[(
                          audioId: entry.accepted!.audioId,
                          jobId: entry.accepted!.jobId,
                        )],
                  onOpen: onOpen,
                ),
              const SizedBox(height: 16),
            ],
            if (state.page.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.page.hasError)
              _Message(
                text: _safeMessage(
                  state.page.error,
                  'Не удалось загрузить результаты.',
                ),
                onRetry: notifier.refresh,
              )
            else if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  dates == null
                      ? 'Результатов пока нет.'
                      : 'За выбранный период результатов нет.',
                ),
              )
            else
              for (final row in rows)
                _ResultCard(
                  result: row,
                  progress: jobs[(audioId: row.audioId, jobId: row.resultId)],
                  deleting: state.deleting.contains(row.audioId),
                  onDelete: () => notifier.delete(row.audioId),
                  onOpen: onOpen,
                ),
            if (page != null && page.pagination.totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Предыдущая страница',
                      onPressed: state.pageNumber > 1 && !state.page.isLoading
                          ? () => notifier.goToPage(state.pageNumber - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        'Страница ${state.pageNumber} из ${page.pagination.totalPages}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Следующая страница',
                      onPressed:
                          state.pageNumber < page.pagination.totalPages &&
                              !state.page.isLoading
                          ? () => notifier.goToPage(state.pageNumber + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseDates(
    BuildContext context,
    ResultsNotifier notifier,
    ResultsDateFilter? dates,
  ) async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      initialDateRange: dates == null
          ? null
          : DateTimeRange(start: dates.start, end: dates.end),
    );
    if (selected != null && context.mounted) {
      await notifier.setDates((start: selected.start, end: selected.end));
    }
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.entry,
    required this.sending,
    required this.replay,
    this.blockedReason,
    this.progress,
    this.onOpen,
  });

  final PendingUpload entry;
  final bool sending;
  final VoidCallback replay;
  final String? blockedReason;
  final JobProgress? progress;
  final OpenResult? onOpen;

  @override
  Widget build(BuildContext context) {
    final receipt = entry.accepted;
    final label = switch (entry.state) {
      PendingUploadState.pending => 'Отправка не подтверждена',
      PendingUploadState.conflict => 'Конфликт отправки. Повтор недоступен.',
      PendingUploadState.accepted =>
        'Принято сервером · ${_phaseLabel(progress) ?? 'Ожидает обработки'}',
    };
    final action = switch (entry.state) {
      PendingUploadState.pending when blockedReason == null => TextButton(
        onPressed: sending ? null : replay,
        child: Text(sending ? 'Отправляем…' : 'Повторить отправку'),
      ),
      PendingUploadState.accepted
          when receipt != null && onOpen != null && !_accessLost(progress) =>
        TextButton(
          onPressed: () => onOpen!(receipt.audioId, receipt.jobId),
          child: const Text('Открыть'),
        ),
      _ => null,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    receipt == null
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_done_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              blockedReason ??
                  '${entry.options.anonymous ? 'Без рабочего пространства' : 'Рабочее пространство'} · ${_date(entry.createdAt.toLocal())}',
            ),
            if (action != null)
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.deleting,
    required this.onDelete,
    this.progress,
    this.onOpen,
  });

  final ResultDto result;
  final bool deleting;
  final VoidCallback onDelete;
  final JobProgress? progress;
  final OpenResult? onOpen;

  @override
  Widget build(BuildContext context) {
    final workspace = result.workspaceId.isEmpty
        ? 'Без рабочего пространства'
        : (result.workspaceName?.isNotEmpty ?? false)
        ? result.workspaceName!
        : 'Рабочее пространство ${_shortId(result.workspaceId)}';
    final status =
        _phaseLabel(progress) ??
        switch (result.status) {
          'pending' => 'Обрабатывается',
          'done' => 'Транскрипт сформирован',
          'failed' => 'Обработка не завершилась',
          _ => 'Неизвестное состояние',
        };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const ExcludeSemantics(child: Icon(Icons.description_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Запись ${_shortId(result.audioId)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !deleting,
                  tooltip: 'Удалить результат',
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Удалить результат'),
                    ),
                  ],
                  onSelected: (_) => onDelete(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$workspace · $status${result.createdAt == null ? '' : ' · ${_date(result.createdAt!.toLocal())}'}',
              ),
            ),
            if (deleting)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Удаляем…'),
              )
            else if (onOpen != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => onOpen!(result.audioId, result.resultId),
                  child: const Text('Открыть'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        TextButton(onPressed: onRetry, child: const Text('Повторить загрузку')),
      ],
    ),
  );
}

String _safeMessage(Object? error, String fallback) =>
    error is AppException ? error.message : fallback;

String _shortId(String id) => id.length > 12 ? '${id.substring(0, 12)}…' : id;

bool _accessLost(JobProgress? progress) {
  final error = progress?.error;
  return error is NotFoundException ||
      error is ApiFailure &&
          (error.kind == ApiFailureKind.notFound ||
              error.kind == ApiFailureKind.forbidden);
}

String _date(DateTime date) {
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(date.day)}.${pad(date.month)}.${date.year}';
}

String? _phaseLabel(JobProgress? progress) => switch (progress?.phase) {
  ProcessingPhase.waiting => 'Обрабатывается',
  ProcessingPhase.ready => 'Транскрипт готов',
  ProcessingPhase.failed => 'Ошибка обработки',
  ProcessingPhase.cancelled => 'Обработка отменена',
  ProcessingPhase.expired => 'Сессия обработки истекла',
  ProcessingPhase.unavailable => 'Результат недоступен',
  ProcessingPhase.unsupported => 'Неизвестное состояние',
  null => null,
};
