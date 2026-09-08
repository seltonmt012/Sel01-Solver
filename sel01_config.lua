-- ╔══════════════════════════════════════════════════╗
-- ║  Sel01-Config — Neverlose CSGO HvH config        ║
-- ║  Author: seltonmt01                              ║
-- ║  Version: 5.0                                    ║
-- ╚══════════════════════════════════════════════════╝
-- @name Sel01-Config
-- @author seltonmt01
-- @version 5.0
-- @description v5.0 META REWORK (best-of from 10 current NL luas: elysian, Andromeda,
--   evalate 2, spectral/everlast, nexus, gazolina, arc, DEMONTIME) + new Misc tab:
--   * Presets are now REAL meta configs with decoded values: Nyanza Snapshot (default),
--     Aggressive xo-yaw, Unrivaled xo-yaw, Sata chaos, Everlast Author, Spin, Troll.
--     Asymmetric L/R real-yaw offsets (-25/+40 style), 58/58 body, side switch as a
--     SEQUENCE of un-choked sends ([5,5,2,2,20]) or per-side ranges, Bobrinho 6-step
--     modifier, body "Ticks" pulses, Switch A/B limits, per-state Yaw Base.
--   * Defensive: choke tables (Fixed / Random lo..hi / Sequence [6,22,19,11,16,6]),
--     Hide Shots option override (Break LC), defensive on weapon switch / reload,
--     pause after the ragebot fires, air modes (gingersense / evalate / elysian),
--     fix-recharge-delay, fake-lag disablers (DT / HS / standing). Hidden angles got
--     8 pitch + 9 yaw modes (elysian wave, progressive, povorotniki, sweep, ...).
--   * Safe Head (knife / zeus / air-crouch / height advantage: tiny limits, At Target),
--     Freestanding key + static body yaw, Manual Backward + base, Legit AA on +use,
--     Warmup AA modes (Spin / Distortion / L-R), Edge Yaw, anti-bruteforce modes
--     (Meta / Increase / Decrease / Random phases) + inverter Freeze.
--   * NEW Misc tab: fast ladder, no fall damage, unlock fake-duck speed, edge stop,
--     jump scout, auto hide shots, unlock fake latency, FPS optimizer, warmup config,
--     viewmodel, aspect ratio, kill say (5 styles + revenge), custom clantag text,
--     animation breaker (move lean / leg breaker / landing pitch, FFI, off by default).
--   * Visuals: NL keybinds list (ui.get_binds), arrow styles (Classic / Modern /
--     Triangles), DT charge ring, desync bar, min-damage indicator, fake-lag line,
--     watermark position, left-edge side indicators (skeet style, off by default).
-- @description-prev v4.2 bindable switches instead of hotkeys:
--   * AI Peek trigger = one "active" switch (bind it in NL, hold or toggle) — the
--     v4.1 trigger combo + hotkey are gone. Manual Left/Right/Forward and Force
--     defensive are switches too. NL can bind any switch, no script hotkeys needed.
--   * AI Peek reset every tick in v4.1 because the "manual movement" pause read
--     cmd.forwardmove/sidemove, which NL itself writes (auto-stop / peek assist).
--     It now reads the button bits (in_forward / in_back / in_moveleft / in_moveright).
-- @description-prev v4.1 AI PEEK REWRITE + first-dump fixes:
--   * AI Peek now holds an anchor and only steps out when utils.trace_bullet from a
--     candidate peek position (perpendicular to the threat, wall-traced, eye height)
--     would deal NL Min. Damage - 5 to an enemy hitbox (aiPeek_61044 algorithm).
--     Quick-stop on the point, retreat on events.aim_fire, exposure timeout, DT
--     teleport back, "hittable from cover → don't move" (angelwings). The v3.28
--     version waited for aim_fire (= already exposed) and ran TOWARD the enemy.
--   * Crouching / Crouch-Move get their own state rows in the defaults + presets
--     (first dump: 6/11 hits taken in Crouch-Move on the Global rows).
--   * Copy dump: [NL] line shows EFFECTIVE (override) values, menu values separately,
--     [AIPEEK] line, timeline no longer floods stand↔move flicker, new hints
--     (hits during active defensive, hits on Global rows, one-tap lobby).
-- @description-prev v4.0 FULL ANTI-AIM REWORK (per-state engine + defensive + copy-logs):
--   * The v3 "presets" only wrote Body Yaw limits / inverter noise; Pitch, Yaw Base,
--     Yaw Modifier and Jitter combos in the menu were decorative and the yaw-base
--     rotation wrote invalid option strings (Base takes "At Target"/"Local View").
--     Everything the enemy saw came from the user's NL config.
--   * New per-state builder (Global / Standing / Moving / Slow-Walk / Crouching /
--     Crouch-Move / Air / Air-Crouch): yaw offset L/R, jitter mode (Static / Center /
--     Offset / Random / 3-Way / 5-Way / Spin), randomization, body-yaw mode + fixed /
--     random / bimodal magnitude, side-switch timing in UN-CHOKED sends, freestanding,
--     defensive mode and fake-lag limit per state. Manual L/R/F hotkeys.
--   * Defensive AA on this build: cmd.force_defensive pulses while NL Double Tap is
--     charged (rage.exploit:get() == 1), "On threat" / "Always" / hotkey, optional
--     record-cleaning yaw after a discharge, DT Lag Options auto "Always On", air-lag.
--   * Anti-bruteforce: events.bullet_impact near-miss (point-to-shot-line distance)
--     per shooter → side flip + random fake limit + random switch delay for N seconds.
--     Hit taken → side flip + defensive burst + freestanding off.
--   * 📋 Copy Last Logs (Info tab): hits-taken with FULL engine snapshot (state, side,
--     written yaw / limits, defensive, DT charge, choke, threat, distance, weapon),
--     attacker table, near-miss + reaction + state timeline, NL live values and
--     auto-hints. FFI clipboard + nl/Sel01-Config/last_logs.txt fallback.
-- @description-prev AI Peek hittable-gate (only peek when min-dmg shot exists):
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

