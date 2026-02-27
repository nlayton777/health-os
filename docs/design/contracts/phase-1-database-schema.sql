-- ============================================================
-- HealthOS Phase 1 — Database Schema Contract
-- ============================================================
-- This file is the source-of-truth for Phase 1 tables.
-- Both the Supabase workstream and the iOS workstream must
-- build against these exact table/column definitions.
--
-- The Supabase workstream creates the actual migrations from this.
-- The iOS workstream creates matching Swift models.
-- ============================================================

-- --------------------------------------------------------
-- profiles
-- --------------------------------------------------------
-- Extends Supabase auth.users with app-specific fields.
-- Created automatically on first sign-in via a database trigger.

CREATE TABLE public.profiles (
    id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name            TEXT,
    date_of_birth           DATE,
    height_cm               NUMERIC,
    weight_kg               NUMERIC,
    sex                     TEXT CHECK (sex IN ('male', 'female', 'other', 'prefer_not_to_say')),
    timezone                TEXT DEFAULT 'America/New_York',
    daily_time_budget_min   INTEGER DEFAULT 60,
    onboarding_completed    BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMPTZ DEFAULT now(),
    updated_at              TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
    ON public.profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Trigger: auto-create profile row on new auth.users signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, NEW.raw_user_meta_data ->> 'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- --------------------------------------------------------
-- connected_integrations
-- --------------------------------------------------------
-- Tracks which data sources a user has connected and their
-- OAuth tokens / sync state.

CREATE TABLE public.connected_integrations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider            TEXT NOT NULL CHECK (provider IN (
                            'apple_healthkit',
                            'apple_calendar',
                            'whoop',
                            'strava'
                        )),
    is_active           BOOLEAN DEFAULT TRUE,
    last_synced_at      TIMESTAMPTZ,
    access_token        TEXT,
    refresh_token       TEXT,
    token_expires_at    TIMESTAMPTZ,
    provider_user_id    TEXT,
    metadata            JSONB DEFAULT '{}'::JSONB,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now(),

    UNIQUE (user_id, provider)
);

ALTER TABLE public.connected_integrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own integrations"
    ON public.connected_integrations FOR ALL USING (auth.uid() = user_id);

-- --------------------------------------------------------
-- health_metrics
-- --------------------------------------------------------
-- Normalized health data from all sources. Every data point
-- from HealthKit, Whoop, Strava, etc. lands here.

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

ALTER TABLE public.health_metrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own metrics"
    ON public.health_metrics FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own metrics"
    ON public.health_metrics FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_health_metrics_user_date
    ON public.health_metrics (user_id, recorded_date DESC);

CREATE INDEX idx_health_metrics_user_category_date
    ON public.health_metrics (user_id, category, recorded_date DESC);
