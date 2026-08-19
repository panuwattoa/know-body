-- Target date + cached AI-generated workout program.
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS target_date DATE,
    ADD COLUMN IF NOT EXISTS program     JSONB;
