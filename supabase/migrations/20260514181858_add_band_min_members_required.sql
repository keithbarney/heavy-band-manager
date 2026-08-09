ALTER TABLE public.bands
  ADD COLUMN min_members_required smallint NOT NULL DEFAULT 2
    CHECK (min_members_required >= 1);;
