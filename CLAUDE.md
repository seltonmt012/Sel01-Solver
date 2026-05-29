# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Two Neverlose **CSGO** (legacy build, NOT CS2) Lua scripts for HvH / rage play. Both run together inside the same NL client sandbox; they communicate only via NL's own events/UI, never directly.

| Script | Role | Working copy | NL load path |
|---|---|---|---|
| **Sel01-Solver** (`resolverv2_35544.lua`, ~3700 lines, v9.x) | Resolver: per-player AA learning, JSON export, HUD/ESP overlay, FFI clipboard copy-logs, Sel01-Roast chat-spam | `C:\Users\Seltonmt\Desktop\sazz\aron\ownlua\resolverv2_35544.lua` | `E:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive\nl\scripts\Sel01-Solver_59853.lua` |
| **Sel01-Config** (`sel01_config.lua`, ~1400 lines, v3.x) | Companion: AA presets (Aggressive/Dynamic/Defensive/Spin), anti-bruteforce jitter, air-desync + move-desync overrides, anti-HS extras (pitch jitter, move-fakeduck), peek-boost hotkey, hits-taken log with AA-state snapshots, kill/miss/hit event log top-left, debug stats, watermark + indicators + rotating AA arrow | `C:\Users\Seltonmt\Desktop\sazz\aron\ownlua\sel01_config.lua` | `E:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive\nl\scripts\sel01_config_59908.lua` |

**Dual-copy rule (MANDATORY).** After every Edit/Write to either working copy, immediately overwrite the matching NL file (same path, no new files, no renames). PowerShell one-liner: `Copy-Item -Force -LiteralPath '<working>' -Destination '<nl-path>'`. The git repo only tracks working copies — the NL copies need the mirror so reload in NL picks up the change.

**Version constants — keep all touchpoints in sync per script:**
- Sel01-Solver: `local SEL01_VERSION = "X.Y"` + file-header `@version X.Y` + 3 visible mentions (load-banner, UI label, HUD corner)
- Sel01-Config: `local SEL01_CFG_VERSION = "X.Y"` + file-header `@version X.Y` (no HUD mention; load banner reads constant directly)

Solver runtime data (private, gitignored):
- Persistent learning (Lua-table fast-load): `nl/Sel01-Solver/learned.lua`
- JSON backup + human-readable: `nl/Sel01-Solver/learned.json`
- Copy-logs file fallback: `nl/Sel01-Solver/last_logs.txt`

Solver architecture + bug history + UI doc lives in `README.md`. NL API docs at `https://docs-csgo.neverlose.cc/readme.md?ask=<keywords>` — consult before guessing API names. Config script has no separate README; this file is canonical.

**Git repo.** Remote: `origin https://github.com/seltonmt012/ownlua.git` (branch `master`). `.gitignore` excludes private data + `.claude/` + `.vscode/`. Auto-commit + push on version bumps per project policy.

## Verify changes

```powershell
luac -p resolverv2_35544.lua    # resolver
luac -p sel01_config.lua        # config
```

`luac` from scoop (`C:\Users\Seltonmt\scoop\apps\lua\current\bin\luac.exe`). Must exit clean. No test infrastructure — runtime errors only surface when user reloads in NL and reports. After luac passes, **dual-copy to NL** (see paths table above) so the next NL reload sees the change.

**Local limit warning** (V9.3 hit-point): Lua 5.1 main-chunk limit = 200 locals. Solver is close to that. New top-level locals should be wrapped in `do...end` blocks to scope them out. Both clipboard FFI + log_buffer ring use this pattern.

## Critical patterns (each has bitten before)

**Forward-references kill closures.** NL UI callbacks (button bodies, `:set_callback`, `events.ragebot_target`, `events.render`) capture upvalues at parse-time. If referenced local is declared LATER, closure binds to GLOBAL (nil at call time). **Forward-decl block must be BEFORE any UI element referencing those names.** Currently at top (line ~135): `SteamMemory`, `LearnedModel`, `mode_stats`, `PlayerState`, `tick_cache`, `NormalizeAngle`, `mode_stats_update/dump`, `confidence`, `session_stats`, `record_player_shot`. Pattern: `local X = {}` at top, then `setmetatable(X, ...)` later. NEVER `local X = setmetatable({}, ...)` later (creates a new shadowing local).

**Combo `:get()` returns STRING, not index.** Use string compares or `combo_str()` / `mode_str()` / `baim_hb_id()` helpers. Never arithmetic on combo value. **Combo `:set()` also takes STRING** (the option label), not an index — passing an int silently fails or freezes the menu callback.

**Slider 5th arg is NOT step.** `:slider(name, min, max, default)` only. 5th arg breaks display.

**Neverlose sandbox lacks `os`.** Use `globals.realtime` + `globals.tickcount`. NL also lacks JSON lib — V8.3 ships own encoder.

**Lua 5.1 sandbox restrictions:** no `goto`, no integer-division operator `//` (use `math.floor(a / b)`), no `table.unpack` (use `unpack`), no bitwise operators (use `bit.band` / `bit.bor` / `bit.bnot`).

