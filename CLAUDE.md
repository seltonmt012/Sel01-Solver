# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Three Neverlose **CSGO** (legacy build, NOT CS2) Lua scripts for HvH / rage play. Solver + Config run together inside the same NL client sandbox and communicate only via NL's own events/UI, never directly. WalkBot is a standalone movement bot (no cross-talk; aiming stays with the ragebot).

| Script | Role | Working copy | NL load path |
|---|---|---|---|
| **Sel01-Solver** (`Sel01-Solver.lua`, ~6100 lines, v9.79) | Resolver: per-player AA learning, JSON export, HUD/ESP overlay + top-right event ticker, FFI clipboard copy-logs, Sel01-Roast chat-spam, AA Advisor (in-menu panel + Coach-chat to CSGO say) | `C:\Users\Seltonmt\Desktop\sazz\aron\ownlua\Sel01-Solver.lua` | `E:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive\nl\scripts\Sel01-Solver_59853.lua` |
| **Sel01-Config** (`sel01_config.lua`, ~2000 lines, v3.29) | Companion: AA presets (Aggressive/Dynamic/Defensive/Spin), anti-resolver bundle (defensive on hit-taken, slow-walk boost, fake-lag variance, yaw base rotation, side-streak limit, magnitude jitter), anti-HS extras (pitch jitter, move-fakeduck), peek-boost hotkey, comprehensive Dump Debug Stats, hits-taken log with AA-state snapshots, kill/miss/hit event log top-left, watermark + indicators + rotating AA arrow | `C:\Users\Seltonmt\Desktop\sazz\aron\ownlua\sel01_config.lua` | `E:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive\nl\scripts\sel01_config_59908.lua` |
| **Sel01-WalkBot** (`Sel01-WalkBot.lua`, ~1200 lines, v1.7) | Standalone walk-bot — MOVEMENT only, aiming stays with the ragebot. CSGO nav-mesh A* routing (greedy trace-based fallback), distance-tiered engage (approach / hold-corner shoulder-peek / slow-walk peek / crouch-when-exposed), roam (nav route / HUNT last-seen enemy / leave-spawn / wander), auto-learn routes + bad-spots (persisted), no-jump by default, auto-primary-weapon | `C:\Users\Seltonmt\Desktop\sazz\aron\ownlua\Sel01-WalkBot.lua` | `E:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive\nl\scripts\Sel01-WalkBot_60027.lua` |

**Dual-copy rule (MANDATORY).** After every Edit/Write to either working copy, immediately overwrite the matching NL file (same path, no new files, no renames). PowerShell one-liner: `Copy-Item -Force -LiteralPath '<working>' -Destination '<nl-path>'`. The git repo only tracks working copies — the NL copies need the mirror so reload in NL picks up the change.

**Cloud-copy rule (Sel01-Solver ONLY, MANDATORY since 2026-07-19).** The Solver is ALSO loaded from the NL cloud folder, so every Solver edit is now a **triple-copy**: working → NL local (`Sel01-Solver_59853.lua`) → cloud (`C:\Users\Seltonmt\Desktop\sazz\aron\neverlose hackvshack.net\nl_cloud\scripts\5_Sel Solver.lua`, note the space in the filename → use `-LiteralPath`/`-Destination`). Config + WalkBot are NOT in the cloud folder (it holds unrelated scripts: 6_maycry, 7_angelnbone, 8_angeln, 9_premiumloader, 10_scertiy) — Solver is `5_Sel Solver.lua`.

**Version constants — keep all touchpoints in sync per script:**
- Sel01-Solver: `local SEL01_VERSION = "X.Y"` + file-header `@version X.Y` + **decorative header box `Version: X.Y` (line 4)** + 3 visible mentions (load-banner, UI label, HUD corner)
- Sel01-Config: `local SEL01_CFG_VERSION = "X.Y"` + file-header `@version X.Y` (no HUD mention; load banner reads constant directly)
- Sel01-WalkBot: `local SEL01_WB_VERSION = "X.Y"` + file-header `Version: X.Y` + `@version X.Y` (HUD reads the constant)

WalkBot runtime data (private, gitignored — same `nl/Sel01-WalkBot/` folder the navs are copied into):
- Per-map learned route: `nl/Sel01-WalkBot/<map>.txt` (plain "x y z" lines, files.read-safe text)
- Per-map learned bad/stuck spots: `nl/Sel01-WalkBot/<map>_bad.txt`
- Copied nav meshes: `nl/Sel01-WalkBot/<map>.nav` (binary, read via kernel32 — see WalkBot section)

Solver runtime data (private, gitignored):
- Persistent learning (Lua-table fast-load): `nl/Sel01-Solver/learned.lua`
- JSON backup + human-readable: `nl/Sel01-Solver/learned.json`
- Copy-logs file fallback: `nl/Sel01-Solver/last_logs.txt`

Solver architecture + bug history + UI doc lives in `README.md`. NL API docs at `https://docs-csgo.neverlose.cc/readme.md?ask=<keywords>` — consult before guessing API names. Config script has no separate README; this file is canonical.

**Git repo.** Remote: `origin https://github.com/seltonmt012/Sel01-Solver.git` (branch `master`). `.gitignore` excludes private data + `.claude/` + `.vscode/`. Auto-commit + push on version bumps per project policy.

## Verify changes

```powershell
luac -p Sel01-Solver.lua    # resolver
luac -p sel01_config.lua        # config
luac -p Sel01-WalkBot.lua       # walk-bot
```

`luac` from scoop (`C:\Users\Seltonmt\scoop\apps\lua\current\bin\luac.exe`). Must exit clean. No test infrastructure — runtime errors only surface when user reloads in NL and reports. After luac passes, **dual-copy to NL** (see paths table above) so the next NL reload sees the change.

**Local limit warning** (V9.3 hit-point, V9.19 + V9.20 + V9.21 escalation): Lua 5.1 main-chunk limit = 200 locals. Solver is AT THE CAP. Since v9.19 new helpers + UI groups + buttons + state tables are declared as MODULE GLOBALS (no `local` keyword) instead of locals — captures from local scope still work (lexical) because the function is defined after the local is declared. Globals affected: `sel01_session_desyncs`, `session_push_desync`, `adaptive_guess_mag`, `alt_side_pick`, `g_advisor`, `advisor_state`, `advisor_*` helpers + buttons, `event_ticker`, `cs_event_*`, `esp_event_ticker`, `advisor_lbl_*`, `render_event_ticker`. The clipboard FFI + log_buffer ring still use the `do...end` pattern from earlier days. Pick globals for ANYTHING new that needs to be callable across the file — `do...end` is only useful for purely local helpers that ALL their call sites can fit inside one block.

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

