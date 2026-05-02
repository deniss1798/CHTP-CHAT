from __future__ import annotations

import asyncio
from dataclasses import asdict, dataclass
import json
import logging
from uuid import uuid4

from app.core.redis_client import make_async_redis_client
from app.core.ws_manager import inbox_manager, manager
from app.db.database import SessionLocal

logger = logging.getLogger(__name__)

_CHANNEL = "chtp:realtime:v1"
_INSTANCE_ID = uuid4().hex
_task: asyncio.Task | None = None
_stop_event: asyncio.Event | None = None


@dataclass
class RealtimeBusStats:
    enabled: bool = False
    publish_total: int = 0
    publish_error_total: int = 0
    received_total: int = 0
    receive_error_total: int = 0
    delivered_total: int = 0


bus_stats = RealtimeBusStats()


def bus_metrics() -> dict:
    data = asdict(bus_stats)
    data["instance_id"] = _INSTANCE_ID
    return data


async def publish_chat_event(chat_id: int, payload: dict) -> None:
    await _publish({"kind": "chat", "chat_id": chat_id, "payload": payload})


async def publish_inbox_event(user_id: int, payload: dict) -> None:
    await _publish({"kind": "inbox", "user_id": user_id, "payload": payload})


async def publish_reactions_refresh(chat_id: int, message_id: int) -> None:
    await _publish({
        "kind": "reactions_refresh",
        "chat_id": chat_id,
        "message_id": message_id,
    })


async def _publish(envelope: dict) -> None:
    client = make_async_redis_client()
    if client is None:
        return
    body = dict(envelope)
    body["origin"] = _INSTANCE_ID
    try:
        await client.publish(_CHANNEL, json.dumps(body, ensure_ascii=False, default=str))
        bus_stats.publish_total += 1
    except Exception:
        bus_stats.publish_error_total += 1
        logger.exception("Redis realtime publish failed")
    finally:
        try:
            await client.aclose()
        except Exception:
            pass


async def start_realtime_bus() -> None:
    global _stop_event, _task
    if _task is not None:
        return
    client = make_async_redis_client()
    if client is None:
        bus_stats.enabled = False
        return
    await client.aclose()
    bus_stats.enabled = True
    _stop_event = asyncio.Event()
    _task = asyncio.create_task(_subscriber_loop(), name="redis-realtime-bus")


async def stop_realtime_bus() -> None:
    global _stop_event, _task
    if _stop_event is not None:
        _stop_event.set()
    if _task is not None:
        _task.cancel()
        try:
            await _task
        except asyncio.CancelledError:
            pass
    _task = None
    _stop_event = None


async def _subscriber_loop() -> None:
    while _stop_event is not None and not _stop_event.is_set():
        client = make_async_redis_client()
        if client is None:
            await asyncio.sleep(2)
            continue
        pubsub = client.pubsub()
        try:
            await pubsub.subscribe(_CHANNEL)
            while _stop_event is not None and not _stop_event.is_set():
                message = await pubsub.get_message(
                    ignore_subscribe_messages=True,
                    timeout=1.0,
                )
                if not message:
                    continue
                await _handle_message(message.get("data"))
        except asyncio.CancelledError:
            raise
        except Exception:
            bus_stats.receive_error_total += 1
            logger.exception("Redis realtime subscriber failed")
            await asyncio.sleep(2)
        finally:
            try:
                await pubsub.unsubscribe(_CHANNEL)
                await pubsub.aclose()
            except Exception:
                pass
            try:
                await client.aclose()
            except Exception:
                pass


async def _handle_message(raw: object) -> None:
    try:
        if not isinstance(raw, str):
            return
        envelope = json.loads(raw)
        if envelope.get("origin") == _INSTANCE_ID:
            return
        kind = envelope.get("kind")
        payload = envelope.get("payload")
        bus_stats.received_total += 1
        if kind == "chat":
            if not isinstance(payload, dict):
                return
            chat_id = int(envelope["chat_id"])
            await manager.broadcast(chat_id, payload)
            bus_stats.delivered_total += 1
        elif kind == "inbox":
            if not isinstance(payload, dict):
                return
            user_id = int(envelope["user_id"])
            await inbox_manager.send_json(user_id, payload)
            bus_stats.delivered_total += 1
        elif kind == "reactions_refresh":
            await _deliver_reactions_refresh(
                chat_id=int(envelope["chat_id"]),
                message_id=int(envelope["message_id"]),
            )
    except Exception:
        bus_stats.receive_error_total += 1
        logger.exception("Redis realtime message handling failed")


async def _deliver_reactions_refresh(*, chat_id: int, message_id: int) -> None:
    from app.application.messages.reaction_service import reaction_groups_for_messages
    from app.application.realtime.event_payload import realtime_event
    from app.application.realtime.ws_event_names import (
        WS_EVENT_MESSAGE_REACTIONS_UPDATED,
    )

    db = SessionLocal()
    try:
        def build(uid: int) -> dict:
            rmap = reaction_groups_for_messages(db, [message_id], uid)
            groups = rmap.get(message_id, [])
            return realtime_event({
                "event": WS_EVENT_MESSAGE_REACTIONS_UPDATED,
                "message_id": message_id,
                "chat_id": chat_id,
                "reactions": [g.model_dump() for g in groups],
            })

        await manager.broadcast_personalized(chat_id, build)
        bus_stats.delivered_total += 1
    finally:
        db.close()
