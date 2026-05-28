-- ╔══════════════════════════════════════════════════╗
-- ║  Sel01-Config — Neverlose CS2 AA + Misc + Visuals║
-- ║  Author: seltonmt01                              ║
-- ║  Version: 1.3                                    ║
-- ╚══════════════════════════════════════════════════╝
-- @name Sel01-Config
-- @author seltonmt01
-- @version 1.3
-- @description Hotfix: NL ui.find popup error. Use pui.find primary + pcall(fn, ...) style + outer pcall block.

local SEL01_CFG_VERSION = "1.3"

local pui = require("neverlose/pui");
local ffi = require("ffi");

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
local btn_legit      = g_main:button("Legit-Bot (minimal AA)",   function() apply_preset_fwd("legit")      end)

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

-- ══════════════════════════════════════════════════════════════════════════
-- MOVEMENT UI
-- ══════════════════════════════════════════════════════════════════════════
g_move:label(accent .. ui.get_icon"running" .. accent .. "  Movement helpers")
local mv_autopeek_k  = g_move:hotkey("Auto-Peek (hold)")
local mv_quickstop_k = g_move:hotkey("Quick-Stop (hold)")
local mv_strafe_help = g_move:switch("Auto-Strafe nudge", true)
local mv_nofall      = g_move:switch("No-Fall damage (auto-duck land)", true)
local mv_fastladder  = g_move:switch("Fast ladder climb", true)

-- ══════════════════════════════════════════════════════════════════════════
-- VISUALS UI
-- ══════════════════════════════════════════════════════════════════════════
g_visual:label(accent .. ui.get_icon"eye" .. accent .. "  Visual additions (single-toggle, no config)")
local vis_watermark  = g_visual:switch("⌚ Watermark (name + FPS + ping)", true)
local vis_indicators = g_visual:switch("⚡ Bottom indicators (AA/DT/HS/BAIM state)", true)
local vis_velwarn    = g_visual:switch("🐢 Velocity warning (pulse when need to slow)", true)
local vis_aaarrows   = g_visual:switch("← → Manual AA arrows (desync side)", true)
local vis_hitmarker  = g_visual:switch("✕ Hit marker (crosshair X + sound)", true)
local vis_hitlog     = g_visual:switch("📜 Hit log (last 5 shots on-screen)", true)
local vis_keybinds   = g_visual:switch("⌨ Keybinds panel (active hotkeys)", true)
local vis_dmgind     = g_visual:switch("💥 Damage popup (floating −X HP on enemy)", true)
local vis_specoverlay= g_visual:switch("👁 Spectator overlay (who watches us)", true)
g_visual:label(" ")
g_visual:label(accent .. "  NL built-in toggles")
local vis_nl_hitsnd  = g_visual:switch("NL Hit Marker Sound", true)
local vis_nl_3rd     = g_visual:switch("Force Thirdperson (NL)", false)
local vis_nl_scope   = g_visual:switch("Scope Overlay (NL)", false)
local vis_nl_selfglw = g_visual:switch("Self-Glow (NL chams)", false)

-- ══════════════════════════════════════════════════════════════════════════
-- QOL UI
-- ══════════════════════════════════════════════════════════════════════════
g_qol:label(accent .. ui.get_icon"sparkles" .. accent .. "  Quality of Life")
local qol_clantag    = g_qol:switch("Animated clantag (Sel01 cycle)", false)
local qol_clantag_st = g_qol:combo("Clantag style", {"Wave", "Spin", "Pulse"}, 1)
local qol_killsay    = g_qol:switch("Kill-say rotation (chat on kill)", false)
local qol_killsay_t  = g_qol:combo("Kill-say theme", {"Memes", "Tilt", "Polite", "Sel01 brand"}, 4)
local qol_autoaccept = g_qol:switch("Auto-accept match", true)
local qol_buybot     = g_qol:switch("Auto-buy on spawn (AK + armor)", false)

-- ══════════════════════════════════════════════════════════════════════════
-- INFO UI
-- ══════════════════════════════════════════════════════════════════════════
local btn_status = g_info:button("📋 Print Status", function() end) -- callback wired later
local btn_reset  = g_info:button("🔄 Reset Settings (defaults)", function() end)
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

