-- ============================================================
-- Migration: 20260227000001_create_profiles
-- ============================================================
-- Creates the public.profiles table, which extends Supabase
-- auth.users with app-specific fields.
-- A database trigger auto-creates a profile row on every new
-- auth signup so the app never has to do it manually.
-- ============================================================

-- --------------------------------------------------------
-- Table: profiles
-- --------------------------------------------------------

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

-- --------------------------------------------------------
-- Row Level Security
-- --------------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
    ON public.profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- --------------------------------------------------------
-- Trigger: auto-create profile on new user signup
-- --------------------------------------------------------

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
