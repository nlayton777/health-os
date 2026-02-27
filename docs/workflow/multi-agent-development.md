# Multi-Agent Development Workflow

This document defines how to use Claude Code's multi-agent capabilities to parallelize work across HealthOS phases and features.

---

## Overview

Claude Code supports three modes of multi-agent execution. This project uses two of them:

| Mode | When to Use | How |
|---|---|---|
| **Subagents (Task tool)** | Parallel research, API exploration, reading docs | Single terminal session; spawn via Claude's Task tool |
| **Git Worktrees** | Parallel feature implementation (different modules/files) | Multiple terminal sessions; each gets an isolated branch |
| **Agent Teams** *(experimental)* | Complex parallel implementation with cross-agent communication | Enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |

---

## Mode 1: Subagents (Research & Exploration)

Use this when you need Claude to investigate multiple things simultaneously **without writing code** — e.g., reading API docs, exploring SDKs, researching architecture options.

### How to trigger

Just ask. Claude will spawn subagents automatically for parallelizable research:

```
"Research the Whoop API, Strava API, and Apple HealthKit SDK in parallel —
what data points does each expose, what are the auth flows, and what are
the rate limits?"
```

Claude spawns three subagents simultaneously, each focused on one integration, and synthesizes the results.

### Rules
- Subagents are read-only workers — they explore and report back
- Do not use subagents for writing code (use worktrees for that)
- Results are returned to the main conversation context — keep subagent prompts focused to avoid context bloat

---

## Mode 2: Git Worktrees (Parallel Implementation)

Use this when two or more independent features can be built simultaneously without touching the same files.

### Setup

Add worktrees directory to `.gitignore` (one-time setup):
```bash
echo ".claude/worktrees/" >> .gitignore
```

### Starting a parallel session

Open a new terminal for each parallel workstream:

```bash
# Terminal 1 — e.g., iOS HealthKit integration
git worktree add .claude/worktrees/ios-healthkit -b feature/ios-healthkit
cd .claude/worktrees/ios-healthkit
claude

# Terminal 2 — e.g., Supabase schema
git worktree add .claude/worktrees/supabase-schema -b feature/supabase-schema
cd .claude/worktrees/supabase-schema
claude
```

Each session works on its own branch with a full isolated copy of the repo.

### Merging work

When both sessions are done:
```bash
# Back in main repo
git merge feature/ios-healthkit
git merge feature/supabase-schema

# Clean up worktrees
git worktree remove .claude/worktrees/ios-healthkit
git worktree remove .claude/worktrees/supabase-schema
```

### Rules
- Each worktree should own clearly separate files — no overlapping edits
- Establish file ownership before starting (see parallelization map below)
- Commit frequently inside each worktree so merges stay clean
- If two workstreams need to share a contract (e.g., a shared data model), define it first in `main` before branching

---

## Mode 3: Agent Teams *(Experimental)*

For complex phases where agents need to coordinate directly (e.g., one agent builds an API endpoint while another builds the iOS layer that consumes it), enable agent teams:

```bash
# In .claude/settings.json or as env var
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
claude
```

Then prompt the lead agent:
```
"Create an agent team to implement the daily check-in flow.
Spawn three teammates:
- Backend: Build the Supabase Edge Function that calls Claude API and returns the coaching plan
- iOS: Build the SwiftUI morning briefing screen and data sync check UI
- Integration: Write the data normalization layer that maps Whoop/Strava/HealthKit responses to the unified schema

Each agent owns separate files. Backend goes first with the API contract,
then iOS and Integration can work in parallel."
```

### Rules
- Give each teammate explicit file ownership boundaries
- Define shared contracts (API shapes, data models) before spawning
- Start with research-only mode before allowing implementation
- Teams cost significantly more tokens — use for complex phases, not trivial tasks

---

## HealthOS Parallelization Map

This table defines which workstreams are safe to run in parallel per phase, and which files each owns.

### Phase 1: Foundation

| Workstream | Branch Name | File Ownership |
|---|---|---|
| iOS project setup + HealthKit | `feature/ios-foundation` | `HealthOS/` (Xcode project), `HealthOS/Services/HealthKit/` |
| Supabase project + auth schema | `feature/supabase-foundation` | `supabase/migrations/`, `supabase/schema.sql`, `docs/design/database-schema.md` |

> **Dependency:** iOS auth integration (Sign In with Apple) requires Supabase auth to be configured first. Complete Supabase auth setup before wiring iOS → Supabase auth.

---

### Phase 2: Integrations & Goals

| Workstream | Branch Name | File Ownership |
|---|---|---|
| Whoop API integration | `feature/whoop-integration` | `supabase/functions/whoop-sync/`, `HealthOS/Services/Whoop/` |
| Strava API integration | `feature/strava-integration` | `supabase/functions/strava-sync/`, `HealthOS/Services/Strava/` |
| Goal definition UI | `feature/goal-ui` | `HealthOS/Views/Goals/`, `HealthOS/Models/Goal.swift` |
| Data normalization layer | `feature/data-normalization` | `supabase/functions/normalize/`, `HealthOS/Models/HealthData.swift` |

