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

## Phased scope

This is a 12-week build. Three phases:

- **Phase 1 (Weeks 1-4): Personal habit tracker, multi-user-ready data model.** Single active user (the developer). Data model designed to support multiple users from day one — file structure, profile schema, and storage layer all assume future multi-user. Only the developer's profile exists during this phase.
- **Phase 2 (Weeks 5-8): Content features.** Layer in scheduled LINE messages: morning news briefing, midday tips, weekly report. Tips and news are personalized per user profile from the start.
- **Phase 3 (Weeks 9-12): Multi-user activation.** LINE bot self-onboarding flow for friends. Persona-driven content. Storage migrates to Azure Table Storage (the seam pattern was designed for this).

Do not skip ahead. Phase 2 must not start until Phase 1 is shipping daily LINE messages reliably for the developer.

## Data model — multi-user from day one

File structure:

```
data/
├── users/
│   └── {userId}/
│       ├── profile.json
│       ├── habits.json
│       └── delivery-log.json
└── content/
    ├── sysadmin-topics.json
    ├── claude-tips-topics.json
    └── shared/   (any cross-user content)
```

The `{userId}` directory pattern is the future Azure Table partition key. All Public functions (`Add-HabitEntry`, `Get-HabitSummary`, etc.) must accept a `-UserId` parameter. Default it to the value of `$env:DISCIPLINE_ENGINE_DEFAULT_USER` for local dev convenience, but never hardcode a username inside any function.

## Profile schema (profile.json)

Fields captured at onboarding (comprehensive — must be enough for tips to feel personal, not generic):

- `userId`, `displayName`, `createdAt`, `lineUserId`
- `occupation`: { `role`, `yearsExperience`, `techStack[]`, `currentLearning[]`, `careerGoal` }
- `demographics`: { `ageRange`, `location`, `livingSituation` }
- `habits`: { `exercise`: {target, unit}, `sleep`: {target, unit}, `development`: {target, unit}, `custom[]` }
- `interests`: { `news`: { `categories[]`, `language`, `sources[]` }, `learningTopics[]` }
- `sideIncome`: { `targetMonthlyAmount`, `currency`, `primaryTrack`, `secondaryTrack`, `currentEarnings` }
- `preferences`: { `tipLanguage`, `communicationStyle`, `timezone`, `schedule`: {morningBriefing, lunchTip, eveningReview} }
- `constraints`: { `availableHoursPerWeek`, `budgetForToolsMonthly`, `currency` }

Profile is static at base — set once at onboarding. But it grows organically through conversation: when the user mentions new context in LINE messages (new tech stack, new interest, schedule change), Claude detects this during the existing reply call (no extra API cost) and proposes a profile update. User confirms via a yes/no LINE reply before the update is written.

This dynamic-update mechanism does NOT belong in Phase 1. In Phase 1, profile is purely static. The schema must reserve space for an `updateHistory[]` field so Phase 2/3 can append change records without schema migration.

## LINE message schedule

Weekdays:
- 07:30 — Morning briefing: habit check-in + 3 news headlines with 2-3 line summaries (English-only output)
- 12:30 — Lunch tip: Mon/Wed/Fri = SysAdmin tip; Tue/Thu = Claude + Side Income tip
- 21:00 — Evening review: habit log prompt + Claude coaching reply

Weekends: habit check-in only (07:30, 21:00). No news, no tips.

Monday 07:30 replaces news with the weekly report.

All scheduled times are read from the user's `profile.json` `preferences.schedule`, not hardcoded.

## Content personalization — required from day one

Every tip and news selection MUST consume the user's profile. Generic tips ("what is RAID") are not acceptable; tips must connect to the user's tech stack, current learning, side income track, or stated interests. The Claude prompt template for tip generation will always include:

- The user's full profile (or relevant sections)
- The selected topic from the curated list
- The user's recent delivery-log (last 14 days) to avoid repetition
- An instruction to make the tip actionable in the user's specific context

## News pipeline

RSS feeds: TechCrunch, The Verge, Hacker News, Anthropic blog, Reuters Business, Bangkok Post. (Bangkok Post included as a Thai-region source with English content — user wants English output but Thai-region awareness.) Python script fetches last 24h headlines, deduplicates, and Claude Haiku selects top 3 weighted by the user's `profile.interests.news.categories`, then writes 2-3 line summaries.

## SysAdmin & Claude tips — content sources

- SysAdmin topics: curated by user in `content/sysadmin-topics.json`. Topics span storage, networking, AD, M365, backup, security, PowerShell, Linux fundamentals.
- Claude + Side Income topics: curated by user in `content/claude-tips-topics.json`. Weighted ~80/20 toward primary side income track (M365 Migration freelance) vs secondary (AI-augmented IT consulting).
- Tip generation uses Claude Haiku with the personalization template above. No tip is delivered without consulting profile.

## Side income context for the developer

Target: ~5,000 THB/month from small freelance jobs. Primary track: Microsoft 365 migration projects for SMBs (15K–50K THB per project). Secondary track (long-term): AI-augmented IT consulting using Claude Code + MCP. Tips should reinforce both tracks.

## Multi-user onboarding (Phase 3)

Target persona: working-age adults 30–50, friends of the developer. Distribution: LINE bot self-onboarding. Onboarding is a guided multi-turn LINE conversation that captures the full profile schema above. Free for friends; developer absorbs API costs. LINE Official Account on Free tier (1,000 messages/month) is sufficient for early Phase 3.

## LINE plan

LINE Official Account, Free tier (1,000 messages/month). Personal use estimate: ~150 messages/month. Headroom for 5–6 friends in early Phase 3 before upgrade decision.

## Code style

- **PowerShell files (`.ps1`, `.psm1`) must include learner-friendly inline comments in English.** The user is learning PowerShell (studying AZ-802), not an expert. Explain what each section does and what non-trivial commands/cmdlets do — e.g. `Get-Content`, `ConvertFrom-Json`, `param(...)`, splatting, pipeline `$_`, `[CmdletBinding()]`, error handling with `try/catch`. Avoid explaining truly obvious things (`$x = 1`). This rule overrides the general "default to writing no comments" guidance for this repo's PowerShell only.
- Python files follow the normal minimal-comment style — the user isn't learning Python.

## Commands

The `DisciplineEngine` PowerShell module lives at `src/DisciplineEngine/` and exposes `Add-HabitEntry` and `Get-HabitSummary`.

```powershell
# Import the module (from the repo root)
Import-Module ./src/DisciplineEngine/DisciplineEngine.psd1

# Log a habit completion for today (UserId will be required after the refactor)
Add-HabitEntry -UserId dt -Habit exercise -Notes '30 min run'

# Log for a specific date
Add-HabitEntry -UserId dt -Habit sleep -Date 2026-04-24 -Completed $false -Notes 'bed at 23:40'

# Weekly compliance summary for the current week
Get-HabitSummary -UserId dt

# Weekly compliance summary for a specific week
Get-HabitSummary -UserId dt -WeekOf 2026-04-20
```

**Next refactor task:** the module currently does NOT support `-UserId` — it reads/writes a single `./data/habits.json` file (overridable via `$env:DISCIPLINE_ENGINE_STORE`). Adding `-UserId` to all Public functions, moving storage to `data/users/{userId}/habits.json`, and defaulting to `$env:DISCIPLINE_ENGINE_DEFAULT_USER` is the next change. The usage above reflects the target state, not the shipped state.

No build/test commands yet.
