-- =====================================================================
-- CORNERWORK v3: database update
-- GOAL: add hours slept to the morning check-in.
-- Stored as decimal hours, e.g. 7 h 30 min = 7.5
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste > Run. Once.
-- =====================================================================

alter table daily_checkins
  add column sleep_hours numeric(4,2) check (sleep_hours between 0 and 24);
