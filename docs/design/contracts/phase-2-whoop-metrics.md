# Phase 2 — Whoop Metrics Contract

This contract defines every `metric_name`, `category`, `unit`, and `metadata` JSONB shape that the Whoop sync Edge Function produces when writing to `health_metrics`. This is the contract between `whoop-sync/` and the normalization layer.

---

## Whoop Metrics Mapping

| Whoop API Endpoint | `category` | `metric_name` | `numeric_value` | `unit` | `text_value` | `metadata` JSONB shape |
|---|---|---|---|---|---|---|
| `/v1/recovery` | `recovery` | `whoop_recovery_score` | 0-100 | `percent` | null | `{ "hrv_rmssd_ms": number, "resting_heart_rate_bpm": number, "spo2_pct": number \| null, "skin_temp_celsius": number \| null, "user_calibrating": boolean }` |
| `/v1/recovery` | `hrv` | `whoop_hrv_rmssd` | value in ms | `ms` | null | `{ "recovery_id": string }` |
| `/v1/recovery` | `heart_rate` | `whoop_resting_hr` | value in bpm | `bpm` | null | `{ "recovery_id": string }` |
| `/v1/recovery` | `respiratory_rate` | `whoop_respiratory_rate` | breaths/min | `breaths_per_min` | null | `{}` |
| `/v1/recovery` | `skin_temperature` | `whoop_skin_temp` | celsius | `celsius` | null | `{}` |
| `/v1/cycle` (strain) | `strain` | `whoop_strain_score` | 0-21 | `score` | null | `{ "average_hr_bpm": number, "max_hr_bpm": number, "kilojoules": number, "cycle_id": string }` |
| `/v1/sleep` | `sleep` | `whoop_sleep_performance` | 0-100 | `percent` | null | `{ "sleep_efficiency_pct": number, "disturbance_count": number, "time_in_bed_hours": number, "latency_minutes": number, "sleep_id": string }` |
| `/v1/sleep` | `sleep` | `whoop_sleep_duration` | hours of sleep | `hours` | null | `{ "stage_rem_hours": number, "stage_deep_hours": number, "stage_light_hours": number, "stage_awake_hours": number }` |
| `/v1/sleep` | `sleep` | `whoop_sleep_stage` | null | null | `"rem"` / `"deep"` / `"light"` / `"awake"` | `{ "start_iso": string, "end_iso": string, "duration_seconds": number }` |
| `/v1/workout` | `workout` | `whoop_workout` | duration in minutes | `minutes` | sport name string | `{ "strain_score": number, "average_hr_bpm": number, "max_hr_bpm": number, "kilojoules": number, "distance_meters": number \| null, "zone_durations": { "zone_1_sec": number, "zone_2_sec": number, "zone_3_sec": number, "zone_4_sec": number, "zone_5_sec": number } }` |

---

## Whoop OAuth Configuration

- **Authorization URL:** `https://api.prod.whoop.com/oauth/oauth2/auth`
- **Token URL:** `https://api.prod.whoop.com/oauth/oauth2/token`
- **Required Scopes:** `read:recovery read:sleep read:workout read:cycles read:profile`
- **Token Storage:**
  - `access_token` → `connected_integrations.access_token`
  - `refresh_token` → `connected_integrations.refresh_token`
  - `expires_in` → calculate `token_expires_at = now() + expires_in seconds`
- **Refresh Strategy:** Before every API call, check if `token_expires_at <= now()`. If expired, POST to token URL with `grant_type=refresh_token` and `refresh_token`, then update the `connected_integrations` row with new tokens and expiry.

---

## Sync Strategy

**Initial Sync (first time user connects):**
- Backfill last 14 days of data
- Hit `/v1/recovery`, `/v1/sleep`, `/v1/cycle`, `/v1/workout` endpoints with `start` and `end` query params (ISO 8601 dates)
- For each endpoint, paginate if needed (Whoop typically returns all data in one response)
- Write all to `health_metrics` using the metric_name/category/unit/metadata shapes above
- Store `last_synced_cycle_id` in `oauth_sync_cursors` table with `cursor_type="cycle_id"`

**Recurring Sync (daily):**
- Fetch last 2 days of data (to catch retroactive Whoop score adjustments)
- Query each endpoint with appropriate date range
- Compare against `last_synced_cycle_id` to avoid duplicate writes
- Update `oauth_sync_cursors.cursor_value` with the latest cycle_id
