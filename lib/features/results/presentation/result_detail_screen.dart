import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../shared/providers/providers.dart';
import '../data/dto/speech_status_dto.dart';
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
