"""Имена событий WebSocket / payload type (согласованность с клиентами)."""

# Тип в payload для нового сообщения в чате
WS_TYPE_NEW_MESSAGE = "new_message"

# События в теле broadcast (часть путей использует event вместо type)
WS_EVENT_MESSAGE_UPDATED = "message_updated"
WS_EVENT_MESSAGE_DELETED = "message_deleted"
