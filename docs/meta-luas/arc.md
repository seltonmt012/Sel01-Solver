# arc.lua (6,842 lines, partially readable) — "Arc" 1.1 Release by tickcount — NO anti-aim

QoL / movement / visual / config companion (Chimera / Solus market). Only AA-adjacent writes: `Anti Aim > Misc > Leg Movement :override("Walking")` (Directional Legs) and `Miscellaneous > In-Game > Clan Tag :override(false)` while the tag spammer runs. Read-only: `rage.exploit:get()`, `rage.antiaim:get_target(true)`, `entity.get_threat(true)`.

## Architecture worth stealing

- Everything is one IIFE building ~35 lazily-initialized feature closures returning `{enabled, callback}`; a loop initializes each with pcall ("failed to initialize %s biome").
- **Event wrapper `v102(event, cb, state, is_override)`**: unified enable / disable via `:set_callback` / `:unset_callback` or `:set` / `:unset`, works for `events.*`, cvar objects AND NL menu items — features toggle callbacks on / off instead of early-returning.
- **Callback-priority watchdog**: tracks `#event` every 0.1s via `utils.execute_after`; if another script registered later it unregisters + re-registers to reclaim top priority.
- Label builder `v82(icon, text, padL, padMid, padR, color)`: pads with U+0020 and U+200A hair spaces via greedy packing, prefixes `ui.get_icon(name)` in `\a{Link Active}` → pixel-aligned icon + text rows.
- String obfuscation: XOR with key `"b1 c8 9a 05 4f 0e 3c 64"` over `ffi.new("char[?]")` for preset payloads.
- Menu sounds `cvar.playvol:call("ui\\buttonrollover", 1)`, `"ui\\item_drop"`, `"ui\\menu_back"`. Sidebar: per-character gradient of "Arc" lerping `Link Active` → `Text Preview` with `sin(realtime*1.5)`, icon `brackets-curly`, `ui.sidebar(text, "artstation")`.
- Uses NL styles only (`ui.get_style("Link Active" / "Text Preview" / "Small Text" / "DEFAULT")`); palette bg `7,11,20,80|45`, outline `25,32,60,50|60`, text `155,175,190`, warn `\aB6B665FF`, error `\aFF3E3EFF`, gs-green `\a95B806FF`, delete-red `\aDB6361FF`, debug-cyan `\a6BBCAFFF`.

## Menu

Tab 1 `house` (About): WIP warning, Report Bugs → Discord, username + `1.1 Release`, Statistics (Enemies killed / Time played / Time spent — click toggles minutes vs humanized; kills only count with `bot_stop 0`, `host_timescale 1`, `mp_respawn_on_death_* 0`, `sv_infinite_ammo 0`), Our Products (themes Arc Night 4FF9FF / Desert FFB84F / Autumn FF5065 + getitem URLs, scripts, configs).
Tab 2 `list-tree` pages Features / World / Other:
- Features: Arc Reflex, Force Interpolation, Viewmodel (FOV 0-1000 ×0.1, offset X / Y / Z -100..100, Opposite Knife Hand, Force CS:S Animations), VGUI Color (50,50,75,200), Game Focus, Unmute Players (Disabled / Enemies / Teammates / Everyone), Player Name reset / Steal; Movement: Avoid Collisions, Collision Air Duck, No Fall Damage, Fast Ladder, Fast Walk, Edge Quick Stop; Weapon: Super Toss, Quick Throw, Quick Interactions, Grenade Release (Min. Damage 1-50 def 50).
- World: Colored Weapons per weapon (Chams Disabled / Default / Material / Glow / Glass / Solid, color, style color, Texture (26 VMTs), Variable Flags No Draw / Additive / Nocull / Ignorez / Wireframe; categories Grenades / Knives / per-id / Global), Ambient (Wall Dyeing 33,33,34,135, Bloom -1..250, Exposure -1..200, Model Brightness 0-200), Removals (No Blood, Disable Teammate Rendering, Disable Ragdolls Default / Physics / Rendering), Flashlight, Override Weather, Visualize Exploits (color FF0000, thickness 0-100 def 35).
- Other: Player Animations (Interpolate / Disable Move Lean / Landing Zero-Pitch / Preserve Animated Tick, Amount 1-16 def 2 t, Falling Animation Default / Force / Legacy, Directional Legs Ground / Jumping), Shared Features (Cheat Revealer, Shared Logo (on), Clan Tag Spammer), Watermark (Upper-Left / Upper-Right / Bottom-Left / Bottom-Right, def 4), Screen Indicators listable, Network Metrics (Framerate / Connectivity / Server Responsiveness + "Flash if Below Monitor's Frequency"), Hit Marker, Grenade Trajectory, Grenade Proximity Warning, Keep Model Transparency, Inaccuracy Overlay (Simple / Fade palettes), Log Events (Purchases / Damage Dealt), Github.
Tab 3 `flask-round-potion` Presets: list, input `##PRESET_NAME` def "Default", export / import / delete / Save / Load + Cancel / Confirm flow, empty-state "Nothing to see here...". Registry of 9 tabs: Arc Features / World / Other (author_only false) + native NL tabs World / Players / Ragebot / Anti-Aim / Inventory / Miscellaneous (author_only true). Serialization `base64(xor(msgpack({creator, created_at, settings})))` with entries `{tab_idx, group_idx, json.parse(group:export())}`; import `group:import(json.stringify(...))`, `common.force_inventory_update()` for the Inventory group. Persisted `db["arc_presets"]`. Author gate `get_username() == get_config_author() or get_script_author()`.