**`ui.find` path resolution.** Prefer `pui.find(...)` (from `neverlose/pui`) — it returns `nil` on missing paths silently. `ui.find` raises a popup-error dialog on missing paths that pcall does NOT suppress (the popup is a GUI side-effect that fires before the error propagates). Sel01-Config uses `nl_find_safe` which tries pui.find first and falls back to ui.find inside pcall. The full list of verified NL ui.find paths lives in user memory at `reference_nl_ui_paths.md` — consult before writing new path strings.

**`ref:override(value)` is non-destructive; `ui.set(ref, value)` is destructive.** `:override` reverts to the user's manual UI state when the script unloads or `:override()` is called with no args. `ui.set` permanently mutates the user's config. Always prefer `:override` for runtime writes that wrap user-owned NL elements.

**NEVER write fields to `events.antiaim` `cmd` userdata** (Sel01-Config v1.6 bug). No other NL script writes `cmd.pitch / cmd.yaw_base / cmd.desync_range / cmd.desync_side` — JAG0YAW, bloodwings, gingersense, bettervisal, nyanza all drive AA through `ui.find(...):override(...)` on NL's own Anti Aim panel. Writing to undefined fields on cmd causes a C++ panic that bypasses Lua pcall and crashes CSGO a few seconds after team-select. Sel01-Config v1.8 deleted `aa_handler` and replaced it with a periodic sync that only writes to `nl_refs.aa_bodyyaw_l/r/freestand` via `:override`.

**NL events: assume per-script isolation.** Multiple installed scripts (resolver, config, bloodwings, etc.) each register their own `events.weapon_fire` / `events.aim_ack` handlers without stepping on each other. Empirically this works — both Sel01 scripts hook `events.weapon_fire` simultaneously and both detection paths fire. If a handler stops firing, suspect this assumption.

**Event-name aliases vary by NL build.** Use `register_first(handler, name1, name2, ...)` (Sel01-Config v1.7 helper): walks aliases, `:set` on the first one that exists, returns its name for status logging. Triple-registering all aliases is dead code — the second `:set` overwrites the first.

**Defer menu-callback work to next tick.** Button callbacks that synchronously call `:set` on combo / slider elements during the menu render lifecycle freeze the menu (Sel01-Config v1.5 fix). Set a `pending_X = name` flag in the button callback and drain it from the next `events.createmove` tick.

**Never `:override(bool)` on NL combo elements** (Sel01-Config v2.2 incident). Scope Overlay, Hit Marker Sound, Force Thirdperson, Self-Glow, NL Glow chams — these LOOK like switches in the menu but are actually multi-value combos under the hood. JAG0YAW writes them with strings (`scope_overlay:set("Remove All")`). Writing `:override(true/false)` segfaults CSGO the first tick the script becomes active in a match. Safe NL :override target types are switches (bool), sliders (int/float), and combos written with the matching string. If unsure, just don't override.

**Never `:override` on NL hotkey elements** (Sel01-Config v2.0 incident). Peek Assist is a hotkey UI element, JAG0YAW only `:get()`s it (gingersense too) and never overrides. Calling `:override(int)` per tick on a hotkey userdata segfaults CSGO at spawn. Use `:get()` to read whether the user is holding the hotkey, then drive OTHER refs (hitchance, mindmg) instead.

**`events.weapon_fire` and `events.player_hurt` cannot read enemy entity properties safely** (Sel01-Config v1.12 incident). CSGO returns invalid memory for `shooter.m_vecOrigin / m_angEyeAngles / victim.m_vecOrigin` on players in transition states (just-respawned, dying, weapon-switching). pcall does NOT catch C++ segfaults from invalid userdata. Skip property reads entirely — use only event fields (event.userid, event.hitgroup, event.dmg_health) plus `entity.get(uid, true)` object-identity comparison against `entity.get_local_player()` (JAG0YAW pattern).

**`aim_ack` nil-state means HIT, not MISS** (Sel01-Config v2.9 fix). NL fires `aim_ack` with `event.state` set to "hit" / "damaged" / "hit-damaged" for hits, named miss reasons for misses, OR nil-state when the shot landed without a specific tag. Resolver uses `is_hit = (reason == nil) or HIT_STATES[reason]`. Config v2.6-v2.8 used `if reason and HIT_STATES[reason] then hit` which inverted nil into miss — caused the stats panel to show 0% hit-rate despite resolver showing 73%+. Always match the resolver pattern.

**`event.hitbox` (aim_ack) is unreliable; `event.hitgroup` (player_hurt) is reliable.** On the user's NL build aim_ack never populates hitbox. Hitbox-bucketing stats must come from player_hurt's hitgroup (1=head, 2=chest, 3=stomach, 6/7=leg). Keep two maps: `HB_INDEX_NAMES = {[0]="head", [3]="chest", ...}` for hitbox-index, `HB_GROUP_NAMES = {[1]="head", [2]="chest", ...}` for hitgroup. _hb_name() should walk both plus string passthrough.

**Per-tick functions mutate state → oscillation.** `pick_bruteforce_angle` runs 64×/sec. Four caching layers prevent state-thrash:
- `bf_cached_missed/angle/mode/eye` — BF only recomputes when `missed` count changes OR eye drifts >20°
- `fs_cached_time/eye/angle/mode` — first-shot held 150ms unless eye drifts >20° AND validated `|angle-eye| >= 5`
- `guess_cached_side/miss` — fallback-side picked once per engagement
- AA-classify uses **5-tick hysteresis + 1s post-commit lock** (V9.0)

