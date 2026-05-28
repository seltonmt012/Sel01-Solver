-- ╔══════════════════════════════════════════════════╗
-- ║  Sel01-Config — Neverlose CSGO HvH config        ║
-- ║  Author: seltonmt01                              ║
-- ║  Version: 2.3                                    ║
-- ╚══════════════════════════════════════════════════╝
-- @name Sel01-Config
-- @author seltonmt01
-- @version 2.3
-- @description Air-AA improvements (HvH-grade): rapid inverter flip, max-jitter boost, optional
--              fake-duck, 1.5x anti-BF variance airborne. Transition handling clears overrides on land.

local SEL01_CFG_VERSION = "2.3"

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
local g_main    = ui.create(TAB, "Main",          1)
local g_aa      = ui.create(TAB, "Anti-Aim",      1)
local g_move    = ui.create(TAB, "Movement",      2)
local g_visual  = ui.create(TAB, "Visuals",       2)
local g_qol     = ui.create(TAB, "Quality of Life", 1)
local g_info    = ui.create(TAB, "Info",          2)

-- Header
g_main:label(accent .. ui.get_icon"user"     .. accent .. "  Welcome:  " .. common.get_username())
g_main:label(accent .. ui.get_icon"sparkles" .. accent .. "  Sel01-Config v" .. SEL01_CFG_VERSION .. " — companion to Sel01-Solver")
g_main:label(" ")
g_main:label(accent .. ui.get_icon"sliders"  .. accent .. "  Playstyle Presets:")

-- Forward-decl preset applier so callbacks see it at call-time, not parse-time
local apply_preset_fwd
local btn_aggressive = g_main:button("Aggressive (full send)",   function() apply_preset_fwd("aggressive") end)
local btn_dynamic    = g_main:button("Dynamic (balanced)",       function() apply_preset_fwd("dynamic")    end)
local btn_defensive  = g_main:button("Defensive (safe AA)",      function() apply_preset_fwd("defensive")  end)
local btn_spin       = g_main:button("Spin (full spinbot)",      function() apply_preset_fwd("spin")       end)

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
-- G: Anti-bruteforce jitter variance
local aa_anti_bf     = g_aa:switch("Anti-bruteforce jitter (random mag variance)", true)
local aa_anti_bf_var = g_aa:slider("Anti-BF variance (deg)", 5, 25, 15)
-- H: Fake-duck assist (V1.9: default OFF — hooks events.weapon_fire which fires for
-- audio/init events on spawn, suspected contributor to v1.8 spawn-crash)
local aa_fd_assist   = g_aa:switch("Fake-duck assist (auto on hostile-fire)", false)
local aa_fd_duration = g_aa:slider("Fake-duck duration (ms)", 200, 2000, 800)

-- ══════════════════════════════════════════════════════════════════════════
-- MOVEMENT UI
-- ══════════════════════════════════════════════════════════════════════════
g_move:label(accent .. ui.get_icon"running" .. accent .. "  Movement helpers")
-- AI Peek removed — NL Peek Assist is a HOTKEY element; our :override on a
-- hotkey userdata crashed CSGO. There is no Lua API to programmatically trigger
-- NL hotkeys from a script. The only reliable peek is NL's own.
g_move:label(accent .. "  AI Peek: assign NL Aimbot/Ragebot/Main/Peek Assist hotkey")
g_move:label(accent .. "  Slow-walk / Fake-duck: NL Aimbot/Anti Aim/Misc tab")
g_move:label(accent .. "  (NL has these built-in — no need to duplicate here)")

