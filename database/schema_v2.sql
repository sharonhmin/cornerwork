-- =====================================================================
-- CORNERWORK v2: database update
-- GOAL: add what the new app needs, without touching your existing data:
--   1. camps            -> one row per fight preparation (the setup stage)
--   2. food_entries     -> every food you log
--   3. food_favorites   -> your saved one-tap meals
--   4. new columns on training_sessions for multi-sport, running, strength
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this whole file > Run.
-- Run it ONCE, after schema.sql (which you already ran).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. CAMPS
-- One fight preparation. An athlete can have many camps over time,
-- which lets us compare cuts later. The app uses the most recent one.
-- ---------------------------------------------------------------------
create table camps (
  id               bigint generated always as identity primary key,
  user_id          uuid not null default auth.uid() references auth.users(id) on delete cascade,

  name             text,                        -- e.g. "Spring fight 2027" (optional)
  sport            text not null check (sport in ('muay_thai', 'boxing', 'mma', 'bjj')),

  start_date       date not null,
  start_weight_kg  numeric(5,2),
  goal_weight_kg   numeric(5,2),               -- the weight class limit

  weigh_in_date    date,
  -- Day-before weigh-ins allow more recovery time than same-day ones,
  -- so the forecast treats them differently.
  weigh_in_type    text check (weigh_in_type in ('day_before', 'same_day')),
  fight_date       date,

  created_at       timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- 2. FOOD ENTRIES
-- One row per food logged. Daily totals are added up by the app.
-- "source" records HOW it was logged, so later we can check whether
-- AI estimates and manual entries behave differently in the analysis.
-- ---------------------------------------------------------------------
create table food_entries (
  id           bigint generated always as identity primary key,
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date         date not null,
  meal         text check (meal in ('breakfast', 'lunch', 'dinner', 'snack')),
  description  text,
  calories     integer check (calories between 0 and 10000),
  protein_g    numeric(6,1) check (protein_g between 0 and 1000),
  source       text check (source in ('favorite', 'ai', 'manual')),
  created_at   timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- 3. FOOD FAVORITES
-- Saved meals for one-tap logging. Fighters in camp eat the same
-- few meals on repeat, so this should cover most of the day.
-- ---------------------------------------------------------------------
create table food_favorites (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null,
  calories    integer check (calories between 0 and 10000),
  protein_g   numeric(6,1) check (protein_g between 0 and 1000),
  created_at  timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- 4. TRAINING SESSIONS: new columns
-- The old single "session_type" is replaced by:
--   category    -> combat / run / strength / other
--   sport       -> which combat sport (combat sessions only)
--   components  -> the parts of a combat session, multi-select
--                  e.g. {warmup,shadow,bag,pads,technique,clinch}
-- Note: this removes session_type. Only test entries used it.
-- ---------------------------------------------------------------------
alter table training_sessions drop column if exists session_type;

alter table training_sessions
  add column category            text check (category in ('combat', 'run', 'strength', 'other')),
  add column sport               text check (sport in ('muay_thai', 'boxing', 'mma', 'bjj')),
  add column components          text[] default '{}',
  -- Hard sparring takes more out of you than light sparring
  add column sparring_intensity  text check (sparring_intensity in ('light', 'hard')),
  add column time_of_day         text check (time_of_day in ('am', 'pm')),
  -- Running only
  add column run_type            text check (run_type in ('easy', 'tempo', 'intervals', 'long')),
  add column distance_km         numeric(5,2) check (distance_km between 0 and 200),
  -- Strength only
  add column strength_focus      text check (strength_focus in ('lower', 'upper', 'full'));


-- ---------------------------------------------------------------------
-- 5. SECURITY: same locked-drawer rule as before
-- "for all" covers read, add, edit and delete in one rule.
-- ---------------------------------------------------------------------
alter table camps          enable row level security;
alter table food_entries   enable row level security;
alter table food_favorites enable row level security;

create policy "own camps"     on camps          for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own food"      on food_entries   for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own favorites" on food_favorites for all using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- ---------------------------------------------------------------------
-- 6. ACCESS: let signed-in users reach these tables through the app.
-- The security rules above still decide WHICH rows each person sees.
-- Analogy: this hands out the key to the building; the rules above
-- decide which drawer that key opens.
-- ---------------------------------------------------------------------
grant select, insert, update, delete on
  camps, food_entries, food_favorites, daily_checkins, training_sessions
to authenticated;
