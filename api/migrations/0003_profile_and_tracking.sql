-- Body metrics for calorie calculation + weight tracking.
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS weight_kg      NUMERIC(5,1),
    ADD COLUMN IF NOT EXISTS activity_level TEXT NOT NULL DEFAULT 'light',    -- sedentary|light|moderate|active|very
    ADD COLUMN IF NOT EXISTS goal_dir       TEXT NOT NULL DEFAULT 'maintain'; -- lose|maintain|gain

-- Weigh-ins power the Trend chart.
CREATE TABLE IF NOT EXISTS weigh_ins (
    id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    weight_kg NUMERIC(5,1) NOT NULL,
    at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS weigh_ins_user ON weigh_ins (user_id, at DESC);
