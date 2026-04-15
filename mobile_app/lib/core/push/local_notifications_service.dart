import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/app.dart';
import 'open_chat_from_push.dart';

/// Локальные уведомления: foreground FCM на Android, inbox на Windows/macOS/Linux.
class LocalNotificationsService {
  LocalNotificationsService._();
  static final LocalNotificationsService instance = LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static bool get supported {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  Future<void> init() async {
    if (!supported || _initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const linux = LinuxInitializationSettings(defaultActionName: 'Открыть');
    final initSettings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
      windows: defaultTargetPlatform == TargetPlatform.windows
          ? const WindowsInitializationSettings(
              appName: 'ЧТП ЧАТ',
              appUserModelId: 'com.chnetp.mobile_app',
              guid: '{a7f3c8d1-4e2b-5c9d-8a1f-0b2c3d4e5f6a}',
            )
          : null,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        'chat_messages',
        'Сообщения',
        description: 'Входящие сообщения',
        importance: Importance.high,
      );
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final cid = int.tryParse(map['c']?.toString() ?? '');
      if (cid == null) return;
      final av = map['a']?.toString();
      openChatFromPushPayload(
        PendingPushPayload(
          chatId: cid,
          avatarUrl: (av != null && av.isNotEmpty) ? av : null,
        ),
      );
    } catch (_) {}
  }

  Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      final r = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final list = r.data;
      if (list == null || list.isEmpty) return null;
      if (list.length > 400000) return null;
      return Uint8List.fromList(list);
    } catch (_) {
      return null;
    }
  }

  /// id — обычно [chatId], чтобы обновлять то же уведомление.
  Future<void> showChatMessage({
    required int notificationId,
    required String title,
    required String body,
    String? avatarUrl,
    required int chatId,
    String? avatarUrlForOpen,
  }) async {
    if (!_initialized) return;

    final payload = jsonEncode({
      'c': chatId,
      if (avatarUrlForOpen != null && avatarUrlForOpen.isNotEmpty) 'a': avatarUrlForOpen,
    });

    late final NotificationDetails details;
    if (defaultTargetPlatform == TargetPlatform.android) {
      Uint8List? iconBytes;
      final u = avatarUrl?.trim();
      if (u != null && u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://'))) {
        iconBytes = await _downloadImageBytes(u);
      }
      details = NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'Сообщения',
          channelDescription: 'Входящие сообщения',
          importance: Importance.high,
          priority: Priority.high,
          largeIcon: iconBytes != null ? ByteArrayAndroidBitmap(iconBytes) : null,
          styleInformation: BigTextStyleInformation(body),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      details = const NotificationDetails(
        windows: WindowsNotificationDetails(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      details = const NotificationDetails(
        linux: LinuxNotificationDetails(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      details = const NotificationDetails(
        macOS: DarwinNotificationDetails(),
      );
    } else {
      return;
    }

    await _plugin.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