**Never lua-override NL ragebot Hit Chance / Min Damage / Hitboxes / Safe Points / Body Aim from auto-paths** (V9.18 hard lesson). User manually tunes NL Selection (HC 72 / MinDmg 100 / multi-hitbox Head+Chest+Stomach / Safepoints Prefer / Hitbox Safety Arms+Legs+Feet) and the lua MUST respect that everywhere except a tight whitelist of emergency paths. v9.4-v9.17 stacked "smart" downgrades (HEAD-FOCUS hc=40 mindmg=25, per-weapon sniper hc=50 mindmg=80 head-only, counter-fire mindmg=1, close-miss followup mindmg=1, jump-shot mindmg=35) — each looked reasonable but stacked into firing at half the intended confidence + accepting 3-6 dmg body taps. v9.18 deleted ALL of them. Hit rate jumped from ~50% to 85.7% in the next session. `ctx:override_min_damage(...)` is now banned globally. Allowed overrides: counter-fire (hc 15 + force head + safepoint off + multipoint; NEVER touch mindmg), close-priority point-blank (tiered hc 5-20 distance), close-miss followup (hc 10 + head + safepoint off), force-baim (user-explicit slider — hitbox + hc decay), jump-shot (head + low hc when airborne), NoSpread / Head-Strict (user-explicit toggles). Any new feature that touches `ctx:override_hitchance / override_hitbox / override_safe_point` is suspect — justify why NL can't do it naturally before adding.

**EMA sample-ramp + drift-bump + AA-switch hard-reset** (V9.26 + V9.30 + V9.39 measurement layers). The per-player `measured_desync` EMA settles at alpha 0.30 (slow / anti-noise) once well-sampled. Three acceleration layers stacked on top: (0) **V9.39 sample-count ramp** — the FIRST hits weight heavier so a cold enemy converges fast: alpha 0.55 on samples ≤1, 0.42 on samples ≤3, then 0.30. Self-decaying (no thrash). (1) drift-bump — when `|actual - EMA| > 5°` and `samples >= 1`, alpha jumps to ≥0.55 so a drifting enemy converges in 2-3 hits. (2) hard-reset — when `|actual - EMA| > 10°` and `samples >= 3` (and NOT bimodal), the EMA is REPLACED with the new actual verbatim and `desync_samples` decimated to `floor(samples * 0.4)`. Catches mid-round AA-preset switches. All three layers run on the global EMA AND both per-side EMAs (`measured_left`/`measured_right`) independently. Verbose logs print "AA-switch hard-reset idx=N L/R/global EMA X→Y (diff=Z)".

**Server-fail vs resolver-fail discrimination is the core of miss-handling** (V9.24-V9.44, the dominant theme of recent work). On a miss the `aim_ack` path classifies WHY before reacting, because the wrong reaction oscillates. Key signals: `bt = event.backtrack` (high = NL replayed a STALE record = netcode, NOT our fault — never flip side); `ack_angle_err = ||delta| - measured|` which measures MAGNITUDE accuracy — a true wrong-SIDE miss keeps `|delta| ≈ measured` (small err), a magnitude overshoot on the correct side gives LARGE err (so flipping side on err>5 is BACKWARDS — V9.42 fix); `ack_side_bad` (learned dom/streak data contradicts the shot side) is the real side signal. Decision (generic correction path): high bt → never flip; `ack_side_bad` → flip; magnitude error with a measurement → keep side + let BF cycle the magnitude; blind first-contact → explore other side. Correct-angle server rejects schedule ONE same-side `BF:retry` (V9.38), and that retry shoots the **learned** magnitude, never the just-shot delta (V9.44 — storing the shot delta memorised overshoots into a feedback loop on locked enemies). High-bt (`>6`) `correction`/`prediction error` misses feed `bt_fail_count` → `backtrack_resistant` after 2 fails or one `bt>12` (V9.40+V9.43), which gives predict_ticks-1 + full-spread multipoint at close range.

**Alt-mode dom-bias** (V9.19). `Predicted-Alt`, `Air-Alt`, `Slow-Alt`, `Still-Alt` previously did blind `-last_hit_side` flip. On a `streak{L=9 R=0}` enemy that = miss every time. `alt_side_pick(s)` returns the dom side when one side leads by 2+ samples, else 0 (blind alt). Callers fall back to `-last_hit_side` only when the helper returns 0.

**Adaptive guess magnitude** (V9.19). Hardcoded `±29°` fallback in `Static-Guess / Networked-Guess / LBY-Snap-Guess / Air-Guess` paths was systematically under-shooting lobbies with ~37-38° modal desync. Replaced with `adaptive_guess_mag()` returning the running median of the last 20 hit-derived measurements across the whole session (clamped 20-58). Pushed from `aim_ack` HIT path via `session_push_desync(actual)`. `LBY-Snap-Guess` cycle anchors on this value too: `{base, min(58, base+16), 58}` instead of `{29, 45, 58}`.

**LBY-Snap-Guess flip only on mismatch** (V9.24). Previously every LBY-Snap miss flipped `last_hit_side`. But misses with `delta = measDesync` exactly are server-side backtrack failures (NL netcode), not our side error — flipping then = next attempt picks wrong side = oscillation. Now we compute `angle_err = |our_delta - measured|` and flip only when `> 5°`. When ≤ 5°, log "server-side fail, no flip".

**Predicted-Alt / Predicted-Streak per-side magnitude** (V9.22 fix, was the biggest single-bug regression in the v9.19-v9.21 era). `_pick_first_shot_impl` computes `desync` at the top using `guess_side = last_hit_side` and the result feeds `eye_yaw + desync * side * mult` at the end. When Alt-mode picks the OPPOSITE side via dom-bias, that cached `desync` is for the WRONG side. Fix: when `used_measured = true` (Predicted-Alt or Predicted-Streak path picked the side from learned data), re-call `effective_desync(s, max_desync, chosen_side)` to fetch the per-side value, AND drop the `0.85 mult` (an already-correct measured magnitude does not want undershooting). `effective_desync` itself was loosened in V9.24 (sample threshold `2 → 1`) so a single hit beats blindly shooting at `max_desync`.

**NL `:name(string)` updates label / button text at runtime** (verified pattern from `bloodwings_33877.lua:958`, `grenade_helper_33880.lua:1259`, `frostlive_33878.lua:4407-4429`). Combo OPTIONS cannot be dynamically replaced (no `:set_items`), but a label's displayed text can. The AA Advisor panel (v9.23) pre-creates 11 label slots in `g_advisor` and calls `advisor_panel_update()` to rewrite them all via `:name()` on each Refresh / Next button. Lets the panel act like a dynamic content area inside the NL menu without an on-screen overlay.

**Console multi-fallback writer** (V9.25). `cs_event_console(text, r, g, b)` writes a line via `client.color_log` → `client.log` → `print` in order, pcall'd. NL builds vary on which writer is exposed. Use this whenever you want a HIT/MISS/KILL to land in the in-game console regardless of `log_enabled` toggles. Each call also pushes to `log_buffer` so the 📋 Copy button captures the history.

**`utils.console_exec("say <text>")`** is the working pattern for sending CSGO chat messages from Lua (Sel01-Roast since v8, Coach-chat send-to-chat since v9.26). Length limit ~127 chars per say. Strip embedded `"` defensively. `engine.execute_client_cmd` is the fallback when `utils.console_exec` isn't exposed.

## File layout (Sel01-Solver.lua, ~5200 lines)

Line numbers are approximate — they drift as features are added. Use `Grep` to find a specific function. The shape of the file is:

| Region | Purpose |
|---|---|
| Header (top) | Version constant + `@version` header + `require`s + `cs_log` helpers + raw refs |
| FFI clipboard helper | Wrapped in a `do...end` block to keep its 2 locals out of the main-chunk budget |
| Loading-screen overlay | FFI URL download + sidebar gradient; calls into `events.render` |
| **EARLY FORWARD-DECL BLOCK** (~line 165) | `SteamMemory`, `LearnedModel`, `mode_stats`, `PlayerState`, `tick_cache`, `NormalizeAngle`, `mode_stats_update/dump`, `confidence`, `session_stats`, `record_player_shot`. MUST come before any UI element with a callback that references these. |
| UI build | Tab `Sel01-Solver`, ~11 groups, 6 preset buttons, 4 Smart Strategy combos, ~20 experimental toggles, V9.20 **🎯 AA Advisor group** (Refresh / Next / Show / Show-ALL / 📨 Send-tips-to-chat buttons + 11 dynamic label slots), V9.21 **Event Ticker** ESP/HUD toggle |
| V9.19+ globals block | `sel01_session_desyncs` ring + `session_push_desync` + `adaptive_guess_mag` + `alt_side_pick`. Declared as MODULE GLOBALS (no `local`) — at the 200-local ceiling. |
| V9.20+ AA Advisor block | `advisor_state` + `advisor_rebuild` + `advisor_show` + `advisor_panel_update` + `advisor_chat_send` (all globals) + `advisor_build_recs` (chat + panel shared formatter). |
| V9.21+ event-ticker block | `event_ticker` ring + `event_ticker_push` + `cs_event_hit/miss/kill/info/console` (all globals, multi-fallback console writer). |
| Logging buttons | 📋 copy-logs (FFI clipboard + file), 🗑 reset learning / session, dump, status |
| Stats + confidence | V5 mode-stats audit (V8.9 normalize `-Recall`) + V5+V9.1 confidence (real-vs-seeded weighting) |
| Persistent learning | V4 + V8.3 JSON encoder + V8.9 migration + V8.6 6-pattern sid + manual reset/export buttons |
| Helpers + presets | mode_str / baim_hb_id / safe_set / apply_preset — 6 presets (aggressive / dynamic / defensive / nospread / ssg_pro / head_only) |
| Log gates | cs_log / verbose / debug + `log_buffer` ring (cap=200) push + V8.8 buffer-from-verbose expansion |
| FFI + math | `AnimatingStateInfo`, `GetAnimState`, `GetMaxDesync`, `RebuildServerYaw` |
| PlayerState meta | `setmetatable` on the forward-decl'd table — fields for V3-V9.30 incl `real_left/right`, `def_delta`, `still_ticks`, `yaw_rate_buf`, `bt_fail_count` |
| `events.aim_ack` | Snapshot match, per-side EMA with V9.26 drift-bump + V9.30 hard-reset, V8.2 correction-flip, V9.6+V9.24 LBY-Snap flip-on-mismatch, V9.3 def-AA fingerprint, non-resolver-miss skip, Init-mode log filter, V9.21 `cs_event_hit/miss` calls |
| `update_jitter` + `classify_aa` | V9.0 yaw_rate clamp 720°/s + V8.0 consistency buf + V9.5 spinner-shortcut + V9.10 7-tick hysteresis + 2s lockout |
| `_pick_first_shot_impl` | All resolver modes: known-player fast-path, V8.4 Still-Server/Meas/BFGuess, V7.8 slow-walker, V9.2 Slow-Alt, AA-classify shortcuts (V9.3 Spinner-Rot), LBY-Snap, jitter-lock, V9.22 Predicted-Alt/Streak per-side mag + V9.19 dom-bias, Networked variants, V9.19 adaptive guess fallback |
| BF + per-tick caches | `pick_bruteforce_angle` (V9.5 def_delta cycle, V7.8 finer cycle for static/slow) |
| `resolve_player` | Dormancy reset + V9.2 decay measured + V4 learning boot + V8.2/V9.6/V9.19 air-branch + slow + V8.4 stationary detect + V9.0 AA-classify + V4+V9.3 extrapolation (4 gates + dist + per-weapon + ping) + V7.1/V8.6 passive seed |
| createmove + weapon_fire + aim_fire | V8.4 periodic auto-save 10s + LBY snap + V7.8 last_shot_side + V9.21 fake-lag variance / yaw rotation / side-streak tick |
| `events.ragebot_target` | 10-stage override stack (V5 shot-cooldown → V9.4 close-priority → V6 air-block → V9.11 counter-fire → cancel-conf → per-weapon (V9.18 sniper-only respect) → V9.6 fast-fire → NoSpread → V7.9 head-strict → V9.12 close-miss followup → V8.5 jump-shot → V8.4 force-baim). V9.18 deleted HEAD-FOCUS + per-weapon downgrades; all `override_min_damage` calls stripped. |
| ESP + HUD-corner | V8.0 throttled compute / per-frame draw from cache + V7+V8 learning indicators (`👁/·/★/🔒`). V9.21 `render_event_ticker` (top-right HUD log) — `render_advisor_panel` was removed in V9.23, advisor moved into NL menu |
| Roast + death + shutdown | Sel01-Roast chat spam + `player_death` (V9.21 also fires `cs_event_kill`) + V8.6 force-save shutdown handler |
| Load banner | Full diagnostics + V4 `learning_load` + V8.9 migration call + V6 cleanup + V9.x change log lines |

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
9. **`log_buffer`** — V9.3 ring-buffer (V9.10 cap raised 80 → 200, O(1) push). Captures HIT/MISS-FULL, UNKNOWN states, close-priority/cancel-conf/snapshot/aa-commit/correction-flip/jump events. V8.8 also feeds key verbose events regardless of verbose-toggle.
10. **Event ticker** (V9.21, top-right of screen, toggle in ESP/HUD) — last 12 HIT/MISS/KILL events color-coded with 5s fade. Driven by `cs_event_hit/miss/kill` calls at the `aim_ack` and `player_death` sites. Console-mirror via multi-fallback writer (`client.color_log` → `client.log` → `print`) so events appear without any toggle.
11. **AA Advisor** (V9.20-V9.29, group `🎯 AA Advisor` in Sel01-Solver tab). Buttons: 🔁 Refresh (snapshots tracked PlayerState entries by hits desc), ▶ Next (cycle selected), 💡 Refresh recommendations, 📜 Dump recs for ALL to console, 📨 Send tips to CSGO chat (selected) — Coach-chat fires 2-4 `say` lines via `utils.console_exec`, each addressing the enemy by name with diagnosis + WHY + fix. V9.29 has 3 wording variants per category picked deterministically from the enemy name hash; V9.30 doesn't change Advisor wording. Recommendations are personalised with real stats (streak counts / dom counts / per-side magnitudes); BIMODAL detection (per-side mag diff > 10°) gets its own line. The panel itself renders INSIDE the NL menu via 11 pre-created label slots updated through the `:name(string)` method (V9.23 — confirmed pattern from bloodwings / frostlive / grenade_helper).

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
- **V9 (early)**: V9.0 yaw_rate clamp 720°/s + AA-stability + BF filter, V9.1 real-vs-seeded sample tracking + Init log filter, V9.2 decay measured + dist-scale + Slow-Alt, V9.3 Spinner-Rot + ping-aware extrap + per-weapon predict + def-AA delta fingerprint + log_buffer ring, V9.4 SSG-Pro tuned, V9.5 BF def_delta cycle + tighter spinner detect, V9.6 fast-fire + Air-Guess + LBY auto-flip, V9.7 Still-Alt + still/slow hard-reset on yaw spike, V9.8 counter-fire (events.weapon_fire hostile detect → bypass cancel-conf), V9.9 bulk easy-wins (dominant-side conf-boost / 2-miss mode-blacklist / crouch-aware hitbox / hostile-fire HUD / per-tick lp+wc cache / symmetric-data low-conf / backtrack-fail penalty / yaw-consistency extrap-boost), V9.10 log_buffer cap 80→200 + AA-type hysteresis tightened (7-consecutive + 2s lockout + anti-flap 5s freeze if >3 commits in 10s), V9.11 enhanced counter-fire (force head + safepoint-off + HC 15 + multipoint) + fast-fire tier system (conf 50/70/85 thresholds), V9.12 close-range first-miss follow-up (Aggressive + missed≥1 + dist<1000 → HC 10 + force head + safepoint-off)
- **V9.13-V9.53 (recent)**:
  - **V9.18 (major)** — stripped ALL `ctx:override_min_damage` calls + deleted HEAD-FOCUS block + sniper always-respect + auto-rifle/heavy-pistol overrides removed. User's NL Selection (HC 72 / MinDmg 100 / multi-hitbox / SafePoints Prefer) is now the source of truth globally. Hit rate ~50% → 85.7% in one session. ([memory: feedback_never_override_nl_config.md](file:../.claude/projects/C--Users-Seltonmt-Desktop-sazz-aron-ownlua/memory/feedback_never_override_nl_config.md))
  - **V9.19** — `sel01_session_desyncs` ring (cap 20) + `adaptive_guess_mag()` median replaces hardcoded ±29° in all `*-Guess` fallback paths + `alt_side_pick(s)` dom-bias for Predicted-Alt / Air-Alt / Slow-Alt / Still-Alt
  - **V9.20** — AA Advisor tab (Refresh / Next / Show / Show-ALL buttons, advisor_rebuild + advisor_show, recommendations based on aa_type + dom + mag + miss-rate)
  - **V9.21** — Event ticker (top-right toggle in ESP/HUD) + `cs_event_*` helpers with 3-fallback console writer
  - **V9.22** — Predicted-Alt / Predicted-Streak magnitude fix (recompute `effective_desync` with chosen side, drop 0.85 mult on measured paths)
  - **V9.23** — Advisor panel moved INSIDE NL menu via 11 label slots + `:name()` runtime text updates; on-screen overlay removed
  - **V9.24** — `effective_desync` sample threshold 2 → 1 (one hit beats blind 58°) + LBY-Snap-Guess flip only when `|delta - measured| > 5°`
  - **V9.25** — `cs_event_*` console multi-fallback (HIT/MISS/KILL print to in-game console without any toggle) + Advisor wording rewritten in plain English with color-coded DO/why/warn/good
  - **V9.26** — 📨 Send tips to CSGO chat button (Advisor → utils.console_exec say lines) + EMA drift-bump (alpha 0.30 → 0.55 on |actual - EMA| > 5°)
  - **V9.27** — Coach-chat addresses `@enemy_name` (name trimmed to 18-22 chars to fit 127-char say limit) + up to 4 concrete tips per send
  - **V9.28** — Coach-chat each line explains WHY enemy's AA is exploitable + HOW to fix (was just stating facts)
  - **V9.29** — Coach-chat 3 wording variants per category (deterministic by enemy-name hash) + data-driven WHY (real streak / dom counts) + BIMODAL detection (per-side mag diff > 10°)
  - **V9.30** — AA-switch hard-reset: when `|actual - EMA| > 10°` and `samples >= 3`, EMA is REPLACED with actual + `samples` decimated to 40% (catches locked-target preset switches in 1 hit instead of 3-4)
  - **V9.31** — circular stddev in `confidence()` (arithmetic mean of wrap-around yaws exploded at the ±180 seam → fake 180° stddev → conf wrongly tanked) + real-sample counting moved OUTSIDE per-side guard (conf no longer capped at 50 when per-side toggle OFF) + generalized server-side-fail guard (was LBY-only)
  - **V9.32** — bimodal-switch detection (`s.bimodal` flag off stable per-side EMAs, hysteresis >12 set / ≤8 clear) suppresses the v9.30 GLOBAL hard-reset thrash on two-mode enemies + event ticker shows Δ/meas/conf/side + `RebuildServerYaw` nil-sentinel (no resolve-to-0° on reconstruct fail)
  - **V9.33-V9.34** — air-branch hardening: push air resolves to `recent_resolved` (cancel-conf/conf air-aware), snapshot tick-window guard, per-side magnitude in air corr-path, `update_jitter` now runs in air (correct aa_type on landing)
  - **V9.35** — fast-fire tightened (only fires fast on stddev<12 + well-sampled, hc floors raised 30/45). Stopped marginal early shots catching bad backtrack records
  - **V9.36** — snapshot-match regression fix (v9.33 matched ack-time tickcount → grabbed most-recent snapshot, mis-learned sides on rapid fire; restored `event.tick` matching)
  - **V9.37** — Air first-contact (Air was worst @25%): air guess magnitude biased high + first-contact side uses steam-mem dom
  - **V9.39** — sample-count EMA alpha ramp (0.55 hits 1-2, 0.42 hits 3-4, then 0.30) on global + both per-side — converges in 2-3 hits not 5-6
  - **V9.40** — point-blank stale-record fix: non-sniper close-priority now forces multipoint (was sniper-only) so a single-point head shot stops whiffing on a closing enemy with correct angle + high bt; + bt-driven backtrack-resistance (high `event.backtrack` on `correction`/`prediction error` counts, was reason-string-only)
  - **V9.41** — air-guess magnitude per-player passive-aware: uses THIS enemy's measured/passive-seeded desync before the blind floor (v9.37's `max(median,42)` overshot low-desync air enemies ~30° and ignored 50+ passive obs); blind floor softened 42→36
  - **V9.42** — side-flip from SIDE evidence not magnitude error: `ack_angle_err` is a magnitude metric, so old `err>5 → flip` flipped the correct side on magnitude misses. Now flip only on learned side-conflict or blind first-contact; magnitude misses keep side + BF cycles magnitude
  - **V9.43** — backtrack-resistance escalates faster: resistant flag flips after 2 high-bt fails OR one `bt>12` (was 3) — pairs with v9.40 full-spread multipoint to catch stale records by shot 3
  - **V9.44** — serverfail-retry magnitude fix: retry shoots the LEARNED desync, not `max(|shot delta|, measured)`. The old `max()` memorised a kept-side magnitude OVERSHOOT and `BF:retry` repeated it — a feedback loop fatal on a LOCKED enemy (idx=3, 18 hits, known 22.3°, shot 41.9° twice)
  - **V9.45** — seed-only keep-side fix: the generic-path "magnitude matched measured → server fail, keep side" branch now requires a REAL hit (`real_active >= 1`) OR genuine backtrack (`bt > 6`). On a never-hit enemy `measured_desync` is pure passive seed; matching it proved nothing and froze the side on the WRONG guess forever (logs: idx=8, p_hits=0/2, seed 52.2°L, shot left twice, 2nd shot `bt=0`). Else explores the other side.
  - **V9.46** — teleport-on-peek detection: per-resolve horizontal origin delta vs `max(speed,60)*dt + 16` reveals a blink-peek (lag-switch / fakelag-flush / teleport-peek). On detect, `s.tp_peek_active` time-boxes 0.4s that (a) disables extrapolation (yaw_rate from before the blink can't predict the landing) and (b) forces full-spread multipoint at close-priority. Reacts on the FIRST peek instead of after 2 misses; never touches side/EMA. Per-player `prev_origin_x/y/t` + `tp_peek_until` fields.
  - **V9.47** — side-conflict overrides high-bt keep on large angle error: the generic-path `do_flip` chain now flips on a learned side-conflict (`resolver_side_conflicts`) even under `bt > 8` WHEN `ack_angle_err > 10` (or no measurement). A clean stale-record reject leaves err~0; a large magnitude error alongside a side-conflict = wrong side AND wrong magnitude, bt incidental. Old order let `bt>8` short-circuit before checking side_bad → kept + retried wrong side (logs: idx=8 1 R-hit, shot L -21.6 vs meas 39.5 err=17.9 bt=12 — next real hit confirmed R). err~0 + side-conflict still keeps (switch-stale / v9.42 overshoot / v9.44 locked protected).
  - **V9.48** — `alt_side_pick` uses REAL-hit dominance when both sides have real hits: the function keyed on `samples_left/right` which include passive + seeded entries, so the seeded lean mispinned a genuine 50/50 switch enemy. When `real_left >= 1 AND real_right >= 1`, dominance comes from `real_left/right` and balanced real data alternates off `last_hit_side`; one-sided enemies (a real side empty) keep the old seeded path so the `streak{L=9 R=0}` dom case is unaffected (logs: idx=4 sl=3 sr=1 pinned LEFT, real hits 1L/1R, correct side RIGHT → Predicted-Alt 0/2).
  - **V9.49 (big stat-accuracy win)** — confirmed server-fail keeps no longer pollute hit-rate stats. A correct-angle miss the server rejects (`do_flip == false` keep branch: high `bt`, `err~0`, side kept) is netcode, not a resolver fault. A `local server_fail_keep` flag set in both the LBY-Snap and generic KEEP branches gates `mode_stats_update` + `record_player_shot` + `learning_update_miss` (mode-blacklist already skipped these since V9.31 — this finished the job). `s.missed` STILL increments so BF-cycle + force-baim escalation advance. New counters `s.serverfail_misses` (per-player) + `sel01_session_serverfails` (session global). Logs: idx=9 fired the same correct -21.8° ×3 into a declining stale record (bt 20→10→5) then hit; these dragged session ~56% when true resolver rate was ~82%. **Also: never-hit explore** — after 2 consecutive correct-angle keeps on a `real_active==0` enemy, flip once to break a frozen wrong-side guess; a single real hit disables it.
  - **V9.50** — surfaced the V9.49 filter: copy-dump prints a 2nd `[SESSION]` line (`N server-fails filtered` + raw pre-filter %); HUD corner shows `Netcode: N server-fails filtered`. Counter clears on Reset Session Stats. Pure observability.
  - **V9.51-V9.53 (on-model ESP)** — moved per-enemy intel ONTO the model. `esp_push_shot(s, kind)` (global helper) called from the `aim_ack` HIT / MISS / `server_fail_keep` paths records `s.last_shot_result` + `s.last_shot_result_time` + a 6-entry `s.shot_history` ring. Three new UI toggles (globals, dodge the 200-local cap): `esp_wedge` / `esp_flash` / `esp_enh`, all default ON in the SSG-Pro preset. Visuals: (A) **desync wedge** — two `render.line`s from the pelvis, white = real `last_eye_yaw`, mode-color = resolved `last_resolved`; (B) **hit/miss flash** — ~0.45s fading box around the model, green=hit/red=miss/blue=server-fail; (C) **netcode tag** — `⚠×N bt pk` (serverfail_misses / backtrack_resistant / tp_peek); (D) **AA-icon** `▬⇄≈⟳`; (E) **shot-dots** — last 6 results as colored squares; (F) ~~side-dom bar~~ (added V9.51, REMOVED V9.53 as redundant). **V9.52** rewrote the label in plain words (too big), **V9.53** shrank back to ONE compact symbol line `⇄ → 29° ★` (font size 3, learn-icon 🔒/★/·, confidence = the bar only). Iterated label legibility per user — keep it ONE short line, symbols not words, no redundant second bar.
  - **V9.54-V9.59 (recent)**:
    - **V9.54** — serverfail-retry magnitude PER-SIDE on bimodal enemies. The retry froze the GLOBAL desync EMA; on a two-mode enemy (L=46°/R=30°) the average swings mid-round and the kept side re-fired a wrong magnitude for up to 64 ticks. New `ack_side_measured` (in `aim_ack`) mirrors `effective_desync`'s per-side pick and feeds both `resolver_note_serverfail_retry` callers.
    - **V9.55 (stat honesty)** — `server_fail_keep` now reuses the existing `ack_serverfail_like` signal (`err<=5 OR bt>8`) the mode-blacklist already trusts, instead of filtering EVERY kept-side miss. A `bt=0` kept-side miss is the resolver's OWN side-misprediction (switch/bimodal), not netcode — it now COUNTS in stats (was inflating session 76.5%→96.3%). No aim change.
    - **V9.56** — LBY-Snap-Guess miss-flip is bt/measurement-aware (matches the generic V9.42/V9.47 logic it never had). `err` is meaningless without a measurement (first contact, measDesync=0 → err=inf), and `bt>8` is a stale-record reject not a side error: `lby_flip = ack_side_bad or (ack_measured>5 and ack_angle_err>5)`, forced false when `bt>8`. Stops it disagreeing with the generic path the same tick.
    - **V9.57-V9.59 (UI cosmetics)** — V9.57 chernobl-style group headers + multi-color welcome; **V9.58** split into HORIZONTAL TABS (`Main`/`Resolver`/`ESP+Advisor`/`Advanced`) via distinct `ui.create` first-args + `ui.sidebar(TAB,"crosshairs")`; **V9.59** HUD defaults Top-Left (combo reordered + `apply_preset` forces it). Tab-name strings are GLOBALS (main chunk at the 200-local cap). Re-tabbing/renaming groups re-keys UI elements once → toggles reset on first reload, click a preset to restore.
    - **V9.71 (perf + dead-code batch, full-code audit)** — perf: per-tick UI `:get()` caching in `tick_cache` (`ui_close_range/ui_air_resolve/ui_aa_classify/ui_classify_int`), `yaw_rate_buf` + `recent_resolved` als circular rings (entry-tables wiederverwendet, zero-alloc), ESP-Label-Compute (confidence/mode-parse/format/color-Objekte) 5Hz-throttled in `s._espc_*` cache, konstante Render-Farben als Modul-Globals (`ESP_COL_*`), HUD-Panel-Text/-Position bei 10Hz vorformatiert. Dead code ENTFERNT: `exp_head_focus` + `exp_hitbox_chain` Toggles (tot seit v9.18 HEAD-FOCUS-Löschung — Smart-Strategy „Head + Chest Fallback" == „Head Bias" jetzt), `apply_hitbox_chain()`, `DegToRad/RadToDeg`. 4 main-chunk locals frei.
    - **V9.72 (real-dump fixes)** — (1) **Spread-Miss-Filter**: `reason=="spread"` = Winkel akzeptiert, Kugel-RNG → skippt mode-stats/learning/per-player + mode-blacklist wie server-fails (`sel01_session_spreadfails` + eigene `[SESSION]`-Dump-Zeile; `s.missed` eskaliert weiter baim/multipoint). (2) **Passive-Side-Keep** bei blind first-contact: neue per-side Counter `passive_n_left/right`; wenn ≥20 obs 2:1 die geschossene Seite stützen, hält ein Magnitude-Miss die Seite statt explore-Flip (V9.49 never-hit explore bricht weiterhin nach 2 Keeps). (3) Boot-Log-Throttle global gekeyt (`sel01_boot_log_t`) — Dormancy-Reset erzeugte `s` neu und wischte den Throttle → 3× identischer Boot-Log.
    - **V9.73-V9.77** — V9.74 jitter+defAA BF fix (`pick_bruteforce_angle` skips the `def_delta` cycle on `aa_type=="jitter"` — no stable defensive delta — and falls through to `BF:opposite`) + air-branch yields to a pending `BF:retry` (consumed only in `pick_bruteforce_angle`, the air `return` ate the tick). V9.76 **AA-classify oscillation-freeze**: an `A→B→A` revert (committing back to a type just left) freezes the classifier 5s regardless of timing — the V9.10 10s-window anti-flap missed slow `static↔switch` reverts. V9.77 **Networked-Boost side-conflict guard** (`RebuildServerYaw` side can flip wrong on a hard one-sided enemy; new `learned_dom_side(s)` — real hits + streak only, no seeded/passive — vetoes a wrong-side boost on ground + air) + **server-fail filter honesty** (`ack_serverfail_like`'s `err<=5` branch now also needs `bt>=4`; a `bt=0 err=0` kept-side miss is OUR switch/side misprediction, not netcode — was excusing ~14 keeps and inflating headline rate).
    - **V9.78-V9.79 (BF real-dominance ordering)** — `pick_bruteforce_angle` led every BF cycle with `"opposite"` (flip to `-last_shot_side`), which on a firmly one-sided enemy flips onto the side they have NEVER been on = guaranteed whiff (`BF:opposite` was the worst mode at 0%). New `one_sided` test (`real_left/right` ≥3-vs-0): sweep MAGNITUDE on the proven dominant side first, demote `"opposite"` to last. **V9.78** gated it to static/slow; **V9.79** broadened to ALL non-defensive aa_types (this lobby's one-sided locks were `aa=switch` and fell through to opposite-first). Genuine alternators (real hits on BOTH sides, e.g. `L=2 R=1`) keep opposite-first (V9.63).

## HUD-overlay anatomy

When ESP enabled, `events.render` (10hz throttled compute, per-frame draw from `hud_cache`):
- **Per-enemy ESP** (V9.53 compact): ONE symbol line `[aa-icon] [side-arrow] [deg] [learn-icon]` e.g. `⇄ → 29° ★` (font size 3) + confidence bar. AA-icon `▬`static/`⇄`switch/`≈`jitter/`⟳`spin; learn-icon `🔒`locked/`★`learned/`·`learning. Mode-color: green=Meas, yellow=Predict, red=BF, blue=Air, cyan=LBY, magenta=Jitter. Plus (toggle-gated) on-model flash box (hit/miss/server-fail), shot-dots row, desync wedge (`render.line`, pcall-fallback if the build lacks it), compact netcode tag. Driven by `esp_show_labels` / `esp_show_confbar` / `esp_wedge` / `esp_flash` / `esp_enh`.
- **HUD corner panel** (position via `esp_hud_pos` combo): version + tracked/learned + avg-conf + top-mode + hit-rate + last combat (5s history HIT green/MISS red) + current-target intel (`→Target #N ✓/✗/· conf%🔒LOCKED [aa] mode`) + session-trend (`↑ improving / → stable / ↓ declining`).

All `render.*` pcall-wrapped. Border via 4 thin rects (avoid uncertain `render.rect_outline`).

## Git workflow

**Remote**: `origin → https://github.com/seltonmt012/Sel01-Solver.git` (branch: `master`). Auto-pushed since V9.6.

**Auto-commit + push policy** (user-explicit V9.6): every version constant bump triggers commit + push. No manual approval needed for these. Each script commits independently. Commit format:
```
Sel01-Solver vX.Y — <short summary>      (for resolver bumps)
Sel01-Config vX.Y — <short summary>      (for config bumps)

<bullet list of changes>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

**Dual-copy reminder.** Every edit to `Sel01-Solver.lua` OR `sel01_config.lua` must also overwrite the matching NL file. NEVER create new files in the NL folder — only `Copy-Item -Force` over the existing ones. Working copy is the source of truth tracked by git; NL copy is the one NL reloads from.

`.gitignore` excludes private data (`learned.lua/json/last_logs.txt/logo.png`, `.claude/`, `.vscode/`).

Push command:
```powershell
git push origin master
```

If hook failure on commit: investigate root cause, fix, create NEW commit (don't amend — pre-commit hooks fail means commit didn't happen, amend would modify previous one).

## Sel01-Config layout (`sel01_config.lua`, v3.29, ~2000 lines)

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

### Anti-resolver bundle (v3.6 - v3.9, separate from presets — opt-in toggles)

| Toggle | Default | Effect |
|---|---|---|
| **Defensive AA on hit-taken** (v3.6, bullet-only since v3.7) | ON | `player_hurt` with `hitgroup 1-7` (skip nade / world / fall) → for `aa_def_duration` ms: max desync 58 + 2× anti-BF variance + random body-yaw inverter every periodic tick. v3.7 dropped the force-fakeduck (was crouching mid-escape). |
| **Slow-walk AA boost** (v3.6) | ON | When NL Slow Walk hotkey is held: same chaos package as defensive — slow walkers are easy targets, this hides the magnitude / side. |
| **Fake-lag variance** (v3.6) | OFF | Periodically (every 1-3s) overrides NL Fake Lag Limit by ±2 ticks. Captures user's base value once on first activation so it doesn't drift away. Toggle-off clears. |
| **Yaw base rotation** (v3.7) | OFF | Periodically (every 4-8s random) rotates NL Yaw Base through Forward / Backward / Left / Right via `:override(string)` — combo string override is safe; combo `:override(bool)` segfaults. |
| **Side-streak limit** (v3.7) | ON, threshold 3 | aim_ack reads NL body-yaw inverter after every shot, counts consecutive same-side. When the streak crosses the threshold, queues a force-flip for the next periodic sync. |
| **Magnitude jitter** (v3.9, per-tick) | OFF, range 35-58° | Randomizes the base desync magnitude inside [min, max] every periodic-sync tick. EMA-based resolvers (including Sel01-Solver v9.x) lock onto the AVERAGE, leaving the actual fake yaw 5-15° off that average every shot. |

### Comprehensive Dump Debug Stats (v3.8)

The `Dump Debug Stats` button now emits 9 sections to chat in one click: SESSION + DEALT (shots / hits / HS% / dmg / kills / KD-ish) + RECENT EVENTS (last 8 from `hit_log`) + HITS TAKEN (all 10 incidents w/ full AA snapshots) + AA CONFIG (every slider + switch) + ANTI-RESOLVER state (v3.6 / v3.7 toggles + live activity windows) + NL RAGEBOT live (reads user's NL HC / MinDmg / Penetrate / SafePoints / HitboxSafety / FakeLag / SlowWalk / FakeDuck via `nl_refs[...]:get()`) + PERF (FPS / ping / velocity / airborne).

### Sel01-Config V2-V3 feature timeline

- **V2.0-2.1**: Re-enable subsystems after v1.13 BISECT confirmed stable baseline. Drop `nl_override` on Peek Assist hotkey (use gingersense pattern: `:get()` read). Switch player_hurt to JAG0YAW entity-compare.
- **V2.2**: Drop visual NL :override calls (Scope Overlay etc are combo elements).
- **V2.3**: Air-AA extras — rapid inverter flip + max jitter boost + optional fake-duck while airborne, 1.5× anti-BF variance, transition handling clears overrides on land.
- **V2.4-2.5**: AI Peek iteration (sidemove cycle) — later replaced by Peek Boost.
- **V2.6**: Debug stats accumulator (shots fired/hit/miss + total dmg + biggest + 1-taps) + dump button.
- **V2.7-2.8**: Peek Boost as hold hotkey — drives NL hitchance / mindmg `:override` on rising/falling edge of our own hotkey. Hits-Taken log (cap 10) with AA-state snapshot per incident.
- **V2.9**: aim_ack hit-detection fixed (nil = HIT, was MISS). Unified event log: HITS + MISSES (with reason) + KILLS, color-coded top-left.
- **V3.0**: Hitbox stats moved from aim_ack to player_hurt (hitgroup-based). Pitch jitter + auto-fakeduck while moving (both default OFF).
- **V3.1**: Peek Boost UI label shortened. Print Recommendations button. Anti-HS Bundle quick-toggle.
- **V3.2**: Move-AA extras (running on ground above velocity threshold). Aggressive preset auto-enables full anti-HS bundle.
- **V3.3**: Sticky fake-duck bug fix — added falling-edge clear via `_move_fd_active` dirty-track. Without it, NL kept the fake-duck override true forever after movement stopped.
- **V3.4 → V3.5**: Peek MinDmg default raised 1 → 50 (low-damage-during-peek hits) → then slider REMOVED entirely (Peek Boost no longer overrides NL min_dmg at all). Aligns with v9.18 "never override NL config" rule.
- **V3.6**: Anti-resolver bundle (Defensive on-dmg / Slow-walk boost / Fake-lag variance) + DEF / SW-BOOST / FL-VAR indicators.
- **V3.7**: Yaw base rotation + Side-streak limit + YAW-ROT indicator. Defensive AA filtered to bullet-only (hitgroup 1-7); force-fakeduck removed from defensive (was hindering escape during nade hits).
- **V3.8**: Dump Debug Stats rewritten — 9 sections, includes live NL Ragebot values via `nl_refs[...]:get()`.
- **V3.9**: Magnitude jitter (per-tick variance, anti-EMA-resolver) + MAG-JIT indicator. Default OFF; combines with anti-BF for full per-side chaos.
- **V3.10-3.17**: bug-fix batch — kills=0 stat fix, dump read bugs (MinDmg/HitboxSafety paths), Troll/Bait preset (run-in chaos, magnitude jitter + anti-BF on, fix "fake faces enemy" → Yaw Base Backward). `rage_mindmg` re-added READ-ONLY for dump (never written — never-override rule).
- **V3.18**: animated clantag FIXED — `common.set_clan_tag` is a game-state write, silently ignored from `events.render`; moved to `events.net_update_end` (bloodwings pattern) via `register_first`. NEVER fall back to a `createmove` registration (would clobber `createmove_unified`). + 5 new ASCII clantag styles (Loading/Scan/Glitch/Arrow/Rage).
- **V3.19-3.20 (visual additions)**: 7 read-only/render features all auto-enabled in Aggressive — desync %, skeet indicator panel, netgraph (`utils.net_channel().latency[1]/.loss[1]/.choke[1]` + `globals.choked_commands` LC warn), model-fade-when-scoped (`events.localplayer_transparency(fn→alpha)` call-form), remove-sleeves (`events.draw_model(fn)→false` on "sleeve"), menu blur, custom scope overlay (Scope-Overlay combo `:override("Remove All")` STRING-only). **V3.20**: premium velocity indicator (frostlive-style: icon box + label box + blur + clipped color-by-% fill bar + smooth fade; loads Verdana 16) + animated HSV menu border (layered frame + `color():as_hsv` flow around `ui.get_position/size`).
- **V3.21-3.23**: chernobl-style group headers (icon + `Sel01 » Section`) + multi-color welcome → then **V3.22** full horizontal TABS (`Main`/`Anti-Aim`/`Visuals` via distinct `ui.create` first-args + `ui.sidebar(TAB,"sliders")`, left/right columns). **V3.23** menu blur OFF by default. Smoothed the jumpy desync number (EMA, was raw per-tick jitter).
- **V3.24-3.27 (indicator presentation)**: `_vis_pill` then `_vis_chip` premium pills → consolidated the AA-state strip + skeet panel + desync into ONE deduped list → readable NAMES (not "FL-VAR" abbreviations) → **V3.27** replaced the whole panel with a MINIMAL JAG0YAW-style centered indicator under the crosshair (plain text: `SEL01` title + `- STANDING/MOVING/AIR/CROUCH -` movement + optional `DESYNC NN` + short curated active states; drops always-on noise). User iterated HARD on indicator legibility — keep it minimal, centered, plain.

### Common Sel01-Config gotchas (each has bitten)

- **`events.antiaim` cmd-writes crash CSGO** (v1.6 incident). No other NL script does this. Always drive AA through `nl_refs.aa_bodyyaw_l/r:override(...)`.
- **Combo `:set(int)` freezes menu** (v1.4 incident). Pass the option string. Better: skip combo `:set` in button callbacks entirely (decorative-only).
- **Preset button callbacks must not synchronously mutate UI** (v1.5 incident). Set `pending_preset = name`; drain from createmove.
- **`ui.find` raises popup-dialog on missing paths** (v1.3 incident). Use `pui.find` as primary.
- **Single `events.render:set`** — registering twice overwrites the first hook. Everything that needs render lives inside the one handler.
- **Forward-decl `update_clantag`** as `local update_clantag = function() end` BEFORE the render closure, then reassign later. Closures capture the upvalue, not the global.
- **Horizontal TABS via multiple `ui.create` first-args** (v3.22 / v9.58). `ui.create(tab, group[, column])` — distinct `tab` strings render as a horizontal tab bar inside the script's sidebar entry; `column` 1=left / 2=right. `ui.sidebar(name, icon_name)` sets the sidebar entry label + icon. Renaming a tab OR group RE-KEYS its elements (NL persists by path string) → the script's own toggles reset to defaults ONCE on the next reload; tell the user to click a preset to restore. Tab-name strings in the Solver must be GLOBALS (main chunk at the 200-local cap).
- **Game-state writes are ignored from the render thread** (v3.18). `common.set_clan_tag` (and similar) only take effect from a game-logic context — drive them from `events.net_update_end` (bloodwings pattern, registered via `register_first`), NEVER a second `events.createmove:set` (clobbers `createmove_unified`).
- **Return-value events use the CALL form, not `:set`** — `events.localplayer_transparency(fn)` where `fn` returns the alpha (0-255), and `events.draw_model(fn)` where `fn` returns `false` to skip a model (e.g. `m.name:find("sleeve")`). pcall-wrap; these are separate from the single render handler.
- **Verified render/color API on this NL build** (use freely, still pcall for version variance): `render.rect(p1,p2,col, radius|{tl,tr,br,bl})` (4th-arg rounding), `render.blur(p1,p2,strength,alpha,radius)`, `render.push_clip_rect(p1,p2)`/`pop_clip_rect`, `render.gradient(p1,p2,c1,c2,c3,c4)`, `render.push_rotation(deg,centerVec)`/`pop_rotation`, `render.measure_text(font,flags,text)→vector`, `render.load_font(name,size,flags)`, `color():as_hsv(h,s,v)`, `color():lerp(other,frac)`, `color:alpha_modulate(f)`, `ui.get_alpha/get_position/get_size/get_icon/get_mouse_position`, `utils.net_channel().latency[1]/.loss[1]/.choke[1]`, `globals.choked_commands`. `rage.antiaim:get_rotation(true)` = fake yaw, `:get_rotation()` = real yaw (desync delta = `|real-fake|/2`).
- **On-screen indicator design: minimal + centered, plain text** (v3.27, user iterated hard). JAG0YAW-style under-crosshair stack (title + movement state + few active states) beats big chip panels / left columns / cryptic abbreviations. Use readable names, smooth jumpy values (EMA), keep always-on internal states OFF the HUD.

## Sel01-WalkBot architecture (`Sel01-WalkBot.lua`, v1.7)

A standalone movement bot. ONE `events.createmove` handler (`walkbot_tick`) drives the local player via the cmd userdata; aiming is left to the ragebot. The whole decision tree is distance-tiered.

**Confirmed NL movement API** (from real build scripts externalapaha / chernobl / JAG0YAW, all pcall'd): `cmd.move_yaw` (degrees, WORLD walk direction — independent of view yaw, so the bot walks while the ragebot aims freely) + `cmd.forwardmove` (±450, lower = slow-walk) + `cmd.sidemove` + `cmd.in_jump` + `cmd.in_duck`. Obstacle traces via `utils.trace_line(start, end, skip_ent, mask)` (`.fraction`/`.end_pos`); the 4th arg is a content mask — movement probes pass `MASK_SOLID_BRUSHONLY` (`0x400B`) so they hit world geometry only, NOT players (without it, spawn teammates wedge the bot). Map name = `common.get_map_data().shortname` (`globals.mapname` is nil on this build). Team = `lp.m_iTeam` (2=T, 3=CT). Weapon swap = `utils.console_exec("slot1")`.

**Tick decision flow** (one `walkbot_tick`): drain Record/Clear waypoint buttons → load route + bad-spots + nav on map change → auto-primary weapon → pick target (`pick_target`, modes Nearest/Lowest-HP/Most-Visible/Crosshair). **ENGAGE** when a target is within `Approach Over` (default 1300u): hold-corner shoulder-peek (`assess_corner` — trace-based, no nav) if behind a corner and enemy not pushed, else slow-walk peek (aggressive jiggle ONLY when the enemy is visible) + crouch-when-exposed. **ROAM** when no target OR target far: nav-routed HUNT toward the freshest `enemy_history` entry → learned waypoint patrol → nav/leave-spawn toward map mid → wander. `compute_move(lp, lo, want_yaw, now, base_act, no_stuck)` is the shared mover — look-ahead probe + fan-out avoidance + crouch-to-pass low gaps + escalating wedge-escape (commit a back+side heading 0.8s); `no_stuck=true` from HOLD/peek so a held angle is not flagged STUCK.

**Nav-mesh (hard-won, see [[project_walkbot]] memory).** Read `csgo/maps/<map>.nav` via **kernel32 `CreateFileA`/`ReadFile` through `ffi.load("kernel32")`** — `files.read` truncates at null bytes (no binary mode, docs-confirmed) and `ffi.C.fopen` is absent in the NL sandbox. The maps are pre-copied into `nl/Sel01-WalkBot/`. The documented Valve v16 area layout is WRONG for this build (a build-specific ~99-byte undocumented trailing block per area; no field-width combo fits) AND area IDs are non-contiguous (de_mirage skips 50→52). So `nav_parse_scan` is **scan-based**: read each area's header (id u32, flags u32, NW/SE corners, neZ/swZ) + connections (4×count u32 + ids), then SCAN forward for the next plausible header (flags==0 + 6 in-range corner floats + neZ/swZ in the corner Z band + 4 small connection counts — strong enough that garbage can't fake it). Recovers ~867/903 areas. `nav_astar` routes the connection graph; `nav_dir()` follows the path node-by-node (cached per goal-area, re-paths every 1.5s) and is wired into ROAM HUNT + leave-spawn. Falls back to greedy straight-line when nav is off/unloaded.

**WalkBot gotchas:**
- **Movement probes MUST use the brush-only mask** or the bot wedges in spawn (traces hit teammates). `assess_corner`/`self_exposed` use it too so a teammate can't fake a corner.
- **`files.read` cannot read binary** (truncates at the first null) — confirmed via NL docs (single-arg, no binary mode). Use kernel32 for `.nav`; route/bad-spot files are plain text so `files.read` is fine there.
- **`files.read` on a MISSING path raises an unsuppressable popup** (ui.find class) — only read paths you know exist (the copied navs / your own written files).
- **Default OFF: jumping** (`Allow Jumping`). Per user, the bot should never jump; bhop + step-up + wedge jumps are all gated behind it. New switches take their default immediately (NL has no persisted value yet), which is how a hard-default-off override reaches an existing user.
- **Distance is king** — far enemy → ROAM/route, not beeline (rams walls, "thinks 3k is near"). Aggressive peek only when the enemy is genuinely visible; close-but-unseen → careful slow approach to gain the sightline.

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
