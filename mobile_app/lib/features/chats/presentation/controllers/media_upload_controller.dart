import 'dart:io' show File;

import '../../../../core/constants/document_attachments.dart';

class MediaUploadValidation {
  const MediaUploadValidation._(this.errorMessage);

  const MediaUploadValidation.ok() : this._(null);
  const MediaUploadValidation.error(String message) : this._(message);

  final String? errorMessage;
  bool get isOk => errorMessage == null;
}

class MediaUploadController {
  Future<MediaUploadValidation> validateDocumentPath({
    required String path,
    required String displayName,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return const MediaUploadValidation.error('Файл не найден');
    }

    final len = await file.length();
    if (len > kMaxDocumentBytes) {
      return const MediaUploadValidation.error('File is larger than 100 MB');
    }

    if (!isAllowedDocumentFileName(displayName)) {
      return const MediaUploadValidation.error(
        'Unsupported file type. Allowed: PDF, Office, ODF, RTF, TXT',
      );
    }

    return const MediaUploadValidation.ok();
  }
}
