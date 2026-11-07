import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/error/app_exception.dart';
import 'audio_capture.dart';
import 'wav_validator.dart';

typedef LinuxProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

/// Captures one microphone and, optionally, the current output's monitor.
/// Every child is observed until exit and its pipes are drained.
final class LinuxAudioCapture implements AudioCapture {
  LinuxAudioCapture({
    required this.captureSystemAudio,
    LinuxProcessStarter? startProcess,
    Future<Directory> Function()? temporaryDirectory,
    bool? isLinux,
    this.startupGrace = const Duration(milliseconds: 200),
    this.commandTimeout = const Duration(seconds: 5),
    this.stopTimeout = const Duration(seconds: 5),
    this.mixTimeout = const Duration(minutes: 15),
  }) : _startProcess = startProcess ?? _launchProcess,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _isLinux = isLinux ?? Platform.isLinux;

  final bool captureSystemAudio;
  final LinuxProcessStarter _startProcess;
  final Future<Directory> Function() _temporaryDirectory;
  final bool _isLinux;
  final Duration startupGrace, commandTimeout, stopTimeout, mixTimeout;
  final _recorders = <_Child>[];
  final _commands = <_Child>[];
  Future<void> _tail = Future<void>.value();
  Future<void>? _disposal;
  Completer<void>? _cancelCommand;
  bool _closing = false;
  CaptureStatus _status = CaptureStatus.idle;
  Directory? _directory;
  File? _finished;

  static const _closed = ValidationException(
    'Запись уже закрыта. Начните новую запись.',
  );
  static const _failed = ServerException(
    'Не удалось завершить аудиозапись Linux. Доступные исходные файлы сохранены.',
  );
  static const _noPause = ValidationException(
    'Пауза записи на Linux недоступна.',
  );

  @override
  CaptureStatus get status => _status;
  @override
  bool get supportsPause => false;
  @override
  String? get sourcePath => _finished?.path ?? _microphone?.path;
  File? get _microphone =>
      _directory == null ? null : File('${_directory!.path}/microphone.wav');
  File? get _system =>
      _directory == null ? null : File('${_directory!.path}/system.wav');

  static Future<Process> _launchProcess(
    String executable,
    List<String> arguments,
  ) => Process.start(
    executable,
    arguments,
    runInShell: false,
    environment: {'LC_ALL': 'C'},
  );

