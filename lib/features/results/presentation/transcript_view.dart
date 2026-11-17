import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/dto/canonical_transcript_dto.dart';

/// A sliver for a validated canonical transcript. Only visible text is laid out;
/// the original DTO owns the text, including for very large single segments.
class TranscriptView extends StatefulWidget {
  const TranscriptView({
    super.key,
    required this.transcript,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final CanonicalTranscriptDto transcript;
  final EdgeInsetsGeometry padding;

  /// A local layout bound, unrelated to the canonical artifact size limit.
  /// A boundary may move back one UTF-16 unit to retain a complete code point.
  static const textChunkLength = 4096;

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  late Map<String, String> _labels;
  late List<int> _rowStarts;
  late Uint8List _overlaps;

  @override
  void initState() {
    super.initState();
    _indexTranscript();
  }

  @override
  void didUpdateWidget(covariant TranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.transcript, widget.transcript)) {
      _indexTranscript();
    }
  }

  void _indexTranscript() {
    final transcript = widget.transcript;
    _labels = {
      for (final speaker in transcript.speakers)
        speaker.speakerId: speaker.label,
      CanonicalTranscriptDto.unknownSpeaker:
          CanonicalTranscriptDto.unknownSpeaker,
    };
    final segments = transcript.segments;
    _rowStarts = List<int>.filled(segments.length + 1, 0);
    _overlaps = Uint8List(segments.length);
    var previousMaxEnd = 0;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      _rowStarts[index + 1] =
          _rowStarts[index] +
          (segment.text.length + TranscriptView.textChunkLength - 1) ~/
              TranscriptView.textChunkLength;
      if (segment.startUs < previousMaxEnd) _overlaps[index] = 1;
      if (segment.endUs > previousMaxEnd) previousMaxEnd = segment.endUs;
    }
  }

  int _segmentForRow(int row) {
    var low = 0;
    var high = widget.transcript.segments.length;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (_rowStarts[middle] <= row) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }

  static int _boundary(String text, int offset) {
    if (offset >= text.length) return text.length;
    if (offset > 0) {
      final previous = text.codeUnitAt(offset - 1);
      final current = text.codeUnitAt(offset);
      if (previous >= 0xD800 &&
          previous <= 0xDBFF &&
          current >= 0xDC00 &&
          current <= 0xDFFF) {
        return offset - 1;
      }
    }
    return offset;
  }

  Widget _row(BuildContext context, int row) {
    final segmentIndex = _segmentForRow(row);
    final segment = widget.transcript.segments[segmentIndex];
    final chunk = row - _rowStarts[segmentIndex];
    final start = _boundary(
      segment.text,
      chunk * TranscriptView.textChunkLength,
    );
    final end = _boundary(
      segment.text,
      (chunk + 1) * TranscriptView.textChunkLength,
    );
    final label = _labels[segment.speakerId]!;
    final identity = label == segment.speakerId
        ? label
        : '$label (${segment.speakerId})';
    final interval = '${_time(segment.startUs)} — ${_time(segment.endUs)}';
    final overlap = _overlaps[segmentIndex] != 0;
    return Padding(
      key: ValueKey('transcript-row-$segmentIndex-$chunk'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Semantics(
        container: true,
        label:
            '$identity. $interval.'
            '${overlap ? ' Перекрытие реплик.' : ''}'
            '${chunk > 0 ? ' Продолжение реплики.' : ''}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  if (label != segment.speakerId)
                    Text(
                      segment.speakerId,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  Text(
                    interval,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  if (overlap)
                    Text(
                      'Перекрытие реплик',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  if (chunk > 0)
                    Text(
                      'Продолжение реплики',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(segment.text.substring(start, end)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: widget.padding,
    sliver: widget.transcript.speechState == CanonicalSpeechState.noSpeech
        ? const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Речь не обнаружена.'),
            ),
          )
        : SliverList.builder(
            itemCount: _rowStarts.last,
            itemBuilder: _row,
            addAutomaticKeepAlives: false,
          ),
  );
}

// Integer microseconds stay exact all the way to the UI, including large
// offsets. Never round through double, fabricate zero, or infer word timing.
String _time(int microseconds) {
  final hours = microseconds ~/ 3600000000;
  final minutes = microseconds ~/ 60000000 % 60;
  final seconds = microseconds ~/ 1000000 % 60;
  final remainder = microseconds % 1000000;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${remainder.toString().padLeft(6, '0')}';
}
