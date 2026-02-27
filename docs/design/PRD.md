# HealthOS — Product Requirements Document

**Version:** 0.1 (Draft)
**Last Updated:** 2026-02-27
**Author:** Nicholas Layton

---

## 1. Problem Statement

Managing health and wellness is fragmented and overwhelming. Data lives across wearables (Whoop, Garmin, Oura, Fitbit), fitness platforms (Strava, Apple Health), nutrition logs, and lab results — but no single system synthesizes it into a coherent, actionable daily plan. Users are left manually interpreting data and planning their own workouts, nutrition, recovery, and goal progression.

HealthOS solves this by acting as an **AI-powered personal health operating system** — it ingests all health data, understands your goals, and tells you exactly what to do today.

---

## 2. Vision

A single iOS app that replaces the need to manually plan health and fitness. You set goals once, connect your data sources, and every morning HealthOS tells you what to do — and every week/month/quarter, it tells you how you're progressing and what to adjust.

---

## 3. Target User

Health-conscious individuals who:
- Use one or more wearables/fitness trackers
- Have specific, measurable fitness and health goals (strength, endurance, body composition, biomarkers)
- Want a unified system rather than switching between 5+ apps
- Are willing to invest daily time in their health but want that time optimized

---

## 4. Core User Experiences

### 4.1 Goal Setting (Define)

Users define measurable targets across multiple health dimensions:

| Category | Example Goals |
|---|---|
| **Strength** | Back squat 315 lbs, bench press 225 lbs, deadlift 405 lbs, 20 strict pull-ups |
| **Endurance** | Sub-22:00 5K run, sub-3:30:00 100K cycling |
| **Body Composition** | 180 lbs body weight, 12% body fat |
| **Biomarkers** | Testosterone > 800 ng/dL, CRP < 1.0 mg/L (via Whoop Advanced Labs) |
| **Recovery & Lifestyle** | Average 7.5+ hrs sleep, HRV > 80ms, daily stress score < 40 |

Each goal includes:
- **Target value** and **target date**
- **Priority level** (primary / secondary / maintenance)
- **Time budget** — how many minutes per day the user allocates to health activities
- **Benchmark test type** — which test validates this goal (e.g., 1RM test for strength, DEXA for body fat, lab work for biomarkers)
- **Testing cadence** — how often the user wants to formally test (e.g., every 8 weeks, quarterly, twice annually). Defaults are suggested but fully customizable.

### 4.2 Training Program Design (Plan)

Users who want hands-on control over their training can define their own workout structure. This is the bridge between goals (Section 4.1) and daily execution (Section 4.3) — the user builds the program, and the AI coach helps schedule, adjust, and optimize it day-to-day.

#### Weekly Training Template

Users define a recurring weekly template that maps workout types to days:

| Day | Workout Type | Example |
|---|---|---|
| Monday | Upper Strength | Heavy bench, OHP, rows, pull-ups |
| Tuesday | Long Run | Marathon training long run (10–18 mi) |
| Wednesday | Active Recovery | Mobility, yoga, light walk |
| Thursday | Lower Strength | Heavy squat, deadlift, lunges |
| Friday | HYROX Circuit | Sled push/pull, rowing, wall balls, burpee broad jumps |
| Saturday | Hybrid (Cardio + Strength) | Short run + accessory lifts |
| Sunday | Rest | Full rest day |

The template is a **default plan, not a rigid schedule.** The AI coach uses it as the user's intent and adjusts daily based on recovery, strain, calendar, and self-assessment. If the user is crushed on a scheduled strength day, the coach might suggest swapping it with tomorrow's recovery day — but always explains why and lets the user override.

#### Custom Workout Definitions

Users can create and name reusable workout definitions with full detail:

**Example: "Upper Strength Day"**
- Type: Strength
- Focus: Upper body
- Intensity: Heavy
- Movements:
  - Bench press — 5 sets × 5 reps @ RPE 8
  - Overhead press — 4 sets × 6 reps @ RPE 7
  - Barbell row — 4 sets × 8 reps
  - Weighted pull-ups — 4 sets × 6 reps
  - Dumbbell lateral raises — 3 sets × 12 reps
- Estimated duration: 60–75 min

