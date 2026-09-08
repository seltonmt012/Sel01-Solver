# gasolinalc.lua (4,099 lines, decompiled) — "gazolina" (db.vorona1) — the preset source

`new_class():struct(...)` chain of ~30 structs; libs `neverlose/pui`, `base64`, `clipboard`, `inspect`, `easing`, `voice_listener`, global `msgpack`. Startup cvars `cl_use_opens_buy_menu 0`, `sv_maxunlag 0.4`. Sidebar icons `user` (About / Watermark / Configs), `paperclip` (Anti Aim), `bars` (Misc / Visuals / Log Events); sidebar = wave gradient of "gazolina" with icon `code-compare`. Central `reference` table of ~30 `pui.find` handles; `context` object reset → filled → `:override()`'d each createmove with fallbacks (`pitch "Disabled"`, `yaw "Disabled"`, `yaw_add 0`, `base "Local View"`, `modifier "Disabled"`, limits 0, `body false`, `options {}`, `disable_yaw_modifiers false`, `body_freestanding false`, `freestanding false`, `freestand_peek "Off"`, DT lag `"On Peek"`, HS `"Favor Fire Rate"`, `avoid_backstab true`); on load every angles handle is `:override()`-cleared.

## Anti-aim

**States** `Standing, Running, Slowing, Crouching, Sneaking, Air, Air Crouching, Freestanding, Manuals, Safe Head` × teams T / CT (20 configs, `Send to Opposite` button). Priority: Manuals (manual ≠ Disabled) → Freestanding (hotkey) → Safe Head (`safe_head:think`) → ground: Slowing (NL Slow Walk) / Standing (vel2d < 5, duck ≤ 0) / Sneaking (duck > 0) / Running → air: Air Crouching (duck > 0) / Air. Each state has `Allow State` (def true) with fall-through.
**Per state** (groups state / Yaw / Modifier / Body Yaw / Tickbase; selection lists for team + condition): `Yaw` Solo / Left-Right; `solo` offset -180..180; `Left` / `Right` -180..180 each with `Randomize` + a range slider (`optional_yaw`, `utils.random_int(v, range)`); `Apply Delay` switch (disables Jitter + Inverter) → `Method` Default / Random / Ways, `Timing` 1-22, `[1]` / `[2]` 1-22, `Ways` 1-10 + sliders 1-22 + `Shuffle` (random 1-10); `Yaw Modifier` = NL list **+ "Bobrinho"** (sent as 3-Way, offset = 6-step LUT `{-x,-x/2,-x/3,x/3,x/2,x}` indexed by `aqua_bomba`, incremented on un-choked cmds, wraps at 7), offset slider, `Randomize` (Method Default min / max or Ways 2-10 sliders + Shuffle); `Body Yaw` switch → `Jitter` (def true), `Inverter` (hidden with Jitter / Apply Delay), `Mode` Static / Ticks (4-16) / Random (4-16), `Limit Mode` Default / Switch / Random, `Left Limit` / `Right Limit` 0-60 def 60, `From` / `To` 0-60 def 60, `Fallback Delay` 1-22 (1 Disabled); Tickbase (visible for states in Break LC): `Choke` Default / Custom, `Randomize`, `Choke` 1-32 def 16, `Method` Default / Custom, `[1]` / `[2]` 1-32 def 32, `Sliders` 2-10 + `1..10` 1-32 + Shuffle.
Base per tick: pitch Down, yaw Backward, base At Target. Order: yaw (skipped for Manuals) → modifier → body → warmup AA; if warmup not active: break_lc → freestanding → manual → anti-bruteforce.
**L/R with delay**: `if choked_commands == 0 then switch_delay++; Default: flip_side(timing) | Random: flip_side(random(min,max)) | Ways: flip_side(max(delay_[random(1..ways)], 1)) end; rage.antiaim:inverter(current_side); yaw_offset = current_side ? left : right` where `flip_side(n): if switch_delay - last_flick >= n / 1.95 then current_side = not current_side; last_flick = switch_delay end`. Without Apply Delay: `yaw_offset = (lp.m_flPoseParameter[11]*120 - 60 > 0) ? left : right` (follows the real desync side).
**Body**: Ticks → `tickcount % ticks == 0` toggles; off-ticks counted, forced back on after `random(2,6)`; disabled while fake ducking. Random → `body_yaw = tickcount % random(n) == 1`. `options = jitter ? "Jitter" : ""`; without jitter / delay → `rage.antiaim:inverter(inverter_switch)`. Limit Switch → flip both limits between From / To every Fallback Delay un-choked cmds; Random → `random(from, to)`.
**Hotkeys**: Freestanding (+ Prefer Manual, Disablers (states minus Freestanding), Disable Yaw Modifiers, Body Freestanding); Manual Yaw Disabled / Left / Right / Forward + Yaw Base (L -90, R 90, F 180).
**Options**: Safe Head + Conditions {Air Crouch, Crouching, Taser, Knife, Height Advantage} + `Difference` -200..200 def 25 (`Difference <= (lp.origin - threat.origin).z`; Knife / Taser share condition index 4 — a bug); the "Safe Head" state then uses whatever its builder page holds. Warmup AA (during `m_bWarmupPeriod` or zero alive enemies): Pitch Disabled / Down / Fake Up, Yaw Spin (`offset += speed/100*14` on unchoked, `yaw = offset % range`) / Distortion (`offset += frametime*speed; yaw = sin(offset) * range`) / L&R (inverter ? left : right), Range 0-360 def 360, Speed 0-100 def 50; body false, modifier Disabled, `cmd.no_choke = true`; short-circuits the rest. Anti-Bruteforce + Conditions (10 states) + Timeout 1-10 + mode Increase (`random(5,15)`) / Decrease (`random(-15,5)`) / Meta (`stage*2 * (inv ? -1 : 1)`, stage 0-10, inv from pose param 11): `bullet_impact` → `sim = lp:simulate_movement()`; if `sim.origin:closest_ray_point(enemy_eye, impact):dist(sim.origin) > 45` return; `time = realtime + timeout`; createmove adds the offset while active and the state is in Conditions.
**Break LC**: selectable states, `Hide Shots` combo Favor Fire Rate / Favor Fake Lag / Break LC, `Disable On Peek` (`think()`: `simulate_movement():think(2)`, trace bullets from the predicted eye to every alive enemy origin; any damage `0 < x < 50` = peeking). Active (state checked, weapon not grenade): `lag_options = "Always On"`, `hs_options = <combo>`; on un-choked cmds cycle the custom slider index; Custom choke → `cmd.force_defensive = command_number % choke == 0` (or `% random(from, to)` / `% choke1_[cur]`). Inactive → nil → fallbacks On Peek / Favor Fire Rate.