  Future<T> _queue<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        done.complete();
      }
    }();
  }

  void _checkOpen() {
    if (!_isLinux) {
      throw const ValidationException(
        'Этот способ записи доступен только на Linux.',
      );
    }
    if (_closing) throw _closed;
  }

  Future<_Child> _spawn(
    String program,
    List<String> arguments, {
    bool collectOutput = false,
  }) async {
    try {
      return _Child(
        await _startProcess(program, arguments),
        collectOutput: collectOutput,
      );
    } on ProcessException {
      throw ServerException(
        'Не удалось запустить $program. Проверьте доступность программы и звуковой среды Linux.',
      );
    }
  }

  Future<String> _command(
    String program,
    List<String> args, {
    bool collectOutput = false,
    Duration? timeout,
  }) async {
    final child = await _spawn(program, args, collectOutput: collectOutput);
    _commands.add(child);
    final cancel = Completer<void>();
    _cancelCommand = cancel;
    if (_closing) cancel.complete();
    try {
      final code = await Future.any<int?>([
        child.joined,
        cancel.future.then<int?>((_) => null),
      ]).timeout(timeout ?? commandTimeout);
      if (code == null) {
        await child.terminate(stopTimeout);
        throw _closed;
      }
      if (code != 0 || child.outputFailed) {
        throw ServerException(
          '$program не завершил аудиооперацию. Проверьте звуковую среду Linux.',
        );
      }
      return utf8.decode(child.output, allowMalformed: false);
    } on TimeoutException {
      await child.terminate(stopTimeout);
      throw ServerException('$program не завершил аудиооперацию вовремя.');
    } on FormatException {
      throw ServerException('Не удалось прочитать ответ $program.');
    } finally {
      _cancelCommand = null;
      if (child.finished) _commands.remove(child);
    }
  }

  Future<List<String>> _sources() async {
    final output = await _command('pactl', [
      'list',
      'short',
      'sources',
    ], collectOutput: true);
    return LineSplitter.split(output)
        .map((line) => line.trim().split(RegExp(r'\s+')))
        .where(
          (fields) => fields.length >= 2 && int.tryParse(fields.first) != null,
        )
        .map((fields) => fields[1])
        .toList();
  }

  String? _setting(String info, String name) {
    final prefix = '$name:';
    for (final line in LineSplitter.split(info)) {
      if (line.startsWith(prefix)) return line.substring(prefix.length).trim();
    }
    return null;
  }

  @override
  Future<List<InputDevice>> listInputDevices() => _queue(() async {
    _checkOpen();
    return List.unmodifiable(
      (await _sources())
          .where((source) => !source.endsWith('.monitor'))
          .map((source) => InputDevice(id: source, label: source)),
    );
  });

  Future<_Child> _capture(String source, File file) => _spawn('parec', [
    '--device=$source',
    '--rate=16000',
    '--channels=1',
    '--format=s16le',
    '--file-format=wav',
    '--',
    file.path,
  ]);

  @override
  Future<void> start({InputDevice? device}) => _queue(() async {
    _checkOpen();
    if (_status == CaptureStatus.recording) return;
    await _cleanupChildren();
    _status = CaptureStatus.starting;
    _directory = null;
    _finished = null;
    try {
      final sources = await _sources();
      final info = await _command('pactl', ['info'], collectOutput: true);
      final microphone = device?.id ?? _setting(info, 'Default Source');
      if (microphone == null ||
          microphone.endsWith('.monitor') ||
          !sources.contains(microphone)) {
        throw const ValidationException('Выберите доступный микрофон Linux.');
      }
      String? monitor;
      if (captureSystemAudio) {
        final sink = _setting(info, 'Default Sink');
        monitor = sink == null ? null : '$sink.monitor';
        if (monitor == null || !sources.contains(monitor)) {
          throw const ValidationException(
            'Системный звук недоступен. Проверьте аудиовыход или выберите запись только с микрофона.',
          );
        }
        // Discover a missing mixer before recording the inputs.
        await _command('ffmpeg', ['-version']);
      }
      _checkOpen();
      _directory = await (await _temporaryDirectory()).createTemp(
        'dictai-linux-capture-',
      );
      _checkOpen();
      _recorders.add(await _capture(microphone, _microphone!));
      if (monitor != null) {
        _checkOpen();
        _recorders.add(await _capture(monitor, _system!));
      }
      await Future<void>.delayed(startupGrace);
      _checkOpen();
      if (_recorders.any((child) => child.exited)) throw _failed;
      _status = CaptureStatus.recording;
    } on AppException {
      _status = CaptureStatus.failed;
      await _stopRecorders(requireComplete: false);
      rethrow;
    } on FileSystemException {
      _status = CaptureStatus.failed;
      await _stopRecorders(requireComplete: false);
      throw _failed;
    } on MissingPlatformDirectoryException {
      _status = CaptureStatus.failed;
      await _stopRecorders(requireComplete: false);
      throw _failed;
    }
  });

  @override
  Future<void> pause() => Future.error(_noPause);
  @override
  Future<void> resume() => Future.error(_noPause);

  @override
  Future<File?> finish({required bool confirmed}) {
    if (!confirmed) return Future<File?>.value();
    return _queue(() async {
      _checkOpen();
      if (_finished != null) return _finished;
      if (_status != CaptureStatus.recording) throw _failed;
      _status = CaptureStatus.finalizing;
      try {
        await _stopRecorders(requireComplete: true);
        final microphone = _microphone!;
        await _validate(microphone);
        final finalFile = captureSystemAudio
            ? await _mix(microphone, _system!)
            : microphone;
        _checkOpen();
        _finished = finalFile;
        if (captureSystemAudio) {
          await _deleteOwned(microphone);
          await _deleteOwned(_system!);
        }
        _checkOpen();
        _status = CaptureStatus.finished;
        return finalFile;
      } on AppException {
        _status = CaptureStatus.failed;
        rethrow;
      } on FileSystemException {
        _status = CaptureStatus.failed;
        throw _failed;
      }
    });
  }

  Future<void> _validate(File file) async {
    final wav = await const WavValidator().validate(file);
    if (wav.encoding != WavEncoding.pcm ||
        wav.sampleRate != 16000 ||
        wav.channels != 1 ||
        wav.bitsPerSample != 16) {
      throw _failed;
    }
  }

  Future<File> _mix(File mic, File system) async {
    await _validate(system);
    _checkOpen();
    final partial = File('${_directory!.path}/mixed.part');
    try {
      await _command('ffmpeg', [
        '-nostdin',
        '-hide_banner',
        '-loglevel',
        'error',
        '-n',
        '-i',
        mic.path,
        '-i',
        system.path,
        '-filter_complex',
        '[0:a][1:a]amix=inputs=2:duration=longest',
        '-c:a',
        'pcm_s16le',
        '-ar',
        '16000',
        '-ac',
        '1',
        '-f',
        'wav',
        partial.path,
      ], timeout: mixTimeout);
      await _validate(partial);
      _checkOpen();
      return await partial.rename('${_directory!.path}/recording.wav');
    } finally {
      await _deleteOwned(partial);
    }
  }

  Future<void> _deleteOwned(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cleanup never replaces the outcome of the capture or the mixer.
    }
  }

  Future<void> _stopRecorders({required bool requireComplete}) async {
    final stopped = await Future.wait(
      _recorders.map((child) => child.terminate(stopTimeout)),
    );
    _recorders.removeWhere((child) => child.finished);
    if (_recorders.isNotEmpty || requireComplete && stopped.any((ok) => !ok)) {
      throw _failed;
    }
  }

  Future<void> _stopCommands() async {
    await Future.wait(_commands.map((child) => child.terminate(stopTimeout)));
    _commands.removeWhere((child) => child.finished);
    if (_commands.isNotEmpty) throw _failed;
  }

  Future<void> _cleanupChildren() async {
    // A failed auxiliary join must not prevent stopping microphone/monitor.
    await Future.wait<void>([
      _stopCommands(),
      _stopRecorders(requireComplete: false),
    ]);
  }

  @override
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    _closing = true;
    final command = _cancelCommand;
    if (command != null && !command.isCompleted) command.complete();
    final work = _queue(() async {
      try {
        await _cleanupChildren();
        _status = CaptureStatus.disposed;
      } on AppException {
        _status = CaptureStatus.failed;
        rethrow;
      }
    });
    _disposal = work;
    work.then(
      (_) {},
      onError: (Object _) {
        _disposal = null;
      },
    );
    return work;
  }
}

