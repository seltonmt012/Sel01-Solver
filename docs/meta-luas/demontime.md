# DEMONTIME.lua (1,502 lines, decompiled) — auto-peek / jump-peek ragebot helper — NO anti-aim

Only rage API: `rage.exploit:get() ~= 1` as a "DT charged" gate. Sidebar `ui.sidebar("DEMONTIME", "😈😈‼️👿🎮")`, navigation `:list("tabs", {"combat 👿👿", "preset 💾"})` switching groups via `:visibility`.

## Menu

`peek`: `demontime peek` switch; `teleportation` switch → `teleport range` 100-150 u def 100, `recharge delay` 32-128 t def 64, `recharge mode` safe recharge / AGGRESSIVE; `movement adaptation` 0-200 % def 135.
`aerobic` (jump peek, SSG-08 only): switch → `jump height` 50-200 def 111, `crouch jump height` def 112, `override hitchance` 0-100 def 44, `override head scale` 1-100 def 60, `override body scale` def 80, `disable delay shot` (true), `autostop` selectable {early, move between shots, in air, full stop} (preset move between shots + in air), `airborne enemy`, `recharge delay` 0-200 def 64.
`additions` selectable {ignore crouching, ignore awp, ignore unsafe edge, ignore autosniper, force safe point, all hitboxes}.
`presets`: list, input `pen name`, icon buttons floppy-disk (save) / upload (load) / file-export / file-import / red trash (`"\aed8179ff" .. icon .. "\r"`) / check + xmark (hidden until needed). Storage `db["demontime_presets"]`; encode `base64(json)` double-wrapped (`{config = b64, time = unixtime}`), clipboard string `dtcfg_<b64>_dtcfg`; sounds `utils.console_exec("play ui/beepclear")` on save / load / import, `"play buttons/weapon_cant_buy"` on delete.

## Overrides (the useful ui.find list)

```
Aimbot,Ragebot,Selection,Hitboxes | Multipoint,Head Scale | Min. Damage
Aimbot,Ragebot,Accuracy,Auto Scope
Aimbot,Ragebot,Main,Double Tap (+ ,Lag Options ,Fake Lag Limit ,Immediate Teleport)
Aimbot,Ragebot,Main,Peek Assist (+ ,Auto Stop ,Retreat Mode ,Max Distance)
Aimbot,Ragebot,Safety,Body Aim
Aimbot,Ragebot,Safety,SSG-08,Safe Points
Aimbot,Ragebot,Selection,SSG-08,Min. Damage | Hit Chance | Min. Damage,Delay Shot | Multipoint,Head Scale | Multipoint,Body Scale
Aimbot,Ragebot,Accuracy,SSG-08,Auto Stop,Options
Aimbot,Ragebot,Selection,AWP,Min. Damage
Aimbot,Ragebot,Selection,Zeus x27,Min. Damage
```
Peek active → `Peek Assist :override(true)`, `DT Fake Lag Limit :override(1)`, `Immediate Teleport :override(false)`; a valid damage point → `Head Scale :override(100)` else release; returning → `Retreat Mode :override({"On Shot", "On Key Release"})`; aerobic → hitchance / head scale / body scale from the menu, `Delay Shot :override(false)`, `Auto Stop options :override(<selectable table>)`; `force safe point` → `Safe Points :override("Force")`. **Double-Tap juggling**: peek path `dt.switch:set(false)` with the previous value stashed and restored; aerobic path `:override(false)`; restore timers sanity-clamped (`> 5 or < -1` → reset) so a stale timer never locks DT off. Full cleanup (bare `:override()` on every handle) on death / no weapon / shutdown.

## Algorithm

- Geometry: `utils.trace_hull(..., 33636363)` with mins `(-16,-16,0)` / maxs `(16,16,72)`, step height 18, base peek distance 22u; left / right candidates at ±90° from camera yaw, retried at ±10 / 20 / 30 / 40°, final downward hull trace to floor-snap. Trace filter `classname == "CCSPlayer" and is_enemy()`.
- Velocity expansion: `dist *= 1 + (vel_expand/100 - 1) * ((clamp(speed,50,250)-50)/200)^0.7`, full effect only toward the side you already move to (> 15° yaw delta), else ×0.3.
- Damage validation: `utils.trace_bullet(local, point, hitbox_pos)` against a hitbox list; head damage × penetration factor `{AWP 4, SSG08 4, SCAR20 4, G3SG1 4, Taser 1}`; min-damage > 100 treated as `health + (dmg - 100)`.
- Hitbox groups `Head {0}`, `Chest {4,5,6}`, `Stomach {2,3}`, `Arms {13..18}`; default scan `{0,5,2,15,17}`, `all hitboxes` widens to 12.
- Predicted origin: forward-simulate velocities N ticks with gravity `800*tickinterval` up / `301.99*tickinterval` down, stopping on `trace_line(..., 33570827).fraction <= 0.99`.
- Unsafe-edge guard: trace 20u ahead + 100u down; drop > 18u → zero all move inputs instead of peeking.
- Movement: `cmd.in_forward = true, forwardmove = 800, sidemove = 0, move_yaw = angle to point`; aerobic `in_jump` / `in_speed` with a 64-tick cooldown.
- Target stickiness 0.06s reusing `last_target_point` while the threat is non-dormant and `get_bbox().alpha >= 1`.
- Weapons: peek `{CWeaponSSG08, CWeaponTaser, CWeaponAWP}`, aerobic `{CWeaponSSG08}`; scoped check `{SSG08, AWP, G3SG1, SCAR20}`.
- Events: `createmove` + `shutdown` only, plus `set_callback` on Hitboxes / Body Aim / additions to rebuild the hitbox cache. No FFI, no HUD.