## Implementations

- Reflex: `NtSetInformationProcess(hProc, 39, {5})` + `(33, {2})`, `SetThreadPriority(hThread, 2)` every 0.5s.
- Force Interpolation: `utils.opcode_scan("client.dll", "57 8B F9 8B 07 8B 80 ? ? ? ? FF D0 84 C0 75 35")` → `memory.hook_func`, swallows the interpolation reset for the local player; forces `cl_predictweapons 0`; red "PREDICTION ERROR" at `(0.5, 0.9785)`.
- No Fall Damage: `utils.get_vfunc(76/77, "float*(__thiscall*)(void*)")` mins / maxs for a jumpbug.
- Weather: `VClient018` idx 8 entity list, linked-list walk, `common.force_full_update()`.
- Disable Ragdolls: `ffi.cast("void**", uint32(ent[0]) + 10752)[0] = nil` on class 42; mode 2 sets `m_nRenderMode = 10`.
- Player Animations: `m_AnimOverlay` at +10640; writes `m_flPoseParameter[0/6/7/12]`, zeroes `layer[12].weight` (move lean), forces `layer[6].weight` for airborne directional legs, EMA-smooths pose params + weights with `alpha = tickinterval * amount`; `cmd.skip_animation_this_tick = true` for Preserve Animated Tick.
- Console Color: `materials.get_materials()` on `vgui_white`, `vgui/hud/800corner1..4`, `color_modulate` / `alpha_modulate`, gated by `VEngineClient014[11]` Con_IsVisible, hooks `cvar.toggleconsole`.
- Game Focus: user32 `GetForegroundWindow / SetForegroundWindow / SetFocus / ShowWindow`, HWND via `opcode_scan("engine.dll", "8B 0D ? ? ? ? 85 C9 74 16 8B 01 8B", 2)` then `((void***)p)[0][0] + 8`, queue via `panorama.PartyListAPI.GetPartySessionSetting("game/mmqueue")`.
- Network Metrics: `EnumDisplaySettingsA` + full `DEVMODE` for `dmDisplayFrequency`.
- Grenade Warning: `VEngineClient014[37]` view matrix.
- Unmute: `panorama.GameStateAPI` (`IsXuidValid`, `HasCommunicationAbuseMute`, `IsSelectedPlayerMuted`, `ToggleMute`, `GetPlayerXuidStringFromEntIndex`, `GetPlayerXuidFromUserID`) on `player_connect_full`.
- Name steal: random teammate name + `common.set_name(name .. "\227\133\164")` (U+3164), restore via `panorama.MyPersonaAPI.GetName`.
- Clan Tag Spammer: scrolling 15-char window of "arc.lua", index `(tickcount + to_ticks(avg_latency)) / to_ticks(0.3)` with an 8-frame dwell at center, static during `m_timeUntilNextPhaseStarts > 0`, optional random case jitter.

