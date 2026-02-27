# Safety Infrastructure

This document defines the safety layers that protect HealthOS from regressions, credential leaks, git history destruction, and agent mistakes during multi-agent parallel development.

---

## Overview

| Layer | What | When to Set Up | Status |
|---|---|---|---|
| **Layer 1** | Pre-commit hooks, Claude Code hooks, xcconfig template | Before any worktree starts | **Complete** |
| **Layer 1b** | Manual build verification rule (xcodebuild before every iOS PR) | Before Phase 2 worktrees | **Complete — in CLAUDE.md + workflow docs** |
| **Layer 2** | GitHub Actions CI pipeline | In parallel with worktrees (doesn't block work) | Pending |
| **Layer 3** | Contract compliance script | After Phase 1 merges (needs real code to validate) | Ready to start |

---

## Layer 1: Pre-Execution Safety (Before Worktrees)

### 1a. Pre-Commit Hook

A git pre-commit hook that runs before every commit, in every branch and worktree.

**What it blocks:**
- Commits containing secrets (API keys, tokens, passwords, `.env` files, `.xcconfig` files with real values, `.p8` files)
- Files larger than 5MB (prevents accidental binary commits)

**What it warns on:**
- TODO/FIXME comments (informational, does not block)

**Location:** `.githooks/pre-commit` (committed to repo, shared across all worktrees)

**Activation:** Each developer (or worktree) runs:
```bash
git config core.hooksPath .githooks
```

### 1b. Claude Code Hooks

Claude Code hooks intercept tool calls before they execute. Defined in `.claude/settings.json`.

**What they block:**

| Hook | Trigger | Blocks |
|---|---|---|
| **No force push** | `Bash` tool containing `push --force` or `push -f` | Force pushes that destroy remote history |
| **No destructive git** | `Bash` tool containing `reset --hard`, `clean -fd`, `checkout -- .` | Commands that destroy local uncommitted work |
| **No credential writes** | `Write`/`Edit` tool targeting `*.env`, `*.p8`, `*.xcconfig` (non-template) | Writing real secrets to tracked files |
| **No broad deletions** | `Bash` tool containing `rm -rf` on project-level directories | Accidental deletion of project directories |

### 1c. Xcconfig Template Pattern

iOS configuration uses `.xcconfig` files that contain Supabase credentials. The pattern:

- **`HealthOS/Config.xcconfig.template`** — committed to git, contains placeholder values
- **`HealthOS/Config.xcconfig`** — NOT committed (in `.gitignore`), contains real values
- Developers copy the template and fill in their own values

---

## Layer 2: CI Pipeline (During Worktrees)

### GitHub Actions Workflow

Runs on every PR targeting `main`.

**Jobs:**

| Job | What It Does |
|---|---|
| **swift-build** | Builds the Xcode project (`xcodebuild build`) — catches compile errors |
| **swift-test** | Runs XCTest suite (`xcodebuild test`) — catches regressions |
| **sql-validate** | Validates SQL migrations parse correctly |
| **secret-scan** | Runs `trufflehog` or `gitleaks` on the diff — catches secrets that snuck past pre-commit |

**Branch protection update:** Once CI is running, require status checks to pass before PR merge.

---

## Layer 3: Contract Compliance (Post Phase 1)

### Schema ↔ Model Sync Check

A script that verifies Swift models match the database schema contract.

**What it checks:**
- Every column in `phase-1-database-schema.sql` has a corresponding Swift property
- Column types map correctly (e.g., `TIMESTAMPTZ` → `Date`, `NUMERIC` → `Double`, `TEXT` → `String`)
- Enum values in SQL `CHECK` constraints match Swift enum cases
- Table names map to expected Swift model names

**When it runs:**
- Manually during Phase 1 review
- Automatically in CI after Phase 1 merges (added to GitHub Actions)

---

## Agent-Specific Safety Rules

These rules apply to all Claude Code sessions operating in worktrees:

1. **File ownership is enforced** — each worktree session is told which files it owns. Claude Code hooks warn if a write targets a file outside the ownership boundary.
2. **No cross-worktree communication** — worktrees do not read or modify each other's branches. Coordination happens through contracts committed to `main`.
3. **Commit early, commit often** — small commits reduce merge conflict surface area and make rollbacks surgical.
4. **No direct pushes to `main`** — enforced by GitHub branch protection. All changes go through PRs.
5. **PR review before merge** — the lead agent (or developer) reviews each worktree's PR for contract compliance before merging.
