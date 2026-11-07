import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/data/wav_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = WavValidator();
  final invalid = throwsA(isA<ValidationException>());

  group('V2 WAV byte preflight', () {
    for (final (format, bits) in [
      (1, 8),
      (1, 16),
      (1, 24),
      (1, 32),
      (3, 32),
      (3, 64),
    ]) {
      test(
        'accepts format=$format bits=$bits at rate/channel bounds',
        () async {
          for (final (rate, channels) in [(8000, 1), (192000, 8)]) {
            final align = channels * bits ~/ 8;
            final metadata = await validator.validateSource(
              _wav(
                format: format,
                bits: bits,
                rate: rate,
                channels: channels,
                dataBytes: align,
              ),
            );
            expect(
              metadata.encoding,
              format == 1 ? WavEncoding.pcm : WavEncoding.ieeeFloat,
            );
            expect(metadata.frames, 1);
            expect(metadata.duration.inMicroseconds, 1000000 ~/ rate);
            expect(metadata.sampleRate, rate);
            expect(metadata.channels, channels);
            expect(metadata.bitsPerSample, bits);
            expect(metadata.blockAlign, align);
            expect(metadata.byteRate, rate * align);
          }
        },
      );
    }

    test(
      'uses bytes rather than extension and closes its local file',
      () async {
        final dir = await Directory.systemTemp.createTemp('dictai-wav-test-');
        addTearDown(() => dir.delete(recursive: true));
        final source = _wav(dataBytes: 16000);
        final file = File('${dir.path}/audio.bin');
        await file.writeAsBytes(await source.readAt(0, source.size));
        final result = await validator.validate(file);
        expect(result.frames, 8000);
        expect(result.duration, const Duration(seconds: 1));
        expect(result.fileBytes, source.size);
        expect(result.dataBytes, 16000);
        await file.delete();
        final disguised = File('${dir.path}/not-a-wav.wav');
        await disguised.writeAsBytes('not audio/wav'.codeUnits);
        await expectLater(validator.validate(disguised), invalid);
      },
    );

    test(
      'skips padded unknown chunks and extended fmt; data may precede fmt',
      () async {
        final source = _chunks([
          _Chunk('JUNK', 3, Uint8List.fromList([1, 2, 3])),
          const _Chunk('data', 1),
          _Chunk('fmt ', 19, _fmt(bits: 8)),
          const _Chunk('LIST', 2),
        ]);
        final metadata = await validator.validateSource(source);
        expect(metadata.frames, 1);
        expect(source.reads, [
          (0, 12),
          (12, 8),
          (24, 8),
          (34, 8),
          (42, 16),
          (62, 8),
        ]);
      },
    );

    for (final tag in ['RF64', 'RIFX', 'OggS', 'fLaC']) {
      test('rejects $tag container', () async {
        final source = _wav()..put(0, Uint8List.fromList(tag.codeUnits));
        await expectLater(validator.validateSource(source), invalid);
      });
    }

    test('rejects wrong WAVE tag and RIFF file length', () async {
      await expectLater(
        validator.validateSource(
          _wav()..put(8, Uint8List.fromList('AVI '.codeUnits)),
        ),
        invalid,
      );
      await expectLater(
        validator.validateSource(_wav()..put(4, _u32(1))),
        invalid,
      );
      await expectLater(
        validator.validateSource(_SparseSource(11, {})),
        invalid,
      );
    });

    final malformedChunks = <String, List<_Chunk>>{
      'missing fmt': [const _Chunk('data', 4)],
      'missing data': [_Chunk('fmt ', 16, _fmt())],
      'short fmt': [
        _Chunk('fmt ', 15, _fmt().sublist(0, 15)),
        const _Chunk('data', 4),
      ],
      'duplicate fmt': [
        _Chunk('fmt ', 16, _fmt()),
        _Chunk('fmt ', 16, _fmt()),
        const _Chunk('data', 4),
      ],
      'duplicate data': [
        _Chunk('fmt ', 16, _fmt()),
        const _Chunk('data', 4),
        const _Chunk('data', 4),
      ],
      'empty data': [_Chunk('fmt ', 16, _fmt()), const _Chunk('data', 0)],
    };
    for (final entry in malformedChunks.entries) {
      test('rejects ${entry.key}', () async {
        await expectLater(
          validator.validateSource(_chunks(entry.value)),
          invalid,
        );
      });
    }

    final invalidMetadata = <String, _SparseSource>{
      'zero channels': _wav(channels: 0),
      'nine channels': _wav(channels: 9),
      'sample rate below 8 kHz': _wav(rate: 7999),
      'sample rate above 192 kHz': _wav(rate: 192001),
      'compressed format': _wav(format: 6),
      'extensible format': _wav(format: 0xfffe),
      'PCM 12 bit': _wav(bits: 12),
      'PCM 64 bit': _wav(bits: 64),
      'float 16 bit': _wav(format: 3, bits: 16),
      'incorrect block alignment': _wav(alignment: 1),
      'incorrect byte rate': _wav(byteRate: 1),
      'incomplete audio frame': _wav(dataBytes: 3),
    };
    for (final entry in invalidMetadata.entries) {
      test('rejects ${entry.key}', () async {
        await expectLater(validator.validateSource(entry.value), invalid);
      });
    }

    test(
      'rejects out-of-bounds chunks, missing pad and trailing bytes',
      () async {
        final beyondEnd = _wav()..put(40, _u32(0xffffffff));
        await expectLater(validator.validateSource(beyondEnd), invalid);
        final missingPad = _wav(bits: 8, dataBytes: 1);
        missingPad.size--;
        missingPad.put(4, _u32(missingPad.size - 8));
        await expectLater(validator.validateSource(missingPad), invalid);
        final trailing = _wav();
        trailing.size++;
        trailing.put(4, _u32(trailing.size - 8));
        await expectLater(validator.validateSource(trailing), invalid);
      },
    );

    test(
      'rejects short metadata reads and a file resized during preflight',
      () async {
        final shortRead = _wav()..shortReadOffset = 20;
        await expectLater(validator.validateSource(shortRead), invalid);
        final resized = _wav()..resizeOnSecondLength = true;
        await expectLater(validator.validateSource(resized), invalid);
      },
    );

    test('accepts exactly 7200 s and rejects one frame above it', () async {
      // Sparse source declares a large payload but stores only header bytes.
      // This proves metadata arithmetic and seeks, not a real 2-hour recording.
      final exact = _wav(bits: 8, dataBytes: 8000 * 7200);
      final result = await validator.validateSource(exact);
      expect(result.duration, const Duration(seconds: 7200));
      expect(exact.bytesRead, 44);
      final above = _wav(bits: 8, dataBytes: 8000 * 7200 + 1);
      await expectLater(
        validator.validateSource(above),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('2 hours'),
          ),
        ),
      );
    });

    test(
      'accepts exact 1 GiB; rejects one byte above before any read',
      () async {
        final exact = _wav(
          bits: 8,
          rate: 192000,
          dataBytes: WavValidator.maxFileBytes - 44,
        );
        expect(exact.size, 1073741824);
        final result = await validator.validateSource(exact);
        expect(result.fileBytes, 1073741824);
        expect(exact.bytesRead, 44);
        expect(
          exact.fragments.values.fold<int>(
            0,
            (sum, bytes) => sum + bytes.length,
          ),
          44,
        );
        final above = _SparseSource(1073741825, {});
        await expectLater(
          validator.validateSource(above),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('1 GiB'),
            ),
          ),
        );
        expect(above.reads, isEmpty);
      },
    );

    test(
      'skips nearly 1 GiB of unknown data using only bounded header reads',
      () async {
        final source = _chunks([
          _Chunk('fmt ', 16, _fmt(bits: 8)),
          const _Chunk('JUNK', WavValidator.maxFileBytes - 54),
          const _Chunk('data', 1),
        ]);
        expect(source.size, WavValidator.maxFileBytes);
        expect((await validator.validateSource(source)).frames, 1);
        expect(source.bytesRead, 52);
        expect(
          source.reads.map((r) => r.$2),
          everyElement(lessThanOrEqualTo(16)),
        );
        expect(source.reads.last.$1, WavValidator.maxFileBytes - 10);
      },
    );

    test(
      'reports safe read errors without OS details or private paths',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'dictai-wav-unreadable-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final privatePath = '${dir.path}/private-example/audio.wav';
        await expectLater(
          validator.validate(File(privatePath)),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              isNot(contains(privatePath)),
            ),
          ),
        );
      },
    );
  });

  group('immutable U01/U02 upload options', () {
    const workspace = 'A1111111-1111-4111-8111-111111111111';
    UploadOptions options({
      bool anonymous = false,
      String? workspaceId = workspace,
      String key = 'upload-key',
      UploadLanguage language = UploadLanguage.auto,
      bool mixed = false,
      UploadSource source = const ImportedWavUploadSource(),
    }) => UploadOptions(
      anonymous: anonymous,
      workspaceId: workspaceId,
      idempotencyKey: key,
      source: source,
      language: language,
      mixed: mixed,
    );

    test('serializes exactly the existing fields and preserves auto/ru/en', () {
      for (final language in UploadLanguage.values) {
        expect(options(language: language).toMultipartFields(), {
          'workspace_id': workspace.toLowerCase(),
          'language': language.wireValue,
          'mixed': 'false',
        });
      }
    });

    test('anonymous omits workspace; ordinary requires an exact UUID', () {
      for (final value in [null, '']) {
        final anonymous = options(anonymous: true, workspaceId: value);
        expect(anonymous.workspaceId, isNull);
        expect(anonymous.toMultipartFields(), {
          'language': '',
          'mixed': 'false',
        });
      }
      expect(() => options(anonymous: true), invalid);
      for (final value in [
        null,
        '',
        'not-a-uuid',
        '$workspace\n',
        ' $workspace',
      ]) {
        expect(() => options(workspaceId: value), invalid);
      }
    });

    test('mixed requires auto and never silently changes language', () {
      expect(options(mixed: true).toMultipartFields()['language'], '');
      expect(options(mixed: true).toMultipartFields()['mixed'], 'true');
      for (final language in [UploadLanguage.ru, UploadLanguage.en]) {
        expect(() => options(mixed: true, language: language), invalid);
      }
    });

    test('snapshots mic/system/workspace/language/key before form changes', () {
      var selectedWorkspace = workspace;
      var deviceId = 'mic-original';
      var system = true;
      var language = UploadLanguage.ru;
      var key = 'fixed-before-start';
      final snapshot = options(
        workspaceId: selectedWorkspace,
        key: key,
        language: language,
        source: RecordingUploadSource(
          microphoneDeviceId: deviceId,
          captureSystemAudio: system,
        ),
      );
      final fields = snapshot.toMultipartFields();
      selectedWorkspace = 'b2222222-2222-4222-8222-222222222222';
      deviceId = 'another-mic';
      system = false;
      language = UploadLanguage.en;
      key = 'a-new-upload';
      final next = options(
        workspaceId: selectedWorkspace,
        key: key,
        language: language,
        source: RecordingUploadSource(
          microphoneDeviceId: deviceId,
          captureSystemAudio: system,
        ),
      );
      expect(snapshot.workspaceId, workspace.toLowerCase());
      expect(snapshot.idempotencyKey, 'fixed-before-start');
      expect(snapshot.language, UploadLanguage.ru);
      final capture = snapshot.source as RecordingUploadSource;
      expect(capture.microphoneDeviceId, 'mic-original');
      expect(capture.captureSystemAudio, isTrue);
      expect(snapshot.toMultipartFields(), fields);
      expect(snapshot.toMultipartFields(), isNot(next.toMultipartFields()));
      expect(() => fields['language'] = 'en', throwsUnsupportedError);
    });

    test('source/device choices stay local, import has no capture fields', () {
      final mic = RecordingUploadSource();
      expect(mic.microphoneDeviceId, isNull);
      expect(mic.captureSystemAudio, isFalse);
      expect(() => RecordingUploadSource(microphoneDeviceId: ''), invalid);
      final captured = options(
        source: RecordingUploadSource(
          microphoneDeviceId: 'selected-device',
          captureSystemAudio: true,
        ),
      );
      expect(captured.toMultipartFields(), options().toMultipartFields());
      expect(options().source, isA<ImportedWavUploadSource>());
    });

    test('checks idempotency by UTF-8 bytes and preserves the exact input', () {
      for (final key in [
        'a' * 128,
        'я' * 64,
        '😀' * 32,
        'a\t b',
        '\ufeffkey',
      ]) {
        expect(options(key: key).idempotencyKey, key);
      }
      for (final key in [
        '',
        'a' * 129,
        'я' * 65,
        '😀' * 33,
        String.fromCharCode(0xd800),
        String.fromCharCode(0xdc00),
      ]) {
        expect(() => options(key: key), invalid);
      }
    });

    test('rejects Go TrimSpace boundaries and NUL/CR/LF anywhere', () {
      for (final space in [
        ' ',
        '\t',
        '\n',
        '\v',
        '\f',
        '\r',
        '\u0085',
        '\u00a0',
        '\u1680',
        '\u2000',
        '\u200a',
        '\u2028',
        '\u2029',
        '\u202f',
        '\u205f',
        '\u3000',
      ]) {
        expect(() => options(key: '${space}key'), invalid);
        expect(() => options(key: 'key$space'), invalid);
      }
      for (final key in ['a\x00b', 'a\rb', 'a\nb']) {
        expect(() => options(key: key), invalid);
      }
    });

    test('invalid metadata errors do not echo source input', () {
      const sensitive = 'private-workspace-value';
      expect(
        () => options(workspaceId: sensitive),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            isNot(contains(sensitive)),
          ),
        ),
      );
      expect(
        () => options(key: 'private-key\n'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            isNot(contains('private-key')),
          ),
        ),
      );
    });
  });
}

