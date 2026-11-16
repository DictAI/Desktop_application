import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/error/app_exception.dart';
import 'wav_validator.dart';

/// A private staging copy. Discarding it never touches the picker source.
final class ImportedWav {
  ImportedWav._(this.file, this.name, this.metadata, this._directory);

  final File file;
  final String name;
  final WavMetadata metadata;
  final Directory _directory;

  Future<void> discard() => _discard(_directory);
}

/// file_picker 8.3.7 uses UIDocumentPickerModeImport on iOS: Files supplies an
/// app-owned Inbox copy, which the plugin moves into the application's tmp.
/// That path is temporary and can be replaced by another pick with the same
/// name. Copy it into a unique directory before offering it for upload.
///
/// The existing PendingUploadStore makes the durable, account-owned copy before
/// POST. This staging copy only belongs to the current selection/upload call.
final class IosWavImporter {
  IosWavImporter({
    Future<File?> Function()? pickFile,
    Future<Directory> Function()? temporaryDirectory,
    WavValidator validator = const WavValidator(),
  }) : _pickFile = pickFile ?? _pickWav,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _validator = validator;

  final Future<File?> Function() _pickFile;
  final Future<Directory> Function() _temporaryDirectory;
  final WavValidator _validator;
  // The plugin reuses tmp/<basename>, including across different modal owners.
  static bool _busy = false;
  static const _chunkBytes = 64 * 1024;
  static const _unavailable = ValidationException(
    'Не удалось импортировать WAV. Проверьте доступность файла и свободное место.',
  );
  static const _changed = ValidationException(
    'Файл изменился во время импорта. Выберите его снова.',
  );

  Future<ImportedWav?> pick({required bool Function() isCurrent}) async {
    if (!isCurrent()) return null;
    if (_busy) {
      throw const ValidationException(
        'Дождитесь завершения выбора и импорта файла.',
      );
    }
    _busy = true;
    try {
      final source = await _pickFile();
      if (source == null || !isCurrent()) return null;
      return await importFile(source, isCurrent: isCurrent);
    } on PlatformException {
      // Provider errors can include private URLs and paths.
      throw _unavailable;
    } on FileSystemException {
      throw _unavailable;
    } finally {
      _busy = false;
    }
  }

  Future<ImportedWav?> importFile(
    File source, {
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return null;
    final name = source.uri.pathSegments.last;
    if (!name.toLowerCase().endsWith('.wav')) {
      throw const ValidationException(
        'Выберите файл WAV. MP3 и M4A не поддерживаются.',
      );
    }
    Directory? staging;
    var transferred = false;
    try {
      final before = await source.stat();
      if (before.type != FileSystemEntityType.file) throw _unavailable;
      // Reject oversized/unsupported input before allocating a second copy.
      await _validator.validate(source);
      if (!isCurrent()) return null;
      final temporary = await _temporaryDirectory();
      if (!isCurrent()) return null;
      staging = await temporary.createTemp('dictai-wav-import-');
      final partial = File('${staging.path}/source.part');
      final input = await source.open();
      try {
        final output = await partial.open(mode: FileMode.write);
        try {
          var copied = 0;
          while (true) {
            if (!isCurrent()) return null;
            final bytes = await input.read(_chunkBytes);
            if (bytes.isEmpty) break;
            copied += bytes.length;
            if (copied > before.size || copied > WavValidator.maxFileBytes) {
              throw _changed;
            }
            await output.writeFrom(bytes);
          }
          if (copied != before.size) throw _changed;
          await output.flush();
        } finally {
          await output.close();
        }
      } finally {
        await input.close();
      }
      final after = await source.stat();
      if (after.type != FileSystemEntityType.file ||
          after.size != before.size ||
          after.modified != before.modified) {
        throw _changed;
      }
      final metadata = await _validator.validate(partial);
      if (!isCurrent()) return null;
      final file = await partial.rename('${staging.path}/source.wav');
      if (!isCurrent()) return null;
      transferred = true;
      return ImportedWav._(file, name, metadata, staging);
    } on FileSystemException {
      throw _unavailable;
    } finally {
      if (!transferred && staging != null) await _discard(staging);
    }
  }

  static Future<File?> _pickWav() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav'],
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );
    if (result == null) return null;
    if (result.files.length != 1 || result.files.single.path == null) {
      throw _unavailable;
    }
    return File(result.files.single.path!);
  }
}

Future<void> _discard(Directory directory) async {
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } on FileSystemException {
    // Only private temporary staging is affected. An OS-denied cleanup can be
    // retried by its owner; never fall back to deleting the external source.
  }
}
