# CLAUDE.md

Guidance for Claude Code when working in this folder.

## Project

**`resolverx.lua`** — a standalone **gamesense CSGO** (legacy) Lua resolver for HvH / rage play. In-game menu label reads `[Owned] Resolverown` / gamesense error strings show `*[Owned] Resolverown`. Loaded directly by gamesense (not Neverlose — this is a separate cheat platform from the sibling `../../Sel01-*` NL scripts).

Single file, ~700 lines. Forces enemy body-yaw via the gamesense player-list ("Force body yaw") so the ragebot aims at the enemy's real feet side.

- Version constant: `local RESOLVER_VERSION` near the top. Prints a colored load banner at the bottom of the file on load so we can confirm the fresh copy is running. **Bump it on every change.**
- No git tracking assumed here; the NL sibling project one folder up has its own repo/rules. Ask before adding VCS.

## Verify changes

```powershell
& "C:\Users\Seltonmt\scoop\apps\lua\current\bin\luac.exe" -p "C:\Users\Seltonmt\Desktop\sazz\aron\ownlua\gs\own\resolverx.lua"
```

Must exit clean. No test harness — runtime errors only surface when the user reloads in gamesense and reports. gamesense APIs (`entity.*`, `client.*`, `plist.*`, `ui.*`, `globals.*`, `cvar.*`, `renderer.*`, ffi) are NOT present under `luac -p`; it only checks syntax.

## Architecture (pure statistical resolver — NN removed v2.8)

The file historically shipped a neural-net "AI resolver" that was **fully inert** (string-keyed input vs numeric read → constant 0.5 output; never called at runtime). **v2.8 deleted the whole ~385-line NN block** (weights/forward_pass/train_on_batch/experience-replay/save_weights + the unused `gamesense/base64` + `gamesense/http` requires). Do NOT re-add it without a real redesign (numeric feature vector + a real measured-desync label).

**Active resolver = per-enemy statistics** in `ResolveState[ent]`:

| field | meaning |
|---|---|
| `side` | current forced side, `-1` LEFT / `+1` RIGHT (persistent) |
| `hits_l` / `hits_r` | confirmed hits per side (dominance). **Capped at 12** (v2.8) so a mid-round switch adapts fast |
| `miss` | total resolver-type misses (baim escalation / debug only) |
| `side_miss` | consecutive FRESH misses on the current side (switch detection). Time-decays after >3s gap (v2.7) |
| `unproven_miss` | fresh-miss counter on an unproven side, drives the 2D magnitude search (v2.8) |
| `mag_bias` / `mag_step` | learned per-enemy desync magnitude + ladder index (v2.6). `nil` = use base 58 |
| `jitter` | live feet-lean sign flips ≥6/1s → jitter/switch AA (v2.6). Damps flip + skips mag probe |
| `lby` | anim layer seq 979 = LBY-flex detected (v2.8, observational — surfaced in debug log) |
| `lean_sign` / `lean_flips` / `lean_seen` | jitter-detection accumulators |
| `last_rmiss` | curtime of last resolver-miss, for `side_miss` decay |
| `seeded` | first-contact side seed already applied |
| `last_mag` / `last_side` / `last_adiff` | snapshot of what was forced + live lean, read by `aim_fire`/miss debug |

`SideMemory[sid]` = cross-round `{l,r}` hit counts (survives entity-index reuse), capped at 20 each (v2.8).

