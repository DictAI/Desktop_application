import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/error/app_exception.dart';
import 'dto/pending_upload.dart';
import 'dto/upload_accepted_dto.dart';
import 'dto/upload_options.dart';
import 'v2_upload_api.dart';
import 'wav_validator.dart';

final class PendingUploadListing {
  PendingUploadListing(List<PendingUpload> entries, this.damagedEntries)
    : entries = List.unmodifiable(entries);

  final List<PendingUpload> entries;
  final int damagedEntries;
}

/// A journal bound to one authenticated owner and session generation. Create a
/// new instance when the session changes. The caller cancels in-flight HTTP via
/// the token passed to [submit].
final class PendingUploadStore {
  PendingUploadStore({
    required this.ownerId,
    required bool Function() isCurrentSession,
    Future<Directory> Function()? applicationSupportDirectory,
    this.maxSourceBytes = 2 * WavValidator.maxFileBytes,
    this.maxEntries = 64,
  }) : _isCurrentSession = isCurrentSession,
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory {
    if (!PendingUpload.validOwnerId(ownerId)) {
      throw const ValidationException(
        'Недопустимый владелец журнала загрузок.',
      );
    }
    if (maxEntries <= 0 || maxSourceBytes <= 0) {
      throw ArgumentError('Journal limits must be positive');
    }
  }

  final String ownerId;
  final bool Function() _isCurrentSession;
  final Future<Directory> Function() _applicationSupportDirectory;
  final int maxSourceBytes;
  final int maxEntries;

  static const _maxMetadataBytes = 16 * 1024;
  static const _metadataName = 'upload.json';
  static const _audioName = 'source.wav';
  static final _ownerTails = <String, Future<void>>{};
  static final _submitting = <String>{};
  static final _random = Random.secure();
  static const _unavailable = ServerException(
    'Не удалось открыть или сохранить журнал загрузок.',
  );
  static const _entryUnavailable = ValidationException(
    'Локальная запись отправки отсутствует или повреждена.',
  );
  static const _sourceChanged = ValidationException(
    'Сохранённый WAV отсутствует или изменён. Восстановление отправки недоступно.',
  );
  static const _busy = ValidationException('Эта отправка уже выполняется.');
  static const _conflict = ValidationException(
    'Сохранённая отправка конфликтует с сервером. Повтор недоступен.',
  );

  /// These local failures make this exact draft unsafe or impossible to send.
  /// A concurrent submission is transient even though it is a validation error.
  static bool isUnrecoverableReplayError(AppException error) =>
      identical(error, _entryUnavailable) ||
      identical(error, _sourceChanged) ||
      identical(error, _conflict);