**`aim_ack` reads stale `s.last_resolved`.** By ack-time several resolves ran. Use `shot_snapshots[]` ring-buffer pushed by `events.aim_fire`. In `aim_ack`, pick snapshot closest to `event.tick`.

**Optional NL API methods** (version variance — always pcall): `ctx:override_multipoint`, `ctx:override_hitbox`, `ctx:override_hitchance`, `ctx:override_min_damage`, `ctx:override_hitboxes` (plural), `ctx:override_safe_point`, `ctx:override_multipoint_scale`, `entity.get_lerp_time`, `client.latency`, `p:get_steam_id`/`get_steamid`/`m_steamid`, `entity.get_steam_id`, `p.m_iAccountID`/`get_account_id`, `events.aim_fire`, `events.ragebot_fire`, `events.ragebot_target`, `render.world_to_screen`, `render.rect_outline`, `lp:get_weapon().m_flNextPrimaryAttack`, `lp.m_fFlags`. Conditional method-check: `obj.method and obj:method()`.

**`m_flGoalFeetYaw = eye_yaw` is BROKEN.** All branches validate `|result - eye_yaw| >= 5` and fall through to `*-Guess` modes with ±29° offset. V9.6 added `Air-Guess` for air-branch fallback (was resolving to exact eye_yaw).

**HIT vs MISS detection inverted + NON_RESOLVER_MISS skip.** Default to MISS, only count HIT for explicit `HIT_STATES` (`hit`, `damaged`, `hit-damaged`). `NON_RESOLVER_MISS` table (V6.8 + V8.8): `death`, `damage rejection`, `player_death`, `unregistered shot`, `backtrack failure` — early-return, not resolver fault.

**Hook-overriding pattern for cross-system updates.** Function needs side-effects elsewhere: wrap `local _orig = X; X = function(...) _orig(...); side_effect(...) end`. Used for `mode_stats_update` → HUD `last_combat_event` + `session_record`.

**Throttled draw needs cached compute.** `events.render` fires every frame. Throttle COMPUTE (refresh `hud_cache` table every N ms), DRAW cached values every frame. Otherwise screen-clear between draws → flicker.

**Steam-ID has 6 fallback patterns** (V7.7): `get_steam_id` → `get_steamid` → `m_steamid` → `entity.get_steam_id` → `m_iAccountID` netvar → name-hash → userid+name combo. Each pcall-wrapped. Failure logged once. Current NL versions tend to fall through to name-hash (sid prefix `name_HASH_LEN`).

**yaw_rate sanity** (V9.0): `>720°/s` is netvar glitch (saw 2700°/s spikes). Clamp to 0 before storing. Also tracked in `yaw_rate_buf` (last 6) with `yaw_rate_consistent` flag — only extrapolate when stable direction.

**Real samples ≠ seeded samples** (V9.1). `samples_left/right` include passive-seeded entries. `real_left/right` counts ONLY actual hit-derived data. Confidence formula uses `real_active` weighted 1.0, seeded + passive 0.3×. Caps: 0 real → max 50, 1 → 70, 2 → 85, 3+ → 100.

**Mode-name suffix chain explosion** (V8.9 bug). Known-player fast-path appended `-Recall` each engagement → `Static-Meas-Recall-Recall-Recall-Recall`. Fix: strip existing suffix before appending. `learning_update_hit` + `mode_stats_update` + `learning_load` migration all clean `+Pred / -DefInv / -Recall / BF: / *-Guess` from stored values.

## File layout (resolverv2_35544.lua, ~3700 lines)

