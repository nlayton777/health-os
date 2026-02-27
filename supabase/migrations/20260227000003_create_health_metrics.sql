-- ============================================================
-- Migration: 20260227000003_create_health_metrics
-- ============================================================
-- Creates the public.health_metrics table, which stores
-- normalized health data from all sources (HealthKit, Whoop,
-- Strava, Apple Calendar, and manual entries).
-- Indexes are tuned for the most common query patterns:
--   - user + date range (daily coaching)
--   - user + category + date range (category-specific queries)
-- ============================================================

-- --------------------------------------------------------
-- Table: health_metrics
-- --------------------------------------------------------

CREATE TABLE public.health_metrics (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    source          TEXT NOT NULL CHECK (source IN (
                        'apple_healthkit',
                        'apple_calendar',
                        'whoop',
                        'strava',
                        'manual'
                    )),
    category        TEXT NOT NULL CHECK (category IN (
                        'sleep',
                        'workout',
                        'heart_rate',
                        'hrv',
                        'steps',
                        'weight',
                        'body_fat',
                        'active_energy',
                        'strain',
                        'recovery',
                        'calendar_event'
                    )),
    metric_name     TEXT NOT NULL,
    numeric_value   NUMERIC,
    text_value      TEXT,
    unit            TEXT,
    recorded_at     TIMESTAMPTZ NOT NULL,
    recorded_date   DATE NOT NULL,
    metadata        JSONB DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- --------------------------------------------------------
-- Row Level Security
-- --------------------------------------------------------

ALTER TABLE public.health_metrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own metrics"
    ON public.health_metrics FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own metrics"
    ON public.health_metrics FOR INSERT WITH CHECK (auth.uid() = user_id);

-- --------------------------------------------------------
-- Indexes
-- --------------------------------------------------------

-- Primary query pattern: fetch all metrics for a user within a date range
CREATE INDEX idx_health_metrics_user_date
    ON public.health_metrics (user_id, recorded_date DESC);

-- Secondary query pattern: fetch a specific category for a user within a date range
CREATE INDEX idx_health_metrics_user_category_date
    ON public.health_metrics (user_id, category, recorded_date DESC);
