# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Single-file Neverlose CS2 Lua script (`resolverv2_35544.lua`, ~2890 lines, author seltonmt01) — custom anti-aim resolver "Sel01-Solver" with Sel01-Roast chat-spam + loading screen + in-game HUD/ESP overlay. No build system, no tests, no package manager. Runs inside Neverlose CS2 client via their Lua sandbox.

**Current version: 7.7** — bumped via `local SEL01_VERSION = "7.7"` constant at top of file. Displayed in load-banner, UI label, HUD corner. Bump this string + file-header comment when shipping changes. User reads ANY of the 3 display points to confirm fresh copy loaded vs stale NL copy.

Full architecture + bug-history + UI doc lives in `README.md`. NL docs reference saved in `~/.claude/projects/.../memory/reference_nl_docs.md` — always consult `https://docs-csgo.neverlose.cc/readme.md?ask=<keywords>` before guessing NL API names.

Working copy: `C:\Users\Seltonmt\Desktop\sazz\aron\ownlua\resolverv2_35544.lua`
NL load copy (user copies manually): `E:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive\nl\scripts\Sel01-Solver_59853.lua`
Persistent learning data: `nl/Sel01-Solver/learned.lua` (auto-created via `files.write`)

## Verify changes

```powershell
luac -p resolverv2_35544.lua
```

`luac` from scoop (`C:\Users\Seltonmt\scoop\apps\lua\current\bin\luac.exe`). Must exit clean. No test infrastructure — runtime errors only surface when user reloads script in NL and reports.

## Critical patterns (these have all bitten before)

**Forward-references kill closures.** NL UI callbacks (button bodies, set_callback bodies, ragebot_target, render, paint) capture upvalues at **parse-time**. If a referenced local is declared LATER in file, the closure resolves to global → nil at call time. **The forward-decl block must come BEFORE any UI element that references it via callback.** Currently early-decl'd at top (line ~135): `SteamMemory`, `LearnedModel`, `mode_stats`, `PlayerState`, `tick_cache`, `NormalizeAngle`, `mode_stats_update/dump`, `confidence`, `session_stats`, `get_steam_mem`, `steam_mem_on_hit/miss`, `learning_cleanup`. Pattern: `local X = {}` at top, then `setmetatable(X, ...)` later — never `local X = setmetatable({}, ...)` later (that creates a NEW local shadowing).

**Combo `:get()` returns STRING, not index.** Use string compares (`== "Aggressive"`) or the `combo_str()` / `mode_str()` / `baim_hb_id()` helpers. Never do arithmetic on combo value.

**Slider 5th arg is NOT step.** `:slider(name, min, max, default)` only. Passing a 5th arg makes display value multiply weirdly.

**Neverlose sandbox lacks `os`.** No `os.time()`. Use `globals.realtime` + `globals.tickcount`.