-- ══════════════════════════════════════════════════════════════════════════
-- VISUALS UI
-- ══════════════════════════════════════════════════════════════════════════
g_visual:label(accent .. ui.get_icon"eye" .. accent .. "  Visual additions")
local vis_watermark  = g_visual:switch(accent .. ui.get_icon"clock"      .. accent .. "  Watermark (user / FPS / ping)", true)
local vis_indicators = g_visual:switch(accent .. ui.get_icon"bolt"       .. accent .. "  State indicators (AA / DT / HS / FREE)", true)
local vis_velwarn    = g_visual:switch(accent .. ui.get_icon"feather"    .. accent .. "  Velocity warning", true)
local vis_aaarrows   = g_visual:switch(accent .. ui.get_icon"sliders"    .. accent .. "  Manual AA arrows", true)
local vis_hitmarker  = g_visual:switch(accent .. ui.get_icon"crosshairs" .. accent .. "  Hit marker", true)
local vis_hitlog     = g_visual:switch(accent .. ui.get_icon"bullseye"   .. accent .. "  Hit log (last 5 shots)", true)
local vis_keybinds   = g_visual:switch(accent .. ui.get_icon"user"       .. accent .. "  Keybinds panel", true)
local vis_dmgind     = g_visual:switch(accent .. ui.get_icon"skull"      .. accent .. "  Damage popup (-X HP on enemy)", true)
local vis_specoverlay= g_visual:switch(accent .. ui.get_icon"eye"        .. accent .. "  Spectator overlay", true)
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
local qol_clantag_st = g_qol:combo("Clantag style", {"Wave", "Spin", "Pulse"}, 1)
-- V2.0: dropped killsay + autoaccept + buybot — NL has these built-in (Misc tab).

-- ══════════════════════════════════════════════════════════════════════════
-- INFO UI
-- ══════════════════════════════════════════════════════════════════════════
local btn_status = g_info:button("Print Status", function() end) -- callback wired later
local btn_reset  = g_info:button("Reset Settings", function() end)
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
    -- V2.1: rage_peek_assist ref dropped — never override hotkey elements per tick.
    nl_refs.rage_hc          = nl_find_safe("Aimbot", "Ragebot", "Selection", "Hit Chance")
    nl_refs.rage_mindmg      = nl_find_safe("Aimbot", "Ragebot", "Selection", "Min. Damage")
    nl_refs.rage_autowall    = nl_find_safe("Aimbot", "Ragebot", "Selection", "Penetrate Walls")
    nl_refs.rage_bodyaim     = nl_find_safe("Aimbot", "Ragebot", "Safety", "Body Aim")
    nl_refs.rage_safepoint   = nl_find_safe("Aimbot", "Ragebot", "Safety", "Safe Points")
    nl_refs.rage_hitsafety   = nl_find_safe("Aimbot", "Ragebot", "Safety", "Ensure Hitbox Safety")
    nl_refs.rage_autoscope   = nl_find_safe("Aimbot", "Ragebot", "Accuracy", "Auto Scope")
    -- Visuals
    nl_refs.vis_viewmodel    = nl_find_safe("Visuals", "World", "Main", "Override Zoom", "Force Viewmodel")
    nl_refs.vis_removals     = nl_find_safe("Visuals", "World", "Main", "Removals")
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
local pending_preset = nil  -- "aggressive" / "dynamic" / "defensive" / "legit" or nil

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
local function _do_apply_preset(name)
    cs_log("[apply] start " .. tostring(name))
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
        safe_set(aa_air_flip, true)      -- V2.3: rapid inverter flip in air
        safe_set(aa_air_boost, true)     -- V2.3: max jitter offset in air
        safe_set(aa_air_fakeduck, false) -- V2.3: optional LBY break (noisy on ground sync, skip)
        safe_set(aa_anti_bf, true)
        safe_set(aa_anti_bf_var, 15)
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
        _safe_step("nl aa_enabled",     function() nl_override(nl_refs.aa_enabled, true) end)
        _safe_step("nl aa_freestand",   function() nl_override(nl_refs.aa_freestand, true) end)
        _safe_step("nl aa_avoidbk",     function() nl_override(nl_refs.aa_avoidbackstab, true) end)
        _safe_step("nl fl_switch",      function() nl_override(nl_refs.fl_switch, true) end)
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
        safe_set(vis_hitlog, false)
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
    on_shot_until = 0,
    fakeduck_until = 0,
    last_fire_time = 0,
}

