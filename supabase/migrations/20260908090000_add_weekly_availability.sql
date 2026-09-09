-- Members can describe recurring rehearsal availability without granting calendar access.
ALTER TABLE public.band_members
  ADD COLUMN IF NOT EXISTS availability_mode text NOT NULL DEFAULT 'calendar'
    CHECK (availability_mode IN ('calendar', 'weekly')),
  ADD COLUMN IF NOT EXISTS availability_setup_complete boolean NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS public.weekly_availability_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES public.band_members(id) ON DELETE CASCADE,
  band_id uuid NOT NULL REFERENCES public.bands(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_minutes smallint NOT NULL CHECK (start_minutes BETWEEN 0 AND 1440),
  end_minutes smallint NOT NULL CHECK (end_minutes BETWEEN 0 AND 1440),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (start_minutes < end_minutes),
  UNIQUE (member_id, day_of_week)
);

ALTER TABLE public.weekly_availability_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view weekly availability" ON public.weekly_availability_rules;
CREATE POLICY "Members can view weekly availability"
  ON public.weekly_availability_rules FOR SELECT
  USING (is_band_member(band_id));

DROP POLICY IF EXISTS "Members can insert own weekly availability" ON public.weekly_availability_rules;
CREATE POLICY "Members can insert own weekly availability"
  ON public.weekly_availability_rules FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.band_members
    WHERE id = member_id AND band_id = weekly_availability_rules.band_id AND user_id = auth.uid()
  ));

DROP POLICY IF EXISTS "Members can delete own weekly availability" ON public.weekly_availability_rules;
CREATE POLICY "Members can delete own weekly availability"
  ON public.weekly_availability_rules FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM public.band_members
    WHERE id = member_id AND band_id = weekly_availability_rules.band_id AND user_id = auth.uid()
  ));

GRANT SELECT, INSERT, DELETE ON public.weekly_availability_rules TO authenticated;
GRANT UPDATE (availability_mode, availability_setup_complete, practice_window_start, practice_window_end)
  ON public.band_members TO authenticated;

CREATE INDEX IF NOT EXISTS idx_weekly_availability_rules_member
  ON public.weekly_availability_rules(member_id);