-- :override(value) is NON-DESTRUCTIVE — value resets when script unloads / no-arg call.
-- :set(value) (and ui.set) is DESTRUCTIVE — overwrites user's manual UI permanently.
-- Always prefer override for runtime writes.
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
    nl_refs.rage_hc          = nl_find_safe("Aimbot", "Ragebot", "Selection", "Hit Chance")
    nl_refs.rage_mindmg      = nl_find_safe("Aimbot", "Ragebot", "Selection", "Min. Damage")
    nl_refs.rage_autowall    = nl_find_safe("Aimbot", "Ragebot", "Selection", "Penetrate Walls")
    nl_refs.rage_bodyaim     = nl_find_safe("Aimbot", "Ragebot", "Safety", "Body Aim")
    nl_refs.rage_safepoint   = nl_find_safe("Aimbot", "Ragebot", "Safety", "Safe Points")
    nl_refs.rage_hitsafety   = nl_find_safe("Aimbot", "Ragebot", "Safety", "Ensure Hitbox Safety")
    nl_refs.rage_autoscope   = nl_find_safe("Aimbot", "Ragebot", "Accuracy", "Auto Scope")
    -- Visuals
    nl_refs.vis_thirdperson  = nl_find_safe("Visuals", "World", "Main", "Force Thirdperson")
    nl_refs.vis_scope_ovl    = nl_find_safe("Visuals", "World", "Main", "Override Zoom", "Scope Overlay")
    nl_refs.vis_viewmodel    = nl_find_safe("Visuals", "World", "Main", "Override Zoom", "Force Viewmodel")
    nl_refs.vis_removals     = nl_find_safe("Visuals", "World", "Main", "Removals")
    nl_refs.vis_hitmark_snd  = nl_find_safe("Visuals", "World", "Other", "Hit Marker Sound")
    nl_refs.vis_self_chams   = nl_find_safe("Visuals", "Players", "Self", "Chams", "Weapon")
    nl_refs.vis_self_glow    = nl_find_safe("Visuals", "Players", "Self", "Chams", "Glow")
end)  -- outer pcall

