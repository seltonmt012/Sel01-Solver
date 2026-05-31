# Sel01-Solver — Self-Learning Anti-Aim Resolver for CS:GO (Neverlose Lua)

A per-player, self-learning anti-aim **resolver** for CS:GO HvH play on the Neverlose
Lua API (legacy CS:GO build — **not** CS2). It fingerprints each enemy's anti-aim,
learns their real desync side and magnitude from landed shots, and feeds the
ragebot a corrected angle. Ships with on-model ESP, an in-menu AA Advisor, and a
companion config script.

**Author:** seltonmt01

> HvH (hack-vs-hack) tooling for the Neverlose cheat platform. Both enemies and
> you run anti-aim; the resolver's job is to undo theirs.

---

## The suite

Two scripts load together in the same Neverlose sandbox and talk only through
Neverlose's own events/UI — never directly.

| Script | Role |
|---|---|
| **Sel01-Solver** (`Sel01-Solver.lua`, ~5200 lines) | The resolver: per-player AA learning, persistent JSON/Lua store, HUD + on-model ESP, event ticker, AA Advisor (in-menu + coach-chat), Sel01-Roast kill-chat. |
| **Sel01-Config** (`sel01_config.lua`, ~1950 lines) | Companion: AA presets, an anti-resolver bundle (defensive-on-hit, fake-lag variance, magnitude jitter, side-streak limiting), watermark + indicators, debug dumps. |

---

## What the resolver does

1. **Resolve** — guesses the enemy's fake-yaw (desync) so aimbot shots land on
   players hiding their hitbox with anti-aim.
2. **Learn** — every landed shot updates a per-enemy model (per-side desync EMA,
   dominant side, best mode per AA-type), persisted across rounds and sessions by
   Steam-ID.
3. **Classify** — labels each enemy `static` / `jitter` / `spinner` / `switch`
   and picks a tailored strategy, with hysteresis so the label doesn't flap.
4. **Discriminate server-fail from resolver-fail** — a correct-angle shot the
   server rejects (stale backtrack record, high `backtrack` value) is netcode, not
   a miss; it's filtered out of the hit-rate so the headline number is honest.
5. **Show its work** — on-model ESP, a HUD panel, an event ticker, and an AA
   Advisor that explains each enemy's exploitable weakness in plain words.

---

## Per-enemy state

Each enemy lives in `PlayerState[idx]`. Core fields:

```
missed              consecutive miss counter (drives BF cycle + force-baim)
last_seen           curtime, for dormancy detection
last_hit_side       +1 / -1 / 0  (right / left / unknown)
measured_desync     EMA of the real desync angle, learned from hits
measured_left/right per-side EMAs (independent drift-bump + hard-reset)
samples_*           sample counts (left/right/global)
real_left/right     hits from ACTUAL landed shots (vs passive-seeded samples)
hit_streak_*        consecutive hits per side
yaw_rate            deg/sec, for ping-aware extrapolation (clamped, sanity-gated)
aa_type             "static" / "jitter" / "spinner" / "switch"
defensive_aa        set on a "spread" miss (enemy moves post-fire)
backtrack_resistant flagged after repeated high-backtrack server rejects
serverfail_misses   correct-angle shots the server rejected (not our fault)
shot_history        ring of the last 6 shot results (for the ESP dot row)
tp_peek_active      time-boxed flag set on a detected teleport/blink-peek
```

The key distinction across the codebase is **real vs seeded samples**: passive
observation seeds a guess, but only actual hits ("real") earn full confidence.

---

## One resolve call (flow)

1. `can_resolve(p)` — alive, enemy, not dormant.
2. Decay stale measurements; on re-engagement after dormancy, boot the model from
   Steam-Memory + the persistent learned store.
3. FOV + distance cull (skip offscreen / far).
4. Cached anim-state read.
5. **Air branch** — airborne enemies use a rebuilt server-yaw + measured side.
6. `update_jitter` → yaw ring buffer + yaw-rate.
7. **Classify AA** (hysteresis + post-commit lock).
8. **Extrapolate** — ping/yaw-rate aware, gated on confidence + stability.
9. **Pick the angle** — `pick_first_shot_angle` (many learned modes) on the first
   shot, else `pick_bruteforce_angle` (cycles magnitudes/sides by miss-count).
10. Store the resolved angle + eye-yaw for the `aim_ack` learner; apply
    `goal_feet_yaw`.