**Per-tick functions mutate state → oscillation.** `pick_bruteforce_angle` runs 64×/sec. Three caching layers prevent state-thrash:
- `bf_cached_missed/angle/mode/eye` — BF only recomputes when `missed` count changes OR eye drifts >20°
- `fs_cached_time/eye/angle/mode` — first-shot result held 150ms unless eye drifts >20° AND validated `|angle-eye| >= 5` (don't cache useless goal=eye results)
- `guess_cached_side/miss` — fallback-side picked once per engagement, not per resolve
AA-classify uses hysteresis: require 3 consecutive matches before committing `aa_type` change.

**`aim_ack` reads stale `s.last_resolved`.** By the time the ack fires, several resolves have run after the shot was launched. Use `shot_snapshots[]` ring-buffer pushed by `events.aim_fire` hook. In aim_ack, pick snapshot closest to `event.tick`.

**API methods that may not exist** (NL version variance): `ctx:override_multipoint`, `ctx:override_hitbox`, `ctx:override_hitchance`, `ctx:override_min_damage`, `ctx:override_hitboxes` (plural), `entity.get_lerp_time`, `p:get_steam_id`, `events.aim_fire`, `events.ragebot_fire`, `events.ragebot_target`, `render.world_to_screen`, `render.rect_outline`, `lp:get_weapon().m_flNextPrimaryAttack`, `lp.m_fFlags`, `p.m_iAccountID`. Always `pcall(function() ... end)`. Conditional method-check: `obj.method and obj:method()` (not `obj:method`).

**`m_flGoalFeetYaw = eye_yaw` is BROKEN.** All branches now validate `|result - eye_yaw| >= 5` and fall through to `*-Guess` modes with ±29° offset.

**HIT vs MISS detection inverted + NON_RESOLVER_MISS skip.** NL `aim_ack` event.state values: `hit`, `damaged`, `correction`, `spread`, `prediction`, `prediction_error`, `unregistered`, `unregistered shot`, `death`, `backtrack`, `damage rejection`, `player death`. Default to MISS, only count as HIT for explicit `HIT_STATES`. Reasons in `NON_RESOLVER_MISS` table (`death`, `damage rejection`, `player_death`, `unregistered shot`) early-return — they aren't resolver faults.

**Hook-overriding pattern for cross-system updates.** When a function needs side-effects in unrelated code (e.g. `mode_stats_update` should push to HUD `last_combat_event`), wrap: `local _orig = X; X = function(...) _orig(...); side_effect(...) end`.

**Throttled draw needs cached compute.** `events.render` fires every frame. Throttle COMPUTE (refresh `hud_cache` table every N ms), but DRAW the cached values every frame. Otherwise screen-clear between draws → flicker.

**Steam-ID has 6 fallback patterns** (V7.7): `get_steam_id`, `get_steamid`, `m_steamid`, `entity.get_steam_id`, `m_iAccountID`/`get_account_id`, name-hash, userid+name combo. Each pcall-wrapped. Failure logged once. Persistent learning gracefully degrades if all fail.

## File layout (resolverv2_35544.lua, ~2890 lines)

| Lines | Purpose |
|---|---|
| 1–20 | Version constant `SEL01_VERSION`, requires, `cs_log` helpers + raw refs |
| 22–115 | Loading screen (FFI URL download), sidebar gradient |
| 117–145 | **EARLY FORWARD-DECL BLOCK** (V7.3 fix) — all locals used by UI callbacks |
| 147–280 | UI: tab `Sel01-Solver`, 10 groups, 5 preset buttons, 4 Smart Strategy combos, 17 individual experimental toggles |
| 283–340 | Logging group + copy-button (V7.5 enhanced dump with diagnostics + tips) |
| 345–490 | V5 mode-stats audit + V5 confidence (passive-weighted V7.7) + V6 target intel |
| 495–620 | V4 persistent learning (load/save/update/lookup, serialize, cleanup) + V4 prediction helpers + V7.7 6-pattern sid fallback |
| 625–745 | `apply_preset()` — 5 presets, all sync Smart Strategy combos |
| 750–820 | FFI cdef `AnimatingStateInfo`, `GetAnimState`, `GetMaxDesync` |
| 825–880 | math helpers, `RebuildServerYaw` (pcall-wrapped) |
| 885–980 | `PlayerState` setmetatable on forward-decl'd table — all V3-V7 fields |
| 985–1310 | `events.aim_ack` — snapshot-based learning, per-side EMA, streak, persistent-learn, mode-stats, adaptive-predict, non-resolver-miss skip |
| 1315–1500 | `update_jitter`, `classify_aa` + hysteresis, steam-memory functions, learning-cleanup |
| 1505–1750 | `_pick_first_shot_impl` (V7.7 known-player fast-path → `<mode>-Recall`) + FS-cache wrapper, `pick_bruteforce_angle` + BF-cache, `get_mode_preset` |
| 1755–1920 | `resolve_player`, anim-cache, tick-cache refresh, FOV/distance cull, learning-boot, hysteresis commit, V4 extrapolation + V7 lock-target boost + V7.1 passive learning read |
| 1925–2200 | events: `weapon_fire` (lby snap), `aim_fire` (shot snapshot), `ragebot_target` (9-stage override stack), `createmove` |
| 2205–2470 | ESP overlay + HUD-corner overlay (events.render, throttled compute / per-frame draw) + learning-progress indicators (`👁/·/★/🔒`) |
| 2475–2725 | Sel01-Roast chat spam + `player_death` |
| 2730–2890 | shutdown handler (unsets ALL events, saves learning), load banner with version + diagnostics, `learning_load()` + `learning_cleanup()` call |

## Resolver mode flow (one resolve call)

`can_resolve` → dormancy reset (+ steam-mem boot + V4 learning-model boot + V6 best_modes boot) → FOV/distance cull → `GetAnimStateCached` → air-branch (server-yaw + measured) → `update_jitter` (yaw_rate) → AA-classify with hysteresis (3-tick commit) → V4 extrapolate `eye_yaw` (adaptive per-player, peek-reduced, locked-target +1) → `pick_first_shot_angle` (V7.7 known-player fast-path / FS-cached, validated `>= 5° offset`) or `pick_bruteforce_angle` (BF-cached, eye-drift invalidate) → store `last_resolved`+`last_eye_yaw` + push to `recent_resolved[]` → V7.1 passive-learn from server's pre-override `m_flGoalFeetYaw` → apply `goal_feet_yaw`.

Mode-name suffixes: `+Pred` (extrapolated), `-DefInv` (defensive-AA inverted), `-Recall` (V7.7 known-player fast-path).

## ragebot_target override order (top to bottom)

1. **V5 shot-cooldown skip** (sniper reload, hc=99)
2. **V6.9 close-priority tiered** (4 tiers: point-blank/close/dive-in/jump-peek, hc 5-20) — Aggressive/sniper only
3. **V6 air-block** (sniper airborne + long range, hc=99, early-return)
4. **V3+V5+V6 cancel-low-confidence intel-aware** (known + mode_match + samples≥3 = TRUST skip; sniper peek-stop = skip; thresholds: sniper sd>50/conf<10, others 25/25; known+mismatch = +15 conf threshold)
5. **V3+V4 auto-per-weapon** (sniper respects manual NL settings if `exp_respect_man`, else override)
6. **NoSpread mode** (head always, hc=1, mindmg=100)
7. **Aggressive head-focus** (hitbox chain + multipoint + hc=40 mindmg=25)
8. **Generic multipoint hint** (Networked/Predicted/Static first-shot)
9. **Force-baim** (after N misses, hitbox=baim_hb_id, mindmg from UI)

Each guarded by toggle. Early-return after `cancel-conf` / `shot-cooldown` / `air-block`. `close-priority` does NOT return — continues with head-focus.

## Debug workflow

User can't easily share neverlose state. Use these:
1. **DEBUG MODE switch** in Logging group → emits `[DBG]` per-resolve lines
2. **📋 Copy Last Logs button** (V7.5+) → strructured dump: config + learning diagnostics + session trend + mode stats + auto-suggestions + tracked players + last 80 important events + improvement hints. User drag-selects between `════` markers.
3. **Print Status button** → toggle snapshot + mode hit-rates table
4. **Dump All Player States button** → every tracked enemy's full state
5. **In-game HUD-corner overlay** (when ESP-toggle on) → live tracked/learned/conf/top-mode/last-event/current-target intel + improvement trend
6. **Per-enemy ESP** → arrow + ⚡(if +Pred) + measured° + learning-progress indicator
7. **`log_buffer`** (80-entry ring) collects HIT-FULL/MISS-FULL/UNKNOWN/cancel-conf/close-priority/snapshot-match — printed by Copy button regardless of debug-toggle state

## ESP learning-progress indicators (per-enemy label)

| Samples (active + 0.3×passive) | Indicator | Meaning |
|---|---|---|
| `passive only, ≥5` | `👁N` | observed but never shot |
| `1-3 active` | `·N+P` | some hits + passive count |
| `4-7 active` | `★N` | well-learned |
| `≥8 active + conf≥60` | `🔒N` | LOCKED-ON (green tint) |

HUD current-target also tags `🔒LOCKED` / `★` / `·` based on samples.

## V3/V4/V5/V6/V7 feature toggle defaults (per preset)

| Feature | Aggro | Dynamic | Defensive | NoSpread | SSG-Pro |
|---|---|---|---|---|---|
| aim_fire snap (V3) | ON | ON | ON | ON | ON |
| per-side desync (V3) | ON | ON | ON | ON | ON |
| ESP+HUD (V3+V5) | OFF | OFF | OFF | OFF | ON (Full) |
| cancel-low-conf (V3+V5+V6) | OFF | ON | ON | ON | ON |
| auto-per-weapon (V3) | OFF | ON | OFF | OFF | ON |
| hitbox-chain (V3) | ON | ON | OFF | OFF | OFF |
| persistent-learning (V4) | ON | ON | ON | ON | ON |
| extrapolation (V4) | ON | ON | OFF | ON | ON |
| respect-manual-SSG (V4) | OFF | ON | ON | OFF | ON |
| predict-ticks (V4) | 2 | 2 | 1 | 3 | 3 |

V5 always-on: shot-cooldown skip, AA-classify hysteresis, mode-stats audit, confidence-score, adaptive predict-ticks.
V6 always-on: close-priority tiered (4 tiers), air-block (sniper-only), per-AA-type best-mode tracking, intel-aware cancel-conf, BF eye-drift invalidate, FS-cache result validation, guess-side per-engagement, learning-cleanup (7d/200-entry cap).
V7 always-on: lock-on visual indicators, session-trend tracker, copy-logs dump, V7.1 passive learning (read `anim.m_flGoalFeetYaw` pre-override), V7.7 6-pattern sid fallback + known-player fast-path + passive-weighted confidence.

## HUD-overlay anatomy

When ESP toggle ON, `events.render` (throttled 10hz compute, per-frame draw from `hud_cache`):
- **Per-enemy ESP**: 1-line arrow `→`/`←` + `⚡` + measured° + learning-progress indicator + confidence bar (color-coded). Mode-color: green=Meas, yellow=Predict, red=BF, blue=Air, cyan=LBY, magenta=Jitter.
- **HUD corner panel** (configurable position via `esp_hud_pos` combo): version header + tracked/learned + avg-conf + top-mode + hit-rate + last combat (5s history, HIT green / MISS red) + current-target intel (`→Target #N ✓/✗/· conf%🔒LOCKED [aa] mode`) + session-trend (`↑ improving / → stable / ↓ declining`).

All `render.*` calls pcall-wrapped. Border via 4 thin rects (avoid uncertain `render.rect_outline`).

## Common mistakes to avoid

- Don't add UI elements without `pcall` around `:set_callback` — callback errors silently brick the script
- Don't introduce numeric step in `:slider` (5th arg — breaks display)
- Don't use `\a{Color}` accent codes in `:button` labels — renders blank
- Don't put resolver-state mutations in `events.render` — race with createmove
- Don't call `print` directly — use `cs_log` / `cs_log_color` / `cs_log_verbose` / `cs_log_debug`
- Don't add features without pcall around new NL API calls — version variance
- Don't forget `events.shutdown:unset()` for any new event hook
- For per-weapon: when user has good manual NL settings (e.g. SSG-08), use `exp_respect_man` to SKIP overriding
- For HUD positioning: use `render.screen_size()` for resolution-independence
- Adaptive features: bound the adaptation range so runaway-tuning can't break resolver
- Cache invalidation: don't only key on `missed` count — eye_yaw drift can make cached angles useless (>20° drift = invalidate)
- First-shot fallbacks: NEVER return `eye_yaw` unchanged when `samples=0` — always offset ±29°
- When bumping `SEL01_VERSION`: update constant + file-header `@version` comment together
- Forward-decl block MUST come before any UI element that uses those locals in a callback
- New learning paths: feed both `mode_stats_update` AND `learning_update_hit` AND `session_record` to keep diagnostics consistent
- Don't expand `confidence()` weight without bounding: cap `sample_score` at 60 to leave room for stddev/age contributions