**Example: "Long Run Day"**
- Type: Endurance
- Focus: Distance running
- Intensity: Easy/moderate (Zone 2–3)
- Target: Distance-based (e.g., 14 miles) or time-based (e.g., 90 min)
- Pace guidance: Conversational pace, HR < 150 bpm
- Estimated duration: 90–120 min

**Example: "HYROX Circuit"**
- Type: Hybrid (circuit)
- Focus: Full body, competition prep
- Intensity: High
- Structure: 8 rounds, each round =
  - 1 km run
  - 1 functional station (sled push 50m, sled pull 50m, burpee broad jumps × 80m, rowing 1000m, farmers carry 200m, sandbag lunges 100m, wall balls × 100, ski erg 1000m)
- Scaling: User can define shortened versions (4 rounds, half distances) for training days vs. full simulation
- Estimated duration: 60–90 min

#### Workout Definition Properties

Each custom workout includes:
- **Name** — user-defined label (e.g., "Upper Strength Day", "Tempo Run", "HYROX Simulation")
- **Type** — strength / endurance / hybrid / recovery / mobility
- **Focus** — body region or energy system (upper, lower, full body, aerobic, anaerobic)
- **Intensity** — light / moderate / heavy / max effort
- **Movements** — ordered list of exercises, each with sets, reps, weight/RPE/pace targets (as applicable)
- **Estimated duration** — so the coach can schedule it within available calendar windows
- **Notes** — free text for anything else (e.g., "superset the last two movements", "do this fasted")

#### How the AI Coach Uses the Training Program

The user's training program is a **constraint and preference, not a suggestion to be ignored.** The AI coach:

1. **Respects the weekly template** — follows the user's intended training split as closely as possible
2. **Fills in the details** — if the user defines "Lower Strength Day" but doesn't specify exact weights, the coach suggests loads based on recent training data and progression
3. **Adapts when necessary** — swaps days, reduces volume, or modifies intensity based on recovery/strain/calendar, but always explains the deviation and asks for confirmation
4. **Progresses over time** — suggests incremental overload (e.g., "+5 lbs on squat this week", "add 1 mile to your long run") aligned with goals and benchmark trends
5. **Never overrides without consent** — if the user says "I'm doing my heavy squat day regardless of recovery score," the coach acknowledges, adjusts the rest of the week accordingly, and moves on

### 4.3 Daily Execution (Do)

The primary user journey — the morning briefing:

#### Morning Check-In Flow

1. **Open app in the morning**
2. **Data sync check** — the app knows which sources are required (e.g., Whoop sleep, Apple HealthKit activity) and shows sync status with per-source detail:

   | Source | Data Points Ingested |
   |---|---|
   | **Whoop** | Sleep score, sleep stages, HRV, respiratory rate, skin temp, recovery score, strain score (prior day), journal entries |
   | **Apple HealthKit** | Sleep analysis, resting heart rate, heart rate variability, step count, active energy, workout summaries, weight, body fat |
   | **Strava** | Weekly training load (fitness/fatigue), recent activity details (distance, pace, elevation, relative effort) |
   | **Apple Calendar** | Today's events, free/busy windows, travel time estimates |

3. **Self-assessment prompt** — before generating the plan, the user reports how they *feel* today:
   - **Energy level** (1–5 scale)
   - **Muscle soreness** (none / mild / moderate / severe) with optional body region tags
   - **Mood / motivation** (1–5 scale)
   - **Illness or injury notes** (free text, optional)
   - **Anything else the coach should know** (free text, optional — e.g., "stressful day ahead", "slept poorly despite what the data says", "feeling great despite low recovery score")

   The self-assessment is a **first-class input** that can override wearable data. If Whoop says recovery is 85% but the user reports feeling terrible, the coaching engine weights the user's subjective input heavily. The philosophy: **the user knows their body better than any sensor.**

4. **Calendar confirmation** — the app reads today's calendar and prompts: *"Is your calendar up to date?"* The user confirms or makes quick adjustments. This ensures the AI coach knows about meetings, travel, commitments, and available time windows before generating the plan.

5. **Once all inputs are collected** (wearable data + self-assessment + calendar), the app generates today's coaching plan.

#### Daily Coaching Output

The coaching output synthesizes **all** integration data points into a single, actionable plan. Every recommendation is grounded in specific data.

