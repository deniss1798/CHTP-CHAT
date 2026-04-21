import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';

/// Запись круглого видеосообщения: удерживайте кнопку записи.
class VideoNoteRecordScreen extends StatefulWidget {
  const VideoNoteRecordScreen({super.key});

  @override
  State<VideoNoteRecordScreen> createState() => _VideoNoteRecordScreenState();
}

class _VideoNoteRecordScreenState extends State<VideoNoteRecordScreen> {
  CameraController? _controller;
  bool _ready = false;
  bool _recording = false;
  Timer? _maxDurationTimer;
  Timer? _recordTicker;
  DateTime? _recordStartedAt;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!camStatus.isGranted || !micStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нужны разрешения камеры и микрофона'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Камера не найдена')),
      );
      Navigator.of(context).pop();
      return;
    }

    final description = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    try {
      await controller.initialize();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Камера: $e')),
      );
      Navigator.of(context).pop();
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _ready = true;
    });
  }

  Future<void> _onPointerDown() async {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return;
    }
    if (_recording) return;

    try {
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordStartedAt = DateTime.now();
      });
      _maxDurationTimer?.cancel();
      _recordTicker?.cancel();
      _maxDurationTimer = Timer(const Duration(seconds: 60), _onPointerUp);
      _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recording) return;
        setState(() {});
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось начать запись: $e')),
      );
    }
  }

  Future<void> _onPointerUp() async {
    final controller = _controller;
    if (controller == null || !_recording) return;

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _recordTicker?.cancel();
    _recordTicker = null;

    final started = _recordStartedAt;
    setState(() {
      _recording = false;
      _recordStartedAt = null;
    });

    try {
      final file = await controller.stopVideoRecording();
      if (!mounted) return;

      final duration = started != null
          ? DateTime.now().difference(started)
          : Duration.zero;
      if (duration < const Duration(milliseconds: 500)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Слишком коротко — удерживайте кнопку дольше',
            ),
          ),
        );
        return;
      }

      Navigator.of(context).pop<String>(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка записи: $e')),
      );
    }
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    _recordTicker?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final durationLabel = _recordStartedAt == null
        ? '00:00'
        : _formatDuration(DateTime.now().difference(_recordStartedAt!));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    AppIconButtonSurface(
                      icon: AppIcons.close,
                      tooltip: 'Закрыть',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 18),
                AppSurface(
                  tone: AppSurfaceTone.elevated,
                  radius: AppRadius.xxl,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(
                    children: [
                      const Text(
                        'Видеосообщение',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Удерживайте кнопку внизу, чтобы записать. Отпустите — отправится.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _recording
                            ? 'Запись · $durationLabel'
                            : 'Готово к записи',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _recording
                              ? AppColors.accentBright
                              : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 304,
                      height: 304,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: _recording
                            ? AppGradients.accentPanel
                            : AppGradients.heroPanel,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _recording
                              ? AppColors.accentBorder
                              : AppColors.strokeSoft,
                        ),
                        boxShadow: _recording
                            ? AppShadows.accentFab()
                            : AppShadows.card,
                      ),
                      child: ClipOval(
                        child: _ready && _controller != null
                            ? CameraPreview(_controller!)
                            : Container(
                                color: AppColors.surfaceSoft,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(
                                  color: AppColors.accent,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Listener(
                  onPointerDown: (_) => _onPointerDown(),
                  onPointerUp: (_) => _onPointerUp(),
                  onPointerCancel: (_) => _onPointerUp(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: _recording ? 108 : 92,
                    height: _recording ? 108 : 92,
                    decoration: BoxDecoration(
                      gradient: _recording
                          ? const LinearGradient(
                              colors: [
                                Color(0xFFFF5E5E),
                                Color(0xFFFF8247),
                              ],
                            )
                          : AppGradients.accentPanel,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(_recording ? 160 : 90),
                        width: 2,
                      ),
                      boxShadow: AppShadows.accentFab(),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: _recording ? 34 : 42,
                      height: _recording ? 34 : 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(_recording ? 220 : 170),
                        borderRadius: BorderRadius.circular(
                          _recording ? 12 : 21,
                        ),
                      ),
                      child: Icon(
                        AppIcons.record,
                        color: AppColors.textOnAccent,
                        size: _recording ? 16 : 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Нажмите и удерживайте',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
