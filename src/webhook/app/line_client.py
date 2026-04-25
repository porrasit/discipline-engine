"""Thin wrapper around the LINE Messaging API.

Two operations are exposed:
  - reply_message: respond to a webhook event using its short-lived reply token.
  - push_message:  send an unsolicited message to a known LINE user id.

Both use httpx.AsyncClient so they integrate with FastAPI's async event loop
(blocking the loop on a network call would stall every other request).
"""

import httpx

from .config import settings

# LINE Messaging API endpoints. Documented at:
# https://developers.line.biz/en/reference/messaging-api/
_REPLY_URL = "https://api.line.me/v2/bot/message/reply"
_PUSH_URL = "https://api.line.me/v2/bot/message/push"


def _auth_headers() -> dict[str, str]:
    """Build the Authorization + Content-Type headers LINE expects."""
    return {
        "Authorization": f"Bearer {settings.LINE_CHANNEL_ACCESS_TOKEN}",
        "Content-Type": "application/json",
    }


async def reply_message(reply_token: str, text: str) -> None:
    """Reply to a webhook event.

    `reply_token` is included on every incoming webhook event and is valid
    for ~30 seconds. Use this (instead of push) whenever possible — replies
    do not count against the monthly message quota on the Free tier.
    """
    payload = {
        "replyToken": reply_token,
        "messages": [{"type": "text", "text": text}],
    }
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(_REPLY_URL, headers=_auth_headers(), json=payload)
        # raise_for_status() turns 4xx/5xx into an exception so callers
        # don't silently ignore failed sends.
        response.raise_for_status()


async def push_message(user_id: str, text: str) -> None:
    """Send a message to a user without an inbound trigger.

    Used by scheduled jobs (morning briefing, evening review prompt). Each
    push counts against the LINE Free-tier 1,000-msg/month quota.
    """
    payload = {
        "to": user_id,
        "messages": [{"type": "text", "text": text}],
    }
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(_PUSH_URL, headers=_auth_headers(), json=payload)
        response.raise_for_status()