// Stores only small header fragments; declared audio/unknown payload is absent.
// Large-boundary tests exercise the same parser through this seekable source.
final class _SparseSource implements WavSource {
  _SparseSource(this.size, this.fragments);
  int size;
  final Map<int, Uint8List> fragments;
  final reads = <(int, int)>[];
  int? shortReadOffset;
  bool resizeOnSecondLength = false;
  int _lengthCalls = 0;
  int get bytesRead => reads.fold(0, (sum, item) => sum + item.$2);

  void put(int offset, Uint8List bytes) => fragments[offset] = bytes;

  @override
  Future<int> length() async =>
      resizeOnSecondLength && ++_lengthCalls > 1 ? size + 1 : size;

  @override
  Future<Uint8List> readAt(int offset, int count) async {
    reads.add((offset, count));
    final available = (size - offset).clamp(0, count);
    final result = Uint8List(available);
    for (final entry in fragments.entries) {
      final start = entry.key > offset ? entry.key : offset;
      final fragmentEnd = entry.key + entry.value.length;
      final end = fragmentEnd < offset + available
          ? fragmentEnd
          : offset + available;
      if (start < end) {
        result.setRange(
          start - offset,
          end - offset,
          entry.value,
          start - entry.key,
        );
      }
    }
    return shortReadOffset == offset
        ? result.sublist(0, result.length - 1)
        : result;
  }
}