/// Keeps only small command metadata in memory. Capture/mixer stdout and stderr
/// are drained from the start so a full pipe cannot block child termination.
final class _Child {
  _Child(this.process, {required bool collectOutput}) {
    final stdout = process.stdout
        .listen((bytes) {
          if (!collectOutput || outputFailed) return;
          if (output.length + bytes.length > 65536) {
            outputFailed = true;
          } else {
            output.addAll(bytes);
          }
        })
        .asFuture<void>()
        .catchError(_pipeFailed);
    final stderr = process.stderr.drain<void>().catchError(_pipeFailed);
    final exit = process.exitCode.then(
      (code) {
        exited = true;
        return code;
      },
      onError: (Object _) {
        exited = true;
        return -1;
      },
    );
    joined = () async {
      final code = await exit;
      await Future.wait([stdout, stderr]);
      finished = true;
      return code;
    }();
  }

  final Process process;
  final output = <int>[];
  bool outputFailed = false;
  bool exited = false;
  bool finished = false;
  late final Future<int> joined;

  void _pipeFailed(Object _) => outputFailed = true;

  Future<bool> terminate(Duration timeout) async {
    final active = !exited;
    if (active) process.kill(ProcessSignal.sigterm);
    try {
      final code = await joined.timeout(timeout);
      return active && code == 0 && !outputFailed;
    } on TimeoutException {
      if (!exited) process.kill(ProcessSignal.sigkill);
      try {
        await joined.timeout(timeout);
      } on TimeoutException {
        return false;
      }
      return false;
    }
  }
}