| Lines (approx) | Purpose |
|---|---|
| 1–35 | Version constant, requires, `cs_log` helpers + raw refs |
| 35–80 | **V8.7 FFI clipboard helper** (wrapped in `do...end` for local-budget) |
| 82–175 | Loading screen FFI URL download, sidebar gradient |
| 130–175 | **EARLY FORWARD-DECL BLOCK** (V7.3 fix) + `record_player_shot` definition |
| 180–355 | UI: tab `Sel01-Solver`, 10 groups, **6 preset buttons**, 4 Smart Strategy combos, ~18 experimental toggles (incl V7.9 `exp_head_strict`) |
| 360–620 | Logging buttons (📋 copy-logs via FFI clipboard + file, 🗑 reset learning, 🗑 reset session, dump, status) |
| 625–700 | V5 mode-stats audit (V8.9 normalize -Recall) + V5+V9.1 confidence (real-vs-seeded weighting) |
| 705–840 | V4 persistent learning + V8.3 JSON encoder + `learning_export_json` + V8.9 migration + V8.6 6-pattern sid + manual reset/export buttons |
| 845–900 | V4 prediction helpers (`predict_yaw_ahead`, `predict_position`) |
| 905–1180 | Helper funcs (mode_str, baim_hb_id) + `safe_set` + `apply_preset()` — **6 presets** (aggressive/dynamic/defensive/nospread/ssg_pro/head_only) |
| 1185–1280 | Logging gates (cs_log/verbose/debug) + log_buffer ring push + V8.8 buffer-from-verbose expansion |
| 1285–1450 | FFI cdef `AnimatingStateInfo`, `GetAnimState`, `GetMaxDesync`, math helpers, `RebuildServerYaw` |
| 1455–1560 | `PlayerState` setmetatable on forward-decl'd table — all V3-V9 fields incl `real_left/right`, `def_delta`, `still_ticks`, `yaw_rate_buf` |
| 1565–1900 | `events.aim_ack` — snapshot match, per-side EMA, **real_samples increment**, V8.2 correction-flip, V9.6 LBY auto-flip, V9.3 def-AA fingerprint, non-resolver-miss skip, **Init-mode log filter** |
| 1905–2050 | `update_jitter` (V9.0 yaw_rate clamp + V8.0 consistency buf), `classify_aa` (V9.5 spinner-shortcut), Steam-mem |
| 2055–2410 | `_pick_first_shot_impl` + **all resolver modes**: known-player fast-path, V8.4 Still-Server/Meas/BFGuess, V7.8 slow-walker, V9.2 Slow-Alt switch-alt, AA-classify shortcuts (V9.3 Spinner-Rot), LBY-Snap, jitter-lock, Predicted-Alt/Streak, Networked variants, ±29 guess fallback |
| 2415–2550 | `pick_first_shot_angle` FS-cache wrapper, `pick_bruteforce_angle` (V9.5 def_delta cycle, V7.8 finer cycle for static/slow) |
| 2555–2720 | per-tick caches, `resolve_player`: dormancy reset + V9.2 decay measured + V4 learning boot + air-branch (V8.2 Air-Alt + V8.2 Air-CorrFlip + V9.6 Air-Guess), slow-walker + V8.4 stationary detect, AA-classify (V9.0 stronger hysteresis), V4+V9.3 extrapolation (V8.1 4 gates + V9.2 dist-scale + V9.3 per-weapon + ping-aware), passive seed + V8.6 persist passive |
| 2725–2825 | `should_force_baim`, weapon_fire (LBY snap), aim_fire snapshot push + V7.8 last_shot_side, createmove (V8.4 periodic auto-save 10s) |
| 2830–3050 | `events.ragebot_target` — **10-stage override stack** incl V9.4 SSG-respect close-priority floor + safe-points respect + V9.6 fast-fire + V8.5 jump-shot V9.4 SSG-respect variant + V7.9 head-strict + V8.4 baim hc-drop |
| 3055–3300 | ESP overlay + HUD-corner overlay (V8.0 throttled compute / per-frame draw from cache) + V7+V8 learning indicators (`👁/·/★/🔒`) |
| 3305–3525 | Sel01-Roast chat spam, player_death, shutdown handler (V8.6 force-save) |
| 3530–3700 | Load banner with full diagnostics + V4 `learning_load` + V8.9 migration call + V6 cleanup |

## Resolver mode flow (one resolve call)

`can_resolve` → V9.2 decay measured → dormancy reset (steam-mem boot + V4 learning-model boot + V6 best_modes + V8.9 throttled boot-log) → FOV/dist cull → `GetAnimStateCached` → **air-branch** (V8.2 Air-Alt switch / V8.2 Air-CorrFlip / V9.6 Air-Guess fallback / measured) → `update_jitter` (V9.0 yaw_rate clamp + consistency buf) → V7.8 slow-walker + V8.4 stationary detect → AA-classify (V9.0 5-tick hysteresis + 1s lock, V9.5 spinner-shortcut) → V4+V8.0+V9.3 extrapolate (4 gates: yaw_consistent, conf>=40, not slow, samples>=1; per-aa cap; V9.2 dist-scale; V9.3 per-weapon; V9.3 ping-aware) → **`pick_first_shot_angle`** (V7.7 known-player fast-path with V8.9 clean `-Recall` / V8.4 Still-Server-Meas-BFGuess / V7.8 slow-walker + V9.2 Slow-Alt / AA-classify static-meas-server-guess / V9.3 Spinner-Rot / jitter-cls / LBY-Snap / V8.2 Predicted-Alt switch + V9.3 def_delta fingerprint / Predicted-Streak / Networked* variants / ±29 guess) **OR `pick_bruteforce_angle`** (V9.5 def_delta cycle when defensive_aa / V7.8 finer cycle for static+slow) → store `last_resolved`+`last_eye_yaw` + push `recent_resolved[]` → V7.1+V8.6 passive-learn from server's pre-override `m_flGoalFeetYaw` + V8.6 passive-persist after 30 obs → apply `goal_feet_yaw`.

**Mode-name suffixes:**
- `+Pred` — extrapolation applied
- `-DefInv` — defensive-AA inverted side
- `-Recall` — V7.7 known-player fast-path (V8.9: strip-before-append, no chain)
- `-Alt` — V8.2/V9.2 switch-AA alternating (Slow-Alt, Air-Alt, Predicted-Alt)
- `-CorrFlip` — V8.2 correction-aware flip
- `-Guess` — V6 fallback (Static-Guess, Networked-Guess, LBY-Snap-Guess, Air-Guess, Slow-Guess, Still-BFGuess)

## ragebot_target override order (V9.6 — top to bottom)

