import logging
import re
from collections.abc import Mapping, Sequence
from typing import Any


SENSITIVE_KEYS = {
    "authorization",
    "access_token",
    "refresh_token",
    "token",
    "password",
    "verification_code",
    "code",
    "presigned_url",
    "media_url",
    "avatar_url",
}

_BEARER_RE = re.compile(r"Bearer\s+[A-Za-z0-9._~+/=-]+", re.IGNORECASE)
_QUERY_SECRET_RE = re.compile(
    r"(?P<key>[?&](?:token|access_token|refresh_token|password|code)=)(?P<value>[^&\s]+)",
    re.IGNORECASE,
)
_PRIVATE_MEDIA_RE = re.compile(
    r"(https?://[^\s'\"]+?(?:X-Amz-Signature|Signature|token|access_token)=[^\s'\"]+)",
    re.IGNORECASE,
)


def redact_value(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {
            key: "***" if str(key).lower() in SENSITIVE_KEYS else redact_value(item)
            for key, item in value.items()
        }

    if isinstance(value, str):
        redacted = _BEARER_RE.sub("Bearer ***", value)
        redacted = _QUERY_SECRET_RE.sub(r"\g<key>***", redacted)
        return _PRIVATE_MEDIA_RE.sub("***", redacted)

    if isinstance(value, Sequence) and not isinstance(value, (bytes, bytearray)):
        return [redact_value(item) for item in value]

    return value


class RedactingFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = redact_value(record.msg)
        if record.args:
            if isinstance(record.args, Mapping):
                record.args = redact_value(record.args)
            else:
                record.args = tuple(redact_value(arg) for arg in record.args)
        return True


def install_log_redaction() -> None:
    redacting_filter = RedactingFilter()
    for logger_name in ("", "uvicorn", "uvicorn.access", "uvicorn.error"):
        logging.getLogger(logger_name).addFilter(redacting_filter)
