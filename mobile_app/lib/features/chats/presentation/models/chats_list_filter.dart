/// Вкладки списка чатов (макет десктопа).
enum ChatsListFilter {
  all,
  unread,
  groups,
  /// Загружает только архивные чаты (`GET /chats/?archived=true`).
  archive,
}
