import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/lifecycle/ios_lifecycle_observer.dart';
import '../../../shared/providers/providers.dart';
import '../data/original_audio_cache.dart';

/// One native playback owner. The bridge reserves capture before requesting
/// this stop callback; ACK follows *all* prior plugin commands and disposal.
final class IosPlaybackCoordinator {
  IosPlaybackCoordinator({
    MethodChannel channel = const MethodChannel('com.dictai/ios_playback'),
  }) : _channel = channel {
    _channel.setMethodCallHandler(_nativeCall);
  }
  final MethodChannel _channel;
  String? _owner;
  Future<void> Function()? _stop;
  Future<void> _acquisitions = Future.value();

  Future<void> _nativeCall(MethodCall call) async {
    if (call.method != 'stopForCapture' && call.method != 'stopForSystem') {
      throw MissingPluginException();
    }
    final args = call.arguments;
    if (args is! Map || args['id'] != _owner) return;
    await _stop?.call();
  }

  Future<void> acquire(String id, Future<void> Function() stop) {
    final acquired = _acquisitions.then((_) => _acquire(id, stop));
    _acquisitions = acquired.then(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return acquired;
  }

  Future<void> _acquire(String id, Future<void> Function() stop) async {
    if (_owner != null && _owner != id) await _stop?.call();
    _owner = id;
    _stop = stop;
    try {
      await _channel.invokeMethod<void>('acquire', {'id': id});
    } on PlatformException {
      if (_owner == id) {
        _owner = null;
        _stop = null;
      }
      throw const ValidationException(
        'Дождитесь завершения записи или системного прерывания.',
      );
    }
  }

  Future<void> release(String id) async {
    // Even stale release is identity-checked natively; it cannot deactivate
    // another playback owner or a recorder that has already started.
    await _channel.invokeMethod<void>('release', {'id': id});
    if (_owner == id) {
      _owner = null;
      _stop = null;
    }
  }
}

/// Commands to the decoder are serialized. Revocation increments the epoch
/// synchronously, then waits for in-flight native preparation before release.
final class ResultAudioController extends ChangeNotifier {
  ResultAudioController({
    required OriginalAudioCache cache,
    required this.audioId,
    required this.jobId,
    required bool Function() isCurrentSession,
    IosPlaybackCoordinator? coordinator,
    IosLifecycleObserver? lifecycle,
    AudioPlayer Function()? playerFactory,
  }) : _cache = cache,
       _isCurrentSession = isCurrentSession,
       _coordinator = coordinator,
       _lifecycle = lifecycle,
       _playerFactory = playerFactory ?? AudioPlayer.new {
    _lifecycle?.addListener(_lifecycleChanged);
  }

  final OriginalAudioCache _cache;
  final String audioId;
  final String jobId;
  final bool Function() _isCurrentSession;
  final IosPlaybackCoordinator? _coordinator;
  final IosLifecycleObserver? _lifecycle;
  final AudioPlayer Function() _playerFactory;
  final String _id =
      'playback-${DateTime.now().microsecondsSinceEpoch}-${++_next}';
  static int _next = 0;
  AudioPlayer? _player;
  OriginalAudioLease? _lease;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _tail = Future.value();
  int _epoch = 0;
  bool _closed = false;
  bool _disposed = false;
  bool loading = false;
  bool playing = false;
  Duration? duration;
  Duration position = Duration.zero;
  String? errorMessage;