- **Workout** — what to train, specific exercises/sets/reps or run distance/pace, scheduled around calendar commitments (e.g., "45-min strength session — best window is 6:30–7:15 AM before your 8 AM meeting"). Intensity calibrated to:
  - Whoop recovery score and HRV
  - Whoop strain score from prior day(s)
  - Strava weekly training load and fatigue curve
  - User's self-reported energy and soreness
- **Nutrition** — calorie/macro targets for the day, adjusted for today's planned training load and yesterday's strain
- **Recovery** — sleep target for tonight (informed by Whoop sleep score trends and HealthKit sleep analysis), stress management suggestions, mobility work targeted at self-reported sore areas
- **Schedule-aware alerts** — conflicts between health goals and calendar (e.g., "Back-to-back meetings 9 AM–4 PM — consider a 20-min lunch walk instead of your planned run; reschedule run to evening")
- **Trend alerts** — anything off-track based on multi-day patterns (e.g., "HRV trending down 15% this week — consider a deload", "Strava training load is 30% above baseline — injury risk elevated")

#### "Why Did You Suggest This?" — Data Source Transparency

Every coaching recommendation includes an expandable **"View sources"** section that shows the user exactly which data points informed the suggestion:

> **Suggestion:** "Light recovery run today (30 min, Zone 2) instead of your planned tempo run"
>
> **Sources:**
> - Whoop Recovery: 42% (below your 60% threshold for high-intensity work)
> - Whoop Strain: 18.2 yesterday (heavy day)
> - Strava Training Load: 15% above your 4-week average
> - HRV: 38ms (trending down 22% over the past 5 days)
> - Self-assessment: Energy 2/5, moderate quad soreness
> - Calendar: 1-hour free window at 6:30 AM

This transparency builds trust and lets the user make informed decisions when they choose to override a recommendation.

Plans cascade across time horizons:
- **Daily** — today's specific actions
- **Weekly** — this week's training split and focus areas
- **Monthly** — mesocycle structure, progressive overload targets
- **Quarterly** — phase goals and milestone check-ins
- **Annually** — macro goal trajectory

### 4.3 Progress Tracking & Retrospective (Review)

#### Automated Progress Monitoring (Passive)

Continuous tracking from daily data ingestion — no extra effort from the user:

- **Strength tracking** — pulls workout data from Whoop strength training logs, Apple HealthKit, or manual entry. Tracks estimated 1RM progression for each target lift.
- **Endurance tracking** — discovers runs from Strava/Whoop/Apple, tracks pace and distance trends against 5K/cycling goals.
- **Body composition** — weight from smart scale via HealthKit, body fat from periodic measurements.
- **Biomarkers** — lab results via Whoop Advanced Labs integration, manual entry for other labs.

#### Benchmark Testing (Active)

Scheduled, intentional tests to get ground-truth measurements of progress. The AI coach proactively suggests these at the right cadence — not so often that they disrupt training, but often enough to validate that the plan is working.

| Test Type | What It Measures | Example Cadence |
|---|---|---|
| **1RM Testing** | True max strength for target lifts (squat, bench, deadlift, press) | Every 8–12 weeks |
| **All-Out Race Effort** | True endurance capacity (5K time trial, FTP test, 100K ride) | Every 12–16 weeks |
| **DEXA Scan** | Body fat %, lean mass, bone density — gold standard body composition | Every 3–6 months |
| **Lab Work (Whoop Advanced Labs / bloodwork)** | Testosterone, cortisol, CRP, lipids, metabolic markers | Every 3–6 months |
| **HRV / Resting HR Baseline** | Aerobic fitness and recovery capacity trend | Continuous (auto-tracked), flagged quarterly |

**User-configurable cadence:** Users set their preferred testing frequency per test type during goal setup. The AI coach respects this cadence but can suggest adjustments (e.g., "You haven't tested your 1RM squat in 14 weeks and your estimated max has plateaued — consider scheduling a test this week").

**Testing workflow:**
1. **Schedule** — the app suggests upcoming benchmark tests on the calendar (e.g., "DEXA scan due in ~2 weeks — book an appointment")
2. **Remind** — push notification and morning briefing reminder as the test window approaches
3. **Record** — user logs the result (manual entry for DEXA/labs, auto-detected for race efforts and 1RM attempts)
4. **Analyze** — AI compares the benchmark result against the goal, prior benchmarks, and estimated progress from passive tracking. Generates a retrospective insight (e.g., "Your DEXA shows 14.2% BF, down from 16.8% three months ago — on track for your 12% target by August")

