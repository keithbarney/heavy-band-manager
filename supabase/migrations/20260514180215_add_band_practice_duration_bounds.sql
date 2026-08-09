ALTER TABLE public.bands
  ADD COLUMN min_practice_minutes smallint NOT NULL DEFAULT 60
    CHECK (min_practice_minutes >= 0 AND min_practice_minutes <= 1440),
  ADD COLUMN max_practice_minutes smallint NOT NULL DEFAULT 240
    CHECK (max_practice_minutes >= 0 AND max_practice_minutes <= 1440),
  ADD CONSTRAINT bands_practice_duration_range CHECK (max_practice_minutes >= min_practice_minutes);;
