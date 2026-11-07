import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/config/app_config.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/workspace/data/workspace_api.dart';
import '../../features/record/data/audio_ingest_api.dart';
import '../../features/record/data/anonymous_session_api.dart';
import '../../features/record/data/anthropic_service.dart';
import '../../features/results/data/results_api.dart';
import '../../features/results/data/canonical_api.dart';
import '../../features/results/data/speech_status_api.dart';
import '../../features/results/data/pending_job_store.dart';
import '../../features/results/presentation/processing_notifier.dart';

// ── Storage ──────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return const SecureStorage();
});

// ── Session notifier — fires when token is deleted externally (401) ───────────

final sessionNotifierProvider = ChangeNotifierProvider<_SessionNotifier>(
  (ref) => _SessionNotifier(),
);

class _SessionNotifier extends ChangeNotifier {
  void invalidate() => notifyListeners();
}

// ── Dio ──────────────────────────────────────────────────────────────────────

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  final session = ref.read(sessionNotifierProvider);
  final config = ref.read(appConfigProvider);
  return createDio(
    baseUrl: config.baseUrl,
    appConfig: config,
    enableNetworkDiagnostics: config.networkDiagnostics,
    storage: storage,
    onUnauthorized: () async => session.invalidate(),
  );
});

// ── API clients ───────────────────────────────────────────────────────────────

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.read(dioProvider)),
);

final workspaceApiProvider = Provider<WorkspaceApi>(
  (ref) => WorkspaceApi(ref.read(dioProvider)),
);

final audioIngestApiProvider = Provider<AudioIngestApi>(
  (ref) => AudioIngestApi(ref.read(dioProvider)),
);

final resultsApiProvider = Provider<ResultsApi>(
  (ref) => ResultsApi(ref.read(dioProvider)),
);

final speechStatusApiProvider = Provider<SpeechStatusApi>(
  (ref) => SpeechStatusApi(ref.read(dioProvider)),
);

final canonicalApiProvider = Provider<CanonicalApi>(
  (ref) => CanonicalApi(ref.read(dioProvider)),
);

final processingNotifierProvider = StateNotifierProvider.autoDispose
    .family<
      ProcessingNotifier,
      Map<ProcessingKey, JobProgress>,
      ProcessingSession
    >(
      (ref, session) => ProcessingNotifier(
        store: session.store,
        statusApi: ref.read(speechStatusApiProvider),
        canonicalApi: ref.read(canonicalApiProvider),
        isCurrentSession: session.isCurrentSession,
      ),
    );

final anthropicServiceProvider = Provider<AnthropicService>(
  (ref) => AnthropicService(ref.read(secureStorageProvider)),
);

final anonymousSessionApiProvider = Provider<AnonymousSessionApi>(
  (ref) => AnonymousSessionApi(ref.read(dioProvider)),
);