  Future<PendingUpload> prepare({
    required File source,
    required UploadOptions options,
  }) => _withOwner((owner) async {
    if (options.idempotencyKey.codeUnits.any(
      (unit) => unit != 0x09 && (unit < 0x20 || unit > 0x7e),
    )) {
      throw const ValidationException(
        'Ключ загрузки содержит символы, недопустимые в HTTP-заголовке.',
      );
    }
    await _cleanup(owner);
    final listing = await _list(owner);
    if (listing.entries.any(
      (entry) => entry.options.idempotencyKey == options.idempotencyKey,
    )) {
      throw const ValidationException(
        'Отправка с этим ключом уже сохранена. Откройте её в журнале.',
      );
    }
    final length = await source.length();
    if (length <= 0 || length > WavValidator.maxFileBytes) {
      throw const ValidationException(
        'Выберите непустой WAV размером до 1 GiB.',
      );
    }
    final usage = await _usage(owner);
    if (usage.entries >= maxEntries || usage.bytes + length > maxSourceBytes) {
      throw const ValidationException(
        'Журнал загрузок достиг лимита хранения.',
      );
    }

    String id;
    Directory destination;
    do {
      id = List.generate(
        16,
        (_) => _random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      destination = Directory('${owner.path}/$id');
    } while (await _type(destination.path) != FileSystemEntityType.notFound);
    final staging = Directory('${owner.path}/.stage-$id');
    _checkSession();
    await staging.create();
    try {
      final copy = File('${staging.path}/$_audioName');
      final digest = await _fileDigest(source.path, length, copyTo: copy.path);
      await const WavValidator().validate(copy);
      final entry = PendingUpload(
        ownerId: ownerId,
        localId: id,
        createdAt: DateTime.now().toUtc(),
        options: options,
        byteCount: length,
        sha256: digest,
      );
      await _writeMetadata(File('${staging.path}/$_metadataName'), entry);
      _checkSession();
      staging.renameSync(destination.path);
      return entry;
    } finally {
      await _deleteStaging(staging);
    }
  });

  Future<PendingUploadListing> list() => _withOwner(_list);

  /// Explicit send or replay of one persisted draft. Accepted entries return
  /// their job reference directly. Use a cancellation token bound to the active
  /// session in addition to the store's synchronous session guard.
  Future<PendingUpload> submit(
    String localId, {
    required V2UploadApi api,
    required CancelToken cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    _checkLocalId(localId);
    final owner = await _ownerDirectory();
    final entryPath = '${owner.path}/$localId';
    if (!_submitting.add(entryPath)) throw _busy;
    RandomAccessFile? sendLock;
    late final PendingUpload result;
    try {
      final entry = await _lockOwner(owner, () async {
        final current = await _requireEntry(owner, localId);
        if (current.state == PendingUploadState.pending) {
          sendLock = await _openLock('$entryPath/send.lock', _busy);
        }
        return current;
      });
      if (entry.state == PendingUploadState.accepted) {
        result = entry;
      } else {
        if (entry.state == PendingUploadState.conflict) throw _conflict;
        final audio = File('$entryPath/$_audioName');
        await _verifySource(audio, entry);
        _checkSession();
        final UploadAcceptedDto accepted;
        try {
          accepted = await api.upload(
            audioFile: audio,
            options: entry.options,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
            hasRecoverableUpload: true,
          );
        } on ApiFailure catch (error) {
          if (error.kind == ApiFailureKind.conflict) {
            await _saveOutcome(
              owner,
              entry.withOutcome(PendingUploadState.conflict),
            );
          }
          rethrow;
        }
        result = await _saveOutcome(
          owner,
          entry.withOutcome(PendingUploadState.accepted, accepted: accepted),
        );
      }
    } finally {
      try {
        await sendLock?.close();
      } on FileSystemException {
        // The saved outcome is authoritative even when lock cleanup fails.
      } finally {
        _submitting.remove(entryPath);
      }
    }
    _checkSession();
    return result;
  }

  /// Called after the accepted job is handled by the result lifecycle.
  Future<void> forgetAccepted(String localId) => _withOwner((owner) async {
    _checkLocalId(localId);
    final entry = await _requireEntry(owner, localId);
    if (entry.state != PendingUploadState.accepted) {
      throw const ValidationException('Исход отправки ещё не подтверждён.');
    }
    final directory = Directory('${owner.path}/$localId');
    _checkSession();
    final discarded = directory.renameSync('${owner.path}/.discard-$localId');
    await _deleteStaging(discarded);
  });

  Future<void> cleanup() => _withOwner(_cleanup);

  Future<PendingUpload> _saveOutcome(Directory owner, PendingUpload entry) =>
      _lockOwner(owner, () async {
        final path = '${owner.path}/${entry.localId}/$_metadataName';
        final next = File('$path.next');
        // Create exclusively so damaged symlinks cannot redirect the write.
        await _removeFile(next);
        await next.create(exclusive: true);
        try {
          await _writeMetadata(next, entry);
          _checkSession();
          next.renameSync(path);
          if (entry.state == PendingUploadState.accepted) {
            await _removeFile(
              File('${owner.path}/${entry.localId}/$_audioName'),
            );
          }
          return entry;
        } finally {
          await _removeFile(next);
        }
      });

  Future<void> _verifySource(File file, PendingUpload entry) async {
    try {
      if (await _type(file.path) != FileSystemEntityType.file ||
          await file.length() != entry.byteCount ||
          await _fileDigest(file.path, entry.byteCount) != entry.sha256) {
        throw _sourceChanged;
      }
    } on FileSystemException {
      throw _sourceChanged;
    }
  }

  Future<PendingUploadListing> _list(Directory owner) async {
    final entries = <PendingUpload>[];
    var damaged = 0;
    await for (final entity in owner.list(followLinks: false)) {
      final id = _basename(entity);
      if (!PendingUpload.validLocalId(id)) continue;
      final entry = await _readEntry(owner, id);
      if (entry == null) {
        damaged++;
      } else {
        entries.add(entry);
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return PendingUploadListing(entries, damaged);
  }

  Future<({int entries, int bytes})> _usage(Directory owner) async {
    var entries = 0;
    var bytes = 0;
    await for (final entity in owner.list(followLinks: false)) {
      final id = _basename(entity);
      if (!PendingUpload.validLocalId(id) && !_isStaging(id)) continue;
      entries++;
      if (entity is Directory) {
        final path = '${entity.path}/$_audioName';
        if (await _type(path) == FileSystemEntityType.file) {
          bytes += await File(path).length();
        }
      }
    }
    return (entries: entries, bytes: bytes);
  }

  Future<void> _cleanup(Directory owner) async {
    await for (final entity in owner.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = _basename(entity);
      if (_isStaging(name)) {
        _checkSession();
        await _deleteStaging(entity);
      } else if (PendingUpload.validLocalId(name)) {
        final entry = await _readEntry(owner, name);
        if (entry?.state == PendingUploadState.accepted) {
          _checkSession();
          await _removeFile(File('${entity.path}/$_audioName'));
        }
        _checkSession();
        await _removeFile(File('${entity.path}/$_metadataName.next'));
      }
    }
  }

  Future<PendingUpload> _requireEntry(Directory owner, String id) async =>
      await _readEntry(owner, id) ?? (throw _entryUnavailable);

  Future<PendingUpload?> _readEntry(Directory owner, String id) async {
    final directory = '${owner.path}/$id';
    final file = File('$directory/$_metadataName');
    if (await _type(directory) != FileSystemEntityType.directory ||
        await _type(file.path) != FileSystemEntityType.file) {
      return null;
    }
    try {
      final handle = await file.open();
      try {
        final bytes = await handle.read(_maxMetadataBytes + 1);
        if (bytes.length > _maxMetadataBytes) return null;
        final envelope = jsonDecode(utf8.decode(bytes));
        if (envelope is! Map<String, dynamic>) return null;
        final payload = envelope['entry'];
        if (payload is! Map<String, dynamic> ||
            envelope['sha256'] != _metadataDigest(payload)) {
          return null;
        }
        final entry = PendingUpload.fromJson(payload);
        return entry.ownerId == ownerId &&
                entry.localId == id &&
                entry.byteCount <= WavValidator.maxFileBytes
            ? entry
            : null;
      } finally {
        await handle.close();
      }
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    } on AppException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _writeMetadata(File file, PendingUpload entry) async {
    final payload = entry.toJson();
    final bytes = utf8.encode(
      jsonEncode({'entry': payload, 'sha256': _metadataDigest(payload)}),
    );
    if (bytes.length > _maxMetadataBytes) {
      throw const ValidationException(
        'Параметры загрузки превышают лимит журнала.',
      );
    }
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<T> _withOwner<T>(Future<T> Function(Directory) action) async {
    final owner = await _ownerDirectory();
    return _lockOwner(owner, () => action(owner));
  }

  Future<T> _lockOwner<T>(Directory owner, Future<T> Function() action) async {
    _checkSession();
    final key = owner.path;
    final previous = _ownerTails[key];
    final done = Completer<void>();
    _ownerTails[key] = done.future;
    RandomAccessFile? lock;
    late final T result;
    try {
      await previous;
      _checkSession();
      lock = await _openLock('$key/journal.lock', _unavailable);
      _checkSession();
      result = await action();
      _checkSession();
    } on FileSystemException {
      throw _unavailable;
    } finally {
      try {
        await lock?.close();
      } on FileSystemException {
        // The process-wide queue must advance even if the OS close fails.
      } finally {
        done.complete();
        if (identical(_ownerTails[key], done.future)) _ownerTails.remove(key);
      }
    }
    _checkSession();
    return result;
  }

  Future<RandomAccessFile> _openLock(String path, AppException busy) async {
    final kind = await _type(path);
    if (kind != FileSystemEntityType.file &&
        kind != FileSystemEntityType.notFound) {
      throw _unavailable;
    }
    final lock = await File(path).open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      return lock;
    } on FileSystemException {
      await lock.close();
      throw busy;
    }
  }

  Future<Directory> _ownerDirectory() async {
    _checkSession();
    try {
      final support = await _applicationSupportDirectory();
      _checkSession();
      await support.create(recursive: true);
      final path = await support.resolveSymbolicLinks();
      final root = Directory('$path/dictai-pending-v1');
      await _ensureDirectory(root);
      final owner = Directory('${root.path}/$ownerId');
      await _ensureDirectory(owner);
      _checkSession();
      return owner;
    } on FileSystemException {
      throw _unavailable;
    } on MissingPlatformDirectoryException {
      throw _unavailable;
    }
  }

  Future<void> _ensureDirectory(Directory directory) async {
    if (await _type(directory.path) == FileSystemEntityType.notFound) {
      _checkSession();
      await directory.create();
    }
    if (await _type(directory.path) != FileSystemEntityType.directory) {
      throw _unavailable;
    }
  }

  void _checkSession() {
    if (!_isCurrentSession()) throw const UnauthorizedException();
  }

  static void _checkLocalId(String id) {
    if (!PendingUpload.validLocalId(id)) throw _entryUnavailable;
  }

  static Future<FileSystemEntityType> _type(String path) =>
      FileSystemEntity.type(path, followLinks: false);

  static String _basename(FileSystemEntity file) =>
      file.path.substring(file.path.lastIndexOf(Platform.pathSeparator) + 1);

  static bool _isStaging(String name) =>
      name.startsWith('.stage-') &&
          PendingUpload.validLocalId(name.substring(7)) ||
      name.startsWith('.discard-') &&
          PendingUpload.validLocalId(name.substring(9));

  static String _metadataDigest(Map<String, Object?> payload) =>
      (_Sha256()..add(Uint8List.fromList(utf8.encode(jsonEncode(payload)))))
          .finish();

  static Future<void> _removeFile(File file) async {
    try {
      if (await _type(file.path) == FileSystemEntityType.file) {
        await file.delete();
      }
    } on FileSystemException {
      // Later cleanup can retry disposable files.
    }
  }

  static Future<void> _deleteStaging(Directory directory) async {
    try {
      if (await _type(directory.path) == FileSystemEntityType.directory) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException {
      // The committed journal remains readable if disposable cleanup fails.
    }
  }
}

// Copying and digest verification share the same bounded byte reader. Keeping
// the SHA-256 work in a worker isolate keeps large files off the UI isolate.
Future<String> _fileDigest(String path, int expectedBytes, {String? copyTo}) =>
    Isolate.run(() => _readDigest(path, expectedBytes, copyTo));

Future<String> _readDigest(
  String path,
  int expectedBytes,
  String? copyTo,
) async {
  const changed = ValidationException(
    'Размер или содержимое WAV изменились при чтении.',
  );
  final source = File(path);
  final before = await source.stat();
  if (before.type != FileSystemEntityType.file ||
      before.size != expectedBytes) {
    throw changed;
  }
  final input = await source.open();
  RandomAccessFile? output;
  try {
    if (copyTo != null) output = await File(copyTo).open(mode: FileMode.write);
    final sha = _Sha256();
    var remaining = expectedBytes;
    while (remaining > 0) {
      final chunk = await input.read(min(remaining, 64 * 1024));
      if (chunk.isEmpty) throw changed;
      sha.add(chunk);
      await output?.writeFrom(chunk);
      remaining -= chunk.length;
    }
    if ((await input.read(1)).isNotEmpty) throw changed;
    final after = await source.stat();
    if (after.size != expectedBytes ||
        before.modified != after.modified ||
        before.changed != after.changed) {
      throw changed;
    }
    await output?.flush();
    return sha.finish();
  } finally {
    try {
      await output?.close();
    } finally {
      await input.close();
    }
  }
}

/// SHA-256 per FIPS 180-4 sections 4.2.2, 5 and 6.2. The journal uses it to
/// compare WAV content before replay. This helper has no authentication role.
final class _Sha256 {
  static const _wordMask = 0xffffffff;
  static const _roundConstants = [
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  final _state = Uint32List.fromList([
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ]);
  final _words = Uint32List(64);
  final _tail = Uint8List(64);
  int _used = 0;
  int _length = 0;

  void add(Uint8List bytes) {
    _length += bytes.length;
    var offset = 0;
    if (_used > 0) {
      final count = min(64 - _used, bytes.length);
      _tail.setRange(_used, _used + count, bytes);
      _used += count;
      offset = count;
      if (_used < 64) return;
      _compress(ByteData.sublistView(_tail), 0);
      _used = 0;
    }
    final view = ByteData.sublistView(bytes);
    while (bytes.length - offset >= 64) {
      _compress(view, offset);
      offset += 64;
    }
    _used = bytes.length - offset;
    _tail.setRange(0, _used, bytes, offset);
  }

  String finish() {
    _tail[_used++] = 0x80;
    final view = ByteData.sublistView(_tail);
    if (_used > 56) {
      _tail.fillRange(_used, 64, 0);
      _compress(view, 0);
      _used = 0;
    }
    _tail.fillRange(_used, 56, 0);
    view.setUint64(56, _length * 8, Endian.big);
    _compress(view, 0);
    return _state.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
  }

  static int _rotate(int word, int bits) =>
      (word >>> bits) | ((word << (32 - bits)) & _wordMask);

  void _compress(ByteData block, int offset) {
    for (var i = 0; i < 16; i++) {
      _words[i] = block.getUint32(offset + i * 4, Endian.big);
    }
    for (var i = 16; i < 64; i++) {
      final x = _words[i - 15];
      final y = _words[i - 2];
      final s0 = _rotate(x, 7) ^ _rotate(x, 18) ^ (x >>> 3);
      final s1 = _rotate(y, 17) ^ _rotate(y, 19) ^ (y >>> 10);
      _words[i] = (_words[i - 16] + s0 + _words[i - 7] + s1) & _wordMask;
    }
    var a = _state[0], b = _state[1], c = _state[2], d = _state[3];
    var e = _state[4], f = _state[5], g = _state[6], h = _state[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotate(e, 6) ^ _rotate(e, 11) ^ _rotate(e, 25);
      final choose = (e & f) ^ (~e & g);
      final t1 = (h + s1 + choose + _roundConstants[i] + _words[i]) & _wordMask;
      final s0 = _rotate(a, 2) ^ _rotate(a, 13) ^ _rotate(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + majority) & _wordMask;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _wordMask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _wordMask;
    }
    _state[0] = (_state[0] + a) & _wordMask;
    _state[1] = (_state[1] + b) & _wordMask;
    _state[2] = (_state[2] + c) & _wordMask;
    _state[3] = (_state[3] + d) & _wordMask;
    _state[4] = (_state[4] + e) & _wordMask;
    _state[5] = (_state[5] + f) & _wordMask;
    _state[6] = (_state[6] + g) & _wordMask;
    _state[7] = (_state[7] + h) & _wordMask;
  }
}