## Built-in presets (base64/msgpack at lines 339-356: `{author, date, config}` → config = base64 → msgpack → pui save table)

| # | Name | Author | Date |
|---|---|---|---|
| 1 | Aggressive (xo-yaw) | nopoint | 07/09 |
| 2 | Unrivaled (xo-yaw) | nopoint | 07/08 |
| 3 | sata | ramzan777888 | 07/24 |
| 4 | Snapper (Nyanza Snapshot) | nopoint | 07/29 |

**Snapper (Nyanza Snapshot)** (T = CT; base Local View in the data; anti-bruteforce Meta timeout 1 on all 7 movement states; safe head height 36 Taser / Knife; warmup AA off (Spin 74 / 360); break lc all 10 states, HS "Break LC", disable on peek off):

| State | yaw | L/R | apply delay | delay | modifier | body | limit mode | limits | choke |
|---|---|---|---|---|---|---|---|---|---|
| Standing | L/R | -25 / 40 | yes | Ways 5 `[5,5,2,2,20]` | Disabled (off -180) | Static, jitter | Switch 58→60 every 4 | 58/58 | Default |
| Running | L/R | -25 / 40 | yes | Ways `[5,5,1,1,10]` | Disabled | Static, jitter | Switch 58→60 every 14 | 58/58 | Default |
| Slowing | L/R | **-35 / 50** | yes | Ways `[10,10,2,2,20]` | Disabled (off -49) | **Ticks 6**, jitter | Switch 58→60 every 9 | 58/58 | Custom random 2-22 |
| Crouching | L/R | -25 / 40 | yes | Ways `[5,5,1,1,15]` | Disabled (+15) | Static, jitter | Default | 58/58 | Default random Custom `[6,22,19,11,16,6]` |
| Sneaking | L/R | -25 / 40 | yes | Ways `[5,5,1,1,20]` | Disabled | Static, jitter | Switch 55→60 every 3 | 58/58 | Default random Custom `[22,11,14,18,11,22]` |
| Air | L/R | 0 / 0 | no | Default | Disabled | Static, jitter | Default | 58/58 | Default random Custom `[10,22,12,16,6,17]` |
| Air Crouching | L/R | -25 / 40 | yes | Ways `[5,5,1,1,15]` | Disabled | Static, jitter | Default | 58/58 | Default random Custom `[9,22,16,10,13,5]` |
| Freestanding | Solo | — | no | — | Disabled | Static, jitter | Default | 58/58 | Custom 10 |
| Manuals | Solo | — | no | — | Disabled | jitter off, **inverter true** | Default | 58/58 | Custom 10 |
| Safe Head (T) | Solo | -23 / 38 | no | — | Disabled | jitter off | Default | **1 / 1** | Default 16 |
| Safe Head (CT) | Solo | — | no | — | **Offset, yaw -10, mod -5** | inverter true | Default | **37 / 3** | Default 16 |