## HUD

- **Screen Indicators**: font `Calibri Bold` `vector(25, 23.5)` "da", anchored `vector(30, screen.y - 345)`, stacking upward (`y -= text.y + 17`); row = `render.rect(color(7,11,20,45), 8)` + `rect_outline(color(25,32,60,60), 0, 8)`, optional SVG icon 32×32 (`bomb_c4.svg`), text, progress ring (bg black 200 r10 t5, fg white 200 r9 t3). Features: Aimbot Statistics (hit % from `aim_ack`; miss = any state other than death / unregistered shot / player death), Ping Spike, Fake Duck, Hide Shots, Double Tap, Safe Point, Body Aim, Minimum Damage, Hit Chance Override, Dormant Aimbot, Freestanding, Defusing, Bomb Information. Tokens `%d%%`, PING, DUCK, OSAA, DT (green charged / `255,0,40,200`), SAFE, BODY, MD, HC, DA, FS (red without target), DEF + ring, bomb `A - 3.4s`, `-N HP` / `FATAL`. Binds via `ui.get_binds()` name `Min. Damage` / `Hit Chance` + `.active`. DUCK suppresses OSAA / DT; DT suppresses OSAA.
- **Watermark**: Verdana 11.86 / 13.5, 4 corners, margin 11, pad 4/2, bg `7,11,20,80`, outline `25,32,60,50`, text `155,175,190`, rounding 7; auto-off when Network Metrics is on.
- **Network Metrics**: at `x = screen.x * 0.59765`, `y = screen.y - h - 48`; `fps: N (99%: M)`, `ping: Nms (T ticks) loss: L% (C%)`, `server: F +- Dms rate: R tps`; lines lerp to Link Active for 1s (falloff 1.35) on threshold trips; 99th-percentile FPS = mean of the worst 2 % frametimes; header "Arc Metrics" at 0.85 alpha.
- **Hit Marker**: 4 diagonal double lines with a 1px black shadow (`color(0, a*0.5)`), radius 5→10 cubic ease-out 0.4s, hooks `player_hurt` and `player_blind`.
- **Visualize Exploits**: `lagrecord.get_snapshot(player)`, `snapshot.command.no_entry` → 3D wireframe box (15 edges, `record:render(a, b, thickness, "lgw", color)`) at `snapshot.origin.current + volume`, alpha `0.35 * (no_entry.x / no_entry.y)`, skipped while spectating that player.
- Shared Logo: custom netmessage over `events.voice_message` (`server_tick(32) | hash(32) | ID 393317(32) | signature(4)`, `buffer:crypt(".ZnVtaW5v|")`); Cheat Revealer via `voice_listener.get_software(player)` → `player:set_icon(icon)`.

## ui.find paths

`Miscellaneous,Main,Movement,Air Strafe,WASD Strafe / Edge Jump / Bunny Hop`; `Miscellaneous,Main,Other,Weapon Actions / Log Events / Fake Latency`; `Miscellaneous,Main,In-Game,Clan Tag`; `Aimbot,Anti Aim,Misc,Fake Duck / Leg Movement`; `Aimbot,Anti Aim,Angles,Freestanding`; `Aimbot,Ragebot,Main,Enabled (+ ,Dormant Aimbot) / Hide Shots / Double Tap`; `Aimbot,Ragebot,Safety,Safe Points / Body Aim (+ ,Disablers)`; `Visuals,World,Main,Removals`; `Visuals,World,Ambient,Post Processing` (2 returns); `Visuals,World,Other,Grenade Prediction (+ ,Color / ,Color Hit)`; `Visuals,Players,Self,Chams,Weapon (+ ,Color / ,Style)`; `Visuals,Players,Self,Chams,Model,Transparency`; group refs `Aimbot,Ragebot`, `Aimbot,Anti Aim`, `Visuals,World,*`, `Visuals,Players,*`, `Visuals,Inventory`, `Miscellaneous,Main`.
