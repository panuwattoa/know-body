-- Track muscle mass alongside weight (optional per weigh-in).
ALTER TABLE weigh_ins ADD COLUMN IF NOT EXISTS muscle_kg NUMERIC(5,1);