**Aggressive (xo-yaw)** (break lc 9 states, HS Break LC, safe head height 60 Taser / Knife; misc: body lean 100, fast ladder / no fall damage / freezetime fakeduck / unlock fakeduck speed / grenade release (dmg 45) / cheat revealer on):

| State | L / R | delay | modifier | choke |
|---|---|---|---|---|
| Standing | -19 / 36 | Random 3-8 (def 3) | Disabled | Custom 10 |
| Running | -24 / 36 | Default 4 | Disabled | Custom 10 |
| Slowing | -26 / 40 | Random 3-6 | Disabled (off -49) | Custom 10 |
| Crouching | -25 / 40 | none | **3-Way +15** | random Custom `[6,22,19,11,16,6]` |
| Sneaking | -25 / 37 | Random 4-14 (def 6) | Disabled | random Custom `[22,11,14,18,11,22]` |
| Air | -24 / 26 | Random 3-6 | Disabled | random Custom `[10,22,12,16,6,17]` |
| Air Crouching | -17 / 37 | Random 2-7 | Disabled | random Custom `[9,22,16,10,13,5]` |
| Manuals | Solo | — | inverter true, jitter off | Custom 10 |
| Safe Head | Solo | — | limits 1/1 | Default 16 |
| Freestanding | Solo | — | — | Custom 10 |

Visuals in preset 1: viewmodel fov 548 x 4 y -49 z 17, aspect 133, scope overlay, hit marker, keep transparency, remove sleeves, arrows off (Yaw AFFF00).

**Unrivaled (xo-yaw)**: all `apply_delay` false except Air — static L/R: Standing -23/38, Running -26/33, Slowing -23/43 (mod off -49), Crouching -29/49 (mod +15, choke `[6,22,19,11,16,6]`), Sneaking -19/42 (choke `[22,11,14,18,11,22]`), Air -14/39 (delay on), Air Crouching -17/38, Manuals / Freestanding Solo, Safe Head Solo -23/38 limits 1/1 choke 16; warmup AA on; safe head height 60 Knife; watermark "у меня есть техники" font 4 gradient prefix C38888.

**sata** (exotic modifiers):

| State | L / R | delay | modifier | body mode | limits | choke |
|---|---|---|---|---|---|---|
| Standing | **-41 / 36** | Random 2-11 (def 9) | **Bobrinho off 56, randomize Default -19..73** | Static | 58/58 | Custom random 2-22 |
| Running | -22 / 44 | Ways `[5,8]` | Disabled | Static | 58/58 | Default |
| Slowing | -26 / **67** | Ways 6 `[6,22,9,6,22,…]` | **Bobrinho off -49, randomize Ways -30..35** | Static | 58/58 | Custom random 2-22 |
| Crouching | -29 / 44 | Default 1 | Disabled off 15, randomize Default 0..-11 | **Ticks 10** | Switch 58→46 every 7 | Default random Custom `[6,22,19,11,16,6]` |
| Sneaking | -22 / 42 | Random 4-8 (def 9) | **Spin off 14, randomize Ways** | Ticks 10, random 16 | Switch 54/54 58→46 every 7 | Custom random Custom `[18,7,19,11,7,21]` |
| Air | -22 / 44 | Default 5 | Disabled | Static | Default | Default random Custom `[10,22,12,16,6,17]` |
| Air Crouching | -22 / 44 | Random 11-22 (def 4) | **Random off 22, randomize Ways -22..44** | **Random 16** | Switch 58→48 every 22 | Custom random Custom `[20,16,12,10,13,5]` |
| Freestanding | -22 / 44 | Default 6 | Disabled | Static | Default | Custom 10 |
| Manuals / Safe Head | Solo | — | Disabled | Static | 58/58 resp. 1/1 | Custom 10 / Default 16 |

