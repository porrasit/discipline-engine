"""FastAPI entry point for the LINE webhook server.

Run locally with:
    uv run uvicorn app.main:app --reload --port 8000

Two endpoints:
  GET  /health    — liveness probe, no auth.
  POST /webhook   — LINE-signed webhook receiver.
"""

import base64
import hashlib
import hmac
import json
import logging

from fastapi import FastAPI, Header, HTTPException, Request

from .config import settings
from .handlers.habit_handler import handle_text_message
from .line_client import reply_message

# Basic logging setup — Uvicorn already configures a root logger, but
# fetching a named logger lets us filter our own messages later.
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("discipline-engine.webhook")

# The FastAPI app object. Uvicorn imports this via "app.main:app".
app = FastAPI(title="DisciplineEngine Webhook")


@app.get("/health")
async def health() -> dict[str, str]:
    """Cheap liveness check. Used by uptime monitors and during local
    smoke testing — confirms the process is up and the import graph
    didn't break."""
    return {"status": "ok"}


def _verify_signature(body: bytes, signature: str | None) -> bool:
    """Validate the X-Line-Signature header.

    LINE signs every webhook body with HMAC-SHA256 using the channel
    secret as the key, then base64-encodes the digest. We recompute the
    same digest from the raw body and compare in constant time.

    Constant-time comparison (hmac.compare_digest) prevents an attacker
    from learning the correct signature one byte at a time via timing.
    """
    if not signature:
        return False

    # Compute HMAC-SHA256(channel_secret, raw_body).
    digest = hmac.new(
        key=settings.LINE_CHANNEL_SECRET.encode("utf-8"),
        msg=body,
        digestmod=hashlib.sha256,
    ).digest()

    # LINE sends the signature base64-encoded; encode ours the same way.
    expected = base64.b64encode(digest).decode("utf-8")

    return hmac.compare_digest(expected, signature)


@app.post("/webhook")
async def webhook(
    request: Request,
    # FastAPI's Header() pulls the signature directly out of the request
    # headers. The alias matches LINE's exact header name.
    x_line_signature: str | None = Header(default=None, alias="X-Line-Signature"),
) -> dict[str, str]:
    """Receive a LINE webhook callback.

    Steps:
      1. Read the raw body (must be raw bytes — the signature is over
         the exact bytes LINE sent, not a re-serialized JSON).
      2. Verify the HMAC signature; reject with 403 if it doesn't match.
      3. Parse the JSON, dispatch each event, and reply.
    """
    # await request.body() returns the unmodified request body.
    body = await request.body()

    if not _verify_signature(body, x_line_signature):
        logger.warning("Rejected webhook: invalid X-Line-Signature")
        raise HTTPException(status_code=403, detail="Invalid signature")

    # Body should be valid JSON per the LINE spec, but guard anyway.
    try:
        payload = json.loads(body.decode("utf-8"))
    except json.JSONDecodeError:
        logger.exception("Webhook body was not valid JSON")
        raise HTTPException(status_code=400, detail="Malformed JSON")

    # `events` is a list — LINE may batch multiple events in one POST.
    events = payload.get("events", [])
    logger.info("Received %d LINE event(s)", len(events))

    for event in events:
        # Phase 1 only handles text messages. Other event types (sticker,
        # image, follow, postback, ...) are logged and ignored for now.
        event_type = event.get("type")
        message_type = event.get("message", {}).get("type")

        if event_type == "message" and message_type == "text":
            reply_text = handle_text_message(event)
            reply_token = event.get("replyToken")

            if reply_token:
                # Send the reply via LINE's reply endpoint.
                await reply_message(reply_token, reply_text)
            else:
                logger.warning("Text event missing replyToken; skipping reply")
        else:
            logger.info("Ignoring event type=%s message_type=%s",
                        event_type, message_type)

    # LINE expects a 2xx response within a few seconds — anything else
    # triggers their retry logic.
    return {"status": "ok"}
