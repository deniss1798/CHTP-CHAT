"""Имена событий WebSocket / payload type (согласованность с клиентами)."""

# Тип в payload для нового сообщения в чате
WS_TYPE_NEW_MESSAGE = "new_message"
WS_TYPE_READ_RECEIPT = "read_receipt"

# События в теле broadcast (часть путей использует event вместо type)
WS_EVENT_MESSAGE_UPDATED = "message_updated"
WS_EVENT_MESSAGE_DELETED = "message_deleted"
WS_EVENT_MESSAGE_REACTIONS_UPDATED = "message_reactions_updated"
