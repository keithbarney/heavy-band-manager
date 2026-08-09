
-- Tables first
CREATE TABLE bands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  creator_id uuid NOT NULL REFERENCES auth.users(id),
  leader_id uuid NOT NULL REFERENCES auth.users(id),
  default_practice_location text DEFAULT '',
  invite_code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE band_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  band_id uuid NOT NULL REFERENCES bands(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  name text NOT NULL,
  instrument text DEFAULT '',
  color text NOT NULL DEFAULT '#888',
  joined_at timestamptz DEFAULT now(),
  UNIQUE(band_id, user_id)
);

CREATE TABLE availability_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES band_members(id) ON DELETE CASCADE,
  band_id uuid NOT NULL REFERENCES bands(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_minutes smallint NOT NULL CHECK (start_minutes BETWEEN 0 AND 1440),
  end_minutes smallint NOT NULL CHECK (end_minutes BETWEEN 0 AND 1440),
  confirmed boolean DEFAULT true
);

CREATE TABLE scheduled_practices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  band_id uuid NOT NULL REFERENCES bands(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_minutes smallint NOT NULL CHECK (start_minutes BETWEEN 0 AND 1440),
  end_minutes smallint NOT NULL CHECK (end_minutes BETWEEN 0 AND 1440),
  location text DEFAULT '',
  scheduled_by uuid NOT NULL REFERENCES auth.users(id),
  scheduled_at timestamptz DEFAULT now()
);

-- Helper functions
CREATE OR REPLACE FUNCTION is_band_member(p_band_id uuid) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM band_members WHERE band_id = p_band_id AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_band_leader(p_band_id uuid) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM bands WHERE id = p_band_id AND leader_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- RLS
ALTER TABLE bands ENABLE ROW LEVEL SECURITY;
ALTER TABLE band_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE availability_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_practices ENABLE ROW LEVEL SECURITY;

-- Bands policies
CREATE POLICY "Authenticated can create bands" ON bands FOR INSERT TO authenticated WITH CHECK (creator_id = auth.uid());
CREATE POLICY "Authenticated can view bands" ON bands FOR SELECT TO authenticated USING (true);
CREATE POLICY "Leader can update band" ON bands FOR UPDATE USING (leader_id = auth.uid());

-- Band Members policies
CREATE POLICY "Members can view band members" ON band_members FOR SELECT USING (is_band_member(band_id));
CREATE POLICY "Users can join via band membership" ON band_members FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Members can update own membership" ON band_members FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Leader can remove members" ON band_members FOR DELETE USING (is_band_leader(band_id));

-- Availability policies
CREATE POLICY "Members can view band availability" ON availability_slots FOR SELECT USING (is_band_member(band_id));
CREATE POLICY "Members can insert own slots" ON availability_slots FOR INSERT WITH CHECK (member_id IN (SELECT id FROM band_members WHERE user_id = auth.uid()));
CREATE POLICY "Members can update own slots" ON availability_slots FOR UPDATE USING (member_id IN (SELECT id FROM band_members WHERE user_id = auth.uid()));
CREATE POLICY "Members can delete own slots" ON availability_slots FOR DELETE USING (member_id IN (SELECT id FROM band_members WHERE user_id = auth.uid()));

-- Practice policies
CREATE POLICY "Members can view practices" ON scheduled_practices FOR SELECT USING (is_band_member(band_id));
CREATE POLICY "Leader can schedule practices" ON scheduled_practices FOR INSERT WITH CHECK (is_band_leader(band_id));
CREATE POLICY "Leader can update practices" ON scheduled_practices FOR UPDATE USING (is_band_leader(band_id));
CREATE POLICY "Leader can cancel practices" ON scheduled_practices FOR DELETE USING (is_band_leader(band_id));

-- Indexes
CREATE INDEX idx_band_members_band_id ON band_members(band_id);
CREATE INDEX idx_band_members_user_id ON band_members(user_id);
CREATE INDEX idx_availability_slots_band_id ON availability_slots(band_id);
CREATE INDEX idx_availability_slots_member_id ON availability_slots(member_id);
CREATE INDEX idx_scheduled_practices_band_id ON scheduled_practices(band_id);
CREATE INDEX idx_bands_invite_code ON bands(invite_code);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE availability_slots;
ALTER PUBLICATION supabase_realtime ADD TABLE scheduled_practices;
;
