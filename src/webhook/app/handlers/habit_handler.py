"""Habit message handler.

Stub for Phase 1 Day 3. Routing logic only — the real work (writing to the
habits store via the PowerShell DisciplineEngine module) lands in Day 4.
"""

# Recognised habit keywords. Defined as a set for O(1) membership checks
# and so the greeting message and the parser stay in sync.
_KNOWN_HABITS = {"exercise", "sleep", "development"}


def handle_text_message(event: dict) -> str:
    """Return the reply text for a LINE text-message event.

    `event` is the raw event dict from the LINE webhook payload. Only the
    message text is consulted here; signature verification and event
    dispatch happen upstream in main.py.
    """
    # Defensive .get() chain — the event shape is documented but we don't
    # want a malformed payload to 500 the whole webhook.
    text = event.get("message", {}).get("text", "").strip()

    # Lowercase for case-insensitive matching of the "log <habit>" command.
    lowered = text.lower()

    if lowered.startswith("log "):
        # Everything after "log " is the habit name. Take only the first
        # token so "log exercise 30min" still routes to "exercise".
        habit = lowered[len("log "):].split()[0] if len(lowered) > 4 else ""

        if habit in _KNOWN_HABITS:
            return (
                f"Logged {habit} for today "
                "(will integrate with PowerShell module in Day 4)"
            )

    # Default greeting / help text. Includes the user's name in Thai
    # because the bot is personal — addressed to ภูมิ specifically.
    return (
        "Hi ภูมิ! Send 'log exercise', 'log sleep', or 'log development' "
        "to track habits."
    )