-- ══════════════════════════════════════════════════════════════════════════
-- PRESETS
-- ══════════════════════════════════════════════════════════════════════════
local function apply_preset(name)
    if name == "aggressive" then
        -- AA: max desync, jitter, backward base
        safe_set(aa_enable, true)
        safe_set(aa_pitch, 2)           -- Down
        safe_set(aa_yaw_base, 2)        -- Backward
        safe_set(aa_yaw_add, 0)
        safe_set(aa_yaw_mod, 5)         -- Jitter
        safe_set(aa_yaw_mod_mag, 45)
        safe_set(aa_yaw_mod_int, 2)
        safe_set(aa_desync, 58)
        safe_set(aa_desync_side, 1)     -- Auto
        safe_set(aa_freestanding, true)
        safe_set(aa_at_targets, false)
        -- Movement: peek + strafe nudge ON
        safe_set(mv_strafe_help, true)
        -- Visuals: full set
        safe_set(vis_watermark, true)
        safe_set(vis_indicators, true)
        safe_set(vis_velwarn, true)
        safe_set(vis_aaarrows, true)
        safe_set(vis_hitmarker, true)
        safe_set(vis_hitlog, true)
        safe_set(vis_keybinds, true)
        safe_set(vis_dmgind, true)
        safe_set(vis_specoverlay, true)
        safe_set(mv_nofall, true)
        safe_set(mv_fastladder, true)
        -- QoL: brand + auto-accept
        safe_set(qol_clantag, true)
        safe_set(qol_clantag_st, 1)
        safe_set(qol_killsay, false)
        safe_set(qol_autoaccept, true)
        -- NL :override() writes (non-destructive — clears on script unload)
        nl_override(nl_refs.aa_enabled, true)
        nl_override(nl_refs.aa_yaw_base, "Backward")
        nl_override(nl_refs.aa_yaw_offset, 0)
        nl_override(nl_refs.aa_yawmod, "Jitter")
        nl_override(nl_refs.aa_yawmod_offset, 45)
        nl_override(nl_refs.aa_bodyyaw, "Static")
        nl_override(nl_refs.aa_bodyyaw_l, 58)
        nl_override(nl_refs.aa_bodyyaw_r, 58)
        nl_override(nl_refs.aa_freestand, true)
        nl_override(nl_refs.aa_avoidbackstab, true)
        nl_override(nl_refs.fl_switch, true)
        nl_override(nl_refs.fl_limit, 7)
        nl_override(nl_refs.fl_variability, 2)
        nl_override(nl_refs.vis_hitmark_snd, true)
        cs_log_color("⚡ AGGRESSIVE preset applied (full-send AA + visuals)")
    elseif name == "dynamic" then
        safe_set(aa_enable, true)
        safe_set(aa_pitch, 2)
        safe_set(aa_yaw_base, 2)
        safe_set(aa_yaw_mod, 5)
        safe_set(aa_yaw_mod_mag, 28)
        safe_set(aa_yaw_mod_int, 3)
        safe_set(aa_desync, 45)
        safe_set(aa_desync_side, 1)
        safe_set(aa_freestanding, true)
        safe_set(aa_at_targets, true)   -- at-target = better aimpoint
        safe_set(vis_watermark, true)
        safe_set(vis_indicators, true)
        safe_set(vis_velwarn, true)
        safe_set(vis_aaarrows, true)
        safe_set(vis_hitmarker, true)
        safe_set(vis_hitlog, true)
        safe_set(vis_keybinds, true)
        safe_set(vis_dmgind, true)
        safe_set(vis_specoverlay, true)
        safe_set(mv_nofall, true)
        safe_set(qol_clantag, true)
        safe_set(qol_clantag_st, 2)
        safe_set(qol_autoaccept, true)
        nl_override(nl_refs.aa_enabled, true)
        nl_override(nl_refs.aa_yaw_base, "Backward")
        nl_override(nl_refs.aa_yawmod, "Center")
        nl_override(nl_refs.aa_bodyyaw, "Jitter")
        nl_override(nl_refs.aa_bodyyaw_l, 45)
        nl_override(nl_refs.aa_bodyyaw_r, 45)
        nl_override(nl_refs.aa_freestand, true)
        nl_override(nl_refs.fl_switch, true)
        nl_override(nl_refs.fl_limit, 5)
        nl_override(nl_refs.vis_hitmark_snd, true)
        cs_log_color("🎯 DYNAMIC preset applied (balanced AA + visuals)")
    elseif name == "defensive" then
        safe_set(aa_enable, true)
        safe_set(aa_pitch, 2)
        safe_set(aa_yaw_base, 2)
        safe_set(aa_yaw_mod, 3)         -- Offset (smaller jitter)
        safe_set(aa_yaw_mod_mag, 15)
        safe_set(aa_yaw_mod_int, 4)
        safe_set(aa_desync, 35)
        safe_set(aa_desync_side, 1)
        safe_set(aa_freestanding, true)
        safe_set(aa_at_targets, false)
        safe_set(vis_watermark, true)
        safe_set(vis_indicators, true)
        safe_set(vis_velwarn, true)
        safe_set(vis_aaarrows, true)
        safe_set(vis_hitmarker, true)
        safe_set(vis_hitlog, false)     -- less clutter
        safe_set(vis_keybinds, true)
        safe_set(vis_dmgind, false)     -- less screen clutter
        safe_set(vis_specoverlay, true)
        safe_set(mv_nofall, true)
        safe_set(qol_clantag, false)
        safe_set(qol_autoaccept, true)
        nl_override(nl_refs.aa_enabled, true)
        nl_override(nl_refs.aa_yaw_base, "Backward")
        nl_override(nl_refs.aa_yawmod, "Offset")
        nl_override(nl_refs.aa_yawmod_offset, 15)
        nl_override(nl_refs.aa_bodyyaw, "Static")
        nl_override(nl_refs.aa_bodyyaw_l, 35)
        nl_override(nl_refs.aa_bodyyaw_r, 35)
        nl_override(nl_refs.aa_freestand, true)
        nl_override(nl_refs.fl_switch, true)
        nl_override(nl_refs.fl_limit, 3)
        nl_override(nl_refs.vis_hitmark_snd, true)
        cs_log_color("🛡 DEFENSIVE preset applied (safe AA, minimal visuals)")
    elseif name == "legit" then
        safe_set(aa_enable, false)      -- legit = NO custom AA
        safe_set(aa_pitch, 1)           -- Off
        safe_set(aa_yaw_mod, 1)         -- None
        safe_set(vis_watermark, true)
        safe_set(vis_indicators, false)  -- legit = minimal
        safe_set(vis_velwarn, false)
        safe_set(vis_aaarrows, false)
        safe_set(vis_hitmarker, true)
        safe_set(vis_hitlog, false)
        safe_set(vis_keybinds, false)
        safe_set(vis_dmgind, false)
        safe_set(vis_specoverlay, false)
        safe_set(mv_nofall, false)
        safe_set(mv_fastladder, false)
        safe_set(qol_clantag, false)
        safe_set(qol_killsay, false)
        nl_override(nl_refs.aa_enabled, false)
        nl_override(nl_refs.aa_freestand, false)
        nl_override(nl_refs.fl_switch, false)
        cs_log_color("👤 LEGIT-BOT preset applied (AA off, minimal visuals)")
    end
