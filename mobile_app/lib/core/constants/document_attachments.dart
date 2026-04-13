/// Соответствует allowlist на сервере (`/messages/document`).
const int kMaxDocumentBytes = 50 * 1024 * 1024;

const List<String> kAllowedDocumentExtensions = [
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'odt',
  'ods',
  'odp',
  'rtf',
  'txt',
];

bool isAllowedDocumentFileName(String name) {
  final trimmed = name.trim();
  final dot = trimmed.lastIndexOf('.');
  if (dot <= 0 || dot >= trimmed.length - 1) return false;
  final ext = trimmed.substring(dot + 1).toLowerCase();
  return kAllowedDocumentExtensions.contains(ext);
}