1. **V5 shot-cooldown skip** (weapon `m_flNextPrimaryAttack` > curtime → hc=99, return)
2. **V6.9 close-priority tiered** (4 tiers: point-blank<400/close<700/dive-in/jump-peek, hc 5-20) — Aggressive/sniper. V9.4: sniper hc-floor 40, preserve mindmg=100, respect safe-points if respect_manual on
3. **V6 air-block** (sniper airborne + dist>3500u, hc=99, early-return — V8.5 was 1500, V9.4 raised)
4. **V3+V5+V6 cancel-low-confidence intel-aware** — known + mode_match + samples≥3 = TRUST skip; sniper peek-stop = skip; thresholds: sniper sd>50/conf<10, others 25/25; known+mismatch = +15 conf threshold
5. **V3+V4 auto-per-weapon** (sniper respects manual NL settings if `exp_respect_man`, else hc=50/mindmg=80/head; auto-rifle/heavy_pistol overrides; knife → hc=99 return)
6. **V9.6 fast-fire** (conf≥70 + samples≥2 + first-shot, skip if respect_manual: hc=20-28 → ragebot fires faster on stable resolve)
7. **NoSpread mode** (head always, hc=1, mindmg=100, no multipoint/safepoint)
8. **V7.9 head-strict** (head every shot, hc=45 mindmg=30 for spread server)
9. **Aggressive head-focus** (hitbox chain + multipoint + hc=40 mindmg=25, Aggressive mode + missed==0 only)
10. **Generic multipoint hint** (Networked/Predicted/Static first-shot)
11. **V8.5 jump-shot** (lp_airborne + dist<4000 + not close-priority): V9.4 SSG-respect mode → multipoint scale 0.85 + hc=40 preserves NL hitboxes; otherwise hitbox=head + hc=30-35
12. **V8.4 force-baim** (after N misses) — hitbox=baim_hb_id, mindmg from UI, **V8.4 hc-drop scaling by miss-count** (3 miss→20, 4→15, 5→10), multipoint scale 1.0

Each guarded by toggle. Early-return after `cancel-conf` / `shot-cooldown` / `air-block` / `knife`. `close-priority` does NOT return — continues with rest of stack.

## Persistence layer (V8.6 robust)

- `learning_save()` checks `learning_dirty` flag (avoids write spam)
- **Save every hit** (V8.6, was every 10th — quick-unload preserves data)
- **Auto-save every 10s** in `events.createmove` if dirty (V8.4: was 30s, V8.6 tightened)
- **Force-save on shutdown** (V8.6: `learning_dirty=true` set before save → unconditional write)
- **Passive obs persistence** (V8.6): after 30+ passive samples without hit, seed `LearnedModel` entry. Refresh every 60 obs.
- **JSON export** (V8.3): `nl/Sel01-Solver/learned.json` written on shutdown + manual `💾 Export Learning → JSON` button + auto every 10s with Lua-table

`LearnedModel[sid]` schema: `{dl, dr, sl, sr, dom, hits, miss, last_seen, best_jitter, best_static, best_switch, best_spinner}`. V9.0 filter: `BF:*` and `*-Guess` modes never saved to `best_*` (fallback paths, not patterns). V8.9 migration on load cleans `-Recall` chain + V9.0 cleans BF/Guess entries.

## Debug workflow

User can't easily share NL state. Tools:
1. **DEBUG MODE switch** in Logging → emits `[DBG]` per-resolve lines (Init-mode filtered V9.1)
2. **📋 Copy Last Logs button** (V7.5+) → comprehensive dump: config + V8.8 ESP/SMART/V7+ rows + learning diagnostics + session trend + mode stats + auto-suggestions + tracked players with V8.8 `└ flags{}` extension (slow/still/def/lby, streak L/R, corr L/R, yaw_rate, last_hit, dist, miss_rate, p_hits/miss) + V8.8 top-5 learned + log_buffer last 80 events + improvement hints. **V8.7: FFI clipboard copy direct (Ctrl+V anywhere) + V8.2 file fallback `nl/Sel01-Solver/last_logs.txt`**
3. **🗑 Reset Learning Data button** (V7.9) — wipes file + in-memory
4. **🗑 Reset Session Stats button** (V7.9) — wipes mode-stats/session/memory/log-buffer
5. **💾 Export Learning → JSON button** (V8.3)
6. **Print Status button**, **Dump All Player States button**
7. **In-game HUD-corner overlay** (when ESP-toggle on) → tracked/learned/conf/top-mode/last-event/current-target intel + session-trend
8. **Per-enemy ESP** — arrow + ⚡(if +Pred) + measured° + learning-progress indicator
9. **`log_buffer`** — V9.3 ring-buffer (cap=80, O(1) push). Captures HIT/MISS-FULL, UNKNOWN states, close-priority/cancel-conf/snapshot/aa-commit/correction-flip/jump events. V8.8 also feeds key verbose events regardless of verbose-toggle.

## ESP learning-progress indicators (per-enemy label)

| Real-active samples + conf | Indicator | Meaning |
|---|---|---|
| `passive only, ≥5` | `👁N` | observed but never shot |
| `1-3 active` | `·N+P` | some hits + passive count |
| `4-7 active` | `★N` | well-learned |
| `≥8 active + conf≥60` | `🔒N` | LOCKED-ON (green tint) |

