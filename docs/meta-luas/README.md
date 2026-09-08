# NL meta-lua survey (scriptleaks) — knowledge base

Source repo: https://github.com/wyscigufa9/scriptleaks/tree/main/nl-luas (clone with `git clone --depth 1` into the scratchpad when the actual source is needed; ~84k lines, decompiled but readable, identifiers `slot_x_y_z` / `var123`).
Surveyed 2026-09-08 for Sel01-Config v5.0. One file per lua in this folder; this README holds the cross-cutting facts. **Read these instead of the luas** — re-reading the sources costs ~1.5M tokens.

| File | Lua | Lines | What it is | Worth reading for |
|---|---|---|---|---|
| [elysian.md](elysian.md) | elysian.lua | 19k | AA-centric, pui, most complete defensive/hidden-angle system | defensive modes, anti-bruteforce phases, safe-head tables, visuals (glass pills, side indicators), config export |
| [andromeda.md](andromeda.md) | AndromedaAlpha.lua | 27k | AA state builder + big misc/visual suite, custom GDI font engine | Meta delay tables, tickbase, anti-BF phases, side indicator layout, FPS optimizer, agent changer |
| [evalate.md](evalate.md) | evalateRecode.lua | 9k | pui 3-tab companion, cloud presets, best switch-timing engine | Delay engine (staged / by sides), Freeze, defensive builder, Auto OS, air exploit, draggable widgets |
| [spectral.md](spectral.md) | spectraldev.lua (everlast fork) | 7k | AA builder from NL `:list()` options + defensive + visuals | the "Author" preset values, defensive yaw formulas (povorotniki, progressive), edge yaw, flick exploit |
| [nexus.md](nexus.md) | nexusluarelease.lua | 5.7k | pui companion, 8 states, skeet-style indicators | L/R delay+variability, X-Way sawtooth, safe head, edge yaw, side indicator list, Peek Assist proxy |
| [gasolina.md](gasolina.md) | gasolinalc.lua (gazolina) | 4k | OOP struct chain, 10 states x 2 teams, **4 decoded built-in presets** | Nyanza Snapshot / Aggressive / Unrivaled / sata values, Bobrinho LUT, break-LC choke tables, warmup AA, anti-BF Meta |
| [arc.md](arc.md) | arc.lua | 6.8k | QoL/visual companion, NO anti-aim | indicator pills + progress ring, network metrics, preset export (base64+xor+msgpack), event wrapper with priority watchdog |
| [demontime.md](demontime.md) | DEMONTIME.lua | 1.5k | auto-peek + jump-peek ragebot helper, NO anti-aim | trace_hull peek geometry, per-weapon ui.find paths, DT juggling, preset clipboard format |
| [worldeditor.md](worldeditor.md) | WorldEditorRemaper.lua + inport-export.lua | 3.4k | world/material FFI editor, NO anti-aim | Ambient ui.find paths (two-handle returns), `tab:export()/import()` config trick |

## The shared AA meta (every AA lua does this)

