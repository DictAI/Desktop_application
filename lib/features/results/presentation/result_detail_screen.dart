import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../shared/providers/providers.dart';
import '../data/dto/speech_status_dto.dart';
import '../data/ios_document_export.dart';
import 'processing_notifier.dart';
import 'audio_player.dart';
import 'result_detail_notifier.dart';
import 'transcript_view.dart';

String resultDetailLocation(String audioId, {String? jobId}) => Uri(
  pathSegments: ['', 'results', audioId],
  queryParameters: jobId == null ? null : {'job_id': jobId},
).toString();

class ResultDetailScreen extends ConsumerWidget {
  const ResultDetailScreen({super.key, required this.audioId, this.jobId});
  final String audioId;
  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(batchSessionProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_safeMessage(error, 'Не удалось открыть результат.')),
          ),
        ),
        data: (session) => session.isCurrent
            ? _Detail(
                request: (session: session, audioId: audioId, jobId: jobId),
              )
            : const Center(child: CircularProgressIndicator()),
      );
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.request});
  final ResultDetailKey request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = resultDetailNotifierProvider(request);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final progress = state.progress;
    final transcript = progress?.canonical;
    final error = state.error ?? progress?.error;
    final spacing = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 28.0;
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        key: const Key('result-detail-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(spacing, spacing, spacing, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Результат записи',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Обновить результат',
                        onPressed: state.resolving ? null : notifier.refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.resolving)
                    const LinearProgressIndicator()
                  else if (progress != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(_progressLabel(progress)),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(liveRegion: true, child: Text(error.message)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: notifier.refresh,
                        child: const Text('Повторить чтение результата'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (state.jobId case final jobId?)
                    ResultAudioPlayer(
                      session: request.session,
                      audioId: request.audioId,
                      jobId: jobId,
                    ),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.iOS &&
                      state.jobId != null)
                    _ResultExports(
                      request: (
                        session: request.session,
                        audioId: request.audioId,
                        jobId: state.jobId!,
                      ),
                      status: state.error != null || _lostAccess(error)
                          ? null
                          : progress?.status,
                    ),
                  Text(
                    'Краткое содержание',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _Summary(state: state, retry: notifier.retrySummary),
                  const SizedBox(height: 24),
                  Text(
                    'Транскрипт',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (transcript == null)
                    const Text('Транскрипт пока недоступен.'),
                ],
              ),
            ),
          ),
          if (transcript != null)
            TranscriptView(
              transcript: transcript,
              padding: EdgeInsets.fromLTRB(spacing, 0, spacing, spacing),
            )
          else
            SliverToBoxAdapter(child: SizedBox(height: spacing)),
        ],
      ),
    );
  }
}

class _ResultExports extends ConsumerWidget {
  const _ResultExports({required this.request, required this.status});
  final ResultAudioKey request;
  final SpeechStatusDto? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exporter = ref.watch(iosDocumentExporterProvider(request));
    final canRequest =
        status != null &&
        IosExportKind.values.any((kind) => kind.canRequest(status));
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exporter.busy)
            TextButton.icon(
              onPressed: () =>
                  unawaited(exporter.cancel().catchError((Object _) {})),
              icon: const Icon(Icons.close),
              label: const Text('Отменить экспорт'),
            )
          else
            PopupMenuButton<IosExportKind>(
              enabled: canRequest && !exporter.needsCleanup,
              tooltip: 'Скачать и поделиться',
              onSelected: (kind) => unawaited(
                exporter
                    .share(
                      audioId: request.audioId,
                      jobId: request.jobId,
                      kind: kind,
                      status: status!,
                    )
                    .catchError((Object _) => IosShareOutcome.cancelled),
              ),
              itemBuilder: (_) => [
                for (final kind in IosExportKind.values)
                  PopupMenuItem(
                    value: kind,
                    enabled: kind.canRequest(status),
                    child: Text(kind.label),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.ios_share),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Скачать и поделиться',
                        style: TextStyle(
                          color: canRequest
                              ? null
                              : Theme.of(context).disabledColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (exporter.errorMessage ?? exporter.message case final message?)
            Semantics(liveRegion: true, child: Text(message)),
          if (exporter.needsCleanup)
            TextButton(
              onPressed: exporter.retryCleanup,
              child: const Text('Повторить удаление временного файла'),
            ),
        ],
      ),
    );
  }
}

bool _lostAccess(Object? error) =>
    error is NotFoundException ||
    error is UnauthorizedException ||
    error is ApiFailure &&
        (error.kind == ApiFailureKind.forbidden ||
            error.kind == ApiFailureKind.notFound ||
            error.kind == ApiFailureKind.unauthorized);

class _Summary extends StatelessWidget {
  const _Summary({required this.state, required this.retry});
  final ResultDetailState state;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    if (state.summary.isLoading) {
      return const Text('Загрузка краткого содержания…');
    }
    if (state.summary.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_safeMessage(state.summary.error, 'Документ пока недоступен.')),
          TextButton(
            onPressed: retry,
            child: const Text('Повторить загрузку содержания'),
          ),
        ],
      );
    }
    if (state.summary.asData?.value case final text?) {
      return SelectableText(text);
    }
    final status = state.progress?.status;
    return Text(switch (status?.summaryStatus) {
      SummaryStatus.failed =>
        ApiErrorMapper.summaryFailureMessage(status?.summaryError) ??
            'Не удалось подготовить краткое содержание.',
      SummaryStatus.ready => 'Краткое содержание пока недоступно.',
      SummaryStatus.unknown =>
        'Состояние краткого содержания не поддерживается.',
      _ => 'Краткое содержание ещё готовится.',
    });
  }
}

String _progressLabel(JobProgress progress) {
  if (progress.canonical != null) return 'Транскрипт готов.';
  return switch (progress.phase) {
    ProcessingPhase.failed => 'Не удалось распознать запись.',
    ProcessingPhase.cancelled => 'Обработка отменена.',
    ProcessingPhase.expired => 'Время ожидания сессии истекло.',
    ProcessingPhase.unavailable => 'Результат временно недоступен.',
    ProcessingPhase.unsupported => 'Состояние обработки не поддерживается.',
    _ => switch (progress.status?.jobStatus) {
      SpeechJobStatus.queued => 'Запись в очереди на обработку.',
      SpeechJobStatus.running => 'Запись обрабатывается.',
      SpeechJobStatus.completed => 'Ожидаем транскрипт записи.',
      _ => 'Проверяем состояние записи…',
    },
  };
}

String _safeMessage(Object? error, String fallback) =>
    error is AppException ? error.message : fallback;