HUD current-target tags `🔒LOCKED` / `★` / `·` based on samples.

## Per-preset toggle defaults (V9.4 — 6 presets)

| Feature | Aggro | Dynamic | Defensive | NoSpread | SSG-Pro | Head-Only |
|---|---|---|---|---|---|---|
| aim_fire snap | ON | ON | ON | ON | ON | ON |
| per-side desync | ON | ON | ON | ON | ON | ON |
| ESP+HUD | OFF | Std | OFF | OFF | Full | Std |
| cancel-low-conf | OFF | ON | ON | ON | ON | ON |
| auto-per-weapon | OFF | ON | OFF | OFF | ON | OFF |
| hitbox-chain | ON | ON | OFF | OFF | OFF | OFF |
| persistent-learning | ON | ON | ON | ON | ON | ON |
| extrapolation | ON | ON | OFF | ON | ON | ON |
| respect-manual-SSG | OFF | ON | ON | OFF | **ON** | OFF |
| predict-ticks | 2 | 2 | 1 | 3 | 3 | 2 |
| head-strict | OFF | OFF | OFF | OFF | OFF | **ON** |
| close_range | 1200 | 800 | 600 | 1500 | **800** | 1200 |
| force-baim | 3 | 2 | 4 | 0 | **5** | 0 |

**V9.4 SSG-Pro tuned for user's NL config**: hc=72, dmg=100, multi-hitbox Head+Chest+Stomach, Auto-Stop+Auto-Scope ON, Safe-Points "Prefer", Penetrate Walls. Preset preserves all those via `respect_manual=ON`.

Always-on features (no toggle):
- **V5**: shot-cooldown skip, AA-classify hysteresis (V9.0: 5-tick + 1s lock), mode-stats audit, adaptive predict-ticks
- **V6**: close-priority tiered (V9.4 sniper hc-floor), per-AA best-mode tracking (V9.0 filter BF/Guess), intel-aware cancel-conf, BF eye-drift invalidate, FS-cache result validation, guess-side per-engagement, learning-cleanup (7d/200-entry)
- **V7**: lock-on visual indicators, session-trend tracker, V7.1 passive learning, V7.7 6-pattern sid fallback + known-player fast-path
- **V8**: V8.0 miss-rate-aware confidence + yaw_rate consistency, V8.2 correction-flip + switch-AA alternating, V8.3 JSON export, V8.4 stationary detect + baim hc-drop + jump-shot + auto-save 10s, V8.5 jump-scout extended range, V8.6 robust persistence (every hit + passive persist + force-save), V8.7 FFI clipboard, V8.8 backtrack-failure handle + comprehensive copy
- **V9**: V9.0 yaw_rate clamp 720°/s + AA-stability + BF filter, V9.1 real-vs-seeded sample tracking + Init log filter, V9.2 decay measured + dist-scale + Slow-Alt, V9.3 Spinner-Rot + ping-aware extrap + per-weapon predict + def-AA delta fingerprint + log_buffer ring, V9.4 SSG-Pro tuned, V9.5 BF def_delta cycle + tighter spinner detect, V9.6 fast-fire + Air-Guess + LBY auto-flip, V9.7 Still-Alt + still/slow hard-reset on yaw spike, V9.8 counter-fire (events.weapon_fire hostile detect → bypass cancel-conf), V9.9 bulk easy-wins (dominant-side conf-boost / 2-miss mode-blacklist / crouch-aware hitbox / hostile-fire HUD / per-tick lp+wc cache / symmetric-data low-conf / backtrack-fail penalty / yaw-consistency extrap-boost), V9.10 log_buffer cap 80→200 + AA-type hysteresis tightened (7-consecutive + 2s lockout + anti-flap 5s freeze if >3 commits in 10s), V9.11 enhanced counter-fire (force head + safepoint-off + HC 15 + multipoint) + fast-fire tier system (conf 50/70/85 thresholds), V9.12 close-range first-miss follow-up (Aggressive + missed≥1 + dist<1000 → HC 10 + force head + safepoint-off)

## HUD-overlay anatomy

When ESP enabled, `events.render` (10hz throttled compute, per-frame draw from `hud_cache`):
- **Per-enemy ESP**: arrow `→`/`←` + `⚡` + measured° + learning-progress indicator + confidence bar. Mode-color: green=Meas, yellow=Predict, red=BF, blue=Air, cyan=LBY, magenta=Jitter.
- **HUD corner panel** (position via `esp_hud_pos` combo): version + tracked/learned + avg-conf + top-mode + hit-rate + last combat (5s history HIT green/MISS red) + current-target intel (`→Target #N ✓/✗/· conf%🔒LOCKED [aa] mode`) + session-trend (`↑ improving / → stable / ↓ declining`).

All `render.*` pcall-wrapped. Border via 4 thin rects (avoid uncertain `render.rect_outline`).

## Git workflow

**Remote**: `origin → https://github.com/seltonmt012/ownlua.git` (branch: `master`). Auto-pushed since V9.6.

