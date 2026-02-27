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

### 4.2 Daily Execution (Do)

The primary user journey — the morning briefing:

1. **Open app in the morning**
2. **Data sync check** — the app knows which sources are required (e.g., Whoop sleep, Apple HealthKit activity) and shows sync status. If a morning journal/survey is required, it prompts for it.
3. **Once all required data is received**, the app generates today's plan:
   - **Workout** — what to train, specific exercises/sets/reps or run distance/pace, based on your program and recovery status
   - **Nutrition** — calorie/macro targets for the day, adjusted for today's training load
   - **Recovery** — sleep target for tonight, stress management suggestions, mobility work
   - **Alerts** — anything off-track (e.g., "HRV trending down 15% this week — consider a deload")

Plans cascade across time horizons:
- **Daily** — today's specific actions
- **Weekly** — this week's training split and focus areas
- **Monthly** — mesocycle structure, progressive overload targets
- **Quarterly** — phase goals and milestone check-ins
- **Annually** — macro goal trajectory

### 4.3 Progress Tracking & Retrospective (Review)

Automated progress monitoring:

- **Strength tracking** — pulls workout data from Whoop strength training logs, Apple HealthKit, or manual entry. Tracks 1RM estimates and progression for each target lift.
- **Endurance tracking** — discovers runs from Strava/Whoop/Apple, tracks pace and distance trends against 5K/cycling goals.
- **Body composition** — weight from smart scale via HealthKit, body fat from periodic measurements or DEXA scans.
- **Biomarkers** — lab results via Whoop Advanced Labs integration, manual entry for other labs.

Retrospective coaching:
- **Weekly review** — what went well, what was missed, adjustment suggestions
- **Monthly review** — are you on track for quarterly milestones? Goal pace analysis.
- **Quarterly review** — deep retrospective. Were goals realistic? Does the plan need restructuring? AI-driven recommendations to adjust goals or execution strategy.

---

## 5. Data Sources (MVP)

### 5.1 MVP Integrations

| Source | Data | Integration Method |
|---|---|---|
| **Apple HealthKit** | Steps, heart rate, workouts, sleep, weight, body fat | Native HealthKit SDK |
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
- **Key Frameworks:** HealthKit, BackgroundTasks, UserNotifications
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
  - Generate personalized daily plans based on goals + recent data
  - Analyze trends and produce weekly/monthly/quarterly retrospectives
  - Provide natural language coaching feedback and adjustments
  - (Post-MVP) Estimate meal macros from photos via Claude Vision
- **Prompt Architecture:** Structured system prompts with user context (goals, recent metrics, training history) injected per request
- **Guardrails:** AI output is structured (JSON) and validated before display; coaching is clearly labeled as AI-generated, not medical advice

### 6.4 Data Flow

```
Wearables/APIs → Supabase Edge Functions → PostgreSQL
                                              ↓
                          Claude API ← User Context + Recent Data
                                              ↓
                                    Personalized Plan (JSON)
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
- Basic user profile and onboarding

### Phase 2: Integrations & Goals (Weeks 4–6)
- Whoop API integration (sleep, strain, recovery, HRV, strength workouts)
- Strava API integration (runs, rides)
- Goal definition UI (strength, endurance, body composition, biomarker targets)
- Data aggregation layer — normalize data from all sources into a unified schema

### Phase 3: AI Coaching & Daily Plan (Weeks 7–9)
- Claude API integration via Supabase Edge Functions
- Morning briefing flow — data sync check → journal prompt → generate daily plan
- Daily plan UI (workout, nutrition, recovery, alerts)
- Weekly plan view

### Phase 4: Progress & Retrospective (Weeks 10–12)
- Strength progression tracking (1RM estimates from workout logs)
- Endurance progression tracking (pace/distance trends)
- Body composition tracking (weight/body fat trends)
- Weekly and monthly retrospective generation via Claude
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
