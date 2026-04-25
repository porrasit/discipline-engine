"""Configuration loader.

Reads environment variables (optionally from a .env file) into a typed
Settings object. Using pydantic-settings means: missing vars fail fast at
startup, types are validated, and the rest of the code can import a single
`settings` object instead of sprinkling os.getenv() calls everywhere.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


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
    # We point at the repo-root .env file so local dev "just works" after
    # copying .env.example -> .env. In production (Azure), real env vars
    # take precedence over the file.
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


# Instantiated once at import time. If a required env var is missing,
# this line raises ValidationError and the app refuses to start — which
# is exactly what we want (better than discovering it on first request).
settings = Settings()
