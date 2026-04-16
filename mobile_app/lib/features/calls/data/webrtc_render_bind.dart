import 'dart:async' show unawaited;

import 'package:flutter/scheduler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Повторно привязывает [MediaStream] к [RTCVideoRenderer].
///
/// В flutter-webrtc при связке **Flutter ↔ Flutter** удалённое видео часто остаётся чёрным,
/// пока не вызвать [RTCVideoRenderer.srcObject] ещё раз после кадра отрисовки
/// (см. upstream issues про black screen между двумя Flutter-клиентами).
///
/// Для потока **только с аудио** повторные присваивания `srcObject` не делаем: на части
/// платформ это обрывает воспроизведение звука через ~300–400 мс после подключения.
void bindRtcVideoRenderer(RTCVideoRenderer renderer, MediaStream stream) {
  renderer.srcObject = stream;

  final hasLiveVideo =
      stream.getVideoTracks().any((MediaStreamTrack t) => t.enabled);
  if (!hasLiveVideo) {
    return;
  }

  void rebind() {
    final cur = renderer.srcObject;
    if (cur == null || cur.id != stream.id) return;
    renderer.srcObject = stream;
  }

  SchedulerBinding.instance.addPostFrameCallback((_) => rebind());
  unawaited(Future<void>.delayed(const Duration(milliseconds: 80), rebind));
  unawaited(Future<void>.delayed(const Duration(milliseconds: 350), rebind));
}
