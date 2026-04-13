import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';

/// Запись круглого видеосообщения в стиле Telegram: удерживайте кнопку записи.
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

    final camDesc = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camDesc,
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
    final c = _controller;
    if (!_ready || c == null || !c.value.isInitialized || _recording) return;

    try {
      await c.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordStartedAt = DateTime.now();
      });
      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(const Duration(seconds: 60), _onPointerUp);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось начать запись: $e')),
      );
    }
  }

  Future<void> _onPointerUp() async {
    final c = _controller;
    if (c == null || !_recording) return;

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    final started = _recordStartedAt;
    setState(() {
      _recording = false;
      _recordStartedAt = null;
    });

    try {
      final xfile = await c.stopVideoRecording();
      if (!mounted) return;

      final duration = started != null
          ? DateTime.now().difference(started)
          : Duration.zero;
      if (duration < const Duration(milliseconds: 500)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Слишком коротко — удерживайте кнопку дольше'),
          ),
        );
        return;
      }

      Navigator.of(context).pop<String>(xfile.path);
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(AppIcons.close, color: Colors.white70),
              ),
            ),
            const Text(
              'Видеосообщение',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Удерживайте кнопку внизу — идёт запись. Отпустите, чтобы отправить.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _ready && _controller != null
                    ? ClipOval(
                        child: SizedBox(
                          width: 280,
                          height: 280,
                          child: CameraPreview(_controller!),
                        ),
                      )
                    : const CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Listener(
                onPointerDown: (_) => _onPointerDown(),
                onPointerUp: (_) => _onPointerUp(),
                onPointerCancel: (_) => _onPointerUp(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? Colors.redAccent : AppColors.accent,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AppIcons.record,
                    color: Colors.black,
                    size: _recording ? 28 : 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