break lc `{Standing, Slowing, Crouching, Sneaking, Air Crouching}`, HS Break LC; freestanding disablers `{Standing, Crouching, Sneaking, Manuals}`; custom manual arrows with Japanese glyphs (`ぁ`, `෴㍾㋿㋿き`, `ぎ`), color 660600, offset 35.

## Misc / Visuals

Anim: Leg Breaker (randomizes layer-12 weight + `m_flPoseParameter[0]`, Leg Movement "Sliding"), Body Lean -1..100 def 50 (layer 12 weight = lean / 100; `ffi.cast($**, char*(ent[0]) + 10640)`). Movement: Fast Ladder (`m_MoveType == 9` + forward only: `m_vecLadderNormal:angles()`, flips keys, `view_angles.x = 89`, `y = ladder.y ± 90`), No Fall Damage (`trace_hull` 1000u down with `m_vecMaxs.z = 54`, plane normal ≥ 0.7, `is_fatal_fall` → `in_duck = 1` fatal, else `in_jump = 1` when `velZ < -580 and dist > 9`), Fakeduck Improvements (`createmove` + `createmove_run`), Freezetime fakeduck (`in_duck = choked >= 7`, `send_packet`, camera z +64). Shared: Cheat Revealer (`voice_listener` signatures → `player:set_icon`). Visuals: Aspect Ratio 1-200 step .01 def 133 (labels 133 / 160 / 150 / 125), Viewmodel (FOV 0-1000, X / Y / Z step .1, opposite knife), Scope Overlay (Fade In / Out 0-100 def 60, Rotation + Degree, color, Length 5-300 def 180, Offset 1-100 def 5), Hit Marker (`player_hurt`, 0.4s `ease_out_cubic`, 4 diagonal pairs at ±5 / ±10 with a black 50 % backdrop), Keep Model Transparency (59 when scoped / resume zoom / grenade, ±10 per frame), Trash Talk (14 RU/EN death lines, 24 brag lines), Manual Arrows Type TS (two `render.poly` triangles at center ±55 + 2px desync bars at ±38-40, colors lerped from 35,35,35,150 by `easing.quad_in_out`, body bar by `rage.antiaim:inverter()`, Yaw 175,255,0 / Body 0,200,255) / Custom (Left / Right / Forward symbol inputs `<` `>` `^`, font Default / Small / Console / Bold, offset 0-120 def 60, color), Damage Indicator (`pui.get_binds()` Min. Damage bind, fallback `Selection,SSG-08,Min. Damage`, draggable, `easing.quad_in_out`, shown while the menu is open or the bind is active), Animated Zoom (`override_view.fov` lerp factor `0.001 + 0.099 * clock/100`), Extended Ping Spike (`sv_maxunlag 1 / 0.1`), Log Events (Prefix DE8989 / Main 96B0BA colors; `item_purchase`, `player_hurt`, `aim_fire`, `aim_ack`).
Watermark: Font Large / Small / Italic / Bold (fonts 1-4), text input, Gradient (Speed 0-100, Amount 2-6 colors, `string:wave`), Effect Disabled / Pulse (`sin(realtime*3)*0.5+0.5`) / Encoded (per-glyph random substitution from `! @ # $ % ^ & + =` at 80 %, refreshed when `realtime % 3 < 1`), Position Left `(28, h/2)` / Bottom `(w/2-textw/2, h-28)` / Right / Custom (drag), Copy / Paste of the watermark subtree.
Draggable helper: hidden `pui.create("BDSM MACHINE PORNO")` sliders `%s:dragging_x/y` (-16384..16384), blocks `mouse_input` while hovering.
Config: `db.vorona1`; per-state Copy / Paste = `pui.setup(state_table, true):save()` → msgpack → base64 → clipboard; whole config Export / Import moves the `{author, date, config}` envelope; pinned presets can't be saved / deleted; separator entry `"\a{Link Active}―――――"`; info label `· Author: X\n· Updated: Y` via `:name()`.
Events: createmove, createmove_run, override_view, render, render_ingame, net_update_end, post_update_clientside_animation, localplayer_transparency, bullet_impact, player_hurt, player_death, aim_fire, aim_ack, item_purchase, purchases, damage_dealt, mouse_input, color, shutdown, config_state.

## Extra ui.find paths

`Aimbot,Ragebot,Selection,SSG-08,Min. Damage`; `Aimbot,Ragebot,Main,Peek Assist,Style / Auto Stop / Retreat Mode`; `Aimbot,Anti Aim,Angles,Extended Angles,Extended Pitch / Extended Roll`.
