import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' show TargetPlatform;

/// Ограничения захвата видео: на телефонах — фронтальная камера; на ПК **не** используем
/// `facingMode` (веб-камеры его не поддерживают). Для десктопа — `true`, максимально совместимо с libwebrtc.
Object webrtcVideoCaptureConstraints() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return <String, dynamic>{
        'facingMode': 'user',
        'width': 640,
        'height': 480,
        'frameRate': 24,
      };
    default:
      return true;
  }
}
