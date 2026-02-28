-- ============================================================
-- HealthOS Phase 2 — Database Schema Contract
-- ============================================================
-- New tables and schema updates for goals and oauth integration.
-- ============================================================

-- --------------------------------------------------------
-- Table: goals
-- --------------------------------------------------------

CREATE TABLE public.goals (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category            TEXT NOT NULL CHECK (category IN (
                            'strength',
                            'endurance',
                            'body_composition',
                            'biomarker',
                            'recovery'
                        )),
    title               TEXT NOT NULL,
    description         TEXT,
    target_value        NUMERIC NOT NULL,
    target_unit         TEXT NOT NULL,
    current_value       NUMERIC,
    target_date         DATE,
    priority            TEXT NOT NULL DEFAULT 'secondary' CHECK (priority IN (
                            'primary',
                            'secondary',
                            'maintenance'
                        )),
    benchmark_test_type TEXT,
    testing_cadence_weeks INTEGER DEFAULT 8,
    status              TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
                            'active',
                            'achieved',
                            'paused',
                            'abandoned'
                        )),
    metadata            JSONB DEFAULT '{}'::JSONB,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own goals"
    ON public.goals FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own goals"
    ON public.goals FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own goals"
    ON public.goals FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own goals"
    ON public.goals FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX idx_goals_user_status
    ON public.goals (user_id, status);

CREATE INDEX idx_goals_user_category
    ON public.goals (user_id, category);

-- --------------------------------------------------------
-- Alter health_metrics category CHECK constraint
-- --------------------------------------------------------

ALTER TABLE public.health_metrics
    DROP CONSTRAINT health_metrics_category_check;

ALTER TABLE public.health_metrics
    ADD CONSTRAINT health_metrics_category_check
    CHECK (category IN (
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
        'calendar_event',
        'respiratory_rate',
        'skin_temperature',
        'training_load'
    ));

-- --------------------------------------------------------
-- Table: oauth_sync_cursors
-- --------------------------------------------------------

CREATE TABLE public.oauth_sync_cursors (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider            TEXT NOT NULL CHECK (provider IN ('whoop', 'strava')),
    cursor_type         TEXT NOT NULL,
    cursor_value        TEXT NOT NULL,
    updated_at          TIMESTAMPTZ DEFAULT now(),

    UNIQUE (user_id, provider, cursor_type)
);

ALTER TABLE public.oauth_sync_cursors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own sync cursors"
    ON public.oauth_sync_cursors FOR ALL USING (auth.uid() = user_id);
