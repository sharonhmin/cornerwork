-- =====================================================================
-- CORNERWORK1.0: database setup
-- GOAL: create two tables (morning check-ins and training sessions)
-- and lock them so each athlete can only ever see and edit HER OWN rows.
--
-- HOW TO USE: in Supabase, open "SQL Editor", paste this whole file,
-- and click "Run". You only do this once.
-- =====================================================================


-- ---------------------------------------------------------------------
-- TABLE 1: daily_checkins
-- One row per athlete per day. Filled in each morning.
-- All 1-5 ratings point the SAME way: 1 = bad, 5 = good.
-- (Mixing directions confuses people when they tap fast in the morning.)
-- ---------------------------------------------------------------------
create table daily_checkins (
  id            bigint generated always as identity primary key,

  -- Who this row belongs to. Filled in automatically from the login.
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,

  -- Which day this check-in is for.
  date          date not null,

  -- Morning weight, always stored in kilograms.
  -- The app converts from lb if the athlete enters lb.
  weight_kg     numeric(5,2),

  -- Period flow today. We work out cycle day from this later,
  -- so athletes never have to count days themselves.
  period_flow   text check (period_flow in ('none', 'spotting', 'light', 'medium', 'heavy')),

  -- Cycle symptoms, stored as a list, e.g. {bloating,cramps}
  symptoms      text[] default '{}',

  -- Wellness ratings, 1 = bad, 5 = good
  sleep_quality smallint check (sleep_quality between 1 and 5),
  energy        smallint check (energy        between 1 and 5),
  soreness      smallint check (soreness      between 1 and 5),  -- 5 = not sore at all
  stress        smallint check (stress        between 1 and 5),  -- 5 = very relaxed
  mood          smallint check (mood          between 1 and 5),
  motivation    smallint check (motivation    between 1 and 5),  -- "how much do you want to train?"

  notes         text,
  created_at    timestamptz not null default now(),

  -- An athlete can only have one check-in per day.
  -- Saving again on the same day updates the existing row.
  unique (user_id, date)
);


-- ---------------------------------------------------------------------
-- TABLE 2: training_sessions
-- One row per training session. An athlete can log several per day.
-- ---------------------------------------------------------------------
create table training_sessions (
  id            bigint generated always as identity primary key,
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date          date not null,

  session_type  text check (session_type in ('sparring', 'pads', 'technical', 'conditioning', 'strength', 'other')),
  minutes       smallint check (minutes between 1 and 600),

  -- How hard it felt, 0 = rest, 10 = maximal. Rated ~30 min after training.
  -- Training load = rpe x minutes (we calculate that later).
  rpe           smallint check (rpe between 0 and 10),

  -- The "answer key": how the session went compared to what she expected.
  performance   text check (performance in ('worse', 'expected', 'better')),

  notes         text,
  created_at    timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- SECURITY: Row Level Security (RLS)
-- GOAL: the database itself refuses to show anyone else's rows.
-- Even if someone has the app's public key, they only get their own data.
-- Analogy: every athlete gets her own locked drawer in the filing cabinet.
-- ---------------------------------------------------------------------
alter table daily_checkins    enable row level security;
alter table training_sessions enable row level security;

-- Each rule says: "you may do X only on rows where user_id is YOU".
create policy "own checkins: read"   on daily_checkins for select using (auth.uid() = user_id);
create policy "own checkins: add"    on daily_checkins for insert with check (auth.uid() = user_id);
create policy "own checkins: edit"   on daily_checkins for update using (auth.uid() = user_id);
create policy "own checkins: delete" on daily_checkins for delete using (auth.uid() = user_id);

create policy "own sessions: read"   on training_sessions for select using (auth.uid() = user_id);
create policy "own sessions: add"    on training_sessions for insert with check (auth.uid() = user_id);
create policy "own sessions: edit"   on training_sessions for update using (auth.uid() = user_id);
create policy "own sessions: delete" on training_sessions for delete using (auth.uid() = user_id);
