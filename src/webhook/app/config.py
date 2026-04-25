"""Configuration loader.

Reads environment variables (optionally from a .env file) into a typed
Settings object. Using pydantic-settings means: missing vars fail fast at
startup, types are validated, and the rest of the code can import a single
`settings` object instead of sprinkling os.getenv() calls everywhere.
"""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# Resolve the repo-root .env path from this file's location, not from the
# current working directory. Otherwise running `uvicorn` from src/webhook/
# vs. from the repo root would look in different places.
#   __file__                           = .../src/webhook/app/config.py
#   parent                             = .../src/webhook/app/
#   parent.parent                      = .../src/webhook/
#   parent.parent.parent               = .../src/
#   parent.parent.parent.parent        = repo root
_REPO_ROOT = Path(__file__).parent.parent.parent.parent
_ENV_FILE = _REPO_ROOT / ".env"


class Settings(BaseSettings):
    # LINE channel secret — used to verify webhook signatures (HMAC key).
    LINE_CHANNEL_SECRET: str

    # LINE channel access token — used as Bearer token when calling the
    # LINE Messaging API to send replies/pushes.
    LINE_CHANNEL_ACCESS_TOKEN: str

    # Default user id for single-user (Phase 1) operation. The webhook maps
    # incoming LINE events to this user until multi-user onboarding lands.
    DEFAULT_USER_ID: str = "poom"

    # `model_config` tells pydantic-settings where to look for values.
    # `_ENV_FILE` is an absolute Path computed above, so it resolves the
    # same way no matter what directory the process was launched from.
    # In production (Azure), real env vars take precedence over the file.
    model_config = SettingsConfigDict(
        env_file=_ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )


# Instantiated once at import time. If a required env var is missing,
# this line raises ValidationError and the app refuses to start — which
# is exactly what we want (better than discovering it on first request).
settings = Settings()
