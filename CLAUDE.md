# CornerWork

A phone-first tracking app for female combat-sport athletes: weight, menstrual cycle, food, training and recovery in one place. Built by Sharon (Muay Thai athlete, MSBA student) using herself as the first tester, with a small group of female fighters (Muay Thai, MMA, BJJ, boxing) to follow.

## The problem it solves

- Weight cuts meant juggling a spreadsheet, Cronometer and a food scale. Too much switching. Everything relevant belongs in one place.
- Hormonal fluctuation swings morning weight by up to ~2.3 kg (5 lb). Generic apps treat every weigh-in as truth.
- Research on women in combat sports is thin, so the tool learns from each athlete's own data (n-of-1), with research as guardrails only.

## Long-term goals

1. **Weigh-in forecast**: true weight trend with cycle-driven water stripped out, and a likely range for weigh-in day.
2. **Today's call**: push / train normally / back off, from cycle phase, sleep, subjective check-in, training load and how deep into a cut the athlete is. Always show the reasons.
3. **Guardrail**: flag signs of under-fueling (weight dropping fast while sleep, HRV and energy fall; cycles becoming irregular during a cut).

## Stack

- `index.html`: the whole app in one file (HTML, CSS, vanilla JavaScript). No build step, no framework.
- Supabase (project `wptlcuzhskngjhvmbqzx`): Postgres + email magic-link auth. Row Level Security on every table: each athlete only sees her own rows.
- Hosted on GitHub Pages: https://sharonhmin.github.io/cornerwork/
- `supabase/functions/estimate-food/index.ts`: Edge Function that calls Claude (Haiku) to estimate calories and protein from a food description or photo. Not deployed yet; needs an `ANTHROPIC_API_KEY` secret. The app falls back to manual entry when it's unavailable.

## Database (see `database/`)

Run in order in the Supabase SQL Editor: `schema.sql`, `schema_v2.sql`, `schema_v3.sql`. **New changes go in a new numbered file** (`schema_v4.sql`, ...) and must be run by hand in Supabase. Never edit a file that has already been run.

- `daily_checkins`: one row per athlete per day (unique `user_id, date`). Weight in kg, sleep hours, period flow, symptoms, six 1-5 ratings where **1 = bad, 5 = good for every scale**.
- `training_sessions`: one row per session. `category` (combat/run/strength/other), `sport`, `components` (text array), sparring intensity, run fields, `minutes`, `rpe` (0-10), `performance` (worse/expected/better: the answer key for readiness calls).
- `food_entries` and `food_favorites`: `source` records favorite / ai / manual.
- `camps`: one fight preparation each. Off-season (no camp) is a normal state.

## Decisions already made (don't undo without discussing)

- **Store kg and km in the database.** Convert for display based on the athlete's unit setting.
- **Log period flow, not cycle day.** Cycle day is calculated. Don't predict from a fixed cycle length: cycles vary with stress, nutrition and training.
- **Sessions are logged whole** (minutes x RPE = load) with component tags, not drill by drill.
- **Session parts share one internal list**; each sport shows its own labels (e.g. `pads` shows as "Mitts" in boxing, `sparring` as "Rolling" in BJJ).
- **Food logging has three ways in**: one-tap favorites, AI estimate (editable), manual numbers. Consistency matters more than precision: later, logged intake plus the weight trend will estimate real maintenance.
- **Daily targets** (calories, protein) are stored in localStorage on the phone.
- **Design**: Today home screen, bottom tab bar (Today, Trends, History, Camp), logging in slide-up sheets. Palette "fig + olive": fig `#5A2A43` for structure, deep olive `#5E6B2E` for quiet data, bright olive `#B7C36A` for progress and the main button, oat `#F4F0EA` background. Dark mode follows the phone. Font: Helvetica Neue / Helvetica. Avoid pastel "shrink it and pink it" styling.

## How Sharon wants code written

- She is new to JavaScript. **Keep code as simple as possible**, and explain the goal of each section in comments, in plain language. Analogies welcome.
- Prefer small, targeted edits over rewrites.
- Escape any user-typed text before putting it in HTML (`escapeHtml`).
- Wrap localStorage reads/writes in try/catch.
- Metric first, imperial second.

## Before saying a change is done

1. Check the JavaScript parses (e.g. extract the last `<script>` block and run `node --check`).
2. If possible, run it in a simulated browser (jsdom) with a fake Supabase client and click through the changed flows.
3. If the change needs a database update, write the new `database/schema_vN.sql` and tell Sharon to run it in Supabase **before** the app change goes live.
4. Commit with a clear message, e.g. `v5: add readiness card`.

## Data so far

- Sharon's Aug 27 - Sep 28, 2026 cut is in an old spreadsheet (`fight_weight_tracker-2.xlsx`, not in the repo). One logged cycle: 27 days. Detrended weight was ~0.27 kg above trend in late luteal (days 21-27) and ~0.24 kg below in the follicular phase (days 6-13). One cycle only: a hint, not a pattern.
- Planned: import that spreadsheet as Camp 1; import the Garmin export (sleep, HRV, resting heart rate) once it arrives.

## Next on the list

- Use v4 daily for 1-2 weeks; Sharon is keeping a list of annoyances to drive v5.
- Import the Aug-Sep cut as Camp 1.
- Deploy the AI food estimate (needs an Anthropic API key).
- Garmin data import.
- Invite 2-3 testers with a short consent note: what's collected, who sees it, how to delete it. Meal descriptions go to the AI provider when AI estimates are on.
- Trends: cycle-phase view once there are 2-3 logged cycles.