end
apply_preset_fwd = apply_preset  -- resolve forward-decl

-- ══════════════════════════════════════════════════════════════════════════
-- ANTI-AIM EVENT HOOK
-- NL exposes events.antiaim (signature varies). Best-effort write to cmd
-- (pitch, yaw_base, yaw_add, yaw_modifier, jitter, desync). All pcall.
-- ══════════════════════════════════════════════════════════════════════════
local aa_jitter_counter = 0
local aa_jitter_dir = 1
local function aa_handler(cmd)
    if not (enable_master:get() and aa_enable:get()) then return end
    if not cmd then return end
    pcall(function()
        -- Pitch
        local pmode = aa_pitch:get()
        if pmode == "Down"             then cmd.pitch = -89
        elseif pmode == "Up"           then cmd.pitch =  89
        elseif pmode == "Jitter Down/Up" then
            aa_jitter_counter = aa_jitter_counter + 1
            cmd.pitch = (aa_jitter_counter % 2 == 0) and -89 or 89
        elseif pmode == "Custom"       then cmd.pitch = aa_pitch_cust:get()
        end
        -- Yaw base
        local ybase = aa_yaw_base:get()
        if ybase == "Forward"  then cmd.yaw_base = 0
        elseif ybase == "Backward" then cmd.yaw_base = 180
        elseif ybase == "Left"     then cmd.yaw_base = 90
        elseif ybase == "Right"    then cmd.yaw_base = -90
        elseif ybase == "AtTarget" and aa_at_targets:get() then
            cmd.yaw_base_at_targets = true
        end
        -- Yaw add
        cmd.yaw_add = (cmd.yaw_add or 0) + aa_yaw_add:get()
        -- Yaw modifier
        local ymod = aa_yaw_mod:get()
        if ymod == "Center" then
            cmd.yaw_modifier = 0
        elseif ymod == "Offset" then
            cmd.yaw_modifier = aa_yaw_mod_mag:get()
        elseif ymod == "Random" then
            cmd.yaw_modifier = (math.random() * 2 - 1) * aa_yaw_mod_mag:get()
        elseif ymod == "Jitter" then
            aa_jitter_counter = aa_jitter_counter + 1
            local int = math.max(1, aa_yaw_mod_int:get())
            if aa_jitter_counter % int == 0 then aa_jitter_dir = -aa_jitter_dir end
            cmd.yaw_modifier = aa_jitter_dir * aa_yaw_mod_mag:get()
        end
        -- Desync
        local dval = aa_desync:get()
        cmd.desync_range = dval
        local dside = aa_desync_side:get()
        if dside == "Left"   then cmd.desync_side = -1
        elseif dside == "Right"  then cmd.desync_side = 1
        elseif dside == "Random" then cmd.desync_side = (math.random(0,1) == 0) and -1 or 1
        else cmd.desync_side = (math.floor(aa_jitter_counter / 4) % 2 == 0) and -1 or 1
        end
        -- Freestanding
        cmd.freestanding = aa_freestanding:get()
    end)
