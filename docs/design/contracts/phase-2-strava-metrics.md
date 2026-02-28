# Phase 2 — Strava Metrics Contract

This contract defines every `metric_name`, `category`, `unit`, and `metadata` JSONB shape that the Strava sync Edge Function produces when writing to `health_metrics`.

---

## Strava Metrics Mapping

| Strava API Endpoint | `category` | `metric_name` | `numeric_value` | `unit` | `text_value` | `metadata` JSONB shape |
|---|---|---|---|---|---|---|
| `/api/v3/athlete/activities` | `workout` | `strava_activity` | duration in minutes | `minutes` | activity type string (e.g. `"Run"`, `"Ride"`, `"Swim"`) | `{ "strava_id": number, "distance_meters": number, "moving_time_seconds": number, "elapsed_time_seconds": number, "total_elevation_gain_meters": number, "average_speed_mps": number, "max_speed_mps": number, "average_heartrate_bpm": number or null, "max_heartrate_bpm": number or null, "suffer_score": number or null, "calories": number or null }` |
| `/api/v3/athlete/activities` (run) | `workout` | `strava_run_pace` | pace in sec/km | `sec_per_km` | null | `{ "strava_id": number, "distance_km": number }` |
| `/api/v3/athlete/activities` (ride) | `workout` | `strava_ride_power` | avg watts | `watts` | null | `{ "strava_id": number, "weighted_avg_watts": number or null, "distance_km": number }` |
| computed | `training_load` | `strava_training_load` | suffer_score sum (rolling 7d) | `score` | null | `{ "period_days": 7, "activity_count": number, "total_distance_km": number }` |

---

## Strava OAuth Configuration

- **Authorization URL:** `https://www.strava.com/oauth/authorize`
- **Token URL:** `https://www.strava.com/oauth/token`
- **Required Scopes:** `read,activity:read_all`
- **Token Refresh:** Check if expired before every API call; if expired, refresh using refresh_token

---

## Sync Strategy

- **Initial:** Fetch last 30 days of activities
- **Recurring:** Fetch activities since `last_synced_epoch` (stored in `oauth_sync_cursors`)
- **For each activity:** Create `strava_activity` metric. If Run: also create `strava_run_pace`. If Ride with power: also create `strava_ride_power`.
- **Training load:** Compute rolling 7-day sum of suffer_scores daily
