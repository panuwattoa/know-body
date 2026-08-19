-- KnowBody initial schema.
-- Postgres 15+. Enable extensions used for Thai-food fuzzy matching.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ─────────────────────────────────────────────────────────────
-- Users & profile
-- The canonical identity lives in Supabase auth.users; we mirror the id here.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE users (
    id           UUID PRIMARY KEY,                     -- == Supabase auth user id (JWT sub)
    email        TEXT,
    display_name TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TYPE goal_kind AS ENUM ('eat_better', 'move_more', 'keep_pet_happy');

CREATE TABLE profiles (
    user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    goal            goal_kind   NOT NULL DEFAULT 'eat_better',
    locale          TEXT        NOT NULL DEFAULT 'th',      -- 'th' | 'en'
    sex             TEXT,                                    -- 'm' | 'f' | null
    birth_year      INT,
    height_cm       NUMERIC(5,1),
    daily_kcal_goal INT         NOT NULL DEFAULT 2000,
    protein_g_goal  INT         NOT NULL DEFAULT 120,
    carbs_g_goal    INT         NOT NULL DEFAULT 220,
    fat_g_goal      INT         NOT NULL DEFAULT 60,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────
-- Thai food composition reference (seeded; Plus users can extend via AI)
-- Values are per 100 g edible portion.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE thai_foods (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_th     TEXT NOT NULL,
    name_en     TEXT NOT NULL,
    aliases     TEXT[] NOT NULL DEFAULT '{}',
    kcal_100g   NUMERIC(6,1) NOT NULL,
    protein_100g NUMERIC(6,1) NOT NULL,
    carbs_100g  NUMERIC(6,1) NOT NULL,
    fat_100g    NUMERIC(6,1) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX thai_foods_name_th_trgm ON thai_foods USING gin (name_th gin_trgm_ops);
CREATE INDEX thai_foods_name_en_trgm ON thai_foods USING gin (name_en gin_trgm_ops);

-- ─────────────────────────────────────────────────────────────
-- Meals & their items
-- ─────────────────────────────────────────────────────────────
CREATE TYPE meal_slot AS ENUM ('breakfast', 'lunch', 'dinner', 'snack');
CREATE TYPE item_source AS ENUM ('thai_db', 'ai', 'manual');

CREATE TABLE meals (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    slot        meal_slot NOT NULL DEFAULT 'snack',
    title       TEXT NOT NULL DEFAULT '',
    photo_key   TEXT,                          -- R2 object key (nullable)
    kcal        INT  NOT NULL DEFAULT 0,        -- denormalised sum of items
    protein_g   NUMERIC(6,1) NOT NULL DEFAULT 0,
    carbs_g     NUMERIC(6,1) NOT NULL DEFAULT 0,
    fat_g       NUMERIC(6,1) NOT NULL DEFAULT 0,
    eaten_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX meals_user_day ON meals (user_id, eaten_at DESC);

CREATE TABLE meal_items (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meal_id      UUID NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
    thai_food_id UUID REFERENCES thai_foods(id),
    name         TEXT NOT NULL,
    grams        NUMERIC(7,1) NOT NULL,
    kcal         INT NOT NULL,
    protein_g    NUMERIC(6,1) NOT NULL DEFAULT 0,
    carbs_g      NUMERIC(6,1) NOT NULL DEFAULT 0,
    fat_g        NUMERIC(6,1) NOT NULL DEFAULT 0,
    source       item_source NOT NULL DEFAULT 'ai',
    confidence   REAL,                          -- 0..1 from the vision model
    position     INT NOT NULL DEFAULT 0
);
CREATE INDEX meal_items_meal ON meal_items (meal_id);

-- ─────────────────────────────────────────────────────────────
-- Workouts
-- ─────────────────────────────────────────────────────────────
CREATE TYPE workout_status AS ENUM ('planned', 'active', 'done', 'skipped');

CREATE TABLE workouts (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    status      workout_status NOT NULL DEFAULT 'planned',
    kcal_burned INT NOT NULL DEFAULT 0,
    duration_s  INT NOT NULL DEFAULT 0,
    started_at  TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX workouts_user ON workouts (user_id, created_at DESC);

CREATE TABLE workout_sets (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workout_id  UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
    exercise    TEXT NOT NULL,
    target_reps INT,
    target_secs INT,
    position    INT NOT NULL DEFAULT 0,
    done        BOOLEAN NOT NULL DEFAULT false
);
CREATE INDEX workout_sets_workout ON workout_sets (workout_id);

-- ─────────────────────────────────────────────────────────────
-- Pet (Mochi), streaks
-- ─────────────────────────────────────────────────────────────
CREATE TABLE pets (
    user_id    UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    name       TEXT NOT NULL DEFAULT 'Mochi',
    level      INT  NOT NULL DEFAULT 1,
    xp         INT  NOT NULL DEFAULT 0,          -- xp within current level
    mood       TEXT NOT NULL DEFAULT 'content',  -- content | happy | sleepy | cheering
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE streaks (
    user_id      UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    count        INT NOT NULL DEFAULT 0,
    freezes_left INT NOT NULL DEFAULT 2,
    last_active  DATE
);

-- ─────────────────────────────────────────────────────────────
-- Body scans (private-by-default; only metadata + optional R2 keys)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE body_scans (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    weight_kg     NUMERIC(5,1),
    bf_pct        NUMERIC(4,1),      -- midpoint estimate
    bf_low        NUMERIC(4,1),
    bf_high       NUMERIC(4,1),
    front_key     TEXT,              -- R2 key, null if kept on-device
    side_key      TEXT,
    notes         JSONB NOT NULL DEFAULT '[]',  -- ["shoulders +1.4cm", ...]
    scanned_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX body_scans_user ON body_scans (user_id, scanned_at DESC);

-- ─────────────────────────────────────────────────────────────
-- Soft social
-- ─────────────────────────────────────────────────────────────
CREATE TABLE friendships (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status     TEXT NOT NULL DEFAULT 'pending',  -- pending | accepted
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, friend_id)
);

CREATE TABLE nudges (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind       TEXT NOT NULL DEFAULT 'cheer',    -- cheer | nudge
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────
-- Subscriptions (mirrored from RevenueCat webhooks)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE subscriptions (
    user_id    UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    tier       TEXT NOT NULL DEFAULT 'free',     -- free | plus | coach
    source     TEXT,                              -- app_store | play | promo
    expires_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Monthly AI usage counter for free-tier enforcement.
CREATE TABLE ai_usage (
    user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    yyyymm    INT  NOT NULL,           -- e.g. 202608
    food_logs INT  NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, yyyymm)
);
