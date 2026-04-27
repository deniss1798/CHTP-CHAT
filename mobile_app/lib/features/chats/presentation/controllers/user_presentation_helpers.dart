import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../chat_detail_message_maps.dart';

int? userIdFromMap(Map<String, dynamic> user) {
  return ChatDetailMessageMaps.intFromDynamic(user['id']);
}

String initialsForTitle(String title) {
  final parts =
      title.split(' ').where((e) => e.trim().isNotEmpty).take(2).toList();

  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first.trim();
    return word.isNotEmpty ? word[0].toUpperCase() : '?';
  }

  final first = parts[0].trim();
  final second = parts[1].trim();
  final firstChar = first.isNotEmpty ? first[0].toUpperCase() : '';
  final secondChar = second.isNotEmpty ? second[0].toUpperCase() : '';
  final result = '$firstChar$secondChar'.trim();
  return result.isEmpty ? '?' : result;
}

String? avatarUrlFromUserMap(Map<String, dynamic> user) {
  for (final value in [user['avatar_url'], user['avatarUrl']]) {
    if (value != null && value.toString().trim().isNotEmpty) {
      final raw = value.toString().trim();
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return raw;
      }
      return '${ApiClient.baseUrl}$raw';
    }
  }
  return null;
}

String extractFeatureErrorMessage(Object e, {required String fallback}) {
  if (e is DioException) {
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
