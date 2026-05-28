# Sel01-Solver — Custom Neverlose CS2 Resolver

**File:** `resolverv2_35544.lua` (~1280 lines)
**For:** Neverlose CS2 Lua API
**Author:** seltonmt01
**Original base:** copypasted resolver code (broken). Fully rewritten + hardened.

---

## What this script does

1. **Resolver** — guesses enemy desync angle to land aimbot shots on dodgy anti-aim users
2. **Sel01-Roast** — auto-chat random insult on enemy kill
3. **Loading screen** — branded splash on script load

---

## Architecture

### File sections (top → bottom)

| Lines (approx) | Section |
|---|---|
| 1–22 | Requires + `cs_log` / `cs_log_color` helpers (uses `print` + `client.color_log`) |
| 24–110 | Loading screen (FFI URL download, render callback, sidebar gradient) |
| 112–270 | UI: tab `Sel01-Solver` + 8 groups (Main, Resolver Core, Aggressive Tuning, Bruteforce, Experimental, Performance Info, Logging, Sel01-Roast) |
| 272–310 | Preset buttons → `apply_preset()` function (4 presets: Aggressive / Dynamic / Defensive / NoSpread) |
| 312–410 | FFI: `AnimatingStateInfo` cdef, `GetAnimState`, `GetMaxDesync` |
| 412–540 | Math helpers (NormalizeAngle, Approach, RebuildServerYaw) |
| 542–610 | `PlayerState` table (per-enemy resolver state) |
| 612–700 | `events.aim_ack` handler — learns from hits/misses |
| 702–810 | Resolver core: `update_jitter`, `classify_aa`, `steam_mem_*` |
| 812–920 | `pick_first_shot_angle`, `pick_bruteforce_angle`, `get_mode_preset` |
| 922–1010 | `resolve_player`, anim-cache, tick-cache, FOV/distance cull |
| 1012–1090 | `events.weapon_fire` (LBY-snap), `events.createmove` (main resolve loop), `events.ragebot_target` (multipoint + baim + head-focus) |
| 1092–1180 | Sel01-Roast: chat-spam tables + `events.player_death` |
| 1182–1230 | Shutdown handler, load banner |

---

## UI Tab: `Sel01-Solver`

### Main (preset buttons)
- **Aggressive (Head-Focus)** — close-range pushers, no-baim head only
- **Dynamic (Adaptive)** — balanced, adapts mode per enemy
- **Defensive (Safe)** — long-range, multi-miss baim, safepoint on
- **NoSpread Server (1-Tap)** — for nospread servers, 100hp head 1%hc

### Resolver Core
- `Resolver Boost` — legacy switch (no-op, kept for config compat)
- `Resolver (beta)` — **MASTER SWITCH** for resolver
- `Resolver Animation` — legacy switch (no-op)
- `Resolver Mode` — combo: Adaptive / Aggressive / Defensive (preset-applied or manual)

### Aggressive Tuning
- `LBY Snap Detection` — when enemy shoots, server snaps their LBY to eye → we use that angle
- `Air Resolve (no desync)` — airborne enemy handling (uses RebuildServerYaw + measured)
- `Close Range (units)` — distance threshold for full-desync vs 85%
- `Dormancy Reset (ms)` — re-engagement timer; resets brute-force-counter

### Bruteforce / Baim
- `Force Baim After N misses` — after N misses, switch to body shots (0 = never)
- `Baim Min Damage` — minimum dmg threshold for baim
- `Baim Hitbox` — Stomach / Pelvis / Chest / Legs

### Experimental
- `AA-Classification` — classifies enemy as static/jitter/spinner/switch and picks tailored strategy
- `Multipoint Boost` — adds multipoint scan in networked/predicted modes
- `Defensive-AA Detect` — detects enemies that move post-fire, inverts side
- `Steam Memory` — persistent per-SteamID hit-side memory across rounds
- `Aggressive Head-Focus` — in Aggressive mode, overrides hitbox=head, hitchance=35, mindmg=1
- `NoSpread Mode (1-tap heads)` — overrides hitbox=head ALWAYS, hitchance=1, mindmg=100, multipoint OFF
- `AA-Classify Interval (ticks)` — how often to re-classify (4-16)