final class _Chunk {
  const _Chunk(this.tag, this.size, [this.prefix]);
  final String tag;
  final int size;
  final Uint8List? prefix;
}

_SparseSource _wav({
  int format = 1,
  int channels = 1,
  int rate = 8000,
  int bits = 16,
  int? alignment,
  int? byteRate,
  int dataBytes = 16,
}) => _chunks([
  _Chunk(
    'fmt ',
    16,
    _fmt(
      format: format,
      channels: channels,
      rate: rate,
      bits: bits,
      alignment: alignment,
      byteRate: byteRate,
    ),
  ),
  _Chunk('data', dataBytes),
]);

Uint8List _fmt({
  int format = 1,
  int channels = 1,
  int rate = 8000,
  int bits = 16,
  int? alignment,
  int? byteRate,
}) {
  final align = channels * bits ~/ 8;
  final bytes = ByteData(16)
    ..setUint16(0, format, Endian.little)
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, rate, Endian.little)
    ..setUint32(8, byteRate ?? rate * align, Endian.little)
    ..setUint16(12, alignment ?? align, Endian.little)
    ..setUint16(14, bits, Endian.little);
  return bytes.buffer.asUint8List();
}

_SparseSource _chunks(List<_Chunk> chunks) {
  final fragments = <int, Uint8List>{};
  var offset = 12;
  for (final chunk in chunks) {
    fragments[offset] = Uint8List.fromList([
      ...chunk.tag.codeUnits,
      ..._u32(chunk.size),
    ]);
    if (chunk.prefix != null) fragments[offset + 8] = chunk.prefix!;
    offset += 8 + chunk.size + chunk.size % 2;
  }
  fragments[0] = Uint8List.fromList([
    ...'RIFF'.codeUnits,
    ..._u32(offset - 8),
    ...'WAVE'.codeUnits,
  ]);
  return _SparseSource(offset, fragments);
}

Uint8List _u32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
