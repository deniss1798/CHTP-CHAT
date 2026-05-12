import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';

enum AttachmentPreviewKind { image, video, document }

class AttachmentPreviewResult {
  const AttachmentPreviewResult({required this.caption});
  final String caption;
}

Future<AttachmentPreviewResult?> showAttachmentPreviewScreen(
  BuildContext context, {
  required String filePath,
  required String fileName,
  required AttachmentPreviewKind kind,
  String submitLabel = 'Отправить',
  bool showCaptionField = true,
  int? fileSizeBytes,
}) {
  return Navigator.of(context).push<AttachmentPreviewResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AttachmentPreviewScreen(
        filePath: filePath,
        fileName: fileName,
        kind: kind,
        submitLabel: submitLabel,
        showCaptionField: showCaptionField,
        fileSizeBytes: fileSizeBytes,
      ),
    ),
  );
}

class _AttachmentPreviewScreen extends StatefulWidget {
  const _AttachmentPreviewScreen({
    required this.filePath,
    required this.fileName,
    required this.kind,
    required this.submitLabel,
    required this.showCaptionField,
    required this.fileSizeBytes,
  });

  final String filePath;
  final String fileName;
  final AttachmentPreviewKind kind;
  final String submitLabel;
  final bool showCaptionField;
  final int? fileSizeBytes;

  @override
  State<_AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState extends State<_AttachmentPreviewScreen> {
  final _captionController = TextEditingController();
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.kind == AttachmentPreviewKind.video) {
      _videoController = VideoPlayerController.file(File(widget.filePath))
        ..setLooping(true)
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  String _humanSize() {
    final size = widget.fileSizeBytes;
    if (size == null || size <= 0) return '';
    const units = ['Б', 'КБ', 'МБ', 'ГБ'];
    var value = size.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final str = value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$str ${units[unit]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildPreview()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.fileSizeBytes != null)
                        Text(
                          _humanSize(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  if (widget.showCaptionField) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _captionController,
                      maxLines: 3,
                      minLines: 1,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Добавьте подпись (необязательно)',
                        hintStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surfaceSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(
                      AttachmentPreviewResult(
                        caption: _captionController.text.trim(),
                      ),
                    ),
                    child: Text(
                      widget.submitLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    switch (widget.kind) {
      case AttachmentPreviewKind.image:
        return InteractiveViewer(
          maxScale: 6,
          child: Center(
            child: Image.file(File(widget.filePath)),
          ),
        );
      case AttachmentPreviewKind.video:
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }
        return GestureDetector(
          onTap: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
            setState(() {});
          },
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  if (!controller.value.isPlaying)
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white70,
                      size: 72,
                    ),
                ],
              ),
            ),
          ),
        );
      case AttachmentPreviewKind.document:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insert_drive_file_rounded,
                  color: AppColors.accent,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.fileName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
