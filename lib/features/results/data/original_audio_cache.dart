import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../record/data/wav_validator.dart';
import 'documents_api.dart';

typedef OriginalAudioKey = ({String ownerId, String audioId, String jobId});

/// A lease keeps an owned original alive until the decoder has released it.
final class OriginalAudioLease {
  OriginalAudioLease._(this.file, this._release);
  final File file;
  final Future<void> Function() _release;
  Future<void>? _released;
  Future<void> release() => _released ??= _release();
}

final class _Entry {
  _Entry(this.key, this.download);
  final OriginalAudioKey key;
  final DownloadedFile download;
  int leases = 0;
  bool valid = true;
  Completer<void>? unused;
}

/// Session-owned, single-original cache. Both complete and partial files share
/// the same quota; a different original cannot replace a leased decoder input.
final class OriginalAudioCache {
  OriginalAudioCache({
    required this.ownerId,
    required DocumentsApi api,
    required Future<Directory> Function() temporaryDirectory,
    required bool Function() isCurrentSession,
    this.maxBytes = 256 * 1024 * 1024,
    Future<void> Function(Directory)? prepareDirectory,
    Future<void> Function(DownloadedFile)? deleteDownloaded,
  }) : _api = api,
       _temporaryDirectory = temporaryDirectory,
       _isCurrentSession = isCurrentSession,
       _prepareDirectory = prepareDirectory,
       _deleteDownloaded = deleteDownloaded ?? _delete {
    if (maxBytes <= 0 || maxBytes > WavValidator.maxFileBytes) {
      throw ArgumentError.value(maxBytes, 'maxBytes');
    }
  }

  final String ownerId;
  final int maxBytes;
  final DocumentsApi _api;
  final Future<Directory> Function() _temporaryDirectory;
  final bool Function() _isCurrentSession;
  final Future<void> Function(Directory)? _prepareDirectory;
  final Future<void> Function(DownloadedFile) _deleteDownloaded;
  static Future<void> _delete(DownloadedFile file) => file.delete();
  Directory? _directory;
  _Entry? _entry;
  Future<void> _tail = Future.value();
  CancelToken? _request;
  bool _closed = false;
  Future<void>? _closing;

  bool get _current => !_closed && _isCurrentSession();

  Future<OriginalAudioLease> acquire(String audioId, String jobId) {
    final result = _tail.then((_) => _acquire(audioId, jobId));
    _tail = result.then((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<OriginalAudioLease> _acquire(String audioId, String jobId) async {
    if (!_current) throw const UnauthorizedException();
    if (audioId.isEmpty || jobId.isEmpty) {
      throw const ValidationException('Не указан идентификатор аудиозаписи.');
    }
    final key = (ownerId: ownerId, audioId: audioId, jobId: jobId);
    var entry = _entry;
    if (entry != null && entry.valid && entry.key == key) {
      try {
        final stat = await entry.download.file.stat();
        entry.valid =
            stat.type == FileSystemEntityType.file &&
            stat.size == entry.download.byteLength &&
            await FileSystemEntity.type(
                  entry.download.file.path,
                  followLinks: false,
                ) ==
                FileSystemEntityType.file;
      } on FileSystemException {
        entry.valid = false;
      }
    }
    if (entry?.key != key || entry?.valid != true) {
      if (entry != null && entry.leases > 0) {
        throw const ValidationException('Сначала закройте другую аудиозапись.');
      }
      final pending = _load(key);
      entry = await pending;
    }
    if (!_current || entry == null || !identical(entry, _entry)) {
      throw const UnauthorizedException();
    }
    final leased = entry;
    leased.leases++;
    return OriginalAudioLease._(leased.download.file, () async {
      leased.leases--;
      if (leased.leases == 0) {
        leased.unused?.complete();
        leased.unused = null;
      }
    });
  }

  Future<_Entry> _load(OriginalAudioKey key) async {
    final old = _entry;
    if (old != null) {
      old.valid = false;
      await _deleteDownloaded(old.download);
      _entry = null;
    }
    if (!_current) throw const UnauthorizedException();
    final parent = await _temporaryDirectory();
    if (!_current) throw const UnauthorizedException();
    final directory = _directory ??= await parent.createTemp(
      'dictai-original-',
    );
    // A failed underlying transfer cleanup may leave staging in this exclusive
    // root. Never start another transfer until that owned residue is removed.
    await for (final child in directory.list(followLinks: false)) {
      await child.delete(recursive: true);
    }
    await _prepareDirectory?.call(directory);
    if (!_current) throw const UnauthorizedException();
    final request = CancelToken();
    _request = request;
    try {
      final downloaded = await _api.getOriginal(
        key.audioId,
        temporaryDirectory: directory,
        cancelToken: request,
        maxBytes: maxBytes,
      );
      final entry = _Entry(key, downloaded);
      _entry = entry;
      if (!_current) {
        entry.valid = false;
        throw const UnauthorizedException();
      }
      return entry;
    } finally {
      if (identical(_request, request)) _request = null;
    }
  }

  /// Cancel immediately, then wait for the decoder's lease before deletion.
  Future<void> close() {
    if (_closing case final closing?) return closing;
    _closed = true;
    _request?.cancel();
    final closing = _finishClose();
    _closing = closing;
    unawaited(
      closing.then(
        (_) {},
        onError: (Object _, StackTrace __) {
          if (identical(_closing, closing)) _closing = null;
        },
      ),
    );
    return closing;
  }

  Future<void> _finishClose() async {
    await _tail;
    final entry = _entry;
    if (entry != null && entry.leases > 0) {
      await (entry.unused ??= Completer<void>()).future;
    }
    if (entry != null) await _deleteDownloaded(entry.download);
    _entry = null;
    final directory = _directory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    _directory = null;
  }
}