#### Retrospective Coaching

- **Weekly review** — what went well, what was missed, adjustment suggestions
- **Monthly review** — are you on track for quarterly milestones? Goal pace analysis. Are any benchmark tests coming due?
- **Quarterly review** — deep retrospective anchored by benchmark test results. Were goals realistic? Does the plan need restructuring? AI-driven recommendations to adjust goals or execution strategy. Prompts the user to complete any overdue benchmark tests before the review.

---

## 5. Data Sources (MVP)

### 5.1 MVP Integrations

| Source | Data | Integration Method |
|---|---|---|
| **Apple HealthKit** | Steps, heart rate, workouts, sleep, weight, body fat | Native HealthKit SDK |
| **Apple Calendar (EventKit)** | Daily schedule, meetings, time blocks, travel time | Native EventKit SDK |
| **Whoop** | Sleep (stages, efficiency), strain, recovery, HRV, journal, strength workouts, Advanced Labs | Whoop API |
| **Strava** | Runs, rides, activity details (distance, pace, elevation) | Strava API |

### 5.2 Post-MVP Integrations

| Source | Data | Integration Method |
|---|---|---|
| **Garmin Connect** | Workouts, sleep, stress, body battery | Garmin API |
| **Oura** | Sleep, readiness, activity | Oura API |
| **Fitbit** | Sleep, heart rate, activity | Fitbit Web API |
| **AI Meal Recognition** | Nutrition via photo capture | Claude Vision API (photo → macro estimation) |
| **MyFitnessPal / Cronometer** | Detailed nutrition logging | API integration |
| **Manual Lab Entry** | Bloodwork not covered by Whoop Labs | Manual input form |

---

## 6. Technical Architecture

### 6.1 iOS Client

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Minimum iOS Version:** 17.0
- **Key Frameworks:** HealthKit, EventKit, BackgroundTasks, UserNotifications
- **Local Storage:** SwiftData for offline caching and quick access
- **Architecture Pattern:** MVVM with a service layer for data integrations

### 6.2 Backend

- **Platform:** Supabase (PostgreSQL + Auth + Edge Functions + Realtime)
- **Authentication:** Supabase Auth (Apple Sign-In as primary, email/password as fallback)
- **Database:** PostgreSQL via Supabase — stores user profiles, goals, plans, synced health data, and coaching history
- **Edge Functions:** Supabase Edge Functions (Deno/TypeScript) for:
  - Orchestrating third-party API syncs (Whoop, Strava)
  - Calling Claude API for coaching logic
  - Generating daily/weekly/monthly plans
- **Storage:** Supabase Storage for meal photos (post-MVP)

### 6.3 AI Coaching Engine

- **LLM:** Claude API (Anthropic)
- **Responsibilities:**
  - Generate personalized, schedule-aware daily plans based on goals + recent data + today's calendar
  - Analyze trends and produce weekly/monthly/quarterly retrospectives
  - Provide natural language coaching feedback and adjustments
  - (Post-MVP) Estimate meal macros from photos via Claude Vision
- **Prompt Architecture:** Structured system prompts with full context injected per request:
  - User goals and priority levels
  - Last 7 days of Whoop scores (sleep, strain, recovery, HRV)
  - Last 7 days of HealthKit data (sleep, resting HR, HRV, activity)
  - Strava training load (current fitness/fatigue balance)
  - Today's calendar events and free windows
  - Today's self-assessment (energy, soreness, mood, notes)
  - Recent benchmark test results
  - Current training phase and mesocycle position
- **Output Structure:** Each coaching recommendation includes:
  - The actionable suggestion
  - A `sources` array listing every data point that influenced it (for the "View sources" UI)
  - A confidence level (high/medium/low) based on data completeness
  - An override flag if the suggestion conflicts with user self-assessment
- **Guardrails:** AI output is structured (JSON) and validated before display; coaching is clearly labeled as AI-generated, not medical advice

### 6.4 Data Flow

```
Wearables/APIs ──→ Supabase Edge Functions → PostgreSQL
Apple Calendar ──→ (via EventKit on device)        ↓
                          Claude API ← User Context + Recent Data + Today's Calendar
                                              ↓
                                  Schedule-Aware Plan (JSON)
                                              ↓
                                     iOS App (SwiftUI)
```