> **Dependency:** Whoop and Strava integrations must define their normalized output shape before the data normalization layer is finalized.

---

### Phase 3: Training Program & Daily Plan

| Workstream | Branch Name | File Ownership |
|---|---|---|
| Training program UI (workout builder) | `feature/training-program-ui` | `HealthOS/Views/Training/`, `HealthOS/Models/Workout.swift` |
| Claude coaching engine (Edge Function) | `feature/coaching-engine` | `supabase/functions/coaching/`, `docs/design/coaching-prompt-architecture.md` |
| Morning briefing UI | `feature/morning-briefing-ui` | `HealthOS/Views/DailyCheckin/` |
| Self-assessment + journal | `feature/self-assessment` | `HealthOS/Views/Journal/`, `HealthOS/Models/DailyCheckin.swift` |

> **Dependency:** Coaching engine must define its output JSON schema before morning briefing UI is built.

---

### Phase 4: Progress & Retrospective

| Workstream | Branch Name | File Ownership |
|---|---|---|
| Strength progression tracker | `feature/strength-tracking` | `HealthOS/Views/Progress/Strength/`, `supabase/functions/strength-analysis/` |
| Endurance progression tracker | `feature/endurance-tracking` | `HealthOS/Views/Progress/Endurance/`, `supabase/functions/endurance-analysis/` |
| Benchmark testing system | `feature/benchmark-tests` | `HealthOS/Views/Benchmarks/`, `HealthOS/Models/BenchmarkTest.swift` |
| Retrospective generation | `feature/retrospective` | `supabase/functions/retrospective/`, `HealthOS/Views/Retrospective/` |

---

## Lead Agent Responsibilities

When running parallel workstreams, one session acts as the **lead** and coordinates:

1. **Before branching:** Define shared contracts — data models, API response shapes, function signatures — and commit them to `main` so all worktrees inherit them
2. **During parallel work:** Monitor each session's progress; unblock dependencies as they complete
3. **Before merging:** Review each branch for contract compliance AND verify the build passes (see Build Verification below)
4. **After merging:** Pull `main`, confirm the build still passes, resolve any conflicts in shared files

## Build Verification (Required Before Every iOS PR)

Any worktree that touches Swift files must run this before creating a PR:

```bash
# Ensure Config.xcconfig exists (copy from template if not)
[ -f HealthOS/Config.xcconfig ] || cp HealthOS/Config.xcconfig.template HealthOS/Config.xcconfig

xcodebuild build \
  -project HealthOS.xcodeproj \
  -scheme HealthOS \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tail -5
```

**`** BUILD SUCCEEDED **`** → push and create PR
**`** BUILD FAILED **`** → fix all errors first. Do not push a broken build.

Worktrees that only modify `supabase/` or `docs/` are exempt.

---

## Prompt Templates

### Research subagent prompt
```
"Research [topic A], [topic B], and [topic C] in parallel.
For each: summarize the key data points available, the auth mechanism,
any rate limits, and any gotchas relevant to HealthOS.
Return a concise summary per source."
```

### Worktree implementation prompt (per session)
```
"You are working in an isolated branch: [branch-name].
Your file ownership is: [list of directories/files].
Do NOT modify files outside your ownership boundary.

Your task: [specific feature description]

Shared contracts to respect:
- Data model: [reference to model file or inline schema]
- API shape: [reference to API contract doc]

When done:
1. Commit all changes with descriptive messages
2. If you touched any Swift files, run the build verification:
   [ -f HealthOS/Config.xcconfig ] || cp HealthOS/Config.xcconfig.template HealthOS/Config.xcconfig
   xcodebuild build -project HealthOS.xcodeproj -scheme HealthOS \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
3. Fix any build errors before finishing — do NOT leave a broken build.
4. Report BUILD SUCCEEDED or list any remaining issues."
```

### Agent team prompt (lead)
```
"Create an agent team to implement [feature].
Spawn [N] teammates:
- [Teammate 1]: owns [files], responsible for [task]
- [Teammate 2]: owns [files], responsible for [task]
- [Teammate 3]: owns [files], responsible for [task]

Dependencies:
- [Teammate 1] must complete the API contract before [Teammate 2] begins implementation

Shared contracts are defined in [path to contract docs].
Start in research/planning mode. Do not write code until the plan is approved."
```

---

## Git Hygiene for Parallel Development

```bash
# Always branch from latest main
git checkout main && git pull
git worktree add .claude/worktrees/<name> -b feature/<name>

# Commit often and with context
git commit -m "feat(whoop): normalize sleep score to unified HealthData schema"

# Keep branches short-lived — merge within the same phase
# Do not let feature branches diverge more than a few days from main

# After merging, clean up
git worktree remove .claude/worktrees/<name>
git branch -d feature/<name>
```
