/// Согласовано с `backend/app/application/realtime/ws_event_names.dart` и payload WS чата.
abstract final class ChatWsContract {
  static const String payloadTypeNewMessage = 'new_message';
  static const String eventMessageUpdated = 'message_updated';
  static const String eventMessageDeleted = 'message_deleted';
}
