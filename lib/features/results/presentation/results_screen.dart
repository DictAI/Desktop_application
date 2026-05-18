import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/dto/result_dto.dart';
import 'results_notifier.dart';

/// React-аналог: ResultsPage.tsx
/// Список результатов обработки аудио (транскрипт + summary).
/// GET /meetings/results — STUB (см. MISSING_ENDPOINTS.md п.2).
/// DELETE /meetings/results/:id — STUB (см. MISSING_ENDPOINTS.md п.3).
/// Скачивание PDF (summary / transcript) — реализовано.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resultsNotifierProvider);
    final notifier = ref.read(resultsNotifierProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Заголовок + кнопка обновления ──────────────────────────────
          Row(
            children: [
              const Text(
                'Results',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: state.status == ResultsStatus.loading
                    ? null
                    : notifier.load,
                icon: state.status == ResultsStatus.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded,
                        color: AppColors.textSecondary),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Meeting transcripts and summaries',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // ── Баннер ошибки / заглушки ─────────────────────────────────
          if (state.errorMessage != null)
            _InfoBanner(
              message: state.errorMessage!,
              isStub: state.isStubError,
              onDismiss: notifier.clearError,
            ),

          // ── Контент ──────────────────────────────────────────────────
          Expanded(
            child: switch (state.status) {
              ResultsStatus.loading => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ResultsStatus.error when state.isStubError =>
                _StubPlaceholder(onRetry: notifier.load),
              ResultsStatus.error => _ErrorState(
                  message: state.errorMessage ?? '',
                  onRetry: notifier.load,
                ),
              ResultsStatus.loaded when state.results.isEmpty =>
                const _EmptyState(),
              _ => _ResultsList(
                  results: state.results,
                  downloadingPdf: state.downloadingPdf,
                  onDownloadSummary: (audioId) =>
                      notifier.downloadSummary(audioId, audioId),
                  onDownloadTranscript: (audioId) =>
                      notifier.downloadTranscript(audioId, audioId),
                  onDelete: (audioId) async {
                    final ok = await notifier.delete(audioId);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Delete is not yet available'),
                          backgroundColor: AppColors.surfaceElevated,
                        ),
                      );
                    }
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Список результатов
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final List<ResultDto> results;
  final Map<String, bool> downloadingPdf;
  final void Function(String audioId) onDownloadSummary;
  final void Function(String audioId) onDownloadTranscript;
  final Future<void> Function(String audioId) onDelete;

  const _ResultsList({
    required this.results,
    required this.downloadingPdf,
    required this.onDownloadSummary,
    required this.onDownloadTranscript,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ResultCard(
        result: results[i],
        isDownloading: downloadingPdf[results[i].audioId] ?? false,
        onDownloadSummary: () => onDownloadSummary(results[i].audioId),
        onDownloadTranscript: () => onDownloadTranscript(results[i].audioId),
        onDelete: () => onDelete(results[i].audioId),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ResultDto result;
  final bool isDownloading;
  final VoidCallback onDownloadSummary;
  final VoidCallback onDownloadTranscript;
  final Future<void> Function() onDelete;

  const _ResultCard({
    required this.result,
    required this.isDownloading,
    required this.onDownloadSummary,
    required this.onDownloadTranscript,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = result.createdAt != null
        ? _formatDate(result.createdAt!)
        : 'Date unknown';
    final workspaceLabel = result.workspaceName?.isNotEmpty == true
        ? result.workspaceName!
        : 'Workspace ${result.workspaceId.substring(0, 12)}…';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Шапка карточки ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_rounded,
                    color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio ID: ${result.audioId.substring(0, 12)}…',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Меню
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: AppColors.textSecondary, size: 18),
                color: AppColors.surfaceElevated,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Workspace ───────────────────────────────────────────────
          _TagRow(
            label: 'Workspace',
            value: workspaceLabel,
          ),
          const SizedBox(height: 16),

          // ── Кнопки скачивания ───────────────────────────────────────
          Row(
            children: [
              _PdfButton(
                label: 'Summary PDF',
                icon: Icons.summarize_rounded,
                isLoading: isDownloading,
                onTap: onDownloadSummary,
              ),
              const SizedBox(width: 10),
              _PdfButton(
                label: 'Transcript PDF',
                icon: Icons.article_rounded,
                isLoading: isDownloading,
                onTap: onDownloadTranscript,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }
}

class _TagRow extends StatelessWidget {
  final String label;
  final String value;

  const _TagRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _PdfButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _PdfButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else
              Icon(icon, color: AppColors.accent, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательные виджеты
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.description_outlined,
                color: AppColors.textSecondary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No results yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload and process audio files to see results here',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StubPlaceholder extends StatelessWidget {
  final VoidCallback onRetry;

  const _StubPlaceholder({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.accentSubtle,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_rounded,
                color: AppColors.accent, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Backend endpoint not implemented',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'GET /meetings/results is missing from the backend.\n'
              'See MISSING_ENDPOINTS.md for details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accent),
                foregroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  final bool isStub;
  final VoidCallback onDismiss;

  const _InfoBanner({
    required this.message,
    required this.isStub,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = isStub ? AppColors.accent : AppColors.error;
    final bg = isStub ? AppColors.accentSubtle : AppColors.errorSubtle;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isStub ? Icons.construction_rounded : Icons.error_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, color: color, size: 16),
          ),
        ],
      ),
    );
  }
}