1. **Never raw angles.** Everything is `:override()` on NL's own `Aimbot > Anti Aim > Angles` elements from ONE `createmove` pass; `:override()` with no arg releases. elysian / gasolina / spectral use a scratch table that is nil'ed → filled by modules → pushed in one `run()`.
2. Baseline every tick: `Pitch = "Down"`, `Yaw = "Backward"`, `Yaw Base = "At Target"` (Local View only for manual / on-use / some slow-walk presets), `Yaw Modifier = "Disabled"` (the script does the modifier math itself and writes the result into `Yaw > Offset`), `Body Yaw > Options = {}` (NL's own jitter never interferes).
3. **Real yaw = asymmetric L/R offset that rides on the desync side** (Nyanza -25/+40, Aggressive -19/+36, everlast -35/+30). The side is the script's own bool, flipped only on un-choked sends (`cmd.choked_commands == 0`), written to `Body Yaw > Inverter` (or `rage.antiaim:inverter(bool)`).
4. Body limits 58/58 or 60/60, optionally random min..max or A/B alternation; body yaw pulsed OFF for 2 ticks every N ("Ticks" mode).
5. Side switch timing: fixed N sends, random lo..hi, a **sequence** of sends (Nyanza `[5,5,2,2,20]`), per-side ranges (evalate "By sides" L 1-4 / R 10-16), delay ladders `{1,3,5,7,10,15,16}` (Andromeda). "Randomize Jitter" = random side instead of alternate.
6. Modifiers used sparingly: `3-Way +15` on crouch, `Center -49` on slow-walk (halved into the offset), gazolina "Bobrinho" = `{-x,-x/2,-x/3,x/3,x/2,x}` LUT advanced per send, evalate Ways = `linspace(n,min,max)`, nexus X-Way sawtooth.
7. **Defensive** = `cmd.force_defensive = (cmd.command_number % choke == 0)` with choke 2-22 (default 16) from a fixed value, random range, or a table (`[6,22,19,11,16,6]`), plus `Double Tap > Lag Options = "Always On"` and `Hide Shots > Options = "Break LC"` while active ("break LC"). Detection of the actual shift: `m_nTickBase` regression (`ticks = clamp(prev - cur - 1, 0, 14)`) or `rage.exploit:get_defensive()` / negative sim-time delta. Hidden angles during the shift via `rage.antiaim:override_hidden_pitch/yaw_offset` + `Yaw > Hidden = true`.
8. **Anti-bruteforce** on `events.bullet_impact`: near-miss = shot line within 45-72u of head/hitboxes (or a `player_hurt` for "hit" trigger); reaction = flip side / random limit / yaw += random or stage*2 / next phase (elysian up to 10 phases each -40..40) / **freeze** the inverter for N sends with a chance (evalate).
9. **Safe Head**: knife / zeus / air-crouch / height advantage → base At Target, limits 1-5 (Andromeda knife 30 + yaw 37), inverter fixed, no jitter, freestanding off.
10. Freestanding via NL `Angles > Freestanding` with per-state disablers; "static" variant = `Disable Yaw Modifiers` ON + `Body Freestanding` OFF.
11. Manual yaw L -90 / R +90 / F 180 / B 0 at Local View; "static" variant kills modifier + fixes body 60/60.
12. Legit AA on +use: swallow `cmd.in_use`, yaw +180, pitch Disabled, base Local View; blocked while holding C4 / near planted C4 as CT / a usable entity is traced in front.
13. Warmup / no-enemy AA: spin, sine distortion, L/R flip, pitch off, `cmd.no_choke = true`.
14. Fake lag: OFF while DT or HS (they fight), limit 1 while the exploit recharges (Andromeda "fix recharge delay"), limit clamped to ≥14 (elysian).
15. Air exploits: gingersense (force_defensive every tick + force_charge + teleport every 6), evalate (every N airborne ticks: force_defensive + DT fake lag limit random 1-7 + `rage.exploit:force_teleport()`), elysian (alternate NL Fake Duck every other airborne tick).
16. Animation breakers all read the anim-layer array at **entity + 10640 (0x2990)** through FFI (`CAnimationLayer` struct: pad 20, order, sequence, prev_cycle, weight, weight_delta_rate, playback_rate, cycle, owner) from `events.post_update_clientside_animation`; layer 12 weight = move lean, layer 6 weight = air legs; pose params 0/6/7/8/12 for leg breaker / falling / landing pitch.

## Config / preset systems (what the luas do)

- Storage: the NL global `db[...]` table (nexus `db["NEXUS::USERDATA"]`, spectral `db["spectral-db"]` + `everlast-presets`, gasolina `db.vorona1`, Andromeda `andromeda_cfg_store`, elysian `db["elysian_db"]` + versioned keys, DEMONTIME `db["demontime_presets"]`). Autosave every 2s from render (elysian) or on shutdown.
- Serialization: `json.stringify` → `require("neverlose/base64").encode` (DEMONTIME double-wraps `{config, time}`), Andromeda adds a 4-byte length prefix, arc xor-obfuscates + msgpack, elysian uses a shuffled base64 alphabet, evalate wraps `evalate>b64<` / `evalate[Builder:T:Stand]>b64<`, DEMONTIME `dtcfg_<b64>_dtcfg`.
- Clipboard: `require("neverlose/clipboard")` `.set/.get`; spectral uses vgui2 `VGUI_System010` vfuncs 7/9/11.
- UI pattern: `:list("##PRESET_LIST", items)` + `:input("##PRESET_NAME", "Default")` + icon buttons (floppy-disk Save, upload Load, copy Export, paste/download Import, trash delete in red `\aDB6361FF`, check / xmark confirm pair hidden until needed via `:visibility(false)`), built-in presets marked and un-deletable ("Can't modify in-built preset"). pui `:depend()` chains for sub-rows.
- **Cheapest possible config share**: NL tab handles support `:export()` / `:import(json)` natively (`inport-export.lua`: `ui.find("Aimbot","Anti Aim"):export()`), and groups support `group:export()` (arc). A whole-config share is base64(json) over the clipboard in ~40 lines.

## Menu presentation patterns

- pui (`require("neverlose/pui")`): `pui.create(icon, name, column)`, `pui.setup(menu, true)` registers save/load, `pui.sidebar(name, icon)`, labels `"\v\f<icon>\r  name"` (`\f<icon>\r` = font-awesome glyph inline, `\v` = accent), sub-options dimmed with `"\aA0A0A0FF" .. lower(name)` (elysian) or prefixed `"\a{Link Active}•\aDEFAULT   Label"` / `"\a{Link Active}›\aDEFAULT   Sub"` (Andromeda). Column names as whitespace strings (`"   "`, `"         "`) render header-less groups (elysian).
- Page switching inside a tab: `:list("", {"Ragebot","Visuals","Misc"})` + `:visibility(idx == n)` on each group (Andromeda / spectral / DEMONTIME), or pui `depend`.
- Sidebar branding: `ui.sidebar(text, icon)` every frame with a per-character color wave (lerp `ui.get_style("Link Active")` → `"Text Preview"` with `sin(realtime)`), spectral/gasolina/elysian/Andromeda all do it.
- Menu sounds: `cvar.playvol:call("ui/buttonrollover", 1)` (press), `"ui/menu_accept.wav"` (success), `"ui/panorama/lobby_error_01.wav"` (error), `"play ui/beepclear"` via console_exec.
- `label:name(text)` updates label text at runtime (used for preset info rows, "Author: X / Updated: Y").
- Multi-state color pickers: `:color_picker("Color", {Active = {color}, Inactive = {color}})` returns a picker with palette presets (Andromeda, arc, gasolina TS arrows).

## On-screen visual language (the "premium" look, verified render API)

- **Glass pill**: outer 22%-alpha shadow rect, triple `render.blur` (radius 6/3/1 at 0.85/0.55/0.25), body `render.rect(p1,p2,color(15,15,18,210), rounding 6-8)`, a 44%-height top gloss at alpha 22, `render.rect_outline(..., color(255,255,255,40))`. Text with a black 45%-alpha shadow 1px offset.
- **Side indicators** (elysian / Andromeda / nexus / arc): vertical list at the LEFT edge (x=6) stacking UPWARD from `screen.y - 350`, rows 20px + 4 gap, mirrored two-half `render.gradient` (transparent → dark → transparent) as background, text + optional progress ring (`render.circle_outline(center, black, 10, 0, 1, 5)` then `(center, color, 9, 0, fraction, 3)`), rows slide in / fade out. Keywords `PING / OSAA / DT / DA / DUCK / SAFE / BODY / MD / HC / FS / DEF / LC`, DT red until `rage.exploit:get() == 1`, then white/green. Bomb rows `A - 3.4s`, `-37 HP` / `FATAL`, defuse bar 20px at the screen edge.
- **Crosshair stack** (evalate / nexus / spectral / elysian): under the crosshair, centered: script name in a moving gradient, `* STANDING *` state word, DT with a charge ring, HS, BODY, SAFE, DMG, FS; modern style reveals text with `render.push_clip_rect` width wipes and flanking `·` dots; each line has its own smoothed alpha (`neverlose/smoothy`).
- Desync bar: two mirrored gradient wings sized by `|normalize_yaw(get_rotation(true) - get_rotation())| / get_max_desync()`.
- Manual arrows: Classic `<` `>` `^` (Verdana 14-20), Modern `⮜ ⮞ ⮝` (Verdana 27 "ab"), gazolina TS = `render.poly` triangles ±55px + 2px desync bars ±38-40, colors Yaw `175,255,0` / Body `0,200,255`, inactive `35,35,35,150` lerped with `easing.quad_in_out`.
- Watermark: 4 corners or bottom center, `Verdana 12-13.5`, margin 11, pad 4/2, bg `7,11,20,80`, outline `25,32,60,50`, text `155,175,190`; content `logo · user · fps · ping · time`, shimmer sweep.
- Keybinds: glass panel 120-160px, header "keybinds", rows from `ui.get_binds()` (`.name`, `.mode`, `.active`), strip `\a%x%x%x%x%x%x%x%x` / `\a%b{}` escapes, per-row smoothy alpha; synthetic entries for script states.
- Hit marker: 4 diagonal double lines with a 1px black shadow, radius 5→10 cubic ease-out over 0.4s, hooks `player_hurt` (+ `player_blind`); kill = gold; damage numbers float at the aim point via `render.world_to_screen`.
- Velocity: icon box + label box + clipped fill bar (already in Sel01 since v3.20, frostlive style).
- Network metrics: `fps N (99%: M)` (mean of worst 2% frametimes), `ping Nms (T ticks) loss L% (C%)`, `server F +- Dms rate R tps`, lines flash to accent on spikes.
- Draggable widgets: hidden `slider("<name>:x"/":y", -16384, 16384)` pair per widget, `ui.get_mouse_position()` + `common.is_button_down(1)`, drag only while the menu is open (elysian: only on its Visuals→ui page), clamp to screen.
- Fonts: `render.load_font("Verdana", 27, "ab")`, `("Calibri Bold", vector(25,23.5), "da")`, `("Trebuc", 13, "ad")`, Inter downloaded from a CDN (elysian). Flags: `a` = antialias, `b` = bold, `d` = dropshadow.

## Verified NL `ui.find` paths (union of all luas)

```
Aimbot,Ragebot,Main,Enabled                  (+ ,Dormant Aimbot | ,Silent Aim | ,Extended Backtrack)
Aimbot,Ragebot,Main,Hide Shots               (+ ,Options)
Aimbot,Ragebot,Main,Double Tap               (+ ,Lag Options | ,Fake Lag Limit | ,Immediate Teleport | ,Quick-Switch)
Aimbot,Ragebot,Main,Peek Assist              (+ ,Style | ,Auto Stop | ,Retreat Mode | ,Max Distance)
Aimbot,Ragebot,Main,Field of View
Aimbot,Ragebot,Selection,Hit Chance | Min. Damage | Hitboxes | Multipoint,Head Scale | Multipoint,Body Scale | Penetrate Walls
Aimbot,Ragebot,Selection,Global,Min. Damage
Aimbot,Ragebot,Selection,<weapon>,Min. Damage | Hit Chance | Min. Damage,Delay Shot | Multipoint,Head Scale | Multipoint,Body Scale   (<weapon> = SSG-08, AWP, Desert Eagle, Pistols, Zeus x27, ...)
Aimbot,Ragebot,Safety,Body Aim               (+ ,Disablers | ,Force on Peek)
Aimbot,Ragebot,Safety,Safe Points | Ensure Hitbox Safety
Aimbot,Ragebot,Safety,<weapon>,Body Aim | Safe Points | Ensure Hitbox Safety
Aimbot,Ragebot,Accuracy,Auto Scope | Auto Stop | Auto Stop,Options
Aimbot,Ragebot,Accuracy,<weapon>,Auto Stop | Auto Stop,Options
Aimbot,Anti Aim,Angles,Enabled | Pitch | Yaw | Yaw,Base | Yaw,Offset | Yaw,Avoid Backstab | Yaw,Hidden
Aimbot,Anti Aim,Angles,Yaw Modifier | Yaw Modifier,Offset
Aimbot,Anti Aim,Angles,Body Yaw | ,Inverter | ,Left Limit | ,Right Limit | ,Options | ,Freestanding
Aimbot,Anti Aim,Angles,Freestanding | ,Disable Yaw Modifiers | ,Body Freestanding
Aimbot,Anti Aim,Angles,Extended Angles | ,Extended Pitch | ,Extended Roll
Aimbot,Anti Aim,Fake Lag,Enabled | Limit | Variability
Aimbot,Anti Aim,Misc,Fake Duck | Slow Walk | Leg Movement
Miscellaneous,Main,Movement,Air Strafe | Air Strafe,WASD Strafe | Strafe Assist | Air Duck | Quick Stop | Edge Jump | Bunny Hop
Miscellaneous,Main,Other,Fake Latency | Weapon Actions | Log Events | Windows | Unlock Hidden Cvars
Miscellaneous,Main,In-Game,Clan Tag | Shared Features
Visuals,World,Main,Force Thirdperson (+ ,Distance) | Removals | Field of View | Override Zoom,Scope Overlay | Override Zoom,Force Viewmodel
Visuals,World,Ambient,Night Mode | Static Props | Post Processing | Fog Changer (+ ,Color ,Start ,Distance) | Illumination (+ ,Pitch ,Yaw ,Distance ,Color)   -- switch+color pairs return TWO handles: {ui.find(...)}[1]/[2]
Visuals,World,Other,Hit Marker,3D Marker | Damage Marker | Grenade Prediction,Color | Color Hit
Visuals,Players,Self,Chams,Weapon (+ ,Color ,Style) | Chams,Model,Transparency
Settings,Animation Speed
```
Option strings: Pitch `Disabled | Down | Fake Up | Fake Down`; Yaw `Disabled | Backward | Static`; Base `Local View | At Target`; Modifier `Disabled | Offset | Center | Random | Spin | 3-Way | 5-Way`; Body Yaw Options `Avoid Overlap | Jitter | Randomize Jitter | Anti Bruteforce`; Body Freestanding `Off | Peek Fake | Peek Real`; Leg Movement `Walking | Sliding`; DT Lag Options `On Peek | Always On`; Hide Shots Options `Favor Fire Rate | Favor Fake Lag | Break LC`; Peek Assist Retreat Mode `On Shot | On Key Release`; Safe Points `Default | Prefer | Force | Off`; Scope Overlay `Remove All`. Matching is case-insensitive.

## Other API facts collected

- `ui.get_binds()` → array of `{name, mode, active, value, id()}`; MD/HC indicators match `.name == "Min. Damage"` / `"Hit Chance"` or `reference:id() == bind:id()`; override detection `ref:get_override() ~= ref:get()`.
- `rage.antiaim:get_rotation(true)` fake yaw, `:get_rotation()` real, `:get_max_desync()`, `:get_target(true)` (freestanding target), `:inverter([bool])`.
- `rage.exploit:get()` charge 0-1, `:get(true)`, `:get_defensive()`, `:allow_defensive(bool)`, `:force_charge()`, `:force_teleport()`.
- `lp:simulate_movement()` → sim with `:think(n)`, `.origin`, `.velocity` (nexus edge stop, gasolina peek detection).
- `utils.trace_line(from, to, skip, mask)`, `utils.trace_hull(from, to, mins, maxs, skip, mask)` (mask `33636363` players+world, `33570827`), `utils.trace_bullet(lp, from, to, skip)` → damage, trace; `utils.net_channel().latency[1]/.loss[1]/.choke[1]`; `utils.console_exec`, `utils.execute_after(t, fn)`, `utils.opcode_scan`, `utils.get_vfunc`, `utils.create_interface`.
- `events.post_update_clientside_animation`, `events.createmove_run`, `events.net_update_start/end`, `events.grenade_override_view`, `events.grenade_prediction`, `events.override_view`, `events.localplayer_transparency(fn)`, `events.draw_model(fn)`, `events.voice_message` (used for peer badges), `events.mouse_input`, `events.level_init`, `events.player_blind`, `events.item_purchase`.
- `cmd` fields written by the luas: `force_defensive`, `no_choke`, `send_packet`, `in_use/in_duck/in_jump/in_speed/in_attack/in_attack2`, `forwardmove/sidemove/move_yaw`, `view_angles`, `block_movement`, `jitter_move`, `skip_animation_this_tick`.
- `common.set_clan_tag`, `common.set_name` (name steal with U+3164 filler), `common.get_map_data().shortname`, `common.force_full_update()`, `common.add_event(text, icon)`, `panorama.SteamOverlayAPI.OpenExternalBrowserURL`, `panorama.MyPersonaAPI.GetName`, `cvar.<name>:int()/:float(v[, true])/:call()`, `entity:set_icon(url)`.
- `db` = NL persisted global table (all config systems use it). `files.read/write/create_folder` (no binary).
