# Webhook Server

FastAPI server that receives LINE Messaging API webhooks for the DisciplineEngine habit tracker.

## Prerequisites

- Python 3.12 (pinned in `.python-version`)
- [`uv`](https://docs.astral.sh/uv/) for dependency management
- A LINE Official Account with Messaging API enabled (channel secret + access token)

## Setup

```bash
# 1. From the repo root, copy the env template and fill in your LINE credentials
cp .env.example .env
# edit .env — add your real LINE_CHANNEL_SECRET and LINE_CHANNEL_ACCESS_TOKEN

# 2. From src/webhook/, install dependencies into a local .venv
cd src/webhook
uv sync
```

## Run locally

```bash
# From src/webhook/
uv run uvicorn app.main:app --reload --port 8000
```

The `--reload` flag restarts the server on code changes (dev only — never in production).

## Smoke test

```bash
curl http://localhost:8000/health
# {"status":"ok"}
```

## Exposing to LINE for development

LINE needs a public HTTPS URL to deliver webhooks. Use ngrok (or similar):

```bash
ngrok http 8000
```

Then in the LINE Developers Console, set the Webhook URL to:
`https://<ngrok-id>.ngrok-free.app/webhook`

Verify with the **Verify** button in the console.

## Endpoints

| Method | Path       | Purpose                                       |
| ------ | ---------- | --------------------------------------------- |
| GET    | `/health`  | Liveness check                                |
| POST   | `/webhook` | LINE webhook receiver (HMAC-SHA256 verified) |

## Project layout

```
src/webhook/
├── pyproject.toml         dependencies + project metadata
├── .python-version        pins Python 3.12
├── app/
│   ├── main.py            FastAPI app, /health and /webhook
│   ├── config.py          env var loader (pydantic-settings)
│   ├── line_client.py     LINE Messaging API wrapper (reply + push)
│   └── handlers/
│       └── habit_handler.py   parses "log <habit>" messages (Day 4 = real wiring)
└── tests/                 (empty for now)
```

## Status

Day 3 scaffold. The habit handler currently returns a placeholder reply; Day 4 will wire it into the PowerShell `DisciplineEngine` module so habit logs persist to `data/users/{userId}/habits.json`.