---

## 7. Multi-User Support

- Each user authenticates independently via Apple Sign-In
- All data is scoped to the authenticated user in Supabase (Row Level Security)
- Users manage their own integrations, goals, and plans
- Backend is multi-tenant from day one — no single-user assumptions in the data model

---

## 8. MVP Scope & Milestones

### Phase 1: Foundation (Weeks 1–3)
- iOS project setup (SwiftUI, SwiftData, HealthKit permissions)
- Supabase project setup (auth, database schema, RLS policies)
- Apple Sign-In authentication flow
- Apple HealthKit integration (read sleep, workouts, heart rate, steps, weight)
- Apple Calendar integration via EventKit (read today's events, detect free/busy windows)
- Basic user profile and onboarding

### Phase 2: Integrations & Goals (Weeks 4–6)
- Whoop API integration (sleep, strain, recovery, HRV, strength workouts)
- Strava API integration (runs, rides, training load)
- Goal definition UI (strength, endurance, body composition, biomarker targets)
- Data aggregation layer — normalize data from all sources into a unified schema

### Phase 3: Training Program & Daily Plan (Weeks 7–9)
- Training program design UI — weekly template builder, custom workout definitions (name, type, movements, sets, reps, intensity)
- Workout library — create, edit, reuse custom workouts
- Claude API integration via Supabase Edge Functions
- Morning briefing flow — data sync check → self-assessment → calendar confirmation → generate daily plan
- Daily plan UI (workout, nutrition, recovery, alerts) with "View sources" expandable per recommendation
- Weekly plan view with training template overlay

### Phase 4: Progress & Retrospective (Weeks 10–12)
- Strength progression tracking (1RM estimates from workout logs)
- Endurance progression tracking (pace/distance trends)
- Body composition tracking (weight/body fat trends)
- Benchmark testing system — configurable cadence per goal, scheduling suggestions, result logging, and trend analysis
- Weekly and monthly retrospective generation via Claude (anchored by benchmark results when available)
- Quarterly review with benchmark-driven insights
- Goal progress dashboard

---

## 9. Key Design Principles

1. **Morning-first** — the app is designed around the morning ritual. Open → sync → plan → go.
2. **Data-driven, not opinion-driven** — every recommendation ties back to actual data from wearables and user inputs.
3. **Progressive disclosure** — show today's plan simply up front; let users drill into weekly/monthly views and detailed analytics on demand.
4. **Coach, not dictator** — the AI suggests and explains; the user decides. Plans are adjustable.
5. **No manual entry unless necessary** — automate data ingestion wherever possible. Only ask the user for things machines can't measure (subjective stress, illness, life events).

---

## 10. Success Metrics

| Metric | Target |
|---|---|
| Daily active usage | User opens app 6+ days/week |
| Morning plan generation | < 30 seconds from open to plan displayed |
| Data source sync reliability | > 95% successful daily syncs |
| Goal tracking accuracy | User-reported usefulness rating > 4/5 |
| Coaching relevance | User acts on > 70% of daily plan suggestions |

---

## 11. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Third-party API rate limits or downtime | Cache last-known data; degrade gracefully with partial data |
| AI coaching gives bad advice | Structured output validation; disclaimers; user override always available |
| HealthKit permission denials | Clear onboarding explaining why each permission matters; graceful handling of partial permissions |
| Whoop/Strava API changes | Abstract integrations behind a common interface; monitor API changelogs |
| Scope creep | Strict MVP phasing; post-MVP features are documented but not built until Phase 1–4 ship |

---

## 12. Out of Scope (Post-MVP)

- AI meal photo recognition
- Garmin, Oura, Fitbit integrations
- Social/community features
- Apple Watch companion app
- Wearable push notifications ("time to go to bed")
- Monetization features (subscriptions, data insights marketplace)
- Android version

---

## 13. Open Questions

1. **Whoop API access** — Does the current Whoop API provide sufficient access to strength workout data, or do we need to rely on HealthKit passthrough?
2. **Nutrition strategy for MVP** — Without AI meal photos, should we integrate MyFitnessPal for MVP or rely on macro target guidance only?
3. **Offline support** — How much of the app should work without internet? (Cached plans from last sync? Full offline mode?)
4. **Journal design** — Build a custom morning journal, or lean on Whoop journal data initially?