Flow (all in `Resolver` table + event callbacks):
- **`net_update_start`** → `Resolver:Animlayer()` (resolve) + `Resolver:Prediction()` (interp cvars). `animation_fix()` is **disabled** here (it wrote enemy `m_flPoseParameter` every tick — prime suspect for the Extrapolation-miss flood; re-enable only to A/B test).
- **`Animlayer`** pre-resolves **ALL alive enemies** every tick (`entity.get_players(true)`), not just `current_threat`, so a target switch is instantly resolved. Also runs `updateLayers` + `isLBYFlexing` → `rs.lby`. On resolver-disable it clears "Force body yaw" once (`resolver_was_on` edge).
- **`find_desync`** → magnitude = `mag_bias` (learned) else `GetMaxDesync × 58` clamped `[0,58]` (pose param unreliable — see gotchas); side = persistent `rs.side` (dominance is NOT re-applied per tick, or a mid-round AA switch could never correct). Runs jitter detection. First contact seeds side from SideMemory > `angle_diff(eye, goal_feet)` sign > blind.
- **`Prediction`** → sets interp cvars per Prediction Type combo. **Interp floor** (v2.8): never lets interp drop to ~0 at ping >40ms (floors to 1/64) — kills the high-BT stale-record miss flood.
- **`aim_fire`** snapshots wanted hitbox + hitchance + forced side/mag into `ShotInfo[e.id]`.
- **`aim_hit`** (`hit_logs`) confirms side: `hits_l/r++` (capped), resets `miss`/`side_miss`/`unproven_miss`/`mag_step` (locks `mag_bias`), increments Stats.hits.
- **`aim_miss`** (`miss_logs`) decides flip — see below.

**Menu** (`Rage → Other`): Enable Resolver, Prediction Type, **Interp floor (high ping)**, **Magnitude search**, **Jitter detection**, Resolver Debug Logs. The three new toggles default ON via `ui.set`; each gates its feature so a regression can be switched off without editing code.

## The core of miss-handling (BT-aware side logic)

`BT = globals.tickcount() - shot.tick` = how far back gamesense backtracked the shot. **High BT = stale/backtracked record = a netcode/ping miss, NOT a wrong side.** Flipping side on those throws away a correct side and causes L↔R oscillation (the dominant bug through the rewrite).

`miss_logs` classifies before reacting:
- **Low hitchance (`< LOW_HC`, 30%)** → gamble/spread shot, NOT a side error → never flip, `lowhc_keep` (v2.9). Checked FIRST so it covers proven and unproven. Logs showed 4-13% HC misses churning sides.
- **`side_evidence` = reason `"?"`/nil AND `bt <= 6`** (`fresh`) → a fresh-record miss is the only real wrong-side signal.
- **Unproven/weaker side** (`cur_hits == 0` or `opp_hits > cur_hits`) → flip ONLY on a `fresh` (low-BT) miss; a stale/high-BT/Extrapolation unproven miss is netcode → `netcode_keep`, wait (SideMemory/lean seed stays). **v2.9 fix:** this branch used to flip regardless of BT, churning the side on BT 14-21 stale records (the dominant issue in the v2.8 logs). **2D search (v2.8):** on the fresh path, after a full L/R cycle at the same magnitude still missing (`unproven_miss >= 4`, every 2nd), `mag_probe` steps the ladder so a low-desync enemy converges instead of oscillating L/R at 58.
- **Proven side + FRESH miss** → flip after `side_miss >= 2` OR (non-jitter enemy) the **live feet-lean sign disagrees** with the forced side (`lean_disagrees`, two-signal confidence → flip on first miss, v2.6). Then decay that side's dominance by half. Otherwise KEEP side and **`mag_probe`** the magnitude ladder (v2.6) — the side is likely right, the magnitude wrong. On a jitter enemy the probe is skipped (side is the problem, not magnitude).
- **Proven side + stale/extrapolation** (`netcode_keep`) → KEEP side, only bump `miss`.
- **Ping / death / Spread** → never flip (RNG / netcode).

**Magnitude search (v2.6):** `MAG_LADDER = {58,46,34,52,40,28}`. Base force = 58 (max desync). On proven-side fresh misses `mag_probe` walks the ladder; a hit locks `mag_bias`. Starts at 58 so a genuine full-desync enemy re-confirms immediately and a hitting lobby never triggers. Reset on side-flip / index-reuse.

