# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Personal habit-tracking system. Not a product — a single-user tool that logs daily habit completion via LINE, stores the history, and uses Claude to produce evening coaching replies and weekly summaries.

Tracked habits and thresholds:
- Exercise — 5 sessions per week
- Sleep — in bed before 22:30
- Self-development — 1 hour per day

The compliance logic should treat these thresholds as the source of truth for "on track" vs. "slipping"; don't invent new metrics without a reason.

## Architecture (planned — repo is currently a stub)

Three components, deliberately split across two languages:

1. **LINE Bot webhook server** — Python. Receives LINE Messaging API webhooks, parses habit log messages from the user, writes to the data store, and posts the Claude-generated coaching reply back via the Messaging API reply/push endpoints.
2. **Habit-tracking core module** — PowerShell. Pure functions for loading history, computing weekly/daily compliance against the thresholds above, and serializing state. Designed to be callable from both (a) local dev and (b) Azure Automation runbooks without modification.
3. **Azure Automation runbooks** — PowerShell. Scheduled jobs that import the core module and call Claude: evening coaching (daily) and weekly summary (Monday morning).

The PowerShell/Python split is intentional: the core logic needs to run inside Azure Automation runbooks (PowerShell-native), and the webhook server needs the Python LINE SDK ecosystem. Do not propose collapsing to one language — the runbook target is a hard constraint (see below).

## Hard constraints

- **Azure surface is Automation Runbooks specifically.** The user is studying for AZ-802 and wants hands-on runbook experience. Do not suggest Azure Functions, Logic Apps, Container Apps, or similar as alternatives even when they would be simpler.
- **LINE Messaging API only.** LINE Notify was discontinued in March 2025. Any suggestion involving `notify-api.line.me` or Notify tokens is wrong — use the Messaging API (channel access token, reply/push endpoints, webhook signature verification).
- **Claude model is Haiku** (`claude-haiku-4-5-20251001`) for cost. Both the daily coaching reply and weekly summary run on Haiku unless there's a specific reason to upgrade.
- **Data store is local JSON now, Azure Table Storage later.** Write the storage layer behind a small interface so the migration is a swap, not a rewrite. Don't prematurely pull in Table Storage SDKs.

## Code style

- **PowerShell files (`.ps1`, `.psm1`) must include learner-friendly inline comments in English.** The user is learning PowerShell (studying AZ-802), not an expert. Explain what each section does and what non-trivial commands/cmdlets do — e.g. `Get-Content`, `ConvertFrom-Json`, `param(...)`, splatting, pipeline `$_`, `[CmdletBinding()]`, error handling with `try/catch`. Avoid explaining truly obvious things (`$x = 1`). This rule overrides the general "default to writing no comments" guidance for this repo's PowerShell only.
- Python files follow the normal minimal-comment style — the user isn't learning Python.

## Commands

No build/test commands yet — repo has no source. Update this section once the first component lands.