`aim_ack` then classifies *why* a shot missed (wrong side vs magnitude error vs
server stale-record) and reacts differently to each — getting this wrong
oscillates, so most of the recent work lives here.

---

## Mode strings (debug)

Base modes carry suffixes that describe what was applied:

| Suffix | Meaning |
|---|---|
| `+Pred` | extrapolation applied |
| `-Alt` | switch-AA alternating side |
| `-CorrFlip` | correction-aware side flip |
| `-DefInv` | defensive-AA side inversion |
| `-Recall` | known-player fast-path (from persistent store) |
| `-Guess` | fallback (no measurement — uses an adaptive median magnitude) |

Base modes include `Air`, `Static-Meas`, `Static-Server(Boost)`, `Networked`,
`Predicted` / `Predicted-Streak`, `Jitter-Cls`, `LBY-Snap`, `Still-Server`, and the
`BF:*` brute-force family. Fallback (`BF:*`, `*-Guess`, `Init`) modes are never
saved as a learned "best mode".

---

## On-model ESP + HUD

When ESP is on (`events.render`, throttled compute / per-frame draw):

- **Per-enemy label** — one compact line `⇄ → 29° ★`: AA-type icon
  (`▬`static `⇄`switch `≈`jitter `⟳`spin) + side arrow + desync° + learn icon
  (`🔒`locked `★`learned `·`learning). Color = resolve mode.
- **Confidence bar** under the label.
- **Hit/miss flash** — a short fading box on each shot: green hit / red miss /
  blue server-fail.
- **Shot dots** — the last 6 results as colored squares.
- **Desync wedge** — two lines from the pelvis: white = the enemy's real eye-yaw,
  mode-color = our resolved fake-yaw.
- **Netcode tag** — `⚠×N` when an enemy fake-lags, so their "miss" reads as
  server-side, not a resolver fault.
- **HUD corner panel** — tracked/learned counts, average confidence, top mode,
  session hit-rate (with server-fails filtered out), and an improvement trend.

---

## Events hooked

`aim_ack` (learn from hit/miss) · `weapon_fire` (LBY-snap + counter-fire) ·
`aim_fire` (per-shot snapshot ring) · `createmove` (resolve loop + auto-save) ·
`ragebot_target` (multipoint / hitbox / hitchance overrides) · `player_death`
(roast + kill event) · `render` (ESP/HUD) · `shutdown` (force-save + unhook).

Per-script isolation is assumed — multiple installed scripts each register their
own handlers without stepping on each other.

---

## Build / verify

No test infrastructure — runtime errors only surface on reload in Neverlose.
Bytecode-compile each script before loading:

```bash
luac -p Sel01-Solver.lua    # resolver
luac -p sel01_config.lua        # config
```

Must exit clean. Then reload in Neverlose and watch the load banner + `[DBG]`
stream (enable DEBUG MODE in the Logging group) for per-resolve / per-shot lines.

---

## Lessons baked into the code

A few of the sharper Neverlose-sandbox gotchas (the rest live in `CLAUDE.md`):

| Gotcha | Why | Handling |
|---|---|---|
| No `os` library | NL sandbox | `globals.realtime` / `globals.tickcount` |
| Combo `:get()` returns a **string** | not an index | string compare, never arithmetic |
| Forward-refs kill closures | UI callbacks capture upvalues at parse time | forward-declare locals before any UI that references them |
| Writing fields to `events.antiaim` `cmd` | C++ panic that bypasses pcall | drive AA only through `ui.find(...):override(...)` |
| `:override(bool)` on a combo / hotkey | segfaults at spawn | override only switches/sliders, and combos with the matching string |
| `aim_ack` nil-state | means **hit**, not miss | `is_hit = (reason == nil) or HIT_STATES[reason]` |
| High `event.backtrack` miss | server replayed a stale record | never flip side — it's netcode, not our angle |
| Lua 5.1 only | no `goto`, no `//`, no bitwise, no JSON | `math.floor`, `bit.*`, a hand-rolled JSON encoder |

---

## Persistence (private, gitignored)

Learned data is per-user and never committed:

- `nl/Sel01-Solver/learned.lua` — fast-load Lua table
- `nl/Sel01-Solver/learned.json` — JSON backup + human-readable
- `nl/Sel01-Solver/last_logs.txt` — copy-log fallback

---

## Files

- `Sel01-Solver.lua` — the resolver
- `sel01_config.lua` — the companion config
- `CLAUDE.md` — full architecture, bug history, and Neverlose-API notes
- `README.md` — this file
