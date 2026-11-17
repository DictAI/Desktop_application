import 'dart:io';

import 'package:flutter/services.dart';

import '../error/app_exception.dart';

/// Applies and verifies native attributes on app-owned iOS staging/journals.
///
/// The native side restricts paths to those stores. It excludes each existing
/// item from backup and uses protection available after the first device unlock,
/// so an already started microphone recording can continue while locked. New
/// files inherit directory protection; callers protect them again after writing
/// to verify their actual attributes before using a durable copy.
///
/// The compile-time native Simulator build can explicitly report that its host
/// filesystem lacks iOS protection attributes; backup exclusion is still read
/// back. This supports Simulator development without claiming device protection.
/// Native device builds always require verified protection. The shared pending
/// journal container receives only directory metadata; recursive verification
/// starts at an individual owner's directory under its journal lock.
final class IosFilePolicy {
  const IosFilePolicy({
    MethodChannel channel = const MethodChannel(
      'com.dictai/ios_storage_policy',
    ),
    bool? enabled,
  }) : _channel = channel,
       _enabled = enabled;

  final MethodChannel _channel;
  final bool? _enabled;

  Future<void> prepare(Directory directory) => protect(directory);

  Future<void> protect(FileSystemEntity entity) async {
    if (!(_enabled ?? Platform.isIOS)) {
      return;
    }
    const unavailable = ValidationException(
      'Не удалось защитить локальные файлы. Повторите попытку после разблокировки устройства.',
    );
    try {
      final response = await _channel.invokeMethod<Object?>('protect', {
        'path': entity.path,
      });
      if (response is! Map || response['excludedFromBackup'] != true) {
        throw unavailable;
      }
      final verified =
          response['protection'] == 'completeUntilFirstUserAuthentication' &&
          response['protectionVerified'] == true &&
          (response['environment'] == 'device' ||
              response['environment'] == 'simulator');
      final simulatorUnsupported =
          response['protection'] == 'unsupportedInSimulator' &&
          response['protectionVerified'] == false &&
          response['environment'] == 'simulator';
      if (!verified && !simulatorUnsupported) throw unavailable;
    } on PlatformException {
      // Native diagnostics may contain private container paths.
      throw unavailable;
    } on MissingPluginException {
      // A missing bridge must never turn iOS protection into an implicit PASS.
      throw unavailable;
    }
  }
}
