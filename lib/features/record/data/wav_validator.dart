import 'dart:io';
import 'dart:typed_data';

import '../../../core/error/app_exception.dart';

/// A seekable byte source. Each read must return exactly [count] bytes unless
/// EOF is reached. The validator neither owns nor closes caller-owned sources.
abstract interface class WavSource {
  Future<int> length();
  Future<Uint8List> readAt(int offset, int count);
}

enum WavEncoding { pcm, ieeeFloat }

final class WavMetadata {
  const WavMetadata({
    required this.encoding,
    required this.fileBytes,
    required this.dataBytes,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.blockAlign,
    required this.byteRate,
    required this.frames,
  });

  final WavEncoding encoding;
  final int fileBytes;
  final int dataBytes;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int blockAlign;
  final int byteRate;
  final int frames;

  Duration get duration => Duration(
    microseconds: frames * Duration.microsecondsPerSecond ~/ sampleRate,
  );
}

/// Preflight of the actual bytes, matching the V2 upload WAV boundary.
/// Reads at most 16 bytes per operation; audio and unknown chunks are skipped
/// by offset, never buffered. This does not prove file identity at HTTP upload.
final class WavValidator {
  const WavValidator();

  static const maxFileBytes = 1073741824;
  static const maxDurationSeconds = 7200;
  static const requirements =
      'PCM or IEEE-float RIFF WAV, 8–192 kHz, 1–8 channels, up to 2 hours '
      'and 1 GiB. PCM: 8/16/24/32 bit; float: 32/64 bit.';
  static const _invalid = ValidationException(
    'Choose a valid WAV file. $requirements',
  );
  static const _unreadable = ValidationException(
    'The WAV file could not be read. Choose an available local file.',
  );

  Future<WavMetadata> validate(File file) async {
    try {
      final handle = await file.open();
      try {
        return await validateSource(_FileWavSource(handle));
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      throw _unreadable;
    }
  }

  Future<WavMetadata> validateSource(WavSource source) async {
    try {
      return await _validate(source);
    } on FileSystemException {
      // OS exception text can include private paths; never expose it to the UI.
      throw _unreadable;
    }
  }

  Future<WavMetadata> _validate(WavSource source) async {
    final size = await source.length();
    if (size > maxFileBytes) {
      throw const ValidationException('The WAV file must be at most 1 GiB.');
    }
    if (size < 12) throw _invalid;
    final header = await _read(source, 0, 12);
    if (!_tag(header, 0, 'RIFF') ||
        !_tag(header, 8, 'WAVE') ||
        header.getUint32(4, Endian.little) + 8 != size) {
      throw _invalid;
    }

    int? format, channels, rate, byteRate, alignment, bits, dataBytes;
    var pos = 12;
    while (pos < size) {
      if (size - pos < 8) throw _invalid;
      final chunk = await _read(source, pos, 8);
      pos += 8;
      final count = chunk.getUint32(4, Endian.little);
      final padded = count + count % 2;
      if (padded > size - pos) throw _invalid;
      if (_tag(chunk, 0, 'fmt ')) {
        if (format != null || count < 16) throw _invalid;
        final fmt = await _read(source, pos, 16);
        format = fmt.getUint16(0, Endian.little);
        channels = fmt.getUint16(2, Endian.little);
        rate = fmt.getUint32(4, Endian.little);
        byteRate = fmt.getUint32(8, Endian.little);
        alignment = fmt.getUint16(12, Endian.little);
        bits = fmt.getUint16(14, Endian.little);
      } else if (_tag(chunk, 0, 'data')) {
        if (dataBytes != null) throw _invalid;
        dataBytes = count;
      }
      pos += padded;
    }

    if (format == null ||
        channels == null ||
        rate == null ||
        bits == null ||
        dataBytes == null ||
        dataBytes == 0 ||
        channels < 1 ||
        channels > 8 ||
        rate < 8000 ||
        rate > 192000) {
      throw _invalid;
    }
    final align = channels * bits ~/ 8;
    if (align == 0 ||
        alignment != align ||
        byteRate != rate * align ||
        dataBytes % align != 0) {
      throw _invalid;
    }
    final WavEncoding encoding;
    if (format == 1 && const [8, 16, 24, 32].contains(bits)) {
      encoding = WavEncoding.pcm;
    } else if (format == 3 && const [32, 64].contains(bits)) {
      encoding = WavEncoding.ieeeFloat;
    } else {
      throw _invalid;
    }
    final frames = dataBytes ~/ align;
    if (frames > rate * maxDurationSeconds) {
      throw const ValidationException(
        'The WAV duration must be at most 2 hours.',
      );
    }
    if (frames * Duration.microsecondsPerSecond ~/ rate == 0) throw _invalid;
    if (await source.length() != size) throw _invalid;
    return WavMetadata(
      encoding: encoding,
      fileBytes: size,
      dataBytes: dataBytes,
      channels: channels,
      sampleRate: rate,
      bitsPerSample: bits,
      blockAlign: align,
      byteRate: byteRate!,
      frames: frames,
    );
  }

  Future<ByteData> _read(WavSource source, int offset, int count) async {
    final bytes = await source.readAt(offset, count);
    if (bytes.length != count) throw _invalid;
    return ByteData.sublistView(bytes);
  }

  bool _tag(ByteData bytes, int offset, String tag) {
    for (var i = 0; i < tag.length; i++) {
      if (bytes.getUint8(offset + i) != tag.codeUnitAt(i)) return false;
    }
    return true;
  }
}

final class _FileWavSource implements WavSource {
  const _FileWavSource(this.handle);
  final RandomAccessFile handle;

  @override
  Future<int> length() => handle.length();

  @override
  Future<Uint8List> readAt(int offset, int count) async {
    await handle.setPosition(offset);
    return handle.read(count);
  }
}
