# Phase 2 Execution Plan

**Status:** Ready to execute
**Contracts:** 6 shared contract files required
**Workstreams:** 4 parallel
**Merge sequence:** 4 PRs (goal-ui first, data-normalization last)

## Quick Summary

Phase 2 adds Whoop + Strava integrations, goal setting, and data normalization. All 4 workstreams can run in parallel because shared contracts fully specify all output shapes before any code is written.

**Contracts to commit first:**
1. `phase-2-database-schema.sql` — goals table, oauth_sync_cursors, health_metrics updates
2. `phase-2-whoop-metrics.md` — every Whoop metric's shape
3. `phase-2-strava-metrics.md` — every Strava metric's shape
4. `phase-2-swift-models.md` — Goal model, Goal service protocols
5. `phase-2-edge-function-interfaces.md` — NormalizedDaySummary (critical for Phase 3)
6. `phase-2-goal-templates.md` — predefined goal templates

**Workstreams (all parallel):**
- `feature/whoop-integration` — Whoop API + Edge Function + service layer
- `feature/strava-integration` — Strava API + Edge Function + service layer
- `feature/goal-ui` — Goal CRUD views + Goal model
- `feature/data-normalization` — normalize Edge Function + HealthData Swift models

**Merge order:**
1. goal-ui
2. whoop-integration
3. strava-integration
4. data-normalization (last, consumes what others produce)

## Full Plan Details

See the detailed prompt output in `.claude/agents/lead.md` execution history for:
- All 6 contract file specifications (complete JSON/SQL/TypeScript/Swift)
- Exact worktree prompts for each of the 4 agents
- Dependency analysis
- Post-merge integration tasks

## Key Design Decisions

**Single normalize Edge Function:** Rather than individual normalizers per source, one centralized function that deduplicates across Whoop/Strava/HealthKit. This prevents inconsistencies (e.g., which source do we trust for sleep? Whoop wins by design).

**NormalizedDaySummary as the bridge:** Phase 2's normalize function outputs this JSON structure. Phase 3's coaching engine (daily briefing) will consume it directly. This contract is critical — get it right here, and Phase 3 flows cleanly.

**Contracts fully specify output shapes:** Every Whoop metric_name, Strava metric_name, and JSON field is specified. Agents don't guess. Deduplication rules are explicit.

## Next Steps (for when you're ready)

1. Create contract files (copy from the detailed plan)
2. `git add docs/design/contracts/phase-2-*.md` and commit
3. Create worktrees (see prompts in detailed plan):
   ```bash
   git worktree add .claude/worktrees/goal-ui -b feature/goal-ui && cd ... && claude
   git worktree add .claude/worktrees/whoop -b feature/whoop-integration && cd ... && claude
   git worktree add .claude/worktrees/strava -b feature/strava-integration && cd ... && claude
   git worktree add .claude/worktrees/normalize -b feature/data-normalization && cd ... && claude
   ```
4. Paste the exact prompts from the detailed plan into each session
5. Merge in order: goal-ui → whoop → strava → normalize
6. Run post-merge integration tasks (lead agent)
