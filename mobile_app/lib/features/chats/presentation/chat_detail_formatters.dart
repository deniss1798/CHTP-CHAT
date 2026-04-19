import 'package:dio/dio.dart';

import '../../../../core/formatting/server_time.dart' show parseServerUtcInstant;
import '../../../../core/network/api_client.dart';

String chatDetailBuildInitials(String title) {
  final parts =
      title.split(' ').where((e) => e.trim().isNotEmpty).take(2).toList();

  if (parts.isEmpty) return 'Ч';

  if (parts.length == 1) {
    final word = parts.first.trim();
    return word.isNotEmpty ? word[0].toUpperCase() : 'Ч';
  }

  final first = parts[0].trim();
  final second = parts[1].trim();

  final firstChar = first.isNotEmpty ? first[0].toUpperCase() : '';
  final secondChar = second.isNotEmpty ? second[0].toUpperCase() : '';

  final result = '$firstChar$secondChar'.trim();
  return result.isEmpty ? 'Ч' : result;
}

String? chatDetailNormalizedAvatarUrl(String? avatarUrl) {
  final raw = (avatarUrl ?? '').trim();
  if (raw.isEmpty) return null;

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }

  return '${ApiClient.baseUrl}$raw';
}

String chatDetailFormatTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';

  final local = parseServerUtcInstant(raw)?.toLocal();
  if (local == null) return '';
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String chatDetailFormatDateLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';

  final local = parseServerUtcInstant(raw)?.toLocal();
  if (local == null) return '';

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  return '$day.$month.$year';
}

String chatDetailReplyPreviewLabel(Map<String, dynamic> reply) {
  final type = (reply['message_type'] ?? 'text').toString();
  if (type == 'image') {
    return '📷 Фото';
  }
  if (type == 'video') {
    return '🎥 Видео';
  }
  if (type == 'video_note') {
    return '🎬 Видеосообщение';
  }
  if (type == 'document') {
    final name = (reply['text'] ?? '').toString().trim();
    return name.isEmpty ? '📎 Файл' : '📎 $name';
  }

  final t = (reply['text'] ?? '').toString().trim();
  if (t.isEmpty) {
    return 'Сообщение';
  }
  if (t.length > 90) {
    return '${t.substring(0, 90)}…';
  }
  return t;
}

String? chatDetailFormatDocSize(dynamic raw) {
  if (raw == null) return null;
  int? n;
  if (raw is int) {
    n = raw;
  } else {
    n = int.tryParse(raw.toString());
  }
  if (n == null || n <= 0) return null;
  if (n < 1024) return '$n Б';
  if (n < 1024 * 1024) {
    return '${(n / 1024).toStringAsFixed(1)} КБ';
  }
  return '${(n / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

String chatDetailBasenameFromPath(String path) {
  final n = path.replaceAll(r'\', '/').split('/').last;
  return n.isEmpty ? 'video_note.mp4' : n;
}

String chatDetailExtractErrorMessage(Object e, {required String fallback}) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 405) {
      return '405 Method Not Allowed. Проверьте API_BASE_URL: при reverse-proxy часто нужен '
          'точный префикс /api или наоборот без него (см. лог [API ERROR] — полный URI). '
          'Сейчас база: ${ApiClient.baseUrl}';
    }
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
      return data['detail']?.toString() ??
          data['message']?.toString() ??
          fallback;
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    if (e.message != null && e.message!.isNotEmpty) {
      return e.message!;
    }
  }

  return e.toString().replaceFirst('Exception: ', '');
}

bool chatDetailIsMediaOnlyMessage(Map<String, dynamic> message) {
  final type = (message['message_type'] ?? 'text').toString();
  if (type == 'text') return false;
  return (message['text'] ?? '').toString().trim().isEmpty;
}

bool chatDetailShouldShowDateDivider(
  List<Map<String, dynamic>> messages,
  int index,
) {
  final current =
      chatDetailFormatDateLabel(messages[index]['created_at']?.toString());
  if (current.isEmpty) return false;

  if (index == 0) return true;

  final previous =
      chatDetailFormatDateLabel(messages[index - 1]['created_at']?.toString());

  return current != previous;
}
