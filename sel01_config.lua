-- ╔══════════════════════════════════════════════════╗
-- ║  Sel01-Config — Neverlose CSGO HvH config        ║
-- ║  Author: seltonmt01                              ║
-- ║  Version: 3.29                                   ║
-- ╚══════════════════════════════════════════════════╝
-- @name Sel01-Config
-- @author seltonmt01
-- @version 3.31
-- @description AI Peek hittable-gate (only peek when min-dmg shot exists):
--   * v3.28 peeked at any in-range enemy → walked constantly. v3.29 arms the
--     peek ONLY while a fresh events.aim_fire (estimated damage >= the user's NL
--     Min. Damage) says the enemy is provably hittable. No shootable enemy → no
--     aim_fire → the bot holds position. Peek direction now comes from the
--     aim_fire world aim point (event.aim — safe vector, no entity read).
--   * aim_fire re-enabled (disabled since the v1.13 bisect) for THIS gate only;
--     reads numeric fields + the aim vector, never event.target's entity props.
-- @description-prev AI Peek (auto peek-shoot-retreat):
--   * New Movement feature (default OFF). When an enemy is within Max Range and
--     the equipped weapon matches the filter, the bot strafes out toward the
--     target for a short peek window (cmd.move, WalkBot-style — aiming stays with
--     the ragebot), raises ragebot Hit Chance + optionally drops Safe Points for
--     that window only, then strafes back to the cover anchor. Hold-hotkey or
--     always-on trigger, rate-limited. Original Sel01 code (inspired by, not a
--     copy of, angelwings). HEURISTIC range/weapon gate — NOT a physics hit-sim.
--   * The HC / Safe-Point writes deliberately break the v9.18 never-override rule
--     (user-requested full-send) and are restored the instant the peek ends.
-- @description-prev Smart freestand (anti-headshot):
--   * NL freestanding is deterministic — it always picks the same "safe" side, so a
--     resolver models it and headshots the predictably-exposed side (user report:
--     "head outside because of freestand"). New OFF→ON toggle auto-DISABLES freestand
--     during the chaos states (defensive after a hit / slow-walk) so the randomized
--     body-yaw inverter controls the side → head peeks an unpredictable side under
--     fire. Freestand still protects normally; restored on the falling edge.
-- @description-prev Slow-walk / defensive / air ANTI-EMA two-cluster magnitude:
--   * These "sitting-duck" states used to sit at a FIXED center (58 for slow/def,
--     the air slider for air) and rely on symmetric anti-BF noise — which an EMA
--     resolver averages straight back to that center and beams you (hits-taken log
--     showed every hit at desync=58, resolved clean).
--   * Now they alternate TWO magnitude clusters (~base / ~base-22) every 0.4-1.1s
--     so the resolver's tracked mean lands in the empty GAP and matches neither.
--     Side is already randomized per-tick for these states (v3.6), so now both
--     side AND magnitude are unpredictable. Auto — no toggle; user mag-jitter /
--     bimodal still override it.
-- @description-prev Correlated (anti-median) jitter:
--   * New OFF-default toggle replaces the independent symmetric per-side noise
--     with a CORRELATED pattern: sawtooth ramp (same-sign deltas → EMA chases
--     but never centers) or anti-phase L/R (sides pushed opposite from one
--     shared sine phase → whichever side the resolver locks, the other is
--     maximally wrong). Median/EMA trackers smooth symmetric noise to its mean;
--     correlated patterns deny that. Amplitude slider 5-38°.
-- @description-prev Bimodal magnitude (two-cluster anti-EMA AA):
--   * New OFF-default toggle alternates desync between two fixed clusters
--     (default 25° / 55°) every 2-5s with a small ±3° wobble, instead of
--     uniform random. A uniform jitter's mean IS its center, which an EMA /
--     median resolver locks onto exactly; bimodal's long-run mean sits in the
--     empty gap between clusters, so the tracked value matches no real shot.
--   * Mutually exclusive with Magnitude jitter; drives the same body-yaw refs.
-- @description-prev Event-log forward-decl fix (hit_log ring):
--   * hit_log / HIT_LOG_MAX were declared AFTER the aim_ack + player_death
--     closures that write them → Lua bound the writers to a nil global, so
--     table.insert silently threw inside their pcall. The top-left event log
--     never recorded AND the v3.7 side-streak anti-resolver tracker (same
--     pcall) never ran. Moved the decls above the closures.
-- @description-prev Magnitude jitter (per-tick variance, anti-EMA-resolver):
--   * New toggle randomizes the desync magnitude between [min, max] every
--     periodic-sync tick instead of using a fixed value.
--   * Resolvers that track measured_desync via EMA (including Sel01-Solver
--     v9.x) settle to the AVERAGE of the randomized values — actual fake
--     yaw stays 5-15° off that average every shot. Breaks the lock-on path.
--   * Default OFF. Sliders default 35-58° range. Combines with anti-BF
--     variance for full per-side chaos.
--   * MAG-JIT indicator added to bottom HvH strip; dumped in v3.8 stats.

local SEL01_CFG_VERSION = "3.31"

-- DEBUG: print to CSGO console at major load checkpoints. Plain print() bypasses
-- NL chat (which may not flush before crash) and writes directly to CSGO console.
local function _dbg(n, label) pcall(function() print("[Sel01-Config DBG] M" .. n .. " " .. (label or "")) end) end

local pui      = require("neverlose/pui");
local ffi      = require("ffi");
local gradient = nil
pcall(function() gradient = require("neverlose/gradient") end)

local CS_PREFIX = "[Sel01-Config]"
local function cs_log(msg)
    pcall(print, CS_PREFIX .. " " .. tostring(msg))
end
local function cs_log_color(msg)
    local ok = pcall(function() client.color_log(180, 220, 140, CS_PREFIX .. " " .. tostring(msg)) end)
    if not ok then cs_log(msg) end
end

local accent = "\a{Link Active}"
local TAB    = "Sel01-Config"

-- ══════════════════════════════════════════════════════════════════════════
-- UI GROUPS
-- ══════════════════════════════════════════════════════════════════════════
-- v3.22: chernobl-style TABS. Multiple distinct ui.create() first-args render as a
-- horizontal tab bar inside the script's sidebar entry (confirmed via NL docs:
-- "ui.create(tab, group[, column])" + "ui.sidebar(name, icon)"). ui.sidebar sets the
-- sidebar entry label + icon. Column 1 = left, 2 = right within each tab.
-- One-time effect: re-tabbing re-keys UI elements, so this script's own toggles reset
-- to defaults on the first reload — click a preset (Aggressive) once to restore. NL
-- ragebot settings are separate and untouched.
pcall(function() ui.sidebar(TAB, "sliders") end)
local T_MAIN = ui.get_icon"sliders" .. "  Main"
local T_AA   = ui.get_icon"bolt"    .. "  Anti-Aim"
local T_VIS  = ui.get_icon"eye"     .. "  Visuals"
local g_main    = ui.create(T_MAIN, "Presets",         1)
local g_qol     = ui.create(T_MAIN, "Quality of Life", 2)
local g_info    = ui.create(T_MAIN, "Info",            2)
local g_aa      = ui.create(T_AA,   "Anti-Aim",        1)
local g_visual  = ui.create(T_VIS,  "Visuals",         1)
local g_move    = ui.create(T_VIS,  "Movement",        2)

-- Header — v3.21: chernobl-style multi-color welcome (\aDEFAULT resets to white
-- between accent-colored segments, like "Dear <accent>name<reset>, ...").
local _uname = (common and common.get_username and common.get_username()) or "player"
g_main:label(ui.get_icon"user" .. "  Dear " .. accent .. _uname .. "\aDEFAULT, have a good game!")
g_main:label(ui.get_icon"sparkles" .. "  Build " .. accent .. "Sel01-Config" .. "\aDEFAULT  version " .. accent .. SEL01_CFG_VERSION .. "\aDEFAULT")
g_main:label(ui.get_icon"bolt" .. "  Companion to " .. accent .. "Sel01-Solver" .. "\aDEFAULT (resolver)")
g_main:label(" ")
g_main:label(accent .. ui.get_icon"sliders"  .. accent .. "  Playstyle Presets:")

-- Forward-decl preset applier so callbacks see it at call-time, not parse-time
local apply_preset_fwd
local btn_aggressive = g_main:button("Aggressive (full send)",   function() apply_preset_fwd("aggressive") end)
local btn_dynamic    = g_main:button("Dynamic (balanced)",       function() apply_preset_fwd("dynamic")    end)
local btn_defensive  = g_main:button("Defensive (safe AA)",      function() apply_preset_fwd("defensive")  end)
local btn_spin       = g_main:button("Spin (full spinbot)",      function() apply_preset_fwd("spin")       end)
local btn_troll      = g_main:button("Troll / Bait (run-in chaos)", function() apply_preset_fwd("troll")    end)

g_main:label(" ")
local enable_master = g_main:switch(accent .. ui.get_icon"power" .. accent .. "  Master Enable (all features)", true)

-- ══════════════════════════════════════════════════════════════════════════
-- ANTI-AIM UI
-- ══════════════════════════════════════════════════════════════════════════
g_aa:label(accent .. ui.get_icon"target" .. accent .. "  Anti-Aim Override (uses events.antiaim hook + NL UI fallback)")
local aa_enable      = g_aa:switch("Enable AA Override", false)
local aa_pitch       = g_aa:combo("Pitch", {"Off", "Down", "Up", "Jitter Down/Up", "Custom"}, 2)
local aa_pitch_cust  = g_aa:slider("Pitch Custom (deg)", -89, 89, -89)
local aa_yaw_base    = g_aa:combo("Yaw Base", {"Forward", "Backward", "Left", "Right", "AtTarget"}, 2)
local aa_yaw_add     = g_aa:slider("Yaw Add (deg)", -180, 180, 0)
local aa_yaw_mod     = g_aa:combo("Yaw Modifier", {"None", "Center", "Offset", "Random", "Jitter"}, 5)
local aa_yaw_mod_mag = g_aa:slider("Jitter Magnitude (deg)", 5, 60, 30)
local aa_yaw_mod_int = g_aa:slider("Jitter Interval (ticks)", 1, 16, 2)
local aa_desync      = g_aa:slider("Desync Range (deg)", 0, 60, 58)
local aa_desync_side = g_aa:combo("Desync Side", {"Auto (alternate)", "Left", "Right", "Random"}, 1)
local aa_freestanding= g_aa:switch("Freestanding (auto-best-side)", true)
-- V3.14: NL freestanding is DETERMINISTIC — it always picks the same "safe" side, so
-- a resolver models it and headshots the predictably-exposed side (user report). When
-- this is on, freestand is auto-DISABLED during the chaos states (defensive after a
-- hit / slow-walk) so the RANDOM body-yaw inverter controls the side → the head peeks
-- an unpredictable side under fire. Freestand still protects you the rest of the time.
local aa_smart_free  = g_aa:switch("  └ Smart freestand (random side when beamed)", true)
local aa_at_targets  = g_aa:switch("Yaw points at targets (At-Target mode)", false)
g_aa:label(" ")
g_aa:label(accent .. ui.get_icon"bolt" .. accent .. "  HvH extras")
-- D: Force on-shot AA — different values during/after ragebot fire
local aa_onshot      = g_aa:switch("Force on-shot AA (more defensive after fire)", true)
local aa_onshot_dur  = g_aa:slider("On-shot duration (ms)", 100, 1500, 600)
-- F: Air desync override (V2.3 air-AA improvements for jumping aggressive play)
local aa_air_set      = g_aa:switch("Air desync override (airborne = different AA)", true)
local aa_air_mag      = g_aa:slider("Air desync magnitude (deg)", 10, 58, 35)
local aa_air_flip     = g_aa:switch("  └ Air rapid inverter flip (LBY break)", true)
local aa_air_boost    = g_aa:switch("  └ Air max jitter boost (yaw mod offset = 58)", true)
local aa_air_fakeduck = g_aa:switch("  └ Air force fake-duck (LBY break alt)", false)
-- V3.2 F-MOVE: Move desync override (running on ground)
local aa_move_set     = g_aa:switch("Move desync override (running ground)", false)
local aa_move_mag     = g_aa:slider("Move desync magnitude (deg)", 10, 58, 45)
local aa_move_thresh  = g_aa:slider("Move velocity threshold (u/s)", 50, 250, 100)
local aa_move_flip    = g_aa:switch("  └ Move rapid inverter flip", false)
local aa_move_boost   = g_aa:switch("  └ Move max jitter boost", false)
-- G: Anti-bruteforce jitter variance
local aa_anti_bf     = g_aa:switch("Anti-bruteforce jitter (random mag variance)", true)
local aa_anti_bf_var = g_aa:slider("Anti-BF variance (deg)", 5, 25, 15)
-- H: Fake-duck assist (V1.9: default OFF — hooks events.weapon_fire which fires for
-- audio/init events on spawn, suspected contributor to v1.8 spawn-crash)
local aa_fd_assist   = g_aa:switch("Fake-duck assist (auto on hostile-fire)", false)
local aa_fd_duration = g_aa:slider("Fake-duck duration (ms)", 200, 2000, 800)
g_aa:label(" ")
g_aa:label(accent .. "  Anti-headshot extras (default OFF — test first)")
-- V3.0 anti-HS: pitch jitter (head Y bobs)
local aa_pitch_jitter   = g_aa:switch("Pitch jitter (head Y bob Down/Up)", false)
-- V3.0 anti-HS: auto-fakeduck while moving (ducked head = different Y)
local aa_move_fakeduck  = g_aa:switch("Auto fake-duck while moving (ground only)", false)
local aa_move_fd_thresh = g_aa:slider("Move-FD velocity threshold (u/s)", 50, 250, 100)
g_aa:label(" ")
g_aa:label(accent .. ui.get_icon"shield" .. accent .. "  Anti-resolver (v3.6 / 3.7)")
-- V3.6: defensive AA when WE take damage. player_hurt (bullet hits only,
-- nade/world skipped) → max desync + random side flip for N seconds. V3.7:
-- force-fake-duck removed (was crouching mid-movement). Mobility kept.
local aa_def_on_dmg   = g_aa:switch("Defensive AA on hit-taken (bullet only)", true)
local aa_def_duration = g_aa:slider("  └ Defensive duration (ms)", 500, 4000, 2000)
-- V3.6: slow-walk = easy target. NL Slow Walk hotkey held → max desync 58 +
-- random side + 2× anti-BF variance so resolver can't pattern-lock us.
local aa_slow_boost   = g_aa:switch("Slow-walk AA boost (max desync + chaos)", true)
-- V3.6: periodic NL Fake Lag Limit variance (±2 ticks every 1–3s) to break
-- choke prediction. Off by default — may conflict with NL Double Tap.
local aa_fl_var       = g_aa:switch("Fake-lag variance (±2 ticks every 1–3s)", false)
-- V3.7: periodically rotate NL Yaw Base (Forward/Backward/Left/Right) every
-- 4-8s random. Breaks resolvers that learned our eye_yaw → fake_yaw mapping.
local aa_yaw_rotate   = g_aa:switch("Yaw base rotation (anti eye-yaw track)", false)
-- V3.7: force NL body-yaw inverter flip after N consecutive same-side shots.
-- Resolvers like ours track streak{L=9 R=0} → predict L; flipping breaks it.
local aa_side_streak  = g_aa:switch("Side-streak limit (auto flip after N shots)", true)
local aa_side_streak_n= g_aa:slider("  └ Flip after consecutive same-side shots", 2, 6, 3)
-- V3.9: per-tick magnitude variance. Randomize desync magnitude between
-- min/max every periodic-sync tick instead of a fixed value. Resolvers that
-- use EMA on measured_desync (including ours v9.x) settle to the AVERAGE of
-- the randomized magnitudes — so if user picks 35-58 their EMA → 46° but
-- the actual fake yaw cycles {35,42,51,58,38...} → always 5-12° off.
local aa_mag_jitter   = g_aa:switch("Magnitude jitter (per-tick variance, anti-EMA)", false)
local aa_mag_jit_min  = g_aa:slider("  └ Min magnitude (deg)", 10, 58, 35)
local aa_mag_jit_max  = g_aa:slider("  └ Max magnitude (deg)", 10, 58, 58)
-- V3.10: BIMODAL magnitude — alternate between TWO fixed clusters (e.g. 25° / 55°)
-- every 2-5s instead of uniform random. Uniform jitter's mean == its center, which
-- an EMA / median resolver locks onto EXACTLY; bimodal puts the long-run mean in the
-- EMPTY gap between the clusters, so the resolver's tracked value matches NO actual
-- shot. Strongest anti-EMA option. Mutually exclusive with magnitude jitter above.
local aa_bimodal      = g_aa:switch("Bimodal magnitude (two clusters, anti-EMA)", false)
local aa_bimodal_lo   = g_aa:slider("  └ Cluster A (deg)", 10, 58, 25)
local aa_bimodal_hi   = g_aa:slider("  └ Cluster B (deg)", 10, 58, 55)
local aa_bimodal_state = { mode = 1, next_switch = 0 }
-- V3.11: CORRELATED (anti-median) jitter. The anti-BF block draws TWO INDEPENDENT
-- zero-mean uniform offsets per side — but the median/EMA of symmetric independent
-- noise about `lim` IS `lim`, so a median tracker (incl ours) smooths it away.
-- Correlated patterns defeat that: a sawtooth ramp has same-sign successive deltas
-- (EMA chases but never centers); anti-phase pushes L and R in opposite directions
-- from one shared phase (whichever side the resolver locks, the other is max wrong).
local aa_corr_jitter    = g_aa:switch("Correlated jitter (anti-median)", false)
local aa_corr_antiphase = g_aa:switch("  └ Anti-phase L/R (off = sawtooth ramp)", false)
local aa_corr_amp       = g_aa:slider("  └ Amplitude (deg)", 5, 38, 20)
local aa_corr_phase     = 0
-- V3.13: alternation state for the slow-walk / defensive / air ANTI-EMA two-cluster
-- magnitude (replaces fixed-center-+-symmetric-noise, which EMA resolvers average out).
local slow_aa_state     = { mode = 1, next = 0 }
local _smart_free_off   = false  -- V3.14: dirty flag for smart-freestand override

