import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/url_helper.dart';
import '../../../../core/storage/secure_storage_service.dart';

/// Открытие вложений: для URL на том же хосте, что и API — запрос с Bearer и локальный файл.
Future<void> openChatAttachmentUrl(
  BuildContext context, {
  required String mediaUrl,
  String? fallbackFileName,
}) async {
  final uri = Uri.tryParse(mediaUrl.trim());
  if (uri == null || !uri.hasScheme) {
    _toast(context, 'Некорректная ссылка на файл');
    return;
  }

  if (!UrlHelper.isSameServerAsApi(mediaUrl)) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _toast(context, 'Не удалось открыть файл');
    }
    return;
  }

  final token = await SecureStorageService.getAccessToken();
  if (token == null || token.isEmpty) {
    _toast(context, 'Нужна авторизация');
    return;
  }

  try {
    final dir = await getTemporaryDirectory();
    final name = _fileNameFromUri(uri, fallbackFileName);
    final path = p.join(
      dir.path,
      'chat_attach_${DateTime.now().millisecondsSinceEpoch}_$name',
    );

    final response = await ApiClient.dio.get<List<int>>(
      mediaUrl,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Пустой ответ');
    }
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    final result = await OpenFile.open(path);
    if (result.type != ResultType.done && context.mounted) {
      _toast(context, 'Не удалось открыть файл');
    }
  } catch (_) {
    if (context.mounted) {
      _toast(context, 'Не удалось скачать файл');
    }
  }
}

String _fileNameFromUri(Uri uri, String? fallback) {
  final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  if (seg.isNotEmpty && seg.contains('.')) return seg;
  final fb = (fallback ?? 'file').trim();
  if (fb.isNotEmpty) return fb.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
  return 'download.bin';
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
}
