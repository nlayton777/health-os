# Phase 2 — Edge Function Interfaces Contract

---

## whoop-sync Edge Function

- **Path:** `supabase/functions/whoop-sync/index.ts`
- **Request:**
```typescript
interface WhoopSyncRequest {
  action: "sync" | "oauth_callback" | "disconnect";
  code?: string;
  redirect_uri?: string;
}
```
- **Response:**
```typescript
interface WhoopSyncResponse {
  success: boolean;
  action: string;
  metrics_synced?: number;
  error?: string;
}
```

---

## strava-sync Edge Function

- **Path:** `supabase/functions/strava-sync/index.ts`
- **Request:**
```typescript
interface StravaSyncRequest {
  action: "sync" | "oauth_callback" | "disconnect";
  code?: string;
  redirect_uri?: string;
}
```
- **Response:**
```typescript
interface StravaSyncResponse {
  success: boolean;
  action: string;
  activities_synced?: number;
  metrics_synced?: number;
  error?: string;
}
```

---

## normalize Edge Function

- **Path:** `supabase/functions/normalize/index.ts`
- **Request:**
```typescript
interface NormalizeRequest {
  date: string;  // ISO 8601 YYYY-MM-DD
  days?: number; // default 1, max 14
}
```
- **Response:**
```typescript
interface NormalizeResponse {
  success: boolean;
  summaries: NormalizedDaySummary[];
}

interface NormalizedDaySummary {
  date: string;
  sleep: {
    total_hours: number | null;
    sleep_score: number | null;
    sources: string[];
  };
  recovery: {
    whoop_recovery_score: number | null;
    hrv_ms: number | null;
    hrv_source: string | null;
    resting_hr_bpm: number | null;
    sources: string[];
  };
  strain: {
    whoop_strain_score: number | null;
    sources: string[];
  };
  workouts: NormalizedWorkout[];
  body: {
    weight_kg: number | null;
    body_fat_pct: number | null;
    sources: string[];
  };
  training_load: {
    strava_7d_score: number | null;
    sources: string[];
  };
}

interface NormalizedWorkout {
  source: string;
  type: string;
  duration_minutes: number;
  distance_meters: number | null;
  average_hr_bpm: number | null;
  calories: number | null;
  strain_score: number | null;
  pace_sec_per_km: number | null;
  avg_watts: number | null;
}
```

---

## Deduplication Rules (Critical for normalize)

- **Overlapping workouts (Whoop + Strava within 15 min):** Merge with source "merged", use Strava for distance/pace/power and Whoop for strain/HR zones
- **Overlapping workouts (HealthKit + Whoop/Strava):** Drop HealthKit duplicate
- **Sleep:** Prefer Whoop over HealthKit
- **HRV:** Prefer Whoop RMSSD over HealthKit SDNN; report source
- **Resting HR:** Prefer Whoop over HealthKit; report source