**Auto-commit + push policy** (user-explicit V9.6): every version constant bump triggers commit + push. No manual approval needed for these. Each script commits independently. Commit format:
```
Sel01-Solver vX.Y — <short summary>      (for resolver bumps)
Sel01-Config vX.Y — <short summary>      (for config bumps)

<bullet list of changes>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

**Dual-copy reminder.** Every edit to `resolverv2_35544.lua` OR `sel01_config.lua` must also overwrite the matching NL file. NEVER create new files in the NL folder — only `Copy-Item -Force` over the existing ones. Working copy is the source of truth tracked by git; NL copy is the one NL reloads from.

`.gitignore` excludes private data (`learned.lua/json/last_logs.txt/logo.png`, `.claude/`, `.vscode/`).

Push command:
```powershell
git push origin master
```

If hook failure on commit: investigate root cause, fix, create NEW commit (don't amend — pre-commit hooks fail means commit didn't happen, amend would modify previous one).

## Sel01-Config layout (`sel01_config.lua`, v3.x, ~1400 lines)

| Section | Purpose |
|---|---|
| 1–30 | Version constant `SEL01_CFG_VERSION`, `pui` + `ffi` requires, optional `neverlose/gradient`, `cs_log` / `cs_log_color`, `accent`, `TAB = "Sel01-Config"` |
| 30–60 | UI groups (6 tabs: Main / Anti-Aim / Movement / Visuals / Quality of Life / Info), preset buttons forward-decl `apply_preset_fwd` |
| 60–120 | Anti-Aim UI: enable, pitch combo, yaw base, yaw add, yaw modifier, desync slider + side, freestanding, at-targets, plus HvH extras (on-shot, air-desync, anti-BF variance, fake-duck assist) |
| 120–155 | Movement (auto-peek + quick-stop hotkeys, strafe nudge, no-fall, fast-ladder), Visuals switches, QoL toggles, Info buttons |
| 155–230 | `nl_find_safe` (pui.find → ui.find fallback), `nl_override` + `nl_clear`, **verified NL ui.find ref dict** (all paths from JAG0YAW/bettervisal/bloodwings analysis) inside outer pcall |
| 230–390 | `_do_apply_preset` (4 presets: Aggressive / Dynamic / Defensive / Spin) — all writes go through `safe_set` or `nl_override`. Public `apply_preset` only queues `pending_preset = name` so the menu callback returns instantly |
| 390–460 | `aa_state` table (on_shot_until, fakeduck_until, last_fire_time), `aa_periodic_sync` — drives `nl_refs.aa_bodyyaw_l/r/freestand` every tick. No cmd-writes (v1.8 fix) |
| 460–550 | `createmove_handler` (auto-peek, quick-stop, strafe nudge, no-fall, fast-ladder), `createmove_unified` (drains pending_preset, runs movement, runs aa_periodic_sync, syncs NL visuals overrides + fake-duck) |
| 550–700 | Event hooks: `on_local_fire` → aim_fire / ragebot_fire (sets on_shot timer), `events.weapon_fire` (hostile-fire detection → fake-duck assist), `events.aim_ack` (hit-marker + skeet hit-log push), `events.player_hurt` (damage popups with hitgroup) |
| 700–1100 | `events.render` — single handler. Order: hit-marker → rotating AA indicator → damage popups → animated-gradient watermark (sine-wave RGB) → bottom HvH indicators (DT / HS / ON-SHOT pulse / FD-ASSIST pulse / AA / MANUAL L/R / AIR / ANTI-BF / FREE / SW / FD) → velocity warning → skeet hit-log → keybinds panel → clantag updater → spectator overlay |
| 1100–1220 | QoL: animated clantag (3 styles), kill-say themes, auto-accept, Status/Reset Info buttons, `clear_all_nl_overrides`, master-disable + shutdown handlers, load banner with hook-status report |

### Sel01-Config flow (one tick)

`events.createmove` → `createmove_unified(cmd)` → drain `pending_preset` (if any) via `pcall(_do_apply_preset, name)` → `createmove_handler(cmd)` (movement helpers, pcall'd) → `aa_periodic_sync()` (compute Body Yaw L/R from base desync + air override + on-shot reduction + anti-BF variance; clamp [0,58]; nl_override on body-yaw + freestand refs) → if master enabled, sync NL visuals overrides (hit-marker sound, thirdperson, scope overlay) + fake-duck during `fakeduck_until` window.

### Sel01-Config presets (v3.x)

| Toggle | Aggressive | Dynamic | Defensive | Spin |
|---|---|---|---|---|
| desync | 58 | 45 | 35 | 58 |
| jitter mag | 45 | 28 | 15 | 58 |
| jitter interval (ticks) | 2 | 3 | 4 | 1 |
| freestanding | ON | ON | ON | **OFF** |
| at-targets | OFF | ON | OFF | OFF |
| on-shot AA | ON | ON | ON | OFF |
| air desync | ON | ON | ON | ON |
| anti-BF | ON | ON | **OFF** | ON (25°) |
| fake-duck assist | ON | ON | ON | ON |
| move-desync override (v3.2) | **ON** | OFF | OFF | OFF |
| pitch jitter (v3.0/3.2) | **ON** | OFF | OFF | OFF |
| move-fakeduck (v3.0/3.2) | **ON** | OFF | OFF | OFF |
| NL fake-lag limit | 7 | 5 | 3 | (varies) |

### Sel01-Config V2-V3 feature timeline

- **V2.0-2.1**: Re-enable subsystems after v1.13 BISECT confirmed stable baseline. Drop `nl_override` on Peek Assist hotkey (use gingersense pattern: `:get()` read). Switch player_hurt to JAG0YAW entity-compare.
- **V2.2**: Drop visual NL :override calls (Scope Overlay etc are combo elements).
- **V2.3**: Air-AA extras — rapid inverter flip + max jitter boost + optional fake-duck while airborne, 1.5× anti-BF variance, transition handling clears overrides on land. Arrow indicator follows `aa_jitter_dir` when our AA override on (was reading NL inverter, always pointed right).
- **V2.4-2.5**: AI Peek iteration (sidemove cycle) — later replaced by Peek Boost.
- **V2.6**: Debug stats accumulator (shots fired/hit/miss + total dmg + biggest + 1-taps) + dump button.
- **V2.7-2.8**: Peek Boost as hold hotkey — drives NL hitchance + mindmg :override on rising/falling edge of our own hotkey (NL Peek Assist hotkey unchanged, user binds same key for 2-in-1). Hits-Taken log (cap 10) with AA-state snapshot per incident: desync / air-override / anti-BF / on-shot / fd-assist / freestanding / airborne / velocity / peek-boost / jitter direction.
- **V2.9**: aim_ack hit-detection fixed (nil = HIT, was MISS). Unified event log: HITS + MISSES (with reason) + KILLS (from `events.player_death`) — color-coded top-left, default ON in all presets.
- **V3.0**: Hitbox stats moved from aim_ack to player_hurt (hitgroup-based). Two name maps factored out. Anti-headshot extras (pitch jitter via NL Pitch combo set to "Jitter Down/Up", auto-fakeduck while moving above velocity threshold). Both default OFF until opted in.
- **V3.1**: Peek Boost UI label shortened (text overflow). Print Recommendations button (data-driven advice based on stats). Anti-HS Bundle quick-toggle.
- **V3.2**: Move-AA extras (running on ground above velocity threshold) — own desync magnitude, rapid inverter flip, max jitter boost. Aggressive preset auto-enables full anti-HS bundle (pitch_jitter + move_fakeduck + move-AA extras).

### Common Sel01-Config gotchas (each has bitten)

- **`events.antiaim` cmd-writes crash CSGO** (v1.6 incident). No other NL script does this. Always drive AA through `nl_refs.aa_bodyyaw_l/r:override(...)`.
- **Combo `:set(int)` freezes menu** (v1.4 incident). Pass the option string. Better: skip combo `:set` in button callbacks entirely (decorative-only).
- **Preset button callbacks must not synchronously mutate UI** (v1.5 incident). Set `pending_preset = name`; drain from createmove.
- **`ui.find` raises popup-dialog on missing paths** (v1.3 incident). Use `pui.find` as primary.
- **Single `events.render:set`** — registering twice overwrites the first hook. Everything that needs render lives inside the one handler.
- **Forward-decl `update_clantag`** as `local update_clantag = function() end` BEFORE the render closure, then reassign later. Closures capture the upvalue, not the global.

## Common mistakes to avoid

- Don't add UI elements without `pcall` around `:set_callback`
- Don't introduce 5th arg in `:slider` (breaks display)
- Don't use `\a{Color}` accent codes in `:button` labels (renders blank)
- Don't mutate resolver state in `events.render` (race with createmove)
- Don't call `print` directly — use `cs_log` / `cs_log_color` / `cs_log_verbose` / `cs_log_debug`
- Don't add features without pcall around new NL API calls (version variance)
- Don't forget event unhook in shutdown handler
- For per-weapon: when user has good manual NL settings (SSG-08 hc=72), use `exp_respect_man` to SKIP override
- For HUD: use `render.screen_size()` for resolution-independence
- **Adaptive features must bound adaptation range** — runaway tuning breaks resolver
- **Cache invalidation: key on `missed` count AND eye_yaw drift** (>20° = invalidate)
- **First-shot fallbacks: NEVER return `eye_yaw` unchanged** — always offset (V6 added `-Guess` modes, V9.6 added Air-Guess)
- **When bumping `SEL01_VERSION`: update constant + `@version` header together** (3 visible touchpoints)
- **Forward-decl block MUST come before any UI element** that uses those locals in callbacks
- New learning paths: feed `mode_stats_update` AND `learning_update_hit` AND `record_player_shot` AND `session_record` consistently
- Don't expand `confidence()` sample weight beyond cap 60 (leaves room for stddev/age/miss-rate factors)
- **Filter "fallback" modes from best_mode storage** (V9.0): never save `BF:*` or `*-Guess` or `Init` as best_mode — they're emergency paths
- **Strip mode-suffix chains before appending** (V8.9): `Static-Meas-Recall-Recall-Recall...` is bug, suffix-chain must be flat
- **Init-mode entries pollute stats** (V8.7+V9.1): skip from `mode_stats_update` + `record_player_shot` + `cs_log_debug` HIT/MISS-FULL
- **Local count > 200 in main chunk = parse error** — wrap new top-level locals in `do...end` (clipboard FFI + log_buffer ring use this)
- **Lua 5.1 in NL sandbox**: no `goto`, no integer division, no bitwise ops (use `bit.*`), no JSON lib (use V8.3 encoder)