  bool get _current => !_closed && _isCurrentSession();
  bool get _foreground => _lifecycle?.isForeground ?? true;
  bool _active(int epoch) => _current && _foreground && _epoch == epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _queue(Future<void> Function() command) {
    final result = _tail.then((_) => command());
    _tail = result.then((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> toggle() {
    if (!_current || !_foreground || loading) return Future.value();
    final epoch = _epoch;
    loading = true;
    errorMessage = null;
    _notify();
    return _queue(() async {
      try {
        if (!_active(epoch)) return;
        if (playing) {
          await _player?.pause();
          if (!_active(epoch)) return;
          playing = false;
          return;
        }
        if (_player == null) {
          _lease = await _cache.acquire(audioId, jobId);
          if (!_active(epoch)) return;
          await _coordinator?.acquire(_id, stop);
          if (!_active(epoch)) return;
          final player = _playerFactory();
          _player = player;
          _subscriptions.add(
            player.onDurationChanged.listen(
              (value) {
                if (_current &&
                    identical(_player, player) &&
                    value > Duration.zero) {
                  duration = value;
                  _notify();
                }
              },
              // These derived streams also forward eventStream errors. The
              // single raw subscription below owns reporting and teardown.
              onError: (Object _) {},
            ),
          );
          _subscriptions.add(
            player.onPositionChanged.listen((value) {
              if (_current && identical(_player, player)) {
                position = value;
                _notify();
              }
            }, onError: (Object _) {}),
          );
          _subscriptions.add(
            player.onPlayerComplete.listen((_) {
              if (_current && identical(_player, player)) {
                playing = false;
                position = Duration.zero;
                _notify();
              }
            }, onError: (Object _) {}),
          );
          _subscriptions.add(
            player.eventStream.listen(
              (_) {},
              onError: (Object _) {
                if (_current && identical(_player, player)) {
                  errorMessage = 'Не удалось воспроизвести аудиозапись.';
                  unawaited(stop().catchError((Object _) {}));
                }
              },
            ),
          );
          await player.setAudioContext(AudioContext(iOS: AudioContextIOS()));
          if (!_active(epoch)) return;
          await player.setReleaseMode(ReleaseMode.stop);
          if (!_active(epoch)) return;
          await player.setSourceDeviceFile(
            _lease!.file.path,
            mimeType: 'audio/wav',
          );
          if (!_active(epoch)) return;
          final actual = await player.getDuration();
          if (!_active(epoch)) return;
          if (actual != null && actual > Duration.zero) duration = actual;
        }
        await _player!.resume();
        if (!_active(epoch)) return;
        playing = true;
      } catch (error) {
        if (_current && _epoch == epoch) {
          errorMessage = error is AppException
              ? error.message
              : 'Не удалось открыть аудиозапись. Повторите попытку.';
        }
        // A button callback must not leak an unhandled teardown Future. Native
        // stop() still propagates failure so capture cannot ACK unsafe cleanup.
        try {
          await _stopDecoder();
        } catch (_) {
          if (_current) {
            errorMessage = 'Не удалось освободить плеер. Повторите попытку.';
          }
        }
      } finally {
        if (_epoch == epoch) loading = false;
        _notify();
      }
    });
  }

  Future<void> seek(Duration value) {
    final epoch = _epoch;
    return _queue(() async {
      if (!_active(epoch) || _player == null || duration == null) return;
      final micros = value.inMicroseconds.clamp(0, duration!.inMicroseconds);
      try {
        await _player!.seek(Duration(microseconds: micros));
        if (_active(epoch)) position = Duration(microseconds: micros);
      } catch (_) {
        if (_active(epoch)) {
          errorMessage = 'Не удалось изменить позицию записи.';
        }
      }
      _notify();
    });
  }

  Future<void> _stopDecoder() async {
    final player = _player;
    // If native disposal fails, preserve ownership and lease for safe retry.
    if (player != null) {
      await player.stop();
      try {
        await player.dispose();
      } catch (_) {
        // audioplayers marks disposed only after stop/release settled. A final
        // plugin bookkeeping failure cannot make its released input live again.
        if (player.state != PlayerState.disposed) rethrow;
        if (!_closed) {
          errorMessage =
              'Звук остановлен, но не все ресурсы плеера освобождены.';
        }
      }
      _player = null;
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _coordinator?.release(_id);
    await _lease?.release();
    _lease = null;
    playing = false;
    duration = null;
    position = Duration.zero;
  }

  Future<void> stop() {
    ++_epoch;
    loading = false;
    return _queue(() async {
      try {
        await _stopDecoder();
      } catch (_) {
        if (!_closed) {
          errorMessage = 'Не удалось остановить аудио. Повторите попытку.';
        }
        rethrow;
      } finally {
        _notify();
      }
    });
  }

  void _lifecycleChanged() {
    if (!_foreground) unawaited(stop().catchError((Object _) {}));
  }

  Future<void> close() {
    _closed = true;
    return stop();
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycle?.removeListener(_lifecycleChanged);
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}

class ResultAudioPlayer extends ConsumerWidget {
  const ResultAudioPlayer({
    super.key,
    required this.session,
    required this.audioId,
    required this.jobId,
  });
  final BatchSession session;
  final String audioId;
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(
      resultAudioControllerProvider((
        session: session,
        audioId: audioId,
        jobId: jobId,
      )),
    );
    final duration = player.duration;
    final maximum = duration?.inMilliseconds.toDouble() ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Аудиозапись', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: player.loading ? null : player.toggle,
            icon: Icon(
              player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(
              player.loading
                  ? 'Загрузка аудио…'
                  : player.playing
                  ? 'Пауза'
                  : 'Слушать запись',
            ),
          ),
        ),
        if (maximum > 0) ...[
          Slider(
            semanticFormatterCallback: (value) =>
                '${(value / 1000).round()} секунд',
            value: player.position.inMilliseconds.toDouble().clamp(0, maximum),
            max: maximum,
            onChanged: player.loading
                ? null
                : (value) => player.seek(Duration(milliseconds: value.round())),
          ),
          Text('${_clock(player.position)} / ${_clock(duration!)}'),
        ],
        if (player.errorMessage case final error?)
          Semantics(liveRegion: true, child: Text(error)),
        const SizedBox(height: 20),
      ],
    );
  }
}

String _clock(Duration value) {
  final seconds = value.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