Reasons map (`reasons` table): `spread`→Spread, `prediction error`→Extrapolation, `death`→Ping, `?`→?.

## Debug logs (menu: `Rage → Other → Resolver Debug Logs`)

Off = plain hit/miss lines. On = colored `[RESOLVER HIT/MISS]` lines via `client.color_log`, showing: hit vs **wanted** hitbox, dmg, hc, forced side, mag, dominance `L/R`, `lean=` (live feet-lean), `jit=` (jitter flag), `lby=` (LBY-flex flag), BT, and the decision (`WRONG SIDE flip` / `KEPT + probing magnitude=N` / `KEPT jitter` / `STALE RECORD kept` / `spread`). Each miss also prints a `[STATS]` line — session tally `hits/flip/kept/netcode/lowhc/spread/ping/unreg` (v2.5, `lowhc` added v2.9). `flip` = real resolver faults; if `flip` stays low while netcode/lowhc/ping/spread pile up, the side logic is fine and the misses are backtrack/interp/gamble-shots. Counters are module-global and only ++; a mid-session **reload resets them to 0** (they are NOT a bug if they appear to decrease across a paste). `wanted ≠ hit` (e.g. wanted head, hit chest) is flagged as a **ragebot multipoint/hitchance issue, NOT the resolver** — the resolver only controls side, not which hitbox the ragebot picks.

## Gotchas (each cost real debugging)

- **Pose-param desync read is unreliable on this build.** `entity.get_prop(ent,"m_flPoseParameter",11)` returns ~center → any magnitude derived from it is ~0. Use anim-derived `GetMaxDesync × 58` for magnitude. (Mirrors the NL project's `project_pose_param_deadend` note.)
- **Don't overwrite `rs.side` from dominance every tick** — a mid-round AA switch could then never be corrected by the miss-flip. Side is persistent; hits keep it, fresh misses flip it.
- **`entity.get_players(true)`** = enemies only; still guard each with `entity.is_alive`.
- **Never write enemy pose params clientside** (`animation_fix`) — suspected to corrupt enemy anim/backtrack records → Extrapolation misses. Left disabled.
- **`client.color_log(r,g,b,text)`** is the console writer. `shot.tick` can be nil on odd shots — guard `globals.tickcount() - (shot.tick or globals.tickcount())`.
- **`plist.get/set` names are case-sensitive** — use the exact `"Force body yaw"` / `"Force body yaw value"` (lowercase) that the set side uses, or `get` returns nil and concatenation crashes.
- **First line of the file** previously had a scriptleak backdoor (`writefile(random.bin, inspect({...}))`) — removed; do not reintroduce.
- **Multiple resolvers fight.** The user sometimes runs other resolver scripts (`dangerous.lua`, etc.) that also force body yaw — only one may own "Force body yaw" at a time. Not our bug, but note it when diagnosing chaos.

## Known non-resolver factors (advise the user, don't "fix" in lua)

- **High ping (seen 131ms) + Prediction Type = Experimental (interp 0)** → large BT / stale-record misses. Try Prediction Type `Auto` (computes interp from latency via `calculate_interp`) or `Default`. The lua does NOT choose backtrack records — gamesense's ragebot does.
- **`wanted head → hit chest/stomach`** = ragebot config: Multi-point Head+Chest+Stomach + Prefer safe point picks the safe body hitbox. For more head: narrow multipoint to Head, lower min-hitchance, or drop prefer-safe-point. Ragebot settings, not this script.

## When editing

- Bump `RESOLVER_VERSION` every change (load banner is the user's proof of the fresh copy).
- `luac -p` must pass before handing back.
- Keep per-tick work cheap: `Animlayer` runs 64×/s over all enemies. Cache cvar refs (already done: `cv_interp*`), avoid per-tick table sort/alloc (magnitude is O(1), no history buffer).
- Prefer keeping the dead NN defined-but-unused over deleting 300 lines mid-session unless the user asks — less edit risk.
