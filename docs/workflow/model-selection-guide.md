# Model Selection Guide

This guide ensures you pick the right Claude model for each task, balancing capability and cost.

---

## Quick Decision Tree

```
Is this a simple read/search task?
  ├─ Yes → HAIKU
  │   (grep patterns, reading single files, simple questions)
  │
  └─ No, needs reasoning/synthesis?
      ├─ Complex multi-step coding task?
      │   └─ Yes → OPUS (complex architecture, refactoring, multi-file changes)
      │
      ├─ Straightforward feature implementation?
      │   └─ Yes → SONNET (good balance for most coding)
      │
      ├─ Research, exploration, or summary?
      │   └─ Yes → HAIKU (if narrow) or SONNET (if broad)
      │
      └─ Need extended reasoning/planning?
          └─ Yes → OPUS
```

---

## Model Selection by Task Type

### HAIKU (Fast, cheap — use by default)

**Best for:**
- Reading individual files (< 500 lines)
- Searching code with grep/glob patterns
- Answering specific questions about existing code
- Summarizing docs or comments
- Writing simple functions with clear requirements
- Debugging obvious issues (undefined variable, typo)

**Cost:** ~1/3 of Sonnet per token

**Examples from Phase 1:**
- ✅ "What's in this migration file?" → Haiku
- ✅ "Search for all uses of HealthKitService" → Haiku
- ✅ "Add a simple getter to this struct" → Haiku

**NOT for:**
- Multi-file refactoring
- Architecture design
- Complex reasoning about trade-offs

---

### SONNET (Balanced — default for coding)

**Best for:**
- Building individual features (1-3 files)
- Moderate complexity: parsing APIs, implementing protocols, wiring systems
- Code reviews where you need explanations
- Writing tests or documentation
- Debugging non-obvious issues (logic errors, async/await timing)
- Implementing work items from a well-defined spec

**Cost:** Baseline (~1x)

**Examples from Phase 1:**
- ✅ "Implement the HealthKitService protocol" → Sonnet
- ✅ "Build the LoginView with Sign In with Apple" → Sonnet
- ✅ Code review: "Check if these Swift models match the DB schema" → Sonnet

**NOT for:**
- Architectural redesigns
- Multi-day implementation tasks
- Ambiguous requirements needing exploration

---

### OPUS (Powerful — use when necessary)

**Best for:**
- Complex architectural planning (Phase 2 coordination, system design)
- Multi-step refactoring across many files
- Ambiguous requirements that need reasoning to clarify
- Code reviews requiring deep analysis (the Phase 1 review)
- Resolving contradictions or designing trade-offs

**Cost:** ~2x Sonnet per token

**Examples from Phase 1:**
- ✅ "Plan Phase 1 execution — identify workstreams and contracts" → Opus (that was lead agent, defaulted to Opus)
- ✅ "Review iOS foundation against all three contracts" → Opus (needed deep analysis)
- ✅ "Design the safety infrastructure layers" → Opus (architectural decision)

**NOT for:**
- Routine tasks (will waste tokens on overthinking)
- Time-sensitive work (slower generation)

---

## Pre-Prompt Checklist

Before you write a prompt, run through this:

- [ ] **Is the task well-defined?** (Yes → Haiku/Sonnet; No → Opus for planning)
- [ ] **Does it need code from multiple files?** (Yes → Sonnet/Opus; No → Haiku)
- [ ] **Does it need architectural reasoning?** (Yes → Opus; No → drop a tier)
- [ ] **Can the work be done in < 30 lines of code?** (Yes → Haiku; No → Sonnet)
- [ ] **Is this the first time solving this type of problem?** (Yes → Opus; No → Sonnet)

**Default assumption:** Sonnet. Only drop to Haiku for narrow reads, or bump to Opus if you catch yourself thinking "this is really complex."

---

## Cost Impact Examples

**Task:** Implement daily check-in Flow (Phase 3 work)

| Model | Scenario | Estimated Cost |
|---|---|---|
| Haiku | "Write a function to parse Whoop API response" | $0.05 |
| Sonnet | "Implement the full DailyCheckinService" | $0.25 |
| Opus | "Design the daily check-in architecture from scratch" | $0.50 |

Picking wrong on a multi-day task compounds. One wrongly-scoped Opus prompt can cost as much as 10 focused Sonnet tasks.

---

## Special Cases

### Code Reviews
- **Single file, clear checklist:** Haiku
- **Multiple files, unclear patterns:** Sonnet
- **Deep architectural analysis:** Opus

### Refactoring
- **Rename/reorganize files:** Haiku
- **Improve a single module:** Sonnet
- **Restructure the whole layer:** Opus

### Debugging
- **"Function X is undefined":** Haiku
- **"Why is this test failing?":** Sonnet
- **"Performance bottleneck across the system":** Opus

---

## Agents & Default Models

When spawning subagents via the Task tool:

| Agent Type | Default | Override When |
|---|---|---|
| `general-purpose` | Sonnet | Needs complex reasoning → Opus; narrow task → Haiku |
| `Explore` | Haiku | Complex analysis needed → Sonnet |
| `Plan` | Opus | Clear, routine planning → Sonnet |
| `claude-code-guide` | Haiku | (uses web search, appropriate for lookups) |

---

## Saving Money: Real Examples

**Phase 1 code review:** Took ~50k tokens at Sonnet rates.
**Better approach:**
1. Haiku: "List all files in HealthOS/Models" → check model names
2. Haiku: "Read each model, verify CodingKeys match DB column names"
3. Sonnet (once, final): "Are there any logical inconsistencies?" → synthesis pass

**Estimated savings:** 60% (split the work across models by complexity)

---

## When to Break the Rules

- You're stuck and don't know what to do → jump to Opus (clarity is worth it)
- Task is taking longer than expected → don't throw Opus at it; break it into smaller Haiku/Sonnet pieces
- You're iterating rapidly → stick with one model to keep context consistent