end

pcall(function() events.antiaim:set(aa_handler) end)
pcall(function() events.anti_aim:set(aa_handler) end)
pcall(function() events.aa:set(aa_handler) end)

-- ══════════════════════════════════════════════════════════════════════════
-- MOVEMENT — auto-peek, quick-stop, strafe nudge
-- ══════════════════════════════════════════════════════════════════════════
local autopeek_state = { active = false, origin = nil, peek_dir = 0 }

local function createmove_handler(cmd)
    if not (enable_master:get() and cmd) then return end
    pcall(function()
        local lp = entity.get_local_player()
        if not lp or not lp:is_alive() then return end

        -- Auto-strafe nudge (createmove side-correct via velocity direction)
        if mv_strafe_help and mv_strafe_help:get() then
            local v = lp.m_vecVelocity
            local vx, vy = v.x or 0, v.y or 0
            local sp2 = math.sqrt(vx*vx + vy*vy)
            if sp2 > 30 and (lp.m_fFlags and bit.band(lp.m_fFlags, 1) == 0) then
                -- airborne with horizontal velocity → bias sidemove toward velocity direction
                local yaw_rad = math.rad(cmd.yaw or 0)
                local fx, fy = math.cos(yaw_rad), math.sin(yaw_rad)
                -- cross-product sign tells which side velocity is on relative to view
                local cross = fx * vy - fy * vx
                if cross > 0 then cmd.sidemove = 450 else cmd.sidemove = -450 end
            end
        end

        -- Quick-stop: when hotkey held, force forwardmove/sidemove = 0 + emulate slow-walk
        if mv_quickstop_k and mv_quickstop_k:get() then
            cmd.forwardmove = 0
            cmd.sidemove    = 0
        end

        -- NO-FALL: when airborne with downward velocity > -300, send +DUCK to soften landing
        if mv_nofall and mv_nofall:get() then
            local flags = lp.m_fFlags or 0
            local airborne = bit.band(flags, 1) == 0
            if airborne then
                local vz = (lp.m_vecVelocity and lp.m_vecVelocity.z) or 0
                if vz < -300 then
                    -- IN_DUCK = 4 (PlayerCommand button-bit). Adding via cmd.buttons OR.
                    pcall(function() cmd.buttons = bit.bor(cmd.buttons or 0, 4) end)
                end
            end
        end

        -- FAST-LADDER: when on ladder (move_type == 9 LADDER) + jumping input, force +JUMP off
        if mv_fastladder and mv_fastladder:get() then
            pcall(function()
                local mt = lp.m_MoveType or 0
                -- MOVETYPE_LADDER = 9
                if mt == 9 then
                    -- alternate jump bit each tick for speedier ladder climb
                    if (globals.tickcount or 0) % 2 == 0 then
                        cmd.buttons = bit.bor(cmd.buttons or 0, 2)  -- IN_JUMP
                    else
                        cmd.buttons = bit.band(cmd.buttons or 0, bit.bnot(2))
                    end
                end
            end)
        end

        -- Auto-peek: record origin on key-down, move toward last-known-target offset
        local peek_pressed = mv_autopeek_k and mv_autopeek_k:get()
        if peek_pressed then
            if not autopeek_state.active then
                autopeek_state.active = true
                autopeek_state.origin = { x = lp.m_vecOrigin.x, y = lp.m_vecOrigin.y, z = lp.m_vecOrigin.z }
                autopeek_state.peek_dir = (math.random(0,1) == 0) and -1 or 1
            end
            -- nudge sidemove toward peek-side
            cmd.sidemove = 450 * autopeek_state.peek_dir
        elseif autopeek_state.active then
            -- return to origin
            local ox, oy = autopeek_state.origin.x, autopeek_state.origin.y
            local dx, dy = ox - lp.m_vecOrigin.x, oy - lp.m_vecOrigin.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < 30 then
                autopeek_state.active = false
                autopeek_state.origin = nil
            else
                local yaw_rad = math.rad(cmd.yaw or 0)
                local fx, fy = math.cos(yaw_rad), math.sin(yaw_rad)
                local dot   = (dx * fx + dy * fy)
                local cross = (dx * fy - dy * fx) * -1
                local move_norm = math.max(dist, 1)
                cmd.forwardmove = 450 * (dot / move_norm)
                cmd.sidemove    = 450 * (cross / move_norm)
            end
        end
    end)