### Performance Info (labels only)
Shows what optimizations are always-on (anim-cache, FOV-cull, distance-cull, lazy log format)

### Logging
- `Console Logging` — master log switch
- `Verbose (per-shot)` — detailed per-shot logs
- `DEBUG MODE (full dump)` — full per-resolve state dumps
- `Print Status` button — current state snapshot
- `Dump All Player States` button — every tracked player's state

### Sel01-Roast (on kill)
- `Enable Sel01-Roast` — chat-spam toggle
- `Message type` — RU / EN / "1"

---

## Resolver State Machine (per enemy)

Every enemy in `PlayerState[idx]` holds:

```
{
    missed              -- consecutive miss counter (resets on hit)
    last_seen           -- curtime (for dormancy detect)
    lby_snap            -- flag, set true on weapon_fire event
    yaw_cache[8]        -- ring buffer of recent yaws (jitter detect)
    jittering           -- bool from update_jitter()
    last_hit_side       -- +1 / -1 / 0 (right / left / unknown)
    mode                -- current resolve mode string (for debug)
    measured_desync     -- EMA of actual desync angle (learned from hits)
    desync_samples      -- count of measurements
    hit_streak_left     -- consecutive hits on left side
    hit_streak_right    -- consecutive hits on right side
    last_yaw            -- previous yaw (for rate calc)
    yaw_rate            -- deg/sec (for ping extrapolation)
    last_resolved       -- last applied goal_feet_yaw (for learning)
    last_eye_yaw        -- last eye_yaw at resolve time
    defensive_aa        -- bool, set on "spread" miss state
    aa_type             -- "static" / "jitter" / "spinner" / "switch"
    aa_classify_cd      -- countdown to next classify
    tmp_dist, tmp_close -- per-tick scratch
}
```

---

## Mode Flow (single resolve call)

1. `can_resolve(p)` → alive + enemy + not dormant
2. Dormancy reset if `last_seen` > N ms ago — bootstraps `last_hit_side` from Steam Memory
3. FOV cull (>110°) + distance cull (>4500u) — skips offscreen/far
4. `GetAnimStateCached(p)` — cached ffi pointer per tick
5. Air check → if airborne: `RebuildServerYaw` + measured-desync side
6. `update_jitter(p, s)` → updates yaw_cache + yaw_rate
7. Classify AA (every 4-16 ticks)
8. If `missed == 0` → `pick_first_shot_angle()`:
   - AA-classify shortcuts: static/jitter
   - LBY-snap if flagged
   - Networked / Predicted-Streak / Predicted (velocity)
9. Else → `pick_bruteforce_angle()` (cycles bruteforce array based on missed-count)
10. Store `last_resolved` + `last_eye_yaw` (for aim_ack learning)
11. Apply `anim.m_flGoalFeetYaw = NormalizeAngle(angle)`
12. Debug-log if `DEBUG MODE` on

---

## Mode Strings (debug-log)

| Mode | Meaning |
|---|---|
| `Init` | First seen, no resolve yet |
| `Air` | Airborne (server-yaw + measured) |
| `Static-Meas` | Static enemy, used measured_desync × known side |
| `Static-ServerBoost` | Server-yaw smaller than measured, boosted to measured value |
| `Static-Server` | Server-yaw delta ≥5° |
| `Static-Guess` | Server-yaw == eye_yaw (no info). Guessed ±29° via streak |
| `Networked` | Standard server-yaw rebuild |
| `Jitter-Cls` | AA-classified as jitter, locked on last hit side |
| `Jitter-Lock` | Pre-classify jitter handling |
| `LBY-Snap` | Enemy just shot, server-LBY locked to eye |
| `Predicted` | Velocity-based side guess |
| `Predicted-Streak` | Hit-streak history overrode velocity guess |
| `Predicted-DefInv` | Inverted predicted side due to defensive-AA detect |
| `BF:opposite` | Brute-force: flip last hit side |
| `BF:+58 / -58 / +45 / -45 / +29 / -29 / +15 / -15 / 0` | Brute-force fixed angles |
| `BF:desync / -desync` | Brute-force ± effective_desync |
| `BF:lby` | Brute-force using m_flLowerBodyYawTarget |

