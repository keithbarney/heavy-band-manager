-- Add practice window to band_members
ALTER TABLE band_members
  ADD COLUMN practice_window_start smallint DEFAULT 960,  -- 4:00 PM
  ADD COLUMN practice_window_end smallint DEFAULT 1380;   -- 11:00 PM

-- Add calendar event tracking to scheduled_practices
ALTER TABLE scheduled_practices
  ADD COLUMN calendar_event_id text;;