end

-- Single createmove handler that runs movement + NL-visual override sync
local function createmove_unified(cmd)
    createmove_handler(cmd)
    if enable_master:get() then
        nl_override(nl_refs.vis_hitmark_snd, vis_nl_hitsnd:get())
        nl_override(nl_refs.vis_thirdperson, vis_nl_3rd:get())
        nl_override(nl_refs.vis_scope_ovl,   vis_nl_scope:get())
        if vis_nl_selfglw:get() then
            nl_override(nl_refs.vis_self_glow, true)
        end
    end
end
pcall(function() events.createmove:set(createmove_unified) end)
pcall(function() events.setup_command:set(createmove_unified) end)

-- ══════════════════════════════════════════════════════════════════════════
-- VISUALS — hit-marker + damage indicator + perf HUD + spectator overlay
-- ══════════════════════════════════════════════════════════════════════════
local hit_events  = {}   -- {time, dmg, origin, hp_left, hit_idx}
local damage_pops = {}   -- floating "−X HP" entries
local hitmark_time = 0
local hitmark_dmg  = 0

-- Forward-decl: update_clantag is defined further down but referenced inside the
-- events.render closure created below. NL UI callbacks capture upvalues at parse-
-- time — without this forward-decl the closure would bind to a global of the same
-- name (nil at call-time).
local update_clantag = function() end

-- Aim_ack — hit-marker trigger
pcall(function()
    events.aim_ack:set(function(event)
        if not (enable_master:get() and vis_hitmarker:get()) then return end
        if not event then return end
        local reason = event.state
        local HIT_STATES = { hit = true, damaged = true, ["hit-damaged"] = true }
        if reason and HIT_STATES[reason] then
            hitmark_time = globals.realtime or 0
            hitmark_dmg  = event.damage or 0
            -- HIT-LOG push: name + dmg + hitbox
            if vis_hitlog:get() then
                local target_name = "?"
                local hb_name     = "?"
                pcall(function()
                    if event.target then
                        local t = entity.get(event.target, true)
                        if t and t.get_name then target_name = t:get_name() end
                    end
                end)
                pcall(function()
                    local HB_NAMES = { [0]="head", [3]="chest", [4]="stomach",
                                       [6]="leg", [7]="leg" }
                    hb_name = HB_NAMES[event.hitbox] or tostring(event.hitbox or "?")
                end)
                table.insert(hit_log, {
                    time   = globals.realtime or 0,
                    name   = target_name,
                    dmg    = event.damage or 0,
                    hitbox = hb_name,
                })
                while #hit_log > HIT_LOG_MAX do table.remove(hit_log, 1) end
            end
        end
    end)
end)

