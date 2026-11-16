import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/dto/upload_options.dart';
import '../data/ios_wav_import.dart';
import 'record_notifier.dart';

class UploadModal extends ConsumerStatefulWidget {
  const UploadModal({super.key, this.importer});

  final IosWavImporter? importer;

  @override
  ConsumerState<UploadModal> createState() => _UploadModalState();
}

class _UploadModalState extends ConsumerState<UploadModal> {
  ImportedWav? _selection;
  bool _isDragging = false;
  bool _selecting = false;
  bool _invalidated = false;
  int _selectionGeneration = 0;
  String? _selectionError;
  late final IosWavImporter _importer;
  late UploadLanguage _language;
  late bool _mixed;

  @override
  void initState() {
    super.initState();
    _importer = widget.importer ?? IosWavImporter();
    final recording = ref.read(recordNotifierProvider);
    _language = recording.language;
    _mixed = recording.mixed;
  }

  @override
  void dispose() {
    _selectionGeneration++;
    unawaited(_selection?.discard());
    super.dispose();
  }

  bool _current(int generation) =>
      mounted && !_invalidated && generation == _selectionGeneration;

  void _invalidateSelection() {
    if (!mounted || _invalidated) return;
    _selectionGeneration++;
    final previous = _selection;
    setState(() {
      _invalidated = true;
      _selection = null;
      _selecting = false;
      _selectionError = 'Сессия изменилась. Откройте окно отправки заново.';
    });
    unawaited(previous?.discard());
  }

  Future<void> _choose({File? dropped}) async {
    if (_selecting ||
        _invalidated ||
        ref.read(recordNotifierProvider).controlsLocked) {
      return;
    }
    final generation = ++_selectionGeneration;
    final previous = _selection;
    setState(() {
      _selecting = true;
      _selection = null;
      _selectionError = null;
    });
    await previous?.discard();
    try {
      final selection = dropped == null
          ? await _importer.pick(isCurrent: () => _current(generation))
          : await _importer.importFile(
              dropped,
              isCurrent: () => _current(generation),
            );
      if (!_current(generation)) {
        await selection?.discard();
        return;
      }
      setState(() => _selection = selection);
    } on AppException catch (error) {
      if (_current(generation)) {
        setState(() => _selectionError = error.message);
      }
    } on Exception {
      if (_current(generation)) {
        setState(() => _selectionError = 'Не удалось выбрать аудиофайл.');
      }
    } finally {
      if (mounted && generation == _selectionGeneration) {
        setState(() => _selecting = false);
      }
    }
  }

  void _clearSelection() {
    final previous = _selection;
    setState(() => _selection = null);
    unawaited(previous?.discard());
  }

  void _upload() {
    final selection = _selection;
    final record = ref.read(recordNotifierProvider.notifier);
    if (selection == null ||
        _selecting ||
        _invalidated ||
        record.hasActiveOperation) {
      return;
    }
    // Transfer ownership before popping the modal. The journal copies/validates
    // these exact bytes before POST; keep staging alive until that call settles.
    _selection = null;
    unawaited(_sendSelection(record, selection, _language, _mixed));
    Navigator.of(context).pop();
  }

  Future<void> _sendSelection(
    RecordNotifier record,
    ImportedWav selection,
    UploadLanguage language,
    bool mixed,
  ) async {
    try {
      await record.uploadFile(selection.file, language: language, mixed: mixed);
    } finally {
      await selection.discard();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (_, _) => _invalidateSelection());
    ref.listen(sessionNotifierProvider, (_, _) => _invalidateSelection());
    ref.listen(recordNotifierProvider, (previous, next) {
      if (previous != null &&
          (previous.anonymous != next.anonymous ||
              !next.anonymous &&
                  previous.selectedWorkspaceId != next.selectedWorkspaceId)) {
        _invalidateSelection();
      }
    });
    final locked =
        _invalidated ||
        _selecting ||
        ref.watch(recordNotifierProvider).controlsLocked;
    final mobile =
        Theme.of(context).platform == TargetPlatform.iOS ||
        MediaQuery.sizeOf(context).width < 600;
    final picker = _picker(locked, mobile);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 40,
        vertical: 24,
      ),
      child: Container(
        width: 480,
        padding: EdgeInsets.all(mobile ? 20 : 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Upload Audio',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close upload',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (mobile)
                picker
              else
                DragTarget<List<String>>(
                  onWillAcceptWithDetails: (_) {
                    if (locked) return false;
                    setState(() => _isDragging = true);
                    return true;
                  },
                  onLeave: (_) => setState(() => _isDragging = false),
                  onAcceptWithDetails: (details) {
                    setState(() => _isDragging = false);
                    if (!locked && details.data.length == 1) {
                      unawaited(_choose(dropped: File(details.data.single)));
                    }
                  },
                  builder: (_, __, ___) => picker,
                ),
              if (_selection case final selection?) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.audio_file_rounded,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selection.name,
                          style: const TextStyle(color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove selected file',
                        onPressed: locked ? null : _clearSelection,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_selectionError case final error?) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              UploadLanguageControls(
                language: _language,
                mixed: _mixed,
                onLanguage: locked
                    ? null
                    : (value) => setState(() {
                        _language = value;
                        if (value != UploadLanguage.auto) _mixed = false;
                      }),
                onMixed: locked
                    ? null
                    : (value) => setState(() {
                        _mixed = value;
                        if (value) _language = UploadLanguage.auto;
                      }),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _selection != null && !locked ? _upload : null,
                    child: const Text('Upload'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker(bool locked, bool mobile) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: _isDragging ? AppColors.accent : AppColors.surfaceElevated,
        width: 2,
      ),
      color: _isDragging ? AppColors.accentSubtle : Colors.transparent,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selecting)
          Semantics(
            label: 'Подготовка файла',
            liveRegion: true,
            child: const CircularProgressIndicator(),
          )
        else
          const Icon(
            Icons.upload_rounded,
            size: 44,
            color: AppColors.textSecondary,
          ),
        const SizedBox(height: 12),
        Text(
          _selecting
              ? 'Подготовка файла…'
              : mobile
              ? 'Выберите WAV из Files'
              : 'Перетащите файл WAV',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: locked ? null : () => unawaited(_choose()),
          child: const Text('Choose File'),
        ),
      ],
    ),
  );
}

class UploadLanguageControls extends StatelessWidget {
  const UploadLanguageControls({
    super.key,
    required this.language,
    required this.mixed,
    required this.onLanguage,
    required this.onMixed,
  });

  final UploadLanguage language;
  final bool mixed;
  final ValueChanged<UploadLanguage>? onLanguage;
  final ValueChanged<bool>? onMixed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      DropdownButton<UploadLanguage>(
        value: language,
        itemHeight: null,
        isExpanded: true,
        items: const [
          DropdownMenuItem(
            value: UploadLanguage.auto,
            child: Text(
              'Язык: автоматически',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem(
            value: UploadLanguage.ru,
            child: Text(
              'Язык: русский',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem(
            value: UploadLanguage.en,
            child: Text(
              'Язык: английский',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: onLanguage == null
            ? null
            : (value) {
                if (value != null) onLanguage!(value);
              },
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Смешанная речь'),
        value: mixed,
        onChanged: onMixed == null
            ? null
            : (value) {
                if (value != null) onMixed!(value);
              },
      ),
    ],
  );
}