---

## Events Hooked

- `events.aim_ack` — learn from hit/miss, update measured_desync EMA + streak
- `events.weapon_fire` (fallback `player_shoot`) — flag enemy as lby_snap when they shoot
- `events.createmove` — run resolver on all enemies each tick
- `events.ragebot_target` — pcall-attempt multipoint/hitbox/hitchance overrides
- `events.player_death` — Sel01-Roast chat spam
- `events.render` — sidebar + loading screen
- `events.shutdown` — unhook everything + clear all state

---

## Common Bugs Encountered (lessons)

| Bug | Cause | Fix |
|---|---|---|
| `os.time()` nil | NL sandbox no `os` lib | Use `globals.realtime`/`tickcount` |
| `arithmetic on string` | `combo:get()` returns string not index | Use string compare or `combo_str()` helper |
| `pairs(nil)` | PlayerState forward-ref'd in button closure before declared | Forward-declare local, then `setmetatable(existing_table)` later |
| `_cs_log_color_raw nil` | Same forward-ref pattern with raw log refs | Define raw refs at top, gates wrap later |
| `steam_mem_on_miss nil` | Functions defined AFTER aim_ack handler | Forward-declare `local f1, f2, f3` early, assign later |
| `attempt to call ':get_target'` | `obj:method` syntax requires immediate call | Use `obj.method and obj:method()` for conditional |
| L=R=0 streak even after hit | Side-compute ran AFTER streak update | Move side-compute BEFORE streak update in aim_ack |
| Static enemy `goal=eye` (0 desync) | RebuildServerYaw returns eye when can't compute | Fallback to ±29° guess via streak/default |
| Air-resolve always missed | Old code assumed 0 desync midair → set goal=eye | Use server-yaw + measured-side instead |

---

## Performance Optimizations

| Opt | Where | Impact |
|---|---|---|
| Anim-state cache | `GetAnimStateCached()` per tick | Saves ~10× ffi.cast per multi-enemy frame |
| Tick-cache (lp_yaw, lp_origin) | `refresh_tick_cache()` | One lookup vs N × players |
| FOV cull (>110°) | top of `resolve_player` | Skips ~30-50% of enemies in typical fights |
| Distance cull (>4500u) | same | Skips far spectators |
| Lazy log format | `cs_log_verbose(fmt, ...)` only formats if log on | Zero alloc when logging off |
| Render callback swap | After loading-screen done | One less call per frame forever |

---

## Verification

```bash
luac -p resolverv2_35544.lua && echo OK
```

Must print `OK` with no errors before testing in NL.

In-game test:
1. Load script → banner appears with all settings
2. Click preset → log confirms
3. Enable DEBUG MODE in Logging group
4. Engage enemy → `[DBG]` lines stream per resolve + per shot
5. Unload script → "shutdown — unhooking events" log, no crash

---

## Maintenance Notes

- Pcall every neverlose API method that might differ between versions (`override_*`, `set_*`)
- Forward-declare locals before any closure that references them
- Combo `:get()` returns string in neverlose — never do arithmetic on combo value
- Switch `:get()` returns boolean — direct compare ok
- Slider `:get()` returns number — direct compare ok
- Use `setmetatable(existing, mt)` NOT `local x = setmetatable({}, mt)` when forward-decl'd
- Test unload between every major change — crashes here are show-stoppers

---

## Files

- `resolverv2_35544.lua` — main script
- `README.md` — this file

## Author trail

- Original copypaste → broken, missing event-registration, dead vector(0..180) code
- seltonmt01 rewrite: per-player state, presets, debug, performance, head-focus, NoSpread mode