-- V2.3: air-AA improvements for jumping aggressive play. New air-extras (rapid
-- inverter flip, max-jitter boost, force fake-duck). Transition handling clears
-- overrides on land so ground AA returns to user's preset state.
local aa_periodic_last_tick = 0
local _was_airborne = false

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

    local now = globals.realtime or 0
    local on_shot_active = aa_onshot:get() and now < aa_state.on_shot_until
    local anti_bf_active = aa_anti_bf:get()
    local air_set_active = aa_air_set:get() and airborne

    if not (air_set_active or on_shot_active or anti_bf_active) then return end

    -- desync magnitude: air > on-shot > base
    local lim = air_set_active and aa_air_mag:get() or aa_desync:get()
    if on_shot_active then lim = math.max(15, math.floor(lim * 0.5)) end

    local l_lim, r_lim = lim, lim
    if anti_bf_active then
        local var = aa_anti_bf_var:get()
        -- 1.5x variance airborne for more chaos
        if air_set_active then var = math.min(58, var * 1.5) end
        l_lim = lim + (math.random() * 2 - 1) * var
        r_lim = lim + (math.random() * 2 - 1) * var
    end
    if l_lim < 0 then l_lim = 0 elseif l_lim > 58 then l_lim = 58 end
    if r_lim < 0 then r_lim = 0 elseif r_lim > 58 then r_lim = 58 end
    nl_override(nl_refs.aa_bodyyaw_l, math.floor(l_lim))
    nl_override(nl_refs.aa_bodyyaw_r, math.floor(r_lim))

    -- V2.3 AIR EXTRAS — only when airborne
    if air_set_active then
        -- rapid inverter flip every periodic tick (~16Hz) — LBY break in air
        if aa_air_flip:get() then
            local flip_state = (aa_yaw_jitter_counter % 2 == 0)
            nl_override(nl_refs.aa_bodyyaw_inv, flip_state)
        end
        -- boost yaw modifier offset to 58 (max jitter angle) for max desync chaos
        if aa_air_boost:get() then
            nl_override(nl_refs.aa_yawmod_offset, 58)
        end
        -- force fake-duck in air — alt LBY break, ragebot harder to hit ducked target
        if aa_air_fakeduck:get() then
            nl_override(nl_refs.aa_fakeduck, true)
        end
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
-- MOVEMENT — V2.1: createmove_handler now a NO-OP. AI Peek per-tick override on
-- the Peek Assist hotkey element was the v2.0 spawn-crash cause. Use NL's
-- built-in hotkeys directly.
-- ══════════════════════════════════════════════════════════════════════════
local function createmove_handler(cmd) end

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
    -- V2.0: AA periodic sync restored (still throttled + alive-checked + lazy).
    aa_periodic_sync()
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

-- Forward-decl: update_clantag is defined further down but referenced inside the
-- events.render closure created below. NL UI callbacks capture upvalues at parse-
-- time — without this forward-decl the closure would bind to a global of the same
-- name (nil at call-time).
local update_clantag = function() end

-- V1.13 BISECT: aim_fire / ragebot_fire / weapon_fire / aim_ack / player_hurt
-- registrations DISABLED. on_local_fire kept as a stub for any future re-enable.
local function on_local_fire(event) end
_hooks_status.aim_fire = nil   -- not registered in v1.13

-- V1.13 BISECT: weapon_fire handler DISABLED (no registration). If config is
-- stable with this off, FD-assist or weapon_fire-related code is the crash.