-- Player hurt event — damage indicator floating text on enemy
pcall(function()
    events.player_hurt:set(function(event)
        if not (enable_master:get() and vis_dmgind:get()) then return end
        if not event then return end
        local lp = entity.get_local_player()
        if not lp then return end
        local attacker = entity.get(event.attacker, true)
        local victim   = entity.get(event.userid,   true)
        if not attacker or attacker ~= lp then return end
        if not victim or victim == lp then return end
        local ox, oy, oz = 0, 0, 0
        pcall(function()
            ox = victim.m_vecOrigin.x
            oy = victim.m_vecOrigin.y
            oz = victim.m_vecOrigin.z + 70
        end)
        table.insert(damage_pops, {
            time = globals.realtime or 0,
            dmg  = event.dmg_health or event.damage or 0,
            x = ox, y = oy, z = oz,
            hp_left = event.health or 0,
        })
        -- prune to last 16 entries
        while #damage_pops > 16 do table.remove(damage_pops, 1) end
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
    pcall(function()
        local lp_idx = lp:get_index()
        for i = 1, 64 do
            local p = entity.get(i, false)
            if p and not p:is_alive() and p ~= lp then
                local target_obs
                pcall(function()
                    -- m_hObserverTarget is a handle, NL may expose differently
                    target_obs = p.m_hObserverTarget
                end)
                if target_obs then
                    local watching = entity.get(target_obs, true)
                    if watching and watching == lp then
                        local name
                        pcall(function() name = p:get_name() end)
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

        -- ── MANUAL AA ARROWS (left + right desync side at crosshair) ──
        if vis_aaarrows:get() then
            local lp = entity.get_local_player()
            if lp and lp:is_alive() then
                -- read current desync side from NL bodyyaw inverter if available,
                -- else fall back to our own aa_jitter_dir
                local side = aa_jitter_dir or 1
                pcall(function()
                    if nl_refs.aa_bodyyaw_inv then
                        local v = nl_refs.aa_bodyyaw_inv:get()
                        if type(v) == "boolean" then side = v and -1 or 1 end
                    end
                end)
                local lcol = (side < 0) and color(255, 230, 80, 255) or color(60, 60, 60, 140)
                local rcol = (side > 0) and color(255, 230, 80, 255) or color(60, 60, 60, 140)
                pcall(function()
                    render.text(4, vector(cx - 22, cy - 6), lcol, nil, "<")
                    render.text(4, vector(cx + 14, cy - 6), rcol, nil, ">")
                end)
            end
        end

        -- ── DAMAGE POPUPS (floating −X HP near victim, fade upward) ──
        if vis_dmgind:get() then
            for i = #damage_pops, 1, -1 do
                local pop = damage_pops[i]
                local age = now - pop.time
                if age > DMGPOP_DURATION_S then
                    table.remove(damage_pops, i)
                else
                    local alpha = math.floor(255 * (1 - age / DMGPOP_DURATION_S))
                    local yoff  = age * 30
                    pcall(function()
                        local p2d = render.world_to_screen(vector(pop.x, pop.y, pop.z))
                        if p2d and p2d.x and p2d.x > 0 and p2d.y > 0 then
                            render.text(4, vector(p2d.x + 6, p2d.y - yoff),
                                        color(255, 200, 80, alpha), nil,
                                        string.format("-%d HP", pop.dmg))
                            if pop.hp_left > 0 then
                                render.text(3, vector(p2d.x + 6, p2d.y - yoff + 14),
                                            color(180, 180, 180, alpha), nil,
                                            string.format("(%d hp)", pop.hp_left))
                            end
                        end
                    end)
                end
            end
        end

        -- ── WATERMARK (top-right: user + FPS + ping + version) ──
        if vis_watermark:get() then
            local lp_name = common and common.get_username and common.get_username() or "Player"
            local txt = string.format("Sel01 | %s | %d fps | %d ms", lp_name, perf.fps, perf.ping)
            local tw = 0
            pcall(function() tw = render.measure_text(3, nil, txt).x end)
            local pad = 8
            local wx, wy = sx - tw - pad * 2 - 12, 12
            pcall(function()
                render.rect(vector(wx, wy), vector(wx + tw + pad * 2, wy + 22), color(15, 15, 20, 200))
                render.rect_outline(vector(wx, wy), vector(wx + tw + pad * 2, wy + 22), color(120, 180, 255, 220), 1)
                render.text(3, vector(wx + pad, wy + 5), color(220, 230, 255, 255), nil, txt)
            end)
        end

        -- ── BOTTOM STATE INDICATORS (DT/HS/BAIM/AA/FREE) ──
        if vis_indicators:get() then
            local indicators = {}
            -- AA enabled
            local aa_on = aa_enable:get()
            if aa_on then table.insert(indicators, {txt = "AA",   col = color(120, 220, 120, 255)}) end
            -- Double Tap (NL)
            pcall(function()
                if nl_refs.rage_dt and nl_refs.rage_dt:get() then
                    table.insert(indicators, {txt = "DT", col = color(255, 100, 100, 255)})
                end
            end)
            -- Hide Shots (NL)
            pcall(function()
                if nl_refs.rage_hide and nl_refs.rage_hide:get() then
                    table.insert(indicators, {txt = "HS", col = color(255, 180, 80, 255)})
                end
            end)
            -- Freestanding
            if aa_on and aa_freestanding:get() then
                table.insert(indicators, {txt = "FREE", col = color(180, 200, 255, 255)})
            end
            -- Slow Walk (NL)
            pcall(function()
                if nl_refs.aa_slowwalk and nl_refs.aa_slowwalk:get() then
                    table.insert(indicators, {txt = "SW", col = color(255, 220, 120, 255)})
                end
            end)
            -- Fake Duck (NL)
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

        -- ── HIT LOG (top-left, last 5 shots, fade) ──
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
                    local txt = string.format("HIT %s  %d dmg  [%s]",
                                              entry.name or "?", entry.dmg or 0, entry.hitbox or "?")
                    pcall(function()
                        render.text(3, vector(hx, hy + row * 14), color(160, 255, 160, alpha), nil, txt)
                    end)
                    row = row + 1
                end
            end
        end

        -- ── KEYBINDS PANEL (right-middle, active hotkeys list) ──
        if vis_keybinds:get() then
            local active = {}
            pcall(function()
                if mv_autopeek_k and mv_autopeek_k:get() then table.insert(active, "Auto-Peek") end
            end)
            pcall(function()
                if mv_quickstop_k and mv_quickstop_k:get() then table.insert(active, "Quick-Stop") end
            end)
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
    wave  = {"Sel01", "≥el01", "S≥l01", "Se≥01", "Sel≥1", "Sel0≥", "Sel01"},
    spin  = {"|Sel01", "/Sel01", "—Sel01", "\\Sel01"},
    pulse = {"Sel01", "[Sel01]", "{Sel01}", "[Sel01]"},
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

-- clantag updater is invoked from main events.render handler (which is registered
-- above with a single set() call — registering twice would overwrite the first hook).
-- We patch the existing render closure indirectly via a per-tick flag.
local _clantag_tick_flag = true   -- always-true sentinel; update_clantag is gated by master+toggle inside

-- (master-disable handler unified later in shutdown section — clears clantag + overrides)

-- ── KILL-SAY rotation (chat) ──
local KILL_LINES = {
    memes  = {"ez", "skill issue", "gg", "next?", "+rep"},
    tilt   = {"who?", "and who are you?", "yikes", "delete cs", "uninstall"},
    polite = {"gg wp", "well played", "good fight", "respect", "rematch?"},
    sel01  = {"Sel01 says hi", "powered by Sel01-Solver", "resolved.", "Sel01 → ★", "Sel01 brand kill"},
}

pcall(function()
    events.player_death:set(function(event)
        if not (enable_master:get() and qol_killsay:get()) then return end
        if not event then return end
        local lp = entity.get_local_player()
        if not lp then return end
        local attacker = entity.get(event.attacker, true)
        if attacker ~= lp then return end
        local victim   = entity.get(event.userid, true)
        if not victim or victim == lp then return end
        local theme = qol_killsay_t:get()
        local pool = KILL_LINES.sel01
        if theme == "Memes"  then pool = KILL_LINES.memes
        elseif theme == "Tilt"   then pool = KILL_LINES.tilt
        elseif theme == "Polite" then pool = KILL_LINES.polite
        end
        local msg = pool[math.random(1, #pool)]
        pcall(function() client.exec(string.format('say "%s"', msg)) end)
    end)
end)

-- ── AUTO-ACCEPT match ──
pcall(function()
    if events.match_state then
        events.match_state:set(function()
            if qol_autoaccept:get() then
                pcall(function() client.exec("matchmaking_session_accept") end)
            end
        end)
    end
end)
pcall(function()
    if events.matchmaking then
        events.matchmaking:set(function()
            if qol_autoaccept:get() then
                pcall(function() client.exec("matchmaking_session_accept") end)
            end
        end)
    end
end)

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
    cs_log(string.format("QoL: clantag=%s killsay=%s autoaccept=%s",
        tostring(qol_clantag:get()), tostring(qol_killsay:get()),
        tostring(qol_autoaccept:get())))
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
cs_log_color("Sel01-Config v" .. SEL01_CFG_VERSION .. " loaded")
cs_log_color("Companion to Sel01-Solver — handles AA + Misc + Visuals + QoL")
cs_log_color("Pick a preset under Sel01-Config → Main")
cs_log_color("══════════════════════════════════════════")
