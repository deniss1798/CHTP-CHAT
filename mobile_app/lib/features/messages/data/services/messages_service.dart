// Compatibility entry point while the message API is being consolidated.
// The canonical implementation currently lives in the chats feature because
// chat detail owns media upload, pagination, reactions and read-state flows.
export '../../../chats/data/services/messages_service.dart';