-- V2.0: aim_ack restored, ZERO entity.get calls. Target name comes from event
-- fields only ("?" if not present). Hit-marker timer + hit-log push both fire.
pcall(function()
    events.aim_ack:set(function(event)
        pcall(function()
            if not (enable_master:get() and vis_hitmarker:get()) then return end
            if not event then return end
            local reason = event.state
            local HIT_STATES = { hit = true, damaged = true, ["hit-damaged"] = true }
            if reason and HIT_STATES[reason] then
                hitmark_time = globals.realtime or 0
                if vis_hitlog:get() then
                    -- No entity.get(event.target) — name field if NL provides it, else "?"
                    local target_name = tostring(event.target_name or event.name or "?")
                    local HB_NAMES = { [0]="head", [3]="chest", [4]="stomach",
                                       [6]="leg", [7]="leg" }
                    local hb_name = HB_NAMES[event.hitbox] or tostring(event.hitbox or "?")
                    table.insert(hit_log, {
                        time      = globals.realtime or 0,
                        name      = target_name,
                        dmg       = event.damage or 0,
                        dmg_want  = event.wanted_damage or event.requested_damage or event.damage or 0,
                        hitbox    = hb_name,
                        hitbox_id = event.hitbox or -1,
                    })
                    while #hit_log > HIT_LOG_MAX do table.remove(hit_log, 1) end
                end
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
            if not (enable_master:get() and vis_dmgind:get()) then return end
            if not event then return end
            local attacker = entity.get(event.attacker, true)
            local lp = entity.get_local_player()
            if attacker ~= lp then return end
            local victim = entity.get(event.userid, true)
            if not victim or victim == lp then return end
            local hb = -1
            pcall(function() hb = event.hitgroup or -1 end)
            table.insert(damage_pops, {
                time = globals.realtime or 0,
                dmg  = event.dmg_health or event.damage or 0,
                hp_left = event.health or 0,
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

-- Hit-log ring (last 5 entries: {time, target_name, dmg, hitbox})
local hit_log = {}
local HIT_LOG_MAX = 5

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
        if not enable_master:get() then return end
        update_perf()
        update_specs()

        local sx, sy = render.screen_size().x, render.screen_size().y
        local now = globals.realtime or 0
        local cx, cy = sx / 2, sy / 2

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

        -- ── V1.6 J: HVH STATE INDICATORS (DT/HS/FAKE/MANUAL/DEF/ONSHOT/FREE/SW/FD) ──
        if vis_indicators:get() then
            local indicators = {}
            local aa_on = aa_enable:get()
            -- DT (Double Tap) — red, highest priority
            pcall(function()
                if nl_refs.rage_dt and nl_refs.rage_dt:get() then
                    table.insert(indicators, {txt = "DT", col = color(255, 100, 100, 255)})
                end
            end)
            -- HS (Hide Shots) — orange
            pcall(function()
                if nl_refs.rage_hide and nl_refs.rage_hide:get() then
                    table.insert(indicators, {txt = "HS", col = color(255, 180, 80, 255)})
                end
            end)
            -- ON-SHOT — magenta pulse while window active
            if aa_on and aa_onshot:get() and now < aa_state.on_shot_until then
                local a = pulse_alpha(8)
                table.insert(indicators, {txt = "ON-SHOT", col = color(255, 80, 200, a)})
            end
            -- FAKE-DUCK assist active — cyan pulse
            if aa_fd_assist:get() and now < aa_state.fakeduck_until then
                local a = pulse_alpha(6)
                table.insert(indicators, {txt = "FD-ASSIST", col = color(80, 220, 255, a)})
            end
            -- AA basic
            if aa_on then table.insert(indicators, {txt = "AA", col = color(120, 220, 120, 255)}) end
            -- Manual side L / R from local desync_side combo
            local mside = aa_desync_side:get()
            if mside == "Left"  then table.insert(indicators, {txt = "MANUAL L", col = color(255, 230, 80, 255)}) end
            if mside == "Right" then table.insert(indicators, {txt = "MANUAL R", col = color(80, 200, 255, 255)}) end
            -- AIR override active when airborne
            if aa_on and aa_air_set:get() then
                local lp = entity.get_local_player()
                if lp then
                    local f = 0; pcall(function() f = lp.m_fFlags or 0 end)
                    if bit.band(f, 1) == 0 then
                        table.insert(indicators, {txt = "AIR", col = color(180, 220, 255, 220)})
                    end
                end
            end
            -- Anti-BF variance
            if aa_on and aa_anti_bf:get() then
                table.insert(indicators, {txt = "ANTI-BF", col = color(200, 180, 255, 220)})
            end
            -- FREE (Freestanding)
            if aa_on and aa_freestanding:get() then
                table.insert(indicators, {txt = "FREE", col = color(180, 200, 255, 255)})
            end
            -- Slow Walk / Fake Duck (NL state)
            pcall(function()
                if nl_refs.aa_slowwalk and nl_refs.aa_slowwalk:get() then
                    table.insert(indicators, {txt = "SW", col = color(255, 220, 120, 255)})
                end
            end)
            pcall(function()
                if nl_refs.aa_fakeduck and nl_refs.aa_fakeduck:get() then
                    table.insert(indicators, {txt = "FD", col = color(255, 220, 120, 255)})
                end
            end)
            -- draw stacked at bottom-center, line height 16
            local base_y = sy - 110
            for i, ind in ipairs(indicators) do
                local tw = 0
                pcall(function() tw = render.measure_text(4, nil, ind.txt).x end)
                pcall(function()
                    render.text(4, vector(cx - tw / 2, base_y + (i - 1) * 18), ind.col, nil, ind.txt)
                end)
            end
        end

        -- ── VELOCITY WARNING (red pulse when slow-walk or fake-duck needs it) ──
        if vis_velwarn:get() then
            local lp = entity.get_local_player()
            if lp and lp:is_alive() then
                local warn_text = nil
                pcall(function()
                    local v = lp.m_vecVelocity
                    local sp = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
                    -- read NL slow-walk + fake-duck state
                    local sw_on, fd_on = false, false
                    if nl_refs.aa_slowwalk then sw_on = nl_refs.aa_slowwalk:get() == true end
                    if nl_refs.aa_fakeduck then fd_on = nl_refs.aa_fakeduck:get() == true end
                    -- Warn if moving too fast while slow-walk should be active
                    if sw_on and sp > 90 then warn_text = "STOP / SLOW WALK"
                    elseif fd_on and sp > 90 then warn_text = "STOP / FAKE DUCK"
                    end
                end)
                if warn_text then
                    local a = pulse_alpha(VELWARN_PULSE_HZ)
                    local tw = 0
                    pcall(function() tw = render.measure_text(5, nil, warn_text).x end)
                    pcall(function()
                        render.text(5, vector(cx - tw / 2, cy + 40), color(255, 60, 60, a), nil, warn_text)
                    end)
                end
            end
        end

        -- ── V1.6 K: SKEET-STYLE HIT LOG (top-left) ──
        -- format:  > hit NAME in HITBOX for DMG (wanted WANT)
        -- HITBOX gets hitbox-color (head red / chest green / etc), dmg gets damage-tier color
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
                    local hb_id = entry.hitbox_id or -1
                    local hb_r, hb_g, hb_b = 200, 200, 200
                    if hb_id == 0 then hb_r, hb_g, hb_b = 255, 80, 80
                    elseif hb_id == 3 then hb_r, hb_g, hb_b = 120, 220, 120
                    elseif hb_id == 4 then hb_r, hb_g, hb_b = 255, 220, 80
                    elseif hb_id == 6 or hb_id == 7 then hb_r, hb_g, hb_b = 120, 180, 255
                    end
                    local dmg = entry.dmg or 0
                    local dmg_r, dmg_g, dmg_b = 220, 220, 220
                    if dmg >= 100 then dmg_r, dmg_g, dmg_b = 255, 100, 100   -- 1-tap
                    elseif dmg >= 70 then dmg_r, dmg_g, dmg_b = 255, 200, 80
                    elseif dmg >= 40 then dmg_r, dmg_g, dmg_b = 200, 220, 120
                    end
                    -- V1.7 perf: cache measure_text widths on entry first render
                    if not entry._w then
                        entry._w = { name = 0, hb = 0, dmg = 0 }
                        pcall(function() entry._w.name = render.measure_text(3, nil, entry.name or "?").x end)
                        pcall(function() entry._w.hb   = render.measure_text(3, nil, entry.hitbox or "?").x end)
                        pcall(function() entry._w.dmg  = render.measure_text(3, nil, tostring(dmg)).x end)
                    end
                    local nw, hw, dw = entry._w.name, entry._w.hb, entry._w.dmg
                    -- Skeet-style: "> hit NAME in HITBOX for DMG (wanted WANT)"
                    local y = hy + row * 14
                    pcall(function()
                        render.text(3, vector(hx, y), color(160, 160, 160, alpha), nil, ">")
                        render.text(3, vector(hx + 10, y), color(220, 220, 220, alpha), nil, "hit")
                        render.text(3, vector(hx + 30, y), color(180, 220, 255, alpha), nil, entry.name or "?")
                        render.text(3, vector(hx + 34 + nw, y), color(220, 220, 220, alpha), nil, "in")
                        render.text(3, vector(hx + 50 + nw, y), color(hb_r, hb_g, hb_b, alpha), nil, entry.hitbox or "?")
                        render.text(3, vector(hx + 54 + nw + hw, y), color(220, 220, 220, alpha), nil, "for")
                        render.text(3, vector(hx + 74 + nw + hw, y), color(dmg_r, dmg_g, dmg_b, alpha), nil,
                                    tostring(dmg))
                        if entry.dmg_want and entry.dmg_want > dmg then
                            render.text(3, vector(hx + 78 + nw + hw + dw, y),
                                        color(150, 150, 150, alpha), nil,
                                        string.format("(wanted %d)", entry.dmg_want))
                        end
                    end)
                    row = row + 1
                end
            end
        end

        -- ── KEYBINDS PANEL (right-middle, active hotkeys list) ──
        if vis_keybinds:get() then
            local active = {}
            -- V2.1: AI Peek dropped — keybinds panel only shows NL active states
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

        -- ── CLANTAG UPDATE (cheap, throttled inside) ──
        update_clantag()

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
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- QoL — animated clantag, kill-say, auto-accept
-- ══════════════════════════════════════════════════════════════════════════
local clantag_phase = 1
local clantag_last_change = 0

local CLANTAG_FRAMES = {
    wave  = {"Sel01", "sel01", "SEL01", "sel01", "Sel01"},
    spin  = {"Sel01 |", "Sel01 /", "Sel01 -", "Sel01 \\"},
    pulse = {"Sel01", "[Sel01]", "Sel01", "(Sel01)"},
}

update_clantag = function()
    if not (enable_master:get() and qol_clantag:get()) then return end
    local now = globals.realtime or 0
    if now - clantag_last_change < 0.4 then return end
    clantag_last_change = now
    local style = qol_clantag_st:get()
    local frames = CLANTAG_FRAMES.wave
    if style == "Spin"  then frames = CLANTAG_FRAMES.spin
    elseif style == "Pulse" then frames = CLANTAG_FRAMES.pulse
    end
    clantag_phase = (clantag_phase % #frames) + 1
    pcall(function()
        -- Verified API from nyanza snapshot + bloodwings: common.set_clan_tag
        if common and common.set_clan_tag then common.set_clan_tag(frames[clantag_phase]) end
    end)
end

-- clantag updater is invoked from main events.render handler (single set() call).
-- V1.7: dropped unused _clantag_tick_flag sentinel.

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
cs_log_color("══════════════════════════════════════════")
cs_log_color("Sel01-Config v" .. SEL01_CFG_VERSION .. " loaded (CSGO HvH — air-AA improvements: flip + boost + fakeduck)")
cs_log(string.format("  hooks  createmove=%s  aim_fire=%s",
    tostring(_hooks_status.createmove or "MISSING"),
    tostring(_hooks_status.aim_fire or "MISSING")))
cs_log_color("  AA via NL :override path (no cmd writes). Pick preset → Main.")
cs_log_color("══════════════════════════════════════════")
