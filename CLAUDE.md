# HealthOS — Claude Project Instructions

This file is automatically loaded into every Claude session in this repo.
It applies to the lead agent and all subagents/worktree sessions.

---

## Project Overview

HealthOS is an iOS-native AI health coaching app. It aggregates data from
Apple HealthKit, Whoop, Strava, and Apple Calendar, then uses Claude API
to generate personalized daily coaching plans aligned with the user's goals.

- **PRD:** `docs/design/PRD.md`
- **Multi-agent workflow:** `docs/workflow/multi-agent-development.md`

---

## Tech Stack

- **iOS:** Swift, SwiftUI, SwiftData, HealthKit, EventKit (iOS 17+)
- **Backend:** Supabase (PostgreSQL, Auth, Edge Functions, Storage)
- **AI:** Claude API via Supabase Edge Functions
- **Auth:** Apple Sign-In (primary)

---

## Repository Structure

```
HealthOS/                  # Xcode iOS project
  Models/                  # Swift data models
  Views/                   # SwiftUI views
    Goals/
    Training/
    DailyCheckin/
    Journal/
    Progress/
    Benchmarks/
    Retrospective/
  Services/                # Integration service layer
    HealthKit/
    Whoop/
    Strava/
    Calendar/
supabase/
  migrations/              # SQL migrations (versioned)
  functions/               # Edge Functions (Deno/TypeScript)
    whoop-sync/
    strava-sync/
    normalize/
    coaching/
    retrospective/
  schema.sql               # Source-of-truth DB schema
docs/
  design/                  # PRD, technical design docs
  workflow/                # Developer workflow docs
  decisions/               # Architecture Decision Records
.claude/
  agents/                  # Custom agent definitions
```

---

## Coding Conventions

### Swift / SwiftUI
- Use `@Observable` (iOS 17 macro) over `ObservableObject`
- MVVM architecture — views own no business logic
- Service layer handles all external integrations (HealthKit, APIs)
- All HealthKit reads go through `HealthKitService`
- All Supabase calls go through `SupabaseService`
- Use `async/await` throughout — no Combine or callback patterns
- Name views `[Feature]View`, models `[Entity].swift`, services `[Name]Service.swift`

### Supabase / SQL
- All schema changes must be in a versioned migration file in `supabase/migrations/`
- Migration naming: `YYYYMMDDHHMMSS_description.sql`
- Every table must have Row Level Security enabled
- Edge Functions in TypeScript (Deno), one function per concern

### General
- No hardcoded secrets — use Supabase env vars and iOS `.xcconfig` files
- Never commit `.env`, `*.p8`, or any credentials
- Prefer small, focused commits over large sweeping changes
- Write code that a new developer could understand without asking questions

---

## Orchestration Rules (Lead Agent)

When acting as the lead orchestrator:

1. **Plan before executing** — break work into discrete units, identify dependencies, confirm file ownership before spawning worktrees
2. **Define shared contracts first** — data models, API response shapes, and Edge Function interfaces must be committed to `main` before branching
3. **Respect file ownership boundaries** — each worktree session owns a defined set of files (see `docs/workflow/multi-agent-development.md`)
4. **Never modify files outside your ownership boundary** when operating in a worktree
5. **Commit frequently** — small, descriptive commits inside each worktree branch
6. **Report blockers immediately** — if a dependency isn't ready, stop and communicate rather than working around it
7. **Use the PRD as the source of truth** — if requirements are unclear, refer to `docs/design/PRD.md` before guessing

---

## Phase Status

| Phase | Status | Branch |
|---|---|---|
| Phase 1: Foundation | Not started | — |
| Phase 2: Integrations & Goals | Not started | — |
| Phase 3: Training Program & Daily Plan | Not started | — |
| Phase 4: Progress & Retrospective | Not started | — |
