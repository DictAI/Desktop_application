import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
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

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  void _upload() {
    if (_selectedFile == null) return;
    if (widget.anonymous) {
      ref.read(anonRecordNotifierProvider.notifier).uploadPickedFile(_selectedFile!);
      Navigator.of(context).pop();
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (_) => const LabelSpeakersModal(),
      );
    } else {
      ref.read(recordNotifierProvider.notifier).uploadFile(_selectedFile!);
      Navigator.of(context).pop();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Заголовок ─────────────────────────────────────────────────
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
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Drop-зона ─────────────────────────────────────────────────
            DragTarget<List<String>>(
              onWillAcceptWithDetails: (_) {
                setState(() => _isDragging = true);
                return true;
              },
              onLeave: (_) => setState(() => _isDragging = false),
              onAcceptWithDetails: (details) {
                setState(() => _isDragging = false);
                final path = details.data.first;
                final lower = path.toLowerCase();
                if (lower.endsWith('.mp3') ||
                    lower.endsWith('.wav') ||
                    lower.endsWith('.m4a') ||
                    lower.endsWith('.ogg') ||
                    lower.endsWith('.flac')) {
                  setState(() => _selectedFile = File(path));
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
                    const Icon(Icons.upload_rounded,
                        size: 44, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text(
                      'Drag and drop your audio file here',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'or',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _pickFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'Choose File',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Выбранный файл ────────────────────────────────────────────
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
                    const Icon(Icons.audio_file_rounded,
                        color: AppColors.accent, size: 20),
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
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatSize(_selectedFile!.lengthSync()),
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _selectedFile = null),
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 18),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Кнопки ────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.surfaceElevated),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedFile != null ? _upload : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor:
                          AppColors.surfaceElevated,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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
    );
  }
}
