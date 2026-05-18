import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/workspace/data/workspace_api.dart';
import '../../features/record/data/audio_ingest_api.dart';
import '../../features/record/data/anthropic_service.dart';
import '../../features/results/data/results_api.dart';
import '../../features/voice_profile/data/voice_profile_api.dart';

// ── Storage ──────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return const SecureStorage();
});

// ── Dio ──────────────────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  return createDio(
    baseUrl: 'http://localhost:8000',
    storage: ref.read(secureStorageProvider),
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

final voiceProfileApiProvider = Provider<VoiceProfileApi>(
  (ref) => VoiceProfileApi(ref.read(dioProvider)),
);

final anthropicServiceProvider = Provider<AnthropicService>(
  (ref) => AnthropicService(ref.read(secureStorageProvider)),
);
