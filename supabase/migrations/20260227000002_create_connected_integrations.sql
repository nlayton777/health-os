-- ============================================================
-- Migration: 20260227000002_create_connected_integrations
-- ============================================================
-- Creates the public.connected_integrations table, which tracks
-- which data sources each user has connected and stores their
-- OAuth tokens and sync state.
-- ============================================================

-- --------------------------------------------------------
-- Table: connected_integrations
-- --------------------------------------------------------

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

-- --------------------------------------------------------
-- Row Level Security
-- --------------------------------------------------------

ALTER TABLE public.connected_integrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own integrations"
    ON public.connected_integrations FOR ALL USING (auth.uid() = user_id);
