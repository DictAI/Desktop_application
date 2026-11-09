import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/dto/upload_options.dart';
import 'anonymous_record_notifier.dart';
import 'label_speakers_modal.dart';
import 'record_notifier.dart';

class UploadModal extends ConsumerStatefulWidget {
  final bool anonymous;
  const UploadModal({super.key, this.anonymous = false});

  @override
  ConsumerState<UploadModal> createState() => _UploadModalState();
}

class _UploadModalState extends ConsumerState<UploadModal> {
  File? _selectedFile;
  bool _isDragging = false;
  bool _invalidated = false;
  String? _selectionError;
  late UploadLanguage _language;
  late bool _mixed;

  @override
  void initState() {
    super.initState();
    final recording = ref.read(recordNotifierProvider);
    _language = recording.language;
    _mixed = recording.mixed;
  }

  void _invalidateSelection() {
    if (!mounted || _invalidated) return;
    setState(() {
      _invalidated = true;
      _selectedFile = null;
      _selectionError = 'Сессия изменилась. Откройте окно отправки заново.';
    });
  }

  void _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: widget.anonymous ? FileType.audio : FileType.custom,
        allowedExtensions: widget.anonymous ? null : const ['wav'],
        allowMultiple: false,
      );
      if (!mounted || _invalidated) return;
      final path = result?.files.single.path;
      if (path != null) _selectPath(path);
    } on Exception {
      if (mounted && !_invalidated) {
        setState(() => _selectionError = 'Не удалось выбрать аудиофайл.');
      }
    }
  }

  void _selectPath(String path) {
    final lower = path.toLowerCase();
    final extensions = widget.anonymous
        ? const ['.wav', '.mp3', '.m4a', '.ogg', '.flac']
        : const ['.wav'];
    final allowed = extensions.any(lower.endsWith);
    setState(() {
      _selectedFile = allowed ? File(path) : null;
      _selectionError = allowed ? null : 'Выберите файл WAV.';
    });
  }

  void _upload() {
    final file = _selectedFile;
    final record = ref.read(recordNotifierProvider.notifier);
    if (file == null || _invalidated || record.hasActiveOperation) return;
    if (widget.anonymous) {
      ref.read(anonRecordNotifierProvider.notifier).uploadPickedFile(file);
      Navigator.of(context).pop();
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (_) => const LabelSpeakersModal(),
      );
    } else {
      record.uploadFile(file, language: _language, mixed: _mixed);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (_, _) => _invalidateSelection());
    ref.listen(sessionNotifierProvider, (_, _) => _invalidateSelection());
    final locked =
        _invalidated || ref.watch(recordNotifierProvider).controlsLocked;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upload Audio',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

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
                    _selectPath(details.data.single);
                  }
                },
                builder: (context, _, __) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isDragging
                          ? AppColors.accent
                          : AppColors.surfaceElevated,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    color: _isDragging
                        ? AppColors.accentSubtle
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.upload_rounded,
                        size: 44,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.anonymous
                            ? 'Drag and drop your audio file here'
                            : 'Перетащите файл WAV',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'or',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: locked ? null : _pickFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Choose File',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_selectedFile != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.path
                                  .split(Platform.pathSeparator)
                                  .last,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _selectedFile = null),
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
                Text(error, style: const TextStyle(color: AppColors.error)),
              ],
              if (!widget.anonymous) ...[
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
              ],
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.surfaceElevated,
                        ),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedFile != null && !locked
                          ? _upload
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        disabledBackgroundColor: AppColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Upload',
                        style: TextStyle(
                          color: _selectedFile != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        isExpanded: true,
        items: const [
          DropdownMenuItem(
            value: UploadLanguage.auto,
            child: Text('Язык: автоматически'),
          ),
          DropdownMenuItem(
            value: UploadLanguage.ru,
            child: Text('Язык: русский'),
          ),
          DropdownMenuItem(
            value: UploadLanguage.en,
            child: Text('Язык: английский'),
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