local SEL01_CFG_VERSION = "5.0"

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
local T_MISC = ui.get_icon"puzzle-piece" .. "  Misc"   -- v5.0
-- v5.0 menu restyle (Andromeda / elysian / evalate look): group titles carry an icon, and
-- EVERY element name is rewritten by the `styled()` wrapper below — main rows get an accent
-- bullet, sub rows ("  └ ...") a dimmed "›", per-state rows an accent-colored [TAG]. The
-- wrapper returns the real NL element, so :get / :set / :tooltip / :visibility all work.
-- (Renaming re-keys the elements once; click a preset after the first reload.)
local function gi(icon, name) return ui.get_icon(icon) .. "  " .. name end
local function styled(group)
    local DIM = "\aA0A6B4FF"
    local function restyle(name)
        if type(name) ~= "string" then return name end
        if name == " " or name == "" then return name end
        if name:sub(1, 1) == "\a" then return name end                       -- already colored (headers, accent switches)
        if name:sub(1, 2) == "##" then return name end                        -- hidden / keyed elements
        local tag = name:match("^%[(%u+)%] ")
        if tag then return "\a{Link Active}" .. tag .. "\aDEFAULT  " .. name:sub(#tag + 4) end
        local sub2 = name:match("^      (.+)$")                                -- 2nd-level row
        if sub2 then return DIM .. "        ›  " .. sub2 end
        local sub = name:match("^  └ (.+)$")                                   -- sub row
        if sub then return DIM .. "    ›  " .. sub end
        return "\a{Link Active}•\aDEFAULT  " .. name
    end
    local P = {}
    return setmetatable(P, { __index = function(_, k)
        local f = group[k]
        if type(f) ~= "function" then return f end
        -- labels, buttons and lists keep their text (buttons are icon / alt style, lists are "##" keyed)
        if k == "label" or k == "button" or k == "list" or k == "listable" then return function(_, name, ...) return f(group, name, ...) end end
        return function(_, name, ...) return f(group, restyle(name), ...) end
    end })
end
local g_main    = styled(ui.create(T_MAIN, gi("floppy-disk", "Configs"), 1))
local g_presets = styled(ui.create(T_MAIN, gi("sliders", "Presets"), 1))
local g_about   = styled(ui.create(T_MAIN, gi("sparkles", "Sel01-Config"), 2))
local g_qol     = styled(ui.create(T_MAIN, gi("tag", "Quality of Life"), 2))
local g_info    = styled(ui.create(T_MAIN, gi("circle-info", "Info & Logs"), 2))
local g_aa      = styled(ui.create(T_AA,   gi("shield", "Anti-Aim"), 1))
local g_aa_st   = styled(ui.create(T_AA,   gi("hammer", "State Builder"), 1))
local g_aa_def  = styled(ui.create(T_AA,   gi("bolt", "Defensive & Exploit"), 2))
local g_aa_rx   = styled(ui.create(T_AA,   gi("shield-halved", "Anti-Bruteforce & Reactions"), 2))
local g_aa_sh   = styled(ui.create(T_AA,   gi("helmet-safety", "Safe Head / Freestanding / Legit"), 2))
local g_aa_hs   = styled(ui.create(T_AA,   gi("skull", "Anti-Headshot extras"), 2))
local g_visual  = styled(ui.create(T_VIS,  gi("eye", "Visuals"), 1))
local g_move    = styled(ui.create(T_VIS,  gi("running", "Movement"), 2))
-- v5.0 Misc tab (features collected from the current NL meta luas)
local g_misc_mv = styled(ui.create(T_MISC, gi("person-running", "Movement & Exploits"), 1))
local g_misc_gm = styled(ui.create(T_MISC, gi("gauge-high", "Game & Performance"), 1))
local g_misc_ch = styled(ui.create(T_MISC, gi("comment", "Chat & Clantag"), 2))
local g_misc_an = styled(ui.create(T_MISC, gi("person-walking", "Animation breaker (experimental)"), 2))

-- Header — v3.21: chernobl-style multi-color welcome (\aDEFAULT resets to white
-- between accent-colored segments, like "Dear <accent>name<reset>, ...").
local _uname = (common and common.get_username and common.get_username()) or "player"
-- ── Configs (DEMONTIME / nexus / Andromeda preset-manager layout): a LIST you click,
-- a name field, and inline icon buttons under it. list:get() = 1-based index = slot.
local CFG = {}
CFG.SLOTS = 8
do
    local names = {}
    for i = 1, CFG.SLOTS do names[i] = i .. "   (empty)" end
    CFG.list = g_main:list("##SEL01_CONFIGS", names)
end
CFG.name   = nil
pcall(function() CFG.name = g_main:input(ui.get_icon"pen" .. "  name", "my config") end)
CFG.b_save = g_main:button(ui.get_icon"floppy-disk" .. "  Save", nil, true)
CFG.b_load = g_main:button(ui.get_icon"upload" .. "  Load", nil, true)
CFG.b_exp  = g_main:button(ui.get_icon"file-export" .. "  Export", nil, true)
CFG.b_imp  = g_main:button(ui.get_icon"file-import" .. "  Import", nil, true)
CFG.b_del  = g_main:button("\aDB6361FF" .. ui.get_icon"trash" .. "  Delete\r", nil, true)
CFG.status = g_main:label("\aA0A6B4FF  select a slot, type a name, Save")
pcall(function()
    CFG.b_save:tooltip("Save every Sel01-Config element (AA states, defensive, misc, visuals) into the selected slot under the name.")
    CFG.b_load:tooltip("Apply the selected slot.")
    CFG.b_exp:tooltip("Copy the selected slot to the clipboard as text (sel01cfg:...). Empty slot = your live settings.")
    CFG.b_imp:tooltip("Read a sel01cfg: text from the clipboard into the selected slot (then Load).")
    CFG.b_del:tooltip("Empty the selected slot.")
end)

-- ── Presets: pick from the list, Apply. Decoded meta configs (gazolina built-ins + the
-- everlast author preset); the description label follows the selection.
local apply_preset_fwd   -- forward-decl so the button sees it at call-time
local PRESET = {}
PRESET.KEYS  = { "nyanza", "aggressive", "unrivaled", "sata", "everlast", "spin", "troll" }
PRESET.NAMES = { "Nyanza Snapshot", "Aggressive xo-yaw", "Unrivaled xo-yaw", "Sata", "Everlast Author", "Spin", "Troll / Bait" }
PRESET.DESC  = {
    "meta default: -25 / +40 real yaw, 58/58 body, switch sequence [5,5,2,2,20], choke table",
    "gazolina: random hold 3-8 sends, 3-Way on crouch, defensive always, safe head 60",
    "gazolina: static asymmetric L/R every send, warmup spin, knife safe head",
    "gazolina chaos: Bobrinho LUT, tick pulses, A/B limits, wild sequences",
    "spectral / everlast: center-jitter halves, 60/60, progressive + povorotniki hidden",
    "NL Spin modifier, random magnitude, every-send switch, no freestanding",
    "everything random, run in and watch who whiffs (not competitive)",
}
PRESET.list  = g_presets:list("##SEL01_PRESETS", PRESET.NAMES)
PRESET.desc  = g_presets:label("\aA0A6B4FF  " .. PRESET.DESC[1])
PRESET.apply = g_presets:button(ui.get_icon"check" .. "  Apply preset", function()
    local key = "nyanza"
    pcall(function()
        local v = PRESET.list:get()
        if type(v) == "number" then key = PRESET.KEYS[math.max(1, math.min(#PRESET.KEYS, v))] or key
        elseif type(v) == "string" then
            for i, n in ipairs(PRESET.NAMES) do if n == v then key = PRESET.KEYS[i] end end
        end
    end)
    apply_preset_fwd(key)
end, true)
pcall(function() PRESET.apply:tooltip("Writes every AA state, the defensive / anti-bruteforce / safe-head globals and the visual set of the selected preset. Your own configs (left) are not touched.") end)

-- ── About (right column): compact header + master switch
g_about:label(ui.get_icon"user" .. "  " .. accent .. _uname .. "\aDEFAULT  ·  v" .. accent .. SEL01_CFG_VERSION .. "\aDEFAULT  ·  companion to " .. accent .. "Sel01-Solver")
local enable_master = g_about:switch(accent .. ui.get_icon"power" .. accent .. "  Master Enable (all features)", true)

-- ══════════════════════════════════════════════════════════════════════════
-- ANTI-AIM UI
-- ══════════════════════════════════════════════════════════════════════════
-- v4.0: every AA element lives in ONE table (`AA`) — the main chunk sits near the
-- Lua 5.1 200-local ceiling, and the per-state builder alone is ~140 elements.
-- All NL writes go through :override on NL's own Anti Aim elements (never cmd
-- angle fields — v1.6 crash). Option strings verified from nyanza / angelnbone /
-- bloodwings / gingersense on THIS build:
--   Pitch        : "Disabled" | "Down" | "Fake Up" | "Fake Down"
--   Yaw          : "Disabled" | "Backward" | "Static"
--   Yaw Base     : "Local View" | "At Target"     (direction = Yaw Offset math)
--   Yaw Modifier : "Disabled" | "Offset" | "Center" | "Random" | "Spin" | "3-Way" | "5-Way"
--   Body Yaw Options (multi): "Avoid Overlap" | "Jitter" | "Randomize Jitter" | "Anti Bruteforce"
--   Leg Movement : "Walking" | "Sliding"
--   DT Lag Options: "On Peek" | "Always On"
local AA = {}
local AA_STATES = {
    { key = "global",  name = "Global",      tag = "GL"  },
    { key = "stand",   name = "Standing",    tag = "ST"  },
    { key = "move",    name = "Moving",      tag = "MV"  },
    { key = "slow",    name = "Slow-Walk",   tag = "SW"  },
    { key = "duck",    name = "Crouching",   tag = "CR"  },
    { key = "duckmv",  name = "Crouch-Move", tag = "CM"  },
    { key = "air",     name = "Air",         tag = "AIR" },
    { key = "airduck", name = "Air-Crouch",  tag = "AC"  },
}
-- v5.0 mode lists. "Bobrinho" = gazolina's 6-step choke-phase LUT {-x,-x/2,-x/3,x/3,x/2,x}
-- advanced on un-choked sends (sent to NL as a plain yaw offset, modifier disabled).
AA.YAW_MODES  = { "Static", "Center Jitter", "Offset Jitter", "Random", "3-Way", "5-Way", "Spin", "Bobrinho 6-step" }
AA.BODY_MODES = { "Jitter (side switch)", "Random side", "Tick-Switch", "Static side", "Off (no desync)" }
AA.MAG_MODES  = { "Fixed L/R", "Random Min-Max", "Bimodal A/B", "Switch A/B (sends)" }
AA.SW_MODES   = { "Every send", "Fixed delay", "Random delay", "Sequence", "By sides" }
AA.DEF_MODES  = { "Off", "On threat", "Always", "Hotkey only" }
AA.BASE_MODES = { "Global", "At Target", "Local View" }

g_aa:label(accent .. ui.get_icon"target" .. accent .. "  Sel01 AA engine (v5.0 meta per-state)")
AA.enable    = g_aa:switch("Enable AA engine", true)
AA.pitch     = g_aa:combo("Pitch", { "Down", "Fake Up", "Fake Down", "Disabled" }, 1)
AA.base      = g_aa:combo("Yaw Base", { "At Target", "Local View" }, 1)
AA.dir       = g_aa:combo("Direction", { "Backward", "Left", "Right", "Forward" }, 1)
AA.avoid_bs  = g_aa:switch("Avoid Backstab", true)
AA.legs      = g_aa:combo("Leg Movement", { "Keep NL", "Sliding", "Walking" }, 1)
-- v4.2: switches, not hotkeys — bind them in NL (right-click), hold or toggle as you like
AA.key_l     = g_aa:switch("Manual Left (bind in NL)", false)
AA.key_r     = g_aa:switch("Manual Right (bind in NL)", false)
AA.key_f     = g_aa:switch("Manual Forward (bind in NL)", false)
AA.key_b     = g_aa:switch("Manual Backward (bind in NL)", false)          -- v5.0
AA.man_base  = g_aa:combo("  └ Manual yaw base", { "Local View", "At Target" }, 1)   -- v5.0
AA.man_static= g_aa:switch("  └ Manual = static (no jitter / desync)", false)
-- v5.0 warmup / no-enemy AA (gazolina "Warmup AA" + evalate "Unsafe yaw")
AA.idle_mode = g_aa:combo("Idle AA (warmup / round end / no enemy)", { "Off", "Spin", "Distortion (sine)", "L/R flip" }, 1)
AA.idle_speed= g_aa:slider("  └ Idle speed", 1, 100, 50)
AA.idle_pitch= g_aa:combo("  └ Idle pitch", { "Down", "Disabled", "Fake Up" }, 1)
pcall(function()
    AA.enable:tooltip("Master for the per-state engine. OFF = all NL Anti Aim overrides cleared, your NL config is back in control.")
    AA.dir:tooltip("Applied as Yaw Offset math on top of the state offset: Backward 0 / Left +90 / Right -90 / Forward 180.")
    AA.man_static:tooltip("While a manual key is held: yaw modifier off and body yaw fixed 60/60 on the manual side.")
    AA.idle_mode:tooltip("Only when nobody can hurt you: warmup, round end without a threat, or no alive enemy. Spin = spinbot, Distortion = sine sweep, L/R = flip every send.")
end)

-- ── per-state builder ─────────────────────────────────────────────────────
g_aa_st:label(accent .. ui.get_icon"sliders" .. accent .. "  Per-state settings (pick a state, edit its rows)")
do
    local names = {}
    for i, st in ipairs(AA_STATES) do names[i] = st.name end
    AA.state_sel = g_aa_st:combo("Edit state", names, 1)
end
AA.st = {}
-- v5.0 defaults = the "Nyanza Snapshot" preset (gazolina built-in, decoded): asymmetric
-- real-yaw L/R (-25 / +40), 58/58 body, side switch as a SEQUENCE of un-choked sends.
-- A fresh install is playable without clicking anything.
AA.STATE_DEFAULTS = {
    global  = { use_global = false, base = "Global", yaw_mode = "Static", yaw_l = -25, yaw_r = 40, yaw_jit = 0, yaw_rand = 0,
                body_mode = "Jitter (side switch)", body_mag = "Fixed L/R", body_l = 58, body_r = 58, body_min = 58, body_ticks = 6, body_swd = 4,
                sw_mode = "Sequence", sw_delay = 2, sw_lo = 1, sw_hi = 3, sw_rlo = 1, sw_rhi = 3,
                sw_seq1 = 5, sw_seq2 = 5, sw_seq3 = 2, sw_seq4 = 2, sw_seq5 = 20, sw_seq6 = 0,
                freestand = false, defensive = "On threat", fakelag = 0 },
    stand   = { use_global = true },
    move    = { use_global = false, yaw_l = -25, yaw_r = 40,
                sw_seq1 = 5, sw_seq2 = 5, sw_seq3 = 1, sw_seq4 = 1, sw_seq5 = 10, sw_seq6 = 0 },
    slow    = { use_global = false, yaw_l = -35, yaw_r = 50, body_mode = "Tick-Switch", body_ticks = 6,
                sw_seq1 = 10, sw_seq2 = 10, sw_seq3 = 2, sw_seq4 = 2, sw_seq5 = 20, sw_seq6 = 0 },
    duck    = { use_global = false, yaw_l = -25, yaw_r = 40,
                sw_seq1 = 5, sw_seq2 = 5, sw_seq3 = 1, sw_seq4 = 1, sw_seq5 = 15, sw_seq6 = 0 },
    duckmv  = { use_global = false, yaw_l = -25, yaw_r = 40, body_mag = "Switch A/B (sends)", body_min = 55, body_swd = 3,
                sw_seq1 = 5, sw_seq2 = 5, sw_seq3 = 1, sw_seq4 = 1, sw_seq5 = 20, sw_seq6 = 0 },
    air     = { use_global = false, yaw_l = 0, yaw_r = 0, sw_mode = "Every send", defensive = "Always" },
    airduck = { use_global = false, yaw_l = -25, yaw_r = 40, defensive = "Always",
                sw_seq1 = 5, sw_seq2 = 5, sw_seq3 = 1, sw_seq4 = 1, sw_seq5 = 15, sw_seq6 = 0 },
}
for _, st in ipairs(AA_STATES) do
    local d = AA.STATE_DEFAULTS[st.key]
    local g = AA.STATE_DEFAULTS.global
    local function dv(k) if d[k] ~= nil then return d[k] end return g[k] end
    local function idx(list, v) for i, s in ipairs(list) do if s == v then return i end end return 1 end
    local p = "[" .. st.tag .. "] "
    local S = {}
    if st.key ~= "global" then S.use_global = g_aa_st:switch(p .. "Use Global settings", dv("use_global")) end
    S.base      = g_aa_st:combo(p .. "Yaw base", AA.BASE_MODES, idx(AA.BASE_MODES, dv("base")))
    S.yaw_mode  = g_aa_st:combo(p .. "Yaw mode", AA.YAW_MODES, idx(AA.YAW_MODES, dv("yaw_mode")))
    S.yaw_l     = g_aa_st:slider(p .. "Yaw offset L (desync left)", -180, 180, dv("yaw_l"))
    S.yaw_r     = g_aa_st:slider(p .. "Yaw offset R (desync right)", -180, 180, dv("yaw_r"))
    S.yaw_jit   = g_aa_st:slider(p .. "Jitter amount / spin speed / Bobrinho x", 0, 180, dv("yaw_jit"))
    S.yaw_rand  = g_aa_st:slider(p .. "Randomization", 0, 30, dv("yaw_rand"))
    S.body_mode = g_aa_st:combo(p .. "Body yaw", AA.BODY_MODES, idx(AA.BODY_MODES, dv("body_mode")))
    S.body_ticks= g_aa_st:slider(p .. "Tick-Switch period (ticks)", 2, 16, dv("body_ticks"))
    S.body_mag  = g_aa_st:combo(p .. "Body magnitude", AA.MAG_MODES, idx(AA.MAG_MODES, dv("body_mag")))
    S.body_l    = g_aa_st:slider(p .. "Left limit / Max / A", 0, 60, dv("body_l"))
    S.body_r    = g_aa_st:slider(p .. "Right limit / Max / A", 0, 60, dv("body_r"))
    S.body_min  = g_aa_st:slider(p .. "Min magnitude / B", 0, 60, dv("body_min"))
    S.body_swd  = g_aa_st:slider(p .. "Switch A/B every N sends", 1, 22, dv("body_swd"))
    S.sw_mode   = g_aa_st:combo(p .. "Side switch", AA.SW_MODES, idx(AA.SW_MODES, dv("sw_mode")))
    S.sw_delay  = g_aa_st:slider(p .. "Switch delay (sends)", 1, 22, dv("sw_delay"))
    S.sw_lo     = g_aa_st:slider(p .. "Random / Left-side delay min (sends)", 1, 22, dv("sw_lo"))
    S.sw_hi     = g_aa_st:slider(p .. "Random / Left-side delay max (sends)", 1, 22, dv("sw_hi"))
    S.sw_rlo    = g_aa_st:slider(p .. "Right-side delay min (By sides)", 1, 22, dv("sw_rlo"))
    S.sw_rhi    = g_aa_st:slider(p .. "Right-side delay max (By sides)", 1, 22, dv("sw_rhi"))
    S.sw_seq1   = g_aa_st:slider(p .. "Sequence step 1 (sends, 0 = end)", 0, 22, dv("sw_seq1"))
    S.sw_seq2   = g_aa_st:slider(p .. "Sequence step 2", 0, 22, dv("sw_seq2"))
    S.sw_seq3   = g_aa_st:slider(p .. "Sequence step 3", 0, 22, dv("sw_seq3"))
    S.sw_seq4   = g_aa_st:slider(p .. "Sequence step 4", 0, 22, dv("sw_seq4"))
    S.sw_seq5   = g_aa_st:slider(p .. "Sequence step 5", 0, 22, dv("sw_seq5"))
    S.sw_seq6   = g_aa_st:slider(p .. "Sequence step 6", 0, 22, dv("sw_seq6"))
    S.freestand = g_aa_st:switch(p .. "Freestanding", dv("freestand"))
    S.defensive = g_aa_st:combo(p .. "Defensive AA", AA.DEF_MODES, idx(AA.DEF_MODES, dv("defensive")))
    S.fakelag   = g_aa_st:slider(p .. "Fake lag limit (0 = keep NL)", 0, 14, dv("fakelag"))
    pcall(function()
        S.base:tooltip("Global = the Yaw Base combo above. At Target = backward from the closest enemy (meta default). Local View = backward from where you look (everlast uses it on slow-walk).")
        S.yaw_mode:tooltip("Static: the L/R offset rides on the desync side (meta L/R jitter). Center: +/- half amount around it. Offset: amount on one side only. Random: uniform in +/- amount. 3-Way / 5-Way / Spin: NL's own modifier. Bobrinho: gazolina 6-step LUT {-x,-x/2,-x/3,x/3,x/2,x} advanced per send.")
        S.yaw_l:tooltip("Real yaw offset while the desync side is LEFT. Meta values are asymmetric, e.g. -25 / +40 (Nyanza), -35 / +30 (everlast).")
        S.body_mode:tooltip("Jitter = the engine flips the inverter per Side switch timing. Tick-Switch = body yaw OFF for 2 ticks every period (spectral / gazolina Ticks). Random side / Static side / Off.")
        S.body_mag:tooltip("Fixed = L/R sliders. Random = new value between Min and Max on every side switch. Bimodal = alternates Min and Max every 2-5s. Switch A/B = alternates A (L/R) and B (Min) every N un-choked sends (gazolina Limit Switch).")
        S.sw_mode:tooltip("Counted in UN-CHOKED sends (packets the enemy receives), not ticks. Sequence = the 6 step sliders in order (Nyanza [5,5,2,2,20]). By sides = random hold per side (left min/max, right min/max).")
        S.defensive:tooltip("Needs NL Double Tap ON + charged. On threat = only while someone can hit you. Hotkey only = the Force defensive key. While enabled for a state the DT Lag Options / Hide Shots option overrides (Defensive group) also apply.")
    end)
    AA.st[st.key] = S
end
-- show only the selected state's rows; a state on "Use Global" collapses to that one switch
-- v5.0: mode-dependent rows (sequence steps, by-side ranges, tick period, A/B period)
-- are hidden unless their mode is selected, so a state stays readable.
local function aa_state_vis()
    local sel = "Global"
    pcall(function() sel = AA.state_sel:get() end)
    for _, st in ipairs(AA_STATES) do
        local S = AA.st[st.key]
        local show = (st.name == sel)
        local ug = false
        if S.use_global then pcall(function() ug = S.use_global:get() end) end
        local swm, bm, mm = "Sequence", "Jitter (side switch)", "Fixed L/R"
        pcall(function() swm = S.sw_mode:get(); bm = S.body_mode:get(); mm = S.body_mag:get() end)
        local dep = {
            sw_delay = (swm == "Fixed delay"),
            sw_lo = (swm == "Random delay" or swm == "By sides"), sw_hi = (swm == "Random delay" or swm == "By sides"),
            sw_rlo = (swm == "By sides"), sw_rhi = (swm == "By sides"),
            sw_seq1 = (swm == "Sequence"), sw_seq2 = (swm == "Sequence"), sw_seq3 = (swm == "Sequence"),
            sw_seq4 = (swm == "Sequence"), sw_seq5 = (swm == "Sequence"), sw_seq6 = (swm == "Sequence"),
            body_ticks = (bm == "Tick-Switch"),
            body_swd = (mm == "Switch A/B (sends)"),
            body_min = (mm ~= "Fixed L/R"),
        }
        for k, el in pairs(S) do
            local vis = show and (k == "use_global" or not ug)
            if vis and dep[k] == false then vis = false end
            pcall(function() el:visibility(vis) end)
        end
    end
end
pcall(function() AA.state_sel:set_callback(function() aa_state_vis() end) end)
for _, st in ipairs(AA_STATES) do
    local S = AA.st[st.key]
    if S.use_global then pcall(function() S.use_global:set_callback(function() aa_state_vis() end) end) end
    pcall(function() S.sw_mode:set_callback(function() aa_state_vis() end) end)
    pcall(function() S.body_mode:set_callback(function() aa_state_vis() end) end)
    pcall(function() S.body_mag:set_callback(function() aa_state_vis() end) end)
end
aa_state_vis()

-- ── defensive / exploit ───────────────────────────────────────────────────
g_aa_def:label(accent .. ui.get_icon"bolt" .. accent .. "  Defensive AA (needs NL Double Tap ON + charged)")
AA.def_enable = g_aa_def:switch("Defensive AA master", true)
-- v5.0 choke tables (gazolina / Andromeda / spectral "Custom tickbase"): the pulse fires
-- on command_number % N == 0; N comes from a fixed value, a random range re-rolled every
-- tick, or a random pick from a 6-step table (Nyanza: [6,22,19,11,16,6]).
AA.def_mode   = g_aa_def:combo("Choke mode", { "Fixed N", "Random lo..hi", "Sequence (random pick)" }, 3)
AA.def_int    = g_aa_def:slider("  └ Fixed N (commands)", 1, 32, 16)
AA.def_lo     = g_aa_def:slider("  └ Random min", 2, 32, 2)
AA.def_hi     = g_aa_def:slider("  └ Random max", 2, 32, 22)
AA.def_seq    = {}
for i, v in ipairs({ 6, 22, 19, 11, 16, 6 }) do
    AA.def_seq[i] = g_aa_def:slider("  └ Choke step " .. i .. " (0 = unused)", 0, 32, v)
end
AA.def_shuffle= g_aa_def:button("  └ Shuffle choke steps", function() end)
AA.def_key    = g_aa_def:switch("Force defensive (bind in NL)", false)
AA.def_events = g_aa_def:switch("Also defensive on weapon switch / reload", true)
AA.def_pause  = g_aa_def:switch("Pause defensive 0.3s after the ragebot fires", true)
AA.def_clean  = g_aa_def:combo("After discharge: clean records", { "Off", "Random +/-12", "Random + flick 60-72" }, 2)
AA.def_lag    = g_aa_def:switch("DT Lag Options = Always On (break LC)", true)
AA.hs_opts    = g_aa_def:combo("Hide Shots option while defensive", { "Keep NL", "Break LC", "Favor Fake Lag", "Favor Fire Rate" }, 2)
AA.air_mode   = g_aa_def:combo("Air exploit", { "Off", "gingersense (every tick + tp/6)", "evalate (pulse N + fakelag rnd + tp)", "elysian (alternate fake duck)" }, 1)
AA.air_n      = g_aa_def:slider("  └ evalate pulse every N ticks", 5, 40, 10)
AA.fix_rechg  = g_aa_def:switch("Fix recharge delay (fake lag 1 while DT recharges)", true)
AA.fl_mode    = g_aa_def:combo("Fake-lag variance", { "Off", "+/-2 around NL value", "Fluctuate 1 / 14" }, 1)
AA.fl_force   = g_aa_def:switch("Force NL Fake Lag ON while engine runs", false)
AA.fl_dis_dt  = g_aa_def:switch("Fake lag OFF while Double Tap", true)
AA.fl_dis_hs  = g_aa_def:switch("Fake lag OFF while Hide Shots", true)
AA.fl_dis_st  = g_aa_def:switch("Fake lag OFF while standing", false)
g_aa_def:label(" ")
g_aa_def:label(accent .. "  Hidden angles on defensive ticks (silent flick)")
AA.dh_enable  = g_aa_def:switch("Defensive hidden angles", false)
AA.dh_pitch   = g_aa_def:combo("  └ Hidden pitch", { "Down 89", "Up -89", "Cycle", "Random", "Jitter 89/-89", "Elysian wave", "Progressive", "Zero" }, 1)
AA.dh_yaw     = g_aa_def:combo("  └ Hidden yaw", { "Sideways +/-90", "Spin", "Random", "Custom", "Opposite 180", "Jitter (packet parity)", "Povorotniki", "Progressive spin", "Sweep -90..90" }, 1)
AA.dh_yaw_val = g_aa_def:slider("  └ Custom yaw / spin speed", -180, 180, 90)
AA.dh_cond    = g_aa_def:combo("  └ When", { "Hittable threat", "Always" }, 1)
pcall(function()
    AA.def_enable:tooltip("cmd.force_defensive pulses on command_number % N while rage.exploit charge == 1. Revolver skipped. Nothing is written when DT is off.")
    AA.def_mode:tooltip("Fixed = one N. Random = a new N between min and max every tick (evalate / gazolina). Sequence = a random pick from the 6 step sliders every tick (Nyanza [6,22,19,11,16,6]). Lower N = more defensive ticks.")
    AA.def_events:tooltip("elysian 'force defensive' game events: while the weapon is switching (m_flNextAttack) or reloading the defensive pulses run regardless of the state setting.")
    AA.def_pause:tooltip("Defensive + DT lag Always On can eat your own shot. After events.aim_fire the pulses stop for 0.3s so the bullet goes out.")
    AA.def_clean:tooltip("gingersense 'clean records': for 11-17 ticks after a detected discharge (tickbase drop) with a threat, add a random yaw so the records the enemy backtracks are garbage.")
    AA.def_lag:tooltip("Overrides NL Double Tap > Lag Options to Always On while the current state has defensive enabled and the weapon can fire (never while Peek Assist is held). Every meta lua does this ('Break LC').")
    AA.hs_opts:tooltip("Overrides NL Hide Shots > Options while defensive is enabled for the state and Hide Shots is on. Break LC = the hide-shots equivalent of DT lag Always On.")
    AA.air_mode:tooltip("gingersense: force_defensive every airborne tick + force_charge + teleport every 6 ticks. evalate: every N airborne ticks with charge: force_defensive + DT fake lag limit random 1-7 + force_teleport, else force_charge. elysian: airborne with DT or HS -> NL Fake Duck alternates every other tick (tickbase abuse). All need DT on.")
    AA.fix_rechg:tooltip("Andromeda: while DT or Hide Shots are on, on the ground, not fake ducking, not revolver and the exploit is NOT charged, fake lag limit = 1 so the charge comes back faster.")
    AA.fl_dis_dt:tooltip("elysian / nexus / Andromeda FL disablers: NL Fake Lag > Enabled is overridden OFF while the condition holds (fake lag and DT fight each other).")
    AA.dh_enable:tooltip("Writes rage.antiaim:override_hidden_pitch / yaw_offset (Yaw > Hidden). Only defensive records carry it; your visible model does not flick. Turn 11_fakeflick / 12_silentflick OFF - they write the same thing.")
    AA.dh_pitch:tooltip("Jitter = 89 / -89 per send. Elysian wave = fast triangle -89..89 every 0.3s. Progressive = slow sweep. Zero = 0.")
    AA.dh_yaw:tooltip("Jitter = +/-90 by packet parity. Povorotniki = 3-tick flip-flop (spectral). Progressive spin = (curtime*7 % 3 - 1) * 179. Sweep = triangle -90..90.")
end)
-- mode-dependent rows
local function aa_def_vis()
    local m = "Sequence (random pick)"
    pcall(function() m = AA.def_mode:get() end)
    pcall(function()
        AA.def_int:visibility(m == "Fixed N")
        AA.def_lo:visibility(m == "Random lo..hi"); AA.def_hi:visibility(m == "Random lo..hi")
        for i = 1, 6 do AA.def_seq[i]:visibility(m == "Sequence (random pick)") end
        AA.def_shuffle:visibility(m == "Sequence (random pick)")
        local am = AA.air_mode:get()
        AA.air_n:visibility(am == "evalate (pulse N + fakelag rnd + tp)")
    end)
end
pcall(function() AA.def_mode:set_callback(function() aa_def_vis() end) end)
pcall(function() AA.air_mode:set_callback(function() aa_def_vis() end) end)
aa_def_vis()
-- (the Shuffle button callback is attached next to the pending_def_shuffle local below —
--  attaching it here would bind the closure to a nil GLOBAL, the forward-ref trap)

-- ── anti-bruteforce / reactions ───────────────────────────────────────────
g_aa_rx:label(accent .. ui.get_icon"shield" .. accent .. "  Anti-bruteforce (bullet impacts near you)")
AA.ab_enable  = g_aa_rx:switch("Anti-bruteforce", true)
AA.ab_radius  = g_aa_rx:slider("Near-miss radius (u)", 20, 150, 60)
AA.ab_dur     = g_aa_rx:slider("Reaction duration (s)", 1, 10, 5)
AA.ab_flip    = g_aa_rx:switch("  └ Flip side", true)
AA.ab_limit   = g_aa_rx:switch("  └ Random fake limit (10-60)", true)
AA.ab_delay   = g_aa_rx:switch("  └ Random switch delay (-2..+4)", false)
AA.ab_yaw     = g_aa_rx:switch("  └ Yaw offset reaction", true)
AA.ab_mode    = g_aa_rx:combo("      mode", { "Meta staged (+2/stage, alternating)", "Increase +5..15", "Decrease -15..5", "Random phases -40..40" }, 1)
-- v5.0 evalate / elysian "Freeze": with a chance, hold the inverter for N sends after a
-- near-miss so the side does not flip into the bruteforcer's next guess.
AA.ab_freeze  = g_aa_rx:switch("  └ Freeze side switching", false)
AA.ab_fchance = g_aa_rx:slider("      chance %", 0, 100, 50)
AA.ab_fdur    = g_aa_rx:slider("      duration (sends)", 1, 80, 10)
g_aa_rx:label(" ")
AA.hit_react  = g_aa_rx:switch("On hit taken: flip side + defensive burst", true)
AA.hit_dur    = g_aa_rx:slider("  └ Burst duration (ms)", 300, 3000, 1500)
AA.hit_nofree = g_aa_rx:switch("  └ Freestanding OFF during burst", true)
AA.head_prot  = g_aa_rx:switch("Head-safe pulses (threat can shoot, you can too)", false)
pcall(function()
    AA.ab_enable:tooltip("events.bullet_impact: distance from your eye to the shot line (shooter eye -> impact). Per shooter, one reaction per 0.25s.")
    AA.ab_mode:tooltip("Meta = gazolina: per-shooter stage, yaw += stage*2 signed by side. Increase / Decrease = gazolina random push. Random phases = elysian: every near-miss advances a phase with its own random -40..40 offset (up to 10).")
    AA.ab_freeze:tooltip("evalate Freeze: after a near-miss, with the given chance the side switching is frozen for N un-choked sends. Defeats brute-forcers that expect a flip.")
    AA.head_prot:tooltip("gingersense head protection: when the hittable threat's weapon is ready, hold a near-zero yaw with max desync for 1-2 ticks, re-arm after 7-15 ticks. Test before relying on it.")
end)

-- ── v5.0 safe head / freestanding / legit ─────────────────────────────────
-- Safe Head (Andromeda / nexus / gazolina / evalate): with a knife or zeus, in an air-crouch,
-- or with a height advantage the head is tucked behind the body: tiny limits, At Target,
-- no jitter. Freestanding key + static body yaw (elysian / nexus). Legit AA on +use (evalate
-- / spectral / elysian "on use"): the E key is swallowed and the real yaw turns +180 so a
-- bomb/hostage interaction looks legit.
g_aa_sh:label(accent .. ui.get_icon"shield" .. accent .. "  Safe Head (head behind the body)")
AA.sh_enable  = g_aa_sh:switch("Safe Head", true)
AA.sh_knife   = g_aa_sh:switch("  └ with knife", true)
AA.sh_zeus    = g_aa_sh:switch("  └ with zeus", true)
AA.sh_airduck = g_aa_sh:switch("  └ in air-crouch", false)
AA.sh_height  = g_aa_sh:switch("  └ with height advantage", false)
AA.sh_hdiff   = g_aa_sh:slider("      min height difference (u)", 5, 200, 36)
AA.sh_yaw     = g_aa_sh:slider("  └ yaw offset", -60, 60, 0)
AA.sh_limit   = g_aa_sh:slider("  └ body limit", 0, 60, 3)
AA.sh_inv     = g_aa_sh:switch("  └ inverter on", false)
g_aa_sh:label(" ")
g_aa_sh:label(accent .. ui.get_icon"user" .. accent .. "  Freestanding")
AA.fs_key     = g_aa_sh:switch("Freestanding (bind in NL)", false)
AA.fs_static  = g_aa_sh:switch("  └ Static body yaw while freestanding", false)
g_aa_sh:label(" ")
g_aa_sh:label(accent .. ui.get_icon"eye" .. accent .. "  Legit AA / edge")
AA.onuse      = g_aa_sh:switch("Legit AA on +use (swallow E, yaw +180)", true)
AA.edge       = g_aa_sh:switch("Edge yaw (real yaw into the wall you hug)", false)
pcall(function()
    AA.sh_enable:tooltip("Overrides the state while the condition holds: yaw = offset, base At Target, modifier off, body yaw ON with the small limit, freestanding off, no defensive hidden angles. Nyanza: limits 1/1, height 36; Andromeda knife limit 30 yaw 37.")
    AA.sh_height:tooltip("gazolina / evalate 'Height advantage': your origin is at least N units above the tracked threat (you stand on a box / ledge). Only the head peeks over, so hide it.")
    AA.fs_key:tooltip("Forces freestanding in every state while the switch is on (bind it in NL). Per-state Freestanding switches stay as the default.")
    AA.fs_static:tooltip("elysian / evalate static freestand: NL 'Disable Yaw Modifiers' ON + 'Body Freestanding' OFF + modifier off, so the freestanding side is the only thing that moves.")
    AA.onuse:tooltip("While you hold +use (E) the key is swallowed, yaw base = Local View, pitch Disabled and the real yaw turns +180. Skipped while holding the C4, when a door / button / weapon / hostage is in front of you, or as CT next to a planted bomb (defuse).")
    AA.edge:tooltip("spectral edge yaw: 20 rays at 32u around you; when a wall is on 2+ rays the real yaw is turned into the wall (delta*2 + 180, Local View). Experimental - test first.")
end)

-- ── anti-headshot extras ──────────────────────────────────────────────────
g_aa_hs:label(accent .. "  Anti-headshot extras (default OFF - test first)")
AA.pitch_jitter = g_aa_hs:switch("Pitch jitter (Down / Fake Up per send)", false)
AA.move_fd      = g_aa_hs:switch("Auto fake-duck while moving (ground only)", false)
AA.move_fd_thr  = g_aa_hs:slider("  └ Velocity threshold (u/s)", 50, 250, 100)

-- runtime state of the engine (one table, no per-field locals)
local aa_eng = {
    active = false, side = 0, sw_ctr = 0, sends = 0, false_ticks = 0,
    body_l = 60, body_r = 60, body_roll_side = -1, bimodal_mode = 1, bimodal_next = 0,
    max_tickbase = 0, defensive = 0, def_state = false, def_after = 0, def_pulse = false,
    def_pulses = 0, last_def_t = 0, charge = 0, dt_on = false, hs_on = false,
    state = "?", state_since = 0, last_switch_t = 0, switches = 0,
    ab = {}, ab_tick = 0, ab_last = 0, ab_stage = 0, ab_hits = 0,
    react_until = 0, react_from = "", force_side = nil,
    hp = { hold = 0, delay = 8, yaw = 0, active = false },
    manual = "", threat = nil, threat_name = "", threat_dist = 0, threat_x = 0, threat_y = 0, threat_z = 0,
    yaw_w = 0, l_w = 0, r_w = 0, mod_w = "Disabled", modamt_w = 0, free_w = false, body_w = true,
    fl_base = nil, fl_active = false, dtlag_active = false, hidden_active = false,
    airlag_ctr = 0, pitch_flip = false, fd_active = false, fd_cnt = 0,
    -- v5.0
    seq_i = 1, bob_i = 1, freeze_until = 0, ab_phase = 0, ab_phase_off = 0, swab_state = 1, swab_ctr = 0,
    sh_active = false, onuse_active = false, edge_active = false, fs_static_active = false,
    fl_dis_active = false, rc_active = false, hs_active = false, air_fd_active = false, last_fire_t = -10,
    stats = { near_miss = 0, flips = 0, def_ticks = 0, react = 0, hp_pulses = 0, freezes = 0, sh_ticks = 0, onuse = 0 },
}
-- timeline ring (what happened lately) — feeds Copy Last Logs + the hits-taken dump
local aa_tl = {}
local AA_TL_MAX = 160
local function aa_tl_push(kind, text)
    aa_tl[#aa_tl + 1] = { t = globals.realtime or 0, kind = kind, text = tostring(text) }
    if #aa_tl > AA_TL_MAX then table.remove(aa_tl, 1) end
end

-- ══════════════════════════════════════════════════════════════════════════
-- MOVEMENT UI
-- ══════════════════════════════════════════════════════════════════════════
g_move:label(accent .. ui.get_icon"running" .. accent .. "  Movement helpers")
-- V2.8 + V3.1: Peek Boost = HOLD hotkey. Lowers ragebot HC while held.
-- V3.5: MinDmg slider REMOVED — lua never overrides NL min_dmg (was eating user's 100).
local mv_peek_boost_k = g_move:switch("Peek Boost (bind in NL)", false)   -- v4.2: switch, not hotkey
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
g_move:label(accent .. ui.get_icon"crosshairs" .. accent .. "  AI Peek (hold cover → step out when a shot exists → back)")
-- v4.1 AI Peek rewrite (aiPeek_61044 algorithm): you stand at a spot; the script anchors
-- there and HOLDS. Every tick it builds candidate positions left/right of the anchor
-- (perpendicular to the threat, traced against walls) and runs utils.trace_bullet from
-- each candidate EYE position to the enemy hitboxes. Only when a candidate yields at
-- least NL Min. Damage does it strafe to that point (P-controlled, stops on the point),
-- lets the ragebot fire, then returns to the anchor (DT teleport back when charged).
-- Elements live in one table (main-chunk local budget).
local AIP = {}
AIP.enable   = g_move:switch("Enable AI Peek", false)
-- v4.2: plain switch instead of trigger combo + hotkey. NL can bind ANY switch to a key
-- (right-click), so one bindable "active" switch replaces the whole hold/always/key setup.
AIP.active   = g_move:switch("  └ AI Peek active (bind this switch in NL)", false)
AIP.dist     = g_move:slider("Peek distance (u)", 10, 120, 40)
AIP.delay    = g_move:slider("Confirm ticks before peeking", 0, 5, 1)
AIP.expose   = g_move:slider("Max exposure without a shot (ms)", 150, 1500, 450)
AIP.cooldown = g_move:slider("Cooldown after retreat (ms)", 0, 2000, 250)
AIP.retreat  = g_move:combo("Retreat", { "After the shot", "When no shot exists" }, 1)
AIP.dt_wait  = g_move:switch("Wait for DT charge (when DT is on)", false)
AIP.dt_tele  = g_move:switch("DT teleport back on retreat", true)
AIP.keys     = g_move:switch("Pause while you move manually", true)
AIP.hitboxes = g_move:combo("Check hitboxes", { "Head + Body", "Head only", "Body only" }, 1)
AIP.hc       = g_move:slider("Peek Hit Chance (0 = keep NL)", 0, 100, 0)
AIP.unsafe   = g_move:switch("Drop Safe Points during the peek", false)
AIP.wpn      = g_move:combo("Weapon Filter", { "All", "Snipers only", "Pistols only", "Deagle only" }, 1)
AIP.vis      = g_move:switch("Draw peek point + target hitbox", true)
AIP.dev      = g_move:switch("Dev Mode (console debug)", false)
pcall(function()
    AIP.enable:tooltip("Master. Stand still behind cover with 'active' on. The bot only moves when a traced bullet from a peek position would deal NL Min. Damage (-5) to an enemy.")
    AIP.active:tooltip("Right-click this switch in NL and bind it to a key (hold or toggle, your choice). While it is on the peek logic runs; off = the bot never touches your movement.")
    AIP.dist:tooltip("How far left/right of the anchor the peek positions are searched. Walls cut it short automatically.")
    AIP.delay:tooltip("Consecutive ticks a shot must exist before committing. 0 = instant, 1-2 filters flickering sightlines.")
    AIP.expose:tooltip("Safety: standing on the peek point this long without the ragebot firing → retreat anyway.")
    AIP.retreat:tooltip("After the shot = go back the moment events.aim_fire says the ragebot committed (default). When no shot exists = stay out while a shot is still possible.")
    AIP.hc:tooltip("0 keeps your NL Hit Chance (recommended - the bot stops on the point, NL auto-stop handles the rest). A value here overrides HC only while peeking.")
end)

-- ══════════════════════════════════════════════════════════════════════════
-- v5.0 MISC UI — features collected from the current meta luas (elysian, evalate,
-- Andromeda, nexus, gazolina, spectral, arc). Everything lives in the MISC table
-- (main-chunk local budget). Risky / FFI features default OFF and say "test first".
-- ══════════════════════════════════════════════════════════════════════════
local MISC = {}
g_misc_mv:label(accent .. ui.get_icon"running" .. accent .. "  Movement")
MISC.ladder    = g_misc_mv:switch("Fast ladder (look down, keys swapped)", true)
MISC.nofall    = g_misc_mv:switch("No fall damage (auto duck before landing)", true)
MISC.fd_speed  = g_misc_mv:switch("Unlock fake-duck speed (full 450)", false)
MISC.edge_stop = g_misc_mv:switch("Edge stop (stop before falling off)", false)
g_misc_mv:label(" ")
g_misc_mv:label(accent .. ui.get_icon"bolt" .. accent .. "  Ragebot helpers")
MISC.jump_scout= g_misc_mv:switch("Jump scout (SSG in air: no air strafe + auto stop In Air)", false)
MISC.auto_hs   = g_misc_mv:switch("Auto hide shots (DT charged + state)", false)
MISC.auto_hs_st= g_misc_mv:switch("  └ standing", true)
MISC.auto_hs_du= g_misc_mv:switch("  └ crouching", true)
MISC.auto_hs_sw= g_misc_mv:switch("  └ slow-walk", true)
MISC.auto_hs_pi= g_misc_mv:switch("  └ not with pistols / deagle", true)
MISC.fakelat   = g_misc_mv:switch("Unlock fake latency (sv_maxunlag 1.0)", false)
MISC.fakelat_v = g_misc_mv:slider("  └ sv_maxunlag x100", 20, 200, 100)
pcall(function()
    MISC.ladder:tooltip("evalate / elysian / spectral: on a ladder the view pitch is forced to 89 and forward/back are swapped, so you climb at full speed. The ragebot keeps aiming.")
    MISC.nofall:tooltip("Andromeda / evalate: falling faster than 500u/s with ground within 75u (but not 15u) -> +duck for the landing tick. Removes most fall damage.")
    MISC.fd_speed:tooltip("elysian / evalate 'unlock fd speed': while NL Fake Duck is held on the ground the movement vector is renormalized to 450. Uses createmove_run.")
    MISC.edge_stop:tooltip("nexus: simulate 4 ticks ahead; if you would leave the ground the movement is zeroed. Test first.")
    MISC.jump_scout:tooltip("evalate: with an SSG-08 / revolver airborne and no movement input, NL Air Strafe is overridden OFF and Auto Stop options = In Air so the scout shot lands. Test first.")
    MISC.auto_hs:tooltip("evalate 'Auto OS': while the exploit is charged and Hide Shots is off, in the checked states NL Hide Shots is overridden ON (DT stays as you set it). Test first.")
    MISC.fakelat:tooltip("spectral / gazolina / nexus 'unlock latency': cvar sv_maxunlag raised so NL Fake Latency can go beyond 200ms. Restored on unload.")
end)

g_misc_gm:label(accent .. ui.get_icon"sliders" .. accent .. "  Game & performance")
MISC.fps       = g_misc_gm:switch("FPS optimizer (cvars)", false)
MISC.fps_fog   = g_misc_gm:switch("  └ fog off", true)
MISC.fps_blood = g_misc_gm:switch("  └ blood off", true)
MISC.fps_bloom = g_misc_gm:switch("  └ bloom off", true)
MISC.fps_decal = g_misc_gm:switch("  └ decals off", true)
MISC.fps_shadow= g_misc_gm:switch("  └ shadows off", true)
MISC.fps_fx    = g_misc_gm:switch("  └ sprites / ropes / muzzle light off", false)
MISC.warmup    = g_misc_gm:button("Warmup config (local server cvars)", function() end)
g_misc_gm:label(" ")
MISC.vm        = g_misc_gm:switch("Viewmodel changer", false)
MISC.vm_fov    = g_misc_gm:slider("  └ FOV", 54, 120, 68)
MISC.vm_x      = g_misc_gm:slider("  └ X", -20, 20, 2)
MISC.vm_y      = g_misc_gm:slider("  └ Y", -20, 20, 0)
MISC.vm_z      = g_misc_gm:slider("  └ Z", -20, 20, -2)
MISC.vm_knife  = g_misc_gm:switch("  └ opposite knife hand", false)
MISC.aspect    = g_misc_gm:switch("Aspect ratio", false)
MISC.aspect_v  = g_misc_gm:slider("  └ ratio x100 (133 = 4:3, 177 = 16:9)", 100, 250, 133)
pcall(function()
    MISC.fps:tooltip("Andromeda FPS optimizer: fog_enable 0, violence_hblood 0, mat_disable_bloom 1, r_drawdecals 0, csm shadows 0, r_drawsprites/ropes 0, muzzleflash_light 0. Originals restored on unload.")
    MISC.warmup:tooltip("sv_cheats 1; mp_warmup_end; infinite ammo; buy anywhere; respawn on death; bot_stop 1; long round time. Only works on your own server.")
    MISC.vm:tooltip("viewmodel_fov / viewmodel_offset_x/y/z + cl_righthand. Meta values: fov 68, x 2.5, y 0, z -1.5 (evalate x 2.5 / gazolina). Restored on unload.")
    MISC.aspect:tooltip("cvar r_aspectratio (133 = 4:3 stretched). Restored on unload.")
end)

g_misc_ch:label(accent .. ui.get_icon"user" .. accent .. "  Chat")
MISC.killsay   = g_misc_ch:switch("Kill say", false)
MISC.killsay_st= g_misc_ch:combo("  └ style", { "Memes", "Tilt", "Polite", "Sel01", "One (\"1\")" }, 1)
MISC.killsay_rv= g_misc_ch:switch("  └ only on revenge (killed who killed you)", false)
MISC.deathsay  = g_misc_ch:switch("Death say (body shot excuse)", false)
g_misc_ch:label(" ")
g_misc_ch:label(accent .. ui.get_icon"sliders" .. accent .. "  Clantag (Quality of Life switch turns it on)")
MISC.ct_custom = nil
pcall(function() MISC.ct_custom = g_misc_ch:input("Custom clantag text (Typewriter style)", "Sel01") end)
MISC.ct_lat    = g_misc_ch:switch("Latency-compensated frame timing", true)
pcall(function()
    MISC.killsay:tooltip("elysian / evalate / Andromeda kill say: one line after your kill, sent via 'say' from net_update_end with a human-like delay (1-4s by length). Never repeats the last line.")
    MISC.deathsay:tooltip("elysian: when you die to a non-headshot bullet: 'ofc body u fkn nn xd'.")
    MISC.ct_lat:tooltip("arc / spectral / evalate: the clantag frame index uses tickcount + to_ticks(latency) so everyone sees the animation in sync.")
end)

g_misc_an:label(accent .. ui.get_icon"eye" .. accent .. "  Animation breaker (FFI m_AnimOverlay, OFF by default)")
MISC.anim      = g_misc_an:switch("Enable animation breaker", false)
MISC.anim_lean = g_misc_an:switch("  └ Move lean (layer 12 weight)", false)
MISC.anim_leanw= g_misc_an:slider("      lean weight %", 0, 100, 100)
MISC.anim_legs = g_misc_an:switch("  └ Leg breaker (Leg Movement Sliding + pose 0)", false)
MISC.anim_land = g_misc_an:switch("  └ Landing pitch zero (pose 12)", false)
MISC.anim_fall = g_misc_an:switch("  └ Force falling animation in air (pose 6)", false)
pcall(function()
    MISC.anim:tooltip("elysian / evalate / spectral / nexus / gazolina all write the animation layers at entity+10640 (0x2990) from events.post_update_clientside_animation. Client-side only (what YOU see + what desync-reading resolvers sample from your animlayers). FFI writes cannot be pcall-protected - test on a bot server first.")
end)

-- runtime state for the Misc tab
local misc_eng = {
    fps_saved = nil, fakelat_saved = nil, aspect_saved = nil, vm_saved = nil, knife_on = false,
    airstrafe_ov = false, autostop_ov = false, hs_ov = false, edge_stopped = 0,
    killsay_q = {}, last_line = "", last_attacker = nil, revenge_of = nil,
    anim_ok = nil, anim_T = nil, legs_ov = false,
}

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
g_visual:label(accent .. ui.get_icon"sliders" .. accent .. "  Render extras:")
local vis_desyncpct  = g_visual:switch(accent .. ui.get_icon"bolt"       .. accent .. "  Desync delta % (real vs fake yaw)", true)
local vis_skeet      = g_visual:switch(accent .. ui.get_icon"bolt"       .. accent .. "  Skeet indicator panel (DT/FS/SAFE/BODY/MD/DUCK)", false)
local vis_netgraph   = g_visual:switch(accent .. ui.get_icon"feather"    .. accent .. "  Netgraph (ping / loss / choke + LC warn)", false)
local vis_scopefade  = g_visual:switch(accent .. ui.get_icon"eye"        .. accent .. "  Fade own model when scoped", true)
local vis_sleeves    = g_visual:switch(accent .. ui.get_icon"eye"        .. accent .. "  Remove sleeves (cleaner POV)", false)
local vis_menublur   = g_visual:switch(accent .. ui.get_icon"eye"        .. accent .. "  Blur behind menu", false)
local vis_custscope  = g_visual:switch(accent .. ui.get_icon"crosshairs" .. accent .. "  Custom scope overlay", false)
local vis_scope_rot  = g_visual:switch(accent ..                            "      rotate scope 45 deg", false)
local vis_menuborder = g_visual:switch(accent .. ui.get_icon"sliders"    .. accent .. "  Animated menu border (HSV flow)", true)
-- v5.0 visual extras (table = local budget). Meta pieces: NL keybinds via ui.get_binds
-- (evalate / nexus / arc), arrow styles (Andromeda / gazolina TS triangles), DT charge
-- ring (evalate / nexus), desync bar wings (evalate), min-damage indicator (Andromeda /
-- spectral / nexus), left-edge side indicators (elysian / Andromeda / nexus / arc).
local VIS = {}
g_visual:label(" ")
g_visual:label(accent .. ui.get_icon"eye" .. accent .. "  Indicators & panels:")
VIS.arrows_style = g_visual:combo("Manual arrow style", { "Classic < >", "Modern (Verdana 27)", "Triangles (gazolina TS)" }, 1)
VIS.arrows_off   = g_visual:slider("  └ arrow offset (px)", 20, 120, 45)
VIS.dt_ring      = g_visual:switch("DT charge ring under the crosshair", true)
VIS.desync_bar   = g_visual:switch("Desync bar (fake vs real wings)", true)
VIS.fl_line      = g_visual:switch("Fake lag line (FL N while choking)", true)
VIS.md_ind       = g_visual:switch("Min. damage indicator (bind / override)", true)
VIS.keybinds_nl  = g_visual:switch("Keybinds panel: show ALL active NL binds", true)
VIS.side_ind     = g_visual:switch("Left-edge side indicators (skeet style)", false)
VIS.side_off     = g_visual:slider("  └ bottom offset (px)", 100, 600, 350)
VIS.wm_pos       = g_visual:combo("Watermark position", { "Top Right", "Top Left", "Bottom Right", "Bottom Left" }, 1)
VIS.hitmark_dmg  = g_visual:switch("Hit marker: damage number + kill color", true)
VIS.def_glyph    = g_visual:switch("Defensive glyph (pulsing star while shifting)", false)
-- v5.0 draggable panels (elysian / nexus / spectral / evalate pattern): while the NL menu is
-- open every panel can be grabbed with the mouse; the position lives in two HIDDEN sliders
-- per panel (-1 = default position) so NL persists it with the config.
VIS.drag = {}
for _, nm in ipairs({ "watermark", "keybinds", "spectators", "netgraph", "eventlog", "velocity", "sideind" }) do
    local sx = g_visual:slider("##drag_" .. nm .. "_x", -1, 8192, -1)
    local sy = g_visual:slider("##drag_" .. nm .. "_y", -1, 8192, -1)
    pcall(function() sx:visibility(false); sy:visibility(false) end)
    VIS.drag[nm] = { x = sx, y = sy }
end
VIS.drag_reset = g_visual:button(ui.get_icon"rotate-left" .. "  Reset panel positions", nil, true)
g_visual:label("\aA0A6B4FF  open the menu and drag any panel with the mouse")
pcall(function()
    VIS.keybinds_nl:tooltip("Reads ui.get_binds() and lists every active NL bind with its mode (hold / toggle) plus the script's own states.")
    VIS.side_ind:tooltip("Vertical list at the left screen edge stacking upward: DT (fill = charge), HS, FS, FD, DA, PING, LC, DMG. The center indicator stays minimal.")
    VIS.md_ind:tooltip("Shows the current NL Min. Damage above-right of the crosshair while a Min. Damage bind is active or an override is set (Andromeda / spectral).")
end)
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
g_visual:label("\aA0A6B4FF  Hit Marker Sound / Force Thirdperson: set them in the NL Visuals tab")
-- V1.7: self-glow toggle dropped — NL glow is a multi-value combo, our :override(true)
-- on a combo silently no-op'd. Users can configure glow directly in NL Visuals tab.

-- ══════════════════════════════════════════════════════════════════════════
-- QOL UI
-- ══════════════════════════════════════════════════════════════════════════
g_qol:label(accent .. ui.get_icon"sparkles" .. accent .. "  Quality of Life")
local qol_clantag    = g_qol:switch("Animated clantag (Sel01 cycle)", false)
local qol_clantag_st = g_qol:combo("Clantag style", {"Wave", "Spin", "Pulse", "Loading", "Scan", "Glitch", "Arrow", "Rage", "Typewriter (custom text)"}, 1)
-- V2.0: dropped killsay + autoaccept + buybot — NL has these built-in (Misc tab).

-- ══════════════════════════════════════════════════════════════════════════
-- INFO UI
-- ══════════════════════════════════════════════════════════════════════════
-- v4.0: 📋 Copy Last Logs — the Solver-style one-click share dump (hits taken with the
-- full engine snapshot, attacker table, timeline, NL live values, hints) → clipboard.
-- v5.0: short inline (alt-style) buttons — long labels got cut off in the NL column
local btn_copy   = g_info:button(ui.get_icon"clipboard" .. "  Copy Last Logs", nil, true)
local btn_status = g_info:button(ui.get_icon"circle-info" .. "  Status", nil, true)
local btn_stats  = g_info:button(ui.get_icon"chart-simple" .. "  Dump Stats", nil, true) -- V2.6
local btn_clear  = g_info:button(ui.get_icon"eraser" .. "  Clear Stats", nil, true) -- V2.6
local btn_recom  = g_info:button(ui.get_icon"lightbulb" .. "  Tips", nil, true) -- V3.1
local btn_antihs = g_info:button(ui.get_icon"skull" .. "  Anti-HS Bundle", nil, true) -- V3.1
local btn_reset  = g_info:button(ui.get_icon"rotate-left" .. "  Reset to Nyanza", nil, true)
pcall(function()
    btn_copy:tooltip("Hits taken with the full engine snapshot, attacker table, timeline, NL live values and hints → clipboard + nl/Sel01-Config/last_logs.txt")
    btn_recom:tooltip("Data-driven hints from this session's hits taken.")
    btn_reset:tooltip("Applies the Nyanza Snapshot preset (= the element defaults).")
end)
cfg_vc_label = g_info:label("\aAAAAAAFFv" .. SEL01_CFG_VERSION .. " - checking for updates...")
g_info:label("\aA0A6B4FF  Sel01-Solver = resolving (own tab)  ·  this script = AA / Misc / Visuals")

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
    -- v4.0: Yaw combo ("Disabled"/"Backward"/"Static") + Body Yaw > Freestanding combo
    -- ("Off"/"Peek Fake"/"Peek Real") + DT lag options + extended angles master
    nl_refs.aa_bodyyaw_fs    = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Freestanding")
    nl_refs.aa_extended      = nl_find_safe("Aimbot", "Anti Aim", "Angles", "Extended Angles")
    nl_refs.rage_dtlag       = nl_find_safe("Aimbot", "Ragebot", "Main", "Double Tap", "Lag Options")
    nl_refs.rage_dt_fl       = nl_find_safe("Aimbot", "Ragebot", "Main", "Double Tap", "Fake Lag Limit")
    nl_refs.rage_hs          = nl_find_safe("Aimbot", "Ragebot", "Main", "Hide Shots")
    nl_refs.rage_hs_opts     = nl_find_safe("Aimbot", "Ragebot", "Main", "Hide Shots", "Options")
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
    nl_refs.misc_fakelat     = nl_find_safe("Miscellaneous", "Main", "Other", "Fake Latency")
    -- V3.15: rage_mindmg re-added READ-ONLY for the dump display. The V3.5 removal was
    -- to stop WRITING NL min-damage (never-override rule) — reading via :get() is safe.
    -- Verified path "Min. Damage" (was the wrong key before → dump showed MinDmg=?).
    nl_refs.rage_mindmg      = nl_find_safe("Aimbot", "Ragebot", "Selection", "Min. Damage")
    nl_refs.rage_autowall    = nl_find_safe("Aimbot", "Ragebot", "Selection", "Penetrate Walls")
    nl_refs.rage_bodyaim     = nl_find_safe("Aimbot", "Ragebot", "Safety", "Body Aim")
    nl_refs.rage_safepoint   = nl_find_safe("Aimbot", "Ragebot", "Safety", "Safe Points")
    nl_refs.rage_hitsafety   = nl_find_safe("Aimbot", "Ragebot", "Safety", "Ensure Hitbox Safety")
    nl_refs.rage_autoscope   = nl_find_safe("Aimbot", "Ragebot", "Accuracy", "Auto Scope")
    -- v5.0 (paths verified across evalate / DEMONTIME / nexus / Andromeda dumps)
    nl_refs.misc_airstrafe   = nl_find_safe("Miscellaneous", "Main", "Movement", "Air Strafe")
    nl_refs.rage_as_ssg_opts = nl_find_safe("Aimbot", "Ragebot", "Accuracy", "SSG-08", "Auto Stop", "Options")
    nl_refs.rage_as_opts     = nl_find_safe("Aimbot", "Ragebot", "Accuracy", "Auto Stop", "Options")
    nl_refs.misc_clantag     = nl_find_safe("Miscellaneous", "Main", "In-Game", "Clan Tag")
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
local pending_preset = nil  -- v5.0: "nyanza" / "aggressive" / "unrivaled" / "sata" / "everlast" / "spin" / "troll"
local pending_def_shuffle = false   -- v5.0: Shuffle choke steps button (drained from createmove)
pcall(function() AA.def_shuffle:set_callback(function() pending_def_shuffle = true end) end)

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

-- v4.0: presets are DATA. A state cfg lists every per-state element by key; missing keys
-- fall back to the Dynamic defaults so every preset writes every field (deterministic —
-- no leftovers from whatever preset ran last, the v9.96 lesson).
local function aa_apply_state(key, cfg)
    local S = AA.st[key]
    if not S then return end
    local base = AA.STATE_DEFAULTS[key] or {}
    local glob = AA.STATE_DEFAULTS.global
    -- v5.0 shorthand: seq = {5,5,2,2,20} expands to sw_seq1..6 (0 = unused)
    if cfg.seq then
        cfg = setmetatable({}, { __index = cfg })
        for i = 1, 6 do cfg["sw_seq" .. i] = cfg.seq[i] or 0 end
    end
    for field, el in pairs(S) do
        local v = cfg[field]
        if v == nil then v = base[field] end
        if v == nil then v = glob[field] end
        if v ~= nil then safe_set(el, v) end
    end
end
-- G = global-ish switches shared by all presets; states = per-state cfg tables
local function aa_apply_bundle(b)
    for key, cfg in pairs(b.states) do aa_apply_state(key, cfg) end
    -- states a preset does not mention fall back to the element defaults (Dynamic)
    for _, key in ipairs({ "stand", "move", "slow", "duck", "duckmv", "air", "airduck" }) do
        if not b.states[key] then aa_apply_state(key, {}) end
    end
    if not b.states.global then aa_apply_state("global", {}) end
    local g = b.g or {}
    safe_set(AA.enable,      true)
    safe_set(AA.pitch,       g.pitch      or "Down")
    safe_set(AA.base,        g.base       or "At Target")
    safe_set(AA.dir,         g.dir        or "Backward")
    safe_set(AA.avoid_bs,    g.avoid_bs   ~= false)
    safe_set(AA.legs,        g.legs       or "Sliding")
    safe_set(AA.man_base,    g.man_base   or "Local View")
    safe_set(AA.man_static,  g.man_static == true)
    safe_set(AA.idle_mode,   g.idle_mode  or "Off")
    safe_set(AA.idle_speed,  g.idle_speed or 50)
    safe_set(AA.idle_pitch,  g.idle_pitch or "Down")
    -- defensive
    safe_set(AA.def_enable,  g.def_enable ~= false)
    safe_set(AA.def_mode,    g.def_mode   or "Sequence (random pick)")
    safe_set(AA.def_int,     g.def_int    or 16)
    safe_set(AA.def_lo,      g.def_lo     or 2)
    safe_set(AA.def_hi,      g.def_hi     or 22)
    local seq = g.def_seq or { 6, 22, 19, 11, 16, 6 }
    for i = 1, 6 do safe_set(AA.def_seq[i], seq[i] or 0) end
    safe_set(AA.def_events,  g.def_events ~= false)
    safe_set(AA.def_pause,   g.def_pause  ~= false)
    safe_set(AA.def_clean,   g.def_clean  or "Random +/-12")
    safe_set(AA.def_lag,     g.def_lag    ~= false)
    safe_set(AA.hs_opts,     g.hs_opts    or "Break LC")
    safe_set(AA.air_mode,    g.air_mode   or "Off")
    safe_set(AA.air_n,       g.air_n      or 10)
    safe_set(AA.fix_rechg,   g.fix_rechg  ~= false)
    safe_set(AA.fl_mode,     g.fl_mode    or "Off")
    safe_set(AA.fl_force,    g.fl_force   == true)
    safe_set(AA.fl_dis_dt,   g.fl_dis_dt  ~= false)
    safe_set(AA.fl_dis_hs,   g.fl_dis_hs  ~= false)
    safe_set(AA.fl_dis_st,   g.fl_dis_st  == true)
    safe_set(AA.dh_enable,   g.dh_enable  == true)
    safe_set(AA.dh_pitch,    g.dh_pitch   or "Down 89")
    safe_set(AA.dh_yaw,      g.dh_yaw     or "Sideways +/-90")
    safe_set(AA.dh_cond,     g.dh_cond    or "Hittable threat")
    -- anti-bruteforce / reactions
    safe_set(AA.ab_enable,   g.ab_enable  ~= false)
    safe_set(AA.ab_radius,   g.ab_radius  or 60)
    safe_set(AA.ab_dur,      g.ab_dur     or 5)
    safe_set(AA.ab_flip,     g.ab_flip    ~= false)
    safe_set(AA.ab_limit,    g.ab_limit   ~= false)
    safe_set(AA.ab_delay,    g.ab_delay   == true)
    safe_set(AA.ab_yaw,      g.ab_yaw     ~= false)
    safe_set(AA.ab_mode,     g.ab_mode    or "Meta staged (+2/stage, alternating)")
    safe_set(AA.ab_freeze,   g.ab_freeze  == true)
    safe_set(AA.ab_fchance,  g.ab_fchance or 50)
    safe_set(AA.ab_fdur,     g.ab_fdur    or 10)
    safe_set(AA.hit_react,   g.hit_react  ~= false)
    safe_set(AA.hit_dur,     g.hit_dur    or 1500)
    safe_set(AA.hit_nofree,  g.hit_nofree ~= false)
    safe_set(AA.head_prot,   g.head_prot  == true)
    -- safe head / freestanding / legit
    safe_set(AA.sh_enable,   g.sh_enable  ~= false)
    safe_set(AA.sh_knife,    g.sh_knife   ~= false)
    safe_set(AA.sh_zeus,     g.sh_zeus    ~= false)
    safe_set(AA.sh_airduck,  g.sh_airduck == true)
    safe_set(AA.sh_height,   g.sh_height  == true)
    safe_set(AA.sh_hdiff,    g.sh_hdiff   or 36)
    safe_set(AA.sh_yaw,      g.sh_yaw     or 0)
    safe_set(AA.sh_limit,    g.sh_limit   or 3)
    safe_set(AA.sh_inv,      g.sh_inv     == true)
    safe_set(AA.fs_static,   g.fs_static  == true)
    safe_set(AA.onuse,       g.onuse      ~= false)
    safe_set(AA.edge,        g.edge       == true)
    -- anti-hs extras
    safe_set(AA.pitch_jitter,g.pitch_jitter == true)
    safe_set(AA.move_fd,     g.move_fd    == true)
    safe_set(AA.move_fd_thr, g.move_fd_thr or 100)
end
local function vis_apply_all(on_extras)
    safe_set(vis_watermark, true)
    safe_set(vis_indicators, true)
    safe_set(vis_velwarn, true)
    safe_set(vis_aaarrows, true)
    safe_set(vis_hitmarker, true)
    safe_set(vis_hitlog, true)
    safe_set(vis_keybinds, true)
    safe_set(vis_dmgind, true)
    safe_set(vis_specoverlay, true)
    if on_extras then
        safe_set(vis_desyncpct, true)
        safe_set(vis_skeet, true)
        safe_set(vis_netgraph, true)
        safe_set(vis_scopefade, true)
        safe_set(vis_sleeves, true)
        safe_set(vis_menublur, false)
        safe_set(vis_custscope, true)
        safe_set(vis_scope_rot, true)
        safe_set(vis_menuborder, true)
    end
end

-- v5.0: every preset below is a DECODED meta config (gazolina built-ins "Snapper (Nyanza
-- Snapshot)", "Aggressive (xo-yaw)", "Unrivaled (xo-yaw)", "sata" and the everlast/spectral
-- "Author" preset). Values are the real per-state L/R offsets, switch timings and choke
-- tables those luas ship; fields a preset does not name fall back to the Nyanza defaults.
-- State shape: yaw_l / yaw_r = real yaw while the desync side is L / R (meta L/R jitter),
-- seq = side switch sequence in un-choked sends, body_l/r = fake limits.
local AA_PRESETS = {
    -- gazolina "Snapper (Nyanza Snapshot)" = the element defaults
    nyanza = {
        states = {
            global  = { defensive = "On threat" },
            slow    = { defensive = "Always" }, duck = { defensive = "Always" }, duckmv = { defensive = "Always" },
            air     = { defensive = "Always" }, airduck = { defensive = "Always" },
        },
        g = { def_mode = "Sequence (random pick)", def_seq = { 6, 22, 19, 11, 16, 6 }, hs_opts = "Break LC",
              ab_mode = "Meta staged (+2/stage, alternating)", ab_dur = 1, sh_hdiff = 36, sh_limit = 1 },
        vis_extras = false, clantag = true, log = "NYANZA SNAPSHOT applied (gazolina meta default: -25/+40 L/R, 58/58, sequence switch, choke table)",
    },
    -- gazolina "Aggressive (xo-yaw)": random hold per state, 3-Way on crouch, choke 10 / tables
    aggressive = {
        states = {
            global  = { yaw_l = -19, yaw_r = 36, body_l = 60, body_r = 60, body_min = 60, sw_mode = "Random delay", sw_lo = 3, sw_hi = 8, defensive = "Always" },
            move    = { yaw_l = -24, yaw_r = 36, body_l = 60, body_r = 60, sw_mode = "Fixed delay", sw_delay = 4, defensive = "Always" },
            slow    = { yaw_l = -26, yaw_r = 40, body_l = 60, body_r = 60, body_mode = "Jitter (side switch)", sw_mode = "Random delay", sw_lo = 3, sw_hi = 6, defensive = "Always" },
            duck    = { yaw_l = -25, yaw_r = 40, body_l = 60, body_r = 60, yaw_mode = "3-Way", yaw_jit = 15, sw_mode = "Every send", defensive = "Always" },
            duckmv  = { yaw_l = -25, yaw_r = 37, body_l = 60, body_r = 60, body_mag = "Fixed L/R", sw_mode = "Random delay", sw_lo = 4, sw_hi = 14, defensive = "Always" },
            air     = { yaw_l = -24, yaw_r = 26, body_l = 60, body_r = 60, sw_mode = "Random delay", sw_lo = 3, sw_hi = 6, defensive = "Always" },
            airduck = { yaw_l = -17, yaw_r = 37, body_l = 60, body_r = 60, sw_mode = "Random delay", sw_lo = 2, sw_hi = 7, defensive = "Always" },
        },
        g = { def_mode = "Sequence (random pick)", def_seq = { 10, 22, 19, 11, 16, 6 }, hs_opts = "Break LC",
              sh_hdiff = 60, sh_limit = 1, ab_delay = true, hit_dur = 2000 },
        vis_extras = true, clantag = true, log = "AGGRESSIVE xo-yaw applied (gazolina: random hold 3-8, 3-Way crouch, defensive always)",
    },
    -- gazolina "Unrivaled (xo-yaw)": static asymmetric L/R, side follows the body jitter every send
    unrivaled = {
        states = {
            global  = { yaw_l = -23, yaw_r = 38, body_l = 60, body_r = 60, body_min = 60, sw_mode = "Every send", defensive = "Always" },
            move    = { yaw_l = -26, yaw_r = 33, body_l = 60, body_r = 60, sw_mode = "Every send", defensive = "Always" },
            slow    = { yaw_l = -23, yaw_r = 43, body_l = 60, body_r = 60, body_mode = "Jitter (side switch)", sw_mode = "Every send", defensive = "Always" },
            duck    = { yaw_l = -29, yaw_r = 49, body_l = 60, body_r = 60, yaw_mode = "3-Way", yaw_jit = 15, sw_mode = "Every send", defensive = "Always" },
            duckmv  = { yaw_l = -19, yaw_r = 42, body_l = 60, body_r = 60, body_mag = "Fixed L/R", sw_mode = "Every send", defensive = "Always" },
            air     = { yaw_l = -14, yaw_r = 39, body_l = 60, body_r = 60, sw_mode = "Random delay", sw_lo = 3, sw_hi = 6, defensive = "Always" },
            airduck = { yaw_l = -17, yaw_r = 38, body_l = 60, body_r = 60, sw_mode = "Every send", defensive = "Always" },
        },
        g = { def_mode = "Sequence (random pick)", def_seq = { 10, 22, 19, 11, 16, 6 }, hs_opts = "Break LC",
              sh_zeus = false, sh_hdiff = 60, sh_limit = 1, idle_mode = "Spin", idle_speed = 60 },
        vis_extras = false, clantag = true, log = "UNRIVALED xo-yaw applied (gazolina: static L/R every send, warmup spin)",
    },
    -- gazolina "sata": Bobrinho LUT, tick pulses, A/B limits, wild sequences
    sata = {
        states = {
            global  = { yaw_l = -41, yaw_r = 36, yaw_mode = "Bobrinho 6-step", yaw_jit = 56, body_l = 58, body_r = 58, body_min = 58,
                        sw_mode = "Random delay", sw_lo = 2, sw_hi = 11, defensive = "Always" },
            move    = { yaw_l = -22, yaw_r = 44, yaw_mode = "Static", body_l = 58, body_r = 58, sw_mode = "Sequence", seq = { 5, 8 }, defensive = "On threat" },
            slow    = { yaw_l = -26, yaw_r = 67, yaw_mode = "Bobrinho 6-step", yaw_jit = 49, body_l = 58, body_r = 58, body_mode = "Jitter (side switch)",
                        sw_mode = "Sequence", seq = { 6, 22, 9, 6, 22, 9 }, defensive = "Always" },
            duck    = { yaw_l = -29, yaw_r = 44, yaw_mode = "Static", body_mode = "Tick-Switch", body_ticks = 10,
                        body_mag = "Switch A/B (sends)", body_l = 58, body_r = 58, body_min = 46, body_swd = 7,
                        sw_mode = "Fixed delay", sw_delay = 1, defensive = "Always" },
            duckmv  = { yaw_l = -22, yaw_r = 42, yaw_mode = "Spin", yaw_jit = 14, body_mode = "Tick-Switch", body_ticks = 10,
                        body_mag = "Switch A/B (sends)", body_l = 58, body_r = 58, body_min = 46, body_swd = 7,
                        sw_mode = "Random delay", sw_lo = 4, sw_hi = 8, defensive = "Always" },
            air     = { yaw_l = -22, yaw_r = 44, yaw_mode = "Static", body_l = 58, body_r = 58, sw_mode = "Fixed delay", sw_delay = 5, defensive = "On threat" },
            airduck = { yaw_l = -22, yaw_r = 44, yaw_mode = "Random", yaw_jit = 22, body_mode = "Random side",
                        body_mag = "Switch A/B (sends)", body_l = 58, body_r = 58, body_min = 48, body_swd = 22,
                        sw_mode = "Random delay", sw_lo = 11, sw_hi = 22, defensive = "Always" },
        },
        g = { def_mode = "Sequence (random pick)", def_seq = { 18, 7, 19, 11, 7, 21 }, hs_opts = "Break LC",
              sh_hdiff = 36, sh_limit = 1, ab_delay = true },
        vis_extras = false, clantag = true, log = "SATA applied (gazolina chaos: Bobrinho LUT, tick pulses, A/B limits)",
    },
    -- spectral / everlast "Author": center jitter halves, 60/60, every-send switch, Local View on slow-walk
    everlast = {
        states = {
            global  = { yaw_l = -35, yaw_r = 30, yaw_mode = "Static", body_l = 60, body_r = 60, body_min = 60, sw_mode = "Every send", defensive = "Off" },
            move    = { yaw_l = -25, yaw_r = 30, yaw_mode = "Center Jitter", yaw_jit = 24, body_l = 60, body_r = 60, sw_mode = "Every send", defensive = "Off" },
            slow    = { base = "Local View", yaw_l = 0, yaw_r = 0, yaw_mode = "Center Jitter", yaw_jit = 8, body_l = 60, body_r = 60,
                        body_mode = "Jitter (side switch)", sw_mode = "Fixed delay", sw_delay = 2, defensive = "Always" },
            duck    = { yaw_l = -19, yaw_r = 46, yaw_mode = "Static", body_l = 60, body_r = 60, sw_mode = "Fixed delay", sw_delay = 2, defensive = "Always" },
            duckmv  = { yaw_l = 0, yaw_r = 13, yaw_mode = "Center Jitter", yaw_jit = 46, body_l = 60, body_r = 60, body_mag = "Fixed L/R",
                        sw_mode = "Fixed delay", sw_delay = 4, defensive = "Always" },
            air     = { yaw_l = -40, yaw_r = 30, yaw_mode = "Center Jitter", yaw_jit = 13, body_l = 60, body_r = 60, sw_mode = "Every send", defensive = "Always" },
            airduck = { yaw_l = 3, yaw_r = 13, yaw_mode = "Center Jitter", yaw_jit = 51, body_l = 60, body_r = 60, sw_mode = "Every send", defensive = "Always" },
        },
        g = { def_mode = "Fixed N", def_int = 16, hs_opts = "Break LC", dh_enable = true, dh_pitch = "Progressive", dh_yaw = "Povorotniki",
              sh_zeus = false, sh_hdiff = 36, sh_limit = 3, ab_mode = "Increase +5..15" },
        vis_extras = false, clantag = true, log = "EVERLAST AUTHOR applied (spectral: center-jitter halves, 60/60, progressive / povorotniki hidden angles)",
    },
    -- spinbot: NL Spin modifier, random magnitude, every-send switch, no freestanding
    spin = {
        states = {
            global  = { yaw_mode = "Spin", yaw_jit = 40, yaw_rand = 0,
                        body_mode = "Jitter (side switch)", body_mag = "Random Min-Max", body_l = 60, body_r = 60, body_min = 30,
                        sw_mode = "Every send", freestand = false, defensive = "Always" },
            air     = { use_global = false, yaw_mode = "Spin", yaw_jit = 60, yaw_rand = 0,
                        body_mode = "Random side", body_mag = "Random Min-Max", body_l = 60, body_r = 60, body_min = 30,
                        sw_mode = "Every send", freestand = false, defensive = "Always" },
            stand = { use_global = true }, move = { use_global = true }, slow = { use_global = true },
            duck  = { use_global = true }, duckmv = { use_global = true }, airduck = { use_global = true },
        },
        g = { avoid_bs = false, fl_mode = "Fluctuate 1 / 14", ab_enable = false, hit_react = false, idle_mode = "Spin", sh_enable = false },
        vis_extras = false, clantag = true, log = "SPIN preset applied (NL Spin modifier, no freestanding)",
    },
    -- bait: everything random, run in and watch who resolves it. Not competitive.
    troll = {
        states = {
            global  = { yaw_mode = "Random", yaw_jit = 90, yaw_rand = 30,
                        body_mode = "Random side", body_mag = "Random Min-Max", body_l = 60, body_r = 60, body_min = 10,
                        sw_mode = "Every send", freestand = false, defensive = "Always" },
            stand = { use_global = true }, move = { use_global = true }, slow = { use_global = true },
            duck  = { use_global = true }, duckmv = { use_global = true }, air = { use_global = true },
            airduck = { use_global = true },
        },
        g = { avoid_bs = false, def_mode = "Fixed N", def_int = 2, def_clean = "Random + flick 60-72", air_mode = "gingersense (every tick + tp/6)",
              fl_mode = "Fluctuate 1 / 14", dh_enable = true, dh_pitch = "Random", dh_yaw = "Spin",
              dh_cond = "Always", ab_delay = true, pitch_jitter = true, move_fd = true, move_fd_thr = 50,
              idle_mode = "Distortion (sine)", sh_enable = false },
        vis_extras = false, clantag = true, clantag_style = "Spin", troll = true,
        log = "TROLL/BAIT preset applied - max chaos. Run / slow-walk in + watch who whiffs.",
    },
}

local function _do_apply_preset(name)
    cs_log("[apply] start " .. tostring(name))
    _troll_mode = false  -- reset on every preset; troll re-sets it true below
    local P = AA_PRESETS[name]
    if not P then cs_log("[apply] unknown preset " .. tostring(name)); return end
    _safe_step("aa bundle", function() aa_apply_bundle(P) end)
    _safe_step("visuals",   function() vis_apply_all(P.vis_extras) end)
    safe_set(qol_clantag, P.clantag == true)
    if P.clantag_style then safe_set(qol_clantag_st, P.clantag_style) end
    _troll_mode = P.troll == true
    -- v5.0: the engine owns NL Fake Lag > Enabled now (disablers + Force switch), so the
    -- old hard override(true) here is gone.
    aa_tl_push("PRESET", tostring(name))
    cs_log_color(P.log or (tostring(name) .. " preset applied"))
end

-- Public entry — just queue the work, do not touch UI state from this function.
local function apply_preset(name)
    pending_preset = name
    cs_log("preset '" .. tostring(name) .. "' queued (applies on next tick)")
end
apply_preset_fwd = apply_preset  -- resolve forward-decl

-- ══════════════════════════════════════════════════════════════════════════
-- AA ENGINE (v4.0) — ONE createmove pass, every tick:
--   state → threat/defensive tracking → side switch (un-choked sends) → yaw →
--   body yaw → head-safe / manual / idle → NL :override writes → force_defensive →
--   DT lag / hidden angles → fake lag → anti-HS extras.
-- Never writes cmd angle fields (v1.6 CTD) — only NL's own Anti Aim elements via
-- :override, plus the documented cmd.force_defensive bool and rage.antiaim /
-- rage.exploit calls that nyanza / angelnbone / gingersense use on this build.
-- ══════════════════════════════════════════════════════════════════════════
local aa_yaw_jitter_counter = 0   -- drives the crosshair arrow animation
local aa_jitter_dir         = 1   -- -1 = left, +1 = right (engine side)

-- type-guarded override (realsilentff pattern): combo=string, switch=bool,
-- slider=number, multi-select=table. A wrong type on an NL element is how v2.2
-- segfaulted; this refuses instead of crashing.
local function aa_ov(ref, v)
    if not ref then return false end
    if v == nil then return pcall(function() ref:override() end) end
    local cur
    if not pcall(function() cur = ref:get() end) then return false end
    if type(cur) ~= type(v) then return false end
    return pcall(function() ref:override(v) end)
end
-- combo override with label aliases (option labels vary slightly per NL build)
local function aa_ov_str(ref, ...)
    if not ref then return false end
    local cur
    if not pcall(function() cur = ref:get() end) then return false end
    if type(cur) ~= "string" then return false end
    for i = 1, select("#", ...) do
        local s = select(i, ...)
        if s and pcall(function() ref:override(s) end) then return true end
    end
    return false
end

local AA_REF_KEYS = { "aa_enabled", "aa_pitch", "aa_yaw", "aa_yaw_base", "aa_yaw_offset",
    "aa_avoidbackstab", "aa_yawmod", "aa_yawmod_offset", "aa_bodyyaw", "aa_bodyyaw_inv",
    "aa_bodyyaw_l", "aa_bodyyaw_r", "aa_bodyyaw_opts", "aa_freestand", "aa_leg_movement",
    "aa_yaw_hidden", "fl_limit", "rage_dtlag", "aa_fakeduck",
    -- v5.0
    "aa_free_disab_ym", "aa_free_body", "rage_hs_opts", "rage_dt_fl", "fl_switch" }
local function aa_clear_overrides()
    for _, k in ipairs(AA_REF_KEYS) do nl_clear(nl_refs[k]) end
    pcall(function() rage.antiaim:override_hidden_yaw_offset(0) end)
    pcall(function() rage.antiaim:override_hidden_pitch(0) end)
    aa_eng.fl_active, aa_eng.dtlag_active, aa_eng.hidden_active, aa_eng.fd_active = false, false, false, false
    aa_eng.fs_static_active, aa_eng.hs_active, aa_eng.fl_dis_active, aa_eng.air_fd_active, aa_eng.air_fl_active = false, false, false, false, false
    aa_eng.fl_base = nil
end

-- state: air via anim-state on_ground (no landing flicker), duck via m_flDuckAmount
-- or the NL Fake Duck key, slow-walk via the NL Slow Walk key, run via 2D speed.
local function aa_get_state(lp, cmd)
    local flags, vel, duck_amt = 0, 0, 0
    pcall(function()
        flags = lp.m_fFlags or 0
        local v = lp.m_vecVelocity
        vel = math.sqrt((v.x or 0) ^ 2 + (v.y or 0) ^ 2)
        duck_amt = lp.m_flDuckAmount or 0
    end)
    local airborne = (bit.band(flags, 1) == 0)
    pcall(function()
        local as = lp:get_anim_state()
        if as and as.on_ground ~= nil then
            airborne = not (as.on_ground and not as.landed_on_ground_this_frame)
        end
    end)
    pcall(function() if cmd and cmd.in_jump and not airborne and bit.band(flags, 1) == 0 then airborne = true end end)
    local ducked = duck_amt > 0.4 or bit.band(flags, 4) == 4
    pcall(function() if nl_refs.aa_fakeduck and nl_refs.aa_fakeduck:get() then ducked = true end end)
    local slow = false
    pcall(function() slow = (nl_refs.aa_slowwalk and nl_refs.aa_slowwalk:get()) and true or false end)
    local key
    if airborne then key = ducked and "airduck" or "air"
    elseif vel > 3.63 then key = ducked and "duckmv" or (slow and "slow" or "move")
    else key = ducked and "duck" or "stand" end
    return key, airborne, ducked, vel, slow
end

-- hittable threat + cached name / origin / distance (read in createmove context, the
-- safe place; player_hurt only reuses the cache — never reads the attacker entity)
local function aa_update_threat(lp)
    local th = nil
    pcall(function() th = entity.get_threat(true) end)
    aa_eng.threat = th
    if th then
        pcall(function()
            aa_eng.threat_name = tostring(th:get_name() or "?")
            local o, lo = th:get_origin(), lp:get_origin()
            aa_eng.threat_x, aa_eng.threat_y, aa_eng.threat_z = o.x, o.y, o.z
            aa_eng.threat_dist = math.sqrt((o.x - lo.x) ^ 2 + (o.y - lo.y) ^ 2 + (o.z - lo.z) ^ 2)
        end)
    else
        aa_eng.threat_dist = 0
    end
    return th
end

-- defensive discharge detection: m_nTickBase runs BACKWARDS on a defensive tick
-- (angelnbone / gingersense). aa_eng.defensive = how many ticks the shift is.
local function aa_track_defensive(lp)
    local tb = 0
    pcall(function() tb = lp.m_nTickBase or 0 end)
    if math.abs(tb - aa_eng.max_tickbase) > 64 then aa_eng.max_tickbase = 0 end
    local n = 0
    if tb > aa_eng.max_tickbase then aa_eng.max_tickbase = tb
    elseif tb < aa_eng.max_tickbase then n = math.min(14, math.max(0, aa_eng.max_tickbase - tb - 1)) end
    aa_eng.defensive = n
    if n > 0 then aa_eng.stats.def_ticks = aa_eng.stats.def_ticks + 1 end
end

local AA_DIR_ADD = { Backward = 0, Left = 90, Right = -90, Forward = 180 }
local AA_MAN_YAW = { L = -90, R = 90, F = 180, B = 0 }

-- v5.0 helpers (locals, defined before the engine so the closure binds them)
-- Safe Head condition (Andromeda / nexus / gazolina / evalate): knife, zeus, air-crouch
-- or a height advantage over the tracked threat.
local function aa_safe_head_check(lp, key, airborne, ducked)
    if not AA.sh_enable:get() then return false, "" end
    local wtype, wclass = -1, ""
    pcall(function()
        local w = lp:get_player_weapon()
        if not w then return end
        local inf = w:get_weapon_info()
        if inf then wtype = tonumber(inf.weapon_type) or -1 end
        wclass = tostring(w:get_classname() or "")
    end)
    local zeus = (wclass == "CWeaponTaser")
    if AA.sh_knife:get() and wtype == 0 and not zeus then return true, "knife" end
    if AA.sh_zeus:get() and zeus then return true, "zeus" end
    if AA.sh_airduck:get() and airborne and ducked then return true, "air-crouch" end
    if AA.sh_height:get() and aa_eng.threat ~= nil then
        local lz = 0
        pcall(function() lz = lp:get_origin().z end)
        if lz - (aa_eng.threat_z or lz) >= AA.sh_hdiff:get() then return true, "height" end
    end
    return false, ""
end

-- Legit AA on +use: block when the E press is a real interaction (evalate / spectral)
local function aa_onuse_blocked(lp, cmd)
    local blocked = false
    pcall(function()
        local w = lp:get_player_weapon()
        local inf = w and w:get_weapon_info()
        if inf and tonumber(inf.weapon_type) == 7 then blocked = true; return end   -- C4 in hand = planting
        -- CT next to a planted bomb = defusing
        if (lp.m_iTeamNum or 0) == 3 then
            local lo = lp:get_origin()
            local bombs = entity.get_entities("CPlantedC4")
            if bombs then
                for _, b in ipairs(bombs) do
                    local bo = b:get_origin()
                    if bo and (bo.x - lo.x) ^ 2 + (bo.y - lo.y) ^ 2 + (bo.z - lo.z) ^ 2 < 120 * 120 then blocked = true; return end
                end
            end
        end
        -- usable entity in front of the eyes (door / button / weapon / hostage / c4)
        local eye = lp:get_eye_position()
        local ang = nil
        pcall(function() ang = cmd and cmd.view_angles end)
        if not ang then pcall(function() ang = render.camera_angles() end) end
        if eye and ang then
            local fwd = vector():angles(ang.x, ang.y)
            local tr = utils.trace_line(eye, eye + fwd * 128, lp)
            local e = tr and tr.entity
            if e then
                local cn = tostring(e:get_classname() or ""):lower()
                if cn:find("door") or cn:find("button") or cn:find("weapon") or cn:find("hostage")
                   or cn:find("c4") or cn:find("defuser") or cn:find("ammo") then blocked = true end
            end
        end
    end)
    return blocked
end

-- spectral edge yaw: 20 rays at 32u; when 2+ hit a wall, return the yaw delta into it
local AA_EDGE_MASK = 0x400B
local function aa_edge_delta(lp, view_yaw)
    local first, last, n = nil, nil, 0
    local ok = pcall(function()
        local eye = lp:get_eye_position()
        for i = 0, 19 do
            local deg = i * 18
            local dir = vector():angles(0, deg)
            local tr = utils.trace_line(eye, eye + dir * 32, lp, AA_EDGE_MASK)
            if tr and (tr.fraction or 1) < 1 then
                if not first then first = deg end
                last = deg
                n = n + 1
            end
        end
    end)
    if not ok or n < 2 then return nil end
    local mid = (first + last) * 0.5
    local delta = ((-view_yaw + mid + 180) % 360) - 180
    if math.abs(delta) > 90 then return nil end
    return delta
end

local function aa_engine_tick(cmd)
    local on = enable_master:get() and AA.enable:get()
    local lp = on and entity.get_local_player() or nil
    local alive = false
    if lp then pcall(function() alive = lp:is_alive() end) end
    if not (on and lp and alive and globals.is_in_game) then
        if aa_eng.active then
            aa_clear_overrides()
            aa_eng.active = false
            aa_tl_push("ENGINE", on and "dead / not in game → overrides cleared" or "disabled → overrides cleared")
        end
        aa_eng.def_after = 0
        return
    end
    if not aa_eng.active then aa_eng.active = true; aa_tl_push("ENGINE", "active") end

    local now  = globals.realtime or 0
    local tick = globals.tickcount or 0
    local choked, cn = 0, tick
    pcall(function() choked = cmd.choked_commands or globals.choked_commands or 0 end)
    pcall(function() cn = cmd.command_number or tick end)
    local unchoked = (choked == 0)
    aa_yaw_jitter_counter = aa_yaw_jitter_counter + 1

    -- ── 1. state ──
    local key, airborne, ducked, vel, slow = aa_get_state(lp, cmd)
    if key ~= aa_eng.state then
        -- v4.1: the timeline only logs a transition once the previous state lasted 0.3s
        -- (stand↔move flicker at start/stop flooded the first real dump)
        if now - aa_eng.state_since >= 0.3 then
            aa_tl_push("STATE", tostring(aa_eng.state) .. " → " .. key .. string.format(" (vel %.0f)", vel))
        end
        aa_eng.state, aa_eng.state_since = key, now
    end
    local S = AA.st[key]
    if S.use_global and S.use_global:get() then S = AA.st.global end

    -- ── 2. threat / defensive tracking / exploit ──
    local threat = aa_update_threat(lp)
    aa_track_defensive(lp)
    pcall(function() rage.exploit:allow_defensive(true) end)
    pcall(function() aa_eng.charge = rage.exploit:get() or 0 end)
    pcall(function() aa_eng.dt_on = (nl_refs.rage_dt and nl_refs.rage_dt:get()) and true or false end)
    pcall(function() aa_eng.hs_on = (nl_refs.rage_hs and nl_refs.rage_hs:get()) and true or false end)
    local revolver = false
    pcall(function()
        local w = lp:get_player_weapon()
        local inf = w and w:get_weapon_info()
        revolver = (inf and inf.is_revolver) and true or false
    end)

    -- ── 3. reactions (anti-bruteforce entry + hit burst) ──
    if aa_eng.force_side ~= nil and unchoked then
        aa_eng.side = aa_eng.force_side
        aa_eng.force_side = nil
        aa_eng.sw_ctr, aa_eng.sw_need = 0, nil
        aa_eng.body_roll_side = -1
        aa_eng.stats.flips = aa_eng.stats.flips + 1
    end
    local react = now < aa_eng.react_until
    local ab = nil
    for name, e in pairs(aa_eng.ab) do
        if e.until_t > now then
            if not ab then ab = e end
        else
            aa_eng.ab[name] = nil
        end
    end

    -- ── 4. idle AA (warmup / round end without threat / no alive enemy) ──
    local idle = false
    local idle_mode = AA.idle_mode:get()
    if idle_mode ~= "Off" then
        local warm, no_enemy = false, false
        pcall(function() local gr = entity.get_game_rules(); warm = (gr and gr.m_bWarmupPeriod) and true or false end)
        if not warm and now - (aa_eng.enemy_scan_t or 0) > 1.0 then
            aa_eng.enemy_scan_t = now
            pcall(function()
                local ps = entity.get_players(true)
                local alive = false
                for _, p in ipairs(ps or {}) do if p:is_alive() then alive = true; break end end
                aa_eng.no_enemy = not alive
            end)
        end
        no_enemy = aa_eng.no_enemy == true
        if warm or no_enemy or (aa_eng.round_ended and not threat) then idle = true end
    end

    -- ── 5. side switching — counted in UN-CHOKED sends ──
    -- v5.0: Sequence (Nyanza [5,5,2,2,20]) + By sides (evalate: per-side random hold) +
    -- anti-bruteforce Freeze (side held for N sends after a near-miss)
    if unchoked then
        aa_eng.sends = aa_eng.sends + 1
        aa_eng.false_ticks = aa_eng.false_ticks + 1
        aa_eng.bob_i = aa_eng.bob_i % 6 + 1
        local mode = S.sw_mode:get()
        local need
        if mode == "Every send" then need = 1
        elseif mode == "Fixed delay" then need = S.sw_delay:get()
        elseif mode == "Sequence" then
            local seqv = {}
            for i = 1, 6 do local v = S["sw_seq" .. i]:get(); if v > 0 then seqv[#seqv + 1] = v end end
            if #seqv == 0 then seqv[1] = 1 end
            if aa_eng.seq_i > #seqv then aa_eng.seq_i = 1 end
            need = seqv[aa_eng.seq_i]
            aa_eng.seq_n = #seqv
        else
            if not aa_eng.sw_need then
                local lo, hi
                if mode == "By sides" and aa_eng.side == 1 then lo, hi = S.sw_rlo:get(), S.sw_rhi:get()
                else lo, hi = S.sw_lo:get(), S.sw_hi:get() end
                if lo > hi then lo, hi = hi, lo end
                aa_eng.sw_need = math.random(lo, hi)
            end
            need = aa_eng.sw_need
        end
        if ab and ab.delay and AA.ab_delay:get() then need = math.max(1, need + ab.delay) end
        aa_eng.sw_ctr = aa_eng.sw_ctr + 1
        local frozen = aa_eng.sends < aa_eng.freeze_until
        if aa_eng.sw_ctr >= need and not frozen then
            aa_eng.sw_ctr, aa_eng.sw_need = 0, nil
            aa_eng.side = 1 - aa_eng.side
            aa_eng.switches = aa_eng.switches + 1
            aa_eng.last_switch_t = now
            aa_eng.body_roll_side = -1          -- new random magnitude on every switch
            if mode == "Sequence" then aa_eng.seq_i = aa_eng.seq_i % math.max(1, aa_eng.seq_n or 1) + 1 end
        end
        -- Switch A/B magnitude counter
        aa_eng.swab_ctr = aa_eng.swab_ctr + 1
        if aa_eng.swab_ctr >= S.body_swd:get() then
            aa_eng.swab_ctr = 0
            aa_eng.swab_state = 3 - aa_eng.swab_state
        end
    end
    local side = aa_eng.side   -- 0 = left (inverter ON), 1 = right

    -- ── 6. yaw ──
    local dir_add = AA_DIR_ADD[AA.dir:get()] or 0
    local yaw = (side == 0) and S.yaw_l:get() or S.yaw_r:get()
    local rnd = S.yaw_rand:get()
    if rnd > 0 then yaw = yaw + math.random(0, rnd) end
    local jit = math.floor(S.yaw_jit:get())
    local ymode = S.yaw_mode:get()
    local mod_str, mod_amt = "Disabled", 0
    if ymode == "Center Jitter" then yaw = yaw + ((side == 1) and jit / 2 or -jit / 2)
    elseif ymode == "Offset Jitter" then yaw = yaw + ((side == 1) and jit or 0)
    elseif ymode == "Random" then if jit > 0 then yaw = yaw + math.random(-jit, jit) end
    elseif ymode == "3-Way" then mod_str, mod_amt = "3-Way", jit
    elseif ymode == "5-Way" then mod_str, mod_amt = "5-Way", jit
    elseif ymode == "Spin" then mod_str, mod_amt = "Spin", jit
    elseif ymode == "Bobrinho 6-step" then
        -- gazolina LUT {-x, -x/2, -x/3, x/3, x/2, x} indexed by the un-choked send counter
        local x = jit
        yaw = yaw + ({ -x, -x / 2, -x / 3, x / 3, x / 2, x })[aa_eng.bob_i]
    end
    -- per-state yaw base (v5.0)
    local base_str = S.base:get()
    if base_str == "Global" then base_str = AA.base:get() end
    if ab and ab.yaw and AA.ab_yaw:get() then yaw = yaw + ab.yaw end
    -- gingersense "clean records": after a discharge with a threat, garbage yaw for 11-17 ticks
    if aa_eng.defensive > 0 then aa_eng.def_state = true end
    if aa_eng.def_state and aa_eng.defensive < 1 and threat then
        local span = tick % 7 + 11
        aa_eng.def_after = tick + span
        aa_eng.def_state = false
        if now - (aa_eng.def_log_t or 0) > 1.0 then
            aa_eng.def_log_t = now
            aa_tl_push("DEF", string.format("discharge seen (threat %s) → clean records %d ticks", aa_eng.threat_name, span))
        end
    end
    local clean = AA.def_clean:get()
    if aa_eng.def_after >= tick and clean ~= "Off" and not idle then
        local adj = math.random(-9, 12)
        if clean == "Random + flick 60-72" and (tick % math.random(15, 16) == 1) then adj = math.random(60, 72) end
        yaw = yaw + adj
    end
    yaw = yaw + dir_add

    -- ── 7. body yaw ──
    local bmode = S.body_mode:get()
    local body_on = (bmode ~= "Off (no desync)")
    local inv = (side == 0)
    if bmode == "Random side" then
        if unchoked and aa_eng.sends % math.random(3, 7) == 0 then aa_eng.rand_inv = not aa_eng.rand_inv end
        inv = aa_eng.rand_inv and true or false
    elseif bmode == "Tick-Switch" then
        -- spectral / gazolina "Ticks": body yaw OFF for 2 ticks every period
        body_on = (tick % math.max(2, S.body_ticks:get()) > 1)
    elseif bmode == "Static side" then
        inv = true
    end
    local mag_mode = S.body_mag:get()
    local L, R = S.body_l:get(), S.body_r:get()
    if mag_mode == "Random Min-Max" then
        if aa_eng.body_roll_side ~= side or aa_eng.body_roll_state ~= key then
            local mn = S.body_min:get()
            aa_eng.body_l = math.random(math.min(mn, L), L)
            aa_eng.body_r = math.random(math.min(mn, R), R)
            aa_eng.body_roll_side, aa_eng.body_roll_state = side, key
        end
        L, R = aa_eng.body_l, aa_eng.body_r
    elseif mag_mode == "Bimodal A/B" then
        if now >= aa_eng.bimodal_next then
            aa_eng.bimodal_mode = 3 - aa_eng.bimodal_mode
            aa_eng.bimodal_next = now + 2.0 + math.random() * 3.0
        end
        local mn, wob = S.body_min:get(), math.random(-3, 3)
        if aa_eng.bimodal_mode == 1 then L, R = mn + wob, mn + wob else L, R = L + wob, R + wob end
    elseif mag_mode == "Switch A/B (sends)" then
        -- gazolina Limit Switch: alternate A (L/R) and B (Min) every N un-choked sends
        if aa_eng.swab_state == 2 then local mn = S.body_min:get(); L, R = mn, mn end
    end
    if ab and ab.limit and AA.ab_limit:get() then L, R = ab.limit, ab.limit end
    local free = S.freestand:get() and true or false
    if AA.fs_key:get() then free = true end
    if react and AA.hit_nofree:get() then free = false end

    -- ── 7b. Safe Head (v5.0) — knife / zeus / air-crouch / height: head behind the body ──
    local sh_on, sh_why = aa_safe_head_check(lp, key, airborne, ducked)
    if sh_on and not idle then
        yaw = AA.sh_yaw:get()
        base_str = "At Target"
        mod_str, mod_amt = "Disabled", 0
        body_on, inv = true, AA.sh_inv:get() and true or false
        L, R = AA.sh_limit:get(), AA.sh_limit:get()
        free = false
        aa_eng.stats.sh_ticks = aa_eng.stats.sh_ticks + 1
        if not aa_eng.sh_active then aa_tl_push("SAFEHEAD", "on (" .. sh_why .. ")") end
    elseif aa_eng.sh_active then
        aa_tl_push("SAFEHEAD", "off")
    end
    aa_eng.sh_active = sh_on and not idle

    -- ── 7c. Edge yaw (v5.0, spectral) ──
    aa_eng.edge_active = false
    if AA.edge:get() and not sh_on and not airborne and not idle then
        local vy = 0
        pcall(function() vy = cmd.view_angles.y end)
        local d = aa_edge_delta(lp, vy)
        if d then
            yaw = yaw + d * 2 + 180
            base_str = "Local View"
            aa_eng.edge_active = true
        end
    end

    -- ── 8. head-safe pulses (gingersense head protection) ──
    aa_eng.hp.active = false
    if AA.head_prot:get() and choked < 3 and threat and not idle then
        local t_ready, we_ready = false, false
        pcall(function()
            local ct = globals.curtime or 0
            local tw = threat:get_player_weapon()
            t_ready = (tw and ((tw.m_flNextPrimaryAttack or 0) <= ct + 0.2)) and true or false
            we_ready = (lp.m_flNextAttack or 0) <= ct
        end)
        if aa_eng.hp.delay <= 0 and t_ready and we_ready then
            aa_eng.hp.active = true
            if aa_eng.hp.hold > 0 then
                yaw = aa_eng.hp.yaw
                aa_eng.hp.hold = aa_eng.hp.hold - 1
            else
                yaw = ((vel > 5) and math.random(-4, 6) or (3 + tick % 3)) + dir_add
                aa_eng.hp.yaw, aa_eng.hp.hold = yaw, 1 + tick % 2
                aa_eng.hp.delay = 6 + math.random(1, 9)
                aa_eng.stats.hp_pulses = aa_eng.stats.hp_pulses + 1
            end
            L, R, inv = 60, 60, true
            body_on = (tick % 2 == 0)
            mod_str, mod_amt = "Disabled", 0
        else
            aa_eng.hp.delay = aa_eng.hp.delay - 1
        end
    end

    -- ── 9. manual keys (replace the yaw, nyanza) + legit AA on +use + idle AA ──
    local man = ""
    pcall(function()
        if AA.key_l:get() then man = "L" elseif AA.key_r:get() then man = "R"
        elseif AA.key_f:get() then man = "F" elseif AA.key_b:get() then man = "B" end
    end)
    if man ~= aa_eng.manual then
        aa_tl_push("MANUAL", man == "" and "released" or ("held " .. man))
        aa_eng.manual = man
    end
    if man ~= "" then
        yaw = AA_MAN_YAW[man]
        base_str, free = AA.man_base:get(), false
        if AA.man_static:get() then
            mod_str, mod_amt = "Disabled", 0
            L, R, body_on = 60, 60, true
            inv = (man ~= "R")
        end
    end
    -- v5.0 legit AA on +use (evalate / spectral / elysian): swallow E, turn the real yaw +180
    local onuse = false
    if AA.onuse:get() and man == "" and not idle then
        local in_use = false
        pcall(function() in_use = cmd.in_use and true or false end)
        if in_use and not aa_onuse_blocked(lp, cmd) then
            onuse = true
            pcall(function() cmd.in_use = false end)
            yaw = yaw + 180
            base_str, free = "Local View", false
            if not aa_eng.onuse_active then aa_eng.stats.onuse = aa_eng.stats.onuse + 1; aa_tl_push("LEGIT", "+use swallowed, yaw +180") end
        end
    end
    aa_eng.onuse_active = onuse
    if idle then
        local sp = math.max(1, AA.idle_speed:get())
        if idle_mode == "Spin" then
            yaw = (tick * math.max(1, math.floor(sp / 5))) % 360 - 180
        elseif idle_mode == "Distortion (sine)" then
            yaw = math.sin(now * sp / 10) * 180
        else -- L/R flip
            yaw = (side == 0) and -90 or 90
        end
        mod_str, mod_amt, body_on, free = "Disabled", 0, false, false
        L, R = 0, 0
        pcall(function() cmd.no_choke = true end)
    end
    yaw = ((yaw + 180) % 360) - 180
    L = math.floor(math.max(0, math.min(60, L)) + 0.5)
    R = math.floor(math.max(0, math.min(60, R)) + 0.5)

    -- ── 10. NL writes ──
    aa_ov(nl_refs.aa_enabled, true)
    local pitch_str = AA.pitch:get()
    if idle then
        local ip = AA.idle_pitch:get()
        pitch_str = (ip == "Fake Up") and "Fake Up" or ((ip == "Down") and "Down" or "Disabled")
    elseif onuse then pitch_str = "Disabled"
    elseif AA.pitch_jitter:get() then pitch_str = (math.floor(aa_eng.sends / 2) % 2 == 0) and "Down" or "Fake Up" end
    aa_ov_str(nl_refs.aa_pitch, pitch_str, "Down")
    aa_ov_str(nl_refs.aa_yaw, "Backward")
    aa_ov_str(nl_refs.aa_yaw_base, base_str, "At Target")
    aa_ov(nl_refs.aa_yaw_offset, math.floor(yaw + 0.5))
    aa_ov_str(nl_refs.aa_yawmod, mod_str, "Disabled")
    aa_ov(nl_refs.aa_yawmod_offset, math.floor(mod_amt))
    aa_ov(nl_refs.aa_bodyyaw, body_on)
    -- our side switching replaces NL's own jitter options; the element takes a table on
    -- most builds and a string on some (nyanza writes "") — try both
    if not aa_ov(nl_refs.aa_bodyyaw_opts, {}) then aa_ov_str(nl_refs.aa_bodyyaw_opts, "") end
    if not aa_ov(nl_refs.aa_bodyyaw_inv, inv) then pcall(function() rage.antiaim:inverter(inv) end) end
    aa_ov(nl_refs.aa_bodyyaw_l, L)
    aa_ov(nl_refs.aa_bodyyaw_r, R)
    aa_ov(nl_refs.aa_freestand, free)
    -- v5.0 static freestanding (elysian / evalate): only the freestanding side moves
    local fs_static = free and AA.fs_static:get()
    if fs_static then
        aa_ov(nl_refs.aa_free_disab_ym, true)
        aa_ov(nl_refs.aa_free_body, false)
        aa_eng.fs_static_active = true
    elseif aa_eng.fs_static_active then
        nl_clear(nl_refs.aa_free_disab_ym); nl_clear(nl_refs.aa_free_body)
        aa_eng.fs_static_active = false
    end
    aa_ov(nl_refs.aa_avoidbackstab, AA.avoid_bs:get() and true or false)
    local legs = AA.legs:get()
    if MISC.anim:get() and MISC.anim_legs:get() then
        -- v5.0 leg breaker owns Leg Movement (post_update_clientside_animation handler)
    elseif legs == "Keep NL" then nl_clear(nl_refs.aa_leg_movement) else aa_ov_str(nl_refs.aa_leg_movement, legs) end
    aa_eng.yaw_w, aa_eng.l_w, aa_eng.r_w = yaw, L, R
    aa_eng.mod_w, aa_eng.modamt_w, aa_eng.free_w, aa_eng.body_w = mod_str, mod_amt, free, body_on
    aa_jitter_dir = inv and -1 or 1

    -- ── 11. defensive pulse (cmd.force_defensive, needs DT on + charged) ──
    -- v5.0: choke tables (Fixed / Random lo..hi / Sequence random pick), game events
    -- (weapon switch / reload), pause after our own shot, Safe Head + legit skip it.
    local dmode = S.defensive:get()
    local want_def = false
    local key_def = false
    pcall(function() key_def = AA.def_key:get() and true or false end)
    local def_ok = AA.def_enable:get() and aa_eng.dt_on and aa_eng.charge >= 1 and not revolver and not idle
        and not sh_on and not onuse
    local def_event = false
    if def_ok and AA.def_events:get() then
        pcall(function()
            local ct = globals.curtime or 0
            if (lp.m_flNextAttack or 0) > ct then def_event = true end
            local w = lp:get_player_weapon()
            if w and w.m_bInReload then def_event = true end
        end)
    end
    local def_paused = AA.def_pause:get() and (now - aa_eng.last_fire_t) < 0.3
    local def_cond = false
    if def_ok then
        def_cond = (dmode == "Always") or (dmode == "On threat" and threat ~= nil) or key_def or react or def_event
        if def_cond and not def_paused then
            local n
            local dm = AA.def_mode:get()
            if dm == "Fixed N" then n = AA.def_int:get()
            elseif dm == "Random lo..hi" then
                local lo, hi = AA.def_lo:get(), AA.def_hi:get()
                if lo > hi then lo, hi = hi, lo end
                n = math.random(lo, hi)
            else
                local seqv = {}
                for i = 1, 6 do local v = AA.def_seq[i]:get(); if v > 0 then seqv[#seqv + 1] = v end end
                n = (#seqv > 0) and seqv[math.random(1, #seqv)] or 16
            end
            n = math.max(1, n)
            if react then n = math.min(n, 2) end
            want_def = (cn % n == 0)
        end
    end
    -- v5.0 air exploit modes
    local am = AA.air_mode:get()
    if am ~= "Off" and airborne and aa_eng.dt_on and not revolver and not idle then
        aa_eng.airlag_ctr = aa_eng.airlag_ctr + 1
        if am == "gingersense (every tick + tp/6)" then
            want_def = true
            pcall(function() rage.exploit:force_charge() end)
            if aa_eng.airlag_ctr % 6 == 0 then pcall(function() rage.exploit:force_teleport() end) end
        elseif am == "evalate (pulse N + fakelag rnd + tp)" then
            if aa_eng.charge >= 1 and tick % math.max(5, AA.air_n:get()) == 0 then
                want_def = true
                aa_ov(nl_refs.rage_dt_fl, math.random(1, 7))
                aa_eng.air_fl_active = true
                pcall(function() rage.exploit:force_teleport() end)
            else
                pcall(function() rage.exploit:force_charge() end)
            end
        elseif am == "elysian (alternate fake duck)" and (aa_eng.dt_on or aa_eng.hs_on) then
            aa_ov(nl_refs.aa_fakeduck, (tick % 2 == 0))
            aa_eng.air_fd_active = true
        end
    else
        if aa_eng.air_fl_active then nl_clear(nl_refs.rage_dt_fl); aa_eng.air_fl_active = false end
        if aa_eng.air_fd_active then nl_clear(nl_refs.aa_fakeduck); aa_eng.air_fd_active = false end
    end
    -- only ever ASSERT true (never write false) so a second script pulsing defensive is not fought
    if want_def then pcall(function() cmd.force_defensive = true end) end
    if want_def and not aa_eng.def_pulse then
        aa_eng.def_pulses = aa_eng.def_pulses + 1
        aa_eng.last_def_t = now
    end
    aa_eng.def_pulse = want_def

    -- DT Lag Options = Always On ("break LC") while the state has defensive enabled and the
    -- weapon can fire (gingersense "Always"), never while Peek Assist is held. Hide Shots >
    -- Options follows the same gate (v5.0). Cleared the moment the condition drops.
    local want_dtlag, want_hs = false, false
    if AA.def_lag:get() and aa_eng.dt_on and not idle and (dmode ~= "Off" or key_def or react) and not sh_on then
        pcall(function()
            local w = lp:get_player_weapon()
            local np = (w and w.m_flNextPrimaryAttack) or 0
            local ready = math.max(np, lp.m_flNextAttack or 0) - (globals.tickinterval or 0.015625) - (globals.curtime or 0) < 0
            local peek = (nl_refs.rage_peek_assist and nl_refs.rage_peek_assist:get()) and true or false
            want_dtlag = ready and not peek and not def_paused
        end)
    end
    if want_dtlag then
        aa_ov_str(nl_refs.rage_dtlag, "Always On", "Always on")
        aa_eng.dtlag_active = true
    elseif aa_eng.dtlag_active then
        nl_clear(nl_refs.rage_dtlag)
        aa_eng.dtlag_active = false
    end
    local hso = AA.hs_opts:get()
    if hso ~= "Keep NL" and aa_eng.hs_on and not idle and (dmode ~= "Off" or key_def or react) and not sh_on then want_hs = true end
    if want_hs then
        aa_ov_str(nl_refs.rage_hs_opts, hso)
        aa_eng.hs_active = true
    elseif aa_eng.hs_active then
        nl_clear(nl_refs.rage_hs_opts)
        aa_eng.hs_active = false
    end

    -- ── 12. hidden angles on defensive records (silent flick) ──
    -- v5.0: 8 pitch + 9 yaw modes (elysian / spectral / evalate / nexus formulas)
    local hid_on = false
    if AA.dh_enable:get() and aa_eng.dt_on and aa_eng.charge >= 1 and not revolver and not idle and not sh_on then
        hid_on = (AA.dh_cond:get() == "Always") or (threat ~= nil)
    end
    if hid_on then
        local pm, hp = AA.dh_pitch:get(), 89
        local par = (aa_eng.sends % 2 == 0)
        local ctime = globals.curtime or now
        if pm == "Up -89" then hp = -89
        elseif pm == "Cycle" then hp = ({ -89, -45, 0, 45, 89 })[cn % 5 + 1]
        elseif pm == "Random" then hp = math.random(-89, 89)
        elseif pm == "Jitter 89/-89" then hp = par and 89 or -89
        elseif pm == "Elysian wave" then hp = -89 + (math.abs(now % 0.3 - 0.15) / 0.15) * 178
        elseif pm == "Progressive" then hp = ((ctime * 7) % 2 - 1) * 89
        elseif pm == "Zero" then hp = 0 end
        local ym, hy = AA.dh_yaw:get(), 90
        if ym == "Sideways +/-90" then hy = (cn % 4 >= 2) and 90 or -90
        elseif ym == "Spin" then hy = (now * math.max(1, math.abs(AA.dh_yaw_val:get())) / 30 * 360) % 360 - 180
        elseif ym == "Random" then hy = math.random(-180, 180)
        elseif ym == "Opposite 180" then hy = 180
        elseif ym == "Jitter (packet parity)" then hy = par and -90 or 90
        elseif ym == "Povorotniki" then
            if tick % 3 == 1 then hy = par and -90 or 90 else hy = par and 90 or -90 end
        elseif ym == "Progressive spin" then hy = ((ctime * 7) % 3 - 1) * 179
        elseif ym == "Sweep -90..90" then
            local t = (now * 0.8) % 2
            hy = (t < 1) and (-90 + 180 * t) or (90 - 180 * (t - 1))
        else hy = AA.dh_yaw_val:get() end
        aa_ov(nl_refs.aa_yaw_hidden, true)
        pcall(function() rage.antiaim:override_hidden_pitch(math.floor(hp + 0.5)) end)
        pcall(function() rage.antiaim:override_hidden_yaw_offset(math.floor(hy + 0.5)) end)
        aa_eng.hidden_active = true
    elseif aa_eng.hidden_active then
        nl_clear(nl_refs.aa_yaw_hidden)
        pcall(function() rage.antiaim:override_hidden_pitch(0) end)
        pcall(function() rage.antiaim:override_hidden_yaw_offset(0) end)
        aa_eng.hidden_active = false
    end

    -- ── 13. fake lag: disablers (v5.0) → fix recharge (v5.0) → per-state limit → variance ──
    local fd_held = false
    pcall(function() fd_held = (nl_refs.aa_fakeduck and nl_refs.aa_fakeduck:get()) and true or false end)
    local want_fl_off = (AA.fl_dis_dt:get() and aa_eng.dt_on) or (AA.fl_dis_hs:get() and aa_eng.hs_on)
        or (AA.fl_dis_st:get() and key == "stand")
    if want_fl_off and not idle then
        aa_ov(nl_refs.fl_switch, false)
        aa_eng.fl_dis_active = true
    elseif AA.fl_force:get() then
        aa_ov(nl_refs.fl_switch, true)
        aa_eng.fl_dis_active = true
    elseif aa_eng.fl_dis_active then
        nl_clear(nl_refs.fl_switch)
        aa_eng.fl_dis_active = false
    end
    local want_rc = AA.fix_rechg:get() and (aa_eng.dt_on or aa_eng.hs_on) and not fd_held and not airborne
        and not revolver and aa_eng.charge < 1 and not idle
    aa_eng.rc_active = want_rc
    local flm, st_fl = AA.fl_mode:get(), S.fakelag:get()
    if want_rc then
        aa_ov(nl_refs.fl_limit, 1)
        aa_eng.fl_active = true
    elseif st_fl > 0 then
        aa_ov(nl_refs.fl_limit, st_fl)
        aa_eng.fl_active = true
    elseif flm == "Fluctuate 1 / 14" then
        local fd = false
        pcall(function() fd = (nl_refs.aa_fakeduck and nl_refs.aa_fakeduck:get()) and true or false end)
        if not fd then
            local v = 5 + tick % 11
            aa_ov(nl_refs.fl_limit, (tick % v == 0) and 1 or 14)
            aa_eng.fl_active = true
        elseif aa_eng.fl_active then
            nl_clear(nl_refs.fl_limit)
            aa_eng.fl_active = false
        end
    elseif flm == "+/-2 around NL value" then
        if now >= (aa_eng.fl_next or 0) then
            aa_eng.fl_next = now + 1.0 + math.random() * 2.0
            if not aa_eng.fl_base then
                local v0 = 5
                pcall(function() v0 = nl_refs.fl_limit:get() or 5 end)
                aa_eng.fl_base = v0
            end
            aa_ov(nl_refs.fl_limit, math.max(1, math.min(14, aa_eng.fl_base + math.random(-2, 2))))
            aa_eng.fl_active = true
        end
    elseif aa_eng.fl_active then
        nl_clear(nl_refs.fl_limit)
        aa_eng.fl_active, aa_eng.fl_base = false, nil
    end

    -- ── 14. auto fake-duck while moving (dirty-tracked, v3.3 falling-edge clear) ──
    local want_fd = AA.move_fd:get() and not airborne and vel > AA.move_fd_thr:get()
    if want_fd and not aa_eng.fd_active then
        aa_ov(nl_refs.aa_fakeduck, true)
        aa_eng.fd_active = true
    elseif (not want_fd) and aa_eng.fd_active then
        nl_clear(nl_refs.aa_fakeduck)
        aa_eng.fd_active = false
    end
end

-- full engine snapshot — attached to every hit taken, printed by Copy Last Logs
local function aa_snapshot()
    local now = globals.realtime or 0
    local lp = entity.get_local_player()
    local vel, airborne, ducked, hp, wname, fl = 0, false, false, 0, "?", "?"
    if lp then
        pcall(function()
            local v = lp.m_vecVelocity
            vel = math.sqrt((v.x or 0) ^ 2 + (v.y or 0) ^ 2)
            airborne = bit.band(lp.m_fFlags or 0, 1) == 0
            ducked = (lp.m_flDuckAmount or 0) > 0.4
            hp = lp.m_iHealth or 0
            local w = lp:get_player_weapon()
            if w then wname = tostring((w.get_name and w:get_name()) or w:get_classname() or "?") end
        end)
    end
    pcall(function() fl = tostring(nl_refs.fl_limit and nl_refs.fl_limit:get() or "?") end)
    local S = AA.st[aa_eng.state] or AA.st.global
    local ug = false
    if S.use_global then pcall(function() ug = S.use_global:get() end) end
    if ug then S = AA.st.global end
    local abn = 0
    for _, e in pairs(aa_eng.ab) do if e.until_t > now then abn = abn + 1 end end
    return {
        engine = aa_eng.active, state = aa_eng.state, state_age = now - aa_eng.state_since, uses_global = ug,
        side = (aa_eng.side == 0) and "L" or "R", since_switch = now - aa_eng.last_switch_t,
        yaw = aa_eng.yaw_w, l = aa_eng.l_w, r = aa_eng.r_w, mod = aa_eng.mod_w, modamt = aa_eng.modamt_w,
        body = aa_eng.body_w, free = aa_eng.free_w,
        yaw_mode = S.yaw_mode:get(), body_mode = S.body_mode:get(), mag_mode = S.body_mag:get(),
        sw_mode = S.sw_mode:get(), def_mode = S.defensive:get(),
        def_pulse = aa_eng.def_pulse, def_ticks = aa_eng.defensive, since_def = now - aa_eng.last_def_t,
        charge = aa_eng.charge, dt = aa_eng.dt_on, hs = aa_eng.hs_on, dtlag = aa_eng.dtlag_active,
        hidden = aa_eng.hidden_active, choked = globals.choked_commands or 0, fl = fl, fl_ov = aa_eng.fl_active,
        threat = aa_eng.threat ~= nil, threat_name = aa_eng.threat_name, threat_dist = aa_eng.threat_dist,
        react = now < aa_eng.react_until, ab = abn, hp_pulse = aa_eng.hp.active, manual = aa_eng.manual,
        vel = math.floor(vel), airborne = airborne, ducked = ducked, hp = hp, weapon = wname,
        pitch = AA.pitch:get(), dir = AA.dir:get(),
        -- v5.0
        safe_head = aa_eng.sh_active, onuse = aa_eng.onuse_active, edge = aa_eng.edge_active,
        frozen = aa_eng.sends < (aa_eng.freeze_until or 0), hs_ov = aa_eng.hs_active, fl_off = aa_eng.fl_dis_active,
        rc = aa_eng.rc_active, seq_i = aa_eng.seq_i, base = S.base:get(),
    }
end
-- 2-line human format shared by the copy dump + Dump Debug Stats
local function aa_fmt_snapshot(s, ind)
    ind = ind or "    "
    if not s or not s.state then return { ind .. "(no engine snapshot)" } end
    local function b(v) return v and "ON" or "off" end
    return {
        string.format("%sstate=%s%s (%.1fs)  side=%s (%.2fs since switch)  yaw=%d  L/R=%d/%d  mod=%s(%d)  body=%s  free=%s  pitch=%s dir=%s",
            ind, tostring(s.state), s.uses_global and "→global" or "", s.state_age or 0, tostring(s.side), s.since_switch or 0,
            math.floor(s.yaw or 0), s.l or 0, s.r or 0, tostring(s.mod), s.modamt or 0, b(s.body), b(s.free),
            tostring(s.pitch), tostring(s.dir)),
        string.format("%smodes: yaw=%s body=%s mag=%s switch=%s def=%s  | DT=%s charge=%.0f%% pulse=%s defticks=%d (%.1fs ago) dtlag=%s hidden=%s HS=%s",
            ind, tostring(s.yaw_mode), tostring(s.body_mode), tostring(s.mag_mode), tostring(s.sw_mode), tostring(s.def_mode),
            b(s.dt), (s.charge or 0) * 100, b(s.def_pulse), s.def_ticks or 0, s.since_def or 0, b(s.dtlag), b(s.hidden), b(s.hs)),
        string.format("%schoke=%d fakelag=%s%s  vel=%d air=%s duck=%s hp=%d wpn=%s  threat=%s%s%s  react=%s ab=%d headsafe=%s manual=%s",
            ind, s.choked or 0, tostring(s.fl), s.fl_ov and "(ov)" or "", s.vel or 0, b(s.airborne), b(s.ducked), s.hp or 0,
            tostring(s.weapon), b(s.threat), s.threat and (" " .. tostring(s.threat_name)) or "",
            s.threat and string.format(" %.0fu", s.threat_dist or 0) or "",
            b(s.react), s.ab or 0, b(s.hp_pulse), s.manual ~= "" and s.manual or "-"),
        string.format("%sv5: base=%s safehead=%s legit=%s edge=%s frozen=%s hs_ov=%s fl_off=%s rechg=%s seq_i=%s",
            ind, tostring(s.base), b(s.safe_head), b(s.onuse), b(s.edge), b(s.frozen), b(s.hs_ov), b(s.fl_off), b(s.rc), tostring(s.seq_i)),
    }
end

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

-- v4.0: yaw_rotation_tick (wrote invalid "Forward/Left/Right" strings to Yaw Base — a
-- silent no-op) and fake_lag_variance_tick are folded into aa_engine_tick (Direction
-- combo = yaw-offset math; Fake-lag variance combo).

-- ══════════════════════════════════════════════════════════════════════════
-- AI PEEK (v4.1) — hold cover → trace-bullet search for a peek point → step out →
-- ragebot fires → back to the anchor. Algorithm follows aiPeek_61044 `ai_peek_func`
-- (candidate points perpendicular to the threat, utils.trace_bullet from the candidate
-- EYE position to enemy hitboxes, NL Min. Damage - 5 threshold, confirm ticks, 25-tick
-- side lock, P-controlled go_to, DT teleport back). The v3.28/3.29 version waited for
-- aim_fire (= enemy already visible = we were already exposed) and then ran TOWARD the
-- enemy on a timer — the opposite of a peek.
-- ══════════════════════════════════════════════════════════════════════════
local ai_peek = {
    anchor = nil,          -- vector: where you stood when the trigger began (cover)
    phase = "off",         -- off | hold | peek | retreat
    side = nil,            -- 0 = left of the threat direction, 1 = right (locked)
    ent = nil,             -- locked enemy entity
    lock_tick = 0,         -- last tick a shot existed (unlock after 25)
    confirm = 0,           -- consecutive ticks with a shot point
    shoot = nil,           -- { pos, hb, side, ent, dmg }
    points = {},           -- candidate positions (for the drawing)
    peek_t0 = 0,           -- when we reached / started moving to the point
    retreat_until = 0, cooldown_until = 0,
    shot_tick = -1,        -- events.aim_fire tick (ragebot committed)
    tele_done = false,
    hc_active = false, sp_active = false,
    dev_t = 0, def_until = {},   -- per-enemy defensive window (sim time went backwards)
    peeks = 0, shots = 0, timeouts = 0,
}

-- weapon filter: combo :get() returns the option STRING (NL convention)
local function ai_peek_weapon_ok(lp)
    local sel = "All"
    pcall(function() sel = AIP.wpn:get() end)
    local name, wtype, can_fire, clip = "", -1, true, 1
    pcall(function()
        local w = lp:get_player_weapon()
        if not w then return end
        name = tostring((w.get_name and w:get_name()) or w:get_classname() or ""):lower()
        local inf = w:get_weapon_info()
        if inf then wtype = tonumber(inf.weapon_type) or -1 end
        can_fire = (w.m_flNextPrimaryAttack or 0) <= (globals.curtime or 0)
        clip = w.m_iClip1
        if clip == nil then clip = 1 end
    end)
    -- weapon_type: 0 knife, 7 c4, 9 grenade, 11 healthshot-ish → never peek with those
    if wtype == 0 or wtype == 7 or wtype == 9 or wtype == 11 then return false, "no gun" end
    if clip == 0 then return false, "empty clip" end
    if not can_fire then return false, "weapon busy" end
    if sel == "All" or name == "" then return true end
    if sel == "Snipers only" then
        return (name:find("ssg") or name:find("awp") or name:find("scar") or name:find("g3sg")) and true or false, "filtered"
    elseif sel == "Pistols only" then
        return (name:find("glock") or name:find("hkp2000") or name:find("usp") or name:find("p250")
            or name:find("fiveseven") or name:find("tec9") or name:find("cz75") or name:find("elite")
            or name:find("deagle") or name:find("revolver")) and true or false, "filtered"
    elseif sel == "Deagle only" then
        return (name:find("deagle") or name:find("revolver")) and true or false, "filtered"
    end
    return true
end

-- raise ragebot HC + optionally drop Safe Points for the peek window only.
-- BREAKS the never-override rule on purpose (user-requested). Restored on (false).
local function ai_peek_set_overrides(on)
    if on then
        local hc = 0
        pcall(function() hc = AIP.hc:get() end)
        if hc and hc > 0 and nl_refs.rage_hc and not ai_peek.hc_active then
            nl_override(nl_refs.rage_hc, hc)
            ai_peek.hc_active = true
        end
        local unsafe = false
        pcall(function() unsafe = AIP.unsafe:get() end)
        if unsafe and nl_refs.rage_safepoint and not ai_peek.sp_active then
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

local function ai_peek_dev(msg, force)
    if not (AIP.dev and AIP.dev:get()) then return end
    local now = globals.realtime or 0
    if not force and now - (ai_peek.dev_t or 0) < 0.5 then return end
    ai_peek.dev_t = now
    cs_log("[AI-Peek] " .. tostring(msg))
end

local function ai_peek_reset(reason)
    if ai_peek.phase ~= "off" then aa_tl_push("AIPEEK", "off (" .. tostring(reason) .. ")") end
    ai_peek_set_overrides(false)
    ai_peek.anchor, ai_peek.side, ai_peek.ent, ai_peek.shoot = nil, nil, nil, nil
    ai_peek.points, ai_peek.confirm, ai_peek.phase = {}, 0, "off"
end

-- P-controlled move toward a world point (WalkBot-style world-space move_yaw; the
-- ragebot keeps aiming freely). Stops dead on the point so NL auto-stop is happy.
local function ai_peek_go_to(cmd, lp, lo, pos)
    local dx, dy = pos.x - lo.x, pos.y - lo.y
    local d = math.sqrt(dx * dx + dy * dy)
    pcall(function() cmd.in_duck = false; cmd.in_jump = false; cmd.in_speed = false end)
    if d < 5 then
        -- angelwings / gazolina quick-stop: thrust AGAINST the current velocity so we
        -- stand dead on the point within a tick (NL auto-stop then has nothing to do)
        pcall(function()
            local v = lp.m_vecVelocity
            local sp = math.sqrt((v.x or 0) ^ 2 + (v.y or 0) ^ 2)
            if sp > 5 then
                cmd.move_yaw = math.deg(math.atan2(v.y, v.x))
                cmd.forwardmove = -math.min(450, sp)
            else
                cmd.forwardmove = 0
            end
            cmd.sidemove = 0
        end)
        return d
    end
    pcall(function()
        cmd.move_yaw = math.deg(math.atan2(dy, dx))
        cmd.forwardmove = (d < 20) and math.max(120, d * 22) or 450
        cmd.sidemove = 0
    end)
    return d
end

local AIP_BRUSH_MASK = 0x400B   -- MASK_SOLID_BRUSHONLY: world geometry only (WalkBot pattern)

local function ai_peek_tick(cmd)
    -- master / feature gate → restore overrides + reset
    if not (cmd and enable_master:get() and AIP.enable and AIP.enable:get()) then
        if ai_peek.phase ~= "off" then ai_peek_reset("disabled") end
        return
    end
    local lp = entity.get_local_player()
    local alive = false
    if lp then pcall(function() alive = lp:is_alive() end) end
    if not alive then
        if ai_peek.phase ~= "off" then ai_peek_reset("dead") end
        return
    end
    local now  = globals.realtime or 0
    local tick = globals.tickcount or 0

    -- v4.2: one bindable switch is the trigger
    local triggered = false
    pcall(function() triggered = AIP.active:get() and true or false end)
    if not triggered then
        if ai_peek.phase ~= "off" then ai_peek_reset("active switch off") end
        return
    end

    local lo, flags, vel = nil, 0, 0
    pcall(function()
        lo = lp:get_origin()
        flags = lp.m_fFlags or 0
        local v = lp.m_vecVelocity
        vel = math.sqrt((v.x or 0) ^ 2 + (v.y or 0) ^ 2)
    end)
    if not lo then return end
    local on_ground = bit.band(flags, 1) ~= 0

    -- manual movement pauses the bot and re-anchors where you stop. v4.2: read the
    -- BUTTON bits (what you press), not forwardmove/sidemove — NL itself writes those
    -- (auto-stop / peek assist), which made v4.1 reset the anchor every tick.
    local user_moving = false
    pcall(function()
        user_moving = (cmd.in_forward or cmd.in_back or cmd.in_moveleft or cmd.in_moveright) and true or false
    end)
    if AIP.keys:get() and user_moving then
        if ai_peek.anchor then ai_peek_reset("manual movement") end
        return
    end

    -- anchor = where you stand when the trigger begins (needs ground + standing still)
    if not ai_peek.anchor then
        if not on_ground or vel > 15 then return end
        ai_peek.anchor = vector(lo.x, lo.y, lo.z)
        ai_peek.phase = "hold"
        ai_peek.peek_t0, ai_peek.tele_done = 0, false
        aa_tl_push("AIPEEK", string.format("anchored at %.0f %.0f %.0f", lo.x, lo.y, lo.z))
        ai_peek_dev("anchored", true)
    end
    local anchor = ai_peek.anchor
    local d_anchor = math.sqrt((lo.x - anchor.x) ^ 2 + (lo.y - anchor.y) ^ 2)

    -- retreat / cooldown phases: drive back, no searching
    local function go_home(why)
        if ai_peek.phase == "peek" then
            ai_peek.phase = "retreat"
            ai_peek.retreat_until = now + 0.6
            ai_peek_set_overrides(false)
            aa_tl_push("AIPEEK", "retreat: " .. tostring(why))
            ai_peek_dev("RETREAT " .. tostring(why), true)
            -- DT teleport back (aiPeek pattern): one shot per retreat, only when charged
            if AIP.dt_tele:get() and not ai_peek.tele_done then
                local ch = 0
                pcall(function() ch = rage.exploit:get() or 0 end)
                if ch >= 1 then pcall(function() rage.exploit:force_teleport() end); ai_peek.tele_done = true end
            end
        end
        if d_anchor > 3 then ai_peek_go_to(cmd, lp, lo, anchor) else pcall(function() cmd.forwardmove = 0; cmd.sidemove = 0 end) end
    end
    if not on_ground then go_home("airborne"); return end
    if ai_peek.phase == "retreat" then
        go_home("continuing")
        if d_anchor <= 3 or now >= ai_peek.retreat_until then
            ai_peek.phase = "hold"
            ai_peek.cooldown_until = now + (AIP.cooldown:get() / 1000)
            ai_peek.side, ai_peek.ent, ai_peek.confirm, ai_peek.shoot = nil, nil, 0, nil
        end
        return
    end
    if now < ai_peek.cooldown_until then go_home("cooldown"); return end

    -- the ragebot committed a shot (events.aim_fire) → retreat immediately
    if AIP.retreat:get() == "After the shot" and ai_peek.phase == "peek" and ai_peek.shot_tick >= ai_peek.peek_tick then
        ai_peek.shots = ai_peek.shots + 1
        go_home("shot fired")
        return
    end

    -- gates that mean "hold / go back": no threat, wrong weapon, weapon busy, DT charging
    local threat = nil
    pcall(function() threat = entity.get_threat() end)
    if not threat then ai_peek.points = {}; ai_peek.shoot = nil; go_home("no threat"); return end
    local wok, wwhy = ai_peek_weapon_ok(lp)
    if not wok then ai_peek.shoot = nil; go_home(wwhy or "weapon"); ai_peek_dev("hold: " .. tostring(wwhy)); return end
    if AIP.dt_wait:get() then
        local dt_on, ch = false, 1
        pcall(function() dt_on = (nl_refs.rage_dt and nl_refs.rage_dt:get()) and true or false end)
        if dt_on then pcall(function() ch = rage.exploit:get() or 0 end) end
        if dt_on and ch < 1 then ai_peek.shoot = nil; go_home("DT charging"); ai_peek_dev("hold: DT charging"); return end
    end

    -- ── candidate peek positions (eye height), perpendicular to the threat ──
    local to = nil
    pcall(function() to = threat:get_origin() end)
    if not to then go_home("no threat origin"); return end
    local yaw_to = math.deg(math.atan2(to.y - anchor.y, to.x - anchor.x))
    local eye_off = 64
    pcall(function() eye_off = lp:get_eye_position().z - lo.z end)
    local dist = AIP.dist:get()
    local points = {}
    local function side_dir(side)
        local a = math.rad(yaw_to + ((side == 0) and -90 or 90))
        return math.cos(a), math.sin(a)
    end
    local function traced_point(fx, fy, fz, tx, ty, tz)
        local ex, ey, ez, frac = tx, ty, tz, 1
        pcall(function()
            local tr = utils.trace_line(vector(fx, fy, fz), vector(tx, ty, tz), lp, AIP_BRUSH_MASK)
            if tr and tr.end_pos then ex, ey, ez, frac = tr.end_pos.x, tr.end_pos.y, tr.end_pos.z, tr.fraction or 1 end
        end)
        return ex, ey, ez, frac
    end
    local az = anchor.z + eye_off
    if ai_peek.side ~= nil then
        -- locked side: 7 steps along it so we peek only as far as needed
        local cx, cy = side_dir(ai_peek.side)
        local px, py = anchor.x, anchor.y
        for i = 1, 7 do
            local nx, ny, nz, frac = traced_point(px, py, az, px + cx * dist / 7, py + cy * dist / 7, az)
            points[#points + 1] = { x = nx, y = ny, z = nz, side = ai_peek.side }
            px, py = nx, ny
            if frac < 1 then break end
        end
    else
        for side = 0, 1 do
            local cx, cy = side_dir(side)
            local nx, ny, nz = traced_point(anchor.x, anchor.y, az, anchor.x + cx * dist, anchor.y + cy * dist, az)
            points[#points + 1] = { x = nx, y = ny, z = nz, side = side }
        end
    end
    ai_peek.points = points

    -- ── trace bullets: candidate eye → enemy hitboxes, need NL Min. Damage - 5 ──
    local mindmg = 5
    pcall(function() mindmg = math.max((tonumber(nl_refs.rage_mindmg and nl_refs.rage_mindmg:get()) or 10) - 5, 5) end)
    local hbsel = "Head + Body"
    pcall(function() hbsel = AIP.hitboxes:get() end)
    local shoot = nil
    local enemies = nil
    pcall(function() enemies = entity.get_players(true) end)
    local list = {}
    if ai_peek.ent then list[1] = ai_peek.ent elseif enemies then list = enemies end
    -- angelwings check: a shot that already exists from the ANCHOR eye needs no peek —
    -- the ragebot fires from cover; the anchor itself is candidate #0 while we hold
    if ai_peek.phase ~= "peek" and d_anchor <= 5 then
        table.insert(points, 1, { x = anchor.x, y = anchor.y, z = az, side = -1 })
    end
    for _, e in ipairs(list) do
        if shoot then break end
        local ok_e, e_alive, e_dorm = pcall(function() return e:is_alive(), e:is_dormant() end)
        if ok_e and e_alive and not e_dorm then
            -- enemy defensive (sim time went backwards) → body only for 12 ticks, ground only
            local idx = 0
            pcall(function() idx = e:get_index() end)
            pcall(function()
                local st = e:get_simulation_time()
                if st and st.current and st.old and (st.current - st.old) <= -0.01 then
                    ai_peek.def_until[idx] = tick + 12
                end
            end)
            local defensive = (ai_peek.def_until[idx] or 0) > tick
            local hbs = {}
            pcall(function()
                if hbsel ~= "Body only" and not defensive then
                    local h = e:get_hitbox_position(0)
                    if h then hbs[#hbs + 1] = vector(h.x, h.y, h.z + 2) end
                end
                if hbsel ~= "Head only" then
                    local c = e:get_hitbox_position(5); if c then hbs[#hbs + 1] = c end
                    local p = e:get_hitbox_position(2); if p then hbs[#hbs + 1] = p end
                end
            end)
            local hp = 100
            pcall(function() hp = e.m_iHealth or 100 end)
            local need = math.min(mindmg, hp)
            for _, pt in ipairs(points) do
                if shoot then break end
                local from = vector(pt.x, pt.y, pt.z)
                for _, hb in ipairs(hbs) do
                    local dmg, hit_e = 0, nil
                    pcall(function()
                        local d, tr = utils.trace_bullet(lp, from, hb, lp)
                        dmg = tonumber(d) or 0
                        hit_e = tr and tr.entity or nil
                    end)
                    if hit_e == e and dmg >= need then
                        shoot = { pos = pt, hb = hb, side = pt.side, ent = e, dmg = dmg, idx = idx }
                        break
                    end
                end
            end
        end
    end

    -- ── confirm + side lock ──
    if shoot and shoot.side == -1 then
        -- hittable from cover already: stay, let the ragebot work, keep the lock fresh
        ai_peek.lock_tick = tick
        ai_peek.shoot = shoot
        ai_peek_dev("hittable from cover, holding")
        go_home("hittable from cover")
        return
    end
    if shoot then
        ai_peek.confirm = ai_peek.confirm + 1
        ai_peek.lock_tick = tick
        if ai_peek.confirm < AIP.delay:get() then shoot = nil
        elseif ai_peek.side == nil then
            ai_peek.side, ai_peek.ent = shoot.side, shoot.ent
            aa_tl_push("AIPEEK", string.format("shot found: side %s dmg %d (need %d) → peek", shoot.side == 0 and "L" or "R", shoot.dmg, mindmg))
        end
    else
        ai_peek.confirm = 0
        if tick - ai_peek.lock_tick > 25 or not ai_peek.ent then ai_peek.side, ai_peek.ent = nil, nil end
    end
    ai_peek.shoot = shoot

    -- ── move ──
    if shoot then
        if ai_peek.phase ~= "peek" then
            ai_peek.phase = "peek"
            ai_peek.peek_t0, ai_peek.peek_tick, ai_peek.tele_done = now, tick, false
            ai_peek.peeks = ai_peek.peeks + 1
            ai_peek_set_overrides(true)
            ai_peek_dev(string.format("PEEK side=%s dmg=%d", shoot.side == 0 and "L" or "R", shoot.dmg), true)
        end
        ai_peek_go_to(cmd, lp, lo, shoot.pos)
        -- safety: exposed without a shot for too long → back
        if now - ai_peek.peek_t0 > (AIP.expose:get() / 1000) then
            ai_peek.timeouts = ai_peek.timeouts + 1
            go_home("exposure timeout")
        end
    else
        go_home("no shot")
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- v5.0 MISC TAB LOGIC — one createmove pass (misc_tick), cvar sync, createmove_run
-- (fake-duck speed), kill say queue, animation breaker. Global function names (main
-- chunk local budget); all NL writes dirty-tracked and cleared on disable / death.
-- ══════════════════════════════════════════════════════════════════════════
local MISC_FPS_CVARS = {
    fog    = { fog_enable = 0, fog_enable_water_fog = 0 },
    blood  = { violence_hblood = 0 },
    bloom  = { mat_disable_bloom = 1 },
    decal  = { r_drawdecals = 0 },
    shadow = { cl_csm_enabled = 0, cl_csm_shadows = 0, cl_csm_static_prop_shadows = 0, cl_csm_world_shadows = 0,
               cl_csm_viewmodel_shadows = 0, cl_csm_rope_shadows = 0, cl_csm_sprite_shadows = 0, cl_foot_contact_shadows = 0 },
    fx     = { r_drawsprites = 0, r_drawropes = 0, muzzleflash_light = 0, r_drawtracers_firstperson = 0 },
}
local function misc_cvar_set(name, v, is_int)
    return pcall(function()
        local c = cvar[name]
        if not c then error("no cvar " .. name) end
        if is_int then c:int(v) else c:float(v) end
    end)
end
local function misc_cvar_get(name, is_int)
    local v
    pcall(function()
        local c = cvar[name]
        if c then v = is_int and c:int() or c:float() end
    end)
    return v
end
-- cvar-driven features (dirty-tracked, originals saved once, restored on disable / unload)
function misc_cvars_sync(force_off)
    local on = (not force_off) and enable_master:get()
    -- fake latency unlock
    if on and MISC.fakelat:get() then
        if misc_eng.fakelat_saved == nil then misc_eng.fakelat_saved = misc_cvar_get("sv_maxunlag") or 0.2 end
        local want = MISC.fakelat_v:get() / 100
        if misc_eng.fakelat_cur ~= want then misc_cvar_set("sv_maxunlag", want); misc_eng.fakelat_cur = want end
    elseif misc_eng.fakelat_saved ~= nil then
        misc_cvar_set("sv_maxunlag", misc_eng.fakelat_saved); misc_eng.fakelat_saved, misc_eng.fakelat_cur = nil, nil
    end
    -- fps optimizer
    if on and MISC.fps:get() then
        if not misc_eng.fps_saved then
            misc_eng.fps_saved = {}
            for grp, tbl in pairs(MISC_FPS_CVARS) do
                for cv in pairs(tbl) do misc_eng.fps_saved[cv] = misc_cvar_get(cv, true) end
            end
        end
        local sel = { fog = MISC.fps_fog:get(), blood = MISC.fps_blood:get(), bloom = MISC.fps_bloom:get(),
                      decal = MISC.fps_decal:get(), shadow = MISC.fps_shadow:get(), fx = MISC.fps_fx:get() }
        for grp, tbl in pairs(MISC_FPS_CVARS) do
            for cv, v in pairs(tbl) do
                local want = sel[grp] and v or misc_eng.fps_saved[cv]
                if want ~= nil and misc_eng.fps_cur and misc_eng.fps_cur[cv] == want then
                else
                    misc_cvar_set(cv, want, true)
                    misc_eng.fps_cur = misc_eng.fps_cur or {}
                    misc_eng.fps_cur[cv] = want
                end
            end
        end
    elseif misc_eng.fps_saved then
        for cv, v in pairs(misc_eng.fps_saved) do if v ~= nil then misc_cvar_set(cv, v, true) end end
        misc_eng.fps_saved, misc_eng.fps_cur = nil, nil
    end
    -- viewmodel
    if on and MISC.vm:get() then
        if not misc_eng.vm_saved then
            misc_eng.vm_saved = { fov = misc_cvar_get("viewmodel_fov") or 68, x = misc_cvar_get("viewmodel_offset_x") or 2.5,
                                  y = misc_cvar_get("viewmodel_offset_y") or 0, z = misc_cvar_get("viewmodel_offset_z") or -1.5,
                                  rh = misc_cvar_get("cl_righthand", true) or 1 }
        end
        local want = { fov = MISC.vm_fov:get(), x = MISC.vm_x:get(), y = MISC.vm_y:get(), z = MISC.vm_z:get() }
        local cur = misc_eng.vm_cur or {}
        if cur.fov ~= want.fov then misc_cvar_set("viewmodel_fov", want.fov) end
        if cur.x ~= want.x then misc_cvar_set("viewmodel_offset_x", want.x) end
        if cur.y ~= want.y then misc_cvar_set("viewmodel_offset_y", want.y) end
        if cur.z ~= want.z then misc_cvar_set("viewmodel_offset_z", want.z) end
        misc_eng.vm_cur = want
        -- opposite knife hand: flip cl_righthand while a knife is out
        local knife = false
        pcall(function()
            local lp = entity.get_local_player()
            local w = lp and lp:get_player_weapon()
            local inf = w and w:get_weapon_info()
            knife = inf and tonumber(inf.weapon_type) == 0
        end)
        local rh = misc_eng.vm_saved.rh
        if MISC.vm_knife:get() and knife then rh = 1 - rh end
        if misc_eng.vm_rh ~= rh then misc_cvar_set("cl_righthand", rh, true); misc_eng.vm_rh = rh end
    elseif misc_eng.vm_saved then
        local s = misc_eng.vm_saved
        misc_cvar_set("viewmodel_fov", s.fov); misc_cvar_set("viewmodel_offset_x", s.x)
        misc_cvar_set("viewmodel_offset_y", s.y); misc_cvar_set("viewmodel_offset_z", s.z)
        misc_cvar_set("cl_righthand", s.rh, true)
        misc_eng.vm_saved, misc_eng.vm_cur, misc_eng.vm_rh = nil, nil, nil
    end
    -- aspect ratio
    if on and MISC.aspect:get() then
        if misc_eng.aspect_saved == nil then misc_eng.aspect_saved = misc_cvar_get("r_aspectratio") or 0 end
        local want = MISC.aspect_v:get() / 100
        if misc_eng.aspect_cur ~= want then misc_cvar_set("r_aspectratio", want); misc_eng.aspect_cur = want end
    elseif misc_eng.aspect_saved ~= nil then
        misc_cvar_set("r_aspectratio", misc_eng.aspect_saved); misc_eng.aspect_saved, misc_eng.aspect_cur = nil, nil
    end
end

local MISC_NOFALL_MASK = 0x400B
local function misc_clear_overrides()
    if misc_eng.airstrafe_ov then nl_clear(nl_refs.misc_airstrafe); misc_eng.airstrafe_ov = false end
    if misc_eng.autostop_ov then nl_clear(nl_refs.rage_as_ssg_opts); nl_clear(nl_refs.rage_as_opts); misc_eng.autostop_ov = false end
    if misc_eng.hs_ov then nl_clear(nl_refs.rage_hide); misc_eng.hs_ov = false end
end

function misc_tick(cmd)
    if (globals.tickcount or 0) % 8 == 0 then pcall(misc_cvars_sync) end
    local on = enable_master:get()
    local lp = on and entity.get_local_player() or nil
    local alive = false
    if lp then pcall(function() alive = lp:is_alive() end) end
    if not (on and lp and alive and cmd) then misc_clear_overrides(); return end
    local flags, vel, velz, lo = 0, 0, 0, nil
    pcall(function()
        flags = lp.m_fFlags or 0
        local v = lp.m_vecVelocity
        vel = math.sqrt((v.x or 0) ^ 2 + (v.y or 0) ^ 2)
        velz = v.z or 0
        lo = lp:get_origin()
    end)
    local on_ground = bit.band(flags, 1) ~= 0
    local moving_keys = false
    pcall(function() moving_keys = (cmd.in_forward or cmd.in_back or cmd.in_moveleft or cmd.in_moveright) and true or false end)

    -- fast ladder (evalate / elysian / spectral): look down, swap forward/back
    if MISC.ladder:get() then
        pcall(function()
            if (lp.m_MoveType or 0) == 9 and (cmd.in_forward or cmd.in_back) then
                local va = cmd.view_angles
                if va then
                    local ok = pcall(function() va.x = 89; cmd.view_angles = va end)
                    if not ok then pcall(function() cmd.view_angles = vector(89, va.y, 0) end) end
                end
                local f, b = cmd.in_forward, cmd.in_back
                cmd.in_forward, cmd.in_back = b, f
                cmd.forwardmove = -(cmd.forwardmove or 0)
            end
        end)
    end

    -- no fall damage (Andromeda / evalate): fast fall + ground within 75u but not 15u → duck
    if MISC.nofall:get() and lo and velz < -500 and not on_ground then
        local near, far = false, false
        pcall(function()
            for i = 0, 7 do
                local a = math.rad(i * 45)
                local fx, fy = lo.x + math.cos(a) * 10, lo.y + math.sin(a) * 10
                local tr = utils.trace_line(vector(fx, fy, lo.z + 2), vector(fx, fy, lo.z - 75), lp, MISC_NOFALL_MASK)
                if tr and (tr.fraction or 1) < 1 then
                    local d = (tr.fraction or 1) * 77
                    if d < 15 then near = true else far = true end
                end
            end
        end)
        if far and not near then pcall(function() cmd.in_duck = true end) end
    end

    -- edge stop (nexus): predict 4 ticks, if we would leave the ground stop moving
    if MISC.edge_stop:get() and on_ground and moving_keys then
        pcall(function()
            local sim = lp:simulate_movement()
            if not sim then return end
            sim:think(4)
            local sv = sim.velocity
            if sv and math.abs(sv.z or 0) > 1 then
                cmd.forwardmove, cmd.sidemove = 0, 0
                cmd.in_forward, cmd.in_back, cmd.in_moveleft, cmd.in_moveright = false, false, false, false
                misc_eng.edge_stopped = misc_eng.edge_stopped + 1
            end
        end)
    end

    -- jump scout (evalate): SSG / revolver airborne without movement input
    local want_js = false
    if MISC.jump_scout:get() and not on_ground and not moving_keys and vel <= 1.2 then
        pcall(function()
            local w = lp:get_player_weapon()
            local cn = w and tostring(w:get_classname() or "") or ""
            want_js = (cn == "CWeaponSSG08" or cn == "CWeaponRevolver")
        end)
    end
    if want_js then
        aa_ov(nl_refs.misc_airstrafe, false); misc_eng.airstrafe_ov = true
        if not aa_ov(nl_refs.rage_as_ssg_opts, { "In Air" }) then aa_ov(nl_refs.rage_as_opts, { "In Air" }) end
        misc_eng.autostop_ov = true
    elseif misc_eng.airstrafe_ov or misc_eng.autostop_ov then
        if misc_eng.airstrafe_ov then nl_clear(nl_refs.misc_airstrafe); misc_eng.airstrafe_ov = false end
        if misc_eng.autostop_ov then nl_clear(nl_refs.rage_as_ssg_opts); nl_clear(nl_refs.rage_as_opts); misc_eng.autostop_ov = false end
    end

    -- auto hide shots (evalate "Auto OS"): DT charged + HS off by the user + state + weapon
    local want_hs = false
    if MISC.auto_hs:get() and aa_eng.dt_on and aa_eng.charge >= 1 and (misc_eng.hs_ov or not aa_eng.hs_on) then
        local st = aa_eng.state
        local st_ok = (st == "stand" and MISC.auto_hs_st:get()) or (st == "duck" and MISC.auto_hs_du:get())
                   or (st == "slow" and MISC.auto_hs_sw:get())
        if st_ok then
            want_hs = true
            if MISC.auto_hs_pi:get() then
                pcall(function()
                    local w = lp:get_player_weapon()
                    local inf = w and w:get_weapon_info()
                    local wt = inf and tonumber(inf.weapon_type) or -1
                    if wt == 1 then want_hs = false end   -- pistols (incl. deagle)
                end)
            end
        end
    end
    if want_hs then
        if not misc_eng.hs_ov then aa_ov(nl_refs.rage_hide, true); misc_eng.hs_ov = true end
    elseif misc_eng.hs_ov then
        nl_clear(nl_refs.rage_hide); misc_eng.hs_ov = false
    end
end

-- unlock fake-duck speed (elysian / evalate): runs in createmove_run so NL's own fake-duck
-- slowdown is already applied and we renormalize the movement vector back to 450
pcall(function()
    events.createmove_run:set(function(cmd)
        pcall(function()
            if not (enable_master:get() and MISC.fd_speed:get() and cmd) then return end
            local fd = nl_refs.aa_fakeduck and nl_refs.aa_fakeduck:get()
            if not fd then return end
            local lp = entity.get_local_player()
            if not lp or bit.band(lp.m_fFlags or 0, 1) == 0 then return end
            local f, s = cmd.forwardmove or 0, cmd.sidemove or 0
            local len = math.sqrt(f * f + s * s)
            if len > 1 then
                cmd.forwardmove = f / len * 450
                cmd.sidemove    = s / len * 450
            end
        end)
    end)
    _hooks_status.createmove_run = "createmove_run"
end)

-- kill say lines (elysian / evalate / Andromeda styles + Sel01)
local MISC_KILLSAY = {
    ["Memes"]  = { "ez", "skill issue", "gg", "next?", "+rep", "xddd", "1" },
    ["Tilt"]   = { "who?", "yikes", "delete cs", "uninstall", "baited", "too slow", "bot" },
    ["Polite"] = { "gg wp", "well played", "good fight", "respect", "rematch?" },
    ["Sel01"]  = { "Sel01 says hi", "resolved.", "powered by Sel01", "gg by Sel01", "Sel01 - next" },
    ["One (\"1\")"] = { "1" },
}
function misc_killsay_queue(text)
    text = tostring(text or ""):gsub('"', "")
    if #text == 0 then return end
    -- elysian human-like delay: 1 + len/10*2 (+-0.3), clamped 1..4s
    local delay = math.max(1, math.min(4, 1 + (#text / 10) * 2 + (math.random() * 0.6 - 0.3)))
    misc_eng.killsay_q[#misc_eng.killsay_q + 1] = { text = text, at = (globals.realtime or 0) + delay }
    misc_eng.last_line = text
end
function misc_killsay_pick()
    local style = "Memes"
    pcall(function() style = MISC.killsay_st:get() end)
    local lines = MISC_KILLSAY[style] or MISC_KILLSAY["Memes"]
    local line = lines[math.random(1, #lines)]
    if #lines > 1 and line == misc_eng.last_line then line = lines[math.random(1, #lines)] end
    return line
end
function misc_killsay_flush()
    local q = misc_eng.killsay_q
    if #q == 0 then return end
    local now = globals.realtime or 0
    if now < q[1].at then return end
    local e = table.remove(q, 1)
    pcall(function()
        if utils and utils.console_exec then utils.console_exec('say "' .. e.text .. '"')
        elseif engine and engine.execute_client_cmd then engine.execute_client_cmd('say "' .. e.text .. '"') end
    end)
end

-- animation breaker (FFI m_AnimOverlay @ +10640, the offset every meta lua uses on this build)
pcall(function()
    local ev = events.post_update_clientside_animation
    if not ev then return end
    ev:set(function(lp)
        if not (enable_master:get() and MISC.anim:get()) then
            if misc_eng.legs_ov then nl_clear(nl_refs.aa_leg_movement); misc_eng.legs_ov = false end
            return
        end
        local me = entity.get_local_player()
        if not me then return end
        if lp ~= nil and lp ~= me then return end   -- per-player callback: only ours
        local alive = false
        pcall(function() alive = me:is_alive() end)
        if not alive then return end
        local airborne = true
        pcall(function() airborne = bit.band(me.m_fFlags or 0, 1) == 0 end)
        -- move lean: layer 12 weight
        if MISC.anim_lean:get() then
            if misc_eng.anim_ok == nil then
                misc_eng.anim_ok = pcall(function()
                    pcall(ffi.cdef, [[
                        typedef struct {
                            char pad_0000[20]; int m_nOrder; int m_nSequence; float m_flPrevCycle; float m_flWeight;
                            float m_flWeightDeltaRate; float m_flPlaybackRate; float m_flCycle; void *m_pOwner; char pad_0038[4];
                        } Sel01AnimLayer;
                    ]])
                    misc_eng.anim_T = ffi.typeof("Sel01AnimLayer**")
                end)
            end
            if misc_eng.anim_ok and misc_eng.anim_T then
                pcall(function()
                    local layers = ffi.cast(misc_eng.anim_T, ffi.cast("uintptr_t", me[0]) + 10640)[0]
                    layers[12].m_flWeight = MISC.anim_leanw:get() / 100
                end)
            end
        end
        -- leg breaker: sliding legs + pose 0
        if MISC.anim_legs:get() then
            if not misc_eng.legs_ov then aa_ov_str(nl_refs.aa_leg_movement, "Sliding"); misc_eng.legs_ov = true end
            pcall(function() me.m_flPoseParameter[0] = 1 end)
        elseif misc_eng.legs_ov then
            nl_clear(nl_refs.aa_leg_movement); misc_eng.legs_ov = false
        end
        -- landing pitch zero / force falling
        if MISC.anim_land:get() then
            pcall(function()
                local as = me:get_anim_state()
                if as and as.landing then me.m_flPoseParameter[12] = 0.5 end
            end)
        end
        if MISC.anim_fall:get() and airborne then
            pcall(function() me.m_flPoseParameter[6] = 0.5 end)
        end
    end)
    _hooks_status.anim = "post_update_clientside_animation"
end)

-- Single createmove handler that runs movement + NL-visual override sync.
-- V1.5: also drains pending_preset so preset writes happen OUTSIDE menu callback.
-- V2.0: dirty-track restored (only write NL :override on toggle change)
local function createmove_unified(cmd)
    -- Drain queued preset apply (set by the preset buttons)
    if pending_preset then
        local name = pending_preset
        pending_preset = nil
        pcall(_do_apply_preset, name)
    end
    -- v5.0 config system actions (Save / Load / Delete / Export / Import) — drained here
    if pending_cfg then
        local p = pending_cfg
        pending_cfg = nil
        pcall(cfg_drain, p)
    end
    -- preset list: the description label follows the selection (polled, :name from createmove)
    if (globals.tickcount or 0) % 16 == 0 then
        pcall(function()
            local v = PRESET.list:get()
            local idx = nil
            if type(v) == "number" then idx = math.max(1, math.min(#PRESET.KEYS, v))
            elseif type(v) == "string" then for i, n in ipairs(PRESET.NAMES) do if n == v then idx = i end end end
            if idx and idx ~= PRESET.shown then
                PRESET.shown = idx
                PRESET.desc:name("\aA0A6B4FF  " .. PRESET.DESC[idx])
            end
        end)
    end
    if pending_drag_reset then pending_drag_reset = false; pcall(vis_drag_reset_all) end
    -- v5.0: Shuffle choke steps (button callback only sets the flag — v1.5 rule)
    if pending_def_shuffle then
        pending_def_shuffle = false
        pcall(function()
            for i = 1, 6 do safe_set(AA.def_seq[i], math.random(2, 22)) end
            cs_log_color("choke steps shuffled")
        end)
    end

    createmove_handler(cmd)
    pcall(misc_tick, cmd)   -- v5.0 Misc tab (global fn, defined below the AA engine)
    -- V3.28: AI Peek state machine (cheap, internally gated; default OFF)
    pcall(ai_peek_tick, cmd)
    -- v4.0: the per-state AA engine (every tick; side timing counted in un-choked sends)
    local ok, err = pcall(aa_engine_tick, cmd)
    if not ok then
        local now = globals.realtime or 0
        if now - (aa_eng.err_t or 0) > 5 then
            aa_eng.err_t = now
            cs_log("[AA-ENGINE ERROR] " .. tostring(err))
            aa_tl_push("ERROR", tostring(err))
        end
    end
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

-- aim_fire (re-enabled in v3.29 after the v1.13 bisect): v4.1 uses it ONLY as the
-- "ragebot committed a shot" signal for the AI Peek retreat. Reads numeric fields
-- only, never event.target's entity properties (transition-state crash source).
pcall(function()
    if events.aim_fire then
        events.aim_fire:set(function(event)
            pcall(function()
                if not event then return end
                -- v4.1: the ragebot committed a shot → AI Peek retreats on the next tick.
                -- Reads NOTHING from event.target (transition-state crash source).
                ai_peek.shot_tick = globals.tickcount or 0
                aa_eng.last_fire_t = globals.realtime or 0   -- v5.0: defensive pause window
                if ai_peek.phase == "peek" then
                    aa_tl_push("AIPEEK", string.format("ragebot fired (dmg %d hc %d)", tonumber(event.damage) or 0, tonumber(event.hitchance) or 0))
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
local HITS_TAKEN_MAX = 25   -- v4.0: 10 → 25 so the copy dump covers a whole bad round

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

-- v4.0: the hit-taken snapshot is aa_snapshot() (engine block above). Per-attacker
-- table so the dump can say WHO resolves you and in which state.
local attackers = {}   -- [name] = { hits, dmg, head, states = {[state]=n}, last = t, wpn = {} }

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
    attackers            = {}
    aa_tl                = {}
    aa_eng.stats = { near_miss = 0, flips = 0, def_ticks = 0, react = 0, hp_pulses = 0, freezes = 0, sh_ticks = 0, onuse = 0 }
    aa_eng.def_pulses, aa_eng.switches = 0, 0
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
                aa_tl_push("HIT", string.format("%s +%d", target_name, event.damage or 0))
                -- V3.0: hitbox bucketing moved to player_hurt (event.hitgroup is
                -- reliable; event.hitbox in aim_ack returns nil in this NL build).
                if vis_hitmarker:get() then
                    hitmark_time = globals.realtime or 0
                    _vis_state.hitmark_dmg = event.damage or 0
                    _vis_state.hitmark_big = (event.damage or 0) >= 100
                end
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
                aa_tl_push("MISS", string.format("%s (%s)", target_name, tostring(reason or "?")))
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
            -- v4.0: the v3.7 side-streak limiter is gone — the engine owns the side now
            -- and switches it in un-choked sends (per-state timing), so an enemy never
            -- sees N same-side packets unless the state's delay says so.
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
            local victim = entity.get(event.userid, true)
            -- v5.0 death say (elysian): we died to a body shot
            if victim == lp and attacker and attacker ~= lp then
                if MISC.deathsay:get() and not event.headshot then misc_killsay_queue("ofc body u fkn nn xd") end
                misc_eng.killed_by = event.attacker
                return
            end
            if attacker ~= lp then return end
            if not victim or victim == lp then return end
            local victim_name = "?"
            pcall(function() victim_name = victim:get_name() end)
            -- v5.0 kill say (+ revenge mode: only the one who killed / hit you last)
            if MISC.killsay:get() then
                local ok = true
                if MISC.killsay_rv:get() then ok = (misc_eng.killed_by == event.userid) or (misc_eng.last_attacker == event.userid) end
                if ok then misc_killsay_queue(misc_killsay_pick()) end
            end
            -- V3.15: count the kill in a MONOTONIC stat (independent of the event-log
            -- toggle + the 8-entry ring). The dump used to recount from hit_log, which
            -- rotates → showed kills=0 despite 21 one-taps + a 297 headshot.
            stats.kills = (stats.kills or 0) + 1
            aa_tl_push("KILL", tostring(victim_name))
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
                misc_eng.last_attacker = event.attacker   -- v5.0 revenge kill say
                local dmg_in = event.dmg_health or event.damage or 0
                stats.dmg_taken = (stats.dmg_taken or 0) + dmg_in
                local atk_name = "?"
                pcall(function() if attacker.get_name then atk_name = attacker:get_name() end end)
                local hb_in = event.hitgroup or -1
                local wpn_in = "?"
                pcall(function() wpn_in = tostring(event.weapon or "?") end)
                local now = globals.realtime or 0
                -- v4.0: full engine snapshot (state / side / written angles / defensive /
                -- threat cache) — the attacker entity itself is NEVER read here (transition
                -- state crash); distance comes from the createmove threat cache when the
                -- attacker IS the cached threat.
                local snap = aa_snapshot()
                snap.atk_is_threat = (aa_eng.threat ~= nil and attacker == aa_eng.threat)
                table.insert(hits_taken_log, {
                    time     = now,
                    atk_name = atk_name,
                    dmg      = dmg_in,
                    hp_left  = event.health or 0,
                    hitbox   = _hb_name(hb_in),
                    hb_id    = hb_in,
                    weapon   = wpn_in,
                    snapshot = snap,
                })
                while #hits_taken_log > HITS_TAKEN_MAX do table.remove(hits_taken_log, 1) end
                local A = attackers[atk_name] or { hits = 0, dmg = 0, head = 0, states = {}, wpn = {}, last = 0 }
                A.hits, A.dmg, A.last = A.hits + 1, A.dmg + dmg_in, now
                if hb_in == 1 then A.head = A.head + 1 end
                A.states[snap.state or "?"] = (A.states[snap.state or "?"] or 0) + 1
                A.wpn[wpn_in] = (A.wpn[wpn_in] or 0) + 1
                attackers[atk_name] = A
                aa_tl_push("HIT-TAKEN", string.format("%s → %s for %d (%s) hp=%d | %s side=%s yaw=%d L/R=%d/%d def=%s%s",
                    atk_name, _hb_name(hb_in), dmg_in, wpn_in, event.health or 0,
                    tostring(snap.state), tostring(snap.side), math.floor(snap.yaw or 0), snap.l or 0, snap.r or 0,
                    snap.def_pulse and "PULSE" or (snap.dt and "armed" or "noDT"),
                    snap.atk_is_threat and string.format(" dist=%.0f", snap.threat_dist or 0) or ""))
                -- v4.0 hit reaction: bullet hits only (hitgroup 1-7; 0 = nade / world / fall)
                if AA.hit_react:get() and hb_in >= 1 and hb_in <= 7 then
                    aa_eng.react_until = now + (AA.hit_dur:get() / 1000.0)
                    aa_eng.react_from = atk_name
                    aa_eng.force_side = 1 - aa_eng.side
                    aa_eng.stats.react = aa_eng.stats.react + 1
                    aa_tl_push("REACT", string.format("hit by %s → flip side + defensive burst %dms", atk_name, AA.hit_dur:get()))
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

-- v4.0 ANTI-BRUTEFORCE — events.bullet_impact (gazolina / gingersense pattern). A shot
-- whose line (shooter eye → impact) passes within the radius of our eye counts as a
-- near-miss: per-shooter reaction for N seconds (side flip / random fake limit / random
-- switch delay / staged yaw). One reaction per tick, 0.25s per shooter.
local function _seg_dist(px, py, pz, ax, ay, az, bx, by, bz)
    local dx, dy, dz = bx - ax, by - ay, bz - az
    local len2 = dx * dx + dy * dy + dz * dz
    local t = 0
    if len2 > 0 then
        t = ((px - ax) * dx + (py - ay) * dy + (pz - az) * dz) / len2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local cx, cy, cz = ax + dx * t, ay + dy * t, az + dz * t
    return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2 + (pz - cz) ^ 2)
end
pcall(function()
    events.bullet_impact:set(function(event)
        pcall(function()
            if not (enable_master:get() and AA.enable:get() and AA.ab_enable:get()) then return end
            if not event or not event.userid then return end
            local tick = globals.tickcount or 0
            if aa_eng.ab_tick == tick then return end
            local lp = entity.get_local_player()
            if not lp or not lp:is_alive() then return end
            local sh = entity.get(event.userid, true)
            if not sh or sh == lp then return end
            if not sh:is_alive() or sh:is_dormant() or not sh:is_enemy() then return end
            local now = globals.realtime or 0
            local name = "?"
            pcall(function() name = tostring(sh:get_name() or "?") end)
            local prev = aa_eng.ab[name]
            if prev and now - (prev.at or 0) < 0.25 then return end
            local me, from = lp:get_eye_position(), sh:get_eye_position()
            if not (me and from) then return end
            local d = _seg_dist(me.x, me.y, me.z, from.x, from.y, from.z, event.x, event.y, event.z)
            if d > AA.ab_radius:get() then return end
            aa_eng.ab_tick = tick
            aa_eng.ab_stage = (aa_eng.ab_stage + 1) % 15
            aa_eng.stats.near_miss = aa_eng.stats.near_miss + 1
            -- v5.0 yaw reaction modes (gazolina Meta / Increase / Decrease, elysian phases)
            local mode = AA.ab_mode:get()
            local yaw_add
            if mode == "Increase +5..15" then yaw_add = math.random(5, 15)
            elseif mode == "Decrease -15..5" then yaw_add = math.random(-15, 5)
            elseif mode == "Random phases -40..40" then
                aa_eng.ab_phase = aa_eng.ab_phase % 10 + 1
                aa_eng.ab_phase_off = math.random(-40, 40)
                yaw_add = aa_eng.ab_phase_off
            else yaw_add = aa_eng.ab_stage * 2 * ((aa_eng.side == 0) and 1 or -1) end
            local e = {
                at = now, until_t = now + AA.ab_dur:get(),
                yaw   = yaw_add,
                limit = math.random(10, 60),
                delay = math.random(-2, 4),
            }
            aa_eng.ab[name] = e
            if AA.ab_flip:get() then aa_eng.force_side = 1 - aa_eng.side end
            -- v5.0 evalate Freeze: hold the side for N sends with a chance
            local froze = false
            if AA.ab_freeze:get() and math.random(0, 100) < AA.ab_fchance:get() then
                aa_eng.freeze_until = aa_eng.sends + AA.ab_fdur:get()
                aa_eng.stats.freezes = aa_eng.stats.freezes + 1
                froze = true
            end
            aa_tl_push("NEAR-MISS", string.format("%s shot %.0fu from head → %s%s%s%s%s", name, d,
                AA.ab_flip:get() and "flip " or "",
                AA.ab_limit:get() and string.format("limit=%d ", e.limit) or "",
                AA.ab_yaw:get() and string.format("yaw%+d ", e.yaw) or "",
                AA.ab_delay:get() and string.format("delay%+d ", e.delay) or "",
                froze and string.format("FREEZE %d sends", AA.ab_fdur:get()) or ""))
        end)
    end)
    _hooks_status.bullet_impact = "bullet_impact"
end)
-- round markers for the idle-spin gate + the timeline
pcall(function() events.round_start:set(function() aa_eng.round_ended = false; aa_eng.ab = {}; aa_tl_push("ROUND", "start") end) end)
pcall(function() events.round_end:set(function() aa_eng.round_ended = true; aa_tl_push("ROUND", "end") end) end)

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

-- ══════════════════════════════════════════════════════════════════════════
-- v5.0 VISUAL LANGUAGE — the elysian / nexus / evalate "glass" look, all pcall'd:
--   vis_glass(x1, y1, x2, y2, a, rad): outer 22%-alpha shadow, blur, dark body, a top gloss
--   (44% height, alpha 22), 1px outline (255,255,255,40). vis_tsh: text with a 45% black
--   shadow 1px offset. vis_font(): Verdana 12 panel font (fallback int font 3). Globals —
--   the main chunk is at the local cap.
-- ══════════════════════════════════════════════════════════════════════════
VIS_COL_BG   = { 15, 15, 18 }
function vis_font()
    if _vis_fonts.panel == nil then
        _vis_fonts.panel = false
        pcall(function() _vis_fonts.panel = render.load_font("Verdana", 12, "a") end)
    end
    return _vis_fonts.panel or 3
end
function vis_glass(x1, y1, x2, y2, a, rad)
    a = a or 1
    rad = rad or 6
    pcall(function()
        local p1, p2 = vector(x1, y1), vector(x2, y2)
        render.rect(vector(x1 - 1, y1 + 1), vector(x2 + 1, y2 + 3), color(0, 0, 0, math.floor(56 * a)), rad + 1)
        render.blur(p1, p2, 3, 0.85 * a, rad)
        render.rect(p1, p2, color(VIS_COL_BG[1], VIS_COL_BG[2], VIS_COL_BG[3], math.floor(210 * a)), rad)
        render.rect(p1, vector(x2, y1 + (y2 - y1) * 0.44), color(255, 255, 255, math.floor(22 * a)), { rad, rad, 0, 0 })
        render.rect_outline(p1, p2, color(255, 255, 255, math.floor(40 * a)), 1, rad)
    end)
end
function vis_tsh(font, x, y, col, text, flags)
    pcall(function()
        local a = col.a or 255
        render.text(font, vector(x + 1, y + 1), color(0, 0, 0, math.floor(a * 0.45)), flags, text)
        render.text(font, vector(x, y), col, flags, text)
    end)
end
-- accent bar on the left of a row (event log / spectators): 3px, rounded left corners
function vis_accent_bar(x, y1, y2, col)
    pcall(function() render.rect(vector(x, y1), vector(x + 3, y2), col, { 4, 0, 0, 4 }) end)
end
-- ── draggable panels ──
-- vis_drag_frame(): once per render frame — mouse, button edge, menu rect, menu open.
-- vis_drag_pos(name, dx, dy, w, h): returns the panel position (saved or default), handles
-- grab / move / release while the menu is open, draws a dashed accent outline so you see
-- what is draggable. Saved to the hidden sliders on release (pcall'd :set, render context
-- is fine for sliders — the v1.5 freeze was combo :set inside MENU callbacks).
VIS_DRAG = { grab = nil, down = false, prev = false, click = false, mx = 0, my = 0, menu = false }
function vis_drag_frame()
    local D = VIS_DRAG
    D.prev = D.down
    D.menu, D.down = false, false
    pcall(function() D.menu = ui.get_alpha and ui.get_alpha() > 0.05 end)
    if not D.menu then D.grab = nil; return end
    pcall(function() local m = ui.get_mouse_position(); D.mx, D.my = m.x, m.y end)
    pcall(function() D.down = common.is_button_down(1) and true or false end)
    D.click = D.down and not D.prev
    D.in_menu = false
    pcall(function()
        local p, s = ui.get_position(), ui.get_size()
        if p and s then D.in_menu = D.mx >= p.x and D.mx <= p.x + s.x and D.my >= p.y and D.my <= p.y + s.y end
    end)
    if not D.down then
        if D.grab then
            -- release: persist
            local P = VIS_DRAG[D.grab]
            local S = VIS.drag[D.grab]
            if P and S then pcall(function() S.x:set(math.floor(P.x)); S.y:set(math.floor(P.y)) end) end
        end
        D.grab = nil
    end
end
function vis_drag_pos(name, dx, dy, w, h)
    local D = VIS_DRAG
    local P = D[name]
    if not P then
        P = { x = nil, y = nil }
        D[name] = P
    end
    -- (re)load from the sliders when unset or after a reset
    if P.x == nil then
        local sx, sy = -1, -1
        pcall(function() sx = VIS.drag[name].x:get(); sy = VIS.drag[name].y:get() end)
        P.x = (sx and sx >= 0) and sx or dx
        P.y = (sy and sy >= 0) and sy or dy
        P.custom = (sx and sx >= 0)
    elseif not P.custom then
        P.x, P.y = dx, dy   -- default-positioned panels follow their computed default (resolution / combo changes)
    end
    if D.menu then
        local sx, sy = render.screen_size().x, render.screen_size().y
        if D.grab == name and D.down then
            P.x = math.max(0, math.min(sx - w, D.mx - P.ox))
            P.y = math.max(0, math.min(sy - h, D.my - P.oy))
            P.custom = true
        elseif D.click and not D.grab and not D.in_menu
               and D.mx >= P.x and D.mx <= P.x + w and D.my >= P.y and D.my <= P.y + h then
            D.grab = name
            P.ox, P.oy = D.mx - P.x, D.my - P.y
        end
        -- outline so the panel reads as draggable
        pcall(function()
            local c = (D.grab == name) and color(120, 200, 255, 200) or color(120, 200, 255, 90)
            render.rect_outline(vector(P.x - 2, P.y - 2), vector(P.x + w + 2, P.y + h + 2), c, 1, 5)
        end)
    end
    return P.x, P.y
end
function vis_drag_reset_all()
    for _, nm in ipairs({ "watermark", "keybinds", "spectators", "netgraph", "eventlog", "velocity", "sideind" }) do
        pcall(function() VIS.drag[nm].x:set(-1); VIS.drag[nm].y:set(-1) end)
        VIS_DRAG[nm] = nil
    end
end
-- per-key smoothed alpha (keybind rows, log rows): target 0/1, returns 0..1
VIS_FADE = {}
function vis_fade(key, want, speed)
    local a = VIS_FADE[key] or 0
    a = a + ((want and 1 or 0) - a) * (speed or 0.18)
    if a < 0.01 and not want then VIS_FADE[key] = nil; return 0 end
    VIS_FADE[key] = a
    return a
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
        vis_drag_frame()   -- v5.0 draggable panels: mouse / button edge / menu rect once per frame

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
                -- v5.0: kill / 100+ = gold (elysian), damage number next to the marker
                if VIS.hitmark_dmg:get() and _vis_state.hitmark_big then col = color(255, 200, 60, alpha) end
                if VIS.hitmark_dmg:get() and (_vis_state.hitmark_dmg or 0) > 0 then
                    pcall(function() render.text(3, vector(cx + 18, cy + 12), col, nil, "-" .. tostring(_vis_state.hitmark_dmg)) end)
                end
                -- v5.0 arc-style: radius eases 5 → 10 (cubic ease-out) with a 1px black shadow
                local e = 1 - (1 - math.min(1, age / HITMARK_DURATION_S)) ^ 3
                L = 5 + 5 * e
                local sh = color(0, 0, 0, math.floor(alpha * 0.5))
                pcall(function()
                    for _, o in ipairs({ { sh, 1 }, { col, 0 } }) do
                        local c, d = o[1], o[2]
                        render.line(vector(cx - L*2 + d, cy - L*2 + d), vector(cx - L + d, cy - L + d), c)
                        render.line(vector(cx + L + d,   cy - L + d),   vector(cx + L*2 + d, cy - L*2 + d), c)
                        render.line(vector(cx - L*2 + d, cy + L*2 + d), vector(cx - L + d, cy + L + d), c)
                        render.line(vector(cx + L + d,   cy + L + d),   vector(cx + L*2 + d, cy + L*2 + d), c)
                    end
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
                if AA.enable:get() then
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
                -- v5.0 arrow styles: Classic (< >), Modern (Verdana 27 glyphs, Andromeda /
                -- nexus), Triangles (gazolina TS: polys + desync bars). Active side bright,
                -- the other side dim; manual keys tint the arrow white.
                local style = "Classic < >"
                pcall(function() style = VIS.arrows_style:get() end)
                local off = 45
                pcall(function() off = VIS.arrows_off:get() end)
                local manual = (aa_eng.manual ~= "")
                local act = manual and color(255, 255, 255, 255) or ((side < 0) and color(255, 230, 80, 255) or color(80, 200, 255, 255))
                local dim = color(60, 60, 60, 160)
                local lc, rc = (side < 0) and act or dim, (side > 0) and act or dim
                if manual then lc = (aa_eng.manual == "L") and act or dim; rc = (aa_eng.manual == "R") and act or dim end
                if style == "Modern (Verdana 27)" then
                    if not _vis_fonts.arrow then pcall(function() _vis_fonts.arrow = render.load_font("Verdana", 27, "ab") end) end
                    local f = _vis_fonts.arrow or 4
                    pcall(function()
                        render.text(f, vector(cx - off - 12, cy - 16), lc, nil, "⮜")
                        render.text(f, vector(cx + off - 12, cy - 16), rc, nil, "⮞")
                    end)
                elseif style == "Triangles (gazolina TS)" then
                    pcall(function()
                        local s = 7
                        -- left triangle
                        render.line(vector(cx - off, cy), vector(cx - off + s, cy - s), lc)
                        render.line(vector(cx - off, cy), vector(cx - off + s, cy + s), lc)
                        render.line(vector(cx - off + s, cy - s), vector(cx - off + s, cy + s), lc)
                        -- right triangle
                        render.line(vector(cx + off, cy), vector(cx + off - s, cy - s), rc)
                        render.line(vector(cx + off, cy), vector(cx + off - s, cy + s), rc)
                        render.line(vector(cx + off - s, cy - s), vector(cx + off - s, cy + s), rc)
                        -- desync bars next to the crosshair (which side the body faces)
                        local bl = (side < 0) and color(0, 200, 255, 230) or dim
                        local br = (side > 0) and color(0, 200, 255, 230) or dim
                        render.rect(vector(cx - off + s + 6, cy - 6), vector(cx - off + s + 8, cy + 6), bl)
                        render.rect(vector(cx + off - s - 8, cy - 6), vector(cx + off - s - 6, cy + 6), br)
                    end)
                else
                    pcall(function()
                        render.text(4, vector(cx - off + 20, cy - 6), lc, nil, "<")
                        render.text(4, vector(cx + off - 26, cy - 6), rc, nil, ">")
                    end)
                end
                -- rotating accent line — small dash that spins with the send counter (animation)
                local ang = (aa_yaw_jitter_counter * 0.35) + now * 1.8
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
                    -- v5.0: shadowed, the newest entry pops (scale-in over 0.12s = extra x offset)
                    local pop_in = math.min(1, age / 0.12)
                    local y = stack_y_base + row * 16 - (1 - pop_in) * 6
                    vis_tsh(4, stack_x, y, color(r, g, b, alpha), string.format("-%d HP", pop.dmg))
                    if pop.hp_left > 0 then
                        vis_tsh(3, stack_x + 60, y + 2, color(180, 180, 180, alpha), string.format("(%d hp)", pop.hp_left))
                    end
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
            -- v5.0 position combo
            pcall(function()
                local p = VIS.wm_pos:get()
                if p == "Top Left" then wx = 12
                elseif p == "Bottom Right" then wy = sy - 34
                elseif p == "Bottom Left" then wx, wy = 12, sy - 34 end
            end)
            -- v5.0 glass pill (elysian modern watermark): accent dot + name + fps + ping,
            -- a shimmer sweeping through the text every ~3s
            local t = now * 1.5
            local g_r = math.floor(160 + 60 * math.sin(t))
            local g_g = math.floor(160 + 60 * math.sin(t + 2.09))  -- +2pi/3
            local g_b = math.floor(220 + 35 * math.sin(t + 4.19))  -- +4pi/3
            pcall(function()
                local h = 24
                local w = tw + pad * 2 + 14
                wx, wy = vis_drag_pos("watermark", wx, wy, w, h)
                vis_glass(wx, wy, wx + w, wy + h, 1, 7)
                -- accent dot (pulses with the DT charge when DT is on, else the RGB wave)
                local dc = color(g_r, g_g, g_b, 255)
                if nl_refs.rage_dt and nl_refs.rage_dt:get() then
                    dc = ((aa_eng.charge or 0) >= 1) and color(120, 255, 120, 255) or color(255, 90, 90, 255)
                end
                render.rect(vector(wx + 8, wy + h / 2 - 3), vector(wx + 14, wy + h / 2 + 3), dc, 3)
                local f = vis_font()
                vis_tsh(f, wx + 20, wy + 5, color(g_r, g_g, g_b, 255), "Sel01")
                local rest = string.format("  %s  |  %d fps  |  %d ms", lp_name, perf.fps, perf.ping)
                local sw = 0
                pcall(function() sw = render.measure_text(f, nil, "Sel01").x end)
                vis_tsh(f, wx + 20 + sw, wy + 5, color(225, 230, 240, 255), rest)
                -- shimmer: a soft highlight band sweeping left → right
                local ph = (now % 3) / 3
                local sx0 = wx + 4 + (w - 8) * ph
                render.gradient(vector(sx0 - 18, wy + 1), vector(sx0, wy + h - 1), color(255, 255, 255, 0), color(255, 255, 255, 26), color(255, 255, 255, 0), color(255, 255, 255, 26))
                render.gradient(vector(sx0, wy + 1), vector(sx0 + 18, wy + h - 1), color(255, 255, 255, 26), color(255, 255, 255, 0), color(255, 255, 255, 26), color(255, 255, 255, 0))
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
                local aa_on = AA.enable:get() and aa_eng.active
                -- v4.0: movement line = the engine's own state (what the AA is built for)
                local AA_STATE_LABEL = { stand = "STANDING", move = "MOVING", slow = "SLOW-WALK", duck = "CROUCH",
                                         duckmv = "CROUCH-MOVE", air = "AIR", airduck = "AIR-CROUCH" }
                local mstate = AA_STATE_LABEL[aa_eng.state]
                if not (aa_on and mstate) then
                    local f, sp = 0, 0
                    pcall(function()
                        f = lp.m_fFlags or 0
                        local v = lp.m_vecVelocity; sp = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
                    end)
                    mstate = (bit.band(f, 1) == 0) and "AIR"
                          or (bit.band(f, 2) ~= 0) and "CROUCH"
                          or (sp > 5) and "MOVING" or "STANDING"
                end
                -- short curated list of active key states (dynamic / important only)
                local subs = {}
                if aa_on and now < aa_eng.react_until then subs[#subs+1] = "REACTING" end
                if aa_on and aa_eng.def_pulse then subs[#subs+1] = "DEFENSIVE" end
                if aa_on and aa_eng.hidden_active then subs[#subs+1] = "HIDDEN" end
                if aa_on and aa_eng.hp.active then subs[#subs+1] = "HEAD-SAFE" end
                if aa_on and next(aa_eng.ab) ~= nil then subs[#subs+1] = "ANTI-BF" end
                pcall(function() if nl_refs.rage_dt and nl_refs.rage_dt:get() then subs[#subs+1] = (aa_eng.charge or 0) >= 1 and "DOUBLE TAP" or string.format("DT %d%%", math.floor((aa_eng.charge or 0) * 100)) end end)
                pcall(function() if nl_refs.aa_fakeduck and nl_refs.aa_fakeduck:get() then subs[#subs+1] = "FAKE DUCK" end end)
                if aa_on and aa_eng.manual ~= "" then subs[#subs+1] = "MANUAL " .. aa_eng.manual end
                -- v5.0 states
                if aa_on and aa_eng.sh_active then subs[#subs+1] = "SAFE HEAD" end
                if aa_on and aa_eng.onuse_active then subs[#subs+1] = "LEGIT" end
                if aa_on and aa_eng.sends < (aa_eng.freeze_until or 0) then subs[#subs+1] = "FREEZE" end
                if aa_on and aa_eng.edge_active then subs[#subs+1] = "EDGE" end
                if VIS.fl_line:get() then
                    local ck = globals.choked_commands or 0
                    if ck >= 3 then subs[#subs+1] = "FL " .. ck end
                end
                -- desync value (smoothed) + v5.0 wing bar fraction
                local dline, dfrac = nil, 0
                if (vis_desyncpct:get() or VIS.desync_bar:get()) and rage and rage.antiaim and rage.antiaim.get_rotation then
                    local fk, rl = rage.antiaim:get_rotation(true), rage.antiaim:get_rotation()
                    if fk and rl then
                        local diff = math.abs(((rl - fk + 180) % 360) - 180)
                        local maxd = 60
                        pcall(function() if rage.antiaim.get_max_desync then maxd = rage.antiaim:get_max_desync() or 60 end end)
                        local d = math.min(diff / 2, 60)
                        _vis_state.desync_shown = _vis_state.desync_shown + (d - _vis_state.desync_shown) * 0.06
                        if vis_desyncpct:get() then dline = string.format("DESYNC %.0f", _vis_state.desync_shown) end
                        dfrac = math.min(1, (diff / 2) / math.max(1, maxd))
                    end
                end
                -- centered text stack under the crosshair
                local y = cy + 24
                -- v5.0 DT charge ring (evalate / nexus) left of the title
                if VIS.dt_ring:get() then
                    pcall(function()
                        if nl_refs.rage_dt and nl_refs.rage_dt:get() then
                            local ch = math.max(0, math.min(1, aa_eng.charge or 0))
                            local rc = (ch >= 1) and color(120, 255, 120, 255) or color(255, 90, 90, 255)
                            render.circle_outline(vector(cx - 34, y + 8), color(0, 0, 0, 160), 6, 0, 1, 2)
                            render.circle_outline(vector(cx - 34, y + 8), rc, 6, 0, ch, 2)
                        end
                    end)
                end
                -- v5.0: shadowed text (readable on bright maps), the state line cross-fades
                -- when the state changes (per-line alpha via vis_fade)
                local function ctext(font, txt, col, key)
                    local tw = 0
                    pcall(function() tw = render.measure_text(font, nil, txt).x end)
                    if tw <= 0 then tw = #txt * 6 end
                    local a = 1
                    if key then a = vis_fade(key, true, 0.25) end
                    vis_tsh(font, cx - tw / 2, y, color(col.r, col.g, col.b, math.floor((col.a or 255) * a)), txt)
                    y = y + (font >= 4 and 16 or 13)
                end
                ctext(4, "SEL01", color(120, 200, 255, 255))
                -- v5.0 desync bar: two wings (evalate) — the side the body faces is bright
                if VIS.desync_bar:get() then
                    pcall(function()
                        local w = 38 * dfrac
                        local bright, dimc = color(120, 200, 255, 230), color(120, 200, 255, 70)
                        local trans = color(120, 200, 255, 0)
                        local ls = (aa_jitter_dir or 1) < 0
                        render.gradient(vector(cx - 2 - w, y + 1), vector(cx - 2, y + 4), trans, ls and bright or dimc, trans, ls and bright or dimc)
                        render.gradient(vector(cx + 2, y + 1), vector(cx + 2 + w, y + 4), ls and dimc or bright, trans, ls and dimc or bright, trans)
                    end)
                    y = y + 6
                end
                -- state line cross-fade: the previous state word keeps its fade key alive
                -- (vis_fade drops it once it is off), so the switch reads as a soft blend
                if _vis_state.last_mstate ~= mstate then
                    if _vis_state.last_mstate then VIS_FADE["st:" .. mstate] = 0 end
                    _vis_state.last_mstate = mstate
                end
                ctext(3, "- " .. mstate .. " -", color(210, 215, 225, 215), "st:" .. mstate)
                if dline then ctext(3, dline, color(150, 200, 255, 215)) end
                for i = 1, #subs do ctext(3, subs[i], color(170, 230, 175, 230), "sub:" .. subs[i]) end
                -- retire fade keys of sub states no longer shown (keeps the table small)
                for k, _ in pairs(VIS_FADE) do
                    if k:sub(1, 4) == "sub:" then
                        local keep = false
                        for i = 1, #subs do if "sub:" .. subs[i] == k then keep = true; break end end
                        if not keep then vis_fade(k, false, 0.25) end
                    elseif k:sub(1, 3) == "st:" and k ~= "st:" .. mstate then vis_fade(k, false, 0.25) end
                end
                -- v5.0 min-damage indicator (Andromeda / spectral / nexus): above-right of the
                -- crosshair while a Min. Damage bind is active or an override exists (or menu open)
                if VIS.md_ind:get() then
                    pcall(function()
                        local active = false
                        local ov = nil
                        if nl_refs.rage_mindmg and nl_refs.rage_mindmg.get_override then ov = nl_refs.rage_mindmg:get_override() end
                        if ov ~= nil then active = true end
                        if not active and ui.get_binds then
                            for _, b in ipairs(ui.get_binds() or {}) do
                                if b and b.active and tostring(b.name or ""):find("Min. Damage", 1, true) then active = true; break end
                            end
                        end
                        local menu_open = ui.get_alpha and ui.get_alpha() > 0
                        if active or menu_open then
                            local v = tostring(nl_refs.rage_mindmg and nl_refs.rage_mindmg:get() or "?")
                            local col = active and color(255, 255, 255, 255) or color(255, 255, 255, 120)
                            render.text(3, vector(cx + 14, cy - 24), col, nil, "MD " .. v)
                        end
                    end)
                end
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
                local dbx, dby = vis_drag_pos("velocity", cx - (isz.x + 6 + box.x) / 2, sy * 0.18, isz.x + 6 + box.x, 34)
                local base = vector(dbx, dby)
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
        -- v5.0: each entry is a glass row with a colored accent bar (kill green / hit by
        -- damage / miss red), slides in from the left for 0.15s and fades out at the end.
        if vis_hitlog:get() then
            local hx, hy = vis_drag_pos("eventlog", 16, 16, 240, 78)
            local row = 0
            local f = vis_font()
            -- demo rows while the menu is open (so the box can be placed)
            if VIS_DRAG.menu and #hit_log == 0 and not _vis_state.demo_log then
                _vis_state.demo_log = true
                hit_log[1] = { time = now + 99, kind = "hit", name = "enemy", dmg = 87, hitbox = "head", demo = true }
                hit_log[2] = { time = now + 99, kind = "miss", name = "enemy", hitbox = "chest", reason = "spread", demo = true }
            elseif not VIS_DRAG.menu and _vis_state.demo_log then
                _vis_state.demo_log = false
                for i = #hit_log, 1, -1 do if hit_log[i].demo then table.remove(hit_log, i) end end
            end
            for i = #hit_log, 1, -1 do
                local entry = hit_log[i]
                local age = entry.demo and 0.5 or (now - entry.time)
                if age > HITLOG_DURATION_S then
                    table.remove(hit_log, i)
                else
                    local fade = 1
                    if age > HITLOG_DURATION_S - 0.8 then fade = (HITLOG_DURATION_S - age) / 0.8 end
                    local slide = math.min(1, age / 0.15)
                    local ease = 1 - (1 - slide) * (1 - slide)
                    local alpha = math.floor(255 * fade)
                    local y     = hy + row * 20
                    local kind  = entry.kind or "hit"
                    local txt, col
                    if kind == "kill" then
                        txt, col = string.format("KILL   %s", entry.name or "?"), color(120, 255, 120, alpha)
                    elseif kind == "miss" then
                        txt, col = string.format("MISS   %s  [%s]  %s", entry.name or "?", entry.hitbox or "?", entry.reason or "?"), color(255, 100, 100, alpha)
                    else
                        local dmg = entry.dmg or 0
                        local r, g, b = 220, 220, 220
                        if dmg >= 100 then r, g, b = 255, 200, 60
                        elseif dmg >= 70 then r, g, b = 255, 170, 80
                        elseif dmg >= 40 then r, g, b = 200, 220, 120 end
                        txt, col = string.format("HIT    %s  [%s]  +%d", entry.name or "?", entry.hitbox or "?", dmg), color(r, g, b, alpha)
                    end
                    pcall(function()
                        local tw = 0
                        pcall(function() tw = render.measure_text(f, nil, txt).x end)
                        local x = hx - 40 * (1 - ease)
                        local w = tw + 22
                        vis_glass(x, y, x + w, y + 18, fade, 5)
                        vis_accent_bar(x, y + 3, y + 15, col)
                        vis_tsh(f, x + 10, y + 3, col, txt)
                    end)
                    row = row + 1
                end
            end
        end

        -- ── v4.1: AI PEEK drawing (peek point + target hitbox + candidates) ──
        if AIP.vis:get() and ai_peek.phase ~= "off" then
            pcall(function()
                if ai_peek.anchor then render.circle_3d(ai_peek.anchor, color(120, 200, 255, 200), 6, 0, 1) end
                for _, pt in ipairs(ai_peek.points or {}) do
                    render.circle_3d(vector(pt.x, pt.y, pt.z - 60), color(255, 255, 255, 90), 3, 0, 1)
                end
                local s = ai_peek.shoot
                if s and s.pos and s.hb then
                    render.circle_3d(vector(s.pos.x, s.pos.y, s.pos.z - 60), color(80, 255, 120, 230), 5, 0, 1)
                    render.circle_3d(s.hb, color(255, 80, 80, 230), 3, 0, 1)
                    render.line_3d(vector(s.pos.x, s.pos.y, s.pos.z), s.hb, color(80, 255, 120, 120))
                end
            end)
        end

        -- ── KEYBINDS PANEL (right-middle, active hotkeys list) ──
        if vis_keybinds:get() then
            local active = {}
            -- V2.7: show Peek Boost active state
            if _peek_boost_active then
                table.insert(active, "Peek Boost: ACTIVE")
            end
            if ai_peek.phase ~= "off" then
                table.insert(active, "AI Peek: " .. string.upper(ai_peek.phase) .. (ai_peek.shoot and " (shot)" or ""))
            end
            -- v5.0: every active NL bind (evalate / nexus / arc pattern: ui.get_binds())
            if VIS.keybinds_nl:get() then
                pcall(function()
                    local binds = ui.get_binds and ui.get_binds() or nil
                    if not binds then return end
                    for _, b in ipairs(binds) do
                        if b and b.active then
                            local nm = tostring(b.name or "?")
                            nm = nm:gsub("\a%x%x%x%x%x%x%x%x", ""):gsub("\a%b{}", ""):gsub("\aDEFAULT", "")
                            -- NL docs: mode 1 = Hold, 2 = Toggle
                            local m = b.mode
                            local mode = (m == 1 or m == "1") and " [hold]" or ((m == 2 or m == "2") and " [toggle]" or "")
                            if mode == "" and type(m) == "string" and #m > 0 then mode = " [" .. m:lower() .. "]" end
                            if #active < 14 then table.insert(active, nm .. mode) end
                        end
                    end
                end)
            end
            -- v5.0 glass panel (nexus / spectral keybinds): header row with an accent line,
            -- rows fade in / out individually, the [mode] sits right-aligned and dimmed.
            -- Demo rows while the menu is open so the panel can be seen / placed.
            pcall(function()
                local menu_open = ui.get_alpha and ui.get_alpha() > 0
                if #active == 0 and menu_open then active = { "double tap [toggle]", "hide shots [hold]" } end
                local want = {}
                for _, n in ipairs(active) do want[n] = true end
                local rows = {}
                for _, n in ipairs(active) do rows[#rows + 1] = n end
                for k, _ in pairs(VIS_FADE) do
                    local n = k:match("^kb:(.+)$")
                    if n and n ~= "panel" and not want[n] then rows[#rows + 1] = n end
                end
                local vis_rows = {}
                for _, n in ipairs(rows) do
                    local a = vis_fade("kb:" .. n, want[n] == true)
                    if a > 0.01 then vis_rows[#vis_rows + 1] = { n, a } end
                end
                local pa = vis_fade("kb:panel", #vis_rows > 0)
                if pa <= 0.01 then return end
                local f = vis_font()
                local lh, pw = 16, 168
                local h = 22
                for _, r in ipairs(vis_rows) do h = h + lh * r[2] end
                local bx, by = vis_drag_pos("keybinds", sx - 190, sy / 2 + 80, pw, h + 4)
                vis_glass(bx, by, bx + pw, by + h + 4, pa, 6)
                vis_tsh(f, bx + 9, by + 5, color(180, 220, 255, math.floor(255 * pa)), "keybinds")
                render.rect(vector(bx + 8, by + 20), vector(bx + pw - 8, by + 21), color(120, 180, 255, math.floor(120 * pa)))
                local y = by + 24
                for _, r in ipairs(vis_rows) do
                    local n, a = r[1], r[2] * pa
                    local nm, mode = n:match("^(.-)%s*(%[.-%])$")
                    if not nm then nm, mode = n, "" end
                    vis_tsh(f, bx + 9, y, color(225, 230, 240, math.floor(240 * a)), nm)
                    if #mode > 0 then
                        local mw = 0
                        pcall(function() mw = render.measure_text(f, nil, mode).x end)
                        vis_tsh(f, bx + pw - 9 - mw, y, color(150, 158, 175, math.floor(220 * a)), mode)
                    end
                    y = y + lh * r[2]
                end
            end)
        end

        -- ── CLANTAG UPDATE ── (v3.18: moved OUT of render → net_update_end below.
        -- common.set_clan_tag is a game-state write; called from the render/paint
        -- thread it was silently ignored, so the animated tag never changed. The
        -- working bloodwings pattern drives it from events.net_update_end.)

        -- ── SPECTATOR OVERLAY (left-middle) ──
        if vis_specoverlay:get() then
            pcall(function()
                local menu_open = VIS_DRAG.menu
                local pa = vis_fade("spec:panel", #specs > 0 or menu_open)
                if pa <= 0.01 then return end
                local list = specs
                if #list == 0 and menu_open then list = { "(nobody yet)" } end
                local f = vis_font()
                local lh, pw = 16, 180
                local h = 26 + #list * lh
                local bx, by = vis_drag_pos("spectators", 16, sy / 2 - h / 2, pw, h)
                vis_glass(bx, by, bx + pw, by + h, pa, 6)
                vis_accent_bar(bx, by + 6, by + h - 6, color(255, 180, 80, math.floor(220 * pa)))
                vis_tsh(f, bx + 12, by + 5, color(255, 180, 80, math.floor(255 * pa)), string.format("spectators  %d", #specs))
                render.rect(vector(bx + 11, by + 20), vector(bx + pw - 8, by + 21), color(255, 180, 80, math.floor(90 * pa)))
                for i, name in ipairs(list) do
                    vis_tsh(f, bx + 12, by + 8 + i * lh, color(225, 230, 240, math.floor(240 * pa)), name)
                end
            end)
        end

        -- ── v5.0 LEFT-EDGE SIDE INDICATORS (elysian / Andromeda / nexus / arc skeet style) ──
        -- Vertical list at x=6 stacking UPWARD from sy - offset. Each row: mirrored gradient
        -- pill + text. Rows: DT (fill = charge), HS, FS, FD, DA, PING, LC, DMG, DEF, ABF, SH.
        if VIS.side_ind:get() and globals.is_in_game then
            pcall(function()
                local lp = entity.get_local_player()
                if not (lp and lp:is_alive()) then return end
                local rows = {}
                local white, red, green, grey = color(220, 225, 235, 230), color(255, 70, 90, 230), color(120, 255, 120, 230), color(150, 150, 160, 200)
                local dt_on = nl_refs.rage_dt and nl_refs.rage_dt:get()
                if dt_on then
                    local ch = math.max(0, math.min(1, aa_eng.charge or 0))
                    rows[#rows+1] = { "DT", (ch >= 1) and white or red, ch }
                end
                if nl_refs.rage_hide and nl_refs.rage_hide:get() then rows[#rows+1] = { "HS", white } end
                if aa_eng.free_w then rows[#rows+1] = { "FS", white } end
                if nl_refs.aa_fakeduck and nl_refs.aa_fakeduck:get() then rows[#rows+1] = { "FD", white } end
                if nl_refs.rage_dormant and nl_refs.rage_dormant:get() then rows[#rows+1] = { "DA", white } end
                local fl = tonumber(nl_refs.misc_fakelat and nl_refs.misc_fakelat:get()) or 0
                if fl > 0 then rows[#rows+1] = { "PING", color(151, 175, 54, 230) } end
                if (aa_eng.defensive or 0) > 0 then rows[#rows+1] = { "LC " .. aa_eng.defensive, color(101, 213, 255, 230) } end
                if aa_eng.def_pulse then rows[#rows+1] = { "DEF", color(101, 213, 255, 230) } end
                if next(aa_eng.ab) ~= nil then rows[#rows+1] = { "ABF", color(255, 175, 104, 230) } end
                if aa_eng.sh_active then rows[#rows+1] = { "SH", white } end
                local md = nl_refs.rage_mindmg and nl_refs.rage_mindmg:get()
                if md then rows[#rows+1] = { "DMG " .. tostring(md), grey } end
                -- demo rows while the menu is open (so the stack can be placed by dragging)
                if VIS_DRAG.menu and #rows == 0 then rows = { { "DT", white, 0.6 }, { "HS", white }, { "DMG 100", grey } } end
                -- rows slide in from the left edge and fade out individually (elysian)
                local want = {}
                for _, r in ipairs(rows) do want[r[1]] = r end
                local all = {}
                for _, r in ipairs(rows) do all[#all + 1] = r[1] end
                for k, _ in pairs(VIS_FADE) do
                    local n = k:match("^side:(.+)$")
                    if n and not want[n] then all[#all + 1] = n end
                end
                local rh, gap, w = 20, 4, 74
                -- draggable: the box is the stack's full height (rows stack upward from y)
                local stack_h = math.max(1, #rows) * (rh + gap)
                local dx, dy = vis_drag_pos("sideind", 6, sy - VIS.side_off:get() - stack_h, w, stack_h)
                local x, y = dx, dy + stack_h
                local f = vis_font()
                for _, name in ipairs(all) do
                    local r = want[name] or _vis_state["side_" .. name]
                    if r then
                        _vis_state["side_" .. name] = r
                        local a = vis_fade("side:" .. name, want[name] ~= nil, 0.2)
                        if a > 0.01 then
                            local txt, col, fill = r[1], r[2], r[3]
                            local h = rh * a
                            local y1, y2 = y - h, y
                            local xx = x - (1 - a) * 30
                            local bg, trans = color(10, 12, 18, math.floor(170 * a)), color(10, 12, 18, 0)
                            render.gradient(vector(xx, y1), vector(xx + w / 2, y2), trans, bg, trans, bg)
                            render.gradient(vector(xx + w / 2, y1), vector(xx + w, y2), bg, trans, bg, trans)
                            render.rect(vector(xx + 6, y1), vector(xx + w - 6, y1 + 1), color(255, 255, 255, math.floor(28 * a)))
                            if fill then
                                render.rect(vector(xx + 4, y2 - 3), vector(xx + 4 + (w - 8) * fill, y2 - 1), color(col.r, col.g, col.b, math.floor(70 * a)))
                            end
                            vis_tsh(f, xx + 8, y1 + 3, color(col.r, col.g, col.b, math.floor((col.a or 255) * a)), txt)
                            y = y1 - gap * a
                        end
                    end
                end
            end)
        end

        -- ── v5.0 DEFENSIVE GLYPH (elysian ✦ pulse at the bottom center) ──
        if VIS.def_glyph:get() and (aa_eng.def_pulse or (aa_eng.defensive or 0) > 0) then
            pcall(function()
                local a = math.floor(150 + 105 * math.sin(now * 9))
                render.text(4, vector(cx - 5, sy - 55 + math.sin(now * 5) * 2), color(150, 195, 255, a), nil, "✦")
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
                -- v5.0 glass panel (arc network metrics): fps / ping / loss / choke / LC, each
                -- value colored by threshold, panel bottom-left above the netgraph area
                local f = vis_font()
                local pw, lh = 150, 15
                local gx, gy = vis_drag_pos("netgraph", 20, sy - 30 - 22 - lh * 5, pw, 22 + lh * 5)
                vis_glass(gx, gy, gx + pw, gy + 22 + lh * 5, 1, 6)
                vis_tsh(f, gx + 9, gy + 5, color(180, 220, 255, 255), "network")
                render.rect(vector(gx + 8, gy + 20), vector(gx + pw - 8, gy + 21), color(120, 180, 255, 120))
                local white = color(225, 230, 240, 240)
                local function line(i, key, val, c)
                    vis_tsh(f, gx + 9, gy + 24 + i * lh, color(150, 158, 175, 220), key)
                    local vw = 0
                    pcall(function() vw = render.measure_text(f, nil, val).x end)
                    vis_tsh(f, gx + pw - 9 - vw, gy + 24 + i * lh, c, val)
                end
                line(0, "fps",   tostring(perf.fps), perf.fps < 60 and color(255, 120, 60, 240) or white)
                line(1, "ping",  ping .. " ms",  ping > 120 and color(255, 120, 60, 240) or white)
                line(2, "loss",  loss .. " %",   loss > 0 and color(255, 120, 60, 240) or white)
                line(3, "choke", choke .. " %",  choke > 0 and color(255, 200, 60, 240) or white)
                -- lag-comp warn: heavy choke = packets held = LC likely breaking
                local ck = globals.choked_commands or 0
                if ck >= 6 then
                    line(4, "lc", "BREAKING " .. ck, color(255, 70, 90, 240))
                else
                    line(4, "lc", "ok", color(143, 194, 21, 240))
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

-- v5.0 Typewriter frames from the custom text (evalate / spectral: type in, hold, scroll out)
local function clantag_typewriter_frames()
    local txt = "Sel01"
    pcall(function() if MISC.ct_custom then txt = tostring(MISC.ct_custom:get() or "Sel01") end end)
    txt = txt:gsub("^%s+", ""):gsub("%s+$", "")
    if #txt == 0 then txt = "Sel01" end
    if misc_eng.ct_txt == txt and misc_eng.ct_frames then return misc_eng.ct_frames end
    local f = {}
    for i = 1, #txt do f[#f + 1] = txt:sub(1, i) end
    for i = 1, 4 do f[#f + 1] = txt end
    for i = 2, #txt do f[#f + 1] = txt:sub(i) end
    f[#f + 1] = "-"
    misc_eng.ct_txt, misc_eng.ct_frames = txt, f
    return f
end
local clantag_last_sent = nil
update_clantag = function()
    if not (enable_master:get() and qol_clantag:get()) then return end
    local now = globals.realtime or 0
    local style = qol_clantag_st:get()
    local frames = CLANTAG_FRAMES.wave
    if     style == "Spin"    then frames = CLANTAG_FRAMES.spin
    elseif style == "Pulse"   then frames = CLANTAG_FRAMES.pulse
    elseif style == "Loading" then frames = CLANTAG_FRAMES.load
    elseif style == "Scan"    then frames = CLANTAG_FRAMES.scan
    elseif style == "Glitch"  then frames = CLANTAG_FRAMES.glitch
    elseif style == "Arrow"   then frames = CLANTAG_FRAMES.arrow
    elseif style == "Rage"    then frames = CLANTAG_FRAMES.rage
    elseif style == "Typewriter (custom text)" then frames = clantag_typewriter_frames()
    end
    local frame
    if MISC.ct_lat:get() then
        -- arc / spectral / evalate: index from tickcount + latency so everyone sees it in sync
        local lat_ticks = 0
        pcall(function()
            local nc = utils.net_channel and utils.net_channel()
            local lat = nc and nc.latency and nc.latency[1] or 0
            lat_ticks = math.floor(lat / (globals.tickinterval or 0.015625))
        end)
        local idx = math.floor(((globals.tickcount or 0) + lat_ticks) / 17) % #frames + 1
        frame = frames[idx]
    else
        if now - clantag_last_change < 0.4 then return end
        clantag_last_change = now
        clantag_phase = (clantag_phase % #frames) + 1
        frame = frames[clantag_phase]
    end
    if frame == clantag_last_sent then return end   -- CSGO trims + dedupes; only send changes
    clantag_last_sent = frame
    pcall(function()
        -- Verified API from nyanza snapshot + bloodwings: common.set_clan_tag
        if common and common.set_clan_tag then common.set_clan_tag(frame) end
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
_hooks_status.clantag = register_first(function() pcall(update_clantag); pcall(misc_killsay_flush) end,
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
    cs_log(string.format("AA engine: %s active=%s | pitch=%s base=%s dir=%s | state=%s side=%s yaw=%d L/R=%d/%d",
        tostring(AA.enable:get()), tostring(aa_eng.active), tostring(AA.pitch:get()),
        tostring(AA.base:get()), tostring(AA.dir:get()), tostring(aa_eng.state),
        aa_eng.side == 0 and "L" or "R", math.floor(aa_eng.yaw_w or 0), aa_eng.l_w or 0, aa_eng.r_w or 0))
    cs_log(string.format("Defensive: master=%s DT=%s charge=%.0f%% pulses=%d defticks=%d | hidden=%s dtlag=%s | hooks bullet_impact=%s",
        tostring(AA.def_enable:get()), tostring(aa_eng.dt_on), (aa_eng.charge or 0) * 100,
        aa_eng.def_pulses or 0, aa_eng.stats.def_ticks or 0, tostring(aa_eng.hidden_active),
        tostring(aa_eng.dtlag_active), tostring(_hooks_status.bullet_impact or "MISSING")))
    cs_log(string.format("Visuals: watermark=%s indic=%s velwarn=%s arrows=%s hitmark=%s hitlog=%s keybinds=%s dmgind=%s spec=%s",
        tostring(vis_watermark:get()),  tostring(vis_indicators:get()),
        tostring(vis_velwarn:get()),    tostring(vis_aaarrows:get()),
        tostring(vis_hitmarker:get()),  tostring(vis_hitlog:get()),
        tostring(vis_keybinds:get()),   tostring(vis_dmgind:get()),
        tostring(vis_specoverlay:get())))
    cs_log(string.format("QoL: clantag=%s style=%s", tostring(qol_clantag:get()), tostring(qol_clantag_st:get())))
    cs_log("Misc:" .. misc_config_line())
    cs_log(string.format("Perf: FPS=%d ping=%d ms", perf.fps, perf.ping))
    cs_log_color("══ END STATUS ══")
end
pcall(function() btn_status:set_callback(function() dump_status() end) end)
pcall(function() btn_reset:set_callback(function() apply_preset("nyanza") end) end)
pcall(function() VIS.drag_reset:set_callback(function() pending_drag_reset = true end) end)
-- v5.0 warmup config button (Andromeda one-click cvars; only works on your own server)
pcall(function() MISC.warmup:set_callback(function()
    pcall(function()
        utils.console_exec("sv_cheats 1;mp_roundtime_defuse 99999;mp_warmup_end;mp_buytime 99999999;mp_buy_anywhere 1;sv_infinite_ammo 1;impulse 101;sv_airaccelerate 100;sv_regeneration_force_on 1;mp_respawn_on_death_ct 1;mp_respawn_on_death_t 1;bot_stop 1;mp_roundtime_hostage 10000")
        cs_log_color("warmup config sent (sv_cheats, infinite ammo, buy anywhere, respawn, bot_stop)")
    end)
end) end)

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
-- v4.1: EFFECTIVE value — the live :override when one is set, else the menu value.
-- The first real dump printed menu values (mod=3-Way, opts=Jitter) while the engine was
-- overriding them, which read like the engine was not writing at all.
local function _nl_eff(ref, fallback)
    if not ref then return fallback end
    local ov = nil
    pcall(function() if ref.get_override then ov = ref:get_override() end end)
    if ov ~= nil then return ov end
    return _nl_get(ref, fallback)
end
local function _b(v) return v and "ON" or "OFF" end
-- multi-select :get() returns a table (array of labels OR {label=true}); join it
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

-- v4.0: engine config as text — shared by Dump Debug Stats + Copy Last Logs
local function aa_state_line(key)
    local S = AA.st[key]
    if not S then return "  " .. key .. " (missing)" end
    local ug = false
    if S.use_global then pcall(function() ug = S.use_global:get() end) end
    if ug then return string.format("  %-8s → Global", key) end
    local seq = {}
    for i = 1, 6 do local v = S["sw_seq" .. i]:get(); if v > 0 then seq[#seq + 1] = tostring(v) end end
    return string.format("  %-8s base=%s yaw=%s L%d/R%d jit=%d rnd=%d | body=%s(t%d) mag=%s L%d/R%d min%d ab%d | switch=%s d=%d r=%d-%d R%d-%d seq[%s] | free=%s def=%s fl=%d",
        key, tostring(S.base:get()), tostring(S.yaw_mode:get()), S.yaw_l:get(), S.yaw_r:get(), S.yaw_jit:get(), S.yaw_rand:get(),
        tostring(S.body_mode:get()), S.body_ticks:get(), tostring(S.body_mag:get()), S.body_l:get(), S.body_r:get(), S.body_min:get(), S.body_swd:get(),
        tostring(S.sw_mode:get()), S.sw_delay:get(), S.sw_lo:get(), S.sw_hi:get(), S.sw_rlo:get(), S.sw_rhi:get(), table.concat(seq, ","),
        _b(S.freestand:get()), tostring(S.defensive:get()), S.fakelag:get())
end
local function aa_engine_config_lines()
    local L = {}
    L[#L + 1] = string.format("  engine=%s active=%s pitch=%s base=%s dir=%s avoid_bs=%s legs=%s idle=%s/%d/%s manual_static=%s man_base=%s",
        _b(AA.enable:get()), _b(aa_eng.active), tostring(AA.pitch:get()), tostring(AA.base:get()), tostring(AA.dir:get()),
        _b(AA.avoid_bs:get()), tostring(AA.legs:get()), tostring(AA.idle_mode:get()), AA.idle_speed:get(), tostring(AA.idle_pitch:get()),
        _b(AA.man_static:get()), tostring(AA.man_base:get()))
    local seq = {}
    for i = 1, 6 do seq[i] = tostring(AA.def_seq[i]:get()) end
    L[#L + 1] = string.format("  defensive: master=%s mode=%s N=%d rnd=%d-%d seq[%s] events=%s pause=%s clean=%s dtlag=%s hs_opts=%s air=%s/%d fix_rechg=%s | fakelag var=%s force=%s off:dt=%s hs=%s stand=%s | hidden=%s pitch=%s yaw=%s(%d) when=%s",
        _b(AA.def_enable:get()), tostring(AA.def_mode:get()), AA.def_int:get(), AA.def_lo:get(), AA.def_hi:get(), table.concat(seq, ","),
        _b(AA.def_events:get()), _b(AA.def_pause:get()), tostring(AA.def_clean:get()),
        _b(AA.def_lag:get()), tostring(AA.hs_opts:get()), tostring(AA.air_mode:get()), AA.air_n:get(), _b(AA.fix_rechg:get()),
        tostring(AA.fl_mode:get()), _b(AA.fl_force:get()), _b(AA.fl_dis_dt:get()), _b(AA.fl_dis_hs:get()), _b(AA.fl_dis_st:get()),
        _b(AA.dh_enable:get()), tostring(AA.dh_pitch:get()), tostring(AA.dh_yaw:get()), AA.dh_yaw_val:get(), tostring(AA.dh_cond:get()))
    L[#L + 1] = string.format("  anti-BF=%s r=%du dur=%ds flip=%s limit=%s delay=%s yaw=%s mode=%s freeze=%s %d%%/%d | hit-react=%s %dms nofree=%s | head-safe=%s | pitch-jit=%s move-fd=%s@%d",
        _b(AA.ab_enable:get()), AA.ab_radius:get(), AA.ab_dur:get(), _b(AA.ab_flip:get()), _b(AA.ab_limit:get()),
        _b(AA.ab_delay:get()), _b(AA.ab_yaw:get()), tostring(AA.ab_mode:get()), _b(AA.ab_freeze:get()), AA.ab_fchance:get(), AA.ab_fdur:get(),
        _b(AA.hit_react:get()), AA.hit_dur:get(), _b(AA.hit_nofree:get()),
        _b(AA.head_prot:get()), _b(AA.pitch_jitter:get()), _b(AA.move_fd:get()), AA.move_fd_thr:get())
    L[#L + 1] = string.format("  safe-head=%s knife=%s zeus=%s airduck=%s height=%s@%d yaw=%d limit=%d inv=%s | freestand key=%s static=%s | legit-onuse=%s edge=%s",
        _b(AA.sh_enable:get()), _b(AA.sh_knife:get()), _b(AA.sh_zeus:get()), _b(AA.sh_airduck:get()), _b(AA.sh_height:get()), AA.sh_hdiff:get(),
        AA.sh_yaw:get(), AA.sh_limit:get(), _b(AA.sh_inv:get()), _b(AA.fs_key:get()), _b(AA.fs_static:get()), _b(AA.onuse:get()), _b(AA.edge:get()))
    L[#L + 1] = string.format("  live: state=%s side=%s yaw=%d L/R=%d/%d mod=%s(%d) body=%s free=%s | DT=%s HS=%s charge=%.0f%% pulses=%d defticks=%d switches=%d sends=%d | near-miss=%d flips=%d reacts=%d headsafe=%d freezes=%d safehead-ticks=%d legit=%d",
        tostring(aa_eng.state), aa_eng.side == 0 and "L" or "R", math.floor(aa_eng.yaw_w or 0), aa_eng.l_w or 0, aa_eng.r_w or 0,
        tostring(aa_eng.mod_w), aa_eng.modamt_w or 0, _b(aa_eng.body_w), _b(aa_eng.free_w),
        _b(aa_eng.dt_on), _b(aa_eng.hs_on), (aa_eng.charge or 0) * 100, aa_eng.def_pulses or 0, aa_eng.stats.def_ticks or 0,
        aa_eng.switches or 0, aa_eng.sends or 0, aa_eng.stats.near_miss or 0, aa_eng.stats.flips or 0,
        aa_eng.stats.react or 0, aa_eng.stats.hp_pulses or 0, aa_eng.stats.freezes or 0, aa_eng.stats.sh_ticks or 0, aa_eng.stats.onuse or 0)
    for _, st in ipairs(AA_STATES) do L[#L + 1] = aa_state_line(st.key) end
    return L
end
-- v5.0 Misc tab config as text (Copy Last Logs + Dump). GLOBAL: dump_status above this
-- line calls it too (a local here would bind that closure to a nil global).
function misc_config_line()
    return string.format("  ladder=%s nofall=%s fdspeed=%s edgestop=%s(%d) jumpscout=%s autohs=%s(st%s du%s sw%s nopistol%s) fakelat=%s@%d fps=%s vm=%s(%d/%d/%d/%d knife%s) aspect=%s@%d killsay=%s/%s rv=%s deathsay=%s ct_lat=%s anim=%s(lean%s@%d legs%s land%s fall%s) | live: hs_ov=%s airstrafe_ov=%s autostop_ov=%s legs_ov=%s killsay_q=%d",
        _b(MISC.ladder:get()), _b(MISC.nofall:get()), _b(MISC.fd_speed:get()), _b(MISC.edge_stop:get()), misc_eng.edge_stopped or 0,
        _b(MISC.jump_scout:get()), _b(MISC.auto_hs:get()), _b(MISC.auto_hs_st:get()), _b(MISC.auto_hs_du:get()), _b(MISC.auto_hs_sw:get()), _b(MISC.auto_hs_pi:get()),
        _b(MISC.fakelat:get()), MISC.fakelat_v:get(), _b(MISC.fps:get()),
        _b(MISC.vm:get()), MISC.vm_fov:get(), MISC.vm_x:get(), MISC.vm_y:get(), MISC.vm_z:get(), _b(MISC.vm_knife:get()),
        _b(MISC.aspect:get()), MISC.aspect_v:get(), _b(MISC.killsay:get()), tostring(MISC.killsay_st:get()), _b(MISC.killsay_rv:get()), _b(MISC.deathsay:get()),
        _b(MISC.ct_lat:get()), _b(MISC.anim:get()), _b(MISC.anim_lean:get()), MISC.anim_leanw:get(), _b(MISC.anim_legs:get()), _b(MISC.anim_land:get()), _b(MISC.anim_fall:get()),
        _b(misc_eng.hs_ov), _b(misc_eng.airstrafe_ov), _b(misc_eng.autostop_ov), _b(misc_eng.legs_ov), #misc_eng.killsay_q)
end

-- v4.0: data-driven hints from the hits-taken snapshots (what to change, and why)
local function aa_hints()
    local H = {}
    local n = #hits_taken_log
    if n == 0 then H[#H + 1] = "no hits taken this session — nothing to tune yet"; return H end
    local by_state, by_side, head, nodt, uncharged, nothreat, pulsing, late_sw, react_hits, air = {}, { L = 0, R = 0 }, 0, 0, 0, 0, 0, 0, 0, 0
    local def_active_hits, ug_hits, deaths = 0, 0, 0
    for _, e in ipairs(hits_taken_log) do
        local s = e.snapshot or {}
        by_state[s.state or "?"] = (by_state[s.state or "?"] or 0) + 1
        if s.side then by_side[s.side] = (by_side[s.side] or 0) + 1 end
        if e.hb_id == 1 then head = head + 1 end
        if s.dt == false then nodt = nodt + 1 elseif (s.charge or 0) < 1 then uncharged = uncharged + 1 end
        if s.threat == false then nothreat = nothreat + 1 end
        if s.def_pulse then pulsing = pulsing + 1 end
        if s.def_pulse or (s.def_ticks or 0) > 0 or s.dtlag then def_active_hits = def_active_hits + 1 end
        if (s.since_switch or 0) > 0.25 then late_sw = late_sw + 1 end
        if s.react then react_hits = react_hits + 1 end
        -- v4.1: air by ENGINE state (the raw flag reads airborne on a death snapshot)
        if s.state == "air" or s.state == "airduck" then air = air + 1 end
        if s.uses_global then ug_hits = ug_hits + 1 end
        if (e.hp_left or 1) <= 0 then deaths = deaths + 1 end
    end
    local top_state, top_n = "?", 0
    for k, v in pairs(by_state) do if v > top_n then top_state, top_n = k, v end end
    if n >= 3 and top_n / n >= 0.5 then
        local tip = ({
            slow   = "Slow-Walk: set defensive=Always, Min magnitude 45+, Random delay 1-2 sends, Freestanding OFF (deterministic side is resolvable)",
            stand  = "Standing: raise Center jitter (24-30) + Random Min-Max magnitude; if head hits, try Head-safe pulses",
            move   = "Moving: Fixed delay 2 → Random 1-3 sends, Min magnitude 30+, Freestanding OFF",
            air    = "Air: defensive=Always + Air-lag (Aggressive) and Random yaw 26-34",
            duck   = "Crouching: usually the body is safe — check if these were head hits and lower yaw offsets",
            airduck= "Air-Crouch: Static yaw + Random side is expected to take hits; jump less into open angles",
            duckmv = "Crouch-Move: use its own settings (Use Global OFF) with Random Min-Max magnitude",
        })[top_state] or "check that state's settings"
        H[#H + 1] = string.format("%d/%d hits while %s → %s", top_n, n, tostring(top_state), tip)
    end
    if n >= 3 and head / n >= 0.5 then
        H[#H + 1] = string.format("%d/%d hits were HEAD → the resolver has your side/yaw: lower yaw offsets, enable Head-safe pulses or Pitch jitter, raise switch randomness", head, n)
    end
    if n >= 4 then
        local dom = math.max(by_side.L or 0, by_side.R or 0)
        if dom / n >= 0.8 then
            H[#H + 1] = string.format("%d/%d hits on side %s → they resolve one side; switch faster (Every send / Random 1-2) or use Random side body mode", dom, n, (by_side.L or 0) >= (by_side.R or 0) and "L" or "R")
        end
    end
    if nodt > 0 then H[#H + 1] = string.format("%d hits with Double Tap OFF → defensive AA cannot run without DT; enable NL Double Tap", nodt) end
    if uncharged > 0 then H[#H + 1] = string.format("%d hits while DT was NOT charged → you were hit right after shooting; enable 'DT Lag Options = Always On' or peek less after a shot", uncharged) end
    if n >= 3 and pulsing == 0 and nodt + uncharged < n then H[#H + 1] = "defensive never pulsed at a hit → check per-state 'Defensive AA' (Off?) or use 'Always' on the states you die in" end
    if nothreat >= 2 then H[#H + 1] = string.format("%d hits from a non-threat (no hittable enemy known) → dormant / unexpected angle; not an AA problem", nothreat) end
    if def_active_hits >= 2 then H[#H + 1] = string.format("%d hits landed WHILE defensive was active (pulse / shifted ticks / DT lag) → their resolver ignores defensive records; defensive alone will not save you, vary yaw + magnitude harder", def_active_hits) end
    if n >= 4 and ug_hits / n >= 0.5 then H[#H + 1] = string.format("%d/%d hits in states that use the GLOBAL rows → give those states their own settings (Use Global OFF)", ug_hits, n) end
    if deaths >= 3 and deaths / n >= 0.6 then H[#H + 1] = string.format("%d/%d hits were one-taps (hp 0) → sniper lobby: body-yaw magnitude matters less than SIDE + timing; prefer Every send / Random 1-2 and defensive Always", deaths, n) end
    if n >= 3 and late_sw / n >= 0.6 then H[#H + 1] = string.format("%d/%d hits landed >0.25s after the last side switch → switch delay too long for this lobby", late_sw, n) end
    if react_hits >= 2 then H[#H + 1] = string.format("%d hits INSIDE a hit-reaction burst → they re-hit you after the flip; try a longer burst or Random side during the burst", react_hits) end
    if air >= 2 then H[#H + 1] = string.format("%d hits airborne → Air-lag (Aggressive preset) or stop jumping into their angle", air) end
    -- who resolves you
    local worst, wn = nil, 0
    for name, A in pairs(attackers) do if A.hits > wn then worst, wn = name, A.hits end end
    if worst and wn >= 3 then
        local A = attackers[worst]
        H[#H + 1] = string.format("%s hit you %d× (%d head, %d dmg) → this one resolves you; they may run a learning resolver, vary states against them", worst, wn, A.head, A.dmg)
    end
    local nm = aa_eng.stats.near_miss or 0
    if nm + n > 0 then
        H[#H + 1] = string.format("enemy accuracy on you: %d hits vs %d near-misses (%.0f%% miss) — near-misses trigger anti-bruteforce", n, nm, nm / (nm + n) * 100)
    end
    if #H == 0 then H[#H + 1] = "no dominant pattern in the hits taken — keep the current preset" end
    return H
end

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
    cs_log(string.format("  Time: %.1f min  |  Master=%s  AA-engine=%s (active=%s)",
        elapsed / 60, _b(enable_master:get()), _b(AA.enable:get()), _b(aa_eng.active)))

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
            cs_log(string.format("  [%.1fs ago] %s hit %s for %d (%s, hp_left=%d)",
                now - e.time, e.atk_name or "?", e.hitbox or "?", e.dmg or 0, tostring(e.weapon or "?"), e.hp_left or 0))
            for _, line in ipairs(aa_fmt_snapshot(e.snapshot, "    ")) do cs_log(line) end
        end
    end

    -- ── AA ENGINE (v5.0) ──
    cs_log_color("── AA ENGINE (v5.0) ──")
    for _, line in ipairs(aa_engine_config_lines()) do cs_log(line) end
    cs_log_color("── MISC (v5.0) ──")
    cs_log(misc_config_line())

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
        if not AA.pitch_jitter:get() then
            cs_log("[DEFENSE] Pitch jitter OFF — head Y stays constant. Click Anti-HS Bundle to enable.")
        end
        if not AA.move_fd:get() then
            cs_log("[DEFENSE] Auto fake-duck OFF — running head exposed. Click Anti-HS Bundle to enable.")
        end
    end
    for _, h in ipairs(aa_hints()) do cs_log("[AA] " .. h) end

    -- K/D-ish guidance
    if taken >= 5 and kd < 1 then
        cs_log(string.format("[KD] %.2f — try Defensive preset or enable Peek Boost hotkey + bind to NL Peek Assist", kd))
    end

    -- Resolver flag check
    cs_log("[TIP] Resolver Aggressive Head-Focus is OFF by default. Enable in Solver tab → Advanced for HS priority.")
    cs_log_color("══ END RECOMMENDATIONS ══")
end
pcall(function() btn_recom:set_callback(function() print_recommendations() end) end)

-- ══════════════════════════════════════════════════════════════════════════
-- v4.0: 📋 COPY LAST LOGS — Solver-style share dump. Clipboard via user32 FFI (same
-- code as Sel01-Solver v8.7/v9.85: NL's ffi state is shared across scripts, so the
-- SetClipboardData proto may already be resident as (UINT, unsigned int) — try the
-- pointer form, then the numeric cast). File fallback nl/Sel01-Config/last_logs.txt.
-- ══════════════════════════════════════════════════════════════════════════
local set_clipboard
do
    local cdef_ok = pcall(ffi.cdef, [[
        typedef void* HANDLE;
        typedef void* HWND;
        typedef unsigned int UINT;
        typedef unsigned long DWORD;
        typedef int BOOL;
        typedef unsigned long SIZE_T;
        HANDLE GlobalAlloc(UINT uFlags, SIZE_T dwBytes);
        void* GlobalLock(HANDLE hMem);
        BOOL GlobalUnlock(HANDLE hMem);
        BOOL OpenClipboard(HWND hWndNewOwner);
        BOOL CloseClipboard();
        BOOL EmptyClipboard();
        HANDLE SetClipboardData(UINT uFormat, HANDLE hMem);
        int MultiByteToWideChar(UINT CodePage, DWORD dwFlags, const char* lpMultiByteStr, int cbMultiByte, void* lpWideCharStr, int cchWideChar);
    ]])
    local ok_k, k32 = pcall(ffi.load, "kernel32")
    local ok_u, u32 = pcall(ffi.load, "user32")
    if ok_k and ok_u then
        set_clipboard = function(text)
            local ok, err = pcall(function()
                text = tostring(text or "")
                local n = k32.MultiByteToWideChar(65001, 0, text, #text, nil, 0)
                if n <= 0 then error("size=0") end
                local h = k32.GlobalAlloc(0x0002, (n + 1) * 2)
                if h == nil then error("GlobalAlloc") end
                local ptr = k32.GlobalLock(h)
                k32.MultiByteToWideChar(65001, 0, text, #text, ptr, n)
                ffi.cast("unsigned short*", ptr)[n] = 0
                k32.GlobalUnlock(h)
                if u32.OpenClipboard(nil) == 0 then error("OpenClipboard") end
                u32.EmptyClipboard()
                local set_ok = pcall(function() u32.SetClipboardData(13, h) end)
                if not set_ok then
                    set_ok = pcall(function() u32.SetClipboardData(13, ffi.cast("uintptr_t", h)) end)
                end
                u32.CloseClipboard()
                if not set_ok then error("SetClipboardData (all casts failed)") end
            end)
            return ok, err
        end
    else
        set_clipboard = function() return false, "ffi unavailable" end
    end
    if not cdef_ok then cs_log("clipboard cdef already resident (shared ffi state) — using existing protos") end
end

local function config_copy_logs()
    local L = {}
    local function add(s) L[#L + 1] = tostring(s) end
    local now = globals.realtime or 0
    local map = "?"
    pcall(function() map = common.get_map_data().shortname or "?" end)
    add("════ Sel01-Config v" .. SEL01_CFG_VERSION .. " — COPY-FRIENDLY DUMP (hits taken + AA timeline) ════")
    add(string.format("[TIME] session %.1f min | map %s | ping %d ms | fps %d", (now - (stats.session_start or now)) / 60, map, perf.ping or 0, perf.fps or 0))
    local fired, hits = stats.shots_fired, stats.shots_hit
    add(string.format("[SESSION] dealt: %d shots %d hit %d miss = %.1f%% | head=%d chest=%d stomach=%d leg=%d | dmg=%d biggest=%d 1taps=%d kills=%d",
        fired, hits, stats.shots_missed, fired > 0 and hits / fired * 100 or 0,
        stats.hits_head, stats.hits_chest, stats.hits_stomach, stats.hits_leg,
        stats.total_dmg, stats.biggest_hit, stats.one_taps, stats.kills or 0))
    add(string.format("[SESSION] taken: %d hits %d dmg (avg %.1f) | near-misses %d | side flips (reactions) %d | defensive pulses %d, defensive ticks seen %d | switches %d in %d sends",
        stats.hits_taken, stats.dmg_taken, stats.hits_taken > 0 and stats.dmg_taken / stats.hits_taken or 0,
        aa_eng.stats.near_miss or 0, aa_eng.stats.flips or 0, aa_eng.def_pulses or 0, aa_eng.stats.def_ticks or 0,
        aa_eng.switches or 0, aa_eng.sends or 0))
    add("[AA] engine config + live:")
    for _, l in ipairs(aa_engine_config_lines()) do add("[AA]" .. l) end
    add("[MISC]" .. misc_config_line())
    add(string.format("[NL] HC=%s MinDmg=%s DT=%s HS=%s DTlag=%s HSopts=%s SafePoints=%s BodyAim=%s HitboxSafety=%s",
        _fmt_val(_nl_get(nl_refs.rage_hc, "?")), _fmt_val(_nl_get(nl_refs.rage_mindmg, "?")),
        _b(_nl_get(nl_refs.rage_dt, false)), _b(_nl_get(nl_refs.rage_hs, false)),
        _fmt_val(_nl_get(nl_refs.rage_dtlag, "?")), _fmt_val(_nl_get(nl_refs.rage_hs_opts, "?")),
        _fmt_val(_nl_get(nl_refs.rage_safepoint, "?")), _fmt_val(_nl_get(nl_refs.rage_bodyaim, "?")),
        _fmt_val(_nl_get(nl_refs.rage_hitsafety, "?"))))
    add(string.format("[NL] AA (effective = override else menu) enabled=%s pitch=%s yaw=%s base=%s offset=%s mod=%s(%s) bodyyaw=%s inv=%s L/R=%s/%s opts=%s free=%s hidden=%s | fakelag on=%s limit=%s var=%s | fake latency=%s | slowwalk=%s fakeduck=%s",
        _b(_nl_eff(nl_refs.aa_enabled, false)), _fmt_val(_nl_eff(nl_refs.aa_pitch, "?")), _fmt_val(_nl_eff(nl_refs.aa_yaw, "?")),
        _fmt_val(_nl_eff(nl_refs.aa_yaw_base, "?")), tostring(_nl_eff(nl_refs.aa_yaw_offset, "?")),
        _fmt_val(_nl_eff(nl_refs.aa_yawmod, "?")), tostring(_nl_eff(nl_refs.aa_yawmod_offset, "?")),
        _b(_nl_eff(nl_refs.aa_bodyyaw, false)), _b(_nl_eff(nl_refs.aa_bodyyaw_inv, false)),
        tostring(_nl_eff(nl_refs.aa_bodyyaw_l, "?")), tostring(_nl_eff(nl_refs.aa_bodyyaw_r, "?")),
        _fmt_val(_nl_eff(nl_refs.aa_bodyyaw_opts, "?")), _b(_nl_eff(nl_refs.aa_freestand, false)), _b(_nl_eff(nl_refs.aa_yaw_hidden, false)),
        _b(_nl_get(nl_refs.fl_switch, false)), tostring(_nl_eff(nl_refs.fl_limit, "?")), tostring(_nl_get(nl_refs.fl_variability, "?")),
        tostring(_nl_get(nl_refs.misc_fakelat, "?")), _b(_nl_get(nl_refs.aa_slowwalk, false)), _b(_nl_get(nl_refs.aa_fakeduck, false))))
    add(string.format("[NL] AA menu values: pitch=%s yaw=%s base=%s mod=%s(%s) L/R=%s/%s opts=%s free=%s  (what NL falls back to when the engine is off)",
        _fmt_val(_nl_get(nl_refs.aa_pitch, "?")), _fmt_val(_nl_get(nl_refs.aa_yaw, "?")), _fmt_val(_nl_get(nl_refs.aa_yaw_base, "?")),
        _fmt_val(_nl_get(nl_refs.aa_yawmod, "?")), tostring(_nl_get(nl_refs.aa_yawmod_offset, "?")),
        tostring(_nl_get(nl_refs.aa_bodyyaw_l, "?")), tostring(_nl_get(nl_refs.aa_bodyyaw_r, "?")),
        _fmt_val(_nl_get(nl_refs.aa_bodyyaw_opts, "?")), _b(_nl_get(nl_refs.aa_freestand, false))))
    add(string.format("[AIPEEK] enabled=%s active=%s phase=%s anchor=%s side=%s peeks=%d shots=%d exposure-timeouts=%d dist=%d delay=%d expose=%dms retreat=%s dt_wait=%s tele=%s hc=%d",
        _b(AIP.enable:get()), _b(AIP.active:get()), tostring(ai_peek.phase), ai_peek.anchor and "set" or "none",
        ai_peek.side == nil and "-" or (ai_peek.side == 0 and "L" or "R"), ai_peek.peeks or 0, ai_peek.shots or 0,
        ai_peek.timeouts or 0, AIP.dist:get(), AIP.delay:get(), AIP.expose:get(), tostring(AIP.retreat:get()),
        _b(AIP.dt_wait:get()), _b(AIP.dt_tele:get()), AIP.hc:get()))
    -- attackers, most hits first
    local names = {}
    for name in pairs(attackers) do names[#names + 1] = name end
    table.sort(names, function(a, b) return attackers[a].hits > attackers[b].hits end)
    add(string.format("[ATTACKERS] %d players hit you", #names))
    for _, name in ipairs(names) do
        local A = attackers[name]
        local st, wp = {}, {}
        for k, v in pairs(A.states) do st[#st + 1] = k .. "×" .. v end
        for k, v in pairs(A.wpn) do wp[#wp + 1] = k .. "×" .. v end
        table.sort(st); table.sort(wp)
        add(string.format("  %-22s hits=%d head=%d dmg=%d last %.0fs ago | states: %s | weapons: %s",
            name, A.hits, A.head, A.dmg, now - (A.last or now), table.concat(st, " "), table.concat(wp, " ")))
    end
    add(string.format("[HITS TAKEN] last %d (newest first) — snapshot = engine state at the moment of the hit", #hits_taken_log))
    for i = #hits_taken_log, 1, -1 do
        local e = hits_taken_log[i]
        local s = e.snapshot or {}
        add(string.format("  [%.1fs ago] %s → %s for %d (%s) hp_left=%d%s",
            now - e.time, e.atk_name or "?", e.hitbox or "?", e.dmg or 0, tostring(e.weapon or "?"), e.hp_left or 0,
            s.atk_is_threat and " [was the tracked threat]" or ""))
        for _, line in ipairs(aa_fmt_snapshot(s, "      ")) do add(line) end
    end
    add(string.format("[TIMELINE] last %d events (newest first)", math.min(#aa_tl, 100)))
    local lo = math.max(1, #aa_tl - 99)
    for i = #aa_tl, lo, -1 do
        local ev = aa_tl[i]
        add(string.format("  [%7.1fs] %-10s %s", now - ev.t, ev.kind, ev.text))
    end
    add("[HINTS]")
    for _, h in ipairs(aa_hints()) do add("  • " .. h) end
    add("════ END DUMP ════")

    local full = table.concat(L, "\n")
    for _, l in ipairs(L) do cs_log(l) end
    pcall(function()
        files.create_folder("nl/Sel01-Config/")
        files.write("nl/Sel01-Config/last_logs.txt", full)
    end)
    local clip_ok, clip_err = set_clipboard(full)
    if clip_ok then
        cs_log_color(string.format("✓ Copied to CLIPBOARD (%d bytes, %d lines) — Ctrl+V anywhere. Also saved → nl/Sel01-Config/last_logs.txt", #full, #L))
    else
        cs_log_color("⚠ Clipboard FFI failed (" .. tostring(clip_err) .. ") — file fallback: nl/Sel01-Config/last_logs.txt")
    end
end
pcall(function() btn_copy:set_callback(function() pcall(config_copy_logs) end) end)

-- ══════════════════════════════════════════════════════════════════════════
-- v5.0 CONFIG SYSTEM — the meta luas' preset managers (nexus / Andromeda / spectral /
-- DEMONTIME / evalate) boiled down to what this build verifiably supports: 8 fixed slots
-- (combos cannot change items at runtime; slot labels are rewritten via :name()), values
-- read with :get() from every element the script owns, written back with :set() from the
-- createmove drain (menu-callback rule), persisted in the NL `db` table (file fallback),
-- shared as `sel01cfg:<base64>` text over the clipboard. Own base64 + line encoder — no
-- json / base64 lib dependency.
-- ══════════════════════════════════════════════════════════════════════════
pending_cfg = nil   -- global: button callbacks below + the createmove drain
do -- (do-block: the helpers below are locals of this block, not of the main chunk)
CFG.items = {}
CFG.SKIP = { ["aa.key_l"] = true, ["aa.key_r"] = true, ["aa.key_f"] = true, ["aa.key_b"] = true,
             ["aa.def_key"] = true, ["aa.fs_key"] = true, ["aip.active"] = true, ["mv.peek_boost"] = true,
             ["aa.state_sel"] = true }
local function cfg_is_el(v)
    local ok, r = pcall(function() return v ~= nil and type(v) ~= "table" and type(v) ~= "string" and type(v) ~= "number"
        and type(v) ~= "boolean" and type(v) ~= "function" and v.get ~= nil and v.set ~= nil end)
    return ok and r == true
end
local function cfg_reg(key, el)
    if CFG.SKIP[key] then return end
    if cfg_is_el(el) then CFG.items[#CFG.items + 1] = { key, el } end
end
function cfg_build_registry()
    CFG.items = {}
    for k, v in pairs(AA) do cfg_reg("aa." .. k, v) end
    for sk, S in pairs(AA.st) do for k, v in pairs(S) do cfg_reg("st." .. sk .. "." .. k, v) end end
    for i, el in ipairs(AA.def_seq) do cfg_reg("aa.def_seq" .. i, el) end
    for k, v in pairs(AIP) do cfg_reg("aip." .. k, v) end
    for k, v in pairs(MISC) do cfg_reg("misc." .. k, v) end
    for k, v in pairs(VIS) do cfg_reg("vis." .. k, v) end
    local extra = {
        ["v.watermark"] = vis_watermark, ["v.indicators"] = vis_indicators, ["v.velwarn"] = vis_velwarn,
        ["v.aaarrows"] = vis_aaarrows, ["v.hitmarker"] = vis_hitmarker, ["v.hitlog"] = vis_hitlog,
        ["v.keybinds"] = vis_keybinds, ["v.dmgind"] = vis_dmgind, ["v.specoverlay"] = vis_specoverlay,
        ["v.desyncpct"] = vis_desyncpct, ["v.skeet"] = vis_skeet, ["v.netgraph"] = vis_netgraph,
        ["v.scopefade"] = vis_scopefade, ["v.sleeves"] = vis_sleeves, ["v.menublur"] = vis_menublur,
        ["v.custscope"] = vis_custscope, ["v.scope_rot"] = vis_scope_rot, ["v.menuborder"] = vis_menuborder,
        ["qol.clantag"] = qol_clantag, ["qol.clantag_st"] = qol_clantag_st, ["mv.peek_hc"] = mv_peek_hc,
    }
    for k, v in pairs(extra) do cfg_reg(k, v) end
    table.sort(CFG.items, function(a, b) return a[1] < b[1] end)
end
-- own base64 (RFC 4648) — the lua may run on a build without neverlose/base64
local CFG_B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function cfg_b64enc(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64; local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64;     local c4 = n % 64
        out[#out + 1] = CFG_B64:sub(c1 + 1, c1 + 1) .. CFG_B64:sub(c2 + 1, c2 + 1)
            .. (b and CFG_B64:sub(c3 + 1, c3 + 1) or "=") .. (c and CFG_B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end
local function cfg_b64dec(s)
    s = tostring(s or ""):gsub("[^%w%+/=]", "")
    local out, map = {}, {}
    for i = 1, 64 do map[CFG_B64:sub(i, i)] = i - 1 end
    for i = 1, #s, 4 do
        local q = { s:byte(i, i + 3) }
        local v, pad = 0, 0
        for j = 1, 4 do
            local ch = q[j] and string.char(q[j]) or "="
            if ch == "=" then pad = pad + 1; v = v * 64 else v = v * 64 + (map[ch] or 0) end
        end
        local b1 = math.floor(v / 65536) % 256; local b2 = math.floor(v / 256) % 256; local b3 = v % 256
        out[#out + 1] = string.char(b1)
        if pad < 2 then out[#out + 1] = string.char(b2) end
        if pad < 1 then out[#out + 1] = string.char(b3) end
    end
    return table.concat(out)
end
function cfg_snapshot()
    local t = {}
    for _, it in ipairs(CFG.items) do
        local ok, v = pcall(function() return it[2]:get() end)
        if ok and (type(v) == "boolean" or type(v) == "number" or type(v) == "string") then t[it[1]] = v end
    end
    return t
end
local function cfg_encode(t)
    local L = {}
    for k, v in pairs(t) do
        local tv = type(v)
        local sv = tostring(v):gsub("\\", "\\\\"):gsub("\n", "\\n")
        L[#L + 1] = k .. "=" .. tv:sub(1, 1) .. ":" .. sv
    end
    table.sort(L)
    return table.concat(L, "\n")
end
local function cfg_decode(s)
    local t, n = {}, 0
    for line in tostring(s or ""):gmatch("[^\n]+") do
        local k, tv, sv = line:match("^([^=]+)=(%a):(.*)$")
        if k then
            sv = sv:gsub("\\n", "\n"):gsub("\\\\", "\\")
            if tv == "b" then t[k] = (sv == "true")
            elseif tv == "n" then t[k] = tonumber(sv)
            else t[k] = sv end
            n = n + 1
        end
    end
    return t, n
end
function cfg_apply(t)
    local n = 0
    for _, it in ipairs(CFG.items) do
        local v = t[it[1]]
        if v ~= nil then
            local ok, cur = pcall(function() return it[2]:get() end)
            if ok and type(cur) == type(v) then safe_set(it[2], v); n = n + 1 end
        end
    end
    return n
end
-- persistence: NL db table when present, else nl/Sel01-Config/configs.txt
CFG.store = nil
local function cfg_store_load()
    if CFG.store then return CFG.store end
    local st = nil
    pcall(function() if type(db) == "table" and type(db["sel01_config_v5"]) == "table" then st = db["sel01_config_v5"] end end)
    -- no file READ here: files.read on a missing path raises an unsuppressable popup and
    -- there is no exists-check. The db table is the store (every meta lua uses it); the
    -- configs.txt written on save is a human-readable backup you can Import by hand.
    if not st then st = { slots = {} } end
    st.slots = st.slots or {}
    CFG.store = st
    return st
end
local function cfg_store_save()
    local st = CFG.store or cfg_store_load()
    local in_db = false
    pcall(function() if type(db) == "table" then db["sel01_config_v5"] = st; in_db = true end end)
    pcall(function()
        local L = {}
        for i = 1, CFG.SLOTS do
            local s = st.slots["s" .. i]
            if s and s.data then L[#L + 1] = i .. "\t" .. tostring(s.name or "") .. "\t" .. cfg_b64enc(s.data) end
        end
        files.create_folder("nl/Sel01-Config/")
        files.write("nl/Sel01-Config/configs.txt", table.concat(L, "\n"))
    end)
    return in_db
end
-- selected slot = the list's 1-based index (DEMONTIME indexes its name array with it)
local function cfg_sel_slot()
    local v = nil
    pcall(function() v = CFG.list:get() end)
    if type(v) == "number" then
        if v == 0 then v = 1 end
        return math.max(1, math.min(CFG.SLOTS, math.floor(v)))
    elseif type(v) == "string" then
        return tonumber(v:match("^%s*(%d+)")) or 1
    end
    return 1
end
local function cfg_refresh_labels()
    local st = cfg_store_load()
    local names = {}
    for i = 1, CFG.SLOTS do
        local s = st.slots["s" .. i]
        names[i] = s and s.data and (i .. "   " .. tostring(s.name or "?") .. "   (" .. tostring(s.n or "?") .. ")") or (i .. "   (empty)")
    end
    pcall(function() CFG.list:update(names) end)
end
local function cfg_status(text)
    pcall(function() CFG.status:name(text) end)
    cs_log_color("[config] " .. tostring(text):gsub("\a%x%x%x%x%x%x%x%x", ""):gsub("\a%b{}", ""))
end
function cfg_drain(p)
    if #CFG.items == 0 then cfg_build_registry() end
    local st = cfg_store_load()
    local slot = cfg_sel_slot()
    local name = "config"
    pcall(function() if CFG.name then name = tostring(CFG.name:get() or "config") end end)
    if name == "" then name = "config " .. slot end
    if p.op == "save" then
        local snap = cfg_snapshot()
        local n = 0
        for _ in pairs(snap) do n = n + 1 end
        st.slots["s" .. slot] = { name = name, data = cfg_encode(snap), n = n }
        local in_db = cfg_store_save()
        cfg_status(string.format("\a55DD55FFsaved slot %d '%s' (%d values, %s)", slot, name, n, in_db and "db + file" or "file"))
        aa_tl_push("CONFIG", "saved slot " .. slot .. " " .. name)
    elseif p.op == "load" then
        local s = st.slots["s" .. slot]
        if not (s and s.data) then cfg_status("\aFF5555FFslot " .. slot .. " is empty"); return end
        local t, n = cfg_decode(s.data)
        local applied = cfg_apply(t)
        pcall(aa_state_vis); pcall(aa_def_vis)
        cfg_status(string.format("\a55DD55FFloaded slot %d '%s' (%d / %d values applied)", slot, tostring(s.name), applied, n))
        aa_tl_push("CONFIG", "loaded slot " .. slot .. " " .. tostring(s.name))
    elseif p.op == "delete" then
        st.slots["s" .. slot] = nil
        cfg_store_save()
        cfg_status("\aFFAA55FFslot " .. slot .. " deleted")
    elseif p.op == "export" then
        local s = st.slots["s" .. slot]
        local data, nm = nil, name
        if s and s.data then data, nm = s.data, s.name else
            local snap = cfg_snapshot(); data = cfg_encode(snap)   -- empty slot: export the live values
        end
        local text = "sel01cfg:" .. cfg_b64enc(tostring(nm) .. "\n" .. data)
        local ok = false
        pcall(function() local cb = require("neverlose/clipboard"); if cb and cb.set then cb.set(text); ok = true end end)
        if not ok then ok = set_clipboard(text) end
        cfg_status(ok and string.format("\a55DD55FFexported '%s' to the clipboard (%d chars) - paste it anywhere", tostring(nm), #text)
                      or "\aFF5555FFclipboard write failed")
    elseif p.op == "select" then
        local s = st.slots["s" .. slot]
        pcall(function() if s and CFG.name then CFG.name:set(tostring(s.name or "")) end end)
    elseif p.op == "import" then
        local text = nil
        pcall(function() local cb = require("neverlose/clipboard"); if cb and cb.get then text = cb.get() end end)
        if not text then cfg_status("\aFF5555FFclipboard read not available on this build (neverlose/clipboard)"); return end
        local b64 = tostring(text):match("sel01cfg:([%w%+/=]+)")
        if not b64 then cfg_status("\aFF5555FFno sel01cfg: string on the clipboard"); return end
        local raw = cfg_b64dec(b64)
        local nm, data = raw:match("^([^\n]*)\n(.*)$")
        if not data then cfg_status("\aFF5555FFcorrupt config string"); return end
        local t, n = cfg_decode(data)
        if n == 0 then cfg_status("\aFF5555FFconfig string holds no values"); return end
        st.slots["s" .. slot] = { name = nm ~= "" and nm or name, data = data, n = n }
        cfg_store_save()
        pcall(function() if CFG.name then CFG.name:set(st.slots["s" .. slot].name) end end)
        cfg_status(string.format("\a55DD55FFimported '%s' into slot %d (%d values) - press Load slot to apply", tostring(st.slots["s" .. slot].name), slot, n))
    end
    cfg_refresh_labels()
end
pcall(function()
    CFG.b_save:set_callback(function() pending_cfg = { op = "save" } end)
    CFG.b_load:set_callback(function() pending_cfg = { op = "load" } end)
    CFG.b_del:set_callback(function()  pending_cfg = { op = "delete" } end)
    CFG.b_exp:set_callback(function()  pending_cfg = { op = "export" } end)
    CFG.b_imp:set_callback(function()  pending_cfg = { op = "import" } end)
    -- list callback only queues (v1.5 rule: no :set / :name work inside menu callbacks)
    CFG.list:set_callback(function() pending_cfg = { op = "select" } end)
end)
pcall(cfg_build_registry)
pcall(cfg_refresh_labels)
end -- config do-block

-- V3.1: Anti-HS Bundle = enable pitch_jitter + move_fakeduck + reasonable threshold
pcall(function() btn_antihs:set_callback(function()
    local on = not (AA.pitch_jitter:get() and AA.move_fd:get())
    safe_set(AA.pitch_jitter, on)
    safe_set(AA.move_fd,      on)
    safe_set(AA.move_fd_thr,  100)
    cs_log_color("Anti-HS Bundle " .. (on and "ENABLED" or "DISABLED")
        .. " (pitch jitter + move-fakeduck @100u/s)")
end) end)

-- ══════════════════════════════════════════════════════════════════════════
-- SHUTDOWN
-- ══════════════════════════════════════════════════════════════════════════
-- Clear all NL :override() writes so user's manual UI returns to its real state.
-- v5.0 unload crash fix: the old cleanup called :override() on EVERY nl_refs entry (~55,
-- incl. hotkey-bound elements like Double Tap / Hide Shots / Peek Assist / Slow Walk that
-- the script never writes) plus every cvar restore in one shutdown frame → CSGO crashed on
-- unload. Now: only the refs this script actually overrides, and only the ones that carry
-- a live override (get_override ~= nil), each in its own pcall; hidden angles only when we
-- set them; cvars only when we changed them; clantag only when we drove it.
local SEL01_OVERRIDE_KEYS = {}
for _, k in ipairs(AA_REF_KEYS) do SEL01_OVERRIDE_KEYS[#SEL01_OVERRIDE_KEYS + 1] = k end
for _, k in ipairs({ "rage_hc", "rage_safepoint", "misc_airstrafe", "rage_as_ssg_opts", "rage_as_opts", "rage_hide", "vis_scope_ovl" }) do
    SEL01_OVERRIDE_KEYS[#SEL01_OVERRIDE_KEYS + 1] = k
end
local function nl_clear_if_overridden(ref)
    if not ref then return false end
    local has = true
    pcall(function() if ref.get_override then has = (ref:get_override() ~= nil) end end)
    if not has then return false end
    pcall(function() ref:override() end)
    return true
end
local function clear_all_nl_overrides(reason)
    local n = 0
    for _, k in ipairs(SEL01_OVERRIDE_KEYS) do
        if nl_clear_if_overridden(nl_refs[k]) then n = n + 1 end
    end
    if aa_eng.hidden_active then
        pcall(function() rage.antiaim:override_hidden_yaw_offset(0) end)
        pcall(function() rage.antiaim:override_hidden_pitch(0) end)
    end
    aa_eng.active = false
    aa_eng.fl_active, aa_eng.dtlag_active, aa_eng.hidden_active, aa_eng.fd_active = false, false, false, false
    aa_eng.fs_static_active, aa_eng.hs_active, aa_eng.fl_dis_active, aa_eng.air_fd_active, aa_eng.air_fl_active = false, false, false, false, false
    _peek_boost_active = false
    ai_peek.hc_active, ai_peek.sp_active = false, false
    misc_eng.hs_ov, misc_eng.airstrafe_ov, misc_eng.autostop_ov, misc_eng.legs_ov = false, false, false, false
    -- cvars: misc_cvars_sync(true) only touches cvars whose original it saved
    pcall(misc_cvars_sync, true)
    return n
end

local _shutdown_done = false
pcall(function()
    events.shutdown:set(function()
        if _shutdown_done then return end
        _shutdown_done = true
        pcall(function()
            local n = clear_all_nl_overrides("unload")
            if clantag_last_sent then pcall(function() common.set_clan_tag("") end) end
            pcall(function() print(CS_PREFIX .. " v" .. SEL01_CFG_VERSION .. " unloaded (" .. n .. " overrides cleared)") end)
        end)
    end)
end)

-- Also clear on master-disable
enable_master:set_callback(function(r)
    if not r:get() then
        pcall(function()
            local n = clear_all_nl_overrides("master off")
            if clantag_last_sent then pcall(function() common.set_clan_tag("") end) end
            cs_log_color("Master DISABLED — " .. n .. " overrides + clantag cleared")
        end)
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
    -- v3.31: bigger text, and the banner waits ~4s so it appears AFTER the Solver's
    -- fullscreen intro (the scripts load together). Sequence: intro -> "checking
    -- version..." -> verdict, instead of everything stacked at once.
    cfg_vc_font = nil
    pcall(function() cfg_vc_font = render.load_font("Verdana", 26, "b") end)
    cfg_vc_scr  = { text = "checking version...", r = 190, g = 190, b = 190, hold = nil }
    cfg_vc_gate = (globals.realtime or 0) + 4.0
    function cfg_vc_draw()
        local st = cfg_vc_scr
        if not st then return end
        local now = globals.realtime or 0
        if now < cfg_vc_gate then return end
        local shown = now - cfg_vc_gate
        local drawing = st
        if st.hold and shown < 1.2 then
            drawing = { text = "checking version...", r = 190, g = 190, b = 190 }
        elseif st.hold then
            if not st.t_until then st.t_until = now + st.hold end
            if now >= st.t_until then cfg_vc_scr = nil; return end
        elseif shown > 14 then
            cfg_vc_scr = nil; return
        end
        local a = 255
        if drawing.t_until then
            local left = drawing.t_until - now
            if left < 1.0 then a = math.floor(255 * left) end
        end
        pcall(function()
            local ss = render.screen_size()
            local y  = ss.y * 0.71
            local col = color(drawing.r, drawing.g, drawing.b, a)
            local f, w = cfg_vc_font, nil
            if f then pcall(function() w = render.measure_text(f, nil, drawing.text) end) end
            if f and w then
                render.text(f, vector(ss.x / 2 - w.x / 2, y), col, nil, drawing.text)
            else
                render.text(5, vector(ss.x / 2, y), col, "c", drawing.text)
            end
        end)
    end
    function cfg_vc_screen(text, r, g, b, secs)   -- global: main chunk is at the 200-local cap
        cfg_vc_scr = { text = text, r = r, g = g, b = b, hold = secs }
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
cs_log_color("Sel01-Config v" .. SEL01_CFG_VERSION .. " loaded (v5.0 META rework: decoded presets, choke tables, safe head, legit AA, Misc tab)")
cs_log(string.format("  hooks  createmove=%s  createmove_run=%s  aim_fire=%s  bullet_impact=%s  anim=%s",
    tostring(_hooks_status.createmove or "MISSING"),
    tostring(_hooks_status.createmove_run or "MISSING"),
    tostring(_hooks_status.aim_fire or "MISSING"),
    tostring(_hooks_status.bullet_impact or "MISSING"),
    tostring(_hooks_status.anim or "MISSING")))
cs_log_color("  AA via NL :override path (no cmd angle writes). Presets → Main (Nyanza = defaults). Copy Last Logs → Info.")
cs_log_color("══════════════════════════════════════════")