-- ══════════════════════════════════════════════════════════════════════════
-- MOVEMENT UI
-- ══════════════════════════════════════════════════════════════════════════
g_move:label(accent .. ui.get_icon"running" .. accent .. "  Movement helpers")
-- V2.8 + V3.1: Peek Boost = HOLD hotkey. Lowers ragebot HC while held.
-- V3.5: MinDmg slider REMOVED — lua never overrides NL min_dmg (was eating user's 100).
local mv_peek_boost_k = g_move:hotkey("Peek Boost (hold)")
local mv_peek_hc      = g_move:slider("Peek HC", 10, 80, 30)
g_move:label(" ")
g_move:label(accent .. "  Bind same key as NL Peek Assist for 2-in-1")
g_move:label(accent .. "  Slow-walk / Fake-duck: NL Anti Aim/Misc tab")

-- V3.28: AI Peek — original Sel01 auto peek→shoot→retreat (inspired by the
-- angelwings feature; NOT a copy of its code). HEURISTIC, not a physics hit-
-- simulation: when an enemy is in range + the weapon matches the filter the bot
-- strafes out toward the target for a short "peek" window (driving cmd.move like
-- the WalkBot), raises ragebot Hit Chance + optionally drops Safe Points for that
-- window only, then strafes back to the cover anchor. The HC / Safe-Point writes
-- deliberately BREAK the v9.18 never-override rule (user-requested full-send) and
-- are restored the tick the peek ends / feature disables. Default OFF.
g_move:label(" ")
g_move:label(accent .. ui.get_icon"crosshairs" .. accent .. "  AI Peek (auto peek-shoot-retreat)")
local mv_aipeek        = g_move:switch("Enable AI Peek", false)
local mv_aipeek_mode   = g_move:combo("AI Peek Trigger", {"Hold Hotkey", "Always On"}, 1)
local mv_aipeek_key    = g_move:hotkey("AI Peek Key (hold)")
local mv_aipeek_range  = g_move:slider("Max Range (u)", 200, 4000, 2500)
local mv_aipeek_hold   = g_move:slider("Peek Hold (ms)", 100, 600, 280)
local mv_aipeek_retr   = g_move:slider("Retreat (ms)", 100, 1000, 280)
local mv_aipeek_rate   = g_move:slider("Rate Limit (ms)", 0, 3000, 200)
local mv_aipeek_hc     = g_move:slider("Peek Hit Chance (0=keep NL)", 0, 100, 35)
local mv_aipeek_unsafe = g_move:switch("Unsafety (drop Safe Points during peek)", false)
local mv_aipeek_wpn    = g_move:combo("Weapon Filter", {"All", "Snipers only", "Pistols only", "Deagle only"}, 1)
local mv_aipeek_dev    = g_move:switch("Dev Mode (console debug)", false)

-- ══════════════════════════════════════════════════════════════════════════
-- VISUALS UI
-- ══════════════════════════════════════════════════════════════════════════
g_visual:label(accent .. ui.get_icon"eye" .. accent .. "  Visual additions")
local vis_watermark  = g_visual:switch(accent .. ui.get_icon"clock"      .. accent .. "  Watermark (user / FPS / ping)", true)
local vis_indicators = g_visual:switch(accent .. ui.get_icon"bolt"       .. accent .. "  State indicators (AA / DT / HS / FREE)", true)
local vis_velwarn    = g_visual:switch(accent .. ui.get_icon"feather"    .. accent .. "  Velocity warning", true)
local vis_aaarrows   = g_visual:switch(accent .. ui.get_icon"sliders"    .. accent .. "  Manual AA arrows", true)
local vis_hitmarker  = g_visual:switch(accent .. ui.get_icon"crosshairs" .. accent .. "  Hit marker", true)
local vis_hitlog     = g_visual:switch(accent .. ui.get_icon"bullseye"   .. accent .. "  Event log (hits + misses + kills)", true)
local vis_keybinds   = g_visual:switch(accent .. ui.get_icon"user"       .. accent .. "  Keybinds panel", true)
local vis_dmgind     = g_visual:switch(accent .. ui.get_icon"skull"      .. accent .. "  Damage popup (-X HP on enemy)", true)
local vis_specoverlay= g_visual:switch(accent .. ui.get_icon"eye"        .. accent .. "  Spectator overlay", true)
g_visual:label(" ")
g_visual:label(accent .. ui.get_icon"sliders" .. accent .. "  v3.19 extras (read-only / render):")
local vis_desyncpct  = g_visual:switch(accent .. ui.get_icon"bolt"       .. accent .. "  Desync delta % (real vs fake yaw)", true)
local vis_skeet      = g_visual:switch(accent .. ui.get_icon"bolt"       .. accent .. "  Skeet indicator panel (DT/FS/SAFE/BODY/MD/DUCK)", false)
local vis_netgraph   = g_visual:switch(accent .. ui.get_icon"feather"    .. accent .. "  Netgraph (ping / loss / choke + LC warn)", false)
local vis_scopefade  = g_visual:switch(accent .. ui.get_icon"eye"        .. accent .. "  Fade own model when scoped", true)
local vis_sleeves    = g_visual:switch(accent .. ui.get_icon"eye"        .. accent .. "  Remove sleeves (cleaner POV)", false)
local vis_menublur   = g_visual:switch(accent .. ui.get_icon"eye"        .. accent .. "  Blur behind menu", false)
local vis_custscope  = g_visual:switch(accent .. ui.get_icon"crosshairs" .. accent .. "  Custom scope overlay", false)
local vis_scope_rot  = g_visual:switch(accent ..                            "      rotate scope 45 deg", false)
local vis_menuborder = g_visual:switch(accent .. ui.get_icon"sliders"    .. accent .. "  Animated menu border (HSV flow)", true)
-- v3.19: smoothing/animation state for the new render features (single table to dodge
-- any main-chunk local-count pressure). Mutated only from events.render.
local _vis_state = { scope_gap = 0, scope_size = 0, model_alpha = 255, vel_a = 0, desync_shown = 0 }
-- v3.20: premium fonts (loaded once). Fall back to built-in int font 5 if load fails.
local _vis_fonts = {}
pcall(function() _vis_fonts.vel = render.load_font("Verdana", 16, "a") end)
local function _vfont() return _vis_fonts.vel or 5 end
-- v3.24: premium indicator "pill" — rounded dark bg + colored left accent bar + text.
-- Replaces the old plain stacked green text (looked cheap). anchor: "c" center on x
-- (default), "l" left edge at x, "r" right edge at x. Returns width, height.
local function _vis_pill(x, y, text, col, font, anchor)
    font = font or 3
    text = tostring(text)
    local tw = 0
    pcall(function() tw = render.measure_text(font, nil, text).x end)
    if tw <= 0 then tw = #text * 6 end
    local th, padx, barw = 17, 9, 3
    local w  = tw + padx * 2 + barw
    local lx = x
    if anchor == "c" then lx = x - w / 2
    elseif anchor == "r" then lx = x - w end
    pcall(function()
        render.rect(vector(lx, y), vector(lx + w, y + th), color(13, 14, 18, 205), 4)
        render.rect(vector(lx + 1, y + 1), vector(lx + 1 + barw, y + th - 1),
                    color(col.r, col.g, col.b, 255), { 4, 0, 0, 4 })
        render.text(font, vector(lx + barw + padx, y + 2), col, nil, text)
    end)
    return w, th
end
-- v3.26: velocity-style "chip" — a colored status square + a readable label box,
-- the same icon-chip + label-box look as the velocity counter (user-approved).
-- Replaces the cryptic abbreviation pills (nobody read "FL-VAR"). Pulses with col.a.
local function _vis_chip(x, y, name, col)
    local font = 3
    name = tostring(name)
    local tw = 0
    pcall(function() tw = render.measure_text(font, nil, name).x end)
    if tw <= 0 then tw = #name * 6 end
    local h, csz, gap, padx = 18, 18, 4, 8
    local fa = (col.a or 255) / 255
    local bg = color(13, 14, 18, math.floor(210 * fa))
    pcall(function()
        -- status chip (colored square in a dark rounded box)
        render.rect(vector(x, y), vector(x + csz, y + h), bg, 4)
        render.rect(vector(x + 4, y + 4), vector(x + csz - 4, y + h - 4), color(col.r, col.g, col.b, col.a or 255), 2)
        -- label box + readable name
        local lx, lw = x + csz + gap, tw + padx * 2
        render.rect(vector(lx, y), vector(lx + lw, y + h), bg, 4)
        render.text(font, vector(lx + padx, y + 2), color(236, 241, 250, math.floor(255 * fa)), nil, name)
    end)
    return h
end
g_visual:label(" ")
g_visual:label(accent .. "  NL Hit Marker Sound / Force Thirdperson / Scope Overlay:")
g_visual:label(accent .. "  Set those directly in NL Visuals tab (they're combo elements)")
-- V1.7: self-glow toggle dropped — NL glow is a multi-value combo, our :override(true)
-- on a combo silently no-op'd. Users can configure glow directly in NL Visuals tab.

-- ══════════════════════════════════════════════════════════════════════════
-- QOL UI
-- ══════════════════════════════════════════════════════════════════════════
g_qol:label(accent .. ui.get_icon"sparkles" .. accent .. "  Quality of Life")
local qol_clantag    = g_qol:switch("Animated clantag (Sel01 cycle)", false)
local qol_clantag_st = g_qol:combo("Clantag style", {"Wave", "Spin", "Pulse", "Loading", "Scan", "Glitch", "Arrow", "Rage"}, 1)
-- V2.0: dropped killsay + autoaccept + buybot — NL has these built-in (Misc tab).

-- ══════════════════════════════════════════════════════════════════════════
-- INFO UI
-- ══════════════════════════════════════════════════════════════════════════
local btn_status = g_info:button("Print Status", function() end)
local btn_reset  = g_info:button("Reset Settings", function() end)
local btn_stats  = g_info:button("Dump Debug Stats", function() end) -- V2.6
local btn_clear  = g_info:button("Clear Stats", function() end) -- V2.6
local btn_recom  = g_info:button("Print Recommendations", function() end) -- V3.1
local btn_antihs = g_info:button("Toggle Anti-HS Bundle", function() end) -- V3.1
g_info:label(" ")
cfg_vc_label = g_info:label("\aAAAAAAFFv" .. SEL01_CFG_VERSION .. " - checking for updates...")
g_info:label(" ")
g_info:label(accent .. "  Sel01-Solver handles RESOLVING (separate tab)")
g_info:label(accent .. "  This script handles AA / Movement / Visuals / QoL only")

-- ══════════════════════════════════════════════════════════════════════════
-- SAFE-SET HELPER (defensive wrapper around NL UI element :set())
-- ══════════════════════════════════════════════════════════════════════════
local function safe_set(elem, v)
    if not elem then return end
    pcall(function() elem:set(v) end)
end

-- V1.3 hotfix: previous wrapper raised "couldn't find the menu item" on missing paths
-- because the closure-wrapped pcall did not catch NL's popup-side-effect cleanly.
-- pui.find (require'd from neverlose/pui above) is the safer variant used by JAG0YAW
-- and nyanza snapshot. We prefer it. Fallback to ui.find as last resort.
-- pcall(fn, ...) avoids closure-capture issues.
local function nl_find_safe(...)
    if pui and pui.find then
        local ok, ref = pcall(pui.find, ...)
        if ok and ref then return ref end
    end
    local ok, ref = pcall(ui.find, ...)
    if ok and ref then return ref end
    return nil
end

-- V2.0: nl_override restored. v1.13 confirmed crashes were in event handlers, not
-- in :override calls. Body wraps pcall same as v1.0.
local function nl_override(ref, value)
    if not ref then return false end
    local ok = pcall(function() ref:override(value) end)
    return ok
end
local function nl_clear(ref)
    if not ref then return end
    pcall(function() ref:override() end)
end

-- ══════════════════════════════════════════════════════════════════════════
-- NL UI REFERENCES — verified paths from JAG0YAW/bettervisal/bloodwings/nyanza
-- All pcall-wrapped; if a path is gone in a future NL update, write fails silently.
-- ══════════════════════════════════════════════════════════════════════════
local nl_refs = {}
-- Outer pcall: even if pui.find / ui.find pops the NL "couldn't find menu item" dialog
-- for some path that is gone in this NL build, the remaining lookups still run and
-- the rest of the script loads.
pcall(function()
    -- Anti-Aim (Angles)
    nl_refs.aa_enabled       = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Enabled")
    nl_refs.aa_pitch         = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Pitch")
    nl_refs.aa_yaw           = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Yaw")
    nl_refs.aa_yaw_base      = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Yaw", "Base")
    nl_refs.aa_yaw_offset    = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Yaw", "Offset")
    nl_refs.aa_yaw_hidden    = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Yaw", "Hidden")
    nl_refs.aa_avoidbackstab = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Yaw", "Avoid Backstab")
    nl_refs.aa_yawmod        = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Yaw Modifier")
    nl_refs.aa_yawmod_offset = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Yaw Modifier", "Offset")
    -- Body Yaw (desync)
    nl_refs.aa_bodyyaw       = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Body Yaw")
    nl_refs.aa_bodyyaw_inv   = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Inverter")
    nl_refs.aa_bodyyaw_l     = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Left Limit")
    nl_refs.aa_bodyyaw_r     = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Right Limit")
    nl_refs.aa_bodyyaw_opts  = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Options")
    nl_refs.aa_bodyyaw_free  = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Freestanding")
    -- Freestanding (yaw-level)
    nl_refs.aa_freestand     = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Freestanding")
    nl_refs.aa_free_disab_ym = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Freestanding", "Disable Yaw Modifiers")
    nl_refs.aa_free_body     = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Freestanding", "Body Freestanding")
    -- Misc (under Anti Aim)
    nl_refs.aa_leg_movement  = nl_find_safe("Aimbot", "Anti Aim", "Misc", "Leg Movement")
    nl_refs.aa_slowwalk      = nl_find_safe("Aimbot", "Anti Aim", "Misc", "Slow Walk")
    nl_refs.aa_fakeduck      = nl_find_safe("Aimbot", "Anti Aim", "Misc", "Fake Duck")
    -- Fake Lag
    nl_refs.fl_switch        = nl_find_safe("Aimbot", "Anti Aim", "Fake Lag", "Enabled")
    nl_refs.fl_limit         = nl_find_safe("Aimbot", "Anti Aim", "Fake Lag", "Limit")
    nl_refs.fl_variability   = nl_find_safe("Aimbot", "Anti Aim", "Fake Lag", "Variability")
    -- Ragebot
    nl_refs.rage_fov         = nl_find_safe("Aimbot", "Ragebot", "Main", "Field of View")
    nl_refs.rage_hide        = nl_find_safe("Aimbot", "Ragebot", "Main", "Hide Shots")
    nl_refs.rage_dt          = nl_find_safe("Aimbot", "Ragebot", "Main", "Double Tap")
    nl_refs.rage_peek        = nl_find_safe("Aimbot", "Ragebot", "Main", "Peek Assist")
    nl_refs.rage_dormant     = nl_find_safe("Aimbot", "Ragebot", "Main", "Enabled", "Dormant Aimbot")
    -- V2.7: rage_peek_assist ref RE-ADDED but we only :get() it (gingersense
    -- pattern), never :override. Reading a hotkey state is safe; writing crashes.
    nl_refs.rage_peek_assist = nl_find_safe("Aimbot", "Ragebot", "Main", "Peek Assist")
    nl_refs.rage_hc          = nl_find_safe("Aimbot", "Ragebot", "Selection", "Hit Chance")
    -- V3.15: rage_mindmg re-added READ-ONLY for the dump display. The V3.5 removal was
    -- to stop WRITING NL min-damage (never-override rule) — reading via :get() is safe.
    -- Verified path "Min. Damage" (was the wrong key before → dump showed MinDmg=?).
    nl_refs.rage_mindmg      = nl_find_safe("Aimbot", "Ragebot", "Selection", "Min. Damage")
    nl_refs.rage_autowall    = nl_find_safe("Aimbot", "Ragebot", "Selection", "Penetrate Walls")
    nl_refs.rage_bodyaim     = nl_find_safe("Aimbot", "Ragebot", "Safety", "Body Aim")
    nl_refs.rage_safepoint   = nl_find_safe("Aimbot", "Ragebot", "Safety", "Safe Points")
    nl_refs.rage_hitsafety   = nl_find_safe("Aimbot", "Ragebot", "Safety", "Ensure Hitbox Safety")
    nl_refs.rage_autoscope   = nl_find_safe("Aimbot", "Ragebot", "Accuracy", "Auto Scope")
    -- Visuals
    nl_refs.vis_viewmodel    = nl_find_safe("Visuals", "World", "Main", "Override Zoom", "Force Viewmodel")
    nl_refs.vis_removals     = nl_find_safe("Visuals", "World", "Main", "Removals")
    -- v3.19: Scope Overlay ref ONLY for custom-scope. It IS a combo, so the only safe
    -- writes are STRING overrides — :override("Remove All") to hide NL's scope and
    -- :override() to clear. NEVER :override(bool) on it (v2.2 segfault). Read by the
    -- custom-scope render block (nyanza / externalapaha use this exact pattern).
    nl_refs.vis_scope_ovl    = nl_find_safe("Visuals", "World", "Main", "Override Zoom", "Scope Overlay")
    -- V2.2: vis_hitmark_snd / vis_thirdperson / vis_scope_ovl / vis_self_chams / vis_self_glow
    -- refs removed — they are combo elements and :override(bool) on a combo segfaults.
    -- vis_thirdperson + vis_scope_ovl were referenced via separate lookups elsewhere; same fate.
end)  -- outer pcall

-- ══════════════════════════════════════════════════════════════════════════
-- PRESETS
-- ══════════════════════════════════════════════════════════════════════════
-- V1.5: BUTTON CALLBACK MUST NOT MUTATE UI STATE.
-- NL appears to freeze the menu when a button callback synchronously calls :set()
-- on combo / slider elements during the menu render lifecycle (V1.4 user reported
-- the menu hung mid-callback). We defer the work to the next createmove tick
-- which runs OUTSIDE the menu render pipeline.
local pending_preset = nil  -- "aggressive" / "dynamic" / "defensive" / "spin" / "troll" or nil

-- The actual apply runs from createmove (see createmove_unified below).
-- Combo :set() calls are skipped entirely — they were the most likely crash source.
-- The user can still pick combo values manually, and the NL refs :override() handles
-- the actual gameplay AA values which is what matters.
-- V1.10: each step pcall'd so a single bad call can't abort the whole preset,
-- and the step prints to chat so the user sees where a future crash lands.
local function _safe_step(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        cs_log("[STEP-FAIL] " .. label .. " — " .. tostring(err))
    end
end
_troll_mode = false  -- V3.16: global flag for the 🤡 TROLL indicator (set true only by troll)
local function _do_apply_preset(name)
    cs_log("[apply] start " .. tostring(name))
    _troll_mode = false  -- reset on every preset; troll re-sets it true below
    if name == "aggressive" then
        safe_set(aa_enable, true)
        safe_set(aa_freestanding, true)
        safe_set(aa_at_targets, false)
        safe_set(aa_desync, 58)
        safe_set(aa_yaw_add, 0)
        safe_set(aa_yaw_mod_mag, 45)
        safe_set(aa_yaw_mod_int, 2)
        safe_set(aa_onshot, true)
        safe_set(aa_air_set, true)
        safe_set(aa_air_mag, 35)
        safe_set(aa_air_flip, true)
        safe_set(aa_air_boost, true)
        safe_set(aa_air_fakeduck, false)
        -- V3.2 + V3.3: Move-AA + Pitch-jitter enabled. move_fakeduck stays default
        -- OFF (v3.2 had it ON which left NL fake-duck stuck after the user stopped
        -- running — sticky-fakeduck bug). User can opt-in via the toggle.
        safe_set(aa_move_set, true)
        safe_set(aa_move_mag, 45)
        safe_set(aa_move_thresh, 100)
        safe_set(aa_move_flip, true)
        safe_set(aa_move_boost, true)
        safe_set(aa_pitch_jitter, true)
        safe_set(aa_move_fakeduck, false)
        safe_set(aa_move_fd_thresh, 100)
        safe_set(aa_anti_bf, true)
        safe_set(aa_anti_bf_var, 15)
        safe_set(aa_fd_assist, true)
        -- V3.16: enable Magnitude jitter in Aggressive. The debug dumps showed enemies
        -- repeatedly headshotting at a STABLE desync (58/45/35) — that is exactly what an
        -- EMA resolver (incl. Sel01-Solver itself) locks onto. Per-tick magnitude jitter
        -- leaves the real fake-yaw 5-15° off the learned average every shot. Only affects
        -- the OUTGOING anti-aim (how enemies see you) — zero cost to your own hit-rate.
        safe_set(aa_mag_jitter, true)
        safe_set(aa_mag_jit_min, 38)
        safe_set(aa_mag_jit_max, 58)
        safe_set(aa_fl_var, true)        -- fake-lag variance — breaks backtrack resolvers too
        safe_set(vis_watermark, true)
        safe_set(vis_indicators, true)
        safe_set(vis_velwarn, true)
        safe_set(vis_aaarrows, true)
        safe_set(vis_hitmarker, true)
        safe_set(vis_hitlog, true)
        safe_set(vis_keybinds, true)
        safe_set(vis_dmgind, true)
        safe_set(vis_specoverlay, true)
        safe_set(qol_clantag, true)
        -- v3.19/3.20 visuals — ALL ON in Aggressive so the user can test without toggling
        safe_set(vis_desyncpct, true)
        safe_set(vis_skeet, true)
        safe_set(vis_netgraph, true)
        safe_set(vis_scopefade, true)
        safe_set(vis_sleeves, true)
        safe_set(vis_menublur, false)   -- v3.23: menu blur OFF by default (user request)
        safe_set(vis_custscope, true)
        safe_set(vis_scope_rot, true)
        safe_set(vis_menuborder, true)
        _safe_step("nl aa_enabled",     function() nl_override(nl_refs.aa_enabled, true) end)
        _safe_step("nl aa_freestand",   function() nl_override(nl_refs.aa_freestand, true) end)
        _safe_step("nl aa_avoidbk",     function() nl_override(nl_refs.aa_avoidbackstab, true) end)
        _safe_step("nl fl_switch",      function() nl_override(nl_refs.fl_switch, true) end)
        -- V3.16: force NL Yaw Base = Backward. The user noticed the fake facing the enemy
        -- in aggressive — that is Yaw Base "Forward" (fake points toward the look/aim
        -- direction). "Backward" makes the fake point AWAY while the real angle still
        -- snaps to the enemy when the ragebot fires. Combo :override takes the option
        -- STRING (bool segfaults).
        _safe_step("nl yaw_base_back",  function() nl_override(nl_refs.aa_yaw_base, "Backward") end)
        cs_log_color("AGGRESSIVE preset applied")
    elseif name == "dynamic" then
        safe_set(aa_enable, true)
        safe_set(aa_freestanding, true)
        safe_set(aa_at_targets, true)
        safe_set(aa_desync, 45)
        safe_set(aa_yaw_mod_mag, 28)
        safe_set(aa_yaw_mod_int, 3)
        safe_set(aa_onshot, true)
        safe_set(aa_air_set, true)
        safe_set(aa_air_flip, true)
        safe_set(aa_air_boost, false)    -- dynamic = balanced, no max boost
        safe_set(aa_anti_bf, true)
        safe_set(aa_fd_assist, true)
        safe_set(vis_watermark, true)
        safe_set(vis_indicators, true)
        safe_set(vis_velwarn, true)
        safe_set(vis_aaarrows, true)
        safe_set(vis_hitmarker, true)
        safe_set(vis_hitlog, true)
        safe_set(vis_keybinds, true)
        safe_set(vis_dmgind, true)
        safe_set(vis_specoverlay, true)
        safe_set(qol_clantag, true)
        nl_override(nl_refs.aa_enabled, true)
        nl_override(nl_refs.aa_freestand, true)
        nl_override(nl_refs.fl_switch, true)
        cs_log_color("DYNAMIC preset applied")
    elseif name == "defensive" then
        safe_set(aa_enable, true)
        safe_set(aa_freestanding, true)
        safe_set(aa_at_targets, false)
        safe_set(aa_desync, 35)
        safe_set(aa_yaw_mod_mag, 15)
        safe_set(aa_yaw_mod_int, 4)
        safe_set(aa_onshot, true)
        safe_set(aa_air_set, true)
        safe_set(aa_air_flip, false)     -- defensive = no rapid flip
        safe_set(aa_air_boost, false)
        safe_set(aa_anti_bf, false)  -- defensive = predictable static
        safe_set(aa_fd_assist, true)
        safe_set(vis_watermark, true)
        safe_set(vis_indicators, true)
        safe_set(vis_velwarn, true)
        safe_set(vis_aaarrows, true)
        safe_set(vis_hitmarker, true)
        safe_set(vis_hitlog, true)        -- V2.9: always ON for kill/miss/hit log
        safe_set(vis_keybinds, true)
        safe_set(vis_dmgind, false)
        safe_set(vis_specoverlay, true)
        safe_set(qol_clantag, false)
        nl_override(nl_refs.aa_enabled, true)
        nl_override(nl_refs.aa_freestand, true)
        nl_override(nl_refs.fl_switch, true)
        cs_log_color("DEFENSIVE preset applied")
    elseif name == "spin" then
        -- Full spinbot — fast yaw rotation, high-freq jitter, NO freestanding (we WANT spin)
        safe_set(aa_enable, true)
        safe_set(aa_freestanding, false)
        safe_set(aa_at_targets, false)
        safe_set(aa_desync, 58)
        safe_set(aa_yaw_add, 0)
        safe_set(aa_yaw_mod_mag, 58)
        safe_set(aa_yaw_mod_int, 1)  -- every tick flip
        safe_set(aa_onshot, false)   -- spin = always spin, no defensive interrupt
        safe_set(aa_air_set, true)
        safe_set(aa_air_mag, 58)
        safe_set(aa_air_flip, true)      -- spin = full chaos in air
        safe_set(aa_air_boost, true)
        safe_set(aa_air_fakeduck, true)  -- spin allows fake-duck LBY break
        safe_set(aa_anti_bf, true)
        safe_set(aa_anti_bf_var, 25)
        safe_set(aa_fd_assist, true)
        safe_set(vis_watermark, true)
        safe_set(vis_indicators, true)
        safe_set(vis_velwarn, true)
        safe_set(vis_aaarrows, true)
        safe_set(vis_hitmarker, true)
        safe_set(vis_hitlog, true)
        safe_set(vis_keybinds, true)
        safe_set(vis_dmgind, true)
        safe_set(vis_specoverlay, true)
        safe_set(qol_clantag, true)
        nl_override(nl_refs.aa_enabled, true)
        nl_override(nl_refs.aa_freestand, false)
        nl_override(nl_refs.aa_avoidbackstab, false)
        nl_override(nl_refs.fl_switch, true)
        cs_log_color("SPIN preset applied (full spinbot — no freestanding, max jitter)")
    elseif name == "troll" then
        -- V3.16: TROLL / BAIT — NOT competitive. Built for running or slow-walking
        -- straight INTO enemies to see who can actually resolve you (everyone else
        -- whiffs). Stacks EVERY anti-resolver layer at once: per-tick magnitude jitter
        -- (kills EMA resolvers — including the kind Sel01-Solver itself is), fake-lag
        -- variance (breaks backtrack), yaw-base rotation (anti eye-yaw fingerprint),
        -- fast side-streak flipping (never a predictable side), defensive-on-hit +
        -- slow-walk chaos. Freestanding OFF on purpose — it picks a DETERMINISTIC side
        -- (resolvable); pure jitter is less trackable for a bait.
        safe_set(aa_enable, true)
        safe_set(aa_freestanding, false)
        safe_set(aa_at_targets, false)
        safe_set(aa_desync, 58)            -- max angle
        safe_set(aa_yaw_add, 0)
        safe_set(aa_yaw_mod_mag, 58)
        safe_set(aa_yaw_mod_int, 1)        -- flip every tick
        safe_set(aa_onshot, true)
        safe_set(aa_air_set, true)
        safe_set(aa_air_mag, 58)
        safe_set(aa_air_flip, true)
        safe_set(aa_air_boost, true)
        safe_set(aa_air_fakeduck, true)
        safe_set(aa_move_set, true)        -- keep desync while running in
        safe_set(aa_move_mag, 58)
        safe_set(aa_move_thresh, 100)
        safe_set(aa_move_flip, true)
        safe_set(aa_move_boost, true)
        safe_set(aa_pitch_jitter, true)    -- anti-headshot vertical
        -- V3.16-troll-v2: duck-bob while running in. The sticky-fakeduck bug was fixed
        -- in v3.3 (falling-edge clear), so this is safe now. thresh 50 = bob only while
        -- MOVING (running/slow-walking in) and STAND the instant you stop to shoot, so
        -- it stays functional — your ragebot still commits cleanly when stationary.
        safe_set(aa_move_fakeduck, true)
        safe_set(aa_move_fd_thresh, 50)
        safe_set(aa_anti_bf, true)
        safe_set(aa_anti_bf_var, 25)       -- max bruteforce variance
        safe_set(aa_fd_assist, true)
        -- ── the whole anti-resolver bundle ON (this is the point of the preset) ──
        safe_set(aa_mag_jitter, true)      -- THE EMA-resolver killer
        safe_set(aa_mag_jit_min, 20)       -- v2: wider (20-58) so the jitter spans low
        safe_set(aa_mag_jit_max, 58)       --     AND high magnitudes — even harder to lock
        safe_set(aa_fl_var, true)          -- breaks backtrack records
        safe_set(aa_yaw_rotate, true)      -- rotates yaw base, anti eye-yaw fingerprint
        safe_set(aa_side_streak, true)
        safe_set(aa_side_streak_n, 2)      -- flip after 2 same-side shots = never predictable
        safe_set(aa_def_on_dmg, true)
        safe_set(aa_def_duration, 3000)    -- long chaos window when hit
        safe_set(aa_slow_boost, true)      -- max chaos while slow-walking in
        safe_set(vis_watermark, true)
        safe_set(vis_indicators, true)
        safe_set(vis_velwarn, true)
        safe_set(vis_aaarrows, true)
        safe_set(vis_hitmarker, true)
        safe_set(vis_hitlog, true)
        safe_set(vis_keybinds, true)
        safe_set(vis_dmgind, true)
        safe_set(vis_specoverlay, true)
        safe_set(qol_clantag, true)
        safe_set(qol_clantag_st, "Spin")   -- v2: spinning troll clantag
        nl_override(nl_refs.aa_enabled, true)
        nl_override(nl_refs.aa_freestand, false)
        nl_override(nl_refs.aa_avoidbackstab, false)
        nl_override(nl_refs.fl_switch, true)
        -- yaw-rotation is ON in troll → NL Yaw Base cycles on its own; no static set.
        _troll_mode = true   -- v2: drives the 🤡 TROLL indicator in render
        cs_log_color("TROLL/BAIT preset applied — max anti-resolver chaos. Run/slow-walk in + watch who whiffs.")
    end
end

-- Public entry — just queue the work, do not touch UI state from this function.
local function apply_preset(name)
    pending_preset = name
    cs_log("preset '" .. tostring(name) .. "' queued (applies on next tick)")
end
apply_preset_fwd = apply_preset  -- resolve forward-decl

-- ══════════════════════════════════════════════════════════════════════════
-- ANTI-AIM EVENT HOOK
-- NL exposes events.antiaim (signature varies). Best-effort write to cmd
-- (pitch, yaw_base, yaw_add, yaw_modifier, jitter, desync). All pcall.
-- ══════════════════════════════════════════════════════════════════════════
-- V1.8: aa_handler with cmd.* field writes was deleted because no other NL script
-- (JAG0YAW oracle, bloodwings, nyanza, bettervisal, gingersense) uses that pattern.
-- They all drive anti-aim through ui.find:override() on NL's own AA elements. Writing
-- to undefined fields on the events.antiaim cmd userdata likely caused the CTD the
-- user hit a few seconds after team-select. This version routes everything through
-- aa_periodic_sync (called from createmove_unified) which only uses :override on
-- NL refs — same well-tested path the other scripts use.

local aa_yaw_jitter_counter = 0
-- Kept alias for indicator's rotating-line animation (still uses yaw rhythm)
local aa_jitter_counter     = 0
local aa_jitter_dir         = 1
-- V1.6 HvH state — runtime flags shared with indicators + AA decisions
local aa_state = {
    on_shot_until    = 0,
    fakeduck_until   = 0,
    last_fire_time   = 0,
    -- V3.6
    defensive_until  = 0,       -- realtime cutoff for defensive AA mode
    fl_next_change   = 0,       -- next realtime at which to re-randomize fake-lag
    fl_active        = false,   -- dirty-track for clearing override
    fl_base          = nil,     -- captured user fake-lag value before first override
    -- V3.7
    yaw_next_change  = 0,       -- next realtime to re-roll yaw base
    yaw_active       = false,   -- dirty-track yaw-base override
    side_streak_dir  = 0,       -- our last-shot side: +1 right, -1 left, 0 unknown
    side_streak_n    = 0,       -- count of consecutive same-side shots
    side_force_inv   = nil,     -- when set, force aa_bodyyaw_inv to this bool next sync
}

-- V2.3: air-AA improvements for jumping aggressive play. New air-extras (rapid
-- inverter flip, max-jitter boost, force fake-duck). Transition handling clears
-- overrides on land so ground AA returns to user's preset state.
local aa_periodic_last_tick = 0
local _was_airborne   = false
local _move_fd_active = false  -- V3.3 dirty-track for fake-duck override
local _def_inv_active = false  -- V3.6 dirty-track for bodyyaw_inv override (defensive/slow random side)

local function aa_periodic_sync()
    if not (enable_master:get() and aa_enable:get()) then return end
    local lp = entity.get_local_player()
    if not lp then return end
    local alive = false
    pcall(function() alive = lp:is_alive() end)
    if not alive then return end

    local tick = globals.tickcount or 0
    -- jitter rhythm counter (runs every tick, cheap, drives indicator animation)
    aa_yaw_jitter_counter = aa_yaw_jitter_counter + 1
    aa_jitter_counter     = aa_yaw_jitter_counter
    local jint = math.max(1, aa_yaw_mod_int:get())
    if aa_yaw_jitter_counter % jint == 0 then aa_jitter_dir = -aa_jitter_dir end
    if tick - aa_periodic_last_tick < 4 then return end
    aa_periodic_last_tick = tick
    aa_corr_phase = aa_corr_phase + 1  -- V3.11: advance once per EXECUTED sync (post-throttle)

    -- airborne detection (FL_ONGROUND bit 0)
    local f = 0
    pcall(function() f = lp.m_fFlags or 0 end)
    local airborne = (bit.band(f, 1) == 0)

    -- transition handling: just landed -> clear air-extra overrides so ground AA
    -- returns to user's preset / manual values
    if _was_airborne and not airborne then
        nl_clear(nl_refs.aa_bodyyaw_inv)
        nl_clear(nl_refs.aa_yawmod_offset)
        nl_clear(nl_refs.aa_fakeduck)
    end
    _was_airborne = airborne

    -- V3.0: clear pitch override if pitch_jitter is OFF (so user's manual NL pitch
    -- combo value comes back). Cheap: NL handles no-op clears.
    if not aa_pitch_jitter:get() then
        pcall(function() if nl_refs.aa_pitch then nl_refs.aa_pitch:override() end end)
    end

    local now = globals.realtime or 0
    local on_shot_active = aa_onshot:get() and now < aa_state.on_shot_until
    local anti_bf_active = aa_anti_bf:get()
    local air_set_active = aa_air_set:get() and airborne
    -- V3.2: Move override active when running on ground over threshold velocity
    local move_set_active = false
    local _vel_cache = 0
    if aa_move_set:get() and not airborne then
        pcall(function()
            local v = lp.m_vecVelocity
            _vel_cache = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
        end)
        if _vel_cache > (aa_move_thresh:get() or 100) then move_set_active = true end
    end

    -- V3.6: defensive window after we took damage — max desync + random side + fake-duck
    local defensive_active = aa_def_on_dmg:get() and now < (aa_state.defensive_until or 0)
    -- V3.6: slow-walk boost — when NL Slow Walk hotkey held, force max desync + chaos
    local slow_active = false
    if aa_slow_boost:get() and nl_refs.aa_slowwalk then
        local ok, v = pcall(function() return nl_refs.aa_slowwalk:get() end)
        if ok and v then slow_active = true end
    end

    if not (air_set_active or on_shot_active or anti_bf_active or move_set_active
            or defensive_active or slow_active) then return end

    -- V3.2: desync magnitude priority: defensive > air > slow > move > on-shot reduction > base
    local lim = aa_desync:get()
    if move_set_active then lim = aa_move_mag:get() end
    if air_set_active  then lim = aa_air_mag:get() end
    if on_shot_active  then lim = math.max(15, math.floor(lim * 0.5)) end
    -- V3.6: slow + defensive both push to max (base); V3.13 two-cluster overrides below
    if slow_active      then lim = 58 end
    if defensive_active then lim = 58 end

    -- V3.13: ANTI-EMA two-cluster for the chaos states (slow-walk / defensive / air).
    -- These used to sit at a FIXED center (58 for slow/def, the slider for air) and
    -- lean on symmetric anti-BF noise — but an EMA/median resolver averages symmetric
    -- noise straight back to that center and beams you (hits-taken log: every hit at
    -- desync=58, resolved clean). Alternate TWO clusters (~base and ~base-22) every
    -- 0.4-1.1s so the resolver's tracked mean lands in the EMPTY gap and matches
    -- neither. anti-BF still adds per-side spread on top. Skipped if the user
    -- explicitly enabled Magnitude jitter / Bimodal (those take precedence below).
    if (slow_active or defensive_active or air_set_active)
       and not aa_mag_jitter:get() and not aa_bimodal:get() then
        if now >= slow_aa_state.next then
            slow_aa_state.mode = 3 - slow_aa_state.mode
            slow_aa_state.next = now + 0.4 + math.random() * 0.7
        end
        local hi = math.min(58, lim)            -- high cluster = the base magnitude
        local lo = math.max(18, lim - 22)       -- low cluster ~22° below
        lim = (slow_aa_state.mode == 1 and lo or hi) + (math.random() * 4 - 2)
    end

    -- V3.9: per-tick magnitude jitter. When enabled, base magnitude is picked
    -- randomly inside [min,max] every periodic-sync tick. EMA-based resolvers
    -- (incl ours v9.x) lock onto the average; randomized mag keeps the actual
    -- value 5-15° off that average each shot. Off by default — combine with
    -- anti-BF below for full per-side chaos.
    if aa_mag_jitter:get() then
        local mj_lo = aa_mag_jit_min:get()
        local mj_hi = aa_mag_jit_max:get()
        if mj_lo > mj_hi then mj_lo, mj_hi = mj_hi, mj_lo end
        lim = mj_lo + math.random() * (mj_hi - mj_lo)
    elseif aa_bimodal:get() then
        -- V3.10: flip cluster every 2-5s; small ±3° wobble so each cluster isn't a
        -- dead-constant the resolver could lock per-side. Long-run mean sits in the
        -- gap between A and B → resolver EMA/median matches no actual shot.
        local now2 = globals.realtime or 0
        if now2 >= aa_bimodal_state.next_switch then
            aa_bimodal_state.mode = 3 - aa_bimodal_state.mode  -- 1 <-> 2
            aa_bimodal_state.next_switch = now2 + 2.0 + math.random() * 3.0
        end
        local base = (aa_bimodal_state.mode == 1) and aa_bimodal_lo:get() or aa_bimodal_hi:get()
        lim = base + (math.random() * 2 - 1) * 3
    end

    local l_lim, r_lim = lim, lim
    if aa_corr_jitter:get() then
        -- V3.11: correlated pattern REPLACES the independent symmetric draw (stacking
        -- a second random layer would just re-introduce the averaging it defeats).
        local amp = aa_corr_amp:get()
        if aa_corr_antiphase:get() then
            local sn = math.sin(aa_corr_phase * 0.6)
            l_lim = lim + amp * sn
            r_lim = lim - amp * sn
        else
            local span = math.max(1, amp)
            local ramp = (aa_corr_phase * 8) % span   -- same-sign walk; EMA never centers
            l_lim = lim + ramp
            r_lim = lim + ramp
        end
    elseif anti_bf_active or slow_active or defensive_active then
        local var = aa_anti_bf_var:get()
        -- 1.5x variance airborne for more chaos; 2x for slow / defensive
        if air_set_active                       then var = math.min(58, var * 1.5) end
        if slow_active or defensive_active      then var = math.min(58, var * 2.0) end
        l_lim = lim + (math.random() * 2 - 1) * var
        r_lim = lim + (math.random() * 2 - 1) * var
    end
    if l_lim < 0 then l_lim = 0 elseif l_lim > 58 then l_lim = 58 end
    if r_lim < 0 then r_lim = 0 elseif r_lim > 58 then r_lim = 58 end
    nl_override(nl_refs.aa_bodyyaw_l, math.floor(l_lim))
    nl_override(nl_refs.aa_bodyyaw_r, math.floor(r_lim))

    -- V3.6: defensive/slow → random body-yaw inverter every periodic tick. Dirty-tracked
    -- so falling edge clears the override and ground AA returns to user's preset.
    local def_or_slow = defensive_active or slow_active
    if def_or_slow then
        nl_override(nl_refs.aa_bodyyaw_inv, (math.random() < 0.5))
        _def_inv_active = true
    elseif aa_state.side_force_inv ~= nil then
        -- V3.7: streak-limit forced flip — apply once then clear
        nl_override(nl_refs.aa_bodyyaw_inv, aa_state.side_force_inv)
        aa_state.side_force_inv = nil
        _def_inv_active = true   -- mark so next non-forced tick clears
    elseif _def_inv_active then
        pcall(function() if nl_refs.aa_bodyyaw_inv then nl_refs.aa_bodyyaw_inv:override() end end)
        _def_inv_active = false
    end

    -- V3.14: SMART FREESTAND — during the chaos states (defensive / slow) deterministic
    -- freestanding re-locks a predictable side (the one getting your head shot) and
    -- fights the random inverter above. Disable it there so the random inverter rules;
    -- restore the user's freestand setting on the falling edge (override revert).
    if aa_smart_free:get() and aa_freestanding:get() and def_or_slow then
        nl_override(nl_refs.aa_freestand, false)
        _smart_free_off = true
    elseif _smart_free_off then
        nl_clear(nl_refs.aa_freestand)
        _smart_free_off = false
    end

    -- V2.3 AIR EXTRAS — only when airborne
    if air_set_active then
        if aa_air_flip:get() then
            nl_override(nl_refs.aa_bodyyaw_inv, (aa_yaw_jitter_counter % 2 == 0))
        end
        if aa_air_boost:get() then
            nl_override(nl_refs.aa_yawmod_offset, 58)
        end
        if aa_air_fakeduck:get() then
            nl_override(nl_refs.aa_fakeduck, true)
        end
    end

    -- V3.2 MOVE EXTRAS — only when running on ground above threshold
    if move_set_active then
        if aa_move_flip:get() then
            nl_override(nl_refs.aa_bodyyaw_inv, (aa_yaw_jitter_counter % 2 == 0))
        end
        if aa_move_boost:get() then
            nl_override(nl_refs.aa_yawmod_offset, 58)
        end
    end

    -- V3.0 ANTI-HEADSHOT EXTRAS — head Y-axis randomization vs enemy resolver
    if aa_pitch_jitter:get() then
        nl_override(nl_refs.aa_pitch, "Jitter Down/Up")
    end
    -- V3.0/V3.3: auto fake-duck while moving on ground. Dirty-track via
    -- _move_fd_active so we ONLY override on rising edge and CLEAR on falling
    -- edge. Without the clear, NL kept the fake-duck override true forever
    -- after the user stopped moving (v3.2 sticky-fakeduck bug).
    local want_move_fd = false
    if aa_move_fakeduck:get() and not airborne then
        local vel = _vel_cache  -- already computed above for move_set_active
        if vel == 0 then
            pcall(function()
                local v = lp.m_vecVelocity
                vel = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
            end)
        end
        if vel > (aa_move_fd_thresh:get() or 100) then want_move_fd = true end
    end
    -- Combine with air-fakeduck. V3.7: defensive no longer force-fake-ducks (was
    -- crouching during movement, hindering escape). Defensive now = max desync +
    -- random side flip only; user keeps full mobility.
    local want_fd = want_move_fd
        or (air_set_active and aa_air_fakeduck:get())
    if want_fd and not _move_fd_active then
        nl_override(nl_refs.aa_fakeduck, true)
        _move_fd_active = true
    elseif (not want_fd) and _move_fd_active then
        pcall(function() if nl_refs.aa_fakeduck then nl_refs.aa_fakeduck:override() end end)
        _move_fd_active = false
    end
end

-- V1.8: events.antiaim hook DELETED (writing to cmd userdata fields caused CTD).
-- AA now flows entirely through aa_periodic_sync -> nl_override on NL UI refs.
local _hooks_status = {}
local function register_first(handler, ...)
    for _, name in ipairs({...}) do
        local ok = pcall(function() events[name]:set(handler) end)
        if ok then return name end
    end
    return nil
end

-- ══════════════════════════════════════════════════════════════════════════
-- MOVEMENT — V2.8: Peek Boost via our own HOLD hotkey. Dirty-tracked NL
-- hitchance :override on rising + falling edge. V3.5: mindmg removed.
-- ══════════════════════════════════════════════════════════════════════════
local _peek_boost_active = false

local function createmove_handler(cmd)
    if not (enable_master:get() and cmd) then return end
    pcall(function()
        local lp = entity.get_local_player()
        if not lp then return end
        local alive = false
        pcall(function() alive = lp:is_alive() end)
        if not alive then
            if _peek_boost_active then
                pcall(function() if nl_refs.rage_hc then nl_refs.rage_hc:override() end end)
                _peek_boost_active = false
            end
            return
        end

        local held = mv_peek_boost_k and mv_peek_boost_k:get()

        if held and not _peek_boost_active then
            nl_override(nl_refs.rage_hc, mv_peek_hc:get())
            _peek_boost_active = true
        elseif (not held) and _peek_boost_active then
            pcall(function() if nl_refs.rage_hc then nl_refs.rage_hc:override() end end)
            _peek_boost_active = false
        end
    end)
end

-- V3.7: yaw base rotation. Periodic NL Yaw Base override cycling
-- Forward/Backward/Left/Right every 4–8s random. Breaks resolvers that
-- learned our eye_yaw → fake_yaw mapping. :override on a combo with a
-- matching option STRING is the safe pattern (combo :override(bool) segfaults).
local YAW_BASE_OPTS = { "Forward", "Backward", "Left", "Right" }
local function yaw_rotation_tick()
    if not (enable_master:get() and aa_enable:get()
            and aa_yaw_rotate and aa_yaw_rotate:get()) then
        if aa_state.yaw_active then
            pcall(function() if nl_refs.aa_yaw_base then nl_refs.aa_yaw_base:override() end end)
            aa_state.yaw_active = false
        end
        return
    end
    if not nl_refs.aa_yaw_base then return end
    local now = globals.realtime or 0
    if now < (aa_state.yaw_next_change or 0) then return end
    aa_state.yaw_next_change = now + 4.0 + math.random() * 4.0   -- 4–8s
    local pick = YAW_BASE_OPTS[math.random(1, #YAW_BASE_OPTS)]
    nl_override(nl_refs.aa_yaw_base, pick)
    aa_state.yaw_active = true
end

-- V3.6: fake-lag variance. Re-randomize NL Fake Lag Limit every 1–3s within
-- ±2 ticks of user's set value. Read user's current value once on activation
-- (via :get()), then alternate around it. Dirty-tracked so toggle-off clears.
local function fake_lag_variance_tick()
    if not (enable_master:get() and aa_fl_var and aa_fl_var:get()) then
        if aa_state.fl_active then
            pcall(function() if nl_refs.fl_limit then nl_refs.fl_limit:override() end end)
            aa_state.fl_active = false
            aa_state.fl_base   = nil       -- forget so next on-cycle re-captures
        end
        return
    end
    if not nl_refs.fl_limit then return end
    local now = globals.realtime or 0
    if now < (aa_state.fl_next_change or 0) then return end
    aa_state.fl_next_change = now + 1.0 + math.random() * 2.0   -- 1–3s
    -- Capture user's base value ONCE before we start overriding. Reading
    -- :get() while we have an active :override would drift.
    if not aa_state.fl_base then
        local v0 = 5
        pcall(function() v0 = nl_refs.fl_limit:get() or 5 end)
        aa_state.fl_base = v0
    end
    local delta = math.random(-2, 2)
    local v = math.max(1, math.min(16, (aa_state.fl_base or 5) + delta))
    nl_override(nl_refs.fl_limit, v)
    aa_state.fl_active = true
end

-- ══════════════════════════════════════════════════════════════════════════
-- AI PEEK (V3.28) — auto peek → shoot → retreat state machine. Original code.
-- ══════════════════════════════════════════════════════════════════════════
local ai_peek = {
    phase     = "idle",   -- idle | peek | retreat
    until_t   = 0,
    last_peek = 0,
    anchor_x  = 0, anchor_y = 0,
    tx = 0, ty = 0,
    hc_active = false,
    sp_active = false,
    dev_t     = 0,
    -- V3.29 "hittable" gate: set by the events.aim_fire handler. The NL ragebot
    -- only fires aim_fire when it has a target whose ESTIMATED damage clears the
    -- ragebot's Hit Chance + we additionally compare event.damage against the
    -- user's NL Min. Damage. While that signal is fresh the enemy is provably
    -- hittable-for-min-dmg → only then do we peek. No fresh signal → bot holds.
    shootable_until = 0,
    aim_x = 0, aim_y = 0,  -- world aim point from event.aim (safe vector, no entity read)
}
local AI_PEEK_SHOOTABLE_FRESH = 0.35   -- seconds an aim_fire keeps the peek "armed"

local function ai_peek_origin(ent)
    local o = nil
    pcall(function() o = ent.m_vecOrigin end)
    return o
end

-- weapon filter: combo :get() returns the option STRING (NL convention)
local function ai_peek_weapon_ok()
    local sel = "All"
    pcall(function() sel = mv_aipeek_wpn:get() end)
    if sel == "All" then return true end
    local name = ""
    pcall(function()
        local lp = entity.get_local_player()
        local w  = lp and lp:get_weapon()
        if w then name = tostring(w:get_name() or ""):lower() end
    end)
    if name == "" then return true end   -- unknown weapon → don't block the peek
    if sel == "Snipers only" then
        return (name:find("ssg") or name:find("awp") or name:find("scar") or name:find("g3sg")) and true or false
    elseif sel == "Pistols only" then
        return (name:find("glock") or name:find("hkp2000") or name:find("usp") or name:find("p250")
            or name:find("fiveseven") or name:find("tec9") or name:find("cz75") or name:find("elite")
            or name:find("deagle") or name:find("revolver")) and true or false
    elseif sel == "Deagle only" then
        return (name:find("deagle") or name:find("revolver")) and true or false
    end
    return true
end

-- nearest alive non-dormant enemy (WalkBot get_enemies pattern). Returns x,y,z,dist
local function ai_peek_nearest(lp, lo)
    local best, bx, by, bz, bd = nil, 0, 0, 0, math.huge
    local players = nil
    pcall(function() players = entity.get_players(true) end)
    if not players then return nil end
    for _, e in ipairs(players) do
        local alive = false
        pcall(function() alive = e:is_alive() end)
        local dorm = false
        pcall(function() dorm = e:is_dormant() end)
        if alive and not dorm and e ~= lp then
            local o = ai_peek_origin(e)
            if o then
                local dx, dy, dz = o.x - lo.x, o.y - lo.y, o.z - lo.z
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                if d < bd then bd = d; best = e; bx = o.x; by = o.y; bz = o.z end
            end
        end
    end
    if best then return bx, by, bz, bd end
    return nil
end

-- raise ragebot HC + optionally drop Safe Points for the peek window only.
-- BREAKS the never-override rule on purpose (user-requested). Restored on (false).
local function ai_peek_set_overrides(on)
    if on then
        local hc = 0
        pcall(function() hc = mv_aipeek_hc:get() end)
        if hc and hc > 0 and nl_refs.rage_hc then
            nl_override(nl_refs.rage_hc, hc)
            ai_peek.hc_active = true
        end
        local unsafe = false
        pcall(function() unsafe = mv_aipeek_unsafe:get() end)
        if unsafe and nl_refs.rage_safepoint then
            -- Safe Points is a COMBO on this build — string :override only (bool
            -- segfaults). "Off" is best-effort; pcall'd so a bad label no-ops.
            pcall(function() nl_refs.rage_safepoint:override("Off") end)
            ai_peek.sp_active = true
        end
    else
        if ai_peek.hc_active then
            pcall(function() if nl_refs.rage_hc then nl_refs.rage_hc:override() end end)
            ai_peek.hc_active = false
        end
        if ai_peek.sp_active then
            pcall(function() if nl_refs.rage_safepoint then nl_refs.rage_safepoint:override() end end)
            ai_peek.sp_active = false
        end
    end
end

local function ai_peek_dev(msg)
    if not (mv_aipeek_dev and mv_aipeek_dev:get()) then return end
    local now = globals.realtime or 0
    if now - (ai_peek.dev_t or 0) < 0.5 then return end
    ai_peek.dev_t = now
    cs_log("[AI-Peek] " .. tostring(msg))
end

local function ai_peek_tick(cmd)
    -- master/feature/cmd gate → restore any live overrides + reset
    if not (cmd and enable_master:get() and mv_aipeek and mv_aipeek:get()) then
        if ai_peek.phase ~= "idle" or ai_peek.hc_active or ai_peek.sp_active then
            ai_peek_set_overrides(false)
            ai_peek.phase = "idle"
        end
        return
    end
    local lp = entity.get_local_player()
    if not lp then return end
    local alive = false
    pcall(function() alive = lp:is_alive() end)
    if not alive then
        if ai_peek.phase ~= "idle" or ai_peek.hc_active or ai_peek.sp_active then
            ai_peek_set_overrides(false); ai_peek.phase = "idle"
        end
        return
    end

    local lo = ai_peek_origin(lp)
    if not lo then return end
    local now = globals.realtime or 0

    -- trigger gate (hold-hotkey vs always-on)
    local triggered = true
    local mode = "Hold Hotkey"
    pcall(function() mode = mv_aipeek_mode:get() end)
    if mode == "Hold Hotkey" then
        triggered = (mv_aipeek_key and mv_aipeek_key:get()) and true or false
    end

    if ai_peek.phase == "idle" then
        if not triggered then return end
        if now - (ai_peek.last_peek or 0) < ((mv_aipeek_rate:get() or 0) / 1000) then return end
        if not ai_peek_weapon_ok() then ai_peek_dev("weapon filtered"); return end
        -- V3.29 HITTABLE GATE: only peek while a fresh aim_fire (damage >= NL min
        -- dmg) has armed us. No shootable enemy → no aim_fire → bot stays put
        -- instead of walking constantly.
        if now >= (ai_peek.shootable_until or 0) then ai_peek_dev("not hittable (no min-dmg shot)"); return end
        -- direction: prefer the armed aim point; fall back to nearest enemy.
        local tx, ty = ai_peek.aim_x, ai_peek.aim_y
        local td
        local nx, ny, nz, nd = ai_peek_nearest(lp, lo)
        if nx then td = nd; if not (tx ~= 0 or ty ~= 0) then tx, ty = nx, ny end end
        if (tx == 0 and ty == 0) and not nx then ai_peek_dev("no target"); return end
        if td and td > (mv_aipeek_range:get() or 2500) then
            ai_peek_dev("too far " .. math.floor(td)); return
        end
        ai_peek.anchor_x, ai_peek.anchor_y = lo.x, lo.y
        ai_peek.tx, ai_peek.ty = tx, ty
        ai_peek.phase   = "peek"
        ai_peek.until_t = now + ((mv_aipeek_hold:get() or 280) / 1000)
        ai_peek_set_overrides(true)
        ai_peek_dev("PEEK armed dist=" .. (td and math.floor(td) or "?"))
        return
    end

    if ai_peek.phase == "peek" then
        -- strafe toward target to gain the sightline (world-space move_yaw,
        -- independent of view → ragebot keeps aiming freely)
        local ang = math.deg(math.atan2(ai_peek.ty - lo.y, ai_peek.tx - lo.x))
        pcall(function() cmd.move_yaw = ang; cmd.forwardmove = 450 end)
        if now >= ai_peek.until_t then
            ai_peek.phase   = "retreat"
            ai_peek.until_t = now + ((mv_aipeek_retr:get() or 280) / 1000)
            ai_peek_set_overrides(false)   -- restore NL config the moment we pull back
            ai_peek_dev("RETREAT")
        end
        return
    end

    if ai_peek.phase == "retreat" then
        local ang = math.deg(math.atan2(ai_peek.anchor_y - lo.y, ai_peek.anchor_x - lo.x))
        pcall(function() cmd.move_yaw = ang; cmd.forwardmove = 450 end)
        if now >= ai_peek.until_t then
            ai_peek.phase     = "idle"
            ai_peek.last_peek = now
            ai_peek_dev("idle")
        end
        return
    end
end

-- Single createmove handler that runs movement + NL-visual override sync.
-- V1.5: also drains pending_preset so preset writes happen OUTSIDE menu callback.
-- V2.0: dirty-track restored (only write NL :override on toggle change)
local function createmove_unified(cmd)
    -- Drain queued preset apply (set by Aggressive/Dynamic/Defensive/Legit buttons)
    if pending_preset then
        local name = pending_preset
        pending_preset = nil
        pcall(_do_apply_preset, name)
    end

    createmove_handler(cmd)
    -- V3.28: AI Peek state machine (cheap, internally gated; default OFF)
    pcall(ai_peek_tick, cmd)
    -- V2.0: AA periodic sync restored (still throttled + alive-checked + lazy).
    aa_periodic_sync()
    -- V3.6: fake-lag variance loop (cheap, internally throttled)
    fake_lag_variance_tick()
    -- V3.7: yaw-base rotation (cheap, internally throttled)
    yaw_rotation_tick()
    -- V2.2: visual NL :overrides REMOVED. Scope Overlay is a combo element
    -- (confirmed via JAG0YAW :set("Remove All")). Hit Marker Sound + Force
    -- Thirdperson are also likely combos. :override(bool) on a combo userdata
    -- segfaults. User can configure these directly in NL's Visuals tab.
end
-- V1.7: pick the first available createmove name (createmove preferred)
_hooks_status.createmove = register_first(createmove_unified, "createmove", "setup_command")

-- ══════════════════════════════════════════════════════════════════════════
-- VISUALS — hit-marker + damage indicator + perf HUD + spectator overlay
-- ══════════════════════════════════════════════════════════════════════════
-- V1.7: dropped hit_events (never used) + hitmark_dmg (set but never read)
local damage_pops = {}   -- floating "−X HP" entries
local hitmark_time = 0
-- V3.10 FORWARD-DECL FIX: the hit-log ring MUST be declared before the aim_ack /
-- player_death closures (created ~914/984) that table.insert into it. Lua binds
-- upvalues at parse-time, so the previous `local hit_log` lower in the file left
-- those writers bound to a nil GLOBAL — table.insert(nil,..) threw inside their
-- pcall and was swallowed, so the top-left event log AND the v3.7 side-streak
-- anti-resolver tracker (same pcall) silently never ran. (moved up from ~1124)
local hit_log = {}
local HIT_LOG_MAX = 8   -- V2.9: bigger since hits + misses + kills all share log

-- Forward-decl: update_clantag is defined further down but referenced inside the
-- events.render closure created below. NL UI callbacks capture upvalues at parse-
-- time — without this forward-decl the closure would bind to a global of the same
-- name (nil at call-time).
local update_clantag = function() end

-- V1.13 BISECT: aim_fire / ragebot_fire / weapon_fire / aim_ack / player_hurt
-- registrations DISABLED. on_local_fire kept as a stub for any future re-enable.
local function on_local_fire(event) end

-- V3.29: aim_fire RE-ENABLED for the AI Peek "hittable" gate ONLY. aim_ack +
-- player_hurt came back safely after the v1.13 bisect; this handler is stricter
-- still — it reads ONLY numeric fields (event.damage / event.hitchance) and the
-- event.aim VECTOR. It NEVER touches event.target's entity properties (the
-- transition-state crash source). NL fires aim_fire when the ragebot commits a
-- shot; we mark the enemy "hittable" only when the estimated damage clears the
-- user's NL Min. Damage, arming the peek for AI_PEEK_SHOOTABLE_FRESH seconds.
pcall(function()
    if events.aim_fire then
        events.aim_fire:set(function(event)
            pcall(function()
                if not event then return end
                if not (mv_aipeek and mv_aipeek:get()) then return end
                local dmg = tonumber(event.damage) or 0
                local mindmg = 1
                pcall(function() mindmg = tonumber(nl_refs.rage_mindmg and nl_refs.rage_mindmg:get()) or 1 end)
                if dmg < mindmg then return end          -- NOT hittable for the configured min dmg
                local now = globals.realtime or 0
                ai_peek.shootable_until = now + AI_PEEK_SHOOTABLE_FRESH
                local a = event.aim
                if a then
                    pcall(function() ai_peek.aim_x, ai_peek.aim_y = a.x, a.y end)
                end
            end)
        end)
        _hooks_status.aim_fire = "aim_fire"
    end
end)

-- V1.13 BISECT: weapon_fire handler DISABLED (no registration). If config is
-- stable with this off, FD-assist or weapon_fire-related code is the crash.

-- V2.8: hits-taken log — when WE get shot, snapshot AA state + context so we can
-- analyze "why did this hit me". Ring buffer of last 10 incidents.
local hits_taken_log = {}
local HITS_TAKEN_MAX = 10

-- V3.0: two distinct mappings.
--   HB_INDEX = aim_ack's event.hitbox (bone-index, 0 = head, 3 = chest, etc.)
--   HB_GROUP = player_hurt's event.hitgroup (CSGO hitgroup, 1 = head, 2 = chest, etc.)
-- _hb_name auto-detects: string passes through, 0 = head (index), 1 = head (group).
local HB_INDEX_NAMES = { [0]="head", [3]="chest", [4]="stomach", [6]="leg", [7]="leg" }
local HB_GROUP_NAMES = { [1]="head", [2]="chest", [3]="stomach",
                         [4]="arm",  [5]="arm",
                         [6]="leg",  [7]="leg" }

local function _hb_name(hb)
    -- player_hurt sends integer hitgroup (1-7). aim_ack rarely fills hitbox.
    -- If unknown integer, fall back to string repr.
    if type(hb) == "string" then return hb end
    return HB_GROUP_NAMES[hb] or HB_INDEX_NAMES[hb] or tostring(hb or "?")
end

-- V2.8: capture our AA state at the moment we get hit
local function _snapshot_aa_state()
    local lp = entity.get_local_player()
    local airborne = false
    local velocity = 0
    if lp then
        pcall(function()
            local f = lp.m_fFlags or 0
            airborne = bit.band(f, 1) == 0
            local v = lp.m_vecVelocity
            velocity = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
        end)
    end
    return {
        aa_enable     = aa_enable:get(),
        desync        = aa_desync:get(),
        air_set       = aa_air_set:get(),
        air_mag       = aa_air_mag:get(),
        anti_bf       = aa_anti_bf:get(),
        on_shot       = aa_onshot:get() and (globals.realtime or 0) < (aa_state.on_shot_until or 0),
        fd_assist     = aa_fd_assist:get(),
        freestanding  = aa_freestanding:get(),
        airborne      = airborne,
        velocity      = math.floor(velocity),
        peek_boost    = _peek_boost_active,
        jitter_dir    = aa_jitter_dir,
        body_yaw_l    = aa_periodic_last_lim_l or nil,  -- if we track this
        body_yaw_r    = aa_periodic_last_lim_r or nil,
    }
end

-- V2.6: debug stats accumulator. Same idea as resolver's session_stats — track
-- shot counts + hit/miss + hitbox breakdown + total damage so the user can dump
-- a session summary and tune presets accordingly.
local stats = {
    session_start  = globals.realtime or 0,
    shots_fired    = 0,    -- aim_ack fired regardless of outcome
    shots_hit      = 0,
    shots_missed   = 0,
    hits_head      = 0,
    hits_chest     = 0,
    hits_stomach   = 0,
    hits_leg       = 0,
    hits_other     = 0,
    total_dmg      = 0,
    biggest_hit    = 0,
    one_taps       = 0,    -- >= 100 dmg single hit
    hits_taken     = 0,    -- V2.8: we got shot
    dmg_taken      = 0,
    kills          = 0,    -- V3.15: monotonic kill counter (was recounted from the
                           -- 8-entry hit_log ring → always 0 after the ring rotated)
}

local function _stats_clear()
    stats.session_start  = globals.realtime or 0
    stats.shots_fired    = 0
    stats.shots_hit      = 0
    stats.shots_missed   = 0
    stats.hits_head      = 0
    stats.hits_chest     = 0
    stats.hits_stomach   = 0
    stats.hits_leg       = 0
    stats.hits_other     = 0
    stats.total_dmg      = 0
    stats.biggest_hit    = 0
    stats.one_taps       = 0
    stats.hits_taken     = 0
    stats.dmg_taken      = 0
    stats.kills          = 0
    hits_taken_log       = {}  -- clear hits-taken log too
end

-- V2.9: aim_ack hit-detection FIXED. Resolver pattern: nil reason = HIT (was MISS
-- in v2.6-v2.8 -> caused config to show 0 hits while resolver showed 11). Also
-- unified hit_log to include HITS + MISSES (kills added via player_death below).
local HIT_STATES_C  = { hit = true, damaged = true, ["hit-damaged"] = true }
local MISS_STATES_C = { miss = true, missed = true, spread = true, correction = true,
                        ["prediction error"] = true, death = true,
                        ["damage rejection"] = true, ["unregistered shot"] = true,
                        ["backtrack failure"] = true, backtrack_failure = true }
local HB_NAMES_C    = { [0]="head", [3]="chest", [4]="stomach", [6]="leg", [7]="leg" }
pcall(function()
    events.aim_ack:set(function(event)
        pcall(function()
            if not enable_master:get() then return end
            if not event then return end
            local reason = event.state
            -- V2.9: nil reason defaults to HIT (resolver pattern). Previously
            -- treated nil as MISS which made every nil-state shot count as miss.
            local is_hit = (reason == nil) or HIT_STATES_C[reason]
            stats.shots_fired = stats.shots_fired + 1
            local target_name = tostring(event.target_name or event.name or "?")
            local hb_name     = HB_NAMES_C[event.hitbox] or tostring(event.hitbox or "?")
            if is_hit then
                stats.shots_hit = stats.shots_hit + 1
                -- V3.0: hitbox bucketing moved to player_hurt (event.hitgroup is
                -- reliable; event.hitbox in aim_ack returns nil in this NL build).
                if vis_hitmarker:get() then hitmark_time = globals.realtime or 0 end
                if vis_hitlog:get() then
                    table.insert(hit_log, {
                        time      = globals.realtime or 0,
                        kind      = "hit",
                        name      = target_name,
                        dmg       = event.damage or 0,
                        dmg_want  = event.wanted_damage or event.requested_damage or event.damage or 0,
                        hitbox    = hb_name,
                        hitbox_id = event.hitbox or -1,
                    })
                    while #hit_log > HIT_LOG_MAX do table.remove(hit_log, 1) end
                end
            else
                stats.shots_missed = stats.shots_missed + 1
                if vis_hitlog:get() then
                    table.insert(hit_log, {
                        time      = globals.realtime or 0,
                        kind      = "miss",
                        name      = target_name,
                        hitbox    = hb_name,
                        hitbox_id = event.hitbox or -1,
                        reason    = tostring(reason or "?"),
                    })
                    while #hit_log > HIT_LOG_MAX do table.remove(hit_log, 1) end
                end
            end
            -- V3.7: side-streak tracker. After every shot, read NL body-yaw inverter
            -- state and count consecutive same-side. When the streak crosses the
            -- user-set threshold, queue a forced inverter flip for the next periodic
            -- sync. Breaks resolvers that track streak{L=N R=0} → predict L pattern.
            if aa_side_streak and aa_side_streak:get() and nl_refs.aa_bodyyaw_inv then
                local cur
                pcall(function() cur = nl_refs.aa_bodyyaw_inv:get() end)
                if cur ~= nil then
                    local dir = cur and 1 or -1
                    if dir == aa_state.side_streak_dir then
                        aa_state.side_streak_n = aa_state.side_streak_n + 1
                    else
                        aa_state.side_streak_n = 1
                        aa_state.side_streak_dir = dir
                    end
                    if aa_state.side_streak_n >= (aa_side_streak_n:get() or 3) then
                        aa_state.side_force_inv  = not cur
                        aa_state.side_streak_n   = 0
                        aa_state.side_streak_dir = 0
                    end
                end
            end
        end)
    end)
end)

-- V2.9: kill detection via player_death (no entity reads on victim except name)
pcall(function()
    events.player_death:set(function(event)
        pcall(function()
            if not enable_master:get() then return end
            if not event then return end
            local lp = entity.get_local_player()
            if not lp then return end
            local attacker = entity.get(event.attacker, true)
            if attacker ~= lp then return end
            local victim = entity.get(event.userid, true)
            if not victim or victim == lp then return end
            local victim_name = "?"
            pcall(function() victim_name = victim:get_name() end)
            -- V3.15: count the kill in a MONOTONIC stat (independent of the event-log
            -- toggle + the 8-entry ring). The dump used to recount from hit_log, which
            -- rotates → showed kills=0 despite 21 one-taps + a 297 headshot.
            stats.kills = (stats.kills or 0) + 1
            if vis_hitlog:get() then
                table.insert(hit_log, {
                    time = globals.realtime or 0,
                    kind = "kill",
                    name = victim_name,
                })
                while #hit_log > HIT_LOG_MAX do table.remove(hit_log, 1) end
            end
        end)
    end)
end)

-- V2.1: player_hurt switched to JAG0YAW pattern (entity object compare instead
-- of lp:get_user_id()). JAG0YAW's hitmarker.on_player_hurt does:
--   if entity.get(event.attacker, true) == entity.get_local_player() then ...
-- No method call on lp object, no get_user_id call that may not exist in user's
-- NL build. Pure object identity comparison.
pcall(function()
    events.player_hurt:set(function(event)
        pcall(function()
            if not enable_master:get() then return end
            if not event then return end
            local lp = entity.get_local_player()
            if not lp then return end
            local attacker = entity.get(event.attacker, true)
            local victim   = entity.get(event.userid,   true)

            -- V2.8: WE got hit (victim == lp, attacker is someone else)
            if victim == lp and attacker and attacker ~= lp then
                stats.hits_taken = (stats.hits_taken or 0) + 1
                local dmg_in = event.dmg_health or event.damage or 0
                stats.dmg_taken = (stats.dmg_taken or 0) + dmg_in
                local atk_name = "?"
                pcall(function() if attacker.get_name then atk_name = attacker:get_name() end end)
                local hb_in = event.hitgroup or -1
                table.insert(hits_taken_log, {
                    time     = globals.realtime or 0,
                    atk_name = atk_name,
                    dmg      = dmg_in,
                    hp_left  = event.health or 0,
                    hitbox   = _hb_name(hb_in),
                    hb_id    = hb_in,
                    snapshot = _snapshot_aa_state(),
                })
                while #hits_taken_log > HITS_TAKEN_MAX do table.remove(hits_taken_log, 1) end
                -- V3.6 + V3.7: trigger defensive AA window — ONLY on bullet hits
                -- (hitgroup 1-7). Skip hitgroup 0 = nade / world / fall damage; user
                -- reported defensive fake-duck mid-movement during nade hits = annoying.
                if aa_def_on_dmg and aa_def_on_dmg:get() and hb_in >= 1 and hb_in <= 7 then
                    aa_state.defensive_until = (globals.realtime or 0) + (aa_def_duration:get() / 1000.0)
                end
                return  -- don't run damage-given accumulator for received hits
            end

            -- WE dealt damage (attacker == lp, victim is enemy)
            if attacker ~= lp then return end
            if not victim or victim == lp then return end
            local hb  = -1
            local dmg = 0
            pcall(function() hb  = event.hitgroup or -1 end)
            pcall(function() dmg = event.dmg_health or event.damage or 0 end)
            stats.total_dmg = stats.total_dmg + dmg
            if dmg > stats.biggest_hit then stats.biggest_hit = dmg end
            if dmg >= 100 then stats.one_taps = stats.one_taps + 1 end
            -- V3.0: hitbox bucketing using HITGROUP (1=head, 2=chest, etc) — reliable
            if     hb == 1 then stats.hits_head    = stats.hits_head    + 1
            elseif hb == 2 then stats.hits_chest   = stats.hits_chest   + 1
            elseif hb == 3 then stats.hits_stomach = stats.hits_stomach + 1
            elseif hb == 6 or hb == 7 then stats.hits_leg = stats.hits_leg + 1
            else stats.hits_other = stats.hits_other + 1
            end
            if not vis_dmgind:get() then return end
            table.insert(damage_pops, {
                time      = globals.realtime or 0,
                dmg       = dmg,
                hp_left   = event.health or 0,
                hitbox_id = hb,
            })
            while #damage_pops > 16 do table.remove(damage_pops, 1) end
        end)
    end)
end)

-- Performance HUD state
local perf = { fps = 0, ping = 0, choke = 0, var = 0, last_update = 0 }
local function update_perf()
    local now = globals.realtime or 0
    if now - perf.last_update < 0.25 then return end
    perf.last_update = now
    pcall(function() perf.fps = math.floor(1 / (globals.absoluteframetime or 0.016)) end)
    pcall(function() perf.ping = math.floor((client.latency and client.latency() or 0) * 1000) end)
    -- choke approx via ticks-since-last-cmd vs ideal
    -- Skipped: no clean NL exposure
end

-- Spectator overlay — who is watching us
local specs = {}
local specs_last_update = 0
local function update_specs()
    local now = globals.realtime or 0
    if now - specs_last_update < 0.5 then return end
    specs_last_update = now
    local lp = entity.get_local_player()
    if not lp then specs = {}; return end
    specs = {}
    -- V1.7 perf: cap loop at globals.maxplayers when exposed (typical 10-12 for MM),
    -- read all NL handles inside a single pcall to avoid 64 nested pcall calls
    local maxp = 64
    pcall(function() maxp = math.min(maxp, globals.maxplayers or 64) end)
    pcall(function()
        for i = 1, maxp do
            local p = entity.get(i, false)
            -- Spectators are dead and not lp; skip early to avoid prop reads on alive players
            if p and p ~= lp and not p:is_alive() then
                local target_obs = p.m_hObserverTarget
                if target_obs then
                    local watching = entity.get(target_obs, true)
                    if watching and watching == lp then
                        local name = p:get_name()
                        if name then table.insert(specs, name) end
                    end
                end
            end
        end
    end)
end

-- Hit-log ring is declared near damage_pops (top of Visuals) so the aim_ack /
-- player_death writer closures bind to the same upvalue (V3.10 forward-decl fix).

-- Hardcoded durations (no slider clutter)
local HITMARK_DURATION_S = 0.3
local DMGPOP_DURATION_S  = 1.5
local HITLOG_DURATION_S  = 4.0
local VELWARN_PULSE_HZ   = 4

-- Helper: pulse alpha 0..255 from a frequency
local function pulse_alpha(hz)
    return math.floor(127 + 127 * math.sin((globals.realtime or 0) * math.pi * 2 * hz))
end

-- Render loop
pcall(function()
    events.render:set(function()
        -- v3.31: on-screen version banner. Drawn BEFORE the master-disable check so the
        -- load-time result is visible even with the script's master switch off.
        if cfg_vc_draw then cfg_vc_draw() end
        if not enable_master:get() then return end
        update_perf()
        update_specs()

        local sx, sy = render.screen_size().x, render.screen_size().y
        local now = globals.realtime or 0
        local cx, cy = sx / 2, sy / 2

        -- ── v3.19: BLUR BEHIND MENU (only while menu visible) ──
        if vis_menublur:get() then
            pcall(function()
                local a = ui.get_alpha and ui.get_alpha() or 0
                if a and a > 0.01 then
                    render.blur(vector(0, 0), render.screen_size(), 4, a)
                end
            end)
        end

        -- ── v3.20: ANIMATED MENU BORDER (bettervisal-style layered frame + HSV flow) ──
        if vis_menuborder:get() then
            pcall(function()
                local a = ui.get_alpha and ui.get_alpha() or 0
                if not a or a <= 0 then return end
                local pos, sz = ui.get_position(), ui.get_size()
                if not (pos and sz) then return end
                local p2 = vector(pos.x + sz.x, pos.y + sz.y)
                local A = math.floor(a * 255)
                -- layered dark frame (exact bettervisal layering for the "premium" depth)
                render.rect(vector(pos.x - 7, pos.y - 9), vector(p2.x + 7, p2.y + 7), color(12, 12, 12, A))
                render.rect(vector(pos.x - 6, pos.y - 8), vector(p2.x + 6, p2.y + 6), color(60, 60, 60, A))
                render.rect(vector(pos.x - 5, pos.y - 7), vector(p2.x + 5, p2.y + 5), color(40, 40, 40, A))
                render.rect(vector(pos.x - 2, pos.y - 4), vector(p2.x + 2, p2.y + 2), color(60, 60, 60, A))
                render.rect(vector(pos.x - 1, pos.y - 3), vector(p2.x + 1, p2.y + 1), color(12, 12, 12, A))
                -- flowing HSV gradient on the outer accent edge (pcall: as_hsv build-variant)
                pcall(function()
                    local h = (globals.realtime or 0) * 0.10
                    local c1 = color():as_hsv((h) % 1, 0.65, 1.0);        c1.a = A
                    local c2 = color():as_hsv((h + 0.5) % 1, 0.65, 1.0);  c2.a = A
                    local ox1, oy1 = pos.x - 6, pos.y - 8
                    local ox2, oy2 = p2.x + 6, p2.y + 6
                    render.gradient(vector(ox1, oy1), vector(ox2, oy1 + 2), c1, c2, c1, c2)            -- top
                    render.gradient(vector(ox1, oy2 - 2), vector(ox2, oy2), c2, c1, c2, c1)            -- bottom
                    render.gradient(vector(ox1, oy1), vector(ox1 + 2, oy2), c1, c1, c2, c2)            -- left
                    render.gradient(vector(ox2 - 2, oy1), vector(ox2, oy2), c2, c2, c1, c1)            -- right
                end)
            end)
        end

        -- ── HIT-MARKER (4 short diagonal lines around crosshair, fade) ──
        if vis_hitmarker:get() then
            local age = now - hitmark_time
            if age >= 0 and age < HITMARK_DURATION_S then
                local alpha = math.floor(255 * (1 - age / HITMARK_DURATION_S))
                local L = 8
                local col = color(255, 80, 80, alpha)
                pcall(function()
                    render.line(vector(cx - L*2, cy - L*2), vector(cx - L, cy - L), col)
                    render.line(vector(cx + L,   cy - L),   vector(cx + L*2, cy - L*2), col)
                    render.line(vector(cx - L*2, cy + L*2), vector(cx - L, cy + L), col)
                    render.line(vector(cx + L,   cy + L),   vector(cx + L*2, cy + L*2), col)
                end)
            end
        end

        -- ── V1.6 M + V2.3: ROTATING AA INDICATOR (animated line around crosshair)
        -- V2.3 bugfix: arrow was reading nl_refs.aa_bodyyaw_inv:get() which returns
        -- the user's manual inverter (default false -> always right ">"). Now uses
        -- aa_jitter_dir as primary so the arrow animates with our jitter rhythm
        -- and shows actual current side. Only falls back to NL inverter if AA
        -- override is OFF (user is on NL's manual AA).
        if vis_aaarrows:get() then
            local lp = entity.get_local_player()
            if lp and lp:is_alive() then
                local side
                if aa_enable:get() then
                    side = aa_jitter_dir or 1
                else
                    side = 1
                    pcall(function()
                        if nl_refs.aa_bodyyaw_inv then
                            local v = nl_refs.aa_bodyyaw_inv:get()
                            if type(v) == "boolean" then side = v and -1 or 1 end
                        end
                    end)
                end
                -- main desync arrow (color-coded by side: yellow=left, cyan=right)
                local mcol = (side < 0) and color(255, 230, 80, 255) or color(80, 200, 255, 255)
                local txt  = (side < 0) and "<" or ">"
                local ox   = (side < 0) and -22 or 14
                pcall(function() render.text(4, vector(cx + ox, cy - 6), mcol, nil, txt) end)
                -- rotating accent line — small dash that spins with jitter_counter (animation)
                local ang = (aa_jitter_counter * 0.35) + now * 1.8
                local r1, r2 = 18, 28
                local x1 = cx + math.cos(ang) * r1
                local y1 = cy + math.sin(ang) * r1
                local x2 = cx + math.cos(ang) * r2
                local y2 = cy + math.sin(ang) * r2
                pcall(function()
                    render.line(vector(x1, y1), vector(x2, y2), color(120, 180, 255, 180))
                end)
            end
        end

        -- ── V1.12: DAMAGE POPUPS — screen-edge stack (no world_to_screen, no victim entity read) ──
        -- Color by hitbox: head=red / chest=green / stomach=yellow / leg=blue.
        if vis_dmgind:get() then
            local stack_x = cx + 60   -- right of crosshair
            local stack_y_base = cy + 30
            local row = 0
            for i = #damage_pops, 1, -1 do
                local pop = damage_pops[i]
                local age = now - pop.time
                if age > DMGPOP_DURATION_S then
                    table.remove(damage_pops, i)
                else
                    local alpha = math.floor(255 * (1 - age / DMGPOP_DURATION_S))
                    local r, g, b = 255, 200, 80
                    local hb = pop.hitbox_id
                    if hb == 0 then r, g, b = 255, 80, 80
                    elseif hb == 3 then r, g, b = 120, 220, 120
                    elseif hb == 4 then r, g, b = 255, 220, 80
                    elseif hb == 6 or hb == 7 then r, g, b = 120, 180, 255
                    end
                    local y = stack_y_base + row * 16
                    pcall(function()
                        render.text(4, vector(stack_x, y),
                                    color(r, g, b, alpha), nil,
                                    string.format("-%d HP", pop.dmg))
                        if pop.hp_left > 0 then
                            render.text(3, vector(stack_x + 60, y + 2),
                                        color(180, 180, 180, alpha), nil,
                                        string.format("(%d hp)", pop.hp_left))
                        end
                    end)
                    row = row + 1
                end
            end
        end

        -- ── V1.6 I: ANIMATED GRADIENT WATERMARK (color cycle via sine waves on RGB) ──
        if vis_watermark:get() then
            local lp_name = common and common.get_username and common.get_username() or "Player"
            local txt = string.format("Sel01 | %s | %d fps | %d ms", lp_name, perf.fps, perf.ping)
            local tw = 0
            pcall(function() tw = render.measure_text(3, nil, txt).x end)
            local pad = 8
            local wx, wy = sx - tw - pad * 2 - 12, 12
            -- animated RGB via 3 phase-shifted sine waves (no neverlose/gradient dep)
            local t = now * 1.5
            local g_r = math.floor(160 + 60 * math.sin(t))
            local g_g = math.floor(160 + 60 * math.sin(t + 2.09))  -- +2pi/3
            local g_b = math.floor(220 + 35 * math.sin(t + 4.19))  -- +4pi/3
            pcall(function()
                render.rect(vector(wx, wy), vector(wx + tw + pad * 2, wy + 22), color(15, 15, 20, 220))
                render.rect_outline(vector(wx, wy), vector(wx + tw + pad * 2, wy + 22), color(g_r, g_g, g_b, 255), 1)
                -- "Sel01" prefix gets the animated color, rest is white-ish
                render.text(3, vector(wx + pad, wy + 5), color(g_r, g_g, g_b, 255), nil, "Sel01")
                render.text(3, vector(wx + pad + 32, wy + 5), color(220, 230, 255, 255), nil,
                            string.format("| %s | %d fps | %d ms", lp_name, perf.fps, perf.ping))
            end)
        end

        -- V3.16: 🤡 TROLL indicator — pulsing top-center banner while the troll preset is
        -- active, so it is obvious you're in bait mode (not competitive).
        if _troll_mode then
            pcall(function()
                local txt = "🤡 TROLL MODE — run in, watch them whiff"
                local tw = 0
                pcall(function() tw = render.measure_text(4, nil, txt).x end)
                local pulse = math.floor(180 + 75 * math.sin(now * 6))
                local tx = (sx - tw) / 2
                render.text(4, vector(tx, 46), color(255, pulse, 60, 255), nil, txt)
            end)
        end

        -- ── V1.6 J: HVH STATE INDICATORS (DT/HS/FAKE/MANUAL/DEF/ONSHOT/FREE/SW/FD) ──
        if vis_indicators:get() then
            -- v3.27: MINIMAL JAG0YAW-style indicator — centered under the crosshair,
            -- plain clean text, only the basics: title + movement state + (optional)
            -- desync + a SHORT list of active key states. No boxes, no abbreviation
            -- spam, no left column. The big chip list was too much.
            pcall(function()
                local lp = entity.get_local_player()
                if not (lp and lp:is_alive()) then return end
                local aa_on = aa_enable:get()
                local f, sp = 0, 0
                pcall(function()
                    f = lp.m_fFlags or 0
                    local v = lp.m_vecVelocity; sp = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
                end)
                local mstate = (bit.band(f, 1) == 0) and "AIR"
                            or (bit.band(f, 2) ~= 0) and "CROUCH"
                            or (sp > 5) and "MOVING" or "STANDING"
                -- short curated list of active key states (dynamic / important only)
                local subs = {}
                if aa_on and aa_def_on_dmg:get() and now < (aa_state.defensive_until or 0) then subs[#subs+1] = "DEFENSIVE" end
                if aa_on and aa_onshot:get() and now < (aa_state.on_shot_until or 0) then subs[#subs+1] = "ON-SHOT" end
                pcall(function() if nl_refs.rage_dt and nl_refs.rage_dt:get() then subs[#subs+1] = "DOUBLE TAP" end end)
                pcall(function() if nl_refs.aa_fakeduck and nl_refs.aa_fakeduck:get() then subs[#subs+1] = "FAKE DUCK" end end)
                local mside = aa_desync_side:get()
                if mside == "Left" then subs[#subs+1] = "MANUAL L" elseif mside == "Right" then subs[#subs+1] = "MANUAL R" end
                -- desync value (smoothed)
                local dline
                if vis_desyncpct:get() and rage and rage.antiaim and rage.antiaim.get_rotation then
                    local fk, rl = rage.antiaim:get_rotation(true), rage.antiaim:get_rotation()
                    if fk and rl then
                        local d = math.min(math.abs(rl - fk) / 2, 60)
                        _vis_state.desync_shown = _vis_state.desync_shown + (d - _vis_state.desync_shown) * 0.06
                        dline = string.format("DESYNC %.0f", _vis_state.desync_shown)
                    end
                end
                -- centered text stack under the crosshair
                local y = cy + 24
                local function ctext(font, txt, col)
                    local tw = 0
                    pcall(function() tw = render.measure_text(font, nil, txt).x end)
                    if tw <= 0 then tw = #txt * 6 end
                    pcall(function() render.text(font, vector(cx - tw / 2, y), col, nil, txt) end)
                    y = y + (font >= 4 and 16 or 13)
                end
                ctext(4, "SEL01", color(120, 200, 255, 255))
                ctext(3, "- " .. mstate .. " -", color(210, 215, 225, 215))
                if dline then ctext(3, dline, color(150, 200, 255, 215)) end
                for i = 1, #subs do ctext(3, subs[i], color(170, 230, 175, 230)) end
            end)
        end

        -- ── VELOCITY INDICATOR (v3.20: frostlive-style — icon box + label box +
        --    blur backdrop + clipped color-by-% fill bar + smooth fade) ──
        if vis_velwarn:get() then
            pcall(function()
                local lp = entity.get_local_player()
                local alive = lp and lp:is_alive()
                local vmod = (alive and (lp.m_flVelocityModifier or 1)) or 1
                local menu_open = ui.get_alpha and ui.get_alpha() > 0
                -- show when actually slowed, or as a live preview while the menu is open
                local want = (vmod < 1) or menu_open
                _vis_state.vel_a = _vis_state.vel_a + ((want and 1 or 0) - _vis_state.vel_a) * 0.12
                local a = _vis_state.vel_a
                if a <= 0.02 then return end
                if (vmod >= 1) and menu_open then vmod = math.min(1, (globals.tickcount % 200) / 150) end
                local A   = math.floor(255 * a)
                local fnt = _vfont()
                local rad = 8
                local label = "velocity   " .. string.format("%d%%", math.floor(vmod * 100))
                local icon  = ui.get_icon("triangle-exclamation")
                local bg    = color(14, 14, 18, math.floor(150 * a))
                -- color by remaining speed: red <33%, orange <50%, accent >50%
                local bar = (vmod <= 0.33) and color(230, 110, 110)
                         or (vmod <= 0.5)  and color(235, 175, 110)
                         or color(120, 200, 255)
                bar.a = A
                local isz = vector(34, 34)
                local lw  = render.measure_text(fnt, nil, label).x + 22
                local box = vector(lw, 34)
                local base = vector(cx - (isz.x + 6 + box.x) / 2, sy * 0.18)
                -- icon box
                render.blur(base, base + isz, 2, a, rad)
                render.rect(base, base + isz, bg, rad)
                local iw = render.measure_text(fnt, nil, icon)
                render.text(fnt, base + (isz - iw) / 2, color(bar.r, bar.g, bar.b, A), nil, icon)
                -- label box
                local lb = base + vector(isz.x + 6, 0)
                render.blur(lb, lb + box, 2, a, rad)
                render.rect(lb, lb + box, bg, rad)
                local tw = render.measure_text(fnt, nil, label)
                render.text(fnt, lb + vector(11, (box.y - tw.y) / 2), color(255, 255, 255, A), nil, label)
                -- clipped fill bar along the bottom
                local bh = 4
                local by = lb + vector(0, box.y - bh)
                render.push_clip_rect(by, vector(by.x + box.x * vmod, by.y + bh))
                render.rect(by, by + vector(box.x, bh), bar, { 0, 0, rad, rad })
                render.pop_clip_rect()
            end)
        end

        -- ── V2.9: EVENT LOG (top-left) — HITS + MISSES + KILLS unified ──
        -- KILL: green block "▶ KILL <name>"
        -- HIT:  yellow/green "✓ hit <name> [hb] +<dmg>"
        -- MISS: red          "✗ miss <name> [hb] (<reason>)"
        if vis_hitlog:get() then
            local hx, hy = 16, 16
            local row = 0
            for i = #hit_log, 1, -1 do
                local entry = hit_log[i]
                local age = now - entry.time
                if age > HITLOG_DURATION_S then
                    table.remove(hit_log, i)
                else
                    local alpha = math.floor(255 * (1 - age / HITLOG_DURATION_S))
                    local y     = hy + row * 14
                    local kind  = entry.kind or "hit"
                    pcall(function()
                        if kind == "kill" then
                            render.text(4, vector(hx, y),
                                color(120, 255, 120, alpha), nil,
                                string.format("KILL  %s", entry.name or "?"))
                        elseif kind == "miss" then
                            render.text(3, vector(hx, y),
                                color(255, 100, 100, alpha), nil,
                                string.format("MISS  %s  [%s]  (%s)",
                                    entry.name or "?",
                                    entry.hitbox or "?",
                                    entry.reason or "?"))
                        else  -- hit
                            local dmg = entry.dmg or 0
                            local dmg_r, dmg_g, dmg_b = 220, 220, 220
                            if dmg >= 100 then dmg_r, dmg_g, dmg_b = 255, 100, 100
                            elseif dmg >= 70 then dmg_r, dmg_g, dmg_b = 255, 200, 80
                            elseif dmg >= 40 then dmg_r, dmg_g, dmg_b = 200, 220, 120
                            end
                            render.text(3, vector(hx, y),
                                color(dmg_r, dmg_g, dmg_b, alpha), nil,
                                string.format("HIT   %s  [%s]  +%d",
                                    entry.name or "?",
                                    entry.hitbox or "?",
                                    dmg))
                        end
                    end)
                    row = row + 1
                end
            end
        end

        -- ── KEYBINDS PANEL (right-middle, active hotkeys list) ──
        if vis_keybinds:get() then
            local active = {}
            -- V2.7: show Peek Boost active state
            if _peek_boost_active then
                table.insert(active, "Peek Boost: ACTIVE")
            end
            -- NL manual binds + double-tap if enabled show as fallback
            if #active > 0 then
                local lh = 14
                local h = #active * lh + 18
                local bx, by = sx - 180, sy / 2 + 80
                pcall(function()
                    render.rect(vector(bx, by), vector(bx + 160, by + h), color(15, 15, 20, 200))
                    render.rect_outline(vector(bx, by), vector(bx + 160, by + h), color(120, 180, 255, 220), 1)
                    render.text(3, vector(bx + 8, by + 4), color(180, 220, 255, 255), nil, "Active Keys")
                    for i, name in ipairs(active) do
                        render.text(3, vector(bx + 8, by + 4 + i * lh), color(220, 220, 220, 240), nil,
                                    "• " .. name)
                    end
                end)
            end
        end

        -- ── CLANTAG UPDATE ── (v3.18: moved OUT of render → net_update_end below.
        -- common.set_clan_tag is a game-state write; called from the render/paint
        -- thread it was silently ignored, so the animated tag never changed. The
        -- working bloodwings pattern drives it from events.net_update_end.)

        -- ── SPECTATOR OVERLAY (left-middle) ──
        if vis_specoverlay:get() and #specs > 0 then
            local lh = 14
            local h = #specs * lh + 18
            local bx, by = 16, sy / 2 - h / 2
            pcall(function()
                render.rect(vector(bx, by), vector(bx + 180, by + h), color(15, 15, 20, 200))
                render.rect_outline(vector(bx, by), vector(bx + 180, by + h), color(255, 180, 80, 220), 1)
                render.text(3, vector(bx + 8, by + 4), color(255, 180, 80, 255), nil,
                            string.format("Spectators (%d)", #specs))
                for i, name in ipairs(specs) do
                    render.text(3, vector(bx + 8, by + 4 + i * lh), color(220, 220, 220, 240), nil, name)
                end
            end)
        end

        -- v3.25: the standalone DESYNC indicator + SKEET panel were merged into the
        -- single left-edge state column (built in the indicators block above) so they
        -- no longer clutter the crosshair / center. Toggles vis_desyncpct + vis_skeet
        -- still gate their entries there.

        -- ── v3.19: NETGRAPH (ping / loss / choke + lag-comp warn, bottom-left) ──
        if vis_netgraph:get() and globals.is_in_game then
            pcall(function()
                local nc = utils.net_channel and utils.net_channel()
                if not nc then return end
                local ping  = math.floor(math.min(999, (nc.latency and nc.latency[1] or 0) * 1000))
                local loss  = nc.loss  and nc.loss[1]  or 0
                local choke = nc.choke and math.floor(nc.choke[1] or 0) or 0
                local gx, gy = 20, sy - 96
                local function line(i, txt, c) render.text(3, vector(gx, gy + i * 13), c, nil, txt) end
                local white = color(210, 220, 235, 240)
                line(0, "ping:  " .. ping .. "ms",  ping > 120 and color(255, 120, 60, 240) or white)
                line(1, "loss:  " .. loss .. "%",   loss > 0 and color(255, 120, 60, 240) or white)
                line(2, "choke: " .. choke .. "%",  choke > 0 and color(255, 200, 60, 240) or white)
                -- lag-comp warn: heavy choke = packets held = LC likely breaking
                local ck = globals.choked_commands or 0
                if ck >= 6 then
                    line(3, "LC: BREAKING (" .. ck .. ")", color(255, 70, 90, 240))
                else
                    line(3, "LC: ok", color(143, 194, 21, 240))
                end
            end)
        end

        -- ── v3.19: CUSTOM SCOPE OVERLAY (replaces NL scope lines while scoped) ──
        if vis_custscope:get() then
            pcall(function()
                local lp = entity.get_local_player()
                local scoped = lp and lp.m_bIsScoped
                if nl_refs.vis_scope_ovl then nl_refs.vis_scope_ovl:override("Remove All") end
                if not scoped then return end
                local ft = (globals.frametime or 0.016) * 14
                _vis_state.scope_gap  = _vis_state.scope_gap  + (10 - _vis_state.scope_gap)  * math.min(ft, 1)
                _vis_state.scope_size = _vis_state.scope_size + (26 - _vis_state.scope_size) * math.min(ft, 1)
                local g, s = _vis_state.scope_gap, _vis_state.scope_size
                local main = color(120, 200, 255, 235)
                local edge = color(120, 200, 255, 40)
                if vis_scope_rot:get() then render.push_rotation(45, vector(cx, cy)) end
                render.gradient(vector(cx, cy - g - s), vector(cx + 1, cy - g), edge, edge, main, main)
                render.gradient(vector(cx, cy + g + 1), vector(cx + 1, cy + g + s), main, main, edge, edge)
                render.gradient(vector(cx - g - s, cy), vector(cx - g, cy + 1), edge, main, edge, main)
                render.gradient(vector(cx + g + 1, cy), vector(cx + g + s, cy + 1), main, edge, main, edge)
                if vis_scope_rot:get() then render.pop_rotation() end
            end)
        elseif nl_refs.vis_scope_ovl then
            pcall(function() nl_refs.vis_scope_ovl:override() end)  -- restore NL scope when off
        end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- v3.19: LOCAL-MODEL EVENTS (separate from render — return-value events)
-- common pattern from gazolina (events.draw_model / events.localplayer_transparency
-- call form) + nyanza. These are NOT events.render and NOT createmove, so no clash
-- with the single render handler or createmove_unified.
-- ══════════════════════════════════════════════════════════════════════════
do
    -- Fade own model when scoped (returns the alpha NL applies to the local player).
    local ok = pcall(function()
        events.localplayer_transparency(function()
            if not (enable_master:get() and vis_scopefade:get()) then return 255 end
            local lp = entity.get_local_player()
            local scoped = lp and (lp.m_bIsScoped or lp.m_bResumeZoom)
            local target = scoped and 70 or 255
            local a = _vis_state.model_alpha or 255
            local step = 12
            if a < target then a = math.min(a + step, target)
            elseif a > target then a = math.max(a - step, target) end
            _vis_state.model_alpha = a
            return a
        end)
    end)
    _hooks_status.model_fade = ok and "localplayer_transparency" or nil

    -- Remove sleeves (return false to skip rendering a sleeve model).
    local ok2 = pcall(function()
        events.draw_model(function(m)
            if not (enable_master:get() and vis_sleeves:get()) then return true end
            if m and m.name and tostring(m.name):find("sleeve") then return false end
            return true
        end)
    end)
    _hooks_status.remove_sleeves = ok2 and "draw_model" or nil
end

-- ══════════════════════════════════════════════════════════════════════════
-- QoL — animated clantag, kill-say, auto-accept
-- ══════════════════════════════════════════════════════════════════════════
local clantag_phase = 1
local clantag_last_change = 0

local CLANTAG_FRAMES = {
    wave   = {"Sel01", "sel01", "SEL01", "sel01", "Sel01"},
    spin   = {"Sel01 |", "Sel01 /", "Sel01 -", "Sel01 \\"},
    pulse  = {"Sel01", "[Sel01]", "Sel01", "(Sel01)"},
    -- v3.18: extra themed styles (ASCII-only — clan tags drop most unicode)
    load   = {"Sel01", "Sel01.", "Sel01..", "Sel01..."},
    scan   = {">Sel01", ">>Sel01", "Sel01<<", "Sel01<"},
    glitch = {"Sel01", "5el01", "$el01", "5EL01", "Sel01"},
    arrow  = {"-> Sel01", "Sel01 <-", "-> Sel01", "Sel01 <-"},
    rage   = {"Sel01", "Sel01 ez", "Sel01", "Sel01 :)"},
}

update_clantag = function()
    if not (enable_master:get() and qol_clantag:get()) then return end
    local now = globals.realtime or 0
    if now - clantag_last_change < 0.4 then return end
    clantag_last_change = now
    local style = qol_clantag_st:get()
    local frames = CLANTAG_FRAMES.wave
    if     style == "Spin"    then frames = CLANTAG_FRAMES.spin
    elseif style == "Pulse"   then frames = CLANTAG_FRAMES.pulse
    elseif style == "Loading" then frames = CLANTAG_FRAMES.load
    elseif style == "Scan"    then frames = CLANTAG_FRAMES.scan
    elseif style == "Glitch"  then frames = CLANTAG_FRAMES.glitch
    elseif style == "Arrow"   then frames = CLANTAG_FRAMES.arrow
    elseif style == "Rage"    then frames = CLANTAG_FRAMES.rage
    end
    clantag_phase = (clantag_phase % #frames) + 1
    pcall(function()
        -- Verified API from nyanza snapshot + bloodwings: common.set_clan_tag
        if common and common.set_clan_tag then common.set_clan_tag(frames[clantag_phase]) end
    end)
end

-- v3.18: clantag is driven from events.net_update_end (the game network tick),
-- NOT events.render. common.set_clan_tag only takes effect from a game-state
-- context — the bloodwings reference uses net_update_end (bloodwings_33877:1020).
-- Throttle (0.4s) + master/toggle gate stay inside update_clantag itself.
-- NOTE: do NOT add a fallback that calls events.createmove:set here — the config's
-- createmove_unified is already registered on createmove (line ~1001) and a second
-- :set would OVERWRITE it, killing AA sync / movement / preset drain. net_update_end
-- is confirmed present on this NL build (bloodwings drives its clantag from it).
_hooks_status.clantag = register_first(function() pcall(update_clantag) end,
                                       "net_update_end", "net_update", "createmove_end")

-- (master-disable handler unified later in shutdown section — clears clantag + overrides)

-- ── KILL-SAY rotation (chat) ──
-- V2.0: KILL_LINES kept but unused (player_death handler dropped). Future re-add safe.
local KILL_LINES = {
    memes  = {"ez", "skill issue", "gg", "next?", "+rep"},
    tilt   = {"who?", "and who are you?", "yikes", "delete cs", "uninstall"},
    polite = {"gg wp", "well played", "good fight", "respect", "rematch?"},
    sel01  = {"Sel01 says hi", "powered by Sel01-Solver", "resolved.", "Sel01 → ★", "Sel01 brand kill"},
}

-- V2.0: player_death kill-say handler dropped (NL Misc has built-in).
-- V2.0: match_state / matchmaking auto-accept handlers dropped (NL has built-in).

-- ══════════════════════════════════════════════════════════════════════════
-- INFO BUTTONS (Status + Reset)
-- ══════════════════════════════════════════════════════════════════════════
local function dump_status()
    cs_log_color("══ Sel01-Config v" .. SEL01_CFG_VERSION .. " STATUS ══")
    cs_log(string.format("Master enabled: %s", tostring(enable_master:get())))
    cs_log(string.format("AA override: %s | pitch=%s yaw_base=%s desync=%d",
        tostring(aa_enable:get()), tostring(aa_pitch:get()),
        tostring(aa_yaw_base:get()), aa_desync:get()))
    cs_log(string.format("Visuals: watermark=%s indic=%s velwarn=%s arrows=%s hitmark=%s hitlog=%s keybinds=%s dmgind=%s spec=%s",
        tostring(vis_watermark:get()),  tostring(vis_indicators:get()),
        tostring(vis_velwarn:get()),    tostring(vis_aaarrows:get()),
        tostring(vis_hitmarker:get()),  tostring(vis_hitlog:get()),
        tostring(vis_keybinds:get()),   tostring(vis_dmgind:get()),
        tostring(vis_specoverlay:get())))
    cs_log(string.format("QoL: clantag=%s (killsay/autoaccept dropped — use NL)",
        tostring(qol_clantag:get())))
    cs_log(string.format("Perf: FPS=%d ping=%d ms", perf.fps, perf.ping))
    cs_log_color("══ END STATUS ══")
end
pcall(function() btn_status:set_callback(function() dump_status() end) end)
pcall(function() btn_reset:set_callback(function() apply_preset("dynamic") end) end)

-- V3.8: full debug stats dump — every eckdatum the user might want.
-- Sections: SESSION → DEALT → HITBOX → DAMAGE → KILL/HIT-LOG-SUMMARY →
--           TAKEN (all 10 incidents + AA snapshots) → CONFIG → NL-RAGEBOT-LIVE →
--           AA-LIVE → MOVEMENT-LIVE → PERF → ANTI-RESOLVER (v3.6/3.7 flags).
local function _nl_get(ref, fallback)
    if not ref then return fallback end
    local ok, v = pcall(function() return ref:get() end)
    if ok then return v end
    return fallback
end
local function _b(v) return v and "ON" or "OFF" end

local function dump_stats()
    local now      = globals.realtime or 0
    local elapsed  = now - (stats.session_start or now)
    local fired    = stats.shots_fired
    local hits     = stats.shots_hit
    local misses   = stats.shots_missed
    local hit_rate = fired > 0 and (hits / fired * 100) or 0
    local hs_rate  = hits  > 0 and (stats.hits_head / hits * 100) or 0
    local kills    = stats.kills or 0  -- V3.15: monotonic counter (was recounted from
                                       -- the rotating hit_log ring → always 0)

    cs_log_color("══════════════════════════════════════════════════")
    cs_log_color("  Sel01-Config v" .. SEL01_CFG_VERSION .. " — DEBUG STATS DUMP")
    cs_log_color("══════════════════════════════════════════════════")

    -- ── SESSION ──
    cs_log_color("── SESSION ──")
    cs_log(string.format("  Time: %.1f min  |  Master=%s  AA-override=%s",
        elapsed / 60, _b(enable_master:get()), _b(aa_enable:get())))

    -- ── DEALT ──
    cs_log_color("── DEALT ──")
    cs_log(string.format("  Shots: %d fired  %d hit  %d miss  =  %.1f%% hit-rate",
        fired, hits, misses, hit_rate))
    cs_log(string.format("  Hitbox split: head=%d chest=%d stomach=%d leg=%d other=%d  =  %.1f%% HS",
        stats.hits_head, stats.hits_chest, stats.hits_stomach, stats.hits_leg,
        stats.hits_other, hs_rate))
    cs_log(string.format("  Damage: total=%d  biggest=%d  1-taps(>=100)=%d  kills=%d",
        stats.total_dmg, stats.biggest_hit, stats.one_taps, kills))
    cs_log(string.format("  Avg dmg: %.1f / shot  |  %.1f / hit  |  KD-ish=%.2f",
        fired > 0 and (stats.total_dmg / fired) or 0,
        hits  > 0 and (stats.total_dmg / hits)  or 0,
        stats.hits_taken > 0 and (hits / stats.hits_taken) or hits))

    -- ── RECENT EVENT-LOG SUMMARY (last 8 from hit_log) ──
    cs_log_color("── RECENT EVENTS (last 8) ──")
    local start_idx = math.max(1, #hit_log - 7)
    for i = #hit_log, start_idx, -1 do
        local e = hit_log[i]
        local age = now - (e.time or 0)
        if e.kind == "hit" then
            cs_log(string.format("  [%.1fs] HIT  %s  %s  dmg=%d",
                age, tostring(e.name), tostring(e.hitbox), e.dmg or 0))
        elseif e.kind == "miss" then
            cs_log(string.format("  [%.1fs] MISS %s  (%s)",
                age, tostring(e.name), tostring(e.reason)))
        elseif e.kind == "kill" then
            cs_log(string.format("  [%.1fs] KILL %s", age, tostring(e.name)))
        end
    end

    -- ── HITS TAKEN ──
    cs_log_color("── HITS TAKEN (full incidents w/ AA snapshot) ──")
    cs_log(string.format("  TAKEN: %d hits  %d dmg total  avg=%.1f/hit",
        stats.hits_taken, stats.dmg_taken,
        stats.hits_taken > 0 and (stats.dmg_taken / stats.hits_taken) or 0))
    if #hits_taken_log > 0 then
        for i = #hits_taken_log, 1, -1 do
            local e = hits_taken_log[i]
            local s = e.snapshot or {}
            cs_log(string.format("  [%.1fs ago] %s hit %s for %d (hp_left=%d)",
                now - e.time, e.atk_name or "?", e.hitbox or "?", e.dmg or 0, e.hp_left or 0))
            cs_log(string.format("    AA=%s desync=%d air-override=%s(mag=%d) anti-BF=%s onshot=%s fd-assist=%s freestand=%s",
                _b(s.aa_enable),
                s.desync or 0, _b(s.air_set), s.air_mag or 0,
                _b(s.anti_bf), _b(s.on_shot), _b(s.fd_assist),
                _b(s.freestanding)))
            cs_log(string.format("    airborne=%s velocity=%d peek-boost=%s",
                _b(s.airborne), s.velocity or 0, _b(s.peek_boost)))
        end
    end

    -- ── CURRENT AA CONFIG (Sel01-Config sliders + switches) ──
    cs_log_color("── AA CONFIG (Sel01-Config) ──")
    cs_log(string.format("  pitch=%s  yaw_base=%s  yaw_mod=%s int=%d mag=%d",
        tostring(aa_pitch:get()), tostring(aa_yaw_base:get()),
        tostring(aa_yaw_mod:get()), aa_yaw_mod_int:get(), aa_yaw_mod_mag:get()))
    cs_log(string.format("  desync=%d side=%s  freestand=%s  at-targets=%s",
        aa_desync:get(), tostring(aa_desync_side:get()),
        _b(aa_freestanding:get()), _b(aa_at_targets:get())))
    cs_log(string.format("  on-shot=%s dur=%dms  air-override=%s mag=%d  anti-BF=%s var=%d",
        _b(aa_onshot:get()),   aa_onshot_dur:get(),
        _b(aa_air_set:get()),  aa_air_mag:get(),
        _b(aa_anti_bf:get()),  aa_anti_bf_var:get()))
    cs_log(string.format("  air-extras: flip=%s boost=%s fakeduck=%s",
        _b(aa_air_flip:get()), _b(aa_air_boost:get()), _b(aa_air_fakeduck:get())))
    cs_log(string.format("  move-override=%s mag=%d thresh=%d  flip=%s boost=%s",
        _b(aa_move_set:get()), aa_move_mag:get(), aa_move_thresh:get(),
        _b(aa_move_flip:get()), _b(aa_move_boost:get())))
    cs_log(string.format("  fd-assist=%s dur=%dms  pitch-jitter=%s  move-fakeduck=%s thresh=%d",
        _b(aa_fd_assist:get()), aa_fd_duration:get(),
        _b(aa_pitch_jitter:get()),
        _b(aa_move_fakeduck:get()), aa_move_fd_thresh:get()))

    -- ── ANTI-RESOLVER (v3.6/3.7) ──
    cs_log_color("── ANTI-RESOLVER (v3.6/3.7) ──")
    cs_log(string.format("  DEF-on-dmg=%s dur=%dms  active=%s (until %.1fs)",
        _b(aa_def_on_dmg:get()), aa_def_duration:get(),
        _b(now < (aa_state.defensive_until or 0)),
        math.max(0, (aa_state.defensive_until or 0) - now)))
    cs_log(string.format("  Slow-walk-boost=%s  FL-variance=%s active=%s base=%s",
        _b(aa_slow_boost:get()), _b(aa_fl_var:get()),
        _b(aa_state.fl_active), tostring(aa_state.fl_base)))
    cs_log(string.format("  Yaw-rotation=%s active=%s  Side-streak limit=%s thresh=%d (cur streak=%d dir=%d)",
        _b(aa_yaw_rotate:get()), _b(aa_state.yaw_active),
        _b(aa_side_streak:get()), aa_side_streak_n:get(),
        aa_state.side_streak_n or 0, aa_state.side_streak_dir or 0))
    cs_log(string.format("  Mag-jitter=%s  range=%d-%d°",
        _b(aa_mag_jitter:get()), aa_mag_jit_min:get(), aa_mag_jit_max:get()))

    -- ── NL RAGEBOT LIVE (read user's NL config) ──
    -- V3.15: format multi-select combos (HitboxSafety etc) — :get() returns a TABLE
    -- (array of selected labels OR {label=true} map), so tostring() printed a raw
    -- "table: 0x..." pointer. Join into a readable "Arms+Legs+Feet" string.
    local function _fmt_val(v)
        if type(v) ~= "table" then return tostring(v) end
        local parts = {}
        for k, val in pairs(v) do
            if type(k) == "number" then parts[#parts + 1] = tostring(val)
            elseif val == true then parts[#parts + 1] = tostring(k)
            elseif type(val) == "string" then parts[#parts + 1] = val end
        end
        return #parts > 0 and table.concat(parts, "+") or "(none)"
    end
    cs_log_color("── NL RAGEBOT (live) ──")
    cs_log(string.format("  HC=%s  MinDmg=%s  Penetrate=%s  AutoScope=%s",
        _fmt_val(_nl_get(nl_refs.rage_hc,         "?")),
        _fmt_val(_nl_get(nl_refs.rage_mindmg,     "?")),
        _fmt_val(_nl_get(nl_refs.rage_autowall,   "?")),
        _fmt_val(_nl_get(nl_refs.rage_autoscope,  "?"))))
    cs_log(string.format("  BodyAim=%s  SafePoints=%s  HitboxSafety=%s",
        _fmt_val(_nl_get(nl_refs.rage_bodyaim,    "?")),
        _fmt_val(_nl_get(nl_refs.rage_safepoint,  "?")),
        _fmt_val(_nl_get(nl_refs.rage_hitsafety,  "?"))))
    cs_log(string.format("  FakeLag: limit=%s var=%s",
        tostring(_nl_get(nl_refs.fl_limit,        "?")),
        tostring(_nl_get(nl_refs.fl_variability,  "?"))))
    cs_log(string.format("  NL slow-walk=%s  NL fake-duck=%s",
        _b(_nl_get(nl_refs.aa_slowwalk, false)),
        _b(_nl_get(nl_refs.aa_fakeduck, false))))

    -- ── PERF + MOVEMENT LIVE ──
    cs_log_color("── PERF + LIVE ──")
    local vel_now, airborne_now = 0, false
    pcall(function()
        local lp = entity.get_local_player()
        if lp then
            local v = lp.m_vecVelocity
            vel_now = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
            local f = lp.m_fFlags or 0
            airborne_now = bit.band(f, 1) == 0
        end
    end)
    cs_log(string.format("  FPS=%d  ping=%d ms  velocity=%.0f u/s  airborne=%s",
        perf.fps, perf.ping, vel_now, _b(airborne_now)))
    cs_log(string.format("  Hit-log entries: %d (cap %d)  |  Hits-taken entries: %d (cap %d)",
        #hit_log, HIT_LOG_MAX, #hits_taken_log, HITS_TAKEN_MAX))

    cs_log_color("══════════════════════════════════════════════════")
    cs_log_color("  END DUMP — copy from chat ↑ for sharing")
    cs_log_color("══════════════════════════════════════════════════")
end
pcall(function() btn_stats:set_callback(function() dump_stats() end) end)
pcall(function() btn_clear:set_callback(function()
    _stats_clear()
    cs_log_color("Stats cleared.")
end) end)

-- V3.1: data-driven recommendations based on current session stats
local function print_recommendations()
    cs_log_color("══ Sel01-Config v" .. SEL01_CFG_VERSION .. " RECOMMENDATIONS ══")
    local fired    = stats.shots_fired
    local hits     = stats.shots_hit
    local hit_rate = fired > 0 and (hits / fired * 100) or 0
    local hs_rate  = hits  > 0 and (stats.hits_head / hits * 100) or 0
    local taken    = stats.hits_taken or 0
    local dmg_in   = stats.dmg_taken  or 0
    local kd       = taken > 0 and (hits / taken) or hits

    -- Hit rate guidance
    if fired >= 5 then
        if hit_rate < 50 then
            cs_log("[OFFENSE] Hit-rate " .. math.floor(hit_rate) .. "% — enable resolver Aggressive Head-Focus (Advanced tab) or drop NL Hit Chance")
        elseif hs_rate < 30 and hits >= 3 then
            cs_log("[OFFENSE] HS-rate " .. math.floor(hs_rate) .. "% — enable resolver Aggressive Head-Focus + NL Min. Damage 80+ for head priority")
        else
            cs_log("[OFFENSE] OK — hit-rate " .. math.floor(hit_rate) .. "% / HS " .. math.floor(hs_rate) .. "%")
        end
    end

    -- Defense guidance (taking too many head shots = enable anti-HS)
    if taken >= 3 then
        cs_log(string.format("[DEFENSE] %d hits taken / %d dmg in this session", taken, dmg_in))
        -- check recent hits for head pattern
        local head_hits, total = 0, 0
        for _, e in ipairs(hits_taken_log) do
            total = total + 1
            if e.hb_id == 1 or e.hitbox == "head" then head_hits = head_hits + 1 end
        end
        if total > 0 and (head_hits / total) >= 0.5 then
            cs_log(string.format("[DEFENSE] %d/%d recent hits were HEAD — enable Pitch jitter + Auto fake-duck (Anti-HS Bundle button)",
                head_hits, total))
        end
        if not aa_pitch_jitter:get() then
            cs_log("[DEFENSE] Pitch jitter OFF — head Y stays constant. Click Anti-HS Bundle to enable.")
        end
        if not aa_move_fakeduck:get() then
            cs_log("[DEFENSE] Auto fake-duck OFF — running head exposed. Click Anti-HS Bundle to enable.")
        end
    end

    -- K/D-ish guidance
    if taken >= 5 and kd < 1 then
        cs_log(string.format("[KD] %.2f — try Defensive preset or enable Peek Boost hotkey + bind to NL Peek Assist", kd))
    end

    -- Resolver flag check
    cs_log("[TIP] Resolver Aggressive Head-Focus is OFF by default. Enable in Solver tab → Advanced for HS priority.")
    cs_log_color("══ END RECOMMENDATIONS ══")
end
pcall(function() btn_recom:set_callback(function() print_recommendations() end) end)

-- V3.1: Anti-HS Bundle = enable pitch_jitter + move_fakeduck + reasonable threshold
pcall(function() btn_antihs:set_callback(function()
    local on = not (aa_pitch_jitter:get() and aa_move_fakeduck:get())
    safe_set(aa_pitch_jitter,  on)
    safe_set(aa_move_fakeduck, on)
    safe_set(aa_move_fd_thresh, 100)
    cs_log_color("Anti-HS Bundle " .. (on and "ENABLED" or "DISABLED")
        .. " (pitch jitter + move-fakeduck @100u/s)")
end) end)

-- ══════════════════════════════════════════════════════════════════════════
-- SHUTDOWN
-- ══════════════════════════════════════════════════════════════════════════
-- Clear all NL :override() writes so user's manual UI returns to its real state.
local function clear_all_nl_overrides()
    for _, ref in pairs(nl_refs) do nl_clear(ref) end
end

pcall(function()
    events.shutdown:set(function()
        pcall(function() common.set_clan_tag("") end)
        clear_all_nl_overrides()
        cs_log_color("Sel01-Config v" .. SEL01_CFG_VERSION .. " — unloaded (overrides cleared)")
    end)
end)

-- Also clear on master-disable
enable_master:set_callback(function(r)
    if not r:get() then
        clear_all_nl_overrides()
        pcall(function() common.set_clan_tag("") end)
        cs_log_color("Master DISABLED — overrides + clantag cleared")
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
-- LOAD BANNER
-- ══════════════════════════════════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════════════════
-- VERSION CHECK (GitHub, v3.30) — one fetch of versions.txt at load. No nagging:
-- result is one line in the Info group + one console line, nothing on screen.
-- ══════════════════════════════════════════════════════════════════════════
do
    local VC_URL = "https://raw.githubusercontent.com/seltonmt012/Sel01-Solver/master/versions.txt"
    local VC_KEY = "config"

    -- v3.31: ON-SCREEN banner (menu label alone was easy to miss). "checking version..."
    -- while the request is in flight, then a short green "up to date" or a longer red
    -- "OUTDATED", each fading out — nothing stays on screen afterwards.
    cfg_vc_scr = { text = "checking version...", r = 190, g = 190, b = 190,
                   t_until = (globals.realtime or 0) + 12 }
    function cfg_vc_draw()
        local st = cfg_vc_scr
        if not st then return end
        local now = globals.realtime or 0
        if now >= (st.t_until or 0) then cfg_vc_scr = nil; return end
        local a = 255
        local left = st.t_until - now
        if left < 1.0 then a = math.floor(255 * left) end
        pcall(function()
            local ss = render.screen_size()
            render.text(4, vector(ss.x / 2, ss.y * 0.74), color(st.r, st.g, st.b, a), "c", st.text)
        end)
    end
    function cfg_vc_screen(text, r, g, b, secs)   -- global: main chunk is at the 200-local cap
        cfg_vc_scr = { text = text, r = r, g = g, b = b, t_until = (globals.realtime or 0) + secs }
    end

    local function vc_num(v)
        local a, b = tostring(v):match("(%d+)%.(%d+)")
        return (tonumber(a) or 0) * 1000 + (tonumber(b) or 0)
    end
    local function vc_set(text) pcall(function() if cfg_vc_label then cfg_vc_label:name(text) end end) end
    local function vc_apply(body)
        local latest
        for line in tostring(body):gmatch("[^\r\n]+") do
            local k, v = line:match("^%s*([%w_]+)%s*=%s*([%d%.]+)")
            if k == VC_KEY then latest = v end
        end
        if not latest then
            vc_set("\aAAAAAAFFv" .. SEL01_CFG_VERSION .. " - update check: no entry")
            cfg_vc_screen("Sel01-Config v" .. SEL01_CFG_VERSION .. "  -  version unknown", 190, 190, 190, 4)
            return
        end
        if vc_num(latest) > vc_num(SEL01_CFG_VERSION) then
            vc_set("\aFF5555FFUPDATE: v" .. latest .. " available (you run v" .. SEL01_CFG_VERSION .. ")")
            cfg_vc_screen("Sel01-Config OUTDATED  -  v" .. latest .. " available (you run v" .. SEL01_CFG_VERSION .. ")",
                      255, 85, 85, 15)
            pcall(function() cs_log_color("Sel01-Config: update available v" .. latest .. " (you run v"
                .. SEL01_CFG_VERSION .. ") - github.com/seltonmt012/Sel01-Solver") end)
        else
            vc_set("\a55DD55FFv" .. SEL01_CFG_VERSION .. " - up to date")
            cfg_vc_screen("Sel01-Config v" .. SEL01_CFG_VERSION .. "  -  up to date", 85, 221, 85, 4)
        end
    end
    local started = false
    pcall(function()
        http.get(VC_URL, function(ok, resp)
            if ok and resp and (resp.status == nil or resp.status == 200) and resp.body then
                pcall(vc_apply, resp.body)
            else
                vc_set("\aAAAAAAFFv" .. SEL01_CFG_VERSION .. " - update check failed")
                cfg_vc_screen("Sel01-Config v" .. SEL01_CFG_VERSION .. "  -  update check failed", 190, 190, 190, 4)
            end
        end)
        started = true
    end)
    if not started then
        -- fallback for builds without `http`: urlmon download to disk, then read it back
        pcall(function()
            pcall(ffi.cdef, [[
                void* __stdcall URLDownloadToFileA(void* a, const char* url, const char* file, int r, int cb);
                bool DeleteUrlCacheEntryA(const char* url);
            ]])
            local um, wi = ffi.load("UrlMon"), ffi.load("WinInet")
            local path = "nl/Sel01-Config/versions.txt"
            pcall(function() files.create_folder("nl/Sel01-Config/") end)
            pcall(function() files.write(path, "") end)   -- files.read popups on a missing path
            pcall(function() wi.DeleteUrlCacheEntryA(VC_URL) end)
            um.URLDownloadToFileA(nil, VC_URL, path, 0, 0)
            local body = files.read(path)
            if body and #body > 0 then vc_apply(body) end
        end)
        if cfg_vc_scr and tostring(cfg_vc_scr.text):find("checking") then
            cfg_vc_screen("Sel01-Config v" .. SEL01_CFG_VERSION .. "  -  update check failed", 190, 190, 190, 4)
        end
    end
end

cs_log_color("══════════════════════════════════════════")
cs_log_color("Sel01-Config v" .. SEL01_CFG_VERSION .. " loaded (CSGO HvH — +Magnitude jitter per-tick variance, anti EMA-resolvers)")
cs_log(string.format("  hooks  createmove=%s  aim_fire=%s",
    tostring(_hooks_status.createmove or "MISSING"),
    tostring(_hooks_status.aim_fire or "MISSING")))
cs_log_color("  AA via NL :override path (no cmd writes). Pick preset → Main.")
cs_log_color("══════════════════════════════════════════")
