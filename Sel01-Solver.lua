-- ╔══════════════════════════════════════════════════╗
-- ║  Sel01-Solver — Neverlose CS2 Custom Resolver    ║
-- ║  Author: seltonmt01                              ║
-- ║  Version: 9.63                                   ║
-- ╚══════════════════════════════════════════════════╝
-- @name Sel01-Solver
-- @author seltonmt01
-- @version 9.81
-- @description v9.79 BF real-dominance ordering broadened to switch AA:
--   * v9.78 only reordered the static/slow BF branch. This lobby's one-sided
--     locks were aa=switch (idx=8 real 10R/0L still fired BF:opposite LEFT;
--     idx=12 9R/0L fired BF:opposite LEFT) — switch fell through to the
--     opposite-first default. A >=3-vs-0 REAL split is a confirmed lock
--     regardless of AA-class, so the dominant-side magnitude sweep now applies
--     to ALL non-defensive aa_types. Genuine alternators (real hits both sides,
--     idx=6 L=2 R=1) stay opposite-first (V9.63).
-- @description-prev v9.78 BF cycle real-dominance ordering (static/slow only):
--     real_left/right firmly one-sided → sweep magnitude on proven side first.
-- @description-prev2 v9.77 Networked-Boost side-conflict guard + server-fail filter honesty:
--   * Networked-Boost (ground 4090 + air 4513) trusted RebuildServerYaw's SIDE
--     blindly while boosting the magnitude. RebuildServerYaw undershoots magnitude
--     but can also give the WRONG side; on a hard one-sided enemy it boosted onto
--     the wrong side (real-dump idx=5: streak L=20 R=0, real 5L/0R, rebuild said
--     R → boosted 29° R twice → Networked-Boost 0/2). New learned_dom_side(s) (real
--     hits / streak only, no seeded/passive) overrides the rebuild side when learned
--     dominance strongly contradicts it, and uses that side's per-side magnitude.
--   * server-fail filter (ack_serverfail_like) excused a bt=0 err=0 kept-side miss
--     as "netcode" — but bt=0 = server used the CURRENT record, no stale replay, so
--     a correct-magnitude miss there is OUR own side/switch misprediction (the v9.55
--     note already said so; the code never enforced it). The err<=5 branch now needs
--     bt>=4 (genuine backtrack); bt 0-3 correct-angle misses COUNT (real-dump idx=5
--     had ~14 bt=0/2 keeps filtered → headline 86.7% vs raw 59.1%, a 27pt lie).
-- @description-prev v9.76 AA-classify oscillation-freeze (slow-flap fix):
--   * the V9.10 anti-flap counted commits in a 10s window — a slow static<->switch<->static
--     revert spread over >10s never hit 4 entries and flapped freely (real-dump idx=3/7/11
--     at long range on yaw noise; idx=7 mode-thrashed switch->static->switch into a miss
--     right after a hit). Now an A->B->A revert (commit back to a just-left type) freezes
--     the classifier 5s regardless of timing; a real progression never reverts so genuine
--     AA changes are untouched.
-- @description-prev v9.75 AIR magnitude boost (port of ground Networked-Boost, hits 4/4=100%):
--   * resolve_player air-branch boosts an undershot RebuildServerYaw magnitude to the
--     known measured/passive air magnitude (keeps the rebuilt side) in the trust-rebuild
--     fall-through. RebuildServerYaw gives a good SIDE but undershoots magnitude in air —
--     a never-hit-but-passively-known air enemy got the raw short angle and missed
--     (real-dump idx=9: passive/measured 33.9°, rebuild +15° R, 18.9° short → miss → hit).
-- @description-prev v9.74 jitter+defAA BF fix + passive-side dump visibility + air/BF:retry guard:
--   * Issue 1 pick_bruteforce_angle skips the def_delta (BF:def+) cycle when
--     aa_type=="jitter" — jitter oscillation has no stable defensive delta, so
--     BF:def+ whiffed (v9.73 idx=3 0/1) while BF:opposite catches it. Falls through
--     to the standard BF oscillation. aim_ack logs the jitter+defAA+no-samples case.
--   * Issue 2 copy-dump [P] lines show passive_n_left/right as pL=/pR= so the
--     V9.72 passive-side-keep can be verified from a dump.
--   * Issue 3 resolve_player air-branch yields to a pending BF:retry (consumed only
--     in pick_bruteforce_angle) — v9.73 idx=14 KEEP scheduled but logged mode=Air.
--   * Issue 4 IMPROVEMENT HINTS: jitter+defAA hint + 0-real/passive-obs hint.
-- @description-prev v9.73 real-dump fixes (idx=4 switch-stuck / idx=2 BF jitter / cold Air):
--   * FIX #1 one-sided switch enemy: correct magnitude (err<2) + 2 consecutive
--     correct-angle KEEPs on same side = the switch moved → force a flip (was 6+ KEEP).
--   * FIX #2 BF:retry cap — static enemy, 2 correct-angle keeps + samples → commit
--     measured desync (Static-Meas) instead of jittering the magnitude.
--   * FIX #3 cold-air gate — no hit-EMA + no passive baseline → alternate side by
--     miss-count (BF:opposite) at a high air prior, don't fire a blind trusted Air.
--   * FIX #4 conf<15 → skip speculative correction; let BF cycle sweep sides.
--   * FIX #5 don't clobber session-learned per-side EMAs from persistent LearnedModel
--     on dormancy re-track (kept mid-session learning momentum).
--   * FIX #6 tag correct-angle server-fail keeps so Static-Meas mode-confidence isn't
--     decayed (mode_stats already gated; flag makes it explicit + ESP-visible).
-- @description-prev Correction side guard + serverfail retry:
--   * correction/prediction-error misses now check SIDE evidence, not only
--     magnitude. A BF shot on the unlearned opposite side no longer gets labeled
--     "server fail" just because abs(delta) ~= measured_desync.
--   * correct-angle server/backtrack fails schedule one same-side retry before
--     normal BF cycling, so a good +45 shot does not immediately become
--     BF:opposite on the next attempt.
--   * BF magnitude now trusts strong passive desync data (8+ observations), which
--     fixes pass-heavy players getting forced back to max_desync.
-- @description-prev Air first-contact fix (Air was the worst mode @25%):
--   * Air-Guess magnitude now biased HIGH (max(adaptive_median, 42)) — airborne
--     enemies can't move-desync so they sit near max desync; the lobby median was
--     undershooting (guessed ~18-30 on 42-58° air enemies).
--   * first-contact air SIDE now uses steam-memory dominant side instead of a blind
--     +1 coin-flip.
-- @description-prev Snapshot-match regression fix (v9.33 self-inflicted):
--   * aim_ack snapshot picker now matches event.tick (the acked shot) again, not
--     globals.tickcount (ack-time). v9.33 broke this: on rapid fire the ack for shot
--     A grabbed shot B's snapshot → wrong eye/resolved → WRONG hit_side learned →
--     corrupted per-side desync. Kept the v9.33 >64 stale-reject + push-prune.
-- @description-prev Fast-fire tightened (stop shooting too early):
--   * fast-fire used to drop hitchance to 30 on conf>=50 — firing a marginal shot
--     that, on high-desync enemies, caught a bad backtrack record → correction /
--     prediction-error rejects ("shoots too early, misses a lot"). Now it only fires
--     fast on a STABLE (stddev<12) + well-sampled resolve (conf85/s3→hc30,
--     conf70/s2→hc45), hc floors raised toward NL's manual 72 (v9.18-aligned).
-- @description-prev Air-branch hardening (air resolver focus):
--   * air corr-aware path now uses PER-SIDE measured magnitude (was global
--     measured_desync — wrong for bimodal/per-side enemies; v9.22-class fix for air).
--   * update_jitter now runs in the air-branch (used to return before it) → yaw_cache
--     / yaw_rate stay warm, so aa_type is correct on landing and air-spin is visible.
-- @description-prev Batch 3 — air recent_resolved, snapshot window, boot nil-guard, pose-read:
--   * air-branch now pushes recent_resolved so cancel-conf/confidence reflect air.
--   * snapshot matched on tickcount + rejected if >64 ticks stale (+ prune at push)
--     so a cross-engagement snapshot can't teach the wrong side.
--   * LearnedModel boot nil-coalesces fields (partial learned.lua no longer aborts).
--   * adaptive_guess ring capped at 58 so >58 reads can't bias the median high.
--   * [EXP, OFF] pose-param side read (m_flPoseParameter[11]) — A/B tiebreaker in
--     Air-Guess; mapping undocumented, validate in-game before trusting.
-- @description-prev Bimodal resolver + enriched event ticker + RebuildServerYaw nil:
--   * V9.32 bimodal: detect true switch-AA (two stable per-side magnitudes >12°
--     apart) and suppress the v9.30 GLOBAL hard-reset so it stops thrashing the
--     averaged EMA on every alternation (per-side EMAs already hit these).
--   * V9.32 event ticker HIT/MISS lines now show Δdelta / measured / conf / side
--     and bt (backtrack tick) on misses — high bt = stale-record/netcode miss.
--   * V9.32 RebuildServerYaw returns nil on failure (callers `or eye_yaw`) so a
--     failed reconstruct no longer resolves to a literal 0°.
-- @description-prev Server-side-fail flip guard + locked-target head preference:
--   * V9.31 correction-flip fix: a `correction` miss where our resolved delta
--     == measured_desync means the SIDE was right and the server rejected the
--     shot (fake-lag/backtrack). Old code flipped side anyway → oscillation +
--     fed BF:opposite the wrong side. Now flip only when angle_err > 5°; a
--     correct-angle reject KEEPS the side (generalizes the V9.24 LBY guard).
--   * V9.31 body-only fix: on LOCKED targets (8+ samples, 60+ conf, not whiffing)
--     relax NL safe-point + enable multipoint so the ragebot takes HEAD instead
--     of the safe body point. Toggle, never touches mindmg/hitbox.
-- @description-prev AA-switch detection + hard-reset on big changes:
--   * On every hit, if |actual - stored_EMA| > 10° AND we already have >=3
--     samples, treat as the enemy SWITCHING their AA preset (not drift).
--   * Replace EMA with the new actual value directly (no smoothing).
--   * Decimate sample count to 40% so confidence drops temporarily and the
--     resolver re-confirms over the next 2 hits instead of dragging on the
--     old EMA for 4-5 misses.
--   * Applied to global measured_desync AND per-side EMAs independently.
--   * v9.26 drift-bump (alpha 0.55 on 5-10° diff) still handles small shifts.
--   * v9.29 coach variants carry.

local SEL01_VERSION = "9.81"

local pui = require("neverlose/pui");
local ffi = require("ffi");
local gradient = require( 'neverlose/gradient' )

local CS_PREFIX = "[Sel01-Solver]"
local function cs_log(msg)
    pcall(print, CS_PREFIX .. " " .. tostring(msg))
end
local function cs_log_color(msg)
    local ok = pcall(function() client.color_log(150, 200, 255, CS_PREFIX .. " " .. tostring(msg)) end)
    if not ok then cs_log(msg) end
end
-- raw refs always available (used by UI buttons created BEFORE logging-gates are wired)
local _cs_log_raw       = cs_log
local _cs_log_color_raw = cs_log_color
local x, y, ref = render.screen_size().x, render.screen_size().y, ui.find("Aimbot", "Ragebot", "Selection", "Min. Damage")

-- V8.7: FFI clipboard set — write text to Windows clipboard for direct paste
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
    if cdef_ok and ok_k and ok_u then
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
                u32.SetClipboardData(13, h)
                u32.CloseClipboard()
            end)
            return ok, err
        end
    else
        set_clipboard = function() return false, "ffi unavailable" end
    end
end

local loading_config = {
    image_url = "https://i.imgur.com/iEDB6Ef.png",
    image_path = "nl/Sel01-Solver/logo.png",
    image_size = vector(300, 300),
    duration = 3.5,
    text = "\aFFFFFFFFsel01-solver \aFF6B9DFFby seltonmt01",
    text_offset_x = -22,
    overlay_alpha = 0.8
};

local loading_effect = {
    start_time = globals.realtime,
    duration = loading_config.duration,
    alpha = 0,
    image = nil,
    image_loaded = false
};

do
    pcall(ffi.cdef, [[
        void* __stdcall URLDownloadToFileA(void* LPUNKNOWN, const char* LPCSTR, const char* LPCSTR2, int a, int LPBINDSTATUSCALLBACK);
        bool DeleteUrlCacheEntryA(const char* lpszUrlName);
    ]]);
    local urlmon = ffi.load("UrlMon");
    local wininet = ffi.load("WinInet");
    local function download_file(url, path)
        wininet.DeleteUrlCacheEntryA(url);
        urlmon.URLDownloadToFileA(nil, url, path, 0, 0);
    end;
    pcall(function()
        files.create_folder("nl/Sel01-Solver/");
        if not files.read(loading_config.image_path) then
            download_file(loading_config.image_url, loading_config.image_path);
        end;
        local status, img = pcall(function() return render.load_image_from_file(loading_config.image_path, loading_config.image_size) end);
        if status and img then
            loading_effect.image = img;
            loading_effect.image_loaded = true;
        end;
    end);
end;

local function utility_lerp(a, b, t)
    return a + (b - a) * t;
end;

local sidebar_anim = gradient.text_animate('sel01 ~ beta', 1.5, {color(255, 255, 255), color(1, 2, 4)})
local function sidebar()
    ui.sidebar(sidebar_anim:get_animated_text(), 'sparkles')
    sidebar_anim:animate()
end

local loading_render_callback = function()
    if loading_effect then
        local elapsed = globals.realtime - loading_effect.start_time;
        if elapsed < loading_effect.duration then
            local screen = render.screen_size();
            local progress = elapsed / loading_effect.duration;
            if progress < 0.25 then
                loading_effect.alpha = utility_lerp(loading_effect.alpha, 255, 12 * globals.frametime);
            elseif progress > 0.75 then
                loading_effect.alpha = utility_lerp(loading_effect.alpha, 0, 12 * globals.frametime);
            else
                loading_effect.alpha = 255;
            end;
            if loading_effect.alpha > 1 then
                render.rect(vector(0, 0), screen, color(0, 0, 0, loading_effect.alpha * loading_config.overlay_alpha), 0, true);
                local center_y = screen.y / 2;
                if loading_effect.image and loading_effect.image_loaded then
                    local img_pos = vector(screen.x / 2 - loading_config.image_size.x / 2, center_y - loading_config.image_size.y / 2 - 50);
                    render.texture(loading_effect.image, img_pos, loading_config.image_size, color(255, 255, 255, loading_effect.alpha));
                    render.text(4, vector(screen.x / 2 + loading_config.text_offset_x, center_y + loading_config.image_size.y / 2 + 30), color(255, 255, 255, loading_effect.alpha), "c", loading_config.text);
                else
                    render.text(4, vector(screen.x / 2, center_y - 20), color(255, 255, 255, loading_effect.alpha), "c", "\aFFFFFFFFSEL01-SOLVER");
                    render.text(4, vector(screen.x / 2, center_y + 20), color(255, 255, 255, loading_effect.alpha), "c", "\aFFFFFFFFby \aFF6B9DFFseltonmt01");
                end;
            end;
        else
            loading_effect = nil;
            -- (no events.render swap — main wrapper handles loading+sidebar+ESP each frame)
        end;
    end;
end;

events.render:set(function() 
    loading_render_callback();
    sidebar();
end)
pui.sidebar("boost ~ beta",ui.get_icon"sparkles")
local accent = "\a{Link Active}"

-- ╔══════════════════════════════════════╗
-- ║  EARLY FORWARD-DECLS (V7.3 fix)      ║
-- ║  All locals used in UI-callback closures MUST be   ║
-- ║  declared HERE (before UI creation)                 ║
-- ╚══════════════════════════════════════╝
local SteamMemory  = {}
local LearnedModel = {}
local mode_stats   = {}
local PlayerState  = setmetatable({}, {__index = function() return nil end})
local tick_cache   = { tick = -1, curtime = 0, frametime = 0, tickint = 1/64, lp = nil, lp_yaw = 0, lp_ox = 0, lp_oy = 0, lp_oz = 0, valid = false, ping_ms = 0, wc = nil, lp_ducking = false }
local NormalizeAngle
NormalizeAngle = function(angle)
    if angle == nil then return 0 end
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end
local mode_stats_update, mode_stats_dump, confidence
local get_steam_mem, steam_mem_on_hit, steam_mem_on_miss
local learning_cleanup
local record_player_shot
record_player_shot = function(s, hit)
    if not s then return end
    -- V8.7: skip Init mode shots (eye=0 resolved=0 = false data)
    if s.mode == "Init" then return end
    table.insert(s.p_history, hit and true or false)
    while #s.p_history > 10 do table.remove(s.p_history, 1) end
    if hit then s.p_hits = (s.p_hits or 0) + 1
    else        s.p_miss = (s.p_miss or 0) + 1 end
    local h, n = 0, #s.p_history
    for _, v in ipairs(s.p_history) do if not v then h = h + 1 end end
    s.recent_miss_rate = n > 0 and (h / n * 100) or 0
end
local session_stats = {
    total_hits  = 0, total_miss  = 0,
    early_rate  = 0, recent_rate = 0,
    history     = {},
}
-- (real bodies assigned later — these names are now in scope for ALL closures below)

-- ╔══════════════════════════════════════╗
-- ║  SEL01-SOLVER — DEDICATED TAB        ║
-- ╚══════════════════════════════════════╝
local TAB = "Sel01-Solver"

-- v9.58: chernobl-style TABS. Distinct ui.create() first-args render as a horizontal
-- tab bar inside the script's sidebar entry (NL docs: "ui.create(tab, group[, column])"
-- + "ui.sidebar(name, icon)"). Tab-name strings are GLOBALS (no `local`) because the
-- main chunk is AT the 200-local cap. Column 1 = left, 2 = right within each tab.
-- One-time effect: re-tabbing re-keys UI elements -> toggles reset on first reload;
-- click a preset (SSG-Pro / Aggressive) to restore. Learned data is file-based, safe.
pcall(function() ui.sidebar(TAB, "crosshairs") end)
TAB_MAIN = ui.get_icon"sliders"    .. "  Main"
TAB_CORE = ui.get_icon"crosshairs" .. "  Resolver"
TAB_ESP  = ui.get_icon"eye"        .. "  ESP / Advisor"
TAB_ADV  = ui.get_icon"feather"    .. "  Advanced"
local g_main         = ui.create(TAB_MAIN, "Main",              1)
local g_smart        = ui.create(TAB_MAIN, "Smart Strategy",    2)
local g_resolver     = ui.create(TAB_CORE, "Resolver Core",     1)
local g_aggro        = ui.create(TAB_CORE, "Aggressive Tuning", 2)
local g_baim         = ui.create(TAB_CORE, "Bruteforce / Baim", 2)
local g_esp          = ui.create(TAB_ESP,  "ESP / HUD",         1)
local g_experimental = ui.create(TAB_ADV,  "Advanced (Fine Control)", 1)
local g_perf         = ui.create(TAB_ADV,  "Performance Info",  2)
local g_logging      = ui.create(TAB_ADV,  "Logging",           2)
local g_chat         = ui.create(TAB_ESP,  "Sel01-Roast (on kill)", 2)
-- V9.20: AA Advisor group — global (no `local`) to dodge main-chunk 200-local limit.
g_advisor = ui.create(TAB_ESP, "AA Advisor (Per-enemy)", 1)

-- Header — v9.57: chernobl-style multi-color welcome (\aDEFAULT resets to white).
_uname = (common and common.get_username and common.get_username()) or "player"  -- global: at local cap
g_main:label(ui.get_icon"user" .. "  Dear " .. accent .. _uname .. "\aDEFAULT, have a good game!")
g_main:label(ui.get_icon"sparkles" .. "  Build " .. accent .. "Sel01-Solver" .. "\aDEFAULT  version " .. accent .. SEL01_VERSION .. "\aDEFAULT")
g_main:label(ui.get_icon"crosshairs" .. "  Resolver by " .. accent .. "seltonmt01" .. "\aDEFAULT")
g_main:label(" ")
g_main:label(accent .. ui.get_icon"sliders" .. accent .. "  Quick Presets:")

-- preset buttons (apply_preset defined later — closure resolves at click-time)
local apply_preset_fwd  -- forward decl
local btn_preset_aggro    = g_main:button("Aggressive (Head-Focus)",  function() apply_preset_fwd("aggressive") end)
local btn_preset_dyn      = g_main:button("Dynamic (Adaptive)",       function() apply_preset_fwd("dynamic")    end)
local btn_preset_def      = g_main:button("Defensive (Safe)",         function() apply_preset_fwd("defensive")  end)
local btn_preset_nospread = g_main:button("NoSpread Server (1-Tap)",  function() apply_preset_fwd("nospread")   end)
local btn_preset_ssg      = g_main:button("SSG-Pro (Sniper + Learn)",  function() apply_preset_fwd("ssg_pro")    end)
local btn_preset_headonly = g_main:button("Headshot Only (Spread)",    function() apply_preset_fwd("head_only")  end)

g_smart:label(accent .. ui.get_icon"sparkles" .. accent .. "  Quick setup via dropdowns — beats individual toggles below")
g_smart:label(" ")

-- Main resolver toggles
local custom_aa = {
    enable = g_resolver:switch(accent .. ui.get_icon"sliders" .. accent .. "  Resolver Boost"),
}
local resolver = {
    enable = g_resolver:switch(accent .. ui.get_icon"sliders" .. accent .. "  Resolver (beta)", true),
}
local resolver_anim = {
    enable = g_resolver:switch(accent .. ui.get_icon"sliders" .. accent .. "  Resolver Animation"),
}
local resolver_mode = g_resolver:combo(
    accent .. ui.get_icon"crosshairs" .. accent .. "  Resolver Mode",
    "Adaptive", "Aggressive", "Defensive"
)

-- Aggressive-tuning
local lby_snap_toggle  = g_aggro:switch(accent .. ui.get_icon"bolt"     .. accent .. "  LBY Snap Detection",    true)
local air_resolve_tog  = g_aggro:switch(accent .. ui.get_icon"feather"  .. accent .. "  Air Resolve (no desync)", true)
local close_range_dist = g_aggro:slider(accent .. ui.get_icon"bullseye" .. accent .. "  Close Range (units)",  200, 1500, 800)
local dormancy_reset_t = g_aggro:slider(accent .. ui.get_icon"clock"    .. accent .. "  Dormancy Reset (ms)",  100, 2000, 500)

-- Brute-force / Baim
local force_baim_n     = g_baim:slider(accent .. ui.get_icon"skull"     .. accent .. "  Force Baim After N misses", 0, 5, 2)
local baim_min_damage  = g_baim:slider(accent .. ui.get_icon"crosshairs".. accent .. "  Baim Min Damage",       1, 100, 20)
local baim_hitbox      = g_baim:combo(accent  .. ui.get_icon"bullseye"  .. accent .. "  Baim Hitbox",
                                      "Stomach", "Pelvis", "Chest", "Legs")

-- Experimental
local exp_aa_classify  = g_experimental:switch(accent .. ui.get_icon"crosshairs" .. accent .. "  AA-Classification",  true)
local exp_multipoint   = g_experimental:switch(accent .. ui.get_icon"bullseye"   .. accent .. "  Multipoint Boost",   true)
local exp_def_aa       = g_experimental:switch(accent .. ui.get_icon"feather"    .. accent .. "  Defensive-AA Detect",true)
local exp_steam_mem    = g_experimental:switch(accent .. ui.get_icon"user"       .. accent .. "  Steam Memory",       false)
local exp_nospread     = g_experimental:switch(accent .. ui.get_icon"bolt"       .. accent .. "  NoSpread Mode (1-tap heads)", false)
local exp_classify_int = g_experimental:slider(accent .. ui.get_icon"clock"      .. accent .. "  AA-Classify Interval (ticks)", 4, 16, 8)

-- V3 features
local exp_aim_fire_snap = g_experimental:switch(accent .. ui.get_icon"bolt"       .. accent .. "  aim_fire Snapshot Learning", true)
local exp_perside_desync= g_experimental:switch(accent .. ui.get_icon"sliders"    .. accent .. "  Per-Side Desync Learning",   true)
local exp_esp_overlay   = g_experimental:switch(accent .. ui.get_icon"bullseye"   .. accent .. "  ESP Overlay (live mode)",    false)
local exp_cancel_conf   = g_experimental:switch(accent .. ui.get_icon"feather"    .. accent .. "  Cancel Low-Confidence Shots", true)
local exp_auto_weapon   = g_experimental:switch(accent .. ui.get_icon"crosshairs" .. accent .. "  Auto Per-Weapon Settings",   false)
-- V4: persistent learning + prediction
local exp_persistent_lm = g_experimental:switch(accent .. ui.get_icon"user"       .. accent .. "  Persistent Self-Learning Model", true)
local exp_extrapolation = g_experimental:switch(accent .. ui.get_icon"bolt"       .. accent .. "  Strong Prediction / Extrapolation", true)
local exp_respect_man   = g_experimental:switch(accent .. ui.get_icon"crosshairs" .. accent .. "  Respect Manual SSG/Sniper Settings", true)
local exp_predict_ticks = g_experimental:slider(accent .. ui.get_icon"clock"      .. accent .. "  Prediction Ticks Ahead", 1, 6, 2)
-- V7.9: strict head-only on normal (spread) servers
local exp_head_strict   = g_experimental:switch(accent .. ui.get_icon"crosshairs" .. accent .. "  Headshot-Only Strict (spread server)", false)
-- V9.31: relax NL safe-point on LOCKED targets so the ragebot takes HEAD instead
-- of the safe BODY point on proven enemies. GLOBAL (main chunk is at the 200-local
-- cap). Only toggles safepoint+multipoint (NEVER mindmg/hitbox) → respects the
-- never-override-NL-config rule; baseline unchanged for un-learned enemies.
exp_lock_headpref = g_experimental:switch(accent .. ui.get_icon"bullseye" .. accent .. "  Head-Pref on Locked Targets (less body)", true)
-- V9.33 EXPERIMENTAL: read the enemy's animated body-yaw pose param to pick the
-- guess SIDE without shooting. NL exposes m_flPoseParameter[] but the desync index
-- + mapping are NOT documented, so this is a guess (index 11, range ±60°) — OFF by
-- default, A/B test in-game. Only replaces the side coin-flip in guess fallbacks.
pose_read_tog = g_experimental:switch(accent .. ui.get_icon"flask" .. accent .. "  [EXP] Pose-param side read (A/B test)", false)
-- V9.67: four new resolver levers, all GLOBALS (200-local cap) + default OFF so the
-- baseline is untouched until the user opts in.
--  A) pose_cal_tog  — collect pose[0..23] vs known hit-side on every HIT, auto-find the
--     index that actually encodes body_yaw → turns SIDE from a guess into a direct read.
--  A) pose_use_tog  — once an index is calibrated, use its direct side in the resolve.
--  D) onshot_flip_tog — learn enemies that flip desync the tick they fire (on-shot AA),
--     then flip the resolved side inside their fire window.
--  B) switch_pred_tog — observe the server's per-tick predicted feet-yaw side, detect a
--     regular flip period, predict which side the fake is on at shot-land.
pose_cal_tog    = g_experimental:switch(accent .. ui.get_icon"flask"     .. accent .. "  [EXP] Pose-Param Calibration (collect)", false)
pose_use_tog    = g_experimental:switch(accent .. ui.get_icon"flask"     .. accent .. "  [EXP] Use Calibrated Pose Side", false)
onshot_flip_tog = g_experimental:switch(accent .. ui.get_icon"bolt"      .. accent .. "  On-Shot Side-Flip Learn", false)
switch_pred_tog = g_experimental:switch(accent .. ui.get_icon"clock"     .. accent .. "  Switch-Period Side Predict", false)
g_experimental:button("Dump Pose Calibration", function() pcall(pose_cal_dump) end)

-- ─── ESP / HUD dedicated group ─────────────────────────
local esp_master       = g_esp:switch(accent .. ui.get_icon"bullseye"  .. accent .. "  ESP Master (on/off)", true)
local esp_show_labels  = g_esp:switch(accent .. ui.get_icon"crosshairs".. accent .. "  Show Enemy Labels (mode/side/desync)", true)
local esp_show_confbar = g_esp:switch(accent .. ui.get_icon"sliders"   .. accent .. "  Show Confidence Bar", true)
local esp_show_hud     = g_esp:switch(accent .. ui.get_icon"sparkles"  .. accent .. "  Show HUD Corner Panel",  true)
-- v9.59: Top-Left listed first = the combo default (fresh installs start Top-Left)
local esp_hud_pos      = g_esp:combo (accent .. ui.get_icon"clock"     .. accent .. "  HUD Position",
                                      "Top-Left", "Bottom-Left", "Bottom-Right", "Top-Right")
local esp_throttle_hz  = g_esp:slider(accent .. ui.get_icon"bolt"      .. accent .. "  ESP Refresh Rate (Hz)", 5, 30, 10)
local esp_label_color  = g_esp:color_picker(accent .. ui.get_icon"feather" .. accent .. "  Label Default Color", color(255, 255, 255, 255))
g_esp:label(accent .. ui.get_icon"link-slash" .. accent .. "  Mode colors auto: green=Meas, yellow=Predict, red=BF, cyan=LBY")
-- V9.21: live event ticker top-right of screen — HIT/MISS/KILL/INFO with fade.
-- Global (no `local`) to dodge main-chunk 200-local limit.
esp_event_ticker = g_esp:switch(accent .. ui.get_icon"bolt" .. accent .. "  Event Ticker (top-right HUD log)", true)
-- V9.51: per-enemy ON-MODEL visuals. Globals (no `local`) to dodge the 200-local cap.
esp_wedge = g_esp:switch(accent .. ui.get_icon"diagram-project" .. accent .. "  Desync Wedge (real vs fake yaw lines on body)", true)
esp_flash = g_esp:switch(accent .. ui.get_icon"bolt-lightning"  .. accent .. "  Hit/Miss Flash (box on each shot)", true)
esp_enh   = g_esp:switch(accent .. ui.get_icon"layer-group"      .. accent .. "  Enhanced Tags (AA-glyph / netcode / shot-dots / side-dom)", true)

-- ─── SMART STRATEGY COMBOS (batch-set individual toggles) ─────
local strat_learning = g_smart:combo(accent .. ui.get_icon"user"      .. accent .. "  Learning Strategy",
                                     "Off", "Basic", "Smart", "Adaptive (Recommended)")
local strat_predict  = g_smart:combo(accent .. ui.get_icon"bolt"      .. accent .. "  Prediction Strategy",
                                     "Off", "Light", "Normal", "Aggressive")
local strat_visual   = g_smart:combo(accent .. ui.get_icon"bullseye"  .. accent .. "  Visual Style",
                                     "None", "Minimal (HUD only)", "Standard (ESP + HUD)", "Full (everything)")
local strat_hitbox   = g_smart:combo(accent .. ui.get_icon"crosshairs".. accent .. "  Hitbox Strategy",
                                     "NL Default (manual)", "Head Bias", "Head + Chest Fallback", "Head Only", "NoSpread (head always)")

local function safe_set_local(ctrl, val) if ctrl then pcall(function() ctrl:set(val) end) end end

strat_learning:set_callback(function(r)
    local v = tostring(r:get())
    if v == "Off" then
        safe_set_local(exp_aim_fire_snap, false); safe_set_local(exp_perside_desync, false)
        safe_set_local(exp_persistent_lm, false); safe_set_local(exp_def_aa, false)
        safe_set_local(exp_steam_mem, false);     safe_set_local(exp_aa_classify, false)
    elseif v == "Basic" then
        safe_set_local(exp_aim_fire_snap, true);  safe_set_local(exp_perside_desync, false)
        safe_set_local(exp_persistent_lm, false); safe_set_local(exp_def_aa, true)
        safe_set_local(exp_steam_mem, false);     safe_set_local(exp_aa_classify, true)
    elseif v == "Smart" then
        safe_set_local(exp_aim_fire_snap, true);  safe_set_local(exp_perside_desync, true)
        safe_set_local(exp_persistent_lm, true);  safe_set_local(exp_def_aa, true)
        safe_set_local(exp_steam_mem, true);      safe_set_local(exp_aa_classify, true)
    else -- Adaptive
        safe_set_local(exp_aim_fire_snap, true);  safe_set_local(exp_perside_desync, true)
        safe_set_local(exp_persistent_lm, true);  safe_set_local(exp_def_aa, true)
        safe_set_local(exp_steam_mem, true);      safe_set_local(exp_aa_classify, true)
    end
    cs_log("Learning Strategy → " .. v)
end)

strat_predict:set_callback(function(r)
    local v = tostring(r:get())
    if v == "Off" then
        safe_set_local(exp_extrapolation, false)
    elseif v == "Light" then
        safe_set_local(exp_extrapolation, true); safe_set_local(exp_predict_ticks, 1)
    elseif v == "Normal" then
        safe_set_local(exp_extrapolation, true); safe_set_local(exp_predict_ticks, 2)
    else -- Aggressive (V8.1: lowered 4→3, was overshooting)
        safe_set_local(exp_extrapolation, true); safe_set_local(exp_predict_ticks, 3)
    end
    cs_log("Prediction Strategy → " .. v)
end)

strat_visual:set_callback(function(r)
    local v = tostring(r:get())
    if v == "None" then
        safe_set_local(exp_esp_overlay, false); safe_set_local(esp_master, false)
        safe_set_local(esp_show_labels, false); safe_set_local(esp_show_hud, false)
        safe_set_local(esp_show_confbar, false)
    elseif v == "Minimal (HUD only)" then
        safe_set_local(exp_esp_overlay, true);  safe_set_local(esp_master, true)
        safe_set_local(esp_show_labels, false); safe_set_local(esp_show_hud, true)
        safe_set_local(esp_show_confbar, false)
    elseif v == "Standard (ESP + HUD)" then
        safe_set_local(exp_esp_overlay, true);  safe_set_local(esp_master, true)
        safe_set_local(esp_show_labels, true);  safe_set_local(esp_show_hud, true)
        safe_set_local(esp_show_confbar, false)
    else -- Full
        safe_set_local(exp_esp_overlay, true);  safe_set_local(esp_master, true)
        safe_set_local(esp_show_labels, true);  safe_set_local(esp_show_hud, true)
        safe_set_local(esp_show_confbar, true)
    end
    cs_log("Visual Style → " .. v)
end)

strat_hitbox:set_callback(function(r)
    local v = tostring(r:get())
    -- V9.71: exp_head_focus / exp_hitbox_chain removed — dead since v9.18 deleted the
    -- HEAD-FOCUS override block (toggles set state nothing ever read).
    if v == "NL Default (manual)" then
        safe_set_local(exp_nospread, false); safe_set_local(exp_respect_man, true)
        safe_set_local(exp_multipoint, false)
    elseif v == "Head Bias" then
        safe_set_local(exp_nospread, false); safe_set_local(exp_respect_man, false)
        safe_set_local(exp_multipoint, true)
    elseif v == "Head + Chest Fallback" then
        safe_set_local(exp_nospread, false); safe_set_local(exp_respect_man, false)
        safe_set_local(exp_multipoint, true)
    elseif v == "Head Only" then
        safe_set_local(exp_nospread, false); safe_set_local(exp_respect_man, false)
        safe_set_local(exp_multipoint, true)
    else -- NoSpread
        safe_set_local(exp_nospread, true); safe_set_local(exp_respect_man, false)
        safe_set_local(exp_multipoint, false)
    end
    cs_log("Hitbox Strategy → " .. v)
end)

g_smart:label(" ")
g_smart:label(accent .. ui.get_icon"link-slash" .. accent .. "  Tip: click preset above → strategy auto-applies. Advanced toggles below override.")

-- ╔══════════════════════════════════════════════════╗
-- ║ V9.20: AA ADVISOR — per-enemy tuning advisor     ║
-- ╠══════════════════════════════════════════════════╣
-- ║ Build a snapshot of all currently-tracked        ║
-- ║ enemies from PlayerState. Cycle through them and ║
-- ║ generate AA-config recommendations based on what ║
-- ║ the resolver learned about THEIR style. Output   ║
-- ║ goes to chat (color_log) — copy / read live.     ║
-- ║ All state + helpers declared as GLOBALS so they  ║
-- ║ don't consume the main-chunk 200-local budget.   ║
-- ╚══════════════════════════════════════════════════╝
advisor_state = { idx = 0, list = {} }

function advisor_rebuild()
    advisor_state.list = {}
    for idx = 1, 64 do
        local s = PlayerState[idx]
        if s then
            local sl, sr = s.samples_left or 0, s.samples_right or 0
            local pass   = s.passive_samples or 0
            if (sl + sr) >= 1 or pass >= 5 then
                local nm = "idx#" .. idx
                pcall(function()
                    local p = entity.get(idx)
                    if p and p.get_name then
                        local got = p:get_name()
                        if got and got ~= "" then nm = got end
                    end
                end)
                local mag = math.max(s.measured_left or 0, s.measured_right or 0, s.measured_desync or 0)
                local dom = 0
                if sr >= sl + 2 then dom =  1
                elseif sl >= sr + 2 then dom = -1
                end
                advisor_state.list[#advisor_state.list + 1] = {
                    idx        = idx,
                    name       = nm,
                    aa_type    = s.aa_type or "?",
                    samples_l  = sl,
                    samples_r  = sr,
                    measured_l = s.measured_left or 0,
                    measured_r = s.measured_right or 0,
                    mag        = mag,
                    dom        = dom,
                    hits       = sl + sr,
                    miss       = s.missed or 0,
                    miss_rate  = math.floor(s.recent_miss_rate or 0),
                    passive    = pass,
                    last_mode  = s.mode or "?",
                }
            end
        end
    end
    table.sort(advisor_state.list, function(a, b)
        if a.hits ~= b.hits then return a.hits > b.hits end
        return a.passive > b.passive
    end)
    if #advisor_state.list == 0 then advisor_state.idx = 0
    elseif advisor_state.idx == 0 or advisor_state.idx > #advisor_state.list then
        advisor_state.idx = 1
    end
end

function advisor_dom_label(d)
    if d > 0 then return "RIGHT" end
    if d < 0 then return "LEFT" end
    return "BALANCED"
end

function advisor_show()
    if #advisor_state.list == 0 then
        cs_log_color("[Advisor] No tracked players yet. Play 1-2 rounds, then click 🔁 Refresh.")
        return
    end
    local e = advisor_state.list[advisor_state.idx]
    if not e then return end
    cs_log_color("══════════════════════════════════════════")
    cs_log_color(string.format("  AA Advisor:  %s   (#%d / %d)",
        e.name, advisor_state.idx, #advisor_state.list))
    cs_log_color("══════════════════════════════════════════")
    cs_log_color(string.format("  Their AA:  %s  |  prefers %s side  |  desync ≈ %.0f°",
        tostring(e.aa_type):upper(), advisor_dom_label(e.dom), e.mag))
    cs_log_color(string.format("  Our data:  %d hits  |  L=%d  R=%d  |  miss-rate %d%%",
        e.hits, e.samples_l, e.samples_r, e.miss_rate))
    cs_log_color("  ── Recommendations ─────────────────────")
    for _, line in ipairs(advisor_build_recs(e)) do
        cs_log_color("  " .. line)
    end
    cs_log_color("══════════════════════════════════════════")
end

-- V9.25: advisor recommendations rewritten for clarity. Each rec now says
-- WHAT to do (concrete slider/toggle name + value) and WHY in plain language.
-- Builder returns a list of {"label", color_prefix_or_nil} tuples so we can
-- highlight DO-THIS lines green and explanation lines white.
function advisor_build_recs(e)
    local r = {}
    local function push(text, kind)
        -- kind: "do" green / "why" white / "warn" orange / "good" cyan / nil plain
        local prefix = ""
        if     kind == "do"   then prefix = "\aB4F082FF"   -- green
        elseif kind == "why"  then prefix = "\aC8C8C8FF"   -- light grey
        elseif kind == "warn" then prefix = "\aFFB46EFF"   -- orange
        elseif kind == "good" then prefix = "\a8CE0FFFF"   -- cyan
        else                       prefix = "\aFFFFFFFF"
        end
        r[#r+1] = prefix .. text
    end

    -- 1) headline: what type of enemy + how much we know
    if e.aa_type == "static" then
        push("→ Enemy uses STATIC anti-aim (fixed side)", nil)
        push("   Their resolver expects you to use static too — break it",  "why")
        push("   DO: Sel01-Config → Yaw Modifier = Jitter, interval 1-2 ticks", "do")
        push("   DO: Anti-BF jitter ON, YAW base rotation ON",                 "do")
    elseif e.aa_type == "switch" then
        push("→ Enemy uses SWITCH anti-aim (alternates L/R)", nil)
        push("   Their resolver tracks your streak — flip earlier than they expect", "why")
        push("   DO: Sel01-Config → Desync = 58 (max)", "do")
        push("   DO: Side-streak limit ON, threshold 2 shots",                "do")
        push("   DO: YAW rotation ON, Defensive-on-dmg ON",                   "do")
    elseif e.aa_type == "jitter" then
        push("→ Enemy uses JITTER anti-aim (small fast flips)", nil)
        push("   Their resolver syncs to a clock — desync it",            "why")
        push("   DO: Sel01-Config → Desync 35-45 (NOT max)",              "do")
        push("   DO: Jitter interval = 3 or 5 (avoid 2/4)",               "do")
        push("   DO: Slow-walk AA boost ON for peeks",                    "do")
    elseif e.aa_type == "spinner" then
        push("→ Enemy SPINNER (continuously rotating)", nil)
        push("   Rare config — most resolvers fail. Use chaos",           "why")
        push("   DO: YAW rotation ON + Side-streak 2 + Anti-BF max var",  "do")
    else
        push("→ Enemy AA type still unknown", nil)
        push("   Need 2-3 more hits to classify — generic defense:",      "why")
        push("   DO: Defensive-on-dmg ON, Side-streak 3, Anti-BF ON",     "do")
    end

    -- 2) magnitude advice
    if e.mag >= 35 then
        push(string.format("→ Their desync is BIG (%.0f°). Their resolver trains on big numbers.", e.mag), nil)
        push("   DO: Your desync 20-30 OR full 58 (avoid 35-45 middle)",  "do")
    elseif e.mag > 0 and e.mag <= 22 then
        push(string.format("→ Their desync is SMALL (%.0f°). Their resolver under-shoots big.", e.mag), nil)
        push("   DO: Your desync 58 fixed wins reliably",                  "do")
    end

    -- 3) dominance advice (only when enough samples)
    if e.dom ~= 0 and (e.samples_l + e.samples_r) >= 4 then
        local their_word = e.dom > 0 and "RIGHT" or "LEFT"
        local your_word  = e.dom > 0 and "LEFT"  or "RIGHT"
        push(string.format("→ They strongly favor %s side", their_word), nil)
        push(string.format("   DO: NL Anti Aim → Body Yaw Inverter = %s manual", your_word), "do")
        push("   OR: Side-streak threshold 2 (force flip after 2 shots)",       "do")
    end

    -- 4) miss-rate warning
    if e.miss_rate >= 30 then
        push(string.format("⚠ Resolver miss-rate is high on this one (%d%%)", e.miss_rate), "warn")
        push("   DO: Smart Strategy → Predict = Conservative for this match",    "warn")
    end

    -- 5) good-status notes
    if e.hits >= 5 and e.miss_rate <= 15 then
        push(string.format("✓ Solid lock (%d hits, %d%% miss). Keep current preset.", e.hits, e.miss_rate), "good")
    end

    return r
end

-- V9.23+25: panel-update helper. Refreshes the pre-created labels via :name().
function advisor_panel_update()
    local function setn(lbl, text)
        if lbl and lbl.name then pcall(function() lbl:name(text or " ") end) end
    end
    if #advisor_state.list == 0 then
        setn(advisor_lbl_header, "  (empty — click 🔁 Refresh)")
        setn(advisor_lbl_stats1, "  Play 1-2 rounds first, then click 🔁")
        setn(advisor_lbl_stats2, " ")
        setn(advisor_lbl_rec1,   " ")
        setn(advisor_lbl_rec2,   " ")
        setn(advisor_lbl_rec3,   " ")
        setn(advisor_lbl_rec4,   " ")
        setn(advisor_lbl_rec5,   " ")
        setn(advisor_lbl_rec6,   " ")
        setn(advisor_lbl_rec7,   " ")
        setn(advisor_lbl_rec8,   " ")
        return
    end
    local e = advisor_state.list[advisor_state.idx]
    if not e then return end
    -- header line: enemy + position in list
    setn(advisor_lbl_header,
        string.format("  \aFFD8AAFF#%d/%d  \aFFFFFFFF%s",
            advisor_state.idx, #advisor_state.list, e.name))
    -- stats line 1: enemy AA profile (their style)
    setn(advisor_lbl_stats1,
        string.format("  Their AA: %s  |  prefers %s side  |  desync ≈ %.0f°",
            tostring(e.aa_type):upper(), advisor_dom_label(e.dom), e.mag))
    -- stats line 2: how much data we have on them
    setn(advisor_lbl_stats2,
        string.format("  Data: %d hits  |  L=%d  R=%d  |  miss-rate %d%%",
            e.hits, e.samples_l, e.samples_r, e.miss_rate))
    -- recommendations
    local recs = advisor_build_recs(e)
    while #recs < 8 do recs[#recs+1] = " " end
    setn(advisor_lbl_rec1, "  " .. recs[1])
    setn(advisor_lbl_rec2, "  " .. recs[2])
    setn(advisor_lbl_rec3, "  " .. recs[3])
    setn(advisor_lbl_rec4, "  " .. recs[4])
    setn(advisor_lbl_rec5, "  " .. recs[5])
    setn(advisor_lbl_rec6, "  " .. recs[6])
    setn(advisor_lbl_rec7, "  " .. recs[7])
    setn(advisor_lbl_rec8, "  " .. recs[8])
end

advisor_btn_refresh = g_advisor:button("🔁 Refresh player list", function()
    pcall(advisor_rebuild)
    pcall(advisor_panel_update)
end)
advisor_btn_next = g_advisor:button("▶ Next player", function()
    if #advisor_state.list == 0 then
        pcall(advisor_panel_update)
        return
    end
    advisor_state.idx = (advisor_state.idx % #advisor_state.list) + 1
    pcall(advisor_panel_update)
end)
advisor_btn_show = g_advisor:button("💡 Refresh recommendations", function()
    pcall(advisor_rebuild)
    pcall(advisor_panel_update)
end)
advisor_btn_all = g_advisor:button("📜 Dump recs for ALL to console", function()
    pcall(advisor_rebuild)
    if #advisor_state.list == 0 then
        cs_log_color("[Advisor] no enemies tracked yet")
        return
    end
    local save_idx = advisor_state.idx
    for i = 1, #advisor_state.list do
        advisor_state.idx = i
        pcall(advisor_show)
    end
    advisor_state.idx = save_idx
end)

-- V9.29 coach-chat. Goals:
--   * Mention REAL stats in the diagnosis (streak counts, per-side magnitudes,
--     dom counts, hits-on-them) so each enemy gets a personalised line rather
--     than the same template every time.
--   * Pick from 2-3 wording variants per category (deterministic-by-name so
--     the same enemy gets the same flavour across calls, but different enemies
--     vary).
--   * Detect BIMODAL desync (per-side mags differ by >10°) and call it out
--     specifically — the resolver handles bimodal via per-side EMA but the
--     enemy doesn't know they're leaking 2 distinct values.
function advisor_chat_send()
    if #advisor_state.list == 0 then
        cs_event_console("Advisor: no enemy selected — click 🔁 Refresh first", 240, 200, 100)
        return
    end
    local e = advisor_state.list[advisor_state.idx]
    if not e then return end

    -- Trim CSGO name to 18 chars so longer messages fit.
    local nm = tostring(e.name or "enemy")
    if #nm > 18 then nm = nm:sub(1, 18) end

    -- Variant picker: deterministic from name + AA type so same enemy keeps
    -- one phrasing across calls but different enemies vary.
    local function variant_pick(list, salt)
        local h = (#nm) + (salt or 0)
        for i = 1, #nm do h = h + string.byte(nm, i) end
        return list[(h % #list) + 1]
    end

    -- Detect bimodal (two distinct per-side magnitudes >10° apart).
    local bimodal = false
    if (e.samples_l or 0) >= 2 and (e.samples_r or 0) >= 2
       and math.abs((e.measured_l or 0) - (e.measured_r or 0)) > 10 then
        bimodal = true
    end

    -- Variant pools per AA type. Each pool has 3 phrasings of the SAME
    -- diagnosis (PROBLEM + WHY). All <127 chars when prefixed with "[Sel01-
    -- Coach] @<nm> " (max 32 chars prefix).
    local diag_static = {
        "ur static-AA picks the same side every shot, resolvers lock ur fake yaw after 1-2 hits and just shoot opp",
        "u use static body-yaw - no movement on the fake = trivial to learn, every resolver beats this in 2 hits",
        "ur AA never flips, server reads ur fake angle as constant, resolvers fire opposite side blind and hit",
    }
    local diag_switch = {
        "ur switch-AA L<->R is rhythmic, resolvers track ur streak (%d/%d) and predict the next side",
        "u alternate sides predictably (streak L=%d R=%d), good resolvers count the pattern and lead it",
        "ur switch-pattern is readable - hit count L=%d R=%d makes side prediction easy after 3 shots",
    }
    local diag_jitter = {
        "ur jitter has a fixed interval, resolvers sync to it and lead onto ur real head every ~3rd shot",
        "jitter w/ steady interval = clock signal, resolvers period-match and fire when fake hits zero",
        "ur jitter cycles too regular - resolvers detect the period and time shots into ur real yaw window",
    }
    local diag_spinner = {
        "spinner leaks position via yaw_rate sign, resolvers compute desync side from rotation direction",
        "ur spinner gives away the AA side by rotation - resolvers invert yaw_rate sign and hit opposite",
        "spinner = yaw_rate live broadcast, resolvers use it to predict fake yaw within one tick",
    }
    local diag_unknown = {
        "ur AA still readable, no defensive reaction on getting hit = resolvers keep using their first guess",
        "no AA panic-mode here, ur pattern stays steady even after taking dmg - that locks resolvers harder",
        "ur AA has no break-out behaviour, resolvers refine their lock-on each round with no reset",
    }

    -- Fix pools (HOW + brief why).
    local fix_static = {
        "fix: set Yaw Modifier to JITTER, interval 1-2 ticks - fake angle moves every tick, no lock possible",
        "fix: drop static, enable Jitter yaw mod 1-2 tick + Anti-BF variance ON, breaks every dom-side resolver",
        "fix: yaw mod = Jitter (interval 2) + anti-BF noise = fake angle drifts and no resolver can pin it",
    }
    local fix_switch = {
        "fix: desync max 58 + auto flip body-yaw inverter every 2 shots, breaks the L<->R streak they read",
        "fix: enable side-streak limit (flip after 2 shots) + max desync 58 = next side becomes random",
        "fix: max desync + force inverter flip after 2 shots = breaks the alternation pattern they predict",
    }
    local fix_jitter = {
        "fix: jitter interval ODD (3 or 5) + desync 35-45 not max, kills the clock sync most resolvers use",
        "fix: switch jitter interval to 3 or 5 (avoid 2 and 4) + desync 40 mid-range = no period to lock onto",
        "fix: jitter int 3 or 5, plus anti-BF magnitude variance - resolvers cant period-match a moving target",
    }
    local fix_spinner = {
        "fix: drop spinner, use jitter + yaw base rotation + max anti-BF variance = signal stops being readable",
        "fix: switch spinner -> jitter, add yaw rotation every 4-8s = yaw_rate sign keeps inverting on them",
        "fix: spinner off, use jitter w/ random interval + anti-BF max var, removes the rotation tell",
    }
    local fix_unknown = {
        "fix: enable defensive-on-dmg (max desync 2s after hit) + force inverter flip after 3 shots = panic mode works",
        "fix: turn on defensive AA window (2s after taking dmg) + side-streak 3 = resolvers reset on hit",
        "fix: defensive-on-dmg ON + flip-after-3 + anti-BF variance, gives ur AA a break-out routine",
    }

    local lines = {}

    -- Line 1: diagnosis. switch uses streak counts in the line.
    local pool, head, used_stats
    if e.aa_type == "static" then
        pool = diag_static; head = variant_pick(pool, 1)
    elseif e.aa_type == "switch" then
        pool = diag_switch; head = variant_pick(pool, 1)
        head = string.format(head, e.samples_l or 0, e.samples_r or 0)
        used_stats = true
    elseif e.aa_type == "jitter" then
        pool = diag_jitter; head = variant_pick(pool, 1)
    elseif e.aa_type == "spinner" then
        pool = diag_spinner; head = variant_pick(pool, 1)
    else
        pool = diag_unknown; head = variant_pick(pool, 1)
    end
    lines[#lines+1] = string.format("[Sel01-Coach] @%s %s", nm, head)

    -- Line 2: fix.
    local fix_pool
    if e.aa_type == "static" then fix_pool = fix_static
    elseif e.aa_type == "switch" then fix_pool = fix_switch
    elseif e.aa_type == "jitter" then fix_pool = fix_jitter
    elseif e.aa_type == "spinner" then fix_pool = fix_spinner
    else                              fix_pool = fix_unknown
    end
    lines[#lines+1] = string.format("@%s %s", nm, variant_pick(fix_pool, 2))

    -- Line 3 (special): BIMODAL detection — overrides dom line.
    if bimodal then
        lines[#lines+1] = string.format(
            "@%s u use 2 different desync values (L=%.0f° R=%.0f°), resolvers learn each side independently",
            nm, e.measured_l, e.measured_r)
    elseif e.dom ~= 0 and (e.samples_l + e.samples_r) >= 4 then
        local their_side = e.dom > 0 and "right" or "left"
        local your_side  = e.dom > 0 and "left"  or "right"
        local dom_count  = e.dom > 0 and e.samples_r or e.samples_l
        local other      = e.dom > 0 and e.samples_l or e.samples_r
        local dom_variants = {
            "u land %s %d of %d times = strong dom, resolvers see the lean and aim %s - manual %s or auto flip every 2 shots",
            "%s side has %d/%d ur hits - thats a clear lean, resolvers pre-shoot %s - flip to manual %s",
            "%s-side count %d (vs %d) is too one-sided, dom-bias resolvers nail u - force manual %s",
        }
        local fmt = variant_pick(dom_variants, 3)
        local msg
        if fmt == dom_variants[1] then
            msg = string.format(fmt, their_side, dom_count, dom_count + other, their_side, your_side)
        elseif fmt == dom_variants[2] then
            msg = string.format(fmt, their_side, dom_count, dom_count + other, their_side, your_side)
        else
            msg = string.format(fmt, their_side, dom_count, other, your_side)
        end
        lines[#lines+1] = string.format("@%s %s", nm, msg)
    end

    -- Line 4 (optional): magnitude. Cites actual avg.
    if e.mag >= 35 then
        local big_variants = {
            "desync ~%.0f is BIG, most resolvers train on this range - drop to 20-25 to fall under their guess",
            "ur %.0f° desync is in the resolver sweet spot, lower it to 22 or push to 58 max to escape",
            "%.0f° is the standard rage value, every resolver expects it - jump to 58 or hide at 22",
        }
        local fmt = variant_pick(big_variants, 4)
        lines[#lines+1] = string.format("@%s " .. fmt, nm, e.mag)
    elseif e.mag > 0 and e.mag <= 22 then
        local small_variants = {
            "desync ~%.0f is SMALL, resolvers under-shoot u easily - push to 50-58 max so the gap is wide",
            "ur %.0f° desync barely moves the fake - bump to 55+ for real protection",
            "%.0f° is below the resolver guess floor (~29°), they may even miss accidentally - go max 58 for safety",
        }
        local fmt = variant_pick(small_variants, 4)
        lines[#lines+1] = string.format("@%s " .. fmt, nm, e.mag)
    end

    -- Send each line through CSGO chat. utils.console_exec is the Sel01-Roast
    -- pattern; engine.execute_client_cmd is the fallback. Strip embedded
    -- quotes (the say parser dies on those), clamp to 126 chars.
    for _, msg in ipairs(lines) do
        msg = msg:gsub('"', "'")
        if #msg > 126 then msg = msg:sub(1, 126) end
        local sent = pcall(function() utils.console_exec(string.format('say "%s"', msg)) end)
        if not sent then
            pcall(function() engine.execute_client_cmd(string.format('say "%s"', msg)) end)
        end
        cs_event_console("[Coach->chat] " .. msg, 180, 220, 255)
    end
end
advisor_btn_chat = g_advisor:button("📨 Send tips to CSGO chat (selected)", function()
    pcall(advisor_chat_send)
end)
-- V9.23: in-menu advisor panel. Pre-create label slots that get their text
-- updated at runtime via the NL `:name(string)` method (confirmed pattern from
-- bloodwings / frostlive / grenade_helper). No on-screen render — output stays
-- inside the NL UI so the user can read it without opening console.
g_advisor:label(" ")
g_advisor:label("\a{Link Active}══════ Selected Player ══════")
advisor_lbl_header = g_advisor:label("  (click 🔁 Refresh to start)")
advisor_lbl_stats1 = g_advisor:label(" ")
advisor_lbl_stats2 = g_advisor:label(" ")
g_advisor:label("\a{Link Active}── Config-side recs ──")
advisor_lbl_rec1   = g_advisor:label(" ")
advisor_lbl_rec2   = g_advisor:label(" ")
advisor_lbl_rec3   = g_advisor:label(" ")
advisor_lbl_rec4   = g_advisor:label(" ")
advisor_lbl_rec5   = g_advisor:label(" ")
advisor_lbl_rec6   = g_advisor:label(" ")
advisor_lbl_rec7   = g_advisor:label(" ")
advisor_lbl_rec8   = g_advisor:label(" ")

-- ╔══════════════════════════════════════════════════╗
-- ║ V9.21: EVENT TICKER (top-right on-screen log)    ║
-- ╠══════════════════════════════════════════════════╣
-- ║ Dedicated ring of last N HIT/MISS/KILL/INFO      ║
-- ║ events with timestamp + color. Rendered top-right║
-- ║ of screen so user always sees what's happening — ║
-- ║ no console toggle required, no menu open needed. ║
-- ║ cs_event_* helpers also print to console via     ║
-- ║ client.color_log (bypasses log_enabled gate).    ║
-- ╚══════════════════════════════════════════════════╝
event_ticker = { cap = 12, head = 0, count = 0 }
function event_ticker_push(text, r, g, b)
    local t = event_ticker
    t.head = (t.head % t.cap) + 1
    t[t.head] = {
        txt = tostring(text or ""),
        r   = r or 220, g = g or 220, b = b or 220,
        t   = globals.realtime or 0,
    }
    if t.count < t.cap then t.count = t.count + 1 end
end
-- V9.25: console-print with multi-fallback. User reported events showed on
-- ticker but not in NL console. Now we try three writers in order: NL's
-- color_log (if exposed by build), client.log (NL standard), then plain print
-- (CSGO game console). Also push the brief line to log_buffer so 📋 Copy
-- captures it for sharing.
function cs_event_console(text, r, g, b)
    local line = "[Sel01] " .. tostring(text)
    local ok = pcall(function() client.color_log(r or 220, g or 220, b or 220, line) end)
    if not ok then
        ok = pcall(function() client.log(line) end)
        if not ok then pcall(function() print(line) end) end
    end
    pcall(function() log_buffer_push(line) end)
end
-- V9.32: enriched HIT/MISS lines. delta = resolved-vs-eye angle, m = measured EMA,
-- c = confidence, side L/R, bt = backtrack tick (high = stale-record/netcode miss,
-- not our angle error). Extra args optional → callers without them get the short line.
function _side_tag(side)  -- GLOBAL (main chunk at 200-local cap)
    return side and (side > 0 and "R" or (side < 0 and "L" or "·")) or "·"
end
function cs_event_hit(idx, mode, delta, meas, conf, side)
    local txt
    if delta then
        txt = string.format("✓ HIT #%d %s  Δ%.0f m%.0f c%d %s",
            idx or 0, tostring(mode or "?"), delta or 0, meas or 0, conf or 0, _side_tag(side))
    else
        txt = string.format("✓ HIT #%d  %s", idx or 0, tostring(mode or "?"))
    end
    event_ticker_push(txt, 110, 240, 130)
    cs_event_console(txt, 110, 240, 130)
end
function cs_event_miss(idx, reason, mode, delta, meas, bt, conf)
    local txt
    if delta then
        txt = string.format("✗ MISS #%d %s (%s)  Δ%.0f m%.0f bt%d c%d",
            idx or 0, tostring(reason or "?"), tostring(mode or "?"),
            delta or 0, meas or 0, bt or 0, conf or 0)
    else
        txt = string.format("✗ MISS #%d  %s  (%s)",
            idx or 0, tostring(reason or "?"), tostring(mode or "?"))
    end
    event_ticker_push(txt, 240, 110, 110)
    cs_event_console(txt, 240, 110, 110)
end
function cs_event_kill(name)
    local txt = string.format("☠ KILL  %s", tostring(name or "?"))
    event_ticker_push(txt, 200, 180, 255)
    cs_event_console(txt, 200, 180, 255)
end
function cs_event_info(text, r, g, b)
    event_ticker_push(text, r or 200, g or 220, b or 255)
    cs_event_console(text, r or 200, g or 220, b or 255)
end

-- Performance info (labels — settings hardcoded ON)
g_perf:label(accent .. ui.get_icon"bolt"     .. accent .. "  Anim-state cache: ON (per tick)")
g_perf:label(accent .. ui.get_icon"bolt"     .. accent .. "  Globals lookup cache: ON")
g_perf:label(accent .. ui.get_icon"bolt"     .. accent .. "  FOV cull (>110°): ON")
g_perf:label(accent .. ui.get_icon"bolt"     .. accent .. "  Distance cutoff (>4500u): ON")
g_perf:label(accent .. ui.get_icon"bolt"     .. accent .. "  Lazy log format: ON")

-- Logging
local log_enabled      = g_logging:switch(accent .. ui.get_icon"link-slash" .. accent .. "  Console Logging", true)
local log_verbose      = g_logging:switch(accent .. ui.get_icon"sliders"    .. accent .. "  Verbose (per-shot)", false)
local log_debug        = g_logging:switch(accent .. ui.get_icon"link-slash" .. accent .. "  DEBUG MODE (full dump)", false)
-- V7.1 + V9.3: log-buffer as ring (O(1) push). All state in single table to save locals.
-- V9.10: cap 80 -> 200. User reported "not all logs sent" — bigger ring keeps more
-- aa-commit / hit / miss / snapshot history in the copy-logs dump for long sessions.
local log_buffer = { cap = 200, head = 0, count = 0 }
local function log_buffer_push(line)
    log_buffer.head = (log_buffer.head % log_buffer.cap) + 1
    log_buffer[log_buffer.head] = line
    if log_buffer.count < log_buffer.cap then log_buffer.count = log_buffer.count + 1 end
end
local function log_buffer_iter()
    local out = {}
    for i = 1, log_buffer.count do
        local idx = ((log_buffer.head - log_buffer.count + i - 1) % log_buffer.cap) + 1
        out[#out + 1] = log_buffer[idx]
    end
    return out
end

-- V9.19: SESSION-ROLLING DESYNC RING + adaptive guess-magnitude helper.
-- Declared as MODULE GLOBALS (no `local`) because main-chunk is already near
-- the Lua 5.1 200-local limit. Globals are looked up in _G; tiny overhead per
-- call but functionally identical. Safe — these names are unique to this script.
-- Tracks the last N measured desyncs from all hits across all enemies in current
-- lobby. samples=0 fallback paths (Predicted-Guess, Networked-Guess, *-Guess)
-- previously used hardcoded ±29°. User's lobby modal desync was ~37-38° so 29°
-- under-shot constantly. Adaptive median catches up automatically.
sel01_session_desyncs = { cap = 20, head = 0, count = 0, dirty = true }
function session_push_desync(v)
    if not v or v < 5 or v > 58 then return end  -- V9.33: cap at 58 (max desync) so >58 reads can't bias the median high
    local r = sel01_session_desyncs
    r.head = (r.head % r.cap) + 1
    r[r.head] = v
    if r.count < r.cap then r.count = r.count + 1 end
    r.dirty = true  -- V9.31: invalidate adaptive_guess_mag memo
end
function adaptive_guess_mag()
    local r = sel01_session_desyncs
    if r.count == 0 then return 29 end
    -- V9.31: memoize. Median only changes when session_push_desync runs (a HIT),
    -- but this is called from 6 per-resolve *-Guess paths 64×/sec/enemy. Cache the
    -- sorted-median; recompute only when the ring is dirty.
    if not r.dirty and r.cached_mag then return r.cached_mag end
    local tmp = {}
    for i = 1, r.count do tmp[i] = r[i] end
    table.sort(tmp)
    local mid = tmp[math.ceil(r.count / 2)]
    if mid < 20 then mid = 20 elseif mid > 58 then mid = 58 end
    r.cached_mag = mid
    r.dirty = false
    return mid
end

-- V9.19: ALT-MODE side picker. Predicted-Alt / Air-Alt / Slow-Alt / Still-Alt
-- previously did blind `-last_hit_side` flip. On enemies with clear dom (e.g.
-- streak{L=9 R=0}) flipping = miss every time. New rule: if dom-side leads by
-- 2+ samples, STAY on dom. Otherwise blind alternate as before. Returns +1 (R),
-- -1 (L), or 0 if no signal — caller falls back to its own default.
function alt_side_pick(s)
    local sl, sr = s.samples_left or 0, s.samples_right or 0
    -- V9.48: when REAL hits exist on BOTH sides the enemy genuinely alternates —
    -- the seeded-inclusive sample counts (sl/sr also carry passive + seeded entries
    -- that can lean one way) must not pin a dom side. Use real-hit dominance; balanced
    -- real data falls to alternation off last_hit_side. Only when a side has no real
    -- data at all do we trust the seeded counts (the streak{L=9 R=0} dom case stays).
    -- (logs: idx=4 sl=3 sr=1 → old pinned LEFT, but real hits were 1L/1R and the
    -- correct side was RIGHT → Predicted-Alt 0/2.)
    local rl, rr = s.real_left or 0, s.real_right or 0
    if rl >= 1 and rr >= 1 then
        if rl >= rr + 2 then return -1 end
        if rr >= rl + 2 then return  1 end
        if (s.last_hit_side or 0) > 0 then return -1 end
        if (s.last_hit_side or 0) < 0 then return  1 end
        return 0
    end
    if sl >= sr + 2 then return -1 end
    if sr >= sl + 2 then return  1 end
    if (s.last_hit_side or 0) > 0 then return -1 end
    if (s.last_hit_side or 0) < 0 then return  1 end
    return 0
end

-- V9.77: STRONG learned-dominance side from REAL data only (real hits + streak),
-- never seeded/passive sample counts (those mispin — the v9.48 lesson). Returns
-- -1 (L), +1 (R), or 0 (no strong signal). Used to veto a wrong-side magnitude
-- BOOST: RebuildServerYaw gives an undershot but usually-right side, EXCEPT on a
-- hard one-sided enemy where it can flip — there the learned dom must win
-- (real-dump idx=5: streak L=20 R=0, real 5L/0R, rebuild said R → Networked-Boost
-- boosted 29° R twice → 0/2). Returns 0 for passive-only enemies (no real hits,
-- no streak) so the air-boost's never-hit-but-known case keeps the rebuild side.
function learned_dom_side(s)
    if not s then return 0 end
    local rl, rr = s.real_left or 0, s.real_right or 0
    if rl >= rr + 2 then return -1 end
    if rr >= rl + 2 then return  1 end
    local stl, str = s.hit_streak_left or 0, s.hit_streak_right or 0
    if stl >= str + 2 then return -1 end
    if str >= stl + 2 then return  1 end
    return 0
end

local log_copy_btn = g_logging:button("📋 Copy Last Logs (for share)", function()
    -- V8.2: intercept _cs_log_raw / _cs_log_color_raw so we collect dump to file too
    local _dump_lines = {}
    local _save_raw   = _cs_log_raw
    local _save_color = _cs_log_color_raw
    _cs_log_raw       = function(msg) table.insert(_dump_lines, tostring(msg)); _save_raw(msg)   end
    _cs_log_color_raw = function(msg) table.insert(_dump_lines, tostring(msg)); _save_color(msg) end
    _cs_log_color_raw("════ COPY-FRIENDLY LOG DUMP (drag-select all below) ════")
    _cs_log_color_raw("--- Sel01-Solver v" .. SEL01_VERSION .. " ---")
    -- preset snapshot
    pcall(function()
        _cs_log_raw(string.format("[CFG] Resolver=%s Mode=%s LBY=%s Air=%s Close=%du Baim-after=%d Baim-dmg=%d Baim-hb=%s",
            (resolver.enable:get() and "ON" or "OFF"), tostring(resolver_mode:get()),
            (lby_snap_toggle:get() and "ON" or "OFF"), (air_resolve_tog:get() and "ON" or "OFF"),
            close_range_dist:get(), force_baim_n:get(), baim_min_damage:get(), tostring(baim_hitbox:get())))
        _cs_log_raw(string.format("[V3] aim_fire=%s perside=%s ESP=%s cancel=%s autoWeap=%s",
            tostring(exp_aim_fire_snap:get()), tostring(exp_perside_desync:get()),
            tostring(exp_esp_overlay:get()), tostring(exp_cancel_conf:get()),
            tostring(exp_auto_weapon:get())))
        _cs_log_raw(string.format("[V4+] persist=%s extrap=%s respectSSG=%s predTicks=%d",
            tostring(exp_persistent_lm:get()), tostring(exp_extrapolation:get()),
            tostring(exp_respect_man:get()), exp_predict_ticks:get()))
        -- V8.8: additional config dump (head_strict, ESP toggles, smart strategy values)
        _cs_log_raw(string.format("[V7+] head_strict=%s nospread=%s aa_classify=%s classify_int=%d",
            tostring(exp_head_strict:get()),
            tostring(exp_nospread:get()), tostring(exp_aa_classify:get()), exp_classify_int:get()))
        _cs_log_raw(string.format("[ESP] master=%s labels=%s confbar=%s hud=%s pos=%s hz=%d",
            tostring(esp_master:get()), tostring(esp_show_labels:get()),
            tostring(esp_show_confbar:get()), tostring(esp_show_hud:get()),
            tostring(esp_hud_pos:get()), esp_throttle_hz:get()))
        _cs_log_raw(string.format("[SMART] learn=%s predict=%s visual=%s hitbox=%s",
            tostring(strat_learning:get()), tostring(strat_predict:get()),
            tostring(strat_visual:get()), tostring(strat_hitbox:get())))
    end)

    -- V7.5: LEARNING DIAGNOSTICS (key data for improvement suggestions)
    _cs_log_raw("--- LEARNING DIAGNOSTICS ---")
    local persistent_count, persistent_total_hits, persistent_total_samples = 0, 0, 0
    pcall(function()
        for _, e in pairs(LearnedModel) do
            persistent_count = persistent_count + 1
            persistent_total_hits = persistent_total_hits + (e.hits or 0)
            persistent_total_samples = persistent_total_samples + (e.sl or 0) + (e.sr or 0)
        end
    end)
    _cs_log_raw(string.format("[LEARN] Persistent: %d players saved, %d total hits, %d desync samples",
        persistent_count, persistent_total_hits, persistent_total_samples))
    -- in-memory stats
    local mem_players, mem_samples, mem_passive = 0, 0, 0
    local mem_locked, mem_known = 0, 0
    pcall(function()
        for _, s in pairs(PlayerState) do
            mem_players = mem_players + 1
            local total_s = (s.samples_left or 0) + (s.samples_right or 0)
            mem_samples = mem_samples + total_s
            mem_passive = mem_passive + (s.passive_samples or 0)
            if total_s >= 8 and confidence(s) >= 60 then mem_locked = mem_locked + 1 end
            if s.boot_best_modes then mem_known = mem_known + 1 end
        end
    end)
    _cs_log_raw(string.format("[LEARN] In-memory: %d tracked, %d active samples, %d passive obs, %d locked, %d known-from-persist",
        mem_players, mem_samples, mem_passive, mem_locked, mem_known))
    -- session trend
    local sess_total = (session_stats.total_hits or 0) + (session_stats.total_miss or 0)
    _cs_log_raw(string.format("[SESSION] %d hits / %d shots = %.1f%% overall | early %.0f%% → recent %.0f%% (trend %.0f%%)",
        session_stats.total_hits or 0, sess_total,
        sess_total > 0 and (session_stats.total_hits / sess_total * 100) or 0,
        session_stats.early_rate or 0, session_stats.recent_rate or 0,
        (session_stats.recent_rate or 0) - (session_stats.early_rate or 0)))
    -- V9.50: surface the V9.49 server-fail filter. These correct-angle misses the server
    -- rejected (stale backtrack record) are excluded from the hit-rate above — show how
    -- many were filtered so the headline % is trustworthy + the netcode load is visible.
    local sf = sel01_session_serverfails or 0
    if sf > 0 then
        local raw_shots = sess_total + sf
        _cs_log_raw(string.format("[SESSION] %d server-fails filtered (correct angle, server rejected) — raw %d/%d = %.1f%% before filter",
            sf, session_stats.total_hits or 0, raw_shots,
            raw_shots > 0 and (session_stats.total_hits / raw_shots * 100) or 0))
    end
    -- V9.72: same readout for spread-RNG misses (filtered from stats since v9.72)
    local spf = sel01_session_spreadfails or 0
    if spf > 0 then
        _cs_log_raw(string.format("[SESSION] %d spread misses filtered (bullet RNG, angle accepted)", spf))
    end

    -- mode hit-rates + AUTO-SUGGESTIONS
    _cs_log_raw("--- MODE HIT-RATES + SUGGESTIONS ---")
    local rows = mode_stats_dump()
    local worst_mode, worst_rate, worst_total = nil, 100, 0
    local best_mode, best_rate, best_total = nil, 0, 0
    for _, r in ipairs(rows) do
        _cs_log_raw(string.format("[STATS] %-25s %3d/%3d = %5.1f%%", r.mode, r.hits, r.total, r.rate))
        if r.total >= 5 then  -- only count modes with enough samples
            if r.rate < worst_rate then worst_rate, worst_mode, worst_total = r.rate, r.mode, r.total end
            if r.rate > best_rate then best_rate, best_mode, best_total = r.rate, r.mode, r.total end
        end
    end
    if best_mode then
        _cs_log_raw(string.format("[TIP] ✓ Best: %s (%.0f%%, %d shots) — preset tuning works here",
            best_mode, best_rate, best_total))
    end
    if worst_mode and worst_rate < 35 then
        _cs_log_raw(string.format("[TIP] ⚠ Weak: %s (%.0f%%, %d shots) — consider tuning/disabling",
            worst_mode, worst_rate, worst_total))
    end

    -- player snapshot
    _cs_log_raw("--- TRACKED PLAYERS ---")
    local pc = 0
    pcall(function()
        for idx, s in pairs(PlayerState) do
            -- V8.1: skip idx=0 + Init players (world/spec entities spam)
            if not (tonumber(idx) == 0 or (s.mode == "Init" and (s.samples_left or 0) + (s.samples_right or 0) == 0)) then
            pc = pc + 1
            -- V8.0: defensive tonumber + pcall around format (avoid userdata crash)
            local ok, line = pcall(string.format,
                "[P] idx=%d mode=%s aa=%s miss=%d L=%d/%.1f R=%d/%.1f pass=%d pL=%d pR=%d conf=%d boot=%s",
                tonumber(idx) or 0, tostring(s.mode), tostring(s.aa_type), tonumber(s.missed) or 0,
                tonumber(s.samples_left) or 0, tonumber(s.measured_left) or 0,
                tonumber(s.samples_right) or 0, tonumber(s.measured_right) or 0,
                tonumber(s.passive_samples) or 0,
                tonumber(s.passive_n_left) or 0, tonumber(s.passive_n_right) or 0,  -- V9.74: passive-side-keep visibility
                tonumber(confidence(s)) or 0,
                s.boot_best_modes and "yes" or "no")
            if ok then _cs_log_raw(line)
            else _cs_log_raw("[P] (format error idx=" .. tostring(idx) .. ")") end
            -- V8.8: extended per-player detail (slow/still flags, correction L/R, streak, yaw_rate, last_hit_side, dist, miss-rate)
            pcall(function()
                _cs_log_raw(string.format("    └ flags{slow=%s still=%s def=%s lby=%s} streak{L=%d R=%d} corr{L=%d R=%d} yaw_rate=%.1f last_hit=%d dist=%.0f miss_rate=%.0f%% p_hits=%d/%d",
                    tostring(s.is_slow_target), tostring(s.is_stationary or false),
                    tostring(s.defensive_aa), tostring(s.lby_snap),
                    tonumber(s.hit_streak_left) or 0, tonumber(s.hit_streak_right) or 0,
                    tonumber(s.correction_left) or 0, tonumber(s.correction_right) or 0,
                    tonumber(s.yaw_rate) or 0, tonumber(s.last_hit_side) or 0,
                    tonumber(s.tmp_dist) or 0, tonumber(s.recent_miss_rate) or 0,
                    tonumber(s.p_hits) or 0, tonumber(s.p_miss) or 0))
            end)
            end  -- end skip-idx-0 filter
        end
    end)
    if pc == 0 then _cs_log_raw("[P] (no tracked players)") end

    -- V8.8: top-5 learned players (most hits) from persistent model
    _cs_log_raw("--- TOP-5 LEARNED PLAYERS (persistent) ---")
    pcall(function()
        local list = {}
        for sid, e in pairs(LearnedModel) do
            table.insert(list, {sid=sid, e=e})
        end
        table.sort(list, function(a, b) return (a.e.hits or 0) > (b.e.hits or 0) end)
        for i = 1, math.min(5, #list) do
            local r = list[i]
            local e = r.e
            local total = (e.hits or 0) + (e.miss or 0)
            local rate = total > 0 and ((e.hits or 0) / total * 100) or 0
            _cs_log_raw(string.format("[L] %s hits=%d/%d (%.0f%%) L=%d/%.1f° R=%d/%.1f° dom=%d best{j=%s s=%s sw=%s}",
                tostring(r.sid):sub(1, 30),
                e.hits or 0, total, rate,
                e.sl or 0, e.dl or 0,
                e.sr or 0, e.dr or 0,
                e.dom or 0,
                tostring(e.best_jitter or ""), tostring(e.best_static or ""), tostring(e.best_switch or "")))
        end
        if #list == 0 then _cs_log_raw("[L] (no persistent entries — steam_id may be failing)") end
    end)

    -- recent log buffer (V9.3: ring-buffer iter, insertion-order)
    local _buf_list = log_buffer_iter()
    _cs_log_raw("--- RECENT EVENT LOG (last " .. #_buf_list .. " lines) ---")
    for _, line in ipairs(_buf_list) do _cs_log_raw(line) end

    -- improvement hints based on data
    _cs_log_raw("--- IMPROVEMENT HINTS ---")
    if persistent_count == 0 then
        _cs_log_raw("[HINT] LearnedModel empty — steam_id API may not work in your NL version (cross-match learning disabled)")
    elseif persistent_count < 5 then
        _cs_log_raw("[HINT] Only " .. persistent_count .. " players learned — play more matches for stronger cross-match data")
    end
    if mem_locked == 0 and mem_samples > 0 then
        _cs_log_raw("[HINT] No locked targets yet — need 8+ hits + 60+ confidence on same enemy")
    end
    if sess_total >= 10 and (session_stats.recent_rate or 0) < 40 then
        _cs_log_raw("[HINT] Recent hit-rate <40% — check if cancel-low-conf threshold too loose, or weapon-class mismatch")
    end
    if mem_passive == 0 and mem_players > 0 then
        _cs_log_raw("[HINT] Zero passive obs — anim.m_flGoalFeetYaw read may be failing (NL API diff)")
    end
    -- V9.74: per-player pattern hints
    pcall(function()
        for idx, s in pairs(PlayerState) do
            if not (tonumber(idx) == 0 or (s.mode == "Init" and (s.samples_left or 0) + (s.samples_right or 0) == 0)) then
                local mr = tonumber(s.recent_miss_rate) or 0  -- stored as percent (0-100)
                if s.defensive_aa == true and s.aa_type == "jitter" and mr >= 50 then
                    _cs_log_raw(string.format("[HINT] idx=%d jitter+defAA enemy — BF:def+ ineffective; BF:opposite expected to perform better", tonumber(idx) or 0))
                end
                local real_active = (s.real_left or 0) + (s.real_right or 0)
                local pn = (s.passive_n_left or 0) + (s.passive_n_right or 0)
                if (s.missed or 0) >= 2 and real_active == 0 and pn >= 30 then
                    _cs_log_raw(string.format("[HINT] idx=%d 0 real hits but %d passive obs — passive-side-keep may activate; fire more to build real samples", tonumber(idx) or 0, pn))
                end
            end
        end
    end)

    _cs_log_color_raw("════ END DUMP — drag-select from COPY-FRIENDLY LOG DUMP line ════")
    -- V8.2 + V8.7: write full dump to file + clipboard direct + restore originals
    local full_dump = table.concat(_dump_lines, "\n")
    pcall(function()
        files.create_folder("nl/Sel01-Solver/")
        files.write("nl/Sel01-Solver/last_logs.txt", full_dump)
    end)
    -- V8.7: copy directly to Windows clipboard (paste with Ctrl+V anywhere)
    local clip_ok, clip_err = set_clipboard(full_dump)
    _cs_log_raw       = _save_raw
    _cs_log_color_raw = _save_color
    if clip_ok then
        _save_color(string.format("✓ Copied to CLIPBOARD (%d bytes) — Ctrl+V to paste anywhere. Also saved → nl/Sel01-Solver/last_logs.txt",
            #full_dump))
    else
        _save_color("⚠ Clipboard FFI failed (" .. tostring(clip_err) .. ") — file fallback: nl/Sel01-Solver/last_logs.txt")
    end
end)

local log_debug_dump   = g_logging:button("Dump All Player States", function()
    _cs_log_color_raw("─── PLAYER STATE DUMP ───")
    local n = 0
    for idx, s in pairs(PlayerState) do
        -- V8.1: skip idx=0 + uninit entries
        if not (tonumber(idx) == 0 or (s.mode == "Init" and (s.samples_left or 0) + (s.samples_right or 0) == 0)) then
        n = n + 1
        -- V8.0: defensive tonumber coercion (some NL values can be userdata/cdata)
        local ok, line = pcall(string.format,
            "[%d] mode=%s missed=%d aa=%s desync_meas=%.1f° samples=%d L=%d R=%d def=%s lby_snap=%s",
            tonumber(idx) or 0, tostring(s.mode), tonumber(s.missed) or 0, tostring(s.aa_type),
            tonumber(s.measured_desync) or 0, tonumber(s.desync_samples) or 0,
            tonumber(s.hit_streak_left) or 0, tonumber(s.hit_streak_right) or 0,
            tostring(s.defensive_aa), tostring(s.lby_snap)
        )
        if ok then
            _cs_log_color_raw(line)
        else
            _cs_log_color_raw("[" .. tostring(idx) .. "] (format error: " .. tostring(line) .. ")")
        end
        end  -- end skip filter
    end
    if n == 0 then _cs_log_color_raw("(no tracked players)") end
    _cs_log_color_raw("─── END DUMP ───")
end)

-- V7.9: manual reset — wipe persistent learning model (file + memory)
local log_reset_learn  = g_logging:button("🗑 Reset Learning Data (persistent)", function()
    local count_before = 0
    for _ in pairs(LearnedModel) do count_before = count_before + 1 end
    -- wipe table
    for k in pairs(LearnedModel) do LearnedModel[k] = nil end
    -- wipe file (path hardcoded — LEARNING_FILE local declared later, would be nil in closure)
    pcall(function()
        files.create_folder("nl/Sel01-Solver/")
        files.write("nl/Sel01-Solver/learned.lua", "return {}")
    end)
    -- also wipe in-memory per-player boot data so next engagement re-learns fresh
    for _, s in pairs(PlayerState) do
        s.boot_best_modes  = nil
        s.measured_left    = 0
        s.measured_right   = 0
        s.samples_left     = 0
        s.samples_right    = 0
        s.measured_desync  = 0
        s.desync_samples   = 0
        s.passive_samples  = 0
        s.passive_left     = nil
        s.passive_right    = nil
        s.passive_n_left   = 0   -- V9.72
        s.passive_n_right  = 0   -- V9.72
        s.correction_left  = 0
        s.correction_right = 0
    end
    _cs_log_color_raw("🗑 Reset Learning Data — wiped " .. count_before .. " persistent entries + in-memory per-player desync data")
end)

-- V7.9: manual reset — wipe session stats + mode hit-rates + tracking
local log_reset_session = g_logging:button("🗑 Reset Session Stats (in-memory)", function()
    -- session stats
    session_stats.total_hits  = 0
    session_stats.total_miss  = 0
    session_stats.early_rate  = 0
    session_stats.recent_rate = 0
    for k in pairs(session_stats.history) do session_stats.history[k] = nil end
    sel01_session_serverfails = 0  -- V9.50: clear server-fail filter counter
    sel01_session_spreadfails = 0  -- V9.72: clear spread-RNG filter counter
    -- mode stats
    for k in pairs(mode_stats) do mode_stats[k] = nil end
    -- steam memory
    for k in pairs(SteamMemory) do SteamMemory[k] = nil end
    -- per-player runtime state (but keep LearnedModel persistent)
    for k in pairs(PlayerState) do PlayerState[k] = nil end
    -- log buffer
    -- V9.3: reset ring entries but keep meta (cap/head/count)
    for i = 1, log_buffer.cap do log_buffer[i] = nil end
    log_buffer.head = 0; log_buffer.count = 0
    _cs_log_color_raw("🗑 Reset Session Stats — cleared mode-stats, session-trend, tracked players, log-buffer")
end)

local log_clear_btn    = g_logging:button("Print Status", function()
    _cs_log_color_raw("─── status ───")
    _cs_log_color_raw("Resolver: " .. (resolver.enable:get() and "ON" or "OFF") ..
                      " | Mode: " .. tostring(resolver_mode:get()))
    _cs_log_color_raw("LBY-Snap: " .. (lby_snap_toggle:get() and "ON" or "OFF") ..
                      " | Air: " .. (air_resolve_tog:get() and "ON" or "OFF") ..
                      " | Close: " .. close_range_dist:get() .. "u")
    _cs_log_color_raw("Baim after: " .. force_baim_n:get() .. " misses" ..
                      " | Baim-dmg: " .. baim_min_damage:get() ..
                      " | Hitbox: " .. tostring(baim_hitbox:get()))
    local count = 0
    for _ in pairs(PlayerState) do count = count + 1 end
    _cs_log_color_raw("Tracked players: " .. count)
    _cs_log_color_raw("─── MODE HIT-RATES ───")
    local rows = mode_stats_dump()
    if #rows == 0 then
        _cs_log_color_raw("(no shots taken yet)")
    else
        for _, r in ipairs(rows) do
            _cs_log_color_raw(string.format("  %-25s %3d/%3d = %5.1f%%", r.mode, r.hits, r.total, r.rate))
        end
    end
end)

local MODE_NAMES = {"Adaptive", "Aggressive", "Defensive"}
local HITBOX_IDS = {3, 2, 6, 7}  -- stomach, pelvis, chest, legs (CSGO ids)
local HITBOX_MAP = {Stomach = 3, Pelvis = 2, Chest = 6, Legs = 7}
-- (forward-decls for SteamMemory/LearnedModel/mode_stats/NormalizeAngle/tick_cache
--  moved to TOP of file before UI creation — see V7.3 fix block above)
local AngleDifference, Approach  -- still need these forward (used in RebuildServerYaw)

-- ═══════════════════════════════════════════════════════
-- V5: PER-MODE HIT-RATE AUDIT
-- ═══════════════════════════════════════════════════════
-- mode_stats forward-declared at top, populate via mode_stats_update
-- (was: local mode_stats = {})
mode_stats_update = function(mode, hit)
    if not mode or mode == "" then return end
    -- V8.7: skip Init mode — fired before first resolve cycle, useless data (eye=0 resolved=0)
    if mode == "Init" then return end
    -- V8.9: normalize ALL suffixes (+Pred / -DefInv / -Recall chain) for proper grouping
    local base = mode:gsub("%+Pred", ""):gsub("%-DefInv", ""):gsub("%-Recall", "")
    local e = mode_stats[base]
    if not e then e = {hits = 0, miss = 0}; mode_stats[base] = e end
    if hit then e.hits = e.hits + 1 else e.miss = e.miss + 1 end
end
mode_stats_dump = function()
    local rows = {}
    for m, e in pairs(mode_stats) do
        local total = e.hits + e.miss
        local rate = total > 0 and (e.hits / total * 100) or 0
        table.insert(rows, {mode = m, hits = e.hits, miss = e.miss, total = total, rate = rate})
    end
    table.sort(rows, function(a, b) return a.total > b.total end)
    return rows
end

-- ═══════════════════════════════════════════════════════
-- V5: CONFIDENCE SCORE
-- ═══════════════════════════════════════════════════════
confidence = function(s)
    if not s then return 0 end
    -- factors: sample-count, std-dev of recent resolves, age
    -- V9.1: weight REAL hits (1.0) > seeded samples (0.3) > passive obs (0.3)
    local real_active = (s.real_left or 0) + (s.real_right or 0)
    local seeded = math.max(0, ((s.samples_left or 0) + (s.samples_right or 0)) - real_active)
    local passive = (s.passive_samples or 0) * 0.3 + seeded * 0.3
    local samples = real_active + passive
    local sample_score = math.min(samples * 8, 60)  -- max 60 from samples
    -- stddev penalty
    local n = #s.recent_resolved
    local sd_score = 30
    if n >= 3 then
        -- V9.31: circular spread vs a reference angle. A plain arithmetic mean of
        -- wrap-around yaws explodes near the ±180 seam (+179 & -179 are 2° apart
        -- but average to ~0 → fake ~180° stddev → confidence wrongly tanked, which
        -- silently suppresses extrapolation / fast-fire / lock-on for an enemy
        -- whose facing straddles the seam). Deviate from a reference via NormalizeAngle.
        local ref = s.recent_resolved[1].a
        local sumd = 0
        for _, r in ipairs(s.recent_resolved) do sumd = sumd + NormalizeAngle(r.a - ref) end
        local mean_off = sumd / n
        local sq = 0
        for _, r in ipairs(s.recent_resolved) do
            local d = NormalizeAngle(r.a - ref) - mean_off
            sq = sq + d * d
        end
        local sd = math.sqrt(sq / n)
        sd_score = math.max(0, 30 - sd)
    end
    -- dormancy penalty
    local age_pen = 0
    if s.last_seen and tick_cache.curtime then
        local age = tick_cache.curtime - s.last_seen
        if age > 0.2 then age_pen = math.min(age * 10, 30) end
    end
    -- V8.0: miss-rate penalty — high samples + recent misses = lower trust
    -- user feedback: confidence often high but resolver still misses → reality check
    local miss_pen = 0
    local n_recent = #(s.p_history or {})
    if n_recent >= 4 then
        local mr = s.recent_miss_rate or 0
        if mr >= 60 then miss_pen = 35      -- failing hard → big cap
        elseif mr >= 40 then miss_pen = 20  -- below 60% hit → moderate
        elseif mr >= 25 then miss_pen = 10  -- below 75% hit → small
        end
    end
    -- V9.9-A: DOMINANT-SIDE BOOST — when one side has >=3 more REAL hits than other,
    -- side-pick is clearly trustworthy → +15 conf bonus.
    local hit_l, hit_r = s.real_left or 0, s.real_right or 0
    local dom_bonus = 0
    if math.abs(hit_l - hit_r) >= 3 then dom_bonus = 15 end
    -- V9.9-F: SYMMETRIC-DATA LOW-CONF — when L and R have similar magnitudes (<5° diff)
    -- AND small sample count (each side <=2), the true side is genuinely unknown. Drop -20.
    local sym_pen = 0
    if (s.samples_left or 0) >= 1 and (s.samples_right or 0) >= 1
       and (s.samples_left or 0) <= 2 and (s.samples_right or 0) <= 2 then
        local ml, mr = s.measured_left or 0, s.measured_right or 0
        if math.abs(ml - mr) < 5 then sym_pen = 20 end
    end
    local raw = sample_score + sd_score - age_pen - miss_pen + 10 + dom_bonus - sym_pen
    -- additionally clamp ceiling to 65 if recent_miss_rate >= 50
    if n_recent >= 4 and (s.recent_miss_rate or 0) >= 50 then
        if raw > 50 then raw = 50 end
    end
    -- V9.1: caps based on REAL hits (not seeded samples)
    if real_active == 0 and raw > 50 then raw = 50 end   -- never shot at = max 50
    if real_active == 1 and raw > 70 then raw = 70 end   -- 1 hit only = max 70
    if real_active == 2 and raw > 85 then raw = 85 end   -- 2 hits = max 85
    -- 3+ real hits → full 100 possible
    return math.floor(math.max(0, math.min(100, raw)))
end

-- ═══════════════════════════════════════════════════════
-- V4: PERSISTENT SELF-LEARNING MODEL
-- ═══════════════════════════════════════════════════════
local LEARNING_FILE = "nl/Sel01-Solver/learned.lua"
-- LearnedModel forward-declared at top (line 366)
-- (was: local LearnedModel = {})
local learning_dirty = false

local function _ser_value(v)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" then return tostring(v) end
    if t == "boolean" then return tostring(v) end
    return "nil"
end

local function serialize_model(t)
    local parts = {"return {"}
    for k, v in pairs(t) do
        if type(v) == "table" then
            table.insert(parts, string.format("[%q]={", tostring(k)))
            for k2, v2 in pairs(v) do
                table.insert(parts, string.format("[%q]=%s,", tostring(k2), _ser_value(v2)))
            end
            table.insert(parts, "},")
        end
    end
    table.insert(parts, "}")
    return table.concat(parts)
end

-- ═══════════════════════════════════════════════════════
-- V8.3: JSON encoder (sandbox-safe, no external lib)
-- ═══════════════════════════════════════════════════════
local function json_escape(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return s
end

local json_encode
json_encode = function(v, indent)
    indent = indent or ""
    local t = type(v)
    if v == nil then return "null" end
    if t == "string" then return '"' .. json_escape(v) .. '"' end
    if t == "number" then
        if v ~= v then return "null" end             -- NaN guard
        if v == math.huge or v == -math.huge then return "null" end
        return tostring(v)
    end
    if t == "boolean" then return v and "true" or "false" end
    if t == "table" then
        -- decide array vs object: integer 1..n keys = array
        local is_array, n = true, 0
        for k in pairs(v) do
            n = n + 1
            if type(k) ~= "number" or k % 1 ~= 0 or k < 1 then is_array = false end
        end
        if is_array and n > 0 then
            local arr = {}
            for i = 1, n do table.insert(arr, json_encode(v[i], indent .. "  ")) end
            return "[" .. table.concat(arr, ",") .. "]"
        else
            local kv, sub = {}, indent .. "  "
            for k, val in pairs(v) do
                table.insert(kv, "\n" .. sub .. '"' .. json_escape(k) .. '": ' .. json_encode(val, sub))
            end
            if #kv == 0 then return "{}" end
            return "{" .. table.concat(kv, ",") .. "\n" .. indent .. "}"
        end
    end
    return "null"
end

local JSON_FILE = "nl/Sel01-Solver/learned.json"

local function build_json_dump()
    -- snapshot what is worth saving (skip ephemeral runtime state)
    local players_json = {}
    for sid, e in pairs(LearnedModel) do
        players_json[tostring(sid)] = {
            hits          = e.hits or 0,
            miss          = e.miss or 0,
            samples_left  = e.sl or 0,
            samples_right = e.sr or 0,
            desync_left   = e.dl or 0,
            desync_right  = e.dr or 0,
            dominant_side = e.dom or 0,
            last_seen     = e.last_seen or 0,
            best_static   = e.best_static or "",
            best_jitter   = e.best_jitter or "",
            best_switch   = e.best_switch or "",
            best_spinner  = e.best_spinner or "",
        }
    end
    local mode_rows = {}
    for m, e in pairs(mode_stats) do
        local total = e.hits + e.miss
        mode_rows[m] = {
            hits  = e.hits,
            miss  = e.miss,
            total = total,
            rate  = total > 0 and (e.hits / total * 100) or 0,
        }
    end
    return {
        version       = SEL01_VERSION,
        exported_at   = globals.realtime or 0,
        learned_count = (function() local n=0 for _ in pairs(LearnedModel) do n=n+1 end return n end)(),
        session_stats = {
            total_hits  = session_stats.total_hits or 0,
            total_miss  = session_stats.total_miss or 0,
            early_rate  = session_stats.early_rate or 0,
            recent_rate = session_stats.recent_rate or 0,
        },
        mode_stats    = mode_rows,
        learned       = players_json,
    }
end

local function learning_export_json()
    local ok, txt = pcall(function() return json_encode(build_json_dump()) end)
    if not ok or not txt then return false, txt end
    local wr_ok = pcall(function()
        files.create_folder("nl/Sel01-Solver/")
        files.write(JSON_FILE, txt)
    end)
    return wr_ok, txt
end

-- V8.3: manual JSON export button (placed here because closure needs learning_export_json defined)
local log_export_json = g_logging:button("💾 Export Learning → JSON", function()
    -- V9.63: ALSO write learned.lua here. learning_load() ONLY reads learned.lua —
    -- learned.json is a human/backup file that is NEVER loaded back. Users hit Export
    -- expecting it to be the save, restarted, and saw "nothing loaded" because the
    -- loadable file was never refreshed by this button. serialize_model + LEARNING_FILE
    -- are both defined above; write the loadable copy too so Export == persist.
    pcall(function()
        files.create_folder("nl/Sel01-Solver/")
        files.write(LEARNING_FILE, serialize_model(LearnedModel))
    end)
    local ok, payload = learning_export_json()
    if ok then
        local count = 0
        for _ in pairs(LearnedModel) do count = count + 1 end
        _cs_log_color_raw(string.format("💾 Exported %d players → learned.lua (loadable) + %s (%d bytes)",
            count, JSON_FILE, payload and #payload or 0))
    else
        _cs_log_color_raw("⚠ JSON export failed: " .. tostring(payload))
    end
end)

local function learning_load()
    pcall(function()
        local content = files.read(LEARNING_FILE)
        if not content or #content < 5 then return end
        local chunk = loadstring(content)
        if not chunk then return end
        local ok, data = pcall(chunk)
        if ok and type(data) == "table" then
            LearnedModel = data
            -- V8.9 + V9.0: migrate corrupted best_* fields (-Recall chain, BF: fallbacks, *-Guess)
            local migrated = 0
            for _, e in pairs(LearnedModel) do
                for _, k in ipairs({"best_static", "best_jitter", "best_switch", "best_spinner"}) do
                    local v = e[k]
                    if type(v) == "string" then
                        if v:find("%-Recall") then v = v:gsub("%-Recall", ""); migrated = migrated + 1 end
                        -- V9.0: drop unreliable fallback modes stored as "best"
                        -- V9.60: also drop positional "Air*" (see save-filter rationale)
                        if v:find("^BF:") or v:find("%-Guess$") or v:find("^Air") then
                            v = ""
                            migrated = migrated + 1
                        end
                        e[k] = v
                    end
                end
            end
            if migrated > 0 then
                learning_dirty = true
                _cs_log_color_raw("✓ Migrated " .. migrated .. " corrupted best-mode fields")
            end
            local count = 0
            for _ in pairs(LearnedModel) do count = count + 1 end
            _cs_log_color_raw("✓ Loaded persistent model: " .. count .. " players")
        end
    end)
end

local function learning_save()
    if not learning_dirty then return end
    pcall(function()
        files.create_folder("nl/Sel01-Solver/")
        files.write(LEARNING_FILE, serialize_model(LearnedModel))
        learning_dirty = false
    end)
end

local _sid_fail_logged = false
local function _learning_sid(p)
    if not (exp_persistent_lm and exp_persistent_lm:get()) then return nil end
    if not p then return nil end
    local sid
    -- V7.7: expanded fallback chain (6 patterns)
    pcall(function() sid = p:get_steam_id() end)
    if not sid or sid == "" then pcall(function() sid = p:get_steamid() end) end
    if not sid or sid == "" then pcall(function() sid = p.m_steamid end) end
    if not sid or sid == "" then pcall(function() sid = entity.get_steam_id(p) end) end
    -- account ID netvar (often present)
    if not sid or sid == "" then pcall(function()
        local aid = p.m_iAccountID or p:get_account_id()
        if aid and aid ~= 0 then sid = "acc_" .. tostring(aid) end
    end) end
    -- name-hash fallback (last resort, works per-name)
    if not sid or sid == "" then pcall(function()
        local name = p:get_name()
        if name and name ~= "" then
            local hash = 0
            for i = 1, #name do hash = (hash * 31 + string.byte(name, i)) % 2147483647 end
            sid = "name_" .. tostring(hash) .. "_" .. tostring(#name)
        end
    end) end
    -- userid+name combo (per-session)
    if not sid or sid == "" then
        local uid, name
        pcall(function() uid = p:get_user_id() end)
        pcall(function() name = p:get_name() end)
        if uid and name then sid = "uid_" .. tostring(uid) .. "_" .. tostring(name) end
    end
    if not sid or sid == "" then
        if not _sid_fail_logged then
            cs_log_color("⚠ Learning: ALL 6 NL API patterns failed — learning disabled")
            _sid_fail_logged = true
        end
        return nil
    end
    return tostring(sid)
end

local learning_cleanup  -- forward-decl, defined below
local function learning_update_hit(p, side, desync_value, aa_type, mode)
    local sid = _learning_sid(p); if not sid then return end
    local e = LearnedModel[sid]
    if not e then
        e = {dl=0, dr=0, sl=0, sr=0, dom=0, hits=0, miss=0, last_seen=0,
             best_jitter="", best_static="", best_switch="", best_spinner=""}
        LearnedModel[sid] = e
    end
    local alpha = 0.20
    if side > 0 then
        e.dr = e.sr == 0 and desync_value or (e.dr * (1 - alpha) + desync_value * alpha)
        e.sr = math.min(e.sr + 1, 999)
    elseif side < 0 then
        e.dl = e.sl == 0 and desync_value or (e.dl * (1 - alpha) + desync_value * alpha)
        e.sl = math.min(e.sl + 1, 999)
    end
    e.hits = (e.hits or 0) + 1
    e.last_seen = globals.realtime or 0
    if e.sr > e.sl + 3 then e.dom = 1
    elseif e.sl > e.sr + 3 then e.dom = -1 end
    -- V6 + V8.9 + V9.0: per-aa-type best-mode tracking
    -- V9.0: filter unreliable "fallback" modes (BF:, *-Guess) — they're emergency paths not stable best-modes
    if aa_type and mode then
        local clean = tostring(mode):gsub("%+Pred", ""):gsub("%-DefInv", ""):gsub("%-Recall", "")
        -- V9.0: don't save brute-force or guess modes as "best" — they're fallbacks, not patterns
        -- V9.60: also filter "Air*" — Air/Air-Alt/Air-CorrFlip are POSITIONAL (enemy airborne),
        -- not an AA-pattern. Stored as best_static/best_switch it never triggers the fast-path
        -- (3400 only acts on Static/Jitter) but DOES break intel.mode_match on grounded resolves
        -- (4435) → false mismatch → +15 conf cancel threshold → good shots cancelled. Pure liability.
        local is_fallback = clean:find("^BF:") or clean:find("%-Guess$") or clean:find("^Air") or clean == "Init"
        if not is_fallback then
            local key = "best_" .. tostring(aa_type)
            e[key] = clean
        end
    end
    learning_dirty = true
    -- V8.6: save EVERY hit (was every 10th) — crash/quick-unload now preserves data
    learning_save()
    -- V6: periodic cleanup (every 50 total hits across model)
    local total_hits = 0
    for _, x in pairs(LearnedModel) do total_hits = total_hits + (x.hits or 0) end
    if total_hits > 0 and total_hits % 50 == 0 then pcall(learning_cleanup) end
end

-- V6: cleanup old entries (called on load + every 50 hits across all players)
learning_cleanup = function(max_age_seconds, max_entries)
    max_age_seconds = max_age_seconds or (7 * 24 * 3600)  -- 7 days
    max_entries = max_entries or 200
    local now = globals.realtime or 0
    local kept, removed = 0, 0
    -- pass 1: drop too-old
    for sid, e in pairs(LearnedModel) do
        if e.last_seen and (now - e.last_seen) > max_age_seconds then
            LearnedModel[sid] = nil
            removed = removed + 1
        else
            kept = kept + 1
        end
    end
    -- pass 2: if still too many, drop oldest
    if kept > max_entries then
        local list = {}
        for sid, e in pairs(LearnedModel) do
            table.insert(list, {sid=sid, last=e.last_seen or 0})
        end
        table.sort(list, function(a, b) return a.last < b.last end)
        local to_drop = kept - max_entries
        for i = 1, to_drop do
            LearnedModel[list[i].sid] = nil
            removed = removed + 1
        end
    end
    if removed > 0 then
        cs_log_color("Learning cleanup: removed " .. removed .. " stale entries")
        learning_dirty = true
        learning_save()
    end
end

local function learning_update_miss(p)
    local sid = _learning_sid(p); if not sid then return end
    local e = LearnedModel[sid]
    if e then
        e.miss = (e.miss or 0) + 1
        learning_dirty = true
    end
end

local function learning_lookup(p)
    local sid = _learning_sid(p); if not sid then return nil end
    return LearnedModel[sid]
end

-- ═══════════════════════════════════════════════════════
-- V4: PREDICTION / EXTRAPOLATION
-- ═══════════════════════════════════════════════════════
-- V9.66 #5: predict_yaw_ahead (inlined into the unified predictor) + predict_position
-- (never called) removed — both dead, frees 2 main-chunk locals near the 200 cap.
-- PlayerState forward-decl now at top of file (V7.3 fix)

-- forward-declared (defined later, called from aim_ack handler)
local get_steam_mem, steam_mem_on_hit, steam_mem_on_miss

-- combo:get() returns string in neverlose, normalize to safe helpers
local function combo_str(combo, fallback)
    local ok, v = pcall(function() return combo:get() end)
    if not ok or v == nil then return fallback end
    return tostring(v)
end
local function mode_str()  return combo_str(resolver_mode, "Adaptive") end
local function baim_hb_id() return HITBOX_MAP[combo_str(baim_hitbox, "Stomach")] or 3 end

-- ─── PRESETS ───────────────────────────────────────────
local function safe_set(ctrl, val)
    if not ctrl then return end
    pcall(function() ctrl:set(val) end)
end

local function apply_preset(name)
    -- v9.59: every preset forces HUD position Top-Left (user default)
    safe_set(esp_hud_pos, "Top-Left")
    if name == "aggressive" then
        safe_set(resolver.enable,    true)
        safe_set(resolver_mode,      "Aggressive")
        safe_set(lby_snap_toggle,    true)
        safe_set(air_resolve_tog,    true)
        safe_set(close_range_dist,   1200)
        safe_set(dormancy_reset_t,   400)
        safe_set(force_baim_n,       3)            -- baim after 3 misses (not 0 = chest fallback)
        safe_set(baim_min_damage,    35)
        safe_set(baim_hitbox,        "Chest")      -- chest > stomach for trade-fights
        safe_set(exp_aa_classify,    true)
        safe_set(exp_multipoint,     true)
        safe_set(exp_def_aa,         true)
        safe_set(exp_steam_mem,      true)         -- learn over match for repeated engagements
        safe_set(exp_nospread,       false)
        safe_set(exp_classify_int,   6)
        safe_set(exp_aim_fire_snap,  true)
        safe_set(exp_perside_desync, true)
        safe_set(exp_esp_overlay,    false)
        safe_set(exp_cancel_conf,    false)
        safe_set(exp_auto_weapon,    false)
        safe_set(exp_persistent_lm,  true)
        safe_set(exp_extrapolation,  true)
        safe_set(exp_respect_man,    false)
        safe_set(exp_predict_ticks,  2)
        safe_set(exp_head_strict,    false)
        safe_set(strat_learning,     "Adaptive (Recommended)")
        safe_set(strat_predict,      "Normal")
        safe_set(strat_visual,       "Standard (ESP + HUD)")
        safe_set(strat_hitbox,       "Head Bias")
        -- V9.67: new levers — pose-collect (data, harmless), on-shot flip (aggressive)
        safe_set(pose_cal_tog,       true)
        safe_set(pose_use_tog,       false)
        safe_set(onshot_flip_tog,    true)
        safe_set(switch_pred_tog,    false)
        _cs_log_color_raw("✓ PRESET: AGGRESSIVE — Head-bias (hc=40 mindmg=25), chest-baim after 3 misses, all V4 ON")
    elseif name == "defensive" then
        safe_set(resolver.enable,    true)
        safe_set(resolver_mode,      "Defensive")
        safe_set(lby_snap_toggle,    true)
        safe_set(air_resolve_tog,    true)
        safe_set(close_range_dist,   600)
        safe_set(dormancy_reset_t,   1500)
        safe_set(force_baim_n,       4)
        safe_set(baim_min_damage,    80)
        safe_set(baim_hitbox,        "Chest")
        safe_set(exp_aa_classify,    true)
        safe_set(exp_multipoint,     false)
        safe_set(exp_def_aa,         false)
        safe_set(exp_steam_mem,      true)
        safe_set(exp_nospread,       false)
        safe_set(exp_classify_int,   12)
        safe_set(exp_aim_fire_snap,  true)
        safe_set(exp_perside_desync, true)
        safe_set(exp_esp_overlay,    false)
        safe_set(exp_cancel_conf,    true)         -- defensive = wait for confidence
        safe_set(exp_auto_weapon,    false)
        safe_set(exp_persistent_lm,  true)
        safe_set(exp_extrapolation,  false)        -- defensive = trust current state
        safe_set(exp_respect_man,    true)
        safe_set(exp_predict_ticks,  1)
        safe_set(exp_head_strict,    false)
        safe_set(strat_learning,     "Smart")
        safe_set(strat_predict,      "Off")
        safe_set(strat_visual,       "None")
        safe_set(strat_hitbox,       "NL Default (manual)")
        -- V9.67: defensive = aim stays safe — collect pose data only, no aim-changing levers
        safe_set(pose_cal_tog,       true)
        safe_set(pose_use_tog,       false)
        safe_set(onshot_flip_tog,    false)
        safe_set(switch_pred_tog,    false)
        _cs_log_color_raw("✓ PRESET: DEFENSIVE — Safe-point, baim after 4 misses, cancel-low-confidence ON")
    elseif name == "dynamic" then
        safe_set(resolver.enable,    true)
        safe_set(resolver_mode,      "Adaptive")
        safe_set(lby_snap_toggle,    true)
        safe_set(air_resolve_tog,    true)
        safe_set(close_range_dist,   800)
        safe_set(dormancy_reset_t,   700)
        safe_set(force_baim_n,       2)
        safe_set(baim_min_damage,    40)
        safe_set(baim_hitbox,        "Pelvis")
        safe_set(exp_aa_classify,    true)
        safe_set(exp_multipoint,     true)
        safe_set(exp_def_aa,         true)
        safe_set(exp_steam_mem,      false)
        safe_set(exp_nospread,       false)
        safe_set(exp_classify_int,   8)
        safe_set(exp_aim_fire_snap,  true)
        safe_set(exp_perside_desync, true)
        safe_set(exp_esp_overlay,    false)
        safe_set(exp_cancel_conf,    true)
        safe_set(exp_auto_weapon,    true)         -- dynamic = auto-switch per weapon
        safe_set(exp_persistent_lm,  true)
        safe_set(exp_extrapolation,  true)
        safe_set(exp_respect_man,    true)
        safe_set(exp_predict_ticks,  2)
        safe_set(exp_head_strict,    false)
        safe_set(strat_learning,     "Smart")
        safe_set(strat_predict,      "Normal")
        safe_set(strat_visual,       "Standard (ESP + HUD)")
        safe_set(strat_hitbox,       "Head + Chest Fallback")
        -- V9.67: dynamic = the experimental showcase — all learning levers incl switch-period
        safe_set(pose_cal_tog,       true)
        safe_set(pose_use_tog,       false)
        safe_set(onshot_flip_tog,    true)
        safe_set(switch_pred_tog,    true)
        _cs_log_color_raw("✓ PRESET: DYNAMIC — Adaptive, balanced, auto-per-weapon, all V4 ON")
    elseif name == "nospread" then
        safe_set(resolver.enable,    true)
        safe_set(resolver_mode,      "Aggressive")
        safe_set(lby_snap_toggle,    true)
        safe_set(air_resolve_tog,    true)
        safe_set(close_range_dist,   1500)        -- max range, nospread = unlimited
        safe_set(dormancy_reset_t,   300)
        safe_set(force_baim_n,       0)           -- NEVER baim, always head
        safe_set(baim_min_damage,    100)
        safe_set(baim_hitbox,        "Stomach")
        safe_set(exp_aa_classify,    true)
        safe_set(exp_multipoint,     false)       -- multipoint useless w/o spread
        safe_set(exp_def_aa,         true)
        safe_set(exp_steam_mem,      true)        -- learn enemy patterns over match
        safe_set(exp_nospread,       true)
        safe_set(exp_classify_int,   4)           -- fast re-classify
        safe_set(exp_aim_fire_snap,  true)
        safe_set(exp_perside_desync, true)
        safe_set(exp_esp_overlay,    false)
        safe_set(exp_cancel_conf,    true)         -- nospread = single shot precision
        safe_set(exp_auto_weapon,    false)
        safe_set(exp_persistent_lm,  true)
        safe_set(exp_extrapolation,  true)
        safe_set(exp_respect_man,    false)
        safe_set(exp_predict_ticks,  3)            -- nospread = aggressive predict
        safe_set(exp_head_strict,    false)
        safe_set(strat_learning,     "Adaptive (Recommended)")
        safe_set(strat_predict,      "Aggressive")
        safe_set(strat_visual,       "Minimal (HUD only)")
        safe_set(strat_hitbox,       "NoSpread (head always)")
        -- V9.67: nospread is aggressive — collect pose + on-shot flip (side still matters)
        safe_set(pose_cal_tog,       true)
        safe_set(pose_use_tog,       false)
        safe_set(onshot_flip_tog,    true)
        safe_set(switch_pred_tog,    false)
        _cs_log_color_raw("✓ PRESET: NOSPREAD — head-only forever, hitchance 1%%, min-dmg 100, multipoint OFF")
        _cs_log_color_raw("  Aktiviere im NL-menu: Hitchance 1, Min-Damage 100, Disable safepoint")
    elseif name == "ssg_pro" then
        -- V9.4: Tuned for user's NL SSG config (hc=72, dmg=100, multi-hitbox Head+Chest+Stomach,
        -- auto-stop+auto-scope ON, safe-points "Prefer", penetrate walls ON)
        safe_set(resolver.enable,    true)
        safe_set(resolver_mode,      "Aggressive")
        safe_set(lby_snap_toggle,    true)
        safe_set(air_resolve_tog,    true)
        safe_set(close_range_dist,   800)         -- V9.4: auto-stop handles close engagements
        safe_set(dormancy_reset_t,   300)         -- V9.4: balance between peek-snap + re-classify
        safe_set(force_baim_n,       5)           -- V9.4: SSG rarely needs body — let 4 misses fly
        safe_set(baim_min_damage,    80)          -- V9.4: if forced baim, accept body shot (was 100)
        safe_set(baim_hitbox,        "Chest")
        safe_set(exp_aa_classify,    true)
        safe_set(exp_multipoint,     true)        -- NL Head/Chest/Stomach multipoint stays active
        safe_set(exp_def_aa,         true)
        safe_set(exp_steam_mem,      true)
        safe_set(exp_nospread,       false)
        safe_set(exp_classify_int,   6)
        safe_set(exp_aim_fire_snap,  true)
        safe_set(exp_perside_desync, true)
        safe_set(exp_esp_overlay,    true)
        safe_set(exp_cancel_conf,    true)         -- precision — wait for stable resolve
        safe_set(exp_auto_weapon,    true)
        safe_set(exp_persistent_lm,  true)
        safe_set(exp_extrapolation,  true)
        safe_set(exp_respect_man,    true)         -- preserve hc=72 dmg=100 multi-hitbox + safe-points
        safe_set(exp_predict_ticks,  3)
        safe_set(exp_head_strict,    false)        -- still false; head_focus is enough, strict locks user out
        -- V9.4: smart strategy synced
        safe_set(strat_learning,     "Adaptive (Recommended)")
        safe_set(strat_predict,      "Aggressive")
        safe_set(strat_visual,       "Full (everything)")
        safe_set(strat_hitbox,       "NL Default (manual)")
        safe_set(esp_master,         true)
        safe_set(esp_show_labels,    true)
        safe_set(esp_show_confbar,   true)
        safe_set(esp_show_hud,       true)
        safe_set(esp_wedge,          true)   -- V9.51: SSG-Pro shows the full on-model visual suite
        safe_set(esp_flash,          true)
        safe_set(esp_enh,            true)
        -- V9.67 BALANCED: pose-collect ON (auto-calibrates the body_yaw index in the
        -- background — pure observation, zero aim change) + on-shot flip ON (well-gated,
        -- common in HvH). pose-USE + switch-period stay OFF until validated — flip them
        -- on yourself after 'Dump Pose Calibration' shows a clean >85% index. The toggle-
        -- less v9.65 perf, v9.66 prediction rework + v9.67 speed-bucket are already active.
        safe_set(pose_cal_tog,       true)
        safe_set(pose_use_tog,       false)
        safe_set(onshot_flip_tog,    true)
        safe_set(switch_pred_tog,    false)
        _cs_log_color_raw("✓ PRESET: SSG-PRO v9.67 — hc=72/dmg=100/multi-hitbox + HEAD-FOCUS, now with v9.65-67")
        _cs_log_color_raw("  Preserves: hitchance, min-damage, safe-points 'Prefer'")
        _cs_log_color_raw("  v9.65-67: cached server-yaw (perf), unified+decel-damped prediction, speed-bucket desync")
        _cs_log_color_raw("  Levers: pose-collect ON (auto-calibrate) + on-shot flip ON; pose-USE/switch OFF until you validate the dump")
    elseif name == "head_only" then
        -- V7.9: Headshot-Only on normal (spread) servers — head every shot, reasonable hc
        safe_set(resolver.enable,    true)
        safe_set(resolver_mode,      "Aggressive")
        safe_set(lby_snap_toggle,    true)
        safe_set(air_resolve_tog,    true)
        safe_set(close_range_dist,   1200)
        safe_set(dormancy_reset_t,   400)
        safe_set(force_baim_n,       0)           -- NEVER baim, head ONLY
        safe_set(baim_min_damage,    30)
        safe_set(baim_hitbox,        "Chest")
        safe_set(exp_aa_classify,    true)
        safe_set(exp_multipoint,     false)       -- head only = no multipoint scan
        safe_set(exp_def_aa,         true)
        safe_set(exp_steam_mem,      true)
        safe_set(exp_nospread,       false)       -- normal spread server (NOT nospread)
        safe_set(exp_classify_int,   6)
        safe_set(exp_aim_fire_snap,  true)
        safe_set(exp_perside_desync, true)
        safe_set(exp_esp_overlay,    false)
        safe_set(exp_cancel_conf,    true)        -- head shots = precision needed
        safe_set(exp_auto_weapon,    false)
        safe_set(exp_persistent_lm,  true)
        safe_set(exp_extrapolation,  true)
        safe_set(exp_respect_man,    false)
        safe_set(exp_predict_ticks,  2)
        safe_set(strat_learning,     "Adaptive (Recommended)")
        safe_set(strat_predict,      "Normal")
        safe_set(strat_visual,       "Standard (ESP + HUD)")
        safe_set(strat_hitbox,       "Head Only")
        safe_set(exp_head_strict,    true)        -- V7.9: every shot head
        -- V9.67: precision spread — collect pose + on-shot flip (correct side = the head)
        safe_set(pose_cal_tog,       true)
        safe_set(pose_use_tog,       false)
        safe_set(onshot_flip_tog,    true)
        safe_set(switch_pred_tog,    false)
        _cs_log_color_raw("✓ PRESET: HEADSHOT-ONLY (Spread) — head-only forever, normal server spread, no baim, no chest fallback")
        _cs_log_color_raw("  Recommended NL settings: Hitchance 40-50, Min-Damage 25-40, Safepoint OFF, Multipoint OFF")
    end
end
apply_preset_fwd = apply_preset

-- gate cs_log behind the toggle (raw refs already captured at top)
cs_log = function(msg)
    if log_enabled and log_enabled:get() then _cs_log_raw(msg) end
end
cs_log_color = function(msg)
    if log_enabled and log_enabled:get() then _cs_log_color_raw(msg) end
end
local function cs_log_verbose(fmt, ...)
    -- V8.8: build msg unconditionally for log_buffer, only print if toggle on
    local msg
    if select('#', ...) == 0 then msg = tostring(fmt)
    else
        local ok, m = pcall(string.format, fmt, ...)
        msg = ok and m or tostring(fmt)
    end
    -- V8.8: push key events to log_buffer regardless of verbose toggle
    if msg:find("correction%-miss") or msg:find("FLIP") or msg:find("aa_type commit") or
       msg:find("jump%-shot") or msg:find("jump%-scout") or msg:find("LearnedModel boot") or
       msg:find("cancel%-conf TRUST") or msg:find("close%-priority") or msg:find("HEAD") or
       msg:find("air%-block") or msg:find("DEF%-AA detected") or msg:find("force baim") then
        log_buffer_push("[v] " .. msg)
    end
    if not (log_enabled and log_enabled:get() and log_verbose and log_verbose:get()) then return end
    _cs_log_raw("[v] " .. msg)
end

-- DEBUG MODE: full per-resolve / per-shot dump
local function cs_log_debug(fmt, ...)
    -- V7.1: ALWAYS push HIT-FULL / MISS-FULL / UNKNOWN to log_buffer (even if debug toggle off)
    -- so Copy-Logs button has useful history regardless of debug-mode state
    local final_msg
    if select('#', ...) == 0 then final_msg = "[DBG] " .. tostring(fmt)
    else
        local ok, msg = pcall(string.format, fmt, ...)
        final_msg = "[DBG] " .. (ok and msg or tostring(fmt))
    end
    -- V8.8: buffer expanded event types for better diagnostics
    if final_msg:find("HIT%-FULL") or final_msg:find("MISS%-FULL") or final_msg:find("UNKNOWN") or
       final_msg:find("close%-priority") or final_msg:find("cancel%-conf") or final_msg:find("snapshot match") or
       final_msg:find("aa_type commit") or final_msg:find("correction%-miss") or final_msg:find("FLIP") or
       final_msg:find("jump%-shot") or final_msg:find("jump%-scout") or final_msg:find("HEAD%-STRICT") or
       final_msg:find("air%-block") or final_msg:find("shot%-cooldown") or final_msg:find("LearnedModel boot") then
        log_buffer_push(final_msg)
    end
    -- console output only if debug toggle on
    if not (log_enabled and log_enabled:get() and log_debug and log_debug:get()) then return end
    _cs_log_raw(final_msg)
end
local function is_debug() return log_enabled and log_enabled:get() and log_debug and log_debug:get() end

pcall(function()
    resolver.enable:set_callback(function(r)
        cs_log("Resolver " .. (r:get() and "ENABLED" or "disabled"))
    end)
    resolver_mode:set_callback(function(r)
        cs_log("Resolver mode → " .. tostring(r:get()))
    end)
    lby_snap_toggle:set_callback(function(r)
        cs_log("LBY Snap " .. (r:get() and "ON" or "OFF"))
    end)
    air_resolve_tog:set_callback(function(r)
        cs_log("Air Resolve " .. (r:get() and "ON" or "OFF"))
    end)
    force_baim_n:set_callback(function(r)
        cs_log("Force Baim after " .. r:get() .. " misses")
    end)
    baim_hitbox:set_callback(function(r)
        cs_log("Baim hitbox → " .. tostring(r:get()))
    end)
    log_enabled:set_callback(function(r)
        _cs_log_raw("Logging " .. (r:get() and "ENABLED" or "disabled"))
    end)
    log_debug:set_callback(function(r)
        _cs_log_color_raw("DEBUG MODE " .. (r:get() and "ON — sammelt full per-resolve + per-shot dumps" or "OFF"))
    end)
    exp_aa_classify:set_callback(function(r) cs_log("AA-Classify "  .. (r:get() and "ON" or "OFF")) end)
    exp_multipoint:set_callback (function(r) cs_log("Multipoint "   .. (r:get() and "ON" or "OFF")) end)
    exp_def_aa:set_callback     (function(r) cs_log("Defensive-AA " .. (r:get() and "ON" or "OFF")) end)
    exp_steam_mem:set_callback  (function(r)
        cs_log("Steam Memory " .. (r:get() and "ON" or "OFF"))
        if not r:get() then SteamMemory = {} end
    end)
    exp_nospread:set_callback(function(r)
        cs_log("NoSpread Mode " .. (r:get() and "ON — head-only, 1% hitchance, 100 min-dmg" or "OFF"))
    end)
    exp_aim_fire_snap:set_callback (function(r) cs_log("aim_fire Snapshot " .. (r:get() and "ON" or "OFF")) end)
    exp_perside_desync:set_callback(function(r) cs_log("Per-Side Desync " .. (r:get() and "ON" or "OFF")) end)
    exp_esp_overlay:set_callback   (function(r) cs_log("ESP Overlay " .. (r:get() and "ON" or "OFF")) end)
    exp_cancel_conf:set_callback   (function(r) cs_log("Cancel Low-Confidence " .. (r:get() and "ON" or "OFF")) end)
    exp_auto_weapon:set_callback   (function(r) cs_log("Auto Per-Weapon " .. (r:get() and "ON" or "OFF")) end)
    exp_persistent_lm:set_callback (function(r) cs_log("Persistent Learning " .. (r:get() and "ON" or "OFF")) end)
    exp_extrapolation:set_callback (function(r) cs_log("Extrapolation " .. (r:get() and "ON" or "OFF")) end)
    exp_respect_man:set_callback   (function(r) cs_log("Respect Manual SSG " .. (r:get() and "ON" or "OFF")) end)
    exp_head_strict:set_callback   (function(r) cs_log("Headshot-Only Strict " .. (r:get() and "ON" or "OFF")) end)
    if exp_lock_headpref then exp_lock_headpref:set_callback(function(r) cs_log("Head-Pref Locked " .. (r:get() and "ON" or "OFF")) end) end
end)
pcall(ffi.cdef, [[
    typedef struct {
    char pad[3];
    char m_bForceWeaponUpdate;
    char pad1[91];
    void* m_pBaseEntity;
     void* m_pActiveWeapon;
    void* m_pLastActiveWeapon;
    float m_flLastClientSideAnimationUpdateTime;
    int m_iLastClientSideAnimationUpdateFramecount;
    float m_flAnimUpdateDelta;
    float m_flEyeYaw;
    float m_flPitch;
    float m_flGoalFeetYaw;
    float m_flCurrentFeetYaw;
    float m_flCurrentTorsoYaw;
    float m_flUnknownVelocityLean;
    float m_flLeanAmount;
    char pad2[4];
    float m_flFeetCycle;
    float m_flFeetYawRate;
    char pad3[4];
    float m_flDuckAmount;
    float m_fLandingDuckAdditiveSomething;
    char pad4[4];
    float m_vOriginX;
    float m_vOriginY;
    float m_vOriginZ;
    float m_vLastOriginX;
    float m_vLastOriginY;
    float m_vLastOriginZ;
    float m_vVelocityX;
    float m_vVelocityY;
    char pad5[4];
    float m_flUnknownFloat1;
    char pad6[8];
    float m_flUnknownFloat2;
    float m_flUnknownFloat3;
    float m_flUnknown;
    float m_flSpeed2D;
    float m_flUpVelocity;
    float m_flSpeedNormalized;
    float m_flFeetSpeedForwardsOrSideWays;
    float m_flFeetSpeedUnknownForwardOrSideways;
    float m_flTimeSinceStartedMoving;
    float m_flTimeSinceStoppedMoving;
    bool m_bOnGround;
    bool m_bInHitGroundAnimation;
    float m_flTimeSinceInAir;
    float m_flLastOriginZ;
    float m_flHeadHeightOrOffsetFromHittingGroundAnimation;
    float m_flStopToFullRunningFraction;
    char pad7[4];
    float m_flMagicFraction;
    char pad8[60];
    float m_flWorldForce;
    char pad9[458];
    float m_flMinYaw;
    float m_flMaxYaw;
} AnimatingStateInfo;]]);

local VTable = {
    Entry = function(instance, index, type) return ffi.cast(type, (ffi.cast("void***", instance)[0])[index]) end,
    Bind = function(self, module, interface, index, typestring)
        local instance = utils.create_interface(module, interface)
        local fnptr = self.Entry(instance, index, ffi.typeof(typestring))
        return function(...) return fnptr(instance, ...) end
    end
}

local NativeGetClientEntity = VTable:Bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")
local NullPtr, CharPtr, ClassPtr = ffi.new "void*", ffi.typeof "char*", ffi.typeof "void***"

local GetAnimState = function(ent)
    if not ent then return false end
    local Address = type(ent) == "cdata" and ent or NativeGetClientEntity(ent)
    if not Address or Address == ffi.NULL then return false end
    local AddressVtable = ffi.cast("void***", Address)
    return ffi.cast("AnimatingStateInfo**", ffi.cast("char*", AddressVtable) + 0x9960)[0]
end

local GetMaxDesync = function(animstate)
    local speedfactor = math.clamp(animstate.m_flFeetSpeedForwardsOrSideWays, 0, 1)
    local avg_speedfactor = (animstate.m_flStopToFullRunningFraction * -0.3 - 0.2) * speedfactor + 1
    local duck_amount = animstate.m_flDuckAmount
    if duck_amount > 0 then
        local duck_speed = duck_amount * speedfactor
        avg_speedfactor = avg_speedfactor + (duck_speed * (0.5 - avg_speedfactor))
    end

    return math.clamp(avg_speedfactor, .5, 1)
end

local function AngleModifier(a) return (360 / 65536) * bit.band(math.floor(a * (65536 / 360)), 65535) end

Approach = function(target, value, speed)
	target, value = AngleModifier(target), AngleModifier(value)
	local delta = target - value
	if speed < 0 then speed = -speed end
	if delta < -180 then delta = delta + 360
	elseif delta > 180 then delta = delta - 360 end
	if delta > speed then value = value + speed
	elseif delta < -speed then value = value - speed
    else value = target
	end
	return value
end

-- NormalizeAngle already forward-declared+assigned at top

AngleDifference = function(dest_angle, src_angle)
	local delta = math.fmod(dest_angle - src_angle, 360)
	if dest_angle > src_angle then
		if delta >= 180 then delta = delta - 360 end
	else
		if delta <= -180 then delta = delta + 360 end
	end
	return delta
end
local Lerp = function(a, b, t) return a + (b - a) * t end
-- V9.65 perf: per-tick per-player memo for RebuildServerYaw. It was recomputed up
-- to ~5×/resolve/player (resolve_player + each pick_first_shot branch), every one
-- an FFI-heavy anim_state + velocity + LBY read. Result is deterministic for a given
-- (tick, player) — reads only this-tick player state, NOT the passed args — so memoising
-- is behaviour-identical and just removes the redundant FFI work. Globals (200-local cap).
server_yaw_cache, server_yaw_cache_tick = {}, -1
local function RebuildServerYaw(player)
    -- V9.32: return nil (not 0) on failure so callers can distinguish a genuine
    -- ~0° server-yaw from a failed computation. They do `... or eye_yaw`, turning a
    -- failure into a 0° delta → existing guess fallback (was resolving to literal 0°).
    if not player then return nil end
    local _tick = globals.tickcount or 0
    if _tick ~= server_yaw_cache_tick then server_yaw_cache, server_yaw_cache_tick = {}, _tick end
    local _idx = player:get_index()
    local _c = server_yaw_cache[_idx]
    if _c ~= nil then if _c == false then return nil else return _c end end
    local ok, result = pcall(function()
    local Animstate = player:get_anim_state()
    if not Animstate then return nil end
    local vx, vy, vz = 0, 0, 0
    pcall(function()
        local v = player.m_vecVelocity
        vx, vy, vz = v.x, v.y, v.z
    end)
    local Velocity = math.sqrt(vx*vx + vy*vy + vz*vz)
    local MaxSpeed = math.clamp(Velocity, 0.0, 260.0)
    local AimMatrixWidthRange = Lerp(math.clamp(Animstate.speed_as_portion_of_walk_top_speed, 0.0, 1.0), 1.0, Lerp(Animstate.walk_run_transition, 0.8, 0.5))
    if Animstate.anim_duck_amount > 0.0 then AimMatrixWidthRange = Lerp(Animstate.anim_duck_amount * math.clamp(Animstate.speed_as_portion_of_crouch_top_speed, 0.0, 1.0), AimMatrixWidthRange, 0.5) end
    
    local TempYawMax = Animstate.aim_yaw_max * AimMatrixWidthRange;
    local TempYawMin = Animstate.aim_yaw_min * AimMatrixWidthRange;

    local FinalServerYaw = math.clamp(Animstate.abs_yaw, -360, 360)
	local EyeServerDelta = AngleDifference(Animstate.eye_yaw, FinalServerYaw)
	if EyeServerDelta > TempYawMax then
        FinalServerYaw = Animstate.eye_yaw + math.abs(TempYawMax)
	elseif EyeServerDelta < TempYawMin then
		FinalServerYaw = Animstate.eye_yaw - math.abs(TempYawMin)
    end

	if Animstate.on_ground then
		if MaxSpeed > 1.0 or Animstate.velocity.z > 100.0 then
			FinalServerYaw = Approach(Animstate.eye_yaw, FinalServerYaw, globals.tickinterval * (30.0 + (20.0 * Animstate.walk_run_transition)))
		else
			local lby = player.m_flLowerBodyYawTarget or Animstate.eye_yaw or 0
			FinalServerYaw = Approach(lby, FinalServerYaw, globals.tickinterval * 100.0)
        end
    end
	return NormalizeAngle(FinalServerYaw)
    end)
    if not ok or result == nil then server_yaw_cache[_idx] = false; return nil end
    server_yaw_cache[_idx] = result
    return result
end

local JitterBuffer = 8

-- attach real metatable to forward-declared PlayerState
setmetatable(PlayerState, {__index = function(t, k)
    local s = {
        missed       = 0,
        last_seen    = 0,
        last_shot    = 0,
        lby_snap     = false,
        lby_snap_attempts = 0,  -- V9.16: magnitude cycle counter for LBY-Snap-Guess
        last_lby     = 0,
        yaw_cache    = {},
        yaw_idx      = 0,
        jitter_ticks = 0,
        static_ticks = 0,
        jittering    = false,
        last_hit_side= 0,
        prev_origin  = vector(0, 0, 0),
        mode         = "Init",
        -- accuracy upgrades
        measured_desync   = 0,
        desync_samples    = 0,
        hit_streak_left   = 0,
        hit_streak_right  = 0,
        last_yaw          = 0,
        last_yaw_time     = 0,
        yaw_rate          = 0,
        yaw_accel         = 0,         -- V9.66: rate-of-change of yaw_rate (decel-damp)
        last_speed2d      = 0,         -- V9.67 #C: shot-time enemy speed (desync bucket)
        n_stand           = 0,         -- V9.67 #C: standing-desync sample count
        measured_stand    = nil,       -- V9.67 #C: standing-bucket desync EMA
        n_move            = 0,         -- V9.67 #C: moving-desync sample count
        measured_move     = nil,       -- V9.67 #C: moving-bucket desync EMA
        onshot_evi        = 0,         -- V9.67 #D: on-shot AA evidence counter
        onshot_aa         = false,     -- V9.67 #D: enemy flips desync on fire
        sw_last_side      = nil,       -- V9.67 #B: last observed fake side
        sw_last_t         = 0,         -- V9.67 #B: time of last fake-side flip
        sw_periods        = nil,       -- V9.67 #B: recent flip intervals ring
        last_resolved     = 0,
        last_eye_yaw      = 0,
        defensive_aa      = false,
        -- AA classification
        aa_type           = "switch",
        aa_classify_cd    = 0,
        -- per-tick scratch
        tmp_dist          = 0,
        tmp_close         = false,
        -- BF cache (prevents tick-rate angle oscillation)
        bf_cached_missed  = nil,
        bf_cached_angle   = nil,
        bf_cached_mode    = nil,
        -- First-shot cache (prevents branch-flip oscillation)
        fs_cached_time    = nil,
        fs_cached_eye     = nil,
        fs_cached_angle   = nil,
        fs_cached_mode    = nil,
        -- V3: aim_fire snapshot ring-buffer
        shot_snapshots    = {},
        -- V3: per-side desync split
        measured_left     = 0,
        measured_right    = 0,
        samples_left      = 0,
        samples_right     = 0,
        -- V9.1: track REAL hit-based samples separate from seeded (passive boot)
        real_left         = 0,
        real_right        = 0,
        -- V9.3: defensive-AA delta fingerprint (jump magnitude on spread-miss)
        def_delta         = 0,
        def_samples       = 0,
        -- V3: recent resolves for confidence
        recent_resolved   = {},
        -- V7.1: passive learning (observed without shooting)
        passive_samples   = 0,
        passive_left      = nil,
        passive_right     = nil,
        -- V5: AA-classify hysteresis
        pending_aa_type   = "switch",
        pending_aa_count  = 0,
        -- V5: adaptive predict-ticks per-player
        adaptive_predict  = nil,  -- nil = use UI default, int = tuned value
        last_pred_was_hit = nil,
        -- V7.8: slow-walker / correction tracking
        slow_ticks        = 0,         -- consecutive ticks at low speed + low yaw_rate
        is_slow_target    = false,     -- committed slow-walker flag
        correction_left   = 0,         -- correction-misses while shooting left side
        correction_right  = 0,         -- correction-misses while shooting right side
        last_shot_side    = 0,         -- side resolver chose for most recent shot
        -- V8.0: per-player hit-rate (last N shots) + yaw-rate consistency + miss-rate-aware confidence
        p_history         = {},        -- bool ring-buffer of last 10 shot results
        p_hits            = 0,
        p_miss            = 0,
        recent_miss_rate  = 0,         -- 0-100, used to penalize confidence
        yaw_rate_buf      = {},        -- last 6 yaw_rate samples (for consistency)
        yaw_rate_consistent = false,   -- true if low stddev across yaw_rate_buf
    }
    t[k] = s
    return s
end})

local function get_state(p)
    return PlayerState[p:get_index()]
end

local function reset_state(s)
    s.missed             = 0
    s.lby_snap           = false
    s.jitter_ticks       = 0
    s.static_ticks       = 0
    s.jittering          = false
    s.bf_cached_missed   = nil
    s.bf_cached_angle    = nil
    s.bf_cached_eye      = nil
    s.fs_cached_time     = nil
    s.fs_cached_angle    = nil
    s.guess_cached_side  = nil
    s.guess_cached_miss  = nil
    resolver_clear_serverfail_retry(s)
end

local function sign(x) return x >= 0 and 1 or -1 end

function resolver_shot_side_from_delta(delta)
    delta = tonumber(delta) or 0
    if math.abs(delta) <= 3 then return 0 end
    return delta > 0 and 1 or -1
end

function resolver_side_conflicts(s, shot_side)
    if not s or not shot_side or shot_side == 0 then return false end
    local sl, sr = s.samples_left or 0, s.samples_right or 0
    local rl, rr = s.real_left or 0, s.real_right or 0
    local hl, hr = s.hit_streak_left or 0, s.hit_streak_right or 0
    if shot_side > 0 then
        return (sl >= 1 and sr == 0) or (rl >= 1 and rr == 0) or (hl >= 2 and hr == 0)
    end
    return (sr >= 1 and sl == 0) or (rr >= 1 and rl == 0) or (hr >= 2 and hl == 0)
end

function resolver_note_serverfail_retry(s, shot_side, mag)
    if not s or not shot_side or shot_side == 0 then return end
    mag = tonumber(mag) or 0
    if mag < 5 then mag = s.measured_desync or 0 end
    if mag < 5 then return end
    if mag > 58 then mag = 58 end
    s.serverfail_retry_side  = shot_side
    s.serverfail_retry_mag   = mag
    s.serverfail_retry_miss  = s.missed or 0
    s.serverfail_retry_until = (globals.tickcount or 0) + 64
end

function resolver_clear_serverfail_retry(s)
    if not s then return end
    s.serverfail_retry_side  = nil
    s.serverfail_retry_mag   = nil
    s.serverfail_retry_miss  = nil
    s.serverfail_retry_until = nil
end

-- known-hit states (everything else is treated as miss to avoid false-positive streak)
local HIT_STATES  = { hit = true, damaged = true, ["hit-damaged"] = true }
local MISS_STATES = { correction = true, spread = true, ["?"] = true,
                      prediction = true, ["prediction_error"] = true,
                      ["prediction error"] = true, death = true,
                      occlusion = true, resolver = true, none = true,
                      miss = true, unregistered = true,
                      ["unregistered shot"] = true, ["unregistered_shot"] = true,
                      backtrack = true, ["no scope"] = true,
                      ["damage rejection"] = true, damage_rejection = true,
                      ["damage_rejection"] = true, rejection = true,
                      ["player death"] = true, player_death = true,
                      -- V8.8: backtrack-failure variants
                      ["backtrack failure"] = true, backtrack_failure = true,
                      ["backtrack_failure"] = true, ["bt failure"] = true,
                      ["bt_failure"] = true }

-- V6.5+V6.8: states that signal "shot didn't actually go for resolver-fault reasons"
-- → don't count toward miss-counter, don't increment learning miss
local NON_RESOLVER_MISS = {
    death = true, ["player death"] = true, player_death = true,
    ["damage rejection"] = true, damage_rejection = true,
    ["damage_rejection"] = true, rejection = true,
    -- V6.8: network/server issues, NOT our angle fault
    ["unregistered shot"] = true, unregistered = true,
    unregistered_shot = true, ["unregistered_shot"] = true,
    -- V8.8: backtrack failures = NL backtrack subsystem couldn't replay, not resolver fault
    ["backtrack failure"] = true, backtrack_failure = true,
    ["backtrack_failure"] = true, ["bt failure"] = true, ["bt_failure"] = true,
}

-- V9.51: record per-shot result for the on-model ESP flash (B) + shot-dots (E).
-- Global (no `local`) — at the 200-local cap. kind = "hit" / "miss" / "serverfail".
function esp_push_shot(s, kind)
    if not s then return end
    s.last_shot_result = kind
    s.last_shot_result_time = globals.curtime or 0
    s.shot_history = s.shot_history or {}
    s.shot_history[#s.shot_history + 1] = kind
    while #s.shot_history > 6 do table.remove(s.shot_history, 1) end
end

events.aim_ack:set(function(event)
    if event == nil or event.target == nil then return end
    local Ent = entity.get(event.target, true)
    if not Ent then return end
    local s = get_state(Ent)
    local reason = event.state
    -- V9.31: read the backtrack tick (confirmed real on this NL build — gazolina &
    -- JAG0YAW both read event.backtrack). A high bt means NL replayed a STALE
    -- record → the miss is netcode, not our side error → must NOT trigger a flip.
    -- pcall: the field may be absent on some builds.
    local bt = 0
    pcall(function() bt = event.backtrack or 0 end)
    -- INVERTED: default to MISS, only count HIT when explicit known-hit
    local is_hit = (reason == nil) or HIT_STATES[reason]
    -- log unknown reasons in debug so we can learn what NL sends
    if reason ~= nil and not HIT_STATES[reason] and not MISS_STATES[reason] then
        cs_log_debug("UNKNOWN aim_ack state='%s' — treated as MISS", tostring(reason))
    end
    -- V6.5: skip non-resolver-fault states (death, damage rejection, etc.)
    if reason and NON_RESOLVER_MISS[reason] then
        -- V9.9-G: BACKTRACK-FAIL PENALTY — count backtrack failures per-player.
        -- After 3+ failures, mark player as backtrack-resistant so extrapolation predict_ticks -1.
        if tostring(reason):lower():find("backtrack") then
            s.bt_fail_count = (s.bt_fail_count or 0) + 1
            if s.bt_fail_count >= 3 then
                s.backtrack_resistant = true
                cs_log_verbose("backtrack-resistant idx=%d (bt_fails=%d) — predict_ticks-1",
                               Ent:get_index(), s.bt_fail_count)
            end
        end
        cs_log_verbose("aim_ack reason=%s — not counting (not resolver fault)", tostring(reason))
        return
    end
    if not is_hit then
        s.missed = s.missed + 1
        local ack_reason = tostring(reason)
        local ack_delta = NormalizeAngle((s.last_resolved or 0) - (s.last_eye_yaw or 0))
        local ack_shot_side = s.last_shot_side ~= 0 and s.last_shot_side or resolver_shot_side_from_delta(ack_delta)
        local ack_measured = s.measured_desync or 0
        -- V9.54: side-aware measured for the serverfail-retry magnitude. The retry
        -- (resolver_note_serverfail_retry below) used to freeze the GLOBAL EMA
        -- (ack_measured = s.measured_desync). On a BIMODAL enemy the two sides have
        -- very different magnitudes (logs: idx=10 L=2/46.2° R=7/29.7°, diff 16°) and
        -- the global average swings mid-round, so the frozen value mis-shot the kept
        -- side for up to 64 ticks (idx=10 retried 15.7° on a 29.7° R side, err=16).
        -- effective_desync already picks per-side correctly — mirror that here so the
        -- retry shoots the side we actually fired. Identical to global on unimodal
        -- (both per-side EMAs ~= global), strictly more accurate on bimodal.
        -- V9.64: computed BEFORE ack_angle_err — see below.
        local ack_side_measured = ack_measured
        if exp_perside_desync and exp_perside_desync:get() then
            if ack_shot_side > 0 and (s.samples_right or 0) >= 1 and (s.measured_right or 0) > 5 then
                ack_side_measured = s.measured_right
            elseif ack_shot_side < 0 and (s.samples_left or 0) >= 1 and (s.measured_left or 0) > 5 then
                ack_side_measured = s.measured_left
            end
        end
        -- V9.64: ack_angle_err references the PER-SIDE magnitude we actually fired, not
        -- the GLOBAL EMA. The resolver + serverfail-retry both shoot effective_desync
        -- (per-side); comparing our |delta| to the blended global average faked a large
        -- err on asymmetric enemies and mislabelled a clean server-fail as a real miss
        -- (logs: idx=1 fired its learned R-side 40.8° = exactly the R EMA, but err was
        -- computed vs global 31.2 → err 9.6 → first miss counted + mode-blacklisted,
        -- when we shot our learned magnitude on-target and the server rejected it).
        -- Unimodal: ack_side_measured ~= global, so err is unchanged.
        local ack_angle_err = ack_side_measured > 5
                              and math.abs(math.abs(ack_delta) - ack_side_measured) or math.huge
        local ack_side_bad = resolver_side_conflicts(s, ack_shot_side)
        -- V9.67 #D: on-shot AA learning. A wrong-SIDE miss that lands inside the enemy's
        -- own fire window (they shot ~within 12 ticks) is evidence their desync flips the
        -- tick they fire (on-shot AA — our own Config does exactly this). Two such hits
        -- mark the enemy; the resolve then flips side inside their fire window.
        if onshot_flip_tog and onshot_flip_tog:get() and ack_side_bad and (s.last_hostile_fire or 0) > 0 then
            local th_os = (globals.tickcount or 0) - s.last_hostile_fire
            if th_os >= 0 and th_os <= 12 then
                s.onshot_evi = (s.onshot_evi or 0) + 1
                if s.onshot_evi >= 2 and not s.onshot_aa then
                    s.onshot_aa = true
                    cs_log_verbose("on-shot AA learned idx=%d (evidence=%d) → flip side in fire window",
                                   Ent:get_index(), s.onshot_evi)
                end
            end
        end
        local ack_resolverish = ack_reason == "correction" or ack_reason == "prediction error" or ack_reason == "prediction_error"
        -- V9.77: the err<=5 (correct-magnitude) branch now ALSO needs genuine backtrack
        -- (bt >= 4). bt=0 means the server used the CURRENT record (no stale replay), so
        -- a correct-magnitude miss there is OUR own side/switch misprediction, not netcode
        -- — the v9.55 note said exactly this but the code never enforced it (real-dump
        -- idx=5: ~14 bt=0/2 keeps excused → headline 86.7% vs raw 59.1%). bt>8 still
        -- filters outright (clean stale-record reject regardless of our angle theory).
        -- V9.80: the bt>8 branch used to pardon ANY high-backtrack miss outright, even
        -- one whose MAGNITUDE was also wrong (idx=10 our=57 meas=45 err=11.9 bt=24,
        -- idx=9 our=29.7 meas=19.3 err=10.4 bt=25). High bt = stale record likely, but
        -- err>8 means we'd have whiffed on a FRESH record too = our overshoot, not pure
        -- netcode. Now bt>8 pardons only when err is also small (or no measurement, where
        -- err is meaningless). A high-bt + high-err miss COUNTS — keeps headline honest.
        local ack_serverfail_like = ack_resolverish and ack_shot_side ~= 0 and not ack_side_bad
                                     and ((ack_side_measured > 5 and ack_angle_err <= 5 and bt >= 4)
                                          or (bt > 8 and (ack_side_measured <= 5 or ack_angle_err <= 8)))
        -- V9.49: a CONFIRMED server-fail keep (correct angle, high bt, side kept) is not
        -- a resolver fault. Logs showed these polluting the headline hit-rate badly:
        -- idx=9 fired the SAME correct -21.8° three times into a declining stale record
        -- (bt 20→10→5, err=0) then hit on shot 4 — the 3 keeps counted as BF:retry misses
        -- and dragged session 9/16=56% when the real resolver rate was ~9/11=82%. Air 0/2
        -- was likewise two bt 19/12 stale-record fails, making a working mode look broken.
        -- Set in the KEEP branches below; gates mode_stats / session / per-player / learned
        -- miss counters (mode-blacklist already exempts these — this finishes the job).
        -- s.missed still increments so BF cycle + force-baim escalation keep advancing.
        local server_fail_keep = false
        -- V9.9-B: 2-MISS MODE-BLACKLIST — track misses per mode within engagement.
        -- After 2 misses with same base mode, blacklist it for 3 ticks so alternate path runs.
        if not ack_serverfail_like and reason ~= "spread" then  -- V9.72: spread = bullet RNG, not the mode's fault
            local mode_clean = tostring(s.mode or ""):gsub("%+Pred","")
                                                     :gsub("%-DefInv","")
                                                     :gsub("%-Recall","")
                                                     :gsub("%-CorrFlip","")
            if mode_clean ~= "" then
                s.mode_misses = s.mode_misses or {}
                s.mode_blacklist_until = s.mode_blacklist_until or {}
                s.mode_misses[mode_clean] = (s.mode_misses[mode_clean] or 0) + 1
                if s.mode_misses[mode_clean] >= 2 then
                    s.mode_blacklist_until[mode_clean] = (globals.tickcount or 0) + 192  -- 3s @64-tick window
                    cs_log_verbose("mode-blacklist idx=%d mode=%s misses=%d -> banned 192 ticks",
                                   Ent:get_index(), mode_clean, s.mode_misses[mode_clean])
                end
            end
        else
            cs_log_verbose("mode-blacklist skip idx=%d mode=%s (correct-angle serverfail, side=%d)",
                           Ent:get_index(), tostring(s.mode), ack_shot_side)
        end
        steam_mem_on_miss(Ent)
        -- defensive-AA hint: enemy moved post-fire ("spread" state)
        if reason == "spread" and exp_def_aa and exp_def_aa:get() then
            s.defensive_aa = true
            -- V9.3: fingerprint def-AA delta — magnitude of post-fire jump
            local d_mag = math.abs(NormalizeAngle((s.last_resolved or 0) - (s.last_eye_yaw or 0)))
            if d_mag >= 10 and d_mag <= 90 then
                local a = 0.30
                if (s.def_samples or 0) == 0 then s.def_delta = d_mag
                else s.def_delta = (s.def_delta or 0) * (1 - a) + d_mag * a end
                s.def_samples = math.min((s.def_samples or 0) + 1, 20)
            end
            cs_log_verbose("DEF-AA detected idx=%d delta=%.1f samples=%d",
                           Ent:get_index(), s.def_delta or 0, s.def_samples or 0)
        end
        -- V9.6+V9.24+V9.38: LBY-Snap-Guess miss flip only when angle OR side
        -- evidence says the resolver was actually wrong.
        -- Earlier code flipped on every miss, but logs showed misses where our
        -- delta exactly matched measured_desync (server-side backtrack failure /
        -- network noise — not our side error). Flipping then = next attempt picks
        -- WRONG side, oscillation. V9.38 adds side evidence so a wrong-sign
        -- BF/opposite shot is not hidden by a matching magnitude.
        if (reason == "correction" or reason == "prediction error") and
           tostring(s.mode):find("LBY%-Snap%-Guess") then
            -- V9.56: flip only on REAL evidence — match the generic path's bt/measurement
            -- awareness (V9.42/V9.47) that this older LBY-Snap branch never got. err is
            -- meaningless without a measurement (first contact, measDesync=0 -> err=inf),
            -- and a high backtrack (bt>8) is a server stale-record reject, not a side error.
            -- Old code flipped on err=inf on EVERY first-contact miss, contradicting the
            -- generic path which kept (logs: idx=2 our=29 meas=0 err=inf bt=13 — LBY flipped
            -- to -1 while generic KEPT side=1 the same tick). Now both agree: no measurement
            -- + high bt -> keep + retry the blind guess once, don't flip a side we never confirmed.
            local lby_flip = ack_side_bad or (ack_measured > 5 and ack_angle_err > 5)
            if bt > 8 then lby_flip = false end
            if lby_flip then
                s.last_hit_side = -s.last_hit_side
                if s.last_hit_side == 0 then s.last_hit_side = -1 end
                s.fs_cached_time = nil
                resolver_clear_serverfail_retry(s)
                cs_log_verbose("LBY-Snap miss FLIP idx=%d our_delta=%.1f measDsync=%.1f err=%.1f side_bad=%s -> side=%d",
                               Ent:get_index(), ack_delta, ack_measured, ack_angle_err,
                               tostring(ack_side_bad), s.last_hit_side)
            else
                -- V9.43: retry the LEARNED magnitude, not max(|delta|, measured). The
                -- old max() memorised a bad overshoot delta and repeated it (see generic
                -- path note) — fatal on a locked enemy whose desync we already know.
                resolver_note_serverfail_retry(s, ack_shot_side, (ack_side_measured > 5 and ack_side_measured) or math.abs(ack_delta))
                server_fail_keep = ack_serverfail_like  -- V9.55: only filter GENUINE netcode (err<=5 or bt>8); a bt=0 side-miss is our fault, count it
                cs_log_verbose("LBY-Snap miss KEEP idx=%d our_delta=%.1f measDsync=%.1f err=%.1f (server-side fail, retry side=%d)",
                               Ent:get_index(), ack_delta, ack_side_measured, ack_angle_err, ack_shot_side)
            end
        end
        -- V7.8 + V8.2: correction-miss → wrong side picked. Track + flip immediately.
        -- V9.31: GENERALIZED SERVER-SIDE-FAIL GUARD (was LBY-Snap-only in V9.24).
        -- V9.38: side-aware. Matching magnitude alone is not enough: a wrong-sign
        -- BF:opposite shot can still have abs(delta) ~= measured_desync. Keep only
        -- when angle matches AND learned side evidence does not contradict the shot;
        -- otherwise flip/decay as a real resolver error. Correct-angle server rejects
        -- schedule one same-side BF:retry before the normal BF cycle.
        if ack_resolverish and ack_shot_side ~= 0 then
          -- FIX #4: skip speculative flip/keep correction on very-low-confidence players.
          -- idx=4 (conf=5, p_hits=1/3) ran the full correction with repeated flips and
          -- wasted shots on guesses. Below conf 15 there is near-zero learned signal — let
          -- the BF cycle (s.missed → "opposite") sweep both sides systematically instead.
          -- serverfail_retry is NOT scheduled here, so BF is free to alternate. A real hit
          -- lifts conf >=15 and re-enables the correction logic.
          local _conf_corr = confidence(s)  -- FIX #4
          if _conf_corr >= 15 then           -- FIX #4
            -- V9.42: decide the side-flip from SIDE evidence, NOT magnitude error.
            -- ack_angle_err = ||delta| - measured| measures MAGNITUDE accuracy: a true
            -- wrong-SIDE miss keeps |delta| ~= measured (right magnitude, wrong sign) →
            -- SMALL err, while a magnitude overshoot on the CORRECT side gives a LARGE
            -- err. So the old "err > 5 → flip" flipped exactly the magnitude-error case
            -- and chased the wrong fix (logs: idx=4 real 36°L, we resolved 55°L — correct
            -- side, 19° overshoot — got flipped to R then missed). Now: never flip on a
            -- server/backtrack fail (high bt); flip when learned side data conflicts;
            -- keep side on a magnitude error so BF cycles the magnitude instead; and on a
            -- blind first-contact miss (no magnitude reference) explore the other side.
            -- V9.45: the "magnitude matched measured → keep side (server fail)" branch
            -- only holds when the measurement is TRUSTWORTHY. On a never-hit enemy the
            -- measured_desync is pure passive seed (real_active==0) — matching it proves
            -- nothing, and keeping the same side freezes the oscillation on the WRONG
            -- side forever (logs: idx=8, p_hits=0/2, seed 52.2°L, shot left 50.8° twice,
            -- 2nd shot bt=0 = no backtrack at all yet still classed "server fail"). Keep
            -- only when a real hit backs the magnitude OR genuine backtrack evidence
            -- (bt>6) makes a server stale-record plausible; otherwise explore the side.
            local real_active = (s.real_left or 0) + (s.real_right or 0)
            -- V9.74: document the jitter+defAA pattern. On a jitter enemy the def_delta
            -- BF cycle is inapplicable (no stable defensive delta) — the actual fix lives
            -- in pick_bruteforce_angle which now skips def_delta and falls through to
            -- BF:opposite. No side decision changes here; this note tags the case.
            if s.defensive_aa and s.aa_type == "jitter" and (s.missed or 0) >= 2 and real_active == 0 then
                cs_log_verbose("jitter+defAA+no-samples: BF:opposite path preferred idx=%d", Ent:get_index())
            end
            local do_flip
            -- V9.47: a learned side-conflict overrides the high-bt "keep" ONLY when our
            -- angle was NOT actually on-target. A clean stale-record reject (the reason
            -- bt>8 keeps) leaves err~0 — the side was right, server just replayed a stale
            -- record. But a HIGH magnitude error (>10) alongside a side-conflict means we
            -- shot the wrong side AND wrong magnitude; the high bt was incidental, not the
            -- cause. Old order let bt>8 keep that wrong side and retry it (logs: idx=8,
            -- 1 R-hit, shot L -21.6 vs meas 39.5, err=17.9 bt=12 — kept L, next real hit
            -- confirmed R). err~0 + side-conflict stays kept (could be a switch enemy whose
            -- learned side is stale, and v9.42 magnitude-overshoot / v9.44 locked cases).
            -- V9.63: confirmed TWO-SIDE switcher guard. When the enemy has real hits on
            -- BOTH sides (switch-AA that genuinely alternates) OR the bimodal flag is set,
            -- the per-side sample dominance that drives `ack_side_bad` is NOISE — the side
            -- history flips every shot, so flipping on it corrupts last_hit_side / dom and
            -- chases the enemy's own alternation (logs: idx=3 aa=switch hit -45°L then +24°R;
            -- side_bad fired off the stale L-lead and the resolver oscillated 60% miss).
            -- On these, treat the miss as a MAGNITUDE problem: KEEP the shot side and let
            -- the BF cycle (now a real L/R sweep, V9.63) cover both — never flip on a clean
            -- low-error/high-bt reject. First contact (one side empty) still explores below.
            local two_side_switcher = (real_active >= 2 and (s.real_left or 0) >= 1
                                       and (s.real_right or 0) >= 1)
                                      or (s.bimodal == true)
            if two_side_switcher and (ack_angle_err <= 10 or bt > 8) then do_flip = false
            -- FIX #1: one-sided switch enemy, correct magnitude (err<2), 2+ consecutive
            -- correct-angle KEEPs on the same side = the switch moved to the other side and
            -- the bt-fail keep never tries it (idx=4 aa=switch L=3/47.9 R=0, 6+ KEEP err=0.0,
            -- 75% miss). Angle is right, SIDE is stale — force a flip. (two_side switchers
            -- above are handled by BF sweep; this catches the one-sided lock.)
            elseif s.aa_type == "switch" and ack_angle_err < 2.0 and (s.serverfail_streak or 0) >= 2 then do_flip = true  -- FIX #1
            elseif ack_side_bad and (ack_measured <= 5 or ack_angle_err > 10) then do_flip = true
            elseif bt > 8 then do_flip = false
            elseif ack_side_bad then do_flip = true
            elseif ack_measured > 5 and (real_active >= 1 or bt > 6) then do_flip = false
            else
                -- V9.72: blind first-contact — consult the PASSIVE side history before
                -- exploring the other side. Real-dump: idx=6 had 550 passive obs backing
                -- side R, first miss was a MAGNITUDE error (err=11.8, shot 20.7 vs meas
                -- 32.5) — the blind explore flipped to L while R was right (4 later real
                -- R-hits). When passive obs clearly dominate the side we just shot
                -- (2:1 ratio, 20+ obs), keep it; the V9.49 never-hit explore
                -- (serverfail_streak>=2) still breaks a frozen wrong guess.
                local pnl, pnr = s.passive_n_left or 0, s.passive_n_right or 0
                local p_dom = 0
                if pnl + pnr >= 20 then
                    if pnr >= pnl * 2 then p_dom = 1
                    elseif pnl >= pnr * 2 then p_dom = -1 end
                end
                if p_dom ~= 0 and p_dom == ack_shot_side then
                    do_flip = false
                    cs_log_verbose("passive-side keep idx=%d side=%d pn{L=%d R=%d} err=%.1f (magnitude miss, side passively confirmed)",
                                   Ent:get_index(), ack_shot_side, pnl, pnr, ack_angle_err)
                else
                    do_flip = true
                end
            end
            -- V9.49: never-hit explore. The bt>8 / bt>6 keep branches above rest on pure
            -- passive seed when we have NEVER hit this enemy (real_active==0) — both the
            -- side AND the magnitude are unconfirmed guesses. A genuine stale record gets
            -- the benefit of the doubt for the first couple keeps, but after 2 consecutive
            -- correct-angle keeps with zero real confirmation the side guess is most likely
            -- just wrong (logs: idx=5 LBY-switch 0/2, shot LEFT twice while passive leaned
            -- RIGHT 42.9°). Force ONE exploration of the other side; the first real hit
            -- pins real_active>=1 and disables this permanently (idx=5 later self-resolved).
            if not do_flip and real_active == 0 and (s.serverfail_streak or 0) >= 2 then
                do_flip = true
                cs_log_verbose("never-hit explore idx=%d streak=%d real=0 — flip to break frozen side",
                               Ent:get_index(), s.serverfail_streak or 0)
            end
            if do_flip then
                if ack_shot_side > 0 then
                    s.correction_right = s.correction_right + 1
                    s.hit_streak_right = math.max(0, (s.hit_streak_right or 0) - 2)
                    s.last_hit_side = -1
                else
                    s.correction_left = s.correction_left + 1
                    s.hit_streak_left = math.max(0, (s.hit_streak_left or 0) - 2)
                    s.last_hit_side = 1
                end
                -- Invalidate first-shot cache so next engagement re-picks side
                s.fs_cached_time   = nil
                s.fs_cached_angle  = nil
                s.guess_cached_side = nil
                resolver_clear_serverfail_retry(s)
                s.serverfail_streak = 0
                cs_log_verbose("correction-miss idx=%d shot_side=%d FLIP->%d err=%.1f side_bad=%s L=%d R=%d",
                               Ent:get_index(), ack_shot_side, s.last_hit_side, ack_angle_err,
                               tostring(ack_side_bad), s.correction_left, s.correction_right)
            else
                -- angle was correct, server rejected it → server-side / fake-lag fail.
                -- KEEP the side. Repeated fails flag a hard fake-lagger.
                s.serverfail_streak = (s.serverfail_streak or 0) + 1
                -- V9.40: bt-driven backtrack-resistance. The reason-string "backtrack"
                -- check (NON_RESOLVER_MISS path) NEVER fires for these — NL labels the
                -- real stale-record netcode miss "correction" / "prediction error" but
                -- carries a HIGH event.backtrack. Feed those into bt_fail_count so the
                -- resistant flag (predict_ticks-1 + full-spread multipoint at close
                -- range) actually triggers on the enemies that cause it.
                if bt > 6 then
                    s.bt_fail_count = (s.bt_fail_count or 0) + 1
                    -- V9.43: escalate faster on point-blank fakelaggers. Waiting for 3
                    -- high-bt fails wasted 2 sure shots on the recurring "correct angle
                    -- (our=meas, err=0), point-blank, server rejects bt 7-10" enemy.
                    -- Now: 2 high-bt fails OR a single clearly-stale record (bt > 12)
                    -- flips the resistant flag → predict_ticks-1 + full-spread multipoint.
                    if not s.backtrack_resistant and (s.bt_fail_count >= 2 or bt > 12) then
                        s.backtrack_resistant = true
                        cs_log_verbose("backtrack-resistant idx=%d (bt-driven, fails=%d bt=%d)",
                                       Ent:get_index(), s.bt_fail_count, bt)
                    end
                end
                -- V9.43: retry the LEARNED magnitude, NOT max(|delta|, measured). The old
                -- max() stored whatever angle we just shot when it was BIGGER than the
                -- measured value — so a single magnitude OVERSHOOT (err > 5, kept side per
                -- v9.42) poisoned serverfail_retry_mag with the bad value and BF:retry
                -- repeated the overshoot. Logs: locked idx=3 (18 hits, measured 22.3°) shot
                -- 41.9° on BF:retry then retried 41.9° again. Trust the measurement instead.
                resolver_note_serverfail_retry(s, ack_shot_side, (ack_side_measured > 5 and ack_side_measured) or math.abs(ack_delta))
                server_fail_keep = ack_serverfail_like  -- V9.55: only filter GENUINE netcode (err<=5 or bt>8); a bt=0 side-miss is our fault, count it
                cs_log_verbose("correction-miss idx=%d KEEP side=%d our=%.1f meas=%.1f err=%.1f bt=%d (server/backtrack fail #%d, retry same)",
                               Ent:get_index(), ack_shot_side, ack_delta, ack_side_measured, ack_angle_err, bt, s.serverfail_streak)
            end
          else
            -- FIX #4: conf<15 — correction skipped, BF cycle sweeps sides (no flip/keep/retry)
            cs_log_verbose("correction skip idx=%d conf=%d <15 — BF sweeps sides",
                           Ent:get_index(), _conf_corr)
          end  -- FIX #4: closes if _conf_corr >= 15
        end
        cs_log_verbose("MISS [%s] target=%d count=%d mode=%s",
                       tostring(reason), Ent:get_index(), s.missed, tostring(s.mode))
        -- V9.49: a CONFIRMED server-fail keep (correct angle, server rejected, side kept)
        -- is not a resolver fault — exclude it from the headline hit-rate, the per-mode
        -- stats, the per-player rate AND the persistent learned hit/miss ratio. Without
        -- this the same correct angle fired repeatedly into a stale backtrack record made
        -- a working mode (Air, BF:retry) read as broken and dragged session ~56% when the
        -- true resolver rate was ~82% (logs: idx=9 fired -21.8° ×3 into bt 20→10→5 err=0;
        -- idx=4 kept side ×3 at err 0.3 across Air + Jitter-Cls). s.missed already
        -- incremented above so BF cycle + force-baim escalation still advance normally.
        if server_fail_keep then
            s.serverfail_misses = (s.serverfail_misses or 0) + 1
            sel01_session_serverfails = (sel01_session_serverfails or 0) + 1
            s.last_miss_server_fail = true  -- FIX #6: correct-angle (err<=5/bt>8) server reject — mode-confidence decay (mode_stats/blacklist) already gated below; flag makes it explicit so Static-Meas is never penalized + ESP can show it
            esp_push_shot(s, "serverfail")  -- V9.51: blue flash + blue dot
            cs_log_verbose("server-fail miss NOT counted idx=%d mode=%s (player#%d session#%d)",
                           Ent:get_index(), tostring(s.mode), s.serverfail_misses, sel01_session_serverfails)
        elseif reason == "spread" then
            -- V9.72: "spread" = the angle was accepted, the simulated bullet deviated
            -- (pure RNG — real-dump: idx=4 took 2 spread misses that fed mode-stats,
            -- mode-blacklist AND read as resolver failures, 0/3 on a possibly-correct
            -- side). Filter from stats like server-fails; s.missed still advances the
            -- BF/baim escalation (multipoint + body widen the effective target, the
            -- correct anti-spread reaction). No side-flip paths fire on spread anyway.
            s.spread_misses = (s.spread_misses or 0) + 1
            sel01_session_spreadfails = (sel01_session_spreadfails or 0) + 1
            esp_push_shot(s, "serverfail")  -- blue = not a resolver fault
            cs_log_verbose("spread miss NOT counted idx=%d mode=%s (bullet RNG, player#%d session#%d)",
                           Ent:get_index(), tostring(s.mode), s.spread_misses, sel01_session_spreadfails)
        else
            s.last_miss_server_fail = false  -- FIX #6: real resolver miss — mode-confidence MAY decay
            learning_update_miss(Ent)
            mode_stats_update(tostring(s.mode), false)
            record_player_shot(s, false)  -- V8.0: per-player hit-rate
            esp_push_shot(s, "miss")  -- V9.51: red flash + red dot
        end
        -- V5: adaptive predict-ticks tuning (miss → reduce by 1)
        if s.last_used_pred_ticks and tostring(s.mode):find("+Pred") then
            s.adaptive_predict = math.max(1, (s.adaptive_predict or s.last_used_pred_ticks) - 1)
            cs_log_verbose("adaptive-predict idx=%d miss → ticks reduced to %d",
                           Ent:get_index(), s.adaptive_predict)
        end
        -- V9.1: skip Init-mode debug log
        if s.mode ~= "Init" then
            cs_log_debug(
                "MISS-FULL idx=%d reason=%s mode=%s aa=%s missCount=%d eye=%.1f resolved=%.1f delta=%.1f measDesync=%.1f samples=%d sideL=%d sideR=%d defAA=%s",
                Ent:get_index(), tostring(reason), tostring(s.mode), tostring(s.aa_type),
                s.missed, s.last_eye_yaw, s.last_resolved,
                NormalizeAngle(s.last_resolved - s.last_eye_yaw),
                s.measured_desync, s.desync_samples,
                s.hit_streak_left, s.hit_streak_right, tostring(s.defensive_aa)
            )
            -- V9.21: also surface to event ticker + console (always-on)
            pcall(cs_event_miss, Ent:get_index(), reason, s.mode,
                  NormalizeAngle((s.last_resolved or 0) - (s.last_eye_yaw or 0)),
                  s.measured_desync, bt, confidence(s))
        end
    else
        -- V9.9-B: clear mode-blacklist + miss-counter on HIT (mode proven working)
        if s.mode_misses then
            local mode_clean = tostring(s.mode or ""):gsub("%+Pred","")
                                                     :gsub("%-DefInv","")
                                                     :gsub("%-Recall","")
                                                     :gsub("%-CorrFlip","")
            s.mode_misses[mode_clean] = 0
            if s.mode_blacklist_until then s.mode_blacklist_until[mode_clean] = 0 end
        end
        esp_push_shot(s, "hit")  -- V9.51: green flash + green dot
        -- HIT: prefer snapshot from aim_fire if available (accurate per-shot state)
        local src_eye, src_res = s.last_eye_yaw, s.last_resolved
        if exp_aim_fire_snap and exp_aim_fire_snap:get() and #s.shot_snapshots > 0 then
            -- V9.36 REGRESSION FIX: prefer event.tick (the tick the ACK refers to) so
            -- we match the EXACT shot being acked. V9.33 wrongly used globals.tickcount
            -- (the ACK-time tick) which always picks the MOST RECENT snapshot — on rapid
            -- fire the ack for shot A would grab shot B's snapshot → wrong eye/resolved →
            -- wrong hit_side learned → corrupted per-side data. Keep the >64 stale-reject
            -- (if event.tick is on a bad clock it rejects to the safe last_* defaults).
            local target_tick = event.tick or event.tick_count or (globals.tickcount or 0)
            local best, best_diff = nil, math.huge
            for _, snap in ipairs(s.shot_snapshots) do
                local diff = math.abs((snap.tick or 0) - target_tick)
                if diff < best_diff then best, best_diff = snap, diff end
            end
            if best and best_diff <= 64 then
                src_eye, src_res = best.eye_yaw, best.resolved
                cs_log_verbose("snapshot match idx=%d tick=%d (target=%d) mode=%s",
                               Ent:get_index(), best.tick, target_tick, tostring(best.mode))
                -- consume snapshot
                for i, snap in ipairs(s.shot_snapshots) do
                    if snap == best then table.remove(s.shot_snapshots, i) break end
                end
            end
        end
        -- compute hit-side from snapshot or fallback delta
        local hit_side = 0
        if src_res ~= 0 and src_eye ~= 0 then
            local d = NormalizeAngle(src_res - src_eye)
            if math.abs(d) > 3 then
                hit_side = d > 0 and 1 or -1
                s.last_hit_side = hit_side
            end
        end
        -- V9.67 #A: feed the pose-param calibrator the confirmed hit-side so it can find
        -- the index that encodes body_yaw. Cheap, only when collection is enabled.
        if pose_cal_tog and pose_cal_tog:get() and hit_side ~= 0 then
            pcall(pose_cal_record, Ent, hit_side)
        end
        -- update measured-desync EMA (global + per-side)
        if src_res ~= 0 and src_eye ~= 0 then
            local actual = math.abs(NormalizeAngle(src_res - src_eye))
            if actual >= 1 and actual <= 65 then
                -- V9.26: drift-bump. Default alpha 0.30 (slow EMA, anti-noise).
                -- When the latest hit's actual differs from the current EMA by
                -- > 5°, the enemy probably changed their desync magnitude.
                -- V9.30: HARD-RESET on big switch. If diff > 10° AND we have
                -- prior samples, the enemy CHANGED their AA preset (not just
                -- drift). EMA bump still takes 3-4 hits to converge; hard reset
                -- catches up in 1 hit by dropping the stored EMA to the new
                -- actual value and decimating sample-count so confidence drops
                -- temporarily. Without this, locked targets (high conf) stay
                -- using the old EMA after the enemy switches → 2-3 sure misses.
                local prev_emag = s.measured_desync or 0
                local diff = math.abs(actual - prev_emag)
                -- V9.39: sample-count alpha ramp. First few hits weight heavier so
                -- the EMA converges in 2-3 hits instead of 5-6, then settles to the
                -- slow anti-noise 0.30 once well-sampled. Drift-bump (diff>5) still
                -- stacks on top. Faster lock = smoother (side settles sooner → the
                -- first-shot path stops flip-flopping modes on early engagements).
                local alpha = 0.30
                local _sc = s.desync_samples or 0
                if _sc <= 1 then alpha = 0.55
                elseif _sc <= 3 then alpha = 0.42 end
                if _sc > 0 and diff > 5 then alpha = math.max(alpha, 0.55) end
                if s.desync_samples == 0 then
                    s.measured_desync = actual
                elseif (not s.bimodal) and s.desync_samples >= 3 and diff > 10 then
                    -- V9.30 SWITCH-RESET: take the new value as-is, decay samples
                    -- V9.32: suppressed when bimodal — a stable two-mode enemy must
                    -- NOT hard-reset the global on every alternation (that thrashes).
                    s.measured_desync = actual
                    s.desync_samples = math.max(2, math.floor(s.desync_samples * 0.4))
                    cs_log_verbose("AA-switch hard-reset idx=%d global EMA %.1f → %.1f (diff=%.1f, samples↓)",
                                   Ent:get_index(), prev_emag, actual, diff)
                else
                    s.measured_desync = s.measured_desync * (1 - alpha) + actual * alpha
                end
                s.desync_samples = math.min(s.desync_samples + 1, 99)
                -- V9.19: push every hit-derived measurement into the session ring
                -- so adaptive_guess_mag() reflects current lobby AA magnitudes.
                session_push_desync(actual)
                -- V9.67 #C: speed-bucketed magnitude — split the measurement into a
                -- standing vs moving bucket (real desync shrinks with speed). Used by
                -- effective_desync's global fallback when the matching bucket is sampled.
                local _spd = s.last_speed2d or 0
                if _spd < 80 then
                    s.n_stand = math.min((s.n_stand or 0) + 1, 99)
                    s.measured_stand = s.measured_stand and (s.measured_stand * 0.7 + actual * 0.3) or actual
                else
                    s.n_move = math.min((s.n_move or 0) + 1, 99)
                    s.measured_move = s.measured_move and (s.measured_move * 0.7 + actual * 0.3) or actual
                end
                -- V9.31: count real (hit-derived) samples side-independently, OUTSIDE
                -- the per-side guard, so confidence is not capped at 50 when the
                -- per-side-desync toggle is OFF (real_left/right gate the conf cap).
                if hit_side > 0 then
                    s.real_right = math.min((s.real_right or 0) + 1, 99)
                elseif hit_side < 0 then
                    s.real_left  = math.min((s.real_left or 0) + 1, 99)
                end
                -- per-side EMA (V9.26: own drift-bump per side too)
                -- V9.30: per-side hard-reset on big switch >10° too.
                if exp_perside_desync and exp_perside_desync:get() then
                    if hit_side > 0 then
                        local prev = s.measured_right or 0
                        local diff_r = math.abs(actual - prev)
                        if s.samples_right == 0 then
                            s.measured_right = actual
                        elseif s.samples_right >= 3 and diff_r > 10 then
                            s.measured_right = actual
                            s.samples_right = math.max(2, math.floor(s.samples_right * 0.4))
                            cs_log_verbose("AA-switch hard-reset idx=%d R-side %.1f → %.1f (diff=%.1f)",
                                           Ent:get_index(), prev, actual, diff_r)
                        else
                            -- V9.39: sample-count ramp (see global EMA note)
                            local a_r = 0.30
                            local _scr = s.samples_right or 0
                            if _scr <= 1 then a_r = 0.55
                            elseif _scr <= 3 then a_r = 0.42 end
                            if diff_r > 5 then a_r = math.max(a_r, 0.55) end
                            s.measured_right = s.measured_right * (1 - a_r) + actual * a_r
                        end
                        s.samples_right = math.min(s.samples_right + 1, 99)
                    elseif hit_side < 0 then
                        local prev = s.measured_left or 0
                        local diff_l = math.abs(actual - prev)
                        if s.samples_left == 0 then
                            s.measured_left = actual
                        elseif s.samples_left >= 3 and diff_l > 10 then
                            s.measured_left = actual
                            s.samples_left = math.max(2, math.floor(s.samples_left * 0.4))
                            cs_log_verbose("AA-switch hard-reset idx=%d L-side %.1f → %.1f (diff=%.1f)",
                                           Ent:get_index(), prev, actual, diff_l)
                        else
                            -- V9.39: sample-count ramp (see global EMA note)
                            local a_l = 0.30
                            local _scl = s.samples_left or 0
                            if _scl <= 1 then a_l = 0.55
                            elseif _scl <= 3 then a_l = 0.42 end
                            if diff_l > 5 then a_l = math.max(a_l, 0.55) end
                            s.measured_left = s.measured_left * (1 - a_l) + actual * a_l
                        end
                        s.samples_left = math.min(s.samples_left + 1, 99)
                    end
                    -- V9.32: BIMODAL detection. A true switch-AA enemy alternates two
                    -- magnitudes (e.g. L=26° R=41°). The per-side EMAs converge cleanly,
                    -- but the GLOBAL measured_desync averages them and the v9.30 global
                    -- hard-reset then THRASHES (every alternation differs >10° from the
                    -- mid value) → adaptive_guess + LBY checks get garbage. Flag bimodal
                    -- off the stable per-side EMAs; hysteresis (>12 set, ≤8 clear) stops
                    -- flag flap. Per-side hard-resets stay active (a real 1-side preset
                    -- switch still moves that side; |L-R| stays small so bimodal=false).
                    local _sl, _sr = (s.samples_left or 0), (s.samples_right or 0)
                    if _sl >= 2 and _sr >= 2 then
                        local _ml, _mr = (s.measured_left or 0), (s.measured_right or 0)
                        if _ml > 5 and _mr > 5 and math.abs(_ml - _mr) > 12 then
                            s.bimodal = true
                        elseif math.abs(_ml - _mr) <= 8 then
                            s.bimodal = false
                        end
                    end
                end
            end
        end
        -- streak side memory (uses freshly computed last_hit_side)
        if s.last_hit_side > 0 then
            s.hit_streak_right = s.hit_streak_right + 1
            s.hit_streak_left  = math.max(s.hit_streak_left - 1, 0)
        elseif s.last_hit_side < 0 then
            s.hit_streak_left  = s.hit_streak_left + 1
            s.hit_streak_right = math.max(s.hit_streak_right - 1, 0)
        end
        s.defensive_aa = false
        if s.missed > 0 then
            cs_log("HIT after " .. s.missed .. " misses (mode=" .. tostring(s.mode) ..
                   ", measured_desync=" .. string.format("%.1f", s.measured_desync) .. "°)")
        else
            cs_log_verbose("HIT first-shot (mode=%s, measured=%.1f)",
                           tostring(s.mode), s.measured_desync)
        end
        -- V9.1: skip Init-mode debug log (useless eye=0 resolved=0 entries)
        if s.mode ~= "Init" then
            cs_log_debug(
                "HIT-FULL idx=%d mode=%s aa=%s missesBefore=%d eye=%.1f resolved=%.1f actualDelta=%.1f measDesync=%.1f samples=%d L=%d R=%d",
                Ent:get_index(), tostring(s.mode), tostring(s.aa_type), s.missed,
                s.last_eye_yaw, s.last_resolved,
                NormalizeAngle(s.last_resolved - s.last_eye_yaw),
                s.measured_desync, s.desync_samples,
                s.hit_streak_left, s.hit_streak_right
            )
            -- V9.21: also surface to event ticker + console (always-on)
            pcall(cs_event_hit, Ent:get_index(), s.mode,
                  NormalizeAngle((s.last_resolved or 0) - (s.last_eye_yaw or 0)),
                  s.measured_desync, confidence(s), s.last_hit_side)
        end
        s.missed = 0
        s.bf_cached_missed = nil  -- clear BF cache so next miss recomputes fresh
        s.bf_cached_angle  = nil
        s.fs_cached_time   = nil  -- clear FS cache so re-engagement re-evaluates
        s.fs_cached_angle  = nil
        s.guess_cached_side = nil
        s.lby_snap_attempts = 0  -- V9.16: reset LBY-Snap-Guess magnitude cycle on hit
        s.guess_cached_miss = nil
        s.serverfail_streak = 0  -- V9.31: hit clears the server-side-fail tally
        resolver_clear_serverfail_retry(s)
        -- V7.8: hit confirms current side — decay correction counters on opposite side
        if hit_side > 0 then
            s.correction_left = math.max(0, (s.correction_left or 0) - 1)
        elseif hit_side < 0 then
            s.correction_right = math.max(0, (s.correction_right or 0) - 1)
        end
        if event.state == "hit" or event.state == nil then
            steam_mem_on_hit(Ent, s.last_hit_side)
            mode_stats_update(tostring(s.mode), true)
            record_player_shot(s, true)  -- V8.0: per-player hit-rate
            -- V5: adaptive predict-ticks tuning (hit → keep or bump by 1, max 5)
            if s.last_used_pred_ticks and tostring(s.mode):find("+Pred") then
                s.adaptive_predict = math.min(5, (s.adaptive_predict or s.last_used_pred_ticks) + 1)
                cs_log_verbose("adaptive-predict idx=%d hit → ticks bumped to %d",
                               Ent:get_index(), s.adaptive_predict)
            end
            -- V4+V6: feed persistent learning with aa_type + winning mode
            if hit_side ~= 0 and src_res ~= 0 and src_eye ~= 0 then
                local actual = math.abs(NormalizeAngle(src_res - src_eye))
                if actual >= 1 and actual <= 65 then
                    learning_update_hit(Ent, hit_side, actual, s.aa_type, s.mode)
                end
            end
        end
    end
end)

local function update_jitter(p, s)
    local ok, ang = pcall(function() return p:get_angles() end)
    if not ok or not ang then return end
    local yaw = ang.y
    if yaw == nil then return end
    s.yaw_cache[s.yaw_idx % JitterBuffer] = yaw
    s.yaw_idx = (s.yaw_idx + 1) % (JitterBuffer * 2)

    -- yaw-rate for extrapolation
    local now = globals.curtime
    local dt = now - s.last_yaw_time
    if dt > 0 and dt < 0.5 and s.last_yaw_time > 0 then
        local delta = NormalizeAngle(yaw - s.last_yaw)
        local raw_rate = delta / dt
        -- V9.0: sanity-clamp yaw_rate — >720°/s is impossible (netvar glitch)
        -- max realistic spin ≈ 360°/s, allow 2× buffer for tick interpolation noise
        if math.abs(raw_rate) > 720 then raw_rate = 0 end
        -- V9.66 #2: yaw acceleration (delta of rate) for decel-damping. A peeker
        -- accelerates then STOPS at a corner; linear yaw_rate*dt overshoots past where
        -- the body parks. When accel sign opposes rate sign (= braking), the predictor
        -- dampens the lead portion. Clamp same as rate (netvar glitch guard).
        local prev_rate = s.yaw_rate or 0
        local raw_accel = (raw_rate - prev_rate) / dt
        if math.abs(raw_accel) > 40000 then raw_accel = 0 end  -- impossible spike
        s.yaw_accel = raw_accel
        s.yaw_rate = raw_rate
        -- V8.0: yaw-rate consistency — only extrapolate when stable direction (low stddev)
        -- V9.71 perf: circular ring (was table.remove(buf,1) shift per tick per enemy).
        -- Consumers only do mean/stddev + length checks — order-insensitive.
        s.yaw_rate_idx = (s.yaw_rate_idx or 0) % 6 + 1
        s.yaw_rate_buf[s.yaw_rate_idx] = s.yaw_rate
        if #s.yaw_rate_buf >= 4 then
            local sum, n = 0, #s.yaw_rate_buf
            for _, r in ipairs(s.yaw_rate_buf) do sum = sum + r end
            local mean = sum / n
            local sq = 0
            for _, r in ipairs(s.yaw_rate_buf) do sq = sq + (r - mean)^2 end
            local sd = math.sqrt(sq / n)
            -- consistent if stddev is small RELATIVE to mean magnitude
            -- (so we extrapolate steady spin but NOT random jitter)
            -- V9.66 #6: tightened (was max(60, mean*0.7)) — 60°/s stddev let a jittery
            -- spinner pass as "consistent" → fed bad extrapolation. 35 + 0.5× is stricter.
            s.yaw_rate_consistent = sd < math.max(35, math.abs(mean) * 0.5)
        end
    end
    s.last_yaw = yaw
    s.last_yaw_time = now

    local diffs = 0
    for i = 0, JitterBuffer - 1 do
        local a = s.yaw_cache[i]
        local b = s.yaw_cache[(i + 1) % JitterBuffer]
        if a and b then
            if math.abs(NormalizeAngle(a - b)) >= 10.0 then
                diffs = diffs + 1
            end
        end
    end

    if diffs >= 3 then
        s.jitter_ticks = math.min(s.jitter_ticks + 1, 8)
        s.static_ticks = math.max(s.static_ticks - 1, 0)
    else
        s.static_ticks = math.min(s.static_ticks + 1, 8)
        s.jitter_ticks = math.max(s.jitter_ticks - 1, 0)
    end

    s.jittering = s.jitter_ticks > s.static_ticks
end

-- ─── AA classification (experimental C1) ──────────────────
local function classify_aa(s)
    -- V9.5: high yaw_rate with consistent direction = spinner regardless of frame-deltas
    if s.yaw_rate and math.abs(s.yaw_rate) > 500 and s.yaw_rate_consistent then
        return "spinner"
    end
    local diffs, total_delta, max_delta = 0, 0, 0
    local samples = 0
    for i = 0, JitterBuffer - 2 do
        local a, b = s.yaw_cache[i], s.yaw_cache[i + 1]
        if a and b then
            local d = math.abs(NormalizeAngle(a - b))
            total_delta = total_delta + d
            if d > max_delta then max_delta = d end
            if d >= 10 then diffs = diffs + 1 end
            samples = samples + 1
        end
    end
    if samples == 0 then return "switch" end
    local avg = total_delta / samples
    if diffs == 0 and avg < 3 then return "static" end
    if diffs >= 4                then return "jitter" end
    if avg > 25 and max_delta < 60 then return "spinner" end
    return "switch"
end

-- ─── Steam-ID memory (experimental C2) ────────────────────
get_steam_mem = function(p)
    if not (exp_steam_mem and exp_steam_mem:get()) then return nil end
    local ok, sid = pcall(function() return p:get_steam_id() end)
    if not ok or not sid then return nil end
    local m = SteamMemory[sid]
    if m == nil then
        m = {hits_left = 0, hits_right = 0, total_misses = 0, dominant_side = 0}
        SteamMemory[sid] = m
    end
    return m, sid
end

steam_mem_on_hit = function(p, side)
    local m = get_steam_mem(p)
    if not m then return end
    if side > 0 then m.hits_right = m.hits_right + 1
    elseif side < 0 then m.hits_left = m.hits_left + 1 end
    if m.hits_right > m.hits_left + 2 then m.dominant_side = 1
    elseif m.hits_left > m.hits_right + 2 then m.dominant_side = -1 end
end

steam_mem_on_miss = function(p)
    local m = get_steam_mem(p)
    if not m then return end
    m.total_misses = m.total_misses + 1
end

local function can_resolve(p)
    if not p then return false end
    if not p:is_alive() then return false end
    if not p:is_enemy() then return false end
    if p:is_dormant() then return false end
    return true
end

local function get_mode_preset()
    -- NoSpread: finer brute-force scan because single-shot must hit exact
    if exp_nospread and exp_nospread:get() then
        return {
            baim_after   = 999,                              -- never baim on nospread
            first_shot   = "networked",                      -- server-yaw most reliable
            bruteforce   = {"+58", "-58", "+45", "-45", "+29", "-29", "+15", "-15", "0"},
            close_boost  = true,
            jitter_lock  = true,
        }
    end
    local m = mode_str()
    if m == "Aggressive" then
        return {
            baim_after   = force_baim_n:get(),
            first_shot   = "predict",
            -- measured/passive desync before blind 29° guesses; log dumps showed
            -- pass-heavy ~45° enemies wasting shots on BF:opposite/+29/-29.
            bruteforce   = {"opposite", "desync", "-desync", "+45", "-45", "+58", "-58", "+29", "-29", "0", "lby"},
            close_boost  = true,
            jitter_lock  = true,
        }
    elseif m == "Defensive" then
        return {
            baim_after   = 5,
            first_shot   = "networked",
            bruteforce   = {"desync", "-desync", "+29", "-29", "0"},
            close_boost  = false,
            jitter_lock  = false,
        }
    else
        return {
            baim_after   = force_baim_n:get(),
            first_shot   = "adaptive",
            bruteforce   = {"opposite", "desync", "+58", "-58", "0"},
            close_boost  = true,
            jitter_lock  = true,
        }
    end
end

-- effective desync: measured EMA falls vorhanden, sonst theoretical
local function effective_desync(s, max_desync, side)
    -- side: +1 (right), -1 (left), 0/nil (any)
    -- V9.24: threshold lowered 2 → 1. One real measured sample beats blindly
    -- shooting at max_desync (58°). Observed bug: BF:opposite shot 57° at
    -- an enemy with measured 24.2° because samples_right was 0 + desync_samples
    -- was 1 — fell through to max_desync. With this change, the 24.2° measured
    -- value is used as soon as a single hit confirms it.
    if side and exp_perside_desync and exp_perside_desync:get() then
        if side > 0 and (s.samples_right or 0) >= 1 and (s.measured_right or 0) > 5 then
            return s.measured_right
        elseif side < 0 and (s.samples_left or 0) >= 1 and (s.measured_left or 0) > 5 then
            return s.measured_left
        elseif (s.passive_samples or 0) >= 8 then
            if side > 0 and (s.passive_right or 0) > 5 then
                return s.passive_right
            elseif side < 0 and (s.passive_left or 0) > 5 then
                return s.passive_left
            end
        end
    end
    if (s.desync_samples or 0) >= 1 and (s.measured_desync or 0) > 5 then
        -- V9.67 #C: speed-bucket refinement on the GLOBAL fallback only. Real max-desync
        -- scales with the enemy's speed (GetMaxDesync), so a single blended EMA mixes
        -- large standing-desync + smaller moving-desync samples = wrong for each. When the
        -- bucket matching the enemy's CURRENT speed is well-sampled, use it. The per-side
        -- path above (bimodal) returns first and is untouched — this only sharpens the
        -- symmetric / pre-per-side case.
        local spd = s.last_speed2d or 0
        if spd < 80 and (s.n_stand or 0) >= 2 and (s.measured_stand or 0) > 5 then return s.measured_stand end
        if spd >= 80 and (s.n_move or 0) >= 2 and (s.measured_move or 0) > 5 then return s.measured_move end
        return s.measured_desync
    end
    if (s.passive_samples or 0) >= 8 and (s.measured_desync or 0) > 5 then
        return s.measured_desync
    end
    if (s.passive_samples or 0) >= 8 then
        local passive_mag = math.max(s.passive_left or 0, s.passive_right or 0)
        if passive_mag > 5 then return passive_mag end
    end
    return max_desync
end

-- ═══════════════════════════════════════════════════════
-- V9.67 NEW LEVERS (all GLOBAL — 200-local cap; callable from aim_ack / resolve
-- closures because globals resolve at call-time, not parse-time).
-- ═══════════════════════════════════════════════════════

-- (A) POSE-PARAM CALIBRATION. NL exposes m_flPoseParameter[]; one of the indices is
-- the animated body_yaw (= the real desync side) but the index is undocumented and
-- build-specific. We find it by SEPARATION: for each index, track the mean param value
-- on LEFT hits vs RIGHT hits. The body_yaw index is the one whose left-mean and
-- right-mean separate cleanly (|meanR - meanL| large relative to its own stddev). This
-- replaces the v9.67 sign-vs-running-mean scorer, which FALSELY promoted constant /
-- degenerate indices when the early hits were one-sided (real dump: 3 right-side hits →
-- every constant index read 0%/"eff 100%"). Promotion now requires: ≥20 hits, ≥5 on
-- EACH side (so the correlation is real, not predicting the majority side), the param
-- actually varies (stddev > eps), and |separation| ≥ 1.2 stddevs. Sign of the
-- separation says whether higher value = right.
pose_cal_acc    = {}      -- [i] = {n, sum, sumsq, sl, nl, sr, nr}
g_pose_best_idx = nil
g_pose_best_sep = 0       -- |separation| in stddevs of the promoted index
g_pose_best_dir = 1       -- +1: higher value = right ; -1: higher value = left
g_pose_best_mid = 0       -- midpoint between the two side-means (decision boundary)
local function _pose_eval(a)
    -- returns sep (signed, in stddevs), mid, ok
    if (a.nl or 0) < 1 or (a.nr or 0) < 1 then return 0, 0, false end
    local mean = a.sum / a.n
    local var  = a.sumsq / a.n - mean * mean
    local sd   = math.sqrt(math.max(var, 0))
    if sd < 1e-4 then return 0, mean, false end      -- constant param → useless
    local ml, mr = a.sl / a.nl, a.sr / a.nr
    local sep = (mr - ml) / sd
    return sep, (ml + mr) * 0.5, true
end
function pose_cal_record(p, hit_side)
    if hit_side == 0 then return end
    for i = 0, 23 do
        local ok, v = pcall(function() return p.m_flPoseParameter[i] end)
        if ok and type(v) == "number" then
            local a = pose_cal_acc[i]
            if not a then a = {n=0, sum=0, sumsq=0, sl=0, nl=0, sr=0, nr=0}; pose_cal_acc[i] = a end
            a.n = a.n + 1; a.sum = a.sum + v; a.sumsq = a.sumsq + v * v
            if hit_side > 0 then a.sr = a.sr + v; a.nr = a.nr + 1
            else                 a.sl = a.sl + v; a.nl = a.nl + 1 end
        end
    end
    -- V9.70: NON-STICKY re-evaluation. The v9.69 promote was sticky (once an index
    -- crossed the bar it stayed BEST even as its separation decayed) — a small-sample
    -- fluke (idx 16 hit 1.28σ at n=20) locked in, then collapsed to 0.58σ with more
    -- data while still showing "<<< BEST". Now we re-scan ALL indices every hit and pick
    -- the current best meeting STRICTER gates (n≥25, ≥6 per side, |sep|≥1.3). If none
    -- qualifies, g_pose_best_idx clears → the dump is honest. This means a real body_yaw
    -- index must hold its separation as samples grow; pure noise self-demotes.
    local best_i, best_abs, best_sep, best_mid = nil, 0, 0, 0
    for i = 0, 23 do
        local a = pose_cal_acc[i]
        if a and a.n >= 25 and a.nl >= 6 and a.nr >= 6 then
            local sep, mid, valid = _pose_eval(a)
            if valid and math.abs(sep) >= 1.3 and math.abs(sep) > best_abs then
                best_i, best_abs, best_sep, best_mid = i, math.abs(sep), sep, mid
            end
        end
    end
    if best_i ~= g_pose_best_idx then
        if best_i then
            cs_log_verbose("pose-cal: index %d promoted (sep=%.2fσ, dir=%d, mid=%.3f)",
                           best_i, best_sep, (best_sep > 0) and 1 or -1, best_mid)
        elseif g_pose_best_idx then
            cs_log_verbose("pose-cal: index %d DEMOTED (separation decayed below 1.3σ)", g_pose_best_idx)
        end
    end
    g_pose_best_idx = best_i
    g_pose_best_sep = best_abs
    g_pose_best_dir = best_i and ((best_sep > 0) and 1 or -1) or 1
    g_pose_best_mid = best_mid or 0
end
function pose_read_side(p)
    if not g_pose_best_idx then return 0 end
    local ok, v = pcall(function() return p.m_flPoseParameter[g_pose_best_idx] end)
    if not ok or type(v) ~= "number" then return 0 end
    -- higher-than-midpoint → the side g_pose_best_dir points to
    local side = (v > g_pose_best_mid) and 1 or -1
    if g_pose_best_dir < 0 then side = -side end
    return side
end
function pose_cal_dump()
    cs_event_console("─── POSE CALIBRATION (idx : sep(σ) : nL/nR : meanL→meanR) ───", 150, 200, 255)
    for i = 0, 23 do
        local a = pose_cal_acc[i]
        if a and a.n > 0 then
            local sep, _mid, valid = _pose_eval(a)
            local ml = (a.nl > 0) and (a.sl / a.nl) or 0
            local mr = (a.nr > 0) and (a.sr / a.nr) or 0
            local strong = valid and math.abs(sep) >= 1.3
            local mark = (g_pose_best_idx == i) and "  <<< BEST (body_yaw)" or (strong and "  *strong*" or "")
            cs_event_console(string.format("  [%d] sep=%.2f  L%d/R%d  %.3f→%.3f%s", i, sep, a.nl, a.nr, ml, mr, mark),
                             strong and 120 or 200, strong and 255 or 200, 120)
        end
    end
    if not g_pose_best_idx then
        cs_event_console("  no index calibrated — need a SUSTAINED |sep|>=1.3 (25+ hits, 6+ each side). If none holds, this build does not cleanly expose body_yaw → leave pose OFF.", 255, 200, 120)
    end
end

-- (B) SWITCH-PERIOD. The server's per-tick predicted feet-yaw (m_flGoalFeetYaw, read in
-- the passive block) gives the CURRENT fake side every tick — observable without a hit.
-- A switch-AA enemy alternates it on a timer; we record the interval between flips and,
-- if it is regular, predict which side the fake is on at shot-land time.
function switch_period_observe(s, side, now)
    if side == 0 then return end
    if not s.sw_last_side then s.sw_last_side = side; s.sw_last_t = now; s.sw_periods = {}; return end
    if side ~= s.sw_last_side then
        local dt = now - (s.sw_last_t or now)
        if dt > 0.02 and dt < 2.0 then
            s.sw_periods = s.sw_periods or {}
            table.insert(s.sw_periods, dt)
            while #s.sw_periods > 8 do table.remove(s.sw_periods, 1) end
        end
        s.sw_last_side = side; s.sw_last_t = now
    end
end
function switch_period_predict_side(s, now)
    local arr = s.sw_periods
    local n = arr and #arr or 0
    if n < 4 then return 0 end
    local sorted = {}
    for i = 1, n do sorted[i] = arr[i] end
    table.sort(sorted)
    local med = sorted[math.floor(n / 2) + 1]
    if not med or med <= 0 then return 0 end
    -- regularity gate: every interval within 35% of the median (else it is jitter, not a switch)
    for i = 1, n do
        if math.abs(sorted[i] - med) > med * 0.35 then return 0 end
    end
    local cur = s.sw_last_side or 0
    if cur == 0 then return 0 end
    -- phase: half-periods elapsed since the last observed flip, plus a small land-lead.
    local since = now - (s.sw_last_t or now)
    local flips = math.floor((since + 0.05) / med)
    return (flips % 2 == 0) and cur or -cur
end

-- yaw-extrapolation für hohen ping/lerp
local function extrapolate_yaw(s, current_yaw)
    local lerp_ms = 16
    pcall(function() lerp_ms = (entity.get_lerp_time and entity.get_lerp_time() * 1000) or 16 end)
    -- V9.3: add ping/2 (one-way latency) — high ping needs more extrapolation
    local ping_factor = (tick_cache.ping_ms or 0) * 0.5
    local total_ms = lerp_ms + ping_factor
    if total_ms <= 30 or s.yaw_rate == 0 then return current_yaw end
    local extra = s.yaw_rate * (total_ms / 1000)
    if extra > 40 then extra = 40 elseif extra < -40 then extra = -40 end
    return current_yaw + extra
end

local function _pick_first_shot_impl(p, s, anim, eye_yaw, max_desync, preset)
    -- best-guess side for per-side effective_desync
    local guess_side = s.last_hit_side ~= 0 and s.last_hit_side
                       or (s.hit_streak_right >= s.hit_streak_left and 1 or -1)
    local desync = effective_desync(s, max_desync, guess_side)
    local vx, vy = 0, 0
    pcall(function()
        local v = p.m_vecVelocity
        vx, vy = v.x or 0, v.y or 0
    end)
    local speed2d = math.sqrt(vx*vx + vy*vy)
    -- clamp insane velocity from NL netvar glitches (respawn/teleport spikes 1000+ u/s)
    if speed2d > 320 then speed2d = 0 end  -- CS2 max run speed ≈ 260, anything above = glitch
    s.last_speed2d = speed2d  -- V9.67 #C: shot-time speed for the desync speed-bucket
    local close = preset.close_boost and s.tmp_close

    -- V9.66 #1: keep the RAW eye for the sanity bound below. extrapolate_yaw applies
    -- the lerp+ping/2 interp-compensation and is the FALLBACK when full prediction is
    -- gated off — so a non-leading target still gets interp-comp. When prediction DOES
    -- fire, the unified predictor (below) folds interp-comp + lead into one term, so the
    -- comp is no longer thrown away (old code overwrote eye_yaw with lead-only).
    local raw_eye = eye_yaw
    eye_yaw = extrapolate_yaw(s, eye_yaw)
    -- V4+V5+V6+V7+V8.0+V8.1: educated extrapolation — tighter gates, smaller ticks
    -- V8.1: predict was overshooting. Lower per-aa caps, raise conf gate, shrink delta sanity.
    if exp_extrapolation and exp_extrapolation:get() and s.yaw_rate and math.abs(s.yaw_rate) > 10 then
        local can_predict = true
        local p_conf = confidence(s)

        -- V8.0 gate 1: jitter/spinner with inconsistent yaw_rate → skip
        if s.yaw_rate_buf and #s.yaw_rate_buf >= 4 and not s.yaw_rate_consistent then
            can_predict = false
        end
        -- V8.1 gate 2: confidence raised 30 → 40 (less greedy)
        if p_conf < 40 then can_predict = false end
        -- V8.0 gate 3: slow-walker → no extrapolation
        if s.is_slow_target then can_predict = false end
        -- V8.1 gate 4: no extrapolation on first engagement (samples < 1)
        if ((s.samples_left or 0) + (s.samples_right or 0)) < 1 then can_predict = false end
        -- V9.46 gate 5: no extrapolation across a teleport-peek — yaw_rate from before
        -- the blink does not predict where the body lands after it.
        if s.tp_peek_active then can_predict = false end

        if can_predict then
            local ui_ticks = exp_predict_ticks and exp_predict_ticks:get() or 2
            local ticks = s.adaptive_predict or ui_ticks
            -- V8.1: tighter per-aa-type caps
            if s.aa_type == "static" then
                ticks = math.min(ticks, 1)   -- static: 1 tick max (was 2)
            elseif s.aa_type == "jitter" or s.aa_type == "spinner" then
                ticks = math.min(ticks, 2)   -- jitter: 2 ticks max (was 3)
            else
                ticks = math.min(ticks, 3)   -- switch: 3 max
            end
            -- V9.2: distance-scale predict ticks
            local d = s.tmp_dist or 0
            if d > 1800 then ticks = ticks + 1
            elseif d < 400 then ticks = math.max(1, ticks - 1)
            end
            -- V9.3 + V9.9-E: per-weapon predict scaling via tick-cached get_weapon_class()
            local lp_wpn_cls = get_weapon_class()
            if lp_wpn_cls == "sniper" then ticks = ticks + 1     -- 1-tap needs precise predict
            elseif lp_wpn_cls == "heavy_pistol" or lp_wpn_cls == "other" then
                -- 'other' covers pistols/smgs — light commit
                if lp_wpn_cls == "other" then ticks = math.max(1, ticks - 1) end
            end
            -- V7.0: locked target — gentle +1 bonus
            local total_samp = (s.samples_left or 0) + (s.samples_right or 0)
            if total_samp >= 8 and p_conf >= 60 then ticks = ticks + 1 end
            -- V9.9-H: yaw-rate-consistent target with stable buffer → +1 tick lead (clean signal)
            if s.yaw_rate_consistent and s.yaw_rate_buf and #s.yaw_rate_buf >= 6 then
                ticks = ticks + 1
            end
            -- V9.9-G: backtrack-resistant player → -1 tick (NL backtrack can't replay them)
            if s.backtrack_resistant then ticks = math.max(1, ticks - 1) end
            ticks = math.max(1, math.min(4, ticks))   -- hard cap 4 (was 6)
            -- peek-snap reduces — V9.9-E: use tick_cache.lp
            local lp_peek = false
            pcall(function()
                local lp = tick_cache.lp or entity.get_local_player()
                if lp then
                    local v = lp.m_vecVelocity
                    local sp = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
                    if sp < 30 then lp_peek = true end
                end
            end)
            if lp_peek then ticks = math.max(1, ticks - 1) end
            -- V9.66 #1+#2: UNIFIED predictor. One term = interp-comp (lerp+ping/2) + lead
            -- (ticks). The lead portion is decel-damped: when the enemy is braking
            -- (yaw_accel sign opposes yaw_rate sign) the lead shrinks toward 0.3× so a
            -- corner-peek-stop is not overshot. interp-comp is never damped (it corrects
            -- a delay that already happened). One clamp on the total.
            local tickint = (tick_cache and tick_cache.tickint) or (1/64)
            local lerp_ms = 16
            pcall(function() lerp_ms = (entity.get_lerp_time and entity.get_lerp_time() * 1000) or 16 end)
            local comp_dt = (lerp_ms + (tick_cache.ping_ms or 0) * 0.5) / 1000
            -- decel-damp factor for the lead term only
            local lead_factor = 1.0
            local ya, yr = s.yaw_accel or 0, s.yaw_rate or 0
            if yr ~= 0 and ya ~= 0 and ((ya > 0) ~= (yr > 0)) then
                -- braking: |accel| relative to |rate| over one tick = how much the rate
                -- will bleed off. Strong brake → minimal lead.
                local bleed = math.abs(ya) * tickint / math.max(math.abs(yr), 1)
                lead_factor = math.max(0.3, 1.0 - bleed)
            end
            local lead_dt = ticks * tickint * lead_factor
            local total_delta = yr * (comp_dt + lead_dt)
            if total_delta > 60 then total_delta = 60 elseif total_delta < -60 then total_delta = -60 end
            local predicted = (s.last_yaw or raw_eye) + total_delta
            -- V8.1: sanity vs RAW eye (was the lerp-extrapolated one) — cap 30 since the
            -- delta now includes interp-comp on top of the lead (was lead-only @25).
            local delta = NormalizeAngle(predicted - raw_eye)
            if math.abs(delta) < 30 then
                eye_yaw = predicted
                s.mode = (s.mode or "") .. "+Pred"
                s.last_used_pred_ticks = ticks
            end
        end
    end

    -- V9.67: DIRECT-SIDE SOURCES (pose read / on-shot flip / switch-period). When one of
    -- these opt-in levers produces a confident side, resolve straight at the per-side
    -- magnitude and skip the statistical mode tree — these are stronger signals than a
    -- guess. Priority pose > on-shot > switch. All gated behind their own toggle; the
    -- branch is inert (direct_side stays 0) for everyone who has not opted in.
    do
        local direct_side, direct_tag = 0, nil
        if pose_use_tog and pose_use_tog:get() and g_pose_best_idx then
            local ps = pose_read_side(p)
            if ps ~= 0 then direct_side, direct_tag = ps, "Pose" end
        end
        if direct_side == 0 and onshot_flip_tog and onshot_flip_tog:get() and s.onshot_aa
           and (s.last_hostile_fire or 0) > 0 and s.last_hit_side ~= 0 then
            local th = (globals.tickcount or 0) - s.last_hostile_fire
            if th >= 0 and th <= 10 then direct_side, direct_tag = -s.last_hit_side, "OnShot-Flip" end
        end
        if direct_side == 0 and switch_pred_tog and switch_pred_tog:get() then
            local sp = switch_period_predict_side(s, tick_cache.curtime or 0)
            if sp ~= 0 then direct_side, direct_tag = sp, "Switch-Pred" end
        end
        if direct_side ~= 0 then
            s.mode = direct_tag
            return eye_yaw + effective_desync(s, max_desync, direct_side) * direct_side
        end
    end

    -- V7.7 + V8.9 + V9.9-B: KNOWN-PLAYER FAST-PATH — use historical best-mode for current aa_type
    -- V8.9 fix: strip existing -Recall suffix before appending to avoid name explosion
    -- V9.9-B: skip if mode is currently blacklisted (2+ misses within blacklist window)
    if s.boot_best_modes and s.aa_type and s.boot_best_modes[s.aa_type] then
        local best = s.boot_best_modes[s.aa_type]
        if best and best ~= "" then
            local clean = best:gsub("%-Recall", "")
            local blacklisted = false
            if s.mode_blacklist_until and (s.mode_blacklist_until[clean] or 0) > (globals.tickcount or 0) then
                blacklisted = true
            end
            if not blacklisted and (best:find("Static") or best:find("Jitter%-Cls") or best:find("Jitter%-Lock")) then
                if s.measured_desync > 5 then
                    local side = s.last_hit_side ~= 0 and s.last_hit_side or 1
                    s.mode = clean .. "-Recall"
                    return eye_yaw + s.measured_desync * side
                end
            end
        end
    end

    -- V7.8 + V8.4: SLOW-WALKER FAST-PATH — stationary enemy = static AA regardless of aa_type
    -- V8.4: for FULLY stationary, try server-yaw FIRST (most accurate when no movement)
    -- Then fall back to: measured > passive > correction-aware guess
    if s.is_slow_target then
        -- V8.4: STATIONARY → server-yaw is most reliable for standing-still
        if s.is_stationary then
            -- V9.7: switch-AA stationary with hit-data → ALTERNATE side (prev: Still-Server/Still-Meas stuck on last-hit side, BF:opposite kept saving us)
            local sw_both = (s.samples_left or 0) >= 1 and (s.samples_right or 0) >= 1
            local sw_corr = ((s.correction_left or 0) + (s.correction_right or 0)) >= 2
            if s.aa_type == "switch" and s.last_hit_side ~= 0 and (sw_both or sw_corr) then
                -- V9.19: dom-bias — if one side leads by 2+, prefer dom over blind alt
                local side = alt_side_pick(s)
                if side == 0 then side = -s.last_hit_side end
                local mag
                if side > 0 and (s.samples_right or 0) >= 1 and (s.measured_right or 0) > 5 then
                    mag = s.measured_right
                elseif side < 0 and (s.samples_left or 0) >= 1 and (s.measured_left or 0) > 5 then
                    mag = s.measured_left
                elseif (s.measured_desync or 0) > 5 then
                    mag = s.measured_desync
                else
                    mag = adaptive_guess_mag()
                end
                s.mode = "Still-Alt"
                return eye_yaw + mag * side
            end
            local sy = RebuildServerYaw(p) or eye_yaw  -- V9.32: nil=fail → eye_yaw → guess
            local sy_delta = NormalizeAngle(sy - eye_yaw)
            if math.abs(sy_delta) >= 5 and math.abs(sy_delta) <= 65 then
                s.mode = "Still-Server"
                return sy
            end
            -- if server-yaw useless but we have measured, use it on best side
            if s.desync_samples >= 1 and s.measured_desync > 5 then
                local side = s.last_hit_side ~= 0 and s.last_hit_side or 1
                s.mode = "Still-Meas"
                return eye_yaw + s.measured_desync * side
            end
            -- last resort: cycle wide angles to find their desync
            local cyc = {58, -58, 45, -45, 29, -29}
            s._still_count = (s._still_count or 0) + 1
            local mag = cyc[((s._still_count - 1) % #cyc) + 1]
            s.mode = "Still-BFGuess"
            return eye_yaw + mag
        end
        -- regular slow-walker (some movement / aim wobble)
        -- V9.2: stationary switch-AA also alternates (was movement-only)
        local both_hit = (s.samples_left or 0) >= 1 and (s.samples_right or 0) >= 1
        local corr_total = (s.correction_left or 0) + (s.correction_right or 0)
        local corr_diff = (s.correction_right or 0) - (s.correction_left or 0)
        local pref_side
        if s.aa_type == "switch" and (both_hit or corr_total >= 2) and s.last_hit_side ~= 0 then
            -- V9.19: dom-bias — prefer dom if it leads by 2+, else opposite of last hit
            pref_side = alt_side_pick(s)
            if pref_side == 0 then pref_side = -s.last_hit_side end
            s.mode = "Slow-Alt"
        elseif math.abs(corr_diff) >= 2 then
            pref_side = corr_diff > 0 and -1 or 1
        elseif s.last_hit_side ~= 0 then
            pref_side = s.last_hit_side
        elseif s.hit_streak_right ~= s.hit_streak_left then
            pref_side = s.hit_streak_right > s.hit_streak_left and 1 or -1
        else
            pref_side = 1
        end
        local mag
        local is_alt = (s.mode == "Slow-Alt")  -- V9.2 preserve Slow-Alt label
        if pref_side > 0 and s.samples_right >= 1 and s.measured_right > 5 then
            mag = s.measured_right
            if not is_alt then s.mode = "Slow-Meas" end
        elseif pref_side < 0 and s.samples_left >= 1 and s.measured_left > 5 then
            mag = s.measured_left
            if not is_alt then s.mode = "Slow-Meas" end
        elseif s.desync_samples >= 1 and s.measured_desync > 5 then
            mag = s.measured_desync
            if not is_alt then s.mode = "Slow-Meas" end
        elseif s.passive_samples and s.passive_samples >= 5 then
            mag = math.max(s.passive_left or 0, s.passive_right or 0, 29)
            if not is_alt then s.mode = "Slow-Passive" end
        else
            local cyc = {29, 45, 58, 20, 35}
            s._eng_count = (s._eng_count or 0) + 1
            mag = cyc[((s._eng_count - 1) % #cyc) + 1]
            if not is_alt then s.mode = "Slow-Guess" end
        end
        return eye_yaw + mag * pref_side
    end

    -- AA-classify shortcuts
    if exp_aa_classify and exp_aa_classify:get() then
        if s.aa_type == "static" then
            -- 1) measured desync × known side (best case)
            if s.desync_samples >= 2 and s.measured_desync > 5 then
                local side = s.last_hit_side ~= 0 and s.last_hit_side or 1
                s.mode = "Static-Meas"
                return eye_yaw + s.measured_desync * side
            end
            -- 2) server-yaw if it returns meaningful delta
            local sy = RebuildServerYaw(p) or eye_yaw  -- V9.32: nil=fail → eye_yaw → guess
            local sy_delta = NormalizeAngle(sy - eye_yaw)
            if math.abs(sy_delta) >= 5 then
                -- if measured exists but smaller than sy_delta — boost to measured side
                if s.measured_desync > 5 and math.abs(sy_delta) < s.measured_desync then
                    local side = sy_delta >= 0 and 1 or -1
                    s.mode = "Static-ServerBoost"
                    return eye_yaw + s.measured_desync * side
                end
                s.mode = "Static-Server"
                return sy
            end
            -- 3) FALLBACK: server-yaw == eye_yaw (no info). Guess ±29° via streak/default
            -- V7.8: correction-aware — if last shots correction-missed on one side, flip
            local corr_diff = (s.correction_right or 0) - (s.correction_left or 0)
            local side
            if math.abs(corr_diff) >= 2 then
                side = corr_diff > 0 and -1 or 1
            else
                side = s.last_hit_side ~= 0 and s.last_hit_side
                    or (s.hit_streak_right >= s.hit_streak_left and 1 or -1)
            end
            s.mode = "Static-Guess"
            return eye_yaw + adaptive_guess_mag() * side
        elseif s.aa_type == "jitter" and s.last_hit_side ~= 0 then
            s.mode = "Jitter-Cls"
            return eye_yaw + desync * s.last_hit_side
        elseif s.aa_type == "spinner" and s.yaw_rate and math.abs(s.yaw_rate) > 60 then
            -- V9.3: SPINNER-ROT — enemy rotating continuously
            -- desync on side OPPOSITE rotation direction (server compensates rotation)
            local spin_side = s.yaw_rate > 0 and -1 or 1
            s.mode = "Spinner-Rot"
            local mag = s.desync_samples >= 2 and s.measured_desync or desync
            return eye_yaw + mag * spin_side
        end
    end

    if preset.first_shot == "networked" then
        local sy = RebuildServerYaw(p) or eye_yaw  -- V9.32: nil=fail → eye_yaw → guess
        -- V6: harden — if server-yaw returned eye_yaw (no info), fallback to guess
        if math.abs(NormalizeAngle(sy - eye_yaw)) < 5 then
            local side = s.last_hit_side ~= 0 and s.last_hit_side or 1
            s.mode = "Networked-Guess"
            return eye_yaw + adaptive_guess_mag() * side
        end
        s.mode = "Networked"
        return sy
    end

    -- LBY snap: enemy just shot → server yaw locked to eye
    if lby_snap_toggle:get() and s.lby_snap then
        s.mode = "LBY-Snap"
        s.lby_snap = false
        local lby = p.m_flLowerBodyYawTarget
        -- V6+V9.16: harden — if LBY equals eye (no snap actually), guess intelligently:
        --   if we have a measured_desync from prior hits, use that magnitude.
        --   otherwise cycle 29 -> 45 -> 58 across repeated LBY-Snap-Guess attempts so
        --   a single wrong-mag guess (e.g. user-reported amy:3 measDesync ~42 vs hardcoded 29)
        --   does not cause 3 misses in a row before BF takes over.
        if not lby or math.abs(NormalizeAngle(lby - eye_yaw)) < 5 then
            local side = s.last_hit_side ~= 0 and s.last_hit_side or 1
            local mag
            if s.measured_desync and s.measured_desync >= 10 then
                mag = s.measured_desync
            else
                -- V9.19: cycle anchored on adaptive lobby median, not hardcoded 29
                s.lby_snap_attempts = (s.lby_snap_attempts or 0) + 1
                local base = adaptive_guess_mag()
                local cycle = { base, math.min(58, base + 16), 58 }
                mag = cycle[((s.lby_snap_attempts - 1) % 3) + 1]
            end
            s.mode = "LBY-Snap-Guess"
            return eye_yaw + mag * side
        end
        -- successful LBY snap (server returned real value) — reset cycle counter
        s.lby_snap_attempts = 0
        return lby
    end

    -- jitter: lock onto last hit side (aggressive only)
    -- V8.7: ONLY fire for true jitter aa_type — switch enemies trip jittering flag but
    -- should use Predicted-Alt path instead (their side oscillates per shot)
    if s.jittering and preset.jitter_lock and s.last_hit_side ~= 0
       and s.aa_type == "jitter" then
        s.mode = "Jitter-Lock"
        return eye_yaw + desync * s.last_hit_side
    end

    -- moving enemy: desync usually opposite to movement direction
    if speed2d > 5 then
        s.mode = "Predicted"
        local side
        -- V8.2 + V8.7: switch-AA alternating
        -- trigger conditions: (a) both sides hit, OR (b) 2+ corrections (enemy known to switch)
        local both_hit = (s.samples_left or 0) >= 1 and (s.samples_right or 0) >= 1
        local corr_total = (s.correction_left or 0) + (s.correction_right or 0)
        local used_measured = false   -- V9.22: track if we picked side from real data
        if s.aa_type == "switch" and (both_hit or corr_total >= 2) then
            -- V9.19: dom-bias — prefer dom if it leads by 2+, else alternate
            side = alt_side_pick(s)
            if side == 0 then
                if s.last_hit_side > 0 then side = -1
                elseif s.last_hit_side < 0 then side = 1
                else side = 1 end
            end
            s.mode = "Predicted-Alt"
            used_measured = true
        elseif s.hit_streak_left + s.hit_streak_right >= 1 then
            if s.hit_streak_right >= s.hit_streak_left then
                side = 1
            else
                side = -1
            end
            s.mode = "Predicted-Streak"
            used_measured = true
        else
            local move_yaw = math.deg(math.atan2(vy, vx))
            local rel = NormalizeAngle(move_yaw - eye_yaw)
            side = sign(rel) * -1
        end
        -- defensive-AA: invert + V9.3 use def_delta fingerprint
        if s.defensive_aa and exp_def_aa and exp_def_aa:get() then
            side = -side
            s.mode = s.mode .. "-DefInv"
            -- V9.3: if we learned the def-AA jump magnitude, use it directly
            if (s.def_samples or 0) >= 2 and (s.def_delta or 0) > 10 then
                return eye_yaw + s.def_delta * side
            end
        end
        -- V9.22 FIX: recompute desync using chosen side's measured value when
        -- available. The top-of-function `desync` was computed with `guess_side`
        -- (last_hit_side) — Predicted-Alt and -Streak pick different sides so the
        -- magnitude was wrong (e.g. dom-R enemy with sr=4/36° was getting preset
        -- max_desync=58° instead of the 36° we measured). Drop the 0.85 mult on
        -- measured paths — undershooting an already-correct angle = miss.
        local pick_desync = used_measured
            and effective_desync(s, max_desync, side)
            or  desync
        local mult = used_measured and 1.0 or (close and 1.0 or 0.85)
        return eye_yaw + pick_desync * side * mult
    end

    -- static enemy / fallback: try networked yaw, with same boost-fallback as static-class
    local sy = RebuildServerYaw(p) or eye_yaw  -- V9.32: nil=fail → eye_yaw → guess
    local sy_delta = NormalizeAngle(sy - eye_yaw)
    if math.abs(sy_delta) >= 5 then
        if s.desync_samples >= 2 and s.measured_desync > math.abs(sy_delta) then
            -- measured suggests bigger desync — boost to measured magnitude, keep side
            local side = sy_delta >= 0 and 1 or -1
            -- V9.77: side-conflict guard. RebuildServerYaw's side can be WRONG on a hard
            -- one-sided enemy (real-dump idx=5: streak L=20 R=0, rebuild said R → boosted
            -- 29° R twice → 0/2). When learned dom (real hits / streak only) strongly
            -- contradicts, trust dom + use its per-side magnitude.
            local mag = s.measured_desync
            local dom = learned_dom_side(s)
            if dom ~= 0 and dom ~= side then
                side = dom
                mag = effective_desync(s, max_desync, side)
            end
            s.mode = "Networked-Boost"
            return eye_yaw + mag * side
        end
        s.mode = "Networked"
        return sy
    end
    -- server-yaw too weak: use measured if available (V9.24: 2→1), else streak/default
    if (s.desync_samples or 0) >= 1 and (s.measured_desync or 0) > 5 then
        local side = s.last_hit_side ~= 0 and s.last_hit_side or 1
        s.mode = "Networked-Meas"
        return eye_yaw + s.measured_desync * side
    end
    -- V6.5: fall-through guess — ALWAYS offset from eye (never goal=eye)
    -- Cache chosen side PER ENGAGEMENT (until missed-count changes)
    -- Prevents 64×/sec side-flip oscillation
    local side
    if s.guess_cached_side and s.guess_cached_miss == s.missed then
        side = s.guess_cached_side  -- reuse engagement choice
    elseif s.last_hit_side ~= 0 then
        side = s.last_hit_side
    elseif s.hit_streak_right ~= s.hit_streak_left then
        side = s.hit_streak_right > s.hit_streak_left and 1 or -1
    else
        -- truly unknown: pick once per engagement (not per resolve)
        -- use yaw_rate sign as hint — player spinning RIGHT often has AA LEFT
        if s.yaw_rate and math.abs(s.yaw_rate) > 30 then
            side = s.yaw_rate > 0 and -1 or 1
        else
            s._eng_count = (s._eng_count or 0) + 1
            side = (s._eng_count % 2 == 0) and 1 or -1
        end
    end
    s.guess_cached_side = side
    s.guess_cached_miss = s.missed
    s.mode = "Networked-Guess"
    return eye_yaw + adaptive_guess_mag() * side
end

-- wrapper: caches first-shot result for ~150ms to prevent branch oscillation
local function pick_first_shot_angle(p, s, anim, eye_yaw, max_desync, preset)
    local now_ct = tick_cache.curtime or 0
    -- V6: validate cache — don't reuse if cached angle == cached eye (no desync attempted, useless)
    if s.fs_cached_time and (now_ct - s.fs_cached_time) < 0.15
       and s.fs_cached_eye and math.abs(NormalizeAngle(eye_yaw - s.fs_cached_eye)) < 20
       and s.fs_cached_angle ~= nil
       and math.abs(NormalizeAngle(s.fs_cached_angle - s.fs_cached_eye)) >= 5 then
        s.mode = s.fs_cached_mode
        return s.fs_cached_angle
    end
    local angle = _pick_first_shot_impl(p, s, anim, eye_yaw, max_desync, preset)
    s.fs_cached_time  = now_ct
    s.fs_cached_eye   = eye_yaw
    s.fs_cached_angle = angle
    s.fs_cached_mode  = s.mode
    return angle
end

local function pick_bruteforce_angle(s, anim, eye_yaw, max_desync, p, preset)
    -- BF-CACHE: only recompute when miss-count changes OR eye drifted significantly
    -- (V6.5: spinning enemies move eye 100°+ between ticks → cached goal becomes useless)
    if s.bf_cached_missed == s.missed and s.bf_cached_angle ~= nil
       and s.bf_cached_eye and math.abs(NormalizeAngle(eye_yaw - s.bf_cached_eye)) < 20 then
        s.mode = s.bf_cached_mode
        return s.bf_cached_angle
    end

    -- V9.38: if the previous ack looked like a correct-angle server/backtrack
    -- reject, retry that exact side/magnitude once before normal BF cycling.
    if s.serverfail_retry_side and s.serverfail_retry_miss == s.missed
       and (s.serverfail_retry_until or 0) >= (globals.tickcount or 0) then
        local side = s.serverfail_retry_side
        -- FIX #2: BF:retry cap. The same side+mag retry can jitter without converging on a
        -- static enemy we already measured (logs idx=2: our 42.7→43.3→38.2→50.9 vs meas 41.6,
        -- missCount 4). After 2 consecutive correct-angle keeps (serverfail_streak>=2) with
        -- samples, stop retrying and COMMIT the measured desync directly (Static-Meas) —
        -- repeated correct-angle fails on a static enemy are netcode, jittering only hurts.
        if s.aa_type == "static" and (s.desync_samples or 0) > 0 and (s.serverfail_streak or 0) >= 2 then  -- FIX #2
            local cmag = effective_desync(s, max_desync, side)  -- FIX #2
            if cmag >= 5 then
                if cmag > 58 then cmag = 58 end
                resolver_clear_serverfail_retry(s)
                local cres = eye_yaw + cmag * side
                s.mode = "Static-Meas"  -- FIX #2: commit measured, stop BF jitter
                s.bf_cached_missed = s.missed
                s.bf_cached_angle  = cres
                s.bf_cached_mode   = s.mode
                s.bf_cached_eye    = eye_yaw
                return cres
            end
        end
        local mag = s.serverfail_retry_mag or effective_desync(s, max_desync, side)
        -- V9.62: USE-SITE guard against a stale/poisoned retry magnitude (V9.44 fixed the
        -- SETTER; this guards the GETTER). If we hold a learned per-side desync and the
        -- stored retry mag deviates >15° from it, the stored value is suspect (slot reuse /
        -- a poisoned value from an earlier engagement) — trust current learning instead.
        -- Caught idx=11: BF:retry fired -44.5° on a proven 25.4° enemy (learned L=24.9°),
        -- a 19.6° overshoot whose origin wasn't derivable from the shot's own data.
        local cur = effective_desync(s, max_desync, side)
        if cur > 5 and math.abs(mag - cur) > 15 then mag = cur end
        if mag > 58 then mag = 58 end
        if mag >= 5 then
            local result = eye_yaw + mag * side
            s.mode = "BF:retry"
            s.bf_cached_missed = s.missed
            s.bf_cached_angle  = result
            s.bf_cached_mode   = s.mode
            s.bf_cached_eye    = eye_yaw
            return result
        end
    end

    -- V7.8: static / slow-walker → finer BF cycle
    -- V9.5: defensive_aa with def_delta fingerprint → use learned magnitude
    local bf_list = preset.bruteforce
    -- V9.79: REAL-hit one-sided detection, computed once for ALL non-defensive paths.
    -- V9.78 only reordered the static/slow branch, but this lobby's one-sided enemies
    -- are aa=switch (idx=8 real 10R/0L still fired BF:opposite LEFT; idx=12 9R/0L fired
    -- BF:opposite LEFT) — switch fell through to preset.bruteforce (opposite-first). A
    -- >=3-vs-0 real split is a confirmed lock regardless of AA-class: 10 hits all R,
    -- never once L = "opposite" is a near-guaranteed whiff. A GENUINE alternator has
    -- real hits on both sides (idx=6 L=2 R=1) → one_sided stays false → opposite-first
    -- preserved (V9.63 switch sweep).
    local rl, rr = s.real_left or 0, s.real_right or 0
    local one_sided = (rl >= 3 and rr == 0) or (rr >= 3 and rl == 0)
    if s.defensive_aa and s.aa_type ~= "jitter" and (s.def_samples or 0) >= 1 and (s.def_delta or 0) > 10 then
        -- DEF-AA enemy jumps ~def_delta post-fire. Try learned magnitude both sides + variants.
        local dd = math.floor(s.def_delta)
        -- V9.80: def_delta can latch a LONE fingerprint sample (idx=10 seeded 57.8° from a
        -- single spread-miss while per-side measured R was 45° → BF:def+ fired 57° = 12°
        -- overshoot whiff). Cap dd toward the dominant per-side measured when that side has
        -- real data, so the def cycle can't overshoot a magnitude we already learned.
        local meas_dom = math.max(s.measured_left or 0, s.measured_right or 0)
        if meas_dom > 5 and dd > meas_dom + 10 then dd = math.floor(meas_dom + 10) end
        -- V9.80: order the def cycle by REAL-hit dominance (mirrors the one_sided fix below).
        -- A ratio-dominant def enemy (idx=10 real R=5 L=1: not one_sided since L≠0, but 5:1 is
        -- a clear lean) wasted shots — old fixed {def+,def-,opposite,...} tried the wrong
        -- sign + flipped to the near-never side (BF:opposite 0%, BF:+58 0%). Lead the proven
        -- side's def magnitude, demote opposite + the weak-side guess to the tail.
        local rl, rr = s.real_left or 0, s.real_right or 0
        if (rr >= 3 and rr >= 3 * rl) or (rl >= 3 and rl >= 3 * rr) then
            local d = (rr > rl) and "+" or "-"
            local o = (d == "+") and "-" or "+"
            bf_list = {"def" .. d, "def" .. d .. "wide", d .. "58", d .. "45", "def" .. o, "opposite", "0"}
        else
            bf_list = {"def+", "def-", "opposite", "def+wide", "def-wide", "+58", "-58", "0"}
        end
        -- store dynamic magnitude in state for use below
        s.bf_def_delta = dd
    elseif s.defensive_aa and s.aa_type == "jitter" and (s.def_samples or 0) >= 1 and (s.def_delta or 0) > 10 then
        -- V9.74: jitter AA oscillates between two yaw positions — there is NO stable
        -- 'defensive delta'. The def_delta cycle (BF:def+) fires fixed angular offsets
        -- from a defensive fingerprint that don't match jitter's oscillation, so it kept
        -- whiffing (v9.73 idx=3 BF:def+ 0/1) while BF:opposite (full opposite hemisphere)
        -- is what actually catches jitter. Skip the def cycle and fall through to the
        -- standard BF oscillation (preset.bruteforce → reaches BF:opposite).
        cs_log_verbose("BF:def+ skipped — jitter AA, def_delta cycle inapplicable idx=" .. (p and p:get_index() or -1))
    elseif one_sided then
        -- V9.78/V9.79: order by REAL-hit dominance, ANY non-defensive aa_type. "opposite"
        -- as the first BF guess flips onto -last_shot_side = the side a firmly one-sided
        -- enemy has NEVER been on = a guaranteed whiff. Sweep MAGNITUDE on the proven
        -- dominant side first and demote "opposite" to last.
        local sgn = (rl > rr) and "-" or "+"   -- dominant real side sign
        bf_list = {sgn.."58", sgn.."45", sgn.."35", sgn.."29", sgn.."20", "0", "opposite"}
    elseif s.is_slow_target or s.aa_type == "static" then
        -- static/slow but NOT one-sided (balanced or unknown) → opposite-first sweep.
        bf_list = {"opposite", "+58", "-58", "+45", "-45", "+35", "-35", "+29", "-29", "+20", "-20", "0"}
    end

    local idx = ((s.missed - 1) % #bf_list) + 1
    local kind = bf_list[idx]
    s.mode = "BF:" .. kind

    -- determine side for per-side desync lookup
    local kind_side
    if     kind == "desync"  or kind == "+58" or kind == "+45" or kind == "+35" or kind == "+29" or kind == "+20" or kind == "+15" then kind_side = 1
    elseif kind == "-desync" or kind == "-58" or kind == "-45" or kind == "-35" or kind == "-29" or kind == "-20" or kind == "-15" then kind_side = -1
    elseif kind == "opposite" then
        -- V9.63: "opposite" must invert the side WE JUST SHOT (last_shot_side), not
        -- -last_hit_side. On a switcher a correction-flip sets last_hit_side to the
        -- believed-correct side; the old `-last_hit_side` then shot straight back onto
        -- the just-tried wrong side and the next ack flipped again → L/R lock-loop
        -- (logs: idx=3 Recall +41.9 MISS→flip L, BF:opposite +24.4 R again, +58 R again,
        -- all while the enemy sat on R). Keying off last_shot_side makes opposite a real
        -- alternation: shot R → try L → shot L → try R, so BF actually sweeps both sides.
        kind_side = s.last_shot_side ~= 0 and -s.last_shot_side
                    or (s.last_hit_side ~= 0 and -s.last_hit_side or 1)
    end
    local desync = effective_desync(s, max_desync, kind_side)

    local result
    if kind == "opposite" then
        -- V9.31: do NOT write s.last_hit_side here — BF runs while GUESSING
        -- (s.missed>0); no hit confirmed this side. Mutating the confirmed-hit
        -- side memory corrupts every other path's side pick → L/R oscillation.
        result = eye_yaw + desync * kind_side
    elseif kind == "desync"   then result = eye_yaw + desync
    elseif kind == "-desync"  then result = eye_yaw - desync
    elseif kind == "+58"      then result = eye_yaw + 58
    elseif kind == "-58"      then result = eye_yaw - 58
    elseif kind == "+45"      then result = eye_yaw + 45
    elseif kind == "-45"      then result = eye_yaw - 45
    elseif kind == "+35"      then result = eye_yaw + 35
    elseif kind == "-35"      then result = eye_yaw - 35
    elseif kind == "+29"      then result = eye_yaw + 29
    elseif kind == "-29"      then result = eye_yaw - 29
    elseif kind == "+20"      then result = eye_yaw + 20
    elseif kind == "-20"      then result = eye_yaw - 20
    elseif kind == "+15"      then result = eye_yaw + 15
    elseif kind == "-15"      then result = eye_yaw - 15
    elseif kind == "0"        then result = eye_yaw
    elseif kind == "lby"      then result = p.m_flLowerBodyYawTarget or eye_yaw
    -- V9.5: defensive-AA dynamic magnitudes
    elseif kind == "def+"     then result = eye_yaw + (s.bf_def_delta or 45)
    elseif kind == "def-"     then result = eye_yaw - (s.bf_def_delta or 45)
    elseif kind == "def+wide" then result = eye_yaw + (s.bf_def_delta or 45) + 15
    elseif kind == "def-wide" then result = eye_yaw - (s.bf_def_delta or 45) - 15
    else                            result = eye_yaw
    end

    -- cache (V6.5: also cache eye for drift invalidation)
    s.bf_cached_missed = s.missed
    s.bf_cached_angle  = result
    s.bf_cached_mode   = s.mode
    s.bf_cached_eye    = eye_yaw
    return result
end

-- ─── per-tick caches (perf) ─────────────────────────────
local anim_cache, anim_cache_tick = {}, -1
local function GetAnimStateCached(p)
    local tick = globals.tickcount or 0
    if tick ~= anim_cache_tick then
        anim_cache, anim_cache_tick = {}, tick
    end
    local idx = p:get_index()
    local c = anim_cache[idx]
    if c == nil then
        c = GetAnimState(idx) or false
        anim_cache[idx] = c
    end
    return c
end

-- tick_cache already forward-declared at top; here just reset fields if needed
tick_cache.tick      = -1
tick_cache.curtime   = 0
tick_cache.frametime = 0
tick_cache.tickint   = 1/64
tick_cache.lp        = nil
tick_cache.lp_yaw    = 0
tick_cache.lp_ox     = 0
tick_cache.lp_oy     = 0
tick_cache.lp_oz     = 0
tick_cache.valid     = false
tick_cache.ping_ms   = 0
tick_cache.wc        = nil    -- V9.9-E: weapon-class cache (avoid repeated FFI in ragebot_target hot-path)
tick_cache.lp_ducking= false  -- V9.9-C: local crouch flag
local function refresh_tick_cache()
    local tick = globals.tickcount or 0
    if tick == tick_cache.tick then return tick_cache.valid end
    tick_cache.tick      = tick
    tick_cache.curtime   = globals.curtime  or 0
    tick_cache.frametime = globals.frametime or 0
    tick_cache.tickint   = globals.tickinterval or (1/64)
    -- V9.71 perf: UI reads cached once per tick (were per-enemy per-tick :get() calls
    -- in resolve_player — N enemies × 64Hz × menu-API roundtrip)
    pcall(function()
        tick_cache.ui_close_range  = close_range_dist:get()
        tick_cache.ui_air_resolve  = air_resolve_tog:get()
        tick_cache.ui_aa_classify  = (exp_aa_classify and exp_aa_classify:get()) or false
        tick_cache.ui_classify_int = (exp_classify_int and exp_classify_int:get()) or 1
    end)
    local lp = entity.get_local_player()
    tick_cache.lp = lp
    tick_cache.wc = nil  -- invalidate every tick — weapon may swap mid-tick (edge-case rare but cheap)
    if lp then
        local ang_ok, ang = pcall(function() return lp:get_angles() end)
        tick_cache.lp_yaw = (ang_ok and ang and ang.y) or 0
        local origin_ok = pcall(function()
            tick_cache.lp_ox = lp.m_vecOrigin.x
            tick_cache.lp_oy = lp.m_vecOrigin.y
            tick_cache.lp_oz = lp.m_vecOrigin.z
        end)
        tick_cache.valid = origin_ok
        -- V9.3: get local ping (multiple NL API fallback patterns)
        local ping = 0
        pcall(function() ping = client.latency() * 1000 end)
        if ping == 0 then pcall(function() ping = (lp.m_iPing or 0) end) end
        if ping == 0 then pcall(function() ping = (entity.get_local_player_ping and entity.get_local_player_ping()) or 0 end) end
        if ping > 0 and ping < 500 then tick_cache.ping_ms = ping
        else tick_cache.ping_ms = 0 end
    else
        tick_cache.valid = false
    end
    return tick_cache.valid
end

-- V9.33 EXPERIMENTAL: read animated body-yaw pose param → desync side (+ right /
-- - left). GLOBAL (200-local cap). m_flPoseParameter[] is exposed by NL but the
-- desync index/mapping is undocumented — [11] + (v*120-60) is a best-guess and must
-- be A/B validated. pcall-guarded; returns nil on failure → caller keeps coin-flip.
function read_pose_desync(p)
    local ok, v = pcall(function() return p.m_flPoseParameter[11] end)
    if not ok or type(v) ~= "number" then return nil end
    local deg = v * 120 - 60
    if math.abs(deg) < 3 or math.abs(deg) > 62 then return nil end
    return deg
end

local function resolve_player(p)
    if not can_resolve(p) then return end

    local s = get_state(p)
    refresh_tick_cache()
    local now = tick_cache.curtime

    -- V9.2: decay measured_desync when player idle 60s+ (handles AA-config switch mid-match)
    if s.last_seen > 0 and s.measured_desync > 0 then
        local idle = now - s.last_seen
        if idle > 60 then
            -- gentle decay 5% per 60s idle, keeps high samples relevant longer
            local decay_factor = math.max(0.5, 1 - (idle - 60) * 0.001)
            s.measured_desync = s.measured_desync * decay_factor
            s.measured_left   = (s.measured_left or 0) * decay_factor
            s.measured_right  = (s.measured_right or 0) * decay_factor
        end
    end
    -- dormancy reset: re-engagement = fresh state
    if s.last_seen > 0 and (now - s.last_seen) > (dormancy_reset_t:get() / 1000) then
        reset_state(s)
        -- boot last_hit_side from steam-memory if available
        local mem = get_steam_mem(p)
        if mem and mem.dominant_side ~= 0 then
            s.last_hit_side = mem.dominant_side
            cs_log_verbose("Steam mem boot idx=%d side=%d", p:get_index(), mem.dominant_side)
        end
        -- V4: boot from persistent LearnedModel (richer data, across sessions)
        local lrn = learning_lookup(p)
        -- V9.33: nil-coalesce learned fields. A partial/old/hand-edited learned.lua
        -- entry with a missing field would throw on the arithmetic and silently abort
        -- the whole resolve (boot is pcall'd), leaving the enemy unresolved that tick.
        local lsl, lsr = (lrn and lrn.sl or 0), (lrn and lrn.sr or 0)
        local ldl, ldr = (lrn and lrn.dl or 0), (lrn and lrn.dr or 0)
        if lrn and (lsl + lsr) >= 5 then
            -- FIX #5: don't clobber session-learned data on re-track. reset_state keeps
            -- measured_left/right + real_* (only transient counters wiped), but this boot
            -- overwrote the live per-side EMAs with the OLDER persistent LearnedModel values
            -- on every dormancy re-engagement, wiping mid-session learning momentum (logs:
            -- LearnedModel boot idx=1/2 firing 3-4× per session). When we already hold REAL
            -- session hits on a side, keep the live EMA; only fill sides not yet learned.
            local _has_sess_l = (s.real_left  or 0) >= 1  -- FIX #5
            local _has_sess_r = (s.real_right or 0) >= 1  -- FIX #5
            if (lrn.dom or 0) ~= 0 and not (_has_sess_l or _has_sess_r) then s.last_hit_side = lrn.dom end  -- FIX #5: keep session side
            if lsl >= 2 and ldl > 0 and not _has_sess_l then  -- FIX #5: keep session L EMA
                s.measured_left = ldl
                s.samples_left  = math.min(lsl, 10)
            end
            if lsr >= 2 and ldr > 0 and not _has_sess_r then  -- FIX #5: keep session R EMA
                s.measured_right = ldr
                s.samples_right  = math.min(lsr, 10)
            end
            -- V9.81: RESTORE REAL-HIT DOMINANCE. The saved sl/sr ARE real hit counts
            -- (learning_update_hit only bumps them on a confirmed hit), but boot never
            -- seeded s.real_left/right — so a known 17-hit enemy rebooted with real_right=0
            -- and EVERY dominance path treated it as a fresh seed: one_sided BF ordering
            -- (needs real>=3), alt_side_pick real-dominance, and the confidence real-weight
            -- cap all stayed off. Magnitude + side recalled; the "this enemy is locked one
            -- side" knowledge did NOT. Persisted hits are genuine prior-session hits, so
            -- count them as real. Seed when we hold no session real hit on that side yet.
            if not _has_sess_l and lsl >= 1 then s.real_left  = math.min(lsl, 10) end
            if not _has_sess_r and lsr >= 1 then s.real_right = math.min(lsr, 10) end
            if s.measured_desync == 0 then
                local total = lsl + lsr
                if total > 0 then
                    s.measured_desync = (ldl * lsl + ldr * lsr) / total
                    s.desync_samples  = math.min(total, 10)
                end
            end
            -- V6: boot best_modes (per-aa-type historically best mode for this player)
            s.boot_best_modes = {
                jitter  = lrn.best_jitter,
                static  = lrn.best_static,
                switch  = lrn.best_switch,
                spinner = lrn.best_spinner,
            }
            -- V8.9: throttle boot log — only log if 10s+ since last (prevent spam on dormancy churn)
            -- V9.72: throttle keyed OUTSIDE PlayerState — the dormancy reset RECREATES s,
            -- wiping s.last_boot_log, so peek-flicker logged the same boot 3× (real-dump).
            sel01_boot_log_t = sel01_boot_log_t or {}
            local now_rt = globals.realtime or 0
            local _bidx = p:get_index()
            if (now_rt - (sel01_boot_log_t[_bidx] or 0)) > 10 then
                sel01_boot_log_t[_bidx] = now_rt
                cs_log_verbose("LearnedModel boot idx=%d L=%d(%.1f°) R=%d(%.1f°) dom=%d hits=%d best{j=%s s=%s sw=%s}",
                               p:get_index(), lsl, ldl, lsr, ldr, (lrn.dom or 0), lrn.hits or 0,
                               tostring(lrn.best_jitter), tostring(lrn.best_static), tostring(lrn.best_switch))
            end
        end
    end
    s.last_seen = now

    -- FOV + distance cull (perf, skip offscreen/far enemies)
    if tick_cache.valid then
        local dx = p.m_vecOrigin.x - tick_cache.lp_ox
        local dy = p.m_vecOrigin.y - tick_cache.lp_oy
        local dz = p.m_vecOrigin.z - tick_cache.lp_oz
        local dist_sq = dx*dx + dy*dy + dz*dz
        if dist_sq > 4500 * 4500 then
            cs_log_verbose("CULL distance idx=%d", p:get_index())
            return
        end
        s.tmp_dist = math.sqrt(dist_sq)
        s.tmp_close = s.tmp_dist < (tick_cache.ui_close_range or 700)  -- V9.71: per-tick cached
        -- V9.31: clear a stale hostile-fire mark for out-of-range enemies (the
        -- weapon_fire handler no longer range-gates — it cannot read enemy origin
        -- safely). Done here, where the distance is already computed safely.
        if s.tmp_dist >= 3500 and (s.last_hostile_fire or 0) > 0 then s.last_hostile_fire = 0 end

        local to_yaw = math.deg(math.atan2(dy, dx))
        local fov = math.abs(NormalizeAngle(to_yaw - tick_cache.lp_yaw))
        if fov > 110 then
            cs_log_verbose("CULL fov=%d idx=%d", math.floor(fov), p:get_index())
            return
        end
    else
        s.tmp_dist = 0
        s.tmp_close = false
    end

    local anim = GetAnimStateCached(p)
    if not anim or anim == false then return end

    -- V9.74: a scheduled BF:retry (from the server-fail KEEP path) is consumed ONLY
    -- inside pick_bruteforce_angle, which the air-branch below short-circuits with an
    -- unconditional `return`. So when an enemy went airborne the same tick a retry was
    -- pending, the air-branch ate the tick and the kept-side retry never fired (v9.73
    -- idx=14: KEEP scheduled, logged mode=Air not BF:retry). Skip the air-branch while
    -- a retry is pending so pick_bruteforce_angle runs and shoots the learned kept-side
    -- magnitude — airborne enemies keep their desync, so eye_yaw+mag*side is valid in air.
    local bf_retry_pending = s.serverfail_retry_side
        and s.serverfail_retry_miss == s.missed
        and (s.serverfail_retry_until or 0) >= (globals.tickcount or 0)
    -- airborne: enemies still have desync in air. Use server-yaw reconstruction
    -- (old approach assumed 0 desync → broke on nospread)
    if tick_cache.ui_air_resolve and not anim.m_bOnGround and not bf_retry_pending then  -- V9.71: per-tick cached; V9.74: yield to pending BF:retry
        s.mode = "Air"
        -- V9.34: keep yaw_cache / yaw_rate warm during air-time. The air-branch used
        -- to return BEFORE update_jitter ran, so the jitter buffer went stale (wrong
        -- aa_type the moment they land) and air-spin was invisible. pcall-guarded inside.
        update_jitter(p, s)
        local server_yaw = RebuildServerYaw(p) or anim.m_flEyeYaw  -- V9.32: nil=fail → eye_yaw
        -- V9.75: AIR magnitude boost — port of the ground Networked-Boost (which hits
        -- 4/4 = 100% in real dumps). RebuildServerYaw returns a reliable SIDE but an
        -- undershot magnitude in air (it samples a mid-flight feet-yaw). When we know a
        -- LARGER air magnitude (measured EMA or passive-seeded) keep the rebuilt side and
        -- boost to it. Applied to the RAW rebuild BEFORE the side-specific blocks below —
        -- those overwrite server_yaw when they fire, so this only survives in the
        -- trust-rebuild fall-through (the never-hit-but-passively-known air enemy that the
        -- corr-aware/both-sides/cold blocks all skip). Logs: idx=9 passive/measured 33.9°,
        -- rebuild gave +15° R (correct side, 18.9° short) → missed; boost → on-target.
        do
            local _km = ((s.measured_desync or 0) > 5 and s.measured_desync)
                     or (math.max(s.passive_left or 0, s.passive_right or 0) > 5
                         and math.max(s.passive_left or 0, s.passive_right or 0)) or 0
            if _km > 5 then
                local _syd = NormalizeAngle(server_yaw - anim.m_flEyeYaw)
                if math.abs(_syd) >= 5 and _km > math.abs(_syd) + 5 then
                    _km = math.min(_km, 58)
                    local _bside = (_syd >= 0 and 1 or -1)
                    -- V9.77: same side-conflict guard as ground Networked-Boost. dom is 0
                    -- for the passive-only never-hit case this boost targets (idx=9), so the
                    -- rebuild side stays; only a REAL one-sided enemy vetoes a wrong side.
                    local _dom = learned_dom_side(s)
                    if _dom ~= 0 and _dom ~= _bside then _bside = _dom end
                    server_yaw = anim.m_flEyeYaw + _km * _bside
                    cs_log_verbose("air-boost idx=%d side=%d rebuild=%.1f → mag=%.1f",
                                   p:get_index(), _bside, _syd, _km)
                end
            end
        end
        -- V8.2: switch-AA alternate (both sides hit) → use opposite of last hit
        local both_air = (s.samples_left or 0) >= 1 and (s.samples_right or 0) >= 1
        -- V9.37: best side we know even without a confirmed hit (steam dom → +1), and a
        -- HIGH air magnitude prior. Airborne enemies can't move-desync, so they sit near
        -- their max/static desync — Air was the WORST mode (25%) because first-contact
        -- guesses used the lobby median (~30) and undershot the ~42-58° air enemies, and
        -- the side was a blind +1 coin-flip even when steam-memory knew the dom side.
        local air_side = s.last_hit_side
        if air_side == 0 then
            local _mem = get_steam_mem(p)
            air_side = (_mem and _mem.dominant_side ~= 0 and _mem.dominant_side) or 1
        end
        -- V9.41: air-guess magnitude is now PER-PLAYER passive-aware. The v9.37 blind
        -- floor of max(session_median, 42) overshot low-desync air enemies badly
        -- (logs: idx=3 guessed 42/45, real was 12.4 → 30° miss) and ignored the
        -- per-player passive observation we already accumulate (idx=6 had 57 passive
        -- obs of its real ~45° desync, unused). Prefer this enemy's own measured /
        -- passive-seeded magnitude; only fall to the high blind floor when truly cold
        -- (under the 8-obs passive-seed threshold), and soften that floor 42→36.
        local air_guess_mag
        local _pmax = math.max(s.passive_left or 0, s.passive_right or 0)
        if (s.measured_desync or 0) > 5 then
            air_guess_mag = s.measured_desync
        elseif _pmax > 5 then
            air_guess_mag = _pmax
        else
            air_guess_mag = math.max(adaptive_guess_mag(), 36)
        end
        -- FIX #3: cold-air gate. Air corr/alt logic needs a measured side+magnitude; with
        -- zero hit-EMA AND no passive baseline, RebuildServerYaw is the only signal and it's
        -- unreliable in air, so Air fired garbage (logs: Air eye=111.4 res=138.9 delta=27.4
        -- measDesync=0 samples=0 MISS; Air 50% rate). When cold, explore by alternating side
        -- per miss-count (BF:opposite style) at the high air prior instead of committing a
        -- single trusted Air angle — gated below right before the eye-yaw guard.
        local air_cold = (s.desync_samples or 0) == 0 and (s.measured_desync or 0) <= 5
                         and math.max(s.passive_left or 0, s.passive_right or 0) <= 5  -- FIX #3
        if s.aa_type == "switch" and both_air and s.last_hit_side ~= 0 then
            -- V9.19: dom-bias for Air-Alt — prefer dom if it leads by 2+
            local side = alt_side_pick(s)
            if side == 0 then side = -s.last_hit_side end
            local mag = (side > 0 and s.measured_right > 5) and s.measured_right
                     or (side < 0 and s.measured_left > 5)  and s.measured_left
                     or s.measured_desync
            server_yaw = anim.m_flEyeYaw + mag * side
            s.mode = "Air-Alt"
        -- correction-aware: if recent corrections on one side, flip
        elseif s.measured_desync > 0 and s.last_hit_side ~= 0 then
            local side = s.last_hit_side
            local corr_diff = (s.correction_right or 0) - (s.correction_left or 0)
            -- V9.64: don't corr-flip in AIR on a confirmed two-side switcher / bimodal
            -- enemy. Both sides get real hits at very different magnitudes (logs: idx=3
            -- L=2/23.6° R=2/51.1°, idx=6 L=2/7.6° R=2/29.3°); the corr_diff flip just
            -- chases the enemy's own alternation and then fires the FAR-side magnitude on
            -- the freshly-flipped side (idx=3 shot 51.1° vs meas 23.6, idx=6 29.3° vs 7.6).
            -- Air-CorrFlip was the worst mode at 0/2. Mirrors the V9.63 ground-path
            -- two_side_switcher KEEP — treat the miss as MAGNITUDE, let BF cycle cover both.
            local _ra = (s.real_left or 0) + (s.real_right or 0)
            local _two_side = (_ra >= 2 and (s.real_left or 0) >= 1 and (s.real_right or 0) >= 1)
                              or (s.bimodal == true)
            if (not _two_side) and math.abs(corr_diff) >= 1 and side ~= 0 then
                -- if we keep correction-missing on dominant side, flip
                if (side > 0 and corr_diff > 0) or (side < 0 and corr_diff < 0) then
                    side = -side
                    s.mode = "Air-CorrFlip"
                end
            end
            -- V9.34: per-side magnitude (was global measured_desync — wrong for
            -- bimodal / per-side enemies; same class as the v9.22 ground fix).
            local mag = (side > 0 and (s.measured_right or 0) > 5) and s.measured_right
                     or (side < 0 and (s.measured_left or 0) > 5)  and s.measured_left
                     or s.measured_desync
            server_yaw = anim.m_flEyeYaw + mag * side
        end
        -- FIX #3: cold air → force the alternating guess (do NOT trust RebuildServerYaw).
        if air_cold then
            local cside = air_side
            if (s.missed or 0) > 0 then cside = ((s.missed % 2) == 1) and -air_side or air_side end  -- FIX #3: BF:opposite by miss-count
            server_yaw = anim.m_flEyeYaw + air_guess_mag * cside
            s.mode = ((s.missed or 0) > 0) and "Air-BFGuess" or "Air-Guess"  -- FIX #3
        end
        -- V9.6+V9.19: never resolve to exact eye_yaw — offset by adaptive median
        if math.abs(NormalizeAngle(server_yaw - anim.m_flEyeYaw)) < 5 then
            local fallback_side = air_side
            s.mode = "Air-Guess"
            -- V9.33 EXPERIMENTAL pose-param side read (OFF default; A/B test point).
            if pose_read_tog and pose_read_tog:get() then
                local pd = read_pose_desync(p)
                if pd then fallback_side = (pd >= 0) and 1 or -1; s.mode = "Air-PoseGuess" end
            end
            -- V9.37: HIGH air magnitude prior (was the lobby median, which undershot air)
            server_yaw = anim.m_flEyeYaw + air_guess_mag * fallback_side
        end
        s.last_eye_yaw  = anim.m_flEyeYaw
        s.last_resolved = server_yaw
        -- V9.33: push to recent_resolved (mirrors the ground path) so cancel-conf's
        -- stddev gate + confidence() reflect AIR volatility, not stale ground data.
        local now_ct = tick_cache.curtime or 0
        -- V9.71 perf: circular ring, entry tables reused (zero alloc steady-state)
        local _ri = (s.recent_resolved_idx or 0) % 5 + 1
        s.recent_resolved_idx = _ri
        local _re = s.recent_resolved[_ri]
        if _re then _re.a = server_yaw; _re.t = now_ct
        else s.recent_resolved[_ri] = {a = server_yaw, t = now_ct} end
        anim.m_flGoalFeetYaw = NormalizeAngle(server_yaw)
        return
    end

    update_jitter(p, s)

    -- V7.8 + V8.4 + V9.7: slow-walker + fully-stationary detection
    -- slow-walker: velocity < 35 + yaw < 30 for 10+ ticks
    -- stationary: velocity < 5 + yaw < 5 for 8+ ticks (much tighter, completely still)
    -- V9.7: HARD-RESET both counters on big spike (>100°/s yaw or >50u/s velocity) — prevents stale flag for ~280ms after sudden break-out
    do
        local sp = 0
        pcall(function()
            local v = p.m_vecVelocity
            sp = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
        end)
        local yr = math.abs(s.yaw_rate or 0)
        local spike = yr > 100 or sp > 50
        if spike then
            s.slow_ticks = 0
            s.still_ticks = 0
        else
            if sp < 35 and yr < 30 then
                s.slow_ticks = math.min((s.slow_ticks or 0) + 1, 64)
            else
                s.slow_ticks = math.max((s.slow_ticks or 0) - 2, 0)
            end
            if sp < 5 and yr < 5 then
                s.still_ticks = math.min((s.still_ticks or 0) + 1, 64)
            else
                s.still_ticks = math.max((s.still_ticks or 0) - 3, 0)
            end
        end
        s.is_slow_target = (s.slow_ticks or 0) >= 10
        s.is_stationary  = (s.still_ticks or 0) >= 8
    end

    -- V9.46: TELEPORT-ON-PEEK detection. HvH peekers blink their networked origin
    -- (lag-switch / fakelag-flush / teleport-peek) so the body appears across a gap
    -- in one update. NL then backtracks to a STALE record — the live head has already
    -- moved, so a single-point shot at our (correct) resolved angle whiffs. Same root
    -- cause as the bt-driven backtrack_resistant path, just position-derived instead of
    -- ack-derived, so we can react on the FIRST peek instead of after 2 misses.
    -- We compare horizontal origin delta vs the max distance run speed allows over the
    -- elapsed time; a blink exceeds it by a wide margin. On detect: time-box a window
    -- that (a) disables extrapolation (predicted yaw across a teleport is garbage) and
    -- (b) forces full-spread multipoint at close range. It NEVER touches side/EMA, so
    -- the v9.45 seed-only fix + learned pattern stay intact (same player, same AA).
    do
        local now_rt = globals.realtime or 0
        local ox, oy = nil, nil
        pcall(function()
            local o = p.m_vecOrigin
            ox, oy = o.x, o.y
        end)
        if ox and s.prev_origin_x and s.prev_origin_t then
            local dt = now_rt - s.prev_origin_t
            if dt > 0 and dt < 0.5 then   -- only consecutive resolves
                local dxy = math.sqrt((ox - s.prev_origin_x)^2 + (oy - s.prev_origin_y)^2)
                local sp = 0
                pcall(function()
                    local v = p.m_vecVelocity
                    sp = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
                end)
                -- max plausible move + generous margin (16u) for netvar jitter
                local max_move = math.max(sp, 60) * dt + 16
                if dxy > max_move and dxy > 40 then
                    s.tp_peek_until = now_rt + 0.4
                    cs_log_verbose("TP-peek idx=%d dxy=%.0f max=%.0f dt=%.3f sp=%.0f → full-spread+no-extrap 0.4s",
                                   p:get_index(), dxy, max_move, dt, sp)
                end
            end
        end
        if ox then s.prev_origin_x, s.prev_origin_y, s.prev_origin_t = ox, oy, now_rt end
    end
    s.tp_peek_active = (s.tp_peek_until or 0) > (globals.realtime or 0)

    -- AA-classify periodically — V9.10: 7 consecutive + 2s lockout (V9.0 was 5+1s).
    -- User logs showed idx=14 committing static->jitter->static->jitter rapidly — too
    -- many false flips. Higher consecutive threshold + longer lockout stabilizes classification.
    -- Also: V9.10 anti-flap protection — if same player commits >3 times within 10s,
    -- freeze the classifier for 5s.
    if tick_cache.ui_aa_classify then  -- V9.71: per-tick cached
        local now_rt = globals.realtime or 0
        -- V9.61: sticky classification for well-learned enemies. Once we've HIT an enemy
        -- 4+ times (real_active), its AA type rarely changes mid-round — reclassifying it
        -- on borderline yaw_cache noise (eye-aim flicks misread as jitter) just thrashes the
        -- resolver mode/label every few seconds (logs: idx=5 still+slow enemy flapped
        -- jitter<->static 6+ times while hitting 4/4). The slow flap dodged the 10s anti-flap
        -- window. Cold enemies stay responsive (7 evals / 2s); learned ones need 14 evals + 4s
        -- lock to flip. measured_desync + side adapt independently, so slower aa_type ≠ worse aim.
        local well_learned = ((s.real_left or 0) + (s.real_right or 0)) >= 4
        local commit_lock = well_learned and 4.0 or 2.0
        local need_count  = well_learned and 14 or 7
        local commit_lock_active = (s.aa_committed_at or 0) > 0 and (now_rt - s.aa_committed_at) < commit_lock
        if s.aa_classify_cd <= 0 and not commit_lock_active then
            local new_type = classify_aa(s)
            if new_type == s.pending_aa_type then
                s.pending_aa_count = s.pending_aa_count + 1
                if s.pending_aa_count >= need_count and s.aa_type ~= new_type then
                    s.aa_type = new_type
                    s.aa_committed_at = now_rt
                    -- V9.10 anti-flap: track commits in 10s window; freeze 5s if >3
                    s.commit_history = s.commit_history or {}
                    table.insert(s.commit_history, now_rt)
                    while #s.commit_history > 0 and (now_rt - s.commit_history[1]) > 10 do
                        table.remove(s.commit_history, 1)
                    end
                    -- V9.76: oscillation-detect freeze. The 10s-window count above is DODGED
                    -- by slow flaps — a static<->switch<->static revert spread over >10s never
                    -- accumulates 4 entries (real-dump idx=3/7/11 flapped at long range on
                    -- yaw-cache noise; idx=7 mode-thrashed switch->static->switch into a miss
                    -- right after a hit). Detect the REVERT directly: committing back to a type
                    -- we just left (T_n == T_{n-2}, an A->B->A flap) is noise regardless of
                    -- timing → freeze. A genuine progression (static->switch->jitter) never
                    -- reverts, so a real AA change is untouched.
                    local osc = false
                    s.recent_committed_types = s.recent_committed_types or {}
                    for _, t in ipairs(s.recent_committed_types) do
                        if t == new_type then osc = true break end
                    end
                    table.insert(s.recent_committed_types, new_type)
                    while #s.recent_committed_types > 2 do table.remove(s.recent_committed_types, 1) end
                    if #s.commit_history > 3 or osc then
                        s.aa_committed_at = now_rt + 5  -- freeze 5s on top of normal lock
                        cs_log_verbose("aa_type FREEZE idx=%d → %s (%s)", p:get_index(), new_type,
                                       osc and "oscillation revert" or ">3 flaps/10s")
                    else
                        cs_log_verbose("aa_type commit idx=%d → %s", p:get_index(), new_type)
                    end
                end
            else
                s.pending_aa_type = new_type
                s.pending_aa_count = 1
            end
            s.aa_classify_cd = tick_cache.ui_classify_int or 1  -- V9.71: per-tick cached
        else
            s.aa_classify_cd = s.aa_classify_cd - 1
        end
    end

    local preset     = get_mode_preset()
    local eye_yaw    = anim.m_flEyeYaw
    local max_desync = GetMaxDesync(anim) * 58
    local angle

    if s.missed == 0 then
        angle = pick_first_shot_angle(p, s, anim, eye_yaw, max_desync, preset)
    else
        angle = pick_bruteforce_angle(s, anim, eye_yaw, max_desync, p, preset)
    end

    -- store for measured-desync learning in aim_ack
    s.last_eye_yaw  = eye_yaw
    s.last_resolved = angle

    -- V3: recent-resolved ring buffer (last 5) for confidence detection
    local now_ct = tick_cache.curtime or 0
    -- V9.71 perf: circular ring, entry tables reused (zero alloc steady-state)
    local _ri = (s.recent_resolved_idx or 0) % 5 + 1
    s.recent_resolved_idx = _ri
    local _re = s.recent_resolved[_ri]
    if _re then _re.a = angle; _re.t = now_ct
    else s.recent_resolved[_ri] = {a = angle, t = now_ct} end

    -- V7.1: PASSIVE LEARNING — read server's predicted feet_yaw BEFORE override
    -- This is what the server actually computes for this enemy's desync, no shooting needed
    local ok_pass, server_goal_pre = pcall(function() return anim.m_flGoalFeetYaw end)
    if ok_pass and server_goal_pre then
        local server_desync = NormalizeAngle(server_goal_pre - anim.m_flEyeYaw)
        if math.abs(server_desync) >= 3 and math.abs(server_desync) <= 65 then
            -- accumulate passive samples (slower alpha than hit-EMA, lower weight)
            local p_side = server_desync > 0 and 1 or -1
            local p_mag  = math.abs(server_desync)
            -- V9.67 #B: the server's predicted feet-yaw gives the live fake side every
            -- tick — feed the switch-period detector so it can time the flips.
            if switch_pred_tog and switch_pred_tog:get() then
                pcall(switch_period_observe, s, p_side, globals.realtime or 0)
            end
            s.passive_samples = (s.passive_samples or 0) + 1
            if p_side > 0 then
                s.passive_right = s.passive_right and
                    (s.passive_right * 0.92 + p_mag * 0.08) or p_mag
                s.passive_n_right = (s.passive_n_right or 0) + 1  -- V9.72: per-side obs count
            else
                s.passive_left = s.passive_left and
                    (s.passive_left * 0.92 + p_mag * 0.08) or p_mag
                s.passive_n_left = (s.passive_n_left or 0) + 1   -- V9.72: per-side obs count
            end
            -- if no measured (no hit yet), seed measured_desync from passive after 8 obs
            if s.passive_samples >= 8 and s.desync_samples == 0 then
                s.measured_desync = math.max(s.passive_left or 0, s.passive_right or 0)
            end
            -- V8.0 + V9.1: stronger passive seeding — V9.1 noise floor 15° (was 5°)
            if s.passive_samples >= 20 and (s.samples_left or 0) + (s.samples_right or 0) == 0 then
                local pl, pr = s.passive_left or 0, s.passive_right or 0
                -- V9.1: don't seed from sub-15° passive (likely glancing/network noise)
                if pr > pl * 1.3 and pr >= 15 then
                    s.measured_right = pr; s.samples_right = 2
                    if s.last_hit_side == 0 then s.last_hit_side = 1 end
                elseif pl > pr * 1.3 and pl >= 15 then
                    s.measured_left = pl; s.samples_left = 2
                    if s.last_hit_side == 0 then s.last_hit_side = -1 end
                end
            end
            -- V8.6: persist passive observation to file (without needing a hit)
            -- After 30+ passive obs, write seed entry so next match remembers this enemy
            if s.passive_samples == 30 or (s.passive_samples > 30 and s.passive_samples % 60 == 0) then
                local sid = _learning_sid(p)
                if sid then
                    local e = LearnedModel[sid]
                    if not e then
                        e = {dl=0, dr=0, sl=0, sr=0, dom=0, hits=0, miss=0, last_seen=0,
                             best_jitter="", best_static="", best_switch="", best_spinner=""}
                        LearnedModel[sid] = e
                    end
                    -- merge passive data without overriding hit-based numbers
                    local pl, pr = s.passive_left or 0, s.passive_right or 0
                    if e.sl == 0 and pl > 5 then e.dl = pl; e.sl = 1 end
                    if e.sr == 0 and pr > 5 then e.dr = pr; e.sr = 1 end
                    if e.dom == 0 then
                        if pr > pl * 1.3 then e.dom = 1
                        elseif pl > pr * 1.3 then e.dom = -1 end
                    end
                    e.last_seen = globals.realtime or 0
                    learning_dirty = true
                end
            end
        end
    end

    anim.m_flGoalFeetYaw = NormalizeAngle(angle)

    -- DEBUG dump per resolve (only when toggle on, throttled to ~5hz per player)
    if is_debug() then
        local now_ct = tick_cache.curtime
        if (s.last_dbg_t or 0) + 0.2 < now_ct then
            s.last_dbg_t = now_ct
            local sp = 0
            pcall(function()
                local v = p.m_vecVelocity
                sp = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
            end)
            cs_log_debug(
                "idx=%d mode=%s aa=%s eye=%.1f→goal=%.1f desync_use=%.1f vel=%.0f dist=%.0f close=%s missed=%d L=%d R=%d defAA=%s jitter=%s",
                p:get_index(), tostring(s.mode), tostring(s.aa_type),
                eye_yaw, NormalizeAngle(angle), effective_desync(s, max_desync),
                sp, s.tmp_dist or 0, tostring(s.tmp_close),
                s.missed, s.hit_streak_left, s.hit_streak_right,
                tostring(s.defensive_aa), tostring(s.jittering)
            )
        end
    end
end

local function should_force_baim(p)
    local s = PlayerState[p:get_index()]
    if not s then return false end
    local preset = get_mode_preset()
    return preset.baim_after > 0 and s.missed >= preset.baim_after
end

local lby_snap_handler = function(event)
    if not event then return end
    local uid = event.userid or event.user_id or event.player
    if not uid then return end
    local shooter = entity.get(uid, true)
    local lp_e = entity.get_local_player()
    if not shooter or shooter == lp_e then return end
    if not shooter:is_enemy() or not shooter:is_alive() then return end
    local s = get_state(shooter)
    s.lby_snap  = true
    s.last_shot = globals.curtime
    -- V9.8: HOSTILE-FIRE DETECTION — mark when an enemy fires, for the
    -- ragebot_target counter-fire override (bypasses cancel-low-conf in their
    -- fire-window). V9.31 HARD-CONSTRAINT-5 FIX: NEVER read enemy entity props
    -- (m_vecOrigin / m_angEyeAngles) in a weapon_fire handler — transition-state
    -- players (just-respawned / dying / weapon-switching) return invalid memory
    -- that C++-panics PAST pcall and crashes CSGO. Stash ONLY the event-derived
    -- tick. resolve_player clears the mark for out-of-range enemies (where the
    -- distance is read safely), and the counter-fire consumer already re-gates by
    -- ticks_since<=64 + conf>=10, so dropping the range/aim check here is safe.
    s.last_hostile_fire  = globals.tickcount or 0
    s.hostile_fire_count = (s.hostile_fire_count or 0) + 1
    s.last_hostile_aimed = false
end

local lby_event_set = false
pcall(function()
    events.weapon_fire:set(lby_snap_handler)
    lby_event_set = true
end)
if not lby_event_set then
    pcall(function() events.player_shoot:set(lby_snap_handler) end)
end

-- V3: aim_fire snapshot — capture per-shot resolver state for accurate aim_ack learning
local function push_shot_snapshot(target_idx)
    if not (exp_aim_fire_snap and exp_aim_fire_snap:get()) then return end
    local s = PlayerState[target_idx]
    if not s then return end
    -- V7.8: capture which side we shot (delta sign of resolved vs eye)
    local shot_side = 0
    if s.last_eye_yaw and s.last_resolved then
        local d = NormalizeAngle(s.last_resolved - s.last_eye_yaw)
        if math.abs(d) > 3 then shot_side = d > 0 and 1 or -1 end
    end
    s.last_shot_side = shot_side
    local snap = {
        tick     = globals.tickcount or 0,
        time     = globals.curtime   or 0,
        mode     = s.mode,
        eye_yaw  = s.last_eye_yaw,
        resolved = s.last_resolved,
        side     = shot_side,
        measured = s.measured_desync,
    }
    table.insert(s.shot_snapshots, snap)
    -- V9.33: prune snapshots older than ~1s (@64 tick) so a stale snapshot from a
    -- prior engagement can't be matched to the current ack (would learn wrong side).
    local now_t = globals.tickcount or 0
    while #s.shot_snapshots > 0 and (now_t - (s.shot_snapshots[1].tick or 0)) > 64 do
        table.remove(s.shot_snapshots, 1)
    end
    while #s.shot_snapshots > 8 do table.remove(s.shot_snapshots, 1) end
    cs_log_verbose("snapshot pushed idx=%d mode=%s eye=%.1f res=%.1f tick=%d",
                   target_idx, tostring(snap.mode), snap.eye_yaw, snap.resolved, snap.tick)
end

local aim_fire_handler = function(event)
    if not event then return end
    local tid = event.target or event.target_index or event.userid
    if not tid then return end
    push_shot_snapshot(tid)
end

pcall(function() events.aim_fire:set(aim_fire_handler) end)
pcall(function() events.ragebot_fire:set(aim_fire_handler) end)

-- V8.4 + V8.6: periodic auto-save — interval tightened 30s → 10s
local _last_auto_save = 0
local AUTO_SAVE_INTERVAL = 10

events.createmove:set(function(cmd)
    if not resolver.enable:get() then return end
    entity.get_players(true, false, function(p)
        pcall(resolve_player, p)
    end)
    -- V8.4: periodic auto-save (Lua-table + JSON backup)
    local now_rt = globals.realtime or 0
    if now_rt - _last_auto_save >= AUTO_SAVE_INTERVAL then
        _last_auto_save = now_rt
        if learning_dirty then
            pcall(learning_save)
            pcall(learning_export_json)
            cs_log_verbose("auto-save: learned.lua + learned.json written")
        end
    end
end)

-- V6: current-target intel for HUD + smarter hitchance decisions
local current_target = {idx = 0, mode = "—", conf = 0, side = 0, known = false, time = 0}

-- V6.8: session-tracker (forward-decl'd at top of file V7.6)
local function session_record(hit)
    if hit then session_stats.total_hits = session_stats.total_hits + 1
    else        session_stats.total_miss = session_stats.total_miss + 1 end
    table.insert(session_stats.history, hit)
    while #session_stats.history > 20 do table.remove(session_stats.history, 1) end
    -- early = first 10
    local early_h, early_n = 0, 0
    local total = session_stats.total_hits + session_stats.total_miss
    if total <= 10 then
        early_h = session_stats.total_hits; early_n = total
    else
        -- recompute first 10 from history (only if total > 10)
        early_h, early_n = 0, 10
        -- we lost early data when history rotated out; approximation: use total / total_n
        early_h = math.floor(session_stats.total_hits * (10 / total))
    end
    session_stats.early_rate = early_n > 0 and (early_h / early_n * 100) or 0
    -- recent = last 10
    local rec_h, rec_n = 0, 0
    local start = math.max(1, #session_stats.history - 9)
    for i = start, #session_stats.history do
        rec_n = rec_n + 1
        if session_stats.history[i] then rec_h = rec_h + 1 end
    end
    session_stats.recent_rate = rec_n > 0 and (rec_h / rec_n * 100) or 0
end

local function target_intel(p, s)
    if not s then return {known = false, mode_match = false, conf = 0, confident = false, samples = 0} end
    local intel = {
        idx          = p:get_index(),
        mode         = s.mode,
        aa_type      = s.aa_type,
        side         = s.last_hit_side,
        conf         = confidence(s),
        samples      = (s.samples_left or 0) + (s.samples_right or 0),
        known        = false,
        mode_match   = false,
        best_mode    = nil,
    }
    if s.boot_best_modes and s.aa_type and s.boot_best_modes[s.aa_type] then
        local bm = s.boot_best_modes[s.aa_type]
        if bm and bm ~= "" then
            intel.known     = true
            intel.best_mode = bm
            local current_clean = tostring(s.mode):gsub("%+Pred", ""):gsub("%-DefInv", "")
            intel.mode_match = (current_clean == bm)
        end
    end
    intel.confident = intel.conf >= 50 and intel.samples >= 2
    return intel
end

-- V3: confidence via std-dev of last 5 resolves
local function resolve_stddev(s)
    local n = #s.recent_resolved
    if n < 3 then return 0 end
    -- V9.31: circular spread vs reference (wrap-safe; see confidence()). Drives
    -- cancel-conf — a fake-huge stddev here makes the ragebot REFUSE to fire.
    local ref = s.recent_resolved[1].a
    local sumd, sq_sum = 0, 0
    for _, r in ipairs(s.recent_resolved) do sumd = sumd + NormalizeAngle(r.a - ref) end
    local mean_off = sumd / n
    for _, r in ipairs(s.recent_resolved) do
        local d = NormalizeAngle(r.a - ref) - mean_off
        sq_sum = sq_sum + d * d
    end
    return math.sqrt(sq_sum / n)
end

-- V3 + V9.9-E: weapon class detection — tick-cached to avoid 3-5x FFI calls per ragebot_target stack
local function get_weapon_class()
    -- V9.9-E: serve from tick_cache if already resolved this tick
    if tick_cache and tick_cache.wc ~= nil then
        return (tick_cache.wc ~= false) and tick_cache.wc or nil
    end
    local lp = (tick_cache and tick_cache.lp) or entity.get_local_player()
    if not lp then
        if tick_cache then tick_cache.wc = false end
        return nil
    end
    local ok, name = pcall(function()
        local w = lp:get_weapon()
        if not w then return nil end
        local cn = (w.get_class_name and w:get_class_name()) or (w.get_name and w:get_name()) or ""
        return tostring(cn):lower()
    end)
    if not ok or not name or name == "" then
        if tick_cache then tick_cache.wc = false end
        return nil
    end
    local cls
    if name:find("awp") or name:find("ssg") or name:find("scout") then cls = "sniper"
    elseif name:find("ak47") or name:find("m4") or name:find("aug") or name:find("sg") or name:find("famas") or name:find("galil") then cls = "auto"
    elseif name:find("deagle") or name:find("revolver") or name:find("r8") then cls = "heavy_pistol"
    elseif name:find("knife") or name:find("bayonet") or name:find("karambit") then cls = "knife"
    else cls = "other"
    end
    if tick_cache then tick_cache.wc = cls end
    return cls
end

pcall(function()
    events.ragebot_target:set(function(ctx)
        local target = ctx and (ctx.target or (ctx.get_target and ctx:get_target()))
        if not target then return end

        local s = PlayerState[target:get_index()]

        -- V6: track current target + intel for HUD + decision making
        local intel = target_intel(target, s)
        current_target.idx       = intel.idx
        current_target.mode      = intel.mode or "—"
        current_target.conf      = intel.conf
        current_target.side      = intel.side
        current_target.known     = intel.known
        current_target.mode_match= intel.mode_match
        current_target.best_mode = intel.best_mode
        current_target.aa_type   = intel.aa_type or "?"
        current_target.time      = globals.curtime or 0

        -- V5 #1: SHOT-COOLDOWN AWARENESS (SSG/sniper reload-skip) — V9.9-E: tick-cached lp
        local lp = tick_cache.lp or entity.get_local_player()
        if lp then
            local cooldown_skip = false
            pcall(function()
                local wpn = lp:get_weapon()
                if wpn and wpn.m_flNextPrimaryAttack then
                    local next_attack = wpn.m_flNextPrimaryAttack
                    if next_attack > (globals.curtime or 0) + 0.05 then
                        cooldown_skip = true
                    end
                end
            end)
            if cooldown_skip then
                pcall(function() ctx:override_hitchance(99) end)
                cs_log_verbose("shot-cooldown skip idx=%d (weapon reloading)", target:get_index())
                return
            end
        end

        -- V5 #3 + V6.6 + V6.9: AIR-SHOT + close-priority handling
        -- Detect local airborne, falling-toward, target distance
        local lp_airborne, target_dist, lp_vz = false, 99999, 0
        if lp then
            pcall(function()
                local flags = lp.m_fFlags or 0
                lp_airborne = (bit.band(flags, 1) == 0)
            end)
            pcall(function()
                local dx = target.m_vecOrigin.x - lp.m_vecOrigin.x
                local dy = target.m_vecOrigin.y - lp.m_vecOrigin.y
                local dz = target.m_vecOrigin.z - lp.m_vecOrigin.z
                target_dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                lp_vz = lp.m_vecVelocity.z or 0
            end)
        end
        local wc = get_weapon_class()
        local mode_now = mode_str()
        -- V6.9: smarter close-priority — tiered range, jump-in detect, falling-dive
        local close_priority = false
        local priority_hc, priority_reason = 20, ""
        if target_dist < 400 then          -- point-blank trade (~7m)
            close_priority = true; priority_hc = 5; priority_reason = "point-blank"
        elseif target_dist < 700 then      -- close trade (~13m)
            close_priority = true; priority_hc = 15; priority_reason = "close"
        elseif lp_airborne and lp_vz < -50 and target_dist < 1500 then  -- diving (falling toward)
            close_priority = true; priority_hc = 10; priority_reason = "dive-in"
        elseif lp_airborne and target_dist < 1100 then  -- jump-peek
            close_priority = true; priority_hc = 15; priority_reason = "jump-peek"
        end
        if close_priority and (mode_now == "Aggressive" or wc == "sniper") then
            -- V9.4: sniper hc-floor 40 (user's NL hc=72, never drop nuclear) — auto-stop handles close anyway
            local effective_hc = priority_hc
            if wc == "sniper" and effective_hc < 40 then effective_hc = 40 end
            pcall(function() ctx:override_hitchance(effective_hc) end)
            -- V9.18: min_dmg overrides removed globally — NL min_dmg is the source of truth
            -- V9.4: respect safe-points "Prefer" mode when respect-manual on (sniper)
            if not (wc == "sniper" and exp_respect_man and exp_respect_man:get()) then
                pcall(function() ctx:override_safe_point(false) end)
            end
            -- V6.9: SSG bonus — multipoint scale wider for body coverage (NL multi-hitbox = head/chest/stom)
            if wc == "sniper" then
                pcall(function() ctx:override_multipoint(true) end)
                pcall(function() ctx:override_multipoint_scale(1.0) end)
            else
                -- V9.40: non-sniper close-priority — force multipoint on too. A
                -- point-blank enemy running at you produces near-constant stale NL
                -- backtrack records (live head has moved past the replayed record),
                -- so a SINGLE-point head shot whiffs even when our resolved angle is
                -- correct (logs: our=meas, err=0, bt 7-15, reason=correction). Spread
                -- aim points across the hitbox so a slightly-stale record still lands.
                -- Widen to full spread when this target is already flagged stale-record.
                pcall(function() ctx:override_multipoint(true) end)
                -- V9.46: full spread when stale-record-flagged OR mid teleport-peek blink.
                pcall(function() ctx:override_multipoint_scale((s and (s.backtrack_resistant or s.tp_peek_active)) and 1.0 or 0.85) end)
            end
            cs_log_verbose("close-priority idx=%d dist=%.0f reason=%s hc=%d (eff=%d) wc=%s",
                           target:get_index(), target_dist, priority_reason, priority_hc, effective_hc, tostring(wc))
            -- continue (don't return) — head-focus + other overrides still apply
        elseif wc == "sniper" and lp_airborne and target_dist > 3500 then
            -- V8.5: only block VERY long range airborne (3500u+) — let jump-scout work elsewhere
            pcall(function() ctx:override_hitchance(99) end)
            cs_log_verbose("air-block idx=%d (sniper airborne, dist=%.0f >3500)", target:get_index(), target_dist)
            return
        end

        -- V9.8 + V9.11: COUNTER-FIRE OVERRIDE — enemy fired at us in last 1s →
        -- bypass cancel-low-conf, force HEAD hitbox (their head is visible if they
        -- are shooting at us), drop hitchance to 15, mindmg to 1, disable safepoint.
        -- NL backtracks to the latest record where the shot lands; with safepoint
        -- off + head forced + low HC, ragebot fires the first frame it sees their
        -- head (which is the exact peek tick they used to shoot us).
        -- Skip on sniper (precision class) or conf < 10 (no data, waste shot).
        local counter_fire_active = false
        if s and (s.last_hostile_fire or 0) > 0 then
            local ticks_since = (globals.tickcount or 0) - s.last_hostile_fire
            if ticks_since >= 0 and ticks_since <= 64 then
                local wc_cf = get_weapon_class()
                if wc_cf ~= "sniper" and intel and intel.conf >= 10 then
                    counter_fire_active = true
                    pcall(function() ctx:override_hitchance(15) end)
                    -- V9.18: min_dmg overrides removed globally — NL min_dmg=100 stays in effect
                    pcall(function() ctx:override_hitbox(0) end)
                    pcall(function() ctx:override_safe_point(false) end)
                    pcall(function() ctx:override_multipoint(true) end)
                    pcall(function() ctx:override_multipoint_scale(0.85) end)
                    cs_log_verbose("counter-fire+head idx=%d conf=%d aimed=%s (fired %d ticks ago)",
                                   target:get_index(), intel.conf,
                                   tostring(s.last_hostile_aimed), ticks_since)
                end
            end
        end

        -- V9.31: LOCKED-TARGET HEAD PREFERENCE — the body-only-hits fix.
        -- On a normal mid-range fight NO existing stage turns off NL's "Prefer"
        -- safe-points, so NL picks the safe BODY point because head isn't 100%
        -- guaranteed. But on a LOCKED target (8+ samples, 60+ conf, not currently
        -- whiffing) the yaw resolve IS proven → head IS safe. Relax safe-point +
        -- enable multipoint so the ragebot takes the head it was avoiding. Never
        -- touches mindmg/hitbox (respects never-override-NL-config); fires ONLY on
        -- locked targets so the baseline is identical for everyone else. Skip when
        -- counter-fire already forced head, or on snipers honouring manual SSG.
        if not counter_fire_active and exp_lock_headpref and exp_lock_headpref:get()
           and intel and intel.samples >= 8 and intel.conf >= 60
           and (not s or (s.missed or 0) == 0)
           and not (wc == "sniper" and exp_respect_man and exp_respect_man:get()) then
            pcall(function() ctx:override_safe_point(false) end)
            pcall(function() ctx:override_multipoint(true) end)
            cs_log_verbose("lock-headpref idx=%d conf=%d samples=%d → safepoint off (take head)",
                           target:get_index(), intel.conf, intel.samples)
        end

        -- V3+V5+V6: CANCEL LOW-CONFIDENCE — intel-aware (known mode-match = trust)
        if not counter_fire_active and exp_cancel_conf and exp_cancel_conf:get() and s then
            local sd = resolve_stddev(s)
            local wc = get_weapon_class()
            local in_peek_window = false
            if lp then
                pcall(function()
                    local v = lp.m_vecVelocity
                    local sp = math.sqrt((v.x or 0)^2 + (v.y or 0)^2)
                    if sp < 30 then in_peek_window = true end
                end)
            end
            -- V6: known player with proven mode-match → trust + don't bump
            if intel.known and intel.mode_match and intel.samples >= 3 then
                cs_log_verbose("cancel-conf TRUST idx=%d (known player + best-mode match=%s samples=%d)",
                               target:get_index(), tostring(intel.best_mode), intel.samples)
                -- skip cancel — let ragebot fire at proven mode
            elseif wc == "sniper" and in_peek_window and s.missed == 0 then
                cs_log_verbose("cancel-conf SKIPPED idx=%d (sniper peek-shot priority)", target:get_index())
            -- V9.14: stationary target with ANY data → trust. AFK enemies are easy
            -- shots — user reported watching ragebot refuse to fire at AFK players.
            elseif s.is_stationary and intel.samples >= 1 then
                cs_log_verbose("cancel-conf SKIPPED idx=%d (stationary + %d samples)",
                               target:get_index(), intel.samples)
            -- V9.14: slow-walker with 2+ samples → trust (predictable target)
            elseif s.is_slow_target and intel.samples >= 2 then
                cs_log_verbose("cancel-conf SKIPPED idx=%d (slow-walker + %d samples)",
                               target:get_index(), intel.samples)
            else
                local sd_threshold   = (wc == "sniper") and 50  or 25
                -- V9.15: sniper threshold 10 -> 18. Low-conf blind shots were
                -- slipping through because 10 was almost no gate at all.
                local conf_threshold = (wc == "sniper") and 18  or 25
                -- V9.15: zero-real-samples = blind first shot. Require conf 30+ no
                -- matter the weapon class so we don't burn a shot guessing the
                -- side. The user reported "miesses random wo hin geschossen" — that
                -- is exactly the symptom of firing blind on fresh enemies.
                if intel.samples == 0 then
                    conf_threshold = math.max(conf_threshold, 30)
                end
                -- known player but mode mismatch → slightly tighter wait (try right mode first)
                if intel.known and not intel.mode_match then
                    conf_threshold = conf_threshold + 15
                end
                if sd > sd_threshold or intel.conf < conf_threshold then
                    -- V9.15: snipers now also cancel (was: only verbose-log, no actual hc bump).
                    pcall(function() ctx:override_hitchance(99) end)
                    cs_log_verbose("cancel-conf idx=%d sd=%.1f° conf=%d%% samples=%d wc=%s thresh=%d (wait)",
                                   target:get_index(), sd, intel.conf, intel.samples,
                                   tostring(wc), conf_threshold)
                    return
                end
            end
        end

        -- V3 #10 + V4 + V9.18: AUTO PER-WEAPON — only multipoint hint + knife disable.
        -- All hitchance/min_damage/hitbox overrides removed: user's NL settings (hc=72,
        -- mindmg=100, multi-hitbox Head/Chest/Stomach, Safepoints Prefer) are already
        -- well-tuned. Lua-side downgrades were causing fires at insufficient confidence.
        if exp_auto_weapon and exp_auto_weapon:get() then
            local wc = get_weapon_class()
            if wc == "sniper" then
                pcall(function() ctx:override_multipoint(true) end)
                pcall(function() ctx:override_multipoint_scale(0.75) end)
                cs_log_verbose("per-weapon: sniper RESPECT (NL settings preserved, multipoint hint)")
            elseif wc == "knife" then
                pcall(function() ctx:override_hitchance(99) end)  -- effectively disable
                cs_log_verbose("per-weapon: knife (resolver disabled)")
                return
            end
            -- auto / heavy_pistol / other: no override — trust NL config
        end

        -- V9.35: FAST-FIRE TIGHTENED — the old conf>=50/hc=30 tier fired the ragebot
        -- on a marginal 30%-hitchance shot the moment we had ANY decent conf. On
        -- high-desync enemies that early fire caught a bad backtrack record →
        -- correction / prediction-error rejects (user: "shoots too early, misses a
        -- lot"). Now fast-fire ONLY triggers on a STABLE (low-stddev), well-SAMPLED
        -- resolve, and the hc floors are raised toward NL's manual value so even a
        -- fast shot stays high-quality. Lowering hc below NL's 72 is exactly the
        -- v9.18 regression — keep the downgrade small and only when truly locked.
        local respect_active = (wc == "sniper") and exp_respect_man and exp_respect_man:get()
        if not respect_active and s and s.missed == 0 then
            local sd = resolve_stddev(s)
            local stable = sd < 12   -- low angle variance = trustworthy resolve
            local fast_hc
            if intel.conf >= 85 and intel.samples >= 3 and stable then fast_hc = 30
            elseif intel.conf >= 70 and intel.samples >= 2 and stable then fast_hc = 45
            end
            if fast_hc then
                pcall(function() ctx:override_hitchance(fast_hc) end)
                cs_log_verbose("fast-fire idx=%d conf=%d samples=%d sd=%.1f hc=%d",
                               target:get_index(), intel.conf, intel.samples, sd, fast_hc)
            end
        end

        -- V9.12: CLOSE-RANGE FIRST-MISS FOLLOW-UP — user reported missing the first
        -- close shot then waiting too long for ragebot to fire again. After 1+ miss
        -- on a close target (<1000u) in Aggressive mode, drop hc to 10, mindmg to 1,
        -- force head, safepoint off — same package as counter-fire so the trade-shot
        -- fires the next frame the head is takable.
        if mode_now == "Aggressive" and s and s.missed >= 1 and target_dist < 1000 and not counter_fire_active then
            pcall(function() ctx:override_hitchance(10) end)
            -- V9.18: min_dmg overrides removed globally — NL min_dmg stays in effect
            pcall(function() ctx:override_hitbox(0) end)
            pcall(function() ctx:override_safe_point(false) end)
            pcall(function() ctx:override_multipoint(true) end)
            pcall(function() ctx:override_multipoint_scale(0.85) end)
            cs_log_verbose("close-miss followup idx=%d dist=%.0f missed=%d",
                           target:get_index(), target_dist, s.missed)
        end

        -- V9.9-C: CROUCH-AWARE HITBOX — target ducked → head harder to hit (smaller + lower).
        -- Detect FL_DUCKING (bit 1 of m_fFlags). Used by HEAD-STRICT to swap head→chest,
        -- and by all other hitbox modes to widen multipoint scale for body coverage.
        local target_crouched = false
        pcall(function()
            local tflags = target.m_fFlags or 0
            if bit.band(tflags, 2) ~= 0 then target_crouched = true end
        end)

        -- NOSPREAD MODE: head every shot, hitchance 1%, min-dmg 100, no multipoint, no safepoint
        if exp_nospread and exp_nospread:get() then
            pcall(function() ctx:override_hitbox(0) end)            -- head ALWAYS
            pcall(function() ctx:override_hitchance(1) end)         -- 1% = always fire
            -- V9.18: min_dmg removed — user's NL min_dmg=100 already enforces OHK
            pcall(function() ctx:override_safe_point(false) end)
            pcall(function() ctx:override_multipoint(false) end)
            cs_log_verbose("NOSPREAD head-shot mode=%s missed=%d", tostring(s and s.mode), s and s.missed or 0)
        -- V7.9 + V9.9-C: HEADSHOT-ONLY STRICT — head every shot.
        -- Crouched target swaps to chest (head too low/occluded when ducked), tighter hc + higher mindmg.
        elseif exp_head_strict and exp_head_strict:get() then
            if target_crouched then
                pcall(function() ctx:override_hitbox(3) end)        -- chest (head occluded when crouched)
                pcall(function() ctx:override_hitchance(40) end)
            else
                pcall(function() ctx:override_hitbox(0) end)        -- head ALWAYS
                pcall(function() ctx:override_hitchance(45) end)
            end
            -- V9.18: min_dmg removed — NL min_dmg stays in effect
            pcall(function() ctx:override_safe_point(false) end)
            pcall(function() ctx:override_multipoint(false) end)
            cs_log_verbose("HEAD-STRICT %s mode=%s missed=%d",
                           target_crouched and "CHEST(crouched)" or "head",
                           tostring(s and s.mode), s and s.missed or 0)
        -- V9.18: AGGRESSIVE HEAD-FOCUS block REMOVED. Was forcing hc=40 + mindmg=25 +
        -- safepoint=off on every Aggressive first-shot, which downgraded user's NL
        -- hc=72 and overrode user's multi-hitbox Head/Chest/Stomach config — directly
        -- caused "open head miss" symptoms because ragebot fired at insufficient
        -- confidence. Multipoint hint moved to the generic branch below; the toggle
        -- itself is left in UI but no longer applies a hitchance/mindmg downgrade.
        -- multipoint hint when first-shot networked-mode
        elseif exp_multipoint and exp_multipoint:get() then
            if s and s.missed == 0 and (s.mode == "Networked" or s.mode == "Predicted" or s.mode == "Static") then
                pcall(function() ctx:override_multipoint(true) end)
                pcall(function() ctx:override_multipoint_scale(0.7) end)
                pcall(function() ctx:set_multipoint(true) end)
                cs_log_verbose("multipoint hint mode=%s", tostring(s.mode))
            end
        end

        if should_force_baim(target) then
            local hb_idx = baim_hb_id()
            pcall(function() ctx:override_hitbox(hb_idx) end)
            -- V9.18: min_dmg override removed — NL min_dmg stays in effect. NOTE: if NL
            -- min_dmg is set high (e.g. 100), force-baim body hits may still be rejected
            -- by NL since body shots typically deal <100 dmg. Lower NL min_dmg manually
            -- if you want baim to actually fire after misses.
            pcall(function() ctx:override_safe_point(false) end)
            -- V8.4: drop hitchance based on miss-count → faster body follow-up
            -- More misses = lower hc (tries body shot quicker). Scales 25 → 10.
            local baim_hc = 25
            if s and s.missed then
                if s.missed >= 5 then baim_hc = 10
                elseif s.missed >= 4 then baim_hc = 15
                elseif s.missed >= 3 then baim_hc = 20
                end
            end
            pcall(function() ctx:override_hitchance(baim_hc) end)
            -- V8.4: multipoint scan body for chest hits
            pcall(function() ctx:override_multipoint(true) end)
            pcall(function() ctx:override_multipoint_scale(1.0) end)
            cs_log_verbose("force baim → hitbox=%d hc=%d miss=%d",
                           hb_idx, baim_hc, s and s.missed or 0)
        end

        -- V8.5 + V9.4: JUMP-SHOT improvement — extended range + smart hitbox
        if lp_airborne and not close_priority and target_dist < 4000 and not should_force_baim(target) then  -- V9.31: don't let jump-shot clobber force-baim's body hitbox
            local respect_sniper = (wc == "sniper") and exp_respect_man and exp_respect_man:get()
            if respect_sniper then
                -- V9.18: SSG-Pro respect mode — preserve NL hc + multi-hitbox entirely
                pcall(function() ctx:override_multipoint(true) end)
                pcall(function() ctx:override_multipoint_scale(0.85) end)
                cs_log_verbose("jump-scout SSG-RESPECT idx=%d dist=%.0f vz=%.0f (NL settings preserved)",
                               target:get_index(), target_dist, lp_vz)
            else
                -- Standard jump-shot: head-only + low hc (min_dmg now respects NL)
                pcall(function() ctx:override_hitbox(0) end)
                pcall(function() ctx:override_multipoint(false) end)
                pcall(function() ctx:override_safe_point(false) end)
                if wc == "sniper" then
                    pcall(function() ctx:override_hitchance(35) end)
                    cs_log_verbose("jump-scout SNIPER idx=%d dist=%.0f hc=35", target:get_index(), target_dist)
                else
                    pcall(function() ctx:override_hitchance(30) end)
                    cs_log_verbose("jump-shot HEAD idx=%d dist=%.0f wc=%s", target:get_index(), target_dist, tostring(wc))
                end
            end
        end
    end)
end)

-- ─── V3+V5: ESP overlay (per-enemy) + HUD-corner ──────────
local esp_last_paint = 0
local last_combat_event = {mode = "—", conf = 0, time = 0, was_hit = false}

local function color_by_confidence(conf)
    -- red (low) → yellow (mid) → green (high)
    if conf < 33 then return 255, 80, 80 end
    if conf < 66 then return 255, 200, 60 end
    return 80, 255, 80
end

-- V9.71 perf: constant color objects hoisted — were re-created per enemy per FRAME
-- in the draw path. GLOBALS (main chunk at the 200-local cap).
ESP_COL_WEDGE    = color(235, 235, 235, 230)
ESP_COL_TAG      = color(120, 200, 255, 240)
ESP_COL_DOT_HIT  = color(90, 255, 110, 230)
ESP_COL_DOT_MISS = color(255, 70, 70, 230)
ESP_COL_DOT_SF   = color(90, 170, 255, 230)
ESP_COL_BAR_BG   = color(40, 40, 40, 200)
ESP_COL_PANEL    = color(15, 15, 20, 220)
ESP_COL_BORDER   = color(80, 130, 200, 255)
ESP_COL_TXT      = color(220, 220, 220, 255)
ESP_COL_TXT2     = color(180, 220, 255, 255)
ESP_COL_TITLE    = color(150, 200, 255, 255)
ESP_HUD_TITLE    = "▸ SEL01-SOLVER v" .. SEL01_VERSION

-- cached HUD data (refreshed at throttled rate, drawn every frame)
local hud_cache = {
    tracked = 0, learned = 0, avg_conf = 0,
    top_mode = "—", top_rate = 0, top_total = 0,
    last_compute = 0,
}
local function esp_refresh_cache()
    local now = globals.realtime or 0
    local hz = (esp_throttle_hz and esp_throttle_hz:get()) or 10
    if now - hud_cache.last_compute < (1 / hz) then return end
    hud_cache.last_compute = now
    local tracked = 0
    for _ in pairs(PlayerState) do tracked = tracked + 1 end
    local learned = 0
    for _ in pairs(LearnedModel) do learned = learned + 1 end
    local conf_sum, conf_cnt = 0, 0
    for _, s in pairs(PlayerState) do
        if s.mode ~= "Init" then
            conf_sum = conf_sum + confidence(s); conf_cnt = conf_cnt + 1
        end
    end
    hud_cache.tracked = tracked
    hud_cache.learned = learned
    hud_cache.avg_conf = conf_cnt > 0 and math.floor(conf_sum / conf_cnt) or 0
    local top_mode, top_rate, top_total = "—", 0, 0
    for m, e in pairs(mode_stats) do
        local total = e.hits + e.miss
        if total > top_total then
            top_total = total; top_mode = m
            top_rate = total > 0 and (e.hits / total * 100) or 0
        end
    end
    hud_cache.top_mode = top_mode
    hud_cache.top_rate = top_rate
    hud_cache.top_total = top_total
    -- V9.71 perf: pre-format static HUD lines + conf color + panel position at the
    -- throttled rate (10Hz) instead of every frame in the draw path.
    hud_cache.txt_tracked = string.format("Tracked: %d enemies", tracked)
    hud_cache.txt_learned = string.format("Learned: %d players", learned)
    hud_cache.txt_conf    = string.format("Avg Confidence: %d%%", hud_cache.avg_conf)
    hud_cache.txt_topmode = string.format("Top Mode: %s", top_mode)
    hud_cache.txt_toprate = string.format("  Hit-rate: %.0f%% (%d shots)", top_rate, top_total)
    local ar, ag, ab = color_by_confidence(hud_cache.avg_conf)
    hud_cache.conf_col = color(ar, ag, ab, 255)
    pcall(function()
        local screen = render.screen_size()
        local panel_w, panel_h = 320, 150
        local pos = esp_hud_pos and tostring(esp_hud_pos:get()) or "Bottom-Left"
        local x0, y0
        if     pos == "Bottom-Right" then x0 = screen.x - panel_w - 20; y0 = screen.y - panel_h - 20
        elseif pos == "Top-Left"     then x0 = 20;                      y0 = 80
        elseif pos == "Top-Right"    then x0 = screen.x - panel_w - 20; y0 = 80
        else                              x0 = 20;                      y0 = screen.y - panel_h - 20
        end
        hud_cache.x0, hud_cache.y0 = x0, y0
    end)
end

local esp_paint_handler = function()
    -- master gate
    local enabled = (esp_master and esp_master:get()) or (exp_esp_overlay and exp_esp_overlay:get())
    if not enabled then return end
    -- compute throttled, draw every frame
    esp_refresh_cache()

    -- ═══ per-enemy ESP labels ═══
    if esp_show_labels and esp_show_labels:get() then
    pcall(function()
        entity.get_players(true, false, function(p)
            if not p:is_alive() or p:is_dormant() then return end
            local s = PlayerState[p:get_index()]
            if not s or s.mode == "Init" then return end

            local ox, oy, oz = p.m_vecOrigin.x, p.m_vecOrigin.y, p.m_vecOrigin.z
            local ok, head_pos = pcall(function()
                return render.world_to_screen(vector(ox, oy, oz + 72))
            end)
            if not ok or not head_pos then return end  -- nil when offscreen
            -- V9.51: feet point (flash box bottom). Nil-safe — box just skips if offscreen.
            local feet_pos
            pcall(function() feet_pos = render.world_to_screen(vector(ox, oy, oz + 4)) end)

            -- V9.71 perf: heavy per-enemy label compute (confidence() circular stddev,
            -- mode-string finds, string.format, color objects) throttled to 5Hz per
            -- enemy; the per-frame draw path reads the cache. Cosmetic-only fields
            -- (_espc_*) — no resolver state touched from render.
            local enh_on = esp_enh and esp_enh:get()
            local now_rt = globals.realtime or 0
            if (now_rt - (s._espc_t or 0)) > 0.2 or s._espc_mode ~= s.mode then
                s._espc_t = now_rt
                s._espc_mode = s.mode
                -- color by mode category
                local r, g, b = 255, 255, 255
                local m = tostring(s.mode)
                if m:find("BF:")         then r, g, b = 255, 100, 100
                elseif m:find("Air")     then r, g, b = 180, 180, 255
                elseif m:find("Meas")    then r, g, b = 100, 255, 100
                elseif m:find("Predict") then r, g, b = 255, 220, 100
                elseif m:find("Jitter")  then r, g, b = 255, 150, 255
                elseif m:find("LBY")     then r, g, b = 100, 255, 255
                end
                s._espc_col  = color(r, g, b, 255)   -- label text
                s._espc_wcol = color(r, g, b, 240)   -- wedge resolved-line
                local conf = confidence(s)
                s._espc_conf = conf
                local cr, cg, cb = color_by_confidence(conf)
                s._espc_fill = color(cr, cg, cb, 220)  -- conf-bar fill
                local total_samples = (s.samples_left or 0) + (s.samples_right or 0)
                local locked = total_samples >= 8 and conf >= 60

                -- V9.53: COMPACT symbol label. [aa-icon] [side-arrow] [deg] [learn-icon]
                local side_ic = s.last_hit_side > 0 and "→" or (s.last_hit_side < 0 and "←" or "•")
                local desync_val
                if s.last_hit_side > 0 and s.samples_right >= 1 then desync_val = s.measured_right
                elseif s.last_hit_side < 0 and s.samples_left >= 1 then desync_val = s.measured_left
                else desync_val = s.measured_desync end
                local at = tostring(s.aa_type or "")
                local aa_ic = "▬"
                if     at == "switch"  then aa_ic = "⇄"
                elseif at == "jitter"  then aa_ic = "≈"
                elseif at == "spinner" then aa_ic = "⟳" end
                local learn_ic = ""
                if locked then learn_ic = " 🔒"
                elseif total_samples >= 4 then learn_ic = " ★"
                elseif total_samples >= 1 then learn_ic = " ·" end
                s._espc_txt = string.format("%s %s %.0f°%s", aa_ic, side_ic, desync_val, learn_ic)
                -- netcode tag (enh mode): ⚠×N serverfails / bt resistant / tp-peek
                local tag = ""
                if (s.serverfail_misses or 0) > 0 then tag = tag .. string.format("⚠×%d ", s.serverfail_misses) end
                if s.backtrack_resistant then tag = tag .. "bt " end
                if s.tp_peek_active then tag = tag .. "pk " end
                s._espc_tag = tag
            end
            local conf = s._espc_conf or 0
            local txt = s._espc_txt or ""

            pcall(function()
                local now_t = globals.curtime or 0

                -- V9.51-B: HIT/MISS/SERVERFAIL flash box around the model (~0.45s fade).
                if esp_flash and esp_flash:get() and feet_pos and s.last_shot_result
                   and (now_t - (s.last_shot_result_time or 0)) < 0.45 then
                    local age   = now_t - (s.last_shot_result_time or 0)
                    local alpha = math.floor(220 * (1 - age / 0.45))
                    local fr, fg, fb = 255, 70, 70                       -- miss = red
                    if     s.last_shot_result == "hit"        then fr, fg, fb = 90, 255, 110
                    elseif s.last_shot_result == "serverfail" then fr, fg, fb = 90, 170, 255 end
                    local h  = math.abs((feet_pos.y or head_pos.y) - head_pos.y)
                    local bw = math.max(8, h * 0.30)
                    local x1, x2 = head_pos.x - bw, head_pos.x + bw
                    local y1, y2 = head_pos.y - 6, (feet_pos.y or (head_pos.y + h))
                    local fc = color(fr, fg, fb, alpha)
                    render.rect(vector(x1, y1), vector(x2, y1 + 2), fc, 0, true)   -- top
                    render.rect(vector(x1, y2 - 2), vector(x2, y2), fc, 0, true)   -- bottom
                    render.rect(vector(x1, y1), vector(x1 + 2, y2), fc, 0, true)   -- left
                    render.rect(vector(x2 - 2, y1), vector(x2, y2), fc, 0, true)   -- right
                end

                -- V9.51-A: desync wedge — two lines from the pelvis. White = the enemy's
                -- REAL eye_yaw, mode-color = our RESOLVED fake-yaw. The angle between them
                -- IS the desync we're shooting; lets you eyeball side + magnitude on the body.
                if esp_wedge and esp_wedge:get() and s.last_eye_yaw and s.last_resolved then
                    local base, t_eye, t_res
                    pcall(function() base  = render.world_to_screen(vector(ox, oy, oz + 36)) end)
                    local function tip(yaw_deg)
                        local rad = yaw_deg * math.pi / 180
                        return render.world_to_screen(vector(ox + math.cos(rad) * 26,
                                                             oy + math.sin(rad) * 26, oz + 36))
                    end
                    pcall(function() t_eye = tip(s.last_eye_yaw) end)
                    pcall(function() t_res = tip(s.last_resolved) end)
                    if base and t_eye then pcall(function()
                        render.line(vector(base.x, base.y), vector(t_eye.x, t_eye.y), ESP_COL_WEDGE)
                    end) end
                    if base and t_res then pcall(function()
                        render.line(vector(base.x, base.y), vector(t_res.x, t_res.y), s._espc_wcol or ESP_COL_WEDGE)
                    end) end
                end

                -- V9.53: ONE compact line, smaller font (size 3, was 4). Color = mode;
                -- confidence is the bar below, learn-state is the trailing icon (🔒/★/·).
                render.text(3, vector(head_pos.x, head_pos.y - 18), s._espc_col or ESP_COL_TXT, "c", txt)

                -- V9.53-C: compact netcode icon — THIS enemy fake-lags, so a resolver
                -- "miss" on them is server-side (filtered by v9.49), not ours. ⚠×N / bt / pk.
                if enh_on and s._espc_tag and s._espc_tag ~= "" then
                    render.text(1, vector(head_pos.x, head_pos.y - 30), ESP_COL_TAG, "c", s._espc_tag)
                end

                -- V9.51-E: shot-history dots (last 6) — green hit / red miss / blue serverfail.
                if enh_on and s.shot_history and #s.shot_history > 0 then
                    local n  = #s.shot_history
                    local dw, gap = 5, 2
                    local total_w = n * dw + (n - 1) * gap
                    local sx = head_pos.x - total_w / 2
                    for i = 1, n do
                        local k = s.shot_history[i]
                        local dc = ESP_COL_DOT_MISS
                        if     k == "hit"        then dc = ESP_COL_DOT_HIT
                        elseif k == "serverfail" then dc = ESP_COL_DOT_SF end
                        local dx = sx + (i - 1) * (dw + gap)
                        render.rect(vector(dx, head_pos.y - 42), vector(dx + dw, head_pos.y - 38),
                                    dc, 0, true)
                    end
                end

                if esp_show_confbar and esp_show_confbar:get() then
                    local bar_w = 40
                    local fill = math.floor(bar_w * conf / 100)
                    render.rect(vector(head_pos.x - bar_w/2, head_pos.y - 8),
                                vector(head_pos.x - bar_w/2 + bar_w, head_pos.y - 5),
                                ESP_COL_BAR_BG, 0, true)
                    render.rect(vector(head_pos.x - bar_w/2, head_pos.y - 8),
                                vector(head_pos.x - bar_w/2 + fill, head_pos.y - 5),
                                s._espc_fill or ESP_COL_BAR_BG, 0, true)
                    -- V9.53: side-dom mini-bar REMOVED (user: redundant — side is in the
                    -- label arrow, the second bar just added clutter).
                end
            end)
        end)
    end)
    end  -- end esp_show_labels gate

    -- ═══ HUD-corner overlay (drawn every frame from cached data) ═══
    if not (esp_show_hud and esp_show_hud:get()) then return end
    pcall(function()
        local now = globals.curtime or 0  -- V9.31: `now` was an undefined global (nil)
                                          -- here → HUD silently died at the last-combat
                                          -- line (nil arithmetic, swallowed by pcall).
                                          -- Same clock as current_target.time.
        -- V9.71 perf: panel position + screen_size + static line text now cached in
        -- esp_refresh_cache (10Hz) — draw path only positions and blits.
        local x0, y0 = hud_cache.x0 or 20, hud_cache.y0 or 80
        local panel_w, panel_h = 320, 150
        local line_h = 14

        -- background panel + border (drawn every frame)
        render.rect(vector(x0 - 8, y0 - 8), vector(x0 + panel_w - 8, y0 + panel_h - 8),
                    ESP_COL_PANEL, 4, true)
        local b = ESP_COL_BORDER
        render.rect(vector(x0 - 8, y0 - 8),                vector(x0 + panel_w - 8, y0 - 7),                b, 0, true)
        render.rect(vector(x0 - 8, y0 + panel_h - 9),      vector(x0 + panel_w - 8, y0 + panel_h - 8),      b, 0, true)
        render.rect(vector(x0 - 8, y0 - 8),                vector(x0 - 7, y0 + panel_h - 8),                b, 0, true)
        render.rect(vector(x0 + panel_w - 9, y0 - 8),      vector(x0 + panel_w - 8, y0 + panel_h - 8),      b, 0, true)

        render.text(3, vector(x0, y0),              ESP_COL_TITLE, nil, ESP_HUD_TITLE)
        render.text(3, vector(x0, y0 + line_h),     ESP_COL_TXT,   nil, hud_cache.txt_tracked or "")
        render.text(3, vector(x0, y0 + line_h * 2), ESP_COL_TXT,   nil, hud_cache.txt_learned or "")
        render.text(3, vector(x0, y0 + line_h * 3), hud_cache.conf_col or ESP_COL_TXT, nil, hud_cache.txt_conf or "")
        render.text(3, vector(x0, y0 + line_h * 4), ESP_COL_TXT2,  nil, hud_cache.txt_topmode or "")
        render.text(3, vector(x0, y0 + line_h * 5), ESP_COL_TXT2,  nil, hud_cache.txt_toprate or "")

        local age = now - (last_combat_event.time or 0)
        if age < 5 then
            local er, eg, eb = last_combat_event.was_hit and 100 or 255, last_combat_event.was_hit and 255 or 100, 100
            render.text(3, vector(x0, y0 + line_h * 6), color(er, eg, eb, 255), nil,
                string.format("Last: %s %s", last_combat_event.was_hit and "HIT" or "MISS", last_combat_event.mode))
        else
            render.text(3, vector(x0, y0 + line_h * 6), color(120, 120, 120, 200), nil, "Last: —")
        end

        -- V6+V7: current target intel + LOCK indicator
        local ct_age = now - (current_target.time or 0)
        if ct_age < 2 and current_target.idx > 0 then
            local cr, cg, cb = color_by_confidence(current_target.conf)
            local marker = current_target.known and (current_target.mode_match and "✓" or "✗") or "·"
            -- V7.0: check if target is "locked" (high samples + high confidence)
            local target_s = PlayerState[current_target.idx]
            local samples = 0
            if target_s then samples = (target_s.samples_left or 0) + (target_s.samples_right or 0) end
            local lock_tag = ""
            if samples >= 8 and current_target.conf >= 60 then
                lock_tag = " 🔒LOCKED"
                cr, cg, cb = 100, 255, 100  -- override to green for locked
            elseif samples >= 4 then
                lock_tag = " ★"
            end
            -- V9.9-D: HOSTILE-FIRE INDICATOR — show ⚡FIRED when V9.8 counter-fire window active
            local hostile_tag = ""
            if target_s and (target_s.last_hostile_fire or 0) > 0 then
                local ticks_since = (globals.tickcount or 0) - target_s.last_hostile_fire
                if ticks_since >= 0 and ticks_since <= 64 then
                    hostile_tag = " ⚡FIRED"
                    cr, cg, cb = 255, 180, 80  -- orange = counter-fire active
                end
            end
            render.text(3, vector(x0, y0 + line_h * 7 + 2), color(cr, cg, cb, 255), nil,
                string.format("→Target #%d %s %d%%%s%s [%s] %s",
                    current_target.idx, marker, current_target.conf, lock_tag, hostile_tag,
                    tostring(current_target.aa_type), tostring(current_target.mode)))
        end

        -- V6.8: session improvement trend (early vs recent hit-rate)
        local total = session_stats.total_hits + session_stats.total_miss
        if total >= 3 then
            local trend = session_stats.recent_rate - session_stats.early_rate
            local tr_r, tr_g, tr_b
            local trend_str
            if trend > 5 then       -- improving
                tr_r, tr_g, tr_b = 100, 255, 100
                trend_str = string.format("↑ +%.0f%% improving", trend)
            elseif trend < -5 then  -- declining
                tr_r, tr_g, tr_b = 255, 150, 100
                trend_str = string.format("↓ %.0f%% declining", trend)
            else
                tr_r, tr_g, tr_b = 200, 200, 200
                trend_str = "→ stable"
            end
            render.text(3, vector(x0, y0 + line_h * 8 + 2), color(tr_r, tr_g, tr_b, 255), nil,
                string.format("Trend: %s (recent %.0f%% vs early %.0f%%)",
                    trend_str, session_stats.recent_rate, session_stats.early_rate))
        end
        -- V9.50: server-fail filter readout. Shows how many correct-angle misses the
        -- server rejected (stale backtrack) were excluded from the hit-rate above, so the
        -- headline % is trustworthy and the netcode load on this server is visible.
        local sf = sel01_session_serverfails or 0
        if sf > 0 then
            render.text(3, vector(x0, y0 + line_h * 9 + 2), color(150, 180, 210, 230), nil,
                string.format("Netcode: %d server-fail%s filtered (not our miss)",
                    sf, sf == 1 and "" or "s"))
        end
    end)
end

-- V9.21: event ticker (top-right) + advisor panel (mid-left) renderer. Wired
-- as a global so the events.render hook can call it without touching locals.
function render_event_ticker()
    if not (esp_event_ticker and esp_event_ticker:get()) then return end
    if event_ticker.count == 0 then return end
    local sx
    pcall(function() sx = render.screen_size().x end)
    if not sx then return end
    local x = sx - 320
    local y = 80
    local now = globals.realtime or 0
    -- header
    pcall(function()
        render.rect(vector(x - 6, y - 4), vector(x + 305, y + 16),
                    color(15, 15, 20, 200), 2, true)
        render.text(3, vector(x, y), color(180, 220, 255, 255), nil,
                    string.format("▸ Sel01 Events (%d)", event_ticker.count))
    end)
    y = y + 18
    -- draw last N in chronological order (oldest at top, newest at bottom)
    for i = 1, event_ticker.count do
        local idx = ((event_ticker.head - event_ticker.count + i - 1) % event_ticker.cap) + 1
        local e = event_ticker[idx]
        if e then
            local age = now - (e.t or 0)
            local alpha = 255
            if age > 5 then alpha = math.max(40, 255 - math.floor((age - 5) * 35)) end
            pcall(function()
                render.text(3, vector(x, y),
                            color(e.r or 220, e.g or 220, e.b or 220, alpha),
                            nil, e.txt or "?")
            end)
            y = y + 14
        end
    end
end

-- V9.23: render_advisor_panel removed (on-screen). Advisor now lives entirely
-- inside the NL menu — labels updated via :name() on the pre-created slots.

-- NL docs: events.render is THE per-frame draw event. Wrap existing render-callback.
pcall(function()
    events.render:set(function()
        pcall(loading_render_callback)
        pcall(sidebar)
        pcall(esp_paint_handler)
        pcall(render_event_ticker)
    end)
    cs_log("ESP render hook installed (events.render)")
end)

-- hook last-combat-event update for HUD corner display
local _orig_mode_stats_update = mode_stats_update
mode_stats_update = function(mode, hit)
    _orig_mode_stats_update(mode, hit)
    last_combat_event.mode = mode
    last_combat_event.was_hit = hit
    last_combat_event.time = globals.curtime or 0
    session_record(hit)
end

local messagesEN = {
        "𝙹𝚄𝚂𝚃 𝙶𝙴𝚃 【b】【r】【a】【i】【n】 𝚈𝙾𝚄 𝚂𝚃𝚄𝙿𝙸𝙳 𝙵𝙰𝙶",
        "𝚈𝙾𝚄𝚁 𝙲𝙷𝙴𝙰𝚃 𝙸𝚂 𝙾𝙺, 𝙸𝚃 𝙹𝚄𝚂𝚃 𝙼𝚈 𝙰𝙰 𝙸𝚂 𝚄𝙽𝙷𝙸𝚃𝚃𝙰𝙱𝙻𝙴",
        "тебя уебал seltonmt01",
        "𝙸𝙼 𝚂𝙾𝚁𝚁𝚈",
        "1. i 𝐫𝐚𝐩𝐞𝐝 𝐲𝐨𝐮",
        "OWNED BY seltonmt01",
        "ty4clip bot hhhh",
        "1",
        "ow ned", 
        "bot",
        "omfg you so bad ngl",
        "LACHBOMBED n_N",
        "deported to hell d0g",
        "outplayed by seltonmt01",
        "ℕ𝕠 𝕆𝔾 𝕀𝔻? 𝔻𝕠𝕟'𝕥 𝕒𝕕𝕕 𝕞𝕖 𝓷𝓲𝓰𝓰𝓪",
        "𝐨𝐮𝐫 𝐥𝐢𝐟𝐞 𝐦𝐨𝐭𝐨 𝐢𝐬 𝐖𝐈𝐍 > 𝐀𝐂𝐂",
        "ｎｉｃｅ  ｔｒｙ  ｐｏｏｒ  ｄｏｇ",
        "1x1? 2x2? 5x5? rn",
}


local messagesRU = {
        "хаваюпсихотропики.рф",
        "1 why you play without brain?",
        "тебя выебал seltonmt01",
        "1",
        "1.",
        "1 ",
        "от со сал",
        "даже боты на локалке в меня не мисают",
        "ты че опять мне отсосал???", 
        "далбаеб ебаный прикупи мой кфг от seltonmt01",
        "ебаная тупица",
        "а те норм быть отъебанным???",
        "no brain no skill ",
        "братанчек хватит сакать",
        "ебучий даун как я тя ща трахнул нормалдаки?",
        "о да ты ща был выебан",
        "пидора с",
        "отфакан пидор",
        "отсакал? оправдайся",
        "я бы на твоем месте после этой хуйни вышел бы",
        "ой девочки вы упали",
        "далбаеб ебаный",
}				

math.randomseed(math.floor((globals.realtime or 0) * 1000000) + (globals.tickcount or 0))
math.random(); math.random(); math.random()

--varsы
local isON
local trashtype

local enabled = g_chat:switch(accent .. ui.get_icon"link-slash" .. accent .. "  Enable Sel01-Roast", false)
local trashtype = g_chat:combo(accent .. ui.get_icon"sliders" .. accent .. "  Message type", "RU", "EN", "1")

enabled:set_callback(function(ref)
    isON = ref:get()
    cs_log("Sel01-Roast " .. (isON and "enabled" or "disabled"))
end)

trashtype:set_callback(function(ref)
    trashtype = ref:get()
    cs_log("Sel01-Roast message type → " .. tostring(trashtype))
end)

events.player_death:set(function(e)
    local me = entity.get_local_player()
    local attacker = entity.get(e.attacker, true)
    local target = entity.get(e.userid, true)
    if me == attacker and target ~= me then
        -- V9.21: feed event ticker on every kill we get
        local nm = "?"
        pcall(function() if target.get_name then nm = target:get_name() end end)
        pcall(cs_event_kill, nm)
        if (type(isON) == "boolean" and type(trashtype) == "string") then
            local v1 = string.format("%s", isON)
            local v2 = string.format("%s", trashtype)
            if (v1 == "true") then
                local picked
                if (v2 == "RU") then
                    picked = tostring(messagesRU[math.random(1, #messagesRU)])
                elseif (v2 == "EN") then
                    picked = tostring(messagesEN[math.random(1, #messagesEN)])
                elseif (v2 == "1") then
                    picked = "1"
                end
                if picked then
                    utils.console_exec(string.format('say "%s"', picked))
                    cs_log_color("kill → say [" .. v2 .. "]: " .. picked)
                end
            end
        end
    end
end)

pcall(function()
    events.shutdown:set(function()
        cs_log("shutdown — unhooking events + clearing state")
        pcall(function() events.render:unset() end)
        pcall(function() events.aim_ack:unset() end)
        pcall(function() events.player_death:unset() end)
        pcall(function() events.createmove:unset() end)
        pcall(function() events.weapon_fire:unset() end)
        pcall(function() events.player_shoot:unset() end)
        pcall(function() events.ragebot_target:unset() end)
        -- V3 event unsets
        pcall(function() events.aim_fire:unset() end)
        pcall(function() events.ragebot_fire:unset() end)
        -- V4 + V8.6: FORCE save on shutdown (mark dirty so save fires unconditionally)
        learning_dirty = true
        pcall(learning_save)
        -- V8.3: also export JSON backup
        pcall(learning_export_json)
        _cs_log_color_raw("✓ Persistence: learned.lua + learned.json saved on shutdown")
        loading_effect = nil
        sidebar_anim  = nil
        for k in pairs(PlayerState) do PlayerState[k] = nil end
        for k in pairs(SteamMemory) do SteamMemory[k] = nil end
        anim_cache = {}
    end)
end)

-- V4: load persistent learning model on script start, then cleanup
learning_load()
pcall(learning_cleanup)
-- V9.63: surface the load result ON SCREEN (event ticker + multi-fallback console),
-- not only the console line that scrolls past. User reported "doesn't look like it
-- reloaded" — the load worked, the confirmation was just invisible with console closed.
pcall(function()
    local _lc = 0
    for _ in pairs(LearnedModel) do _lc = _lc + 1 end
    if cs_event_info then
        cs_event_info(string.format("Persistent model loaded: %d players", _lc))
    end
end)

_cs_log_color_raw("=========================================")
_cs_log_color_raw("Sel01-Solver v" .. SEL01_VERSION .. " loaded — by seltonmt01")
_cs_log_color_raw("Tab: '" .. TAB .. "' (Main / Resolver Core / Aggressive Tuning / Bruteforce / Experimental / Perf-Info / Logging / Sel01-Roast)")
_cs_log_color_raw("Resolver: " .. (resolver.enable:get() and "ON" or "OFF") ..
                  " | Mode: " .. tostring(resolver_mode:get()) ..
                  " | LBY-Snap: " .. (lby_snap_toggle:get() and "ON" or "OFF") ..
                  " | Air-Resolve: " .. (air_resolve_tog:get() and "ON" or "OFF"))
_cs_log_color_raw("Close-range: " .. close_range_dist:get() .. "u" ..
                  " | Force-Baim after: " .. force_baim_n:get() .. " misses (dmg=" .. baim_min_damage:get() .. ")" ..
                  " | Dormancy reset: " .. dormancy_reset_t:get() .. "ms")
_cs_log_color_raw("Experimental: " ..
                  "AA-Classify=" .. (exp_aa_classify:get() and "ON" or "OFF") ..
                  " | Multipoint=" .. (exp_multipoint:get() and "ON" or "OFF") ..
                  " | DEF-AA=" .. (exp_def_aa:get() and "ON" or "OFF") ..
                  " | SteamMem=" .. (exp_steam_mem:get() and "ON" or "OFF"))
_cs_log_color_raw("V3 Features: " ..
                  "aim_fire-snap=" .. (exp_aim_fire_snap:get() and "ON" or "OFF") ..
                  " | per-side-desync=" .. (exp_perside_desync:get() and "ON" or "OFF") ..
                  " | ESP=" .. (exp_esp_overlay:get() and "ON" or "OFF") ..
                  " | cancel-conf=" .. (exp_cancel_conf:get() and "ON" or "OFF") ..
                  " | auto-weapon=" .. (exp_auto_weapon:get() and "ON" or "OFF"))
_cs_log_color_raw("V4 Features: " ..
                  "persistent-learning=" .. (exp_persistent_lm:get() and "ON" or "OFF") ..
                  " | extrapolation=" .. (exp_extrapolation:get() and "ON" or "OFF") ..
                  " | predict-ticks=" .. exp_predict_ticks:get() ..
                  " | respect-manual-SSG=" .. (exp_respect_man:get() and "ON" or "OFF"))
_cs_log_color_raw("Performance: anim-cache + FOV-cull(110°) + dist-cull(4500u) + lazy-log → ON")
_cs_log_color_raw("Accuracy: measured-desync EMA + side-streak bias + yaw-extrapolation → ON")
_cs_log_color_raw("Aggressive preset = first-shot velocity bias, opposite→58 brute-force, baim after 2 misses")
_cs_log_color_raw("V9.18: ALL min_damage overrides REMOVED — NL min_dmg is source of truth. HEAD-FOCUS hc=40 block DELETED (was downgrading NL hc).")
_cs_log_color_raw("V9.19: Adaptive guess magnitude (session median replaces 29° fallback) + Alt-mode dom-bias (Predicted-Alt/Air-Alt/Slow-Alt/Still-Alt prefer dom-side over blind flip).")
_cs_log_color_raw("V9.20: AA Advisor tab → per-enemy config recommendations (Refresh / Next / Show / Show-ALL buttons).")
_cs_log_color_raw("V9.21: Event ticker top-right (HIT/MISS/KILL always visible) + Advisor on-screen panel toggle (📺) + console HIT/MISS always-on.")
_cs_log_color_raw("V9.22: Predicted-Alt/Streak mag-fix — uses per-side measured (was preset 58° × 0.85). Dom-R 36° enemy: 49° → 36° (no over-shoot).")
_cs_log_color_raw("V9.23: Advisor panel moved INSIDE NL menu (label :name() updates) — no on-screen overlay. Event ticker stays top-right.")
_cs_log_color_raw("V9.24: effective_desync 2→1 sample gate (one hit beats blind 58°) + LBY-Snap miss flips only on |delta-measured|>5° (no flip-flop on backtrack fails).")
_cs_log_color_raw("V9.25: cs_event_* console fallback (HIT/MISS/KILL now print to in-game console too) + AA Advisor wording rewritten plain-English with color-coded DO/why/warn/good lines.")
_cs_log_color_raw("V9.26: 📨 Send tips to CSGO chat button (Advisor) + EMA drift-bump alpha 0.30→0.55 on >5° change (catches enemy mag changes in 2-3 hits).")
_cs_log_color_raw("V9.27: Coach-chat lines now address @enemy by name + up to 4 concrete tips per send (type + dom + magnitude). No more bare 'hey'.")
_cs_log_color_raw("V9.28: Coach-chat each line explains WHY enemy AA is exploitable + HOW to fix (was only stating facts). 4 lines: problem/fix/dom/mag.")
_cs_log_color_raw("V9.29: Coach-chat 3 wording variants per category (name-hash deterministic) + data-driven WHY (real streak/dom counts) + BIMODAL detection.")
_cs_log_color_raw("V9.30: AA-switch hard-reset — when |actual - EMA| > 10° on samples>=3, replace EMA with actual + decay samples to 40% (catches preset changes in 1 hit).")
_cs_log_color_raw("V9.31: correction-flip server-side-fail GUARD (only flip side when angle was actually wrong >5° — stops L/R oscillation & BF:opposite garbage) + LOCKED-target head-pref (relax NL safepoint on 8+sample/60+conf targets → head not body).")
_cs_log_color_raw("V9.32: bimodal-switch detection (suppress global hard-reset thrash on two-mode enemies) + event ticker shows Δ/meas/conf/side + bt on misses + RebuildServerYaw nil-sentinel (no more resolve-to-0° on reconstruct fail).")
_cs_log_color_raw("V9.33: air-branch recent_resolved push (cancel-conf/conf now air-aware) + snapshot tick-window guard (no stale cross-engagement match) + boot nil-guard + adaptive-guess cap 58 + [EXP off] pose-param side read.")
_cs_log_color_raw("V9.34: AIR-branch hardening — per-side magnitude in air corr-aware path (was global, wrong for bimodal) + update_jitter now runs in air (yaw_cache/rate warm → correct aa_type on landing + air-spin visible).")
_cs_log_color_raw("V9.35: fast-fire tightened — only fires fast on stable (stddev<12) + well-sampled resolves, hc floors raised (30/45 not 15/22/30). Stops the 'shoots too early' marginal shots that caught bad backtrack records → correction/prediction-error rejects.")
_cs_log_color_raw("V9.36: snapshot-match REGRESSION FIX — v9.33 matched ack-time tickcount (grabbed the most-recent snapshot, mis-learned sides on rapid fire). Restored event.tick matching of the actual acked shot; kept the stale-reject guard.")
_cs_log_color_raw("V9.37: AIR first-contact fix (Air was worst @25%) — air guess magnitude biased high (max(median,42), airborne=near-max desync) + first-contact side uses steam-mem dom instead of blind +1.")
_cs_log_color_raw("V9.77: Networked-Boost side-conflict guard (RebuildServerYaw side can flip on a hard one-sided enemy — real-dump idx=5 streak L=20 R=0, rebuild said R → boosted 29° R twice → 0/2; learned_dom_side now vetoes a wrong-side boost on ground + air) + server-fail filter honesty (a bt=0 err=0 kept-side miss is OUR switch/side misprediction not netcode; err<=5 branch now needs bt>=4 — real-dump idx=5 had ~14 bt=0/2 keeps excused, headline 86.7% vs raw 59.1%).")
_cs_log_color_raw("V9.78: BF cycle real-dominance ordering — pick_bruteforce_angle led every static/slow BF cycle with 'opposite' (flip to -last_shot_side), which on a firmly one-sided enemy flips onto the side they have NEVER been on = guaranteed whiff (real-dump BF:opposite 0/2; idx=7 real 5L/0R flipped R, idx=8 7R-dom flipped L). Now real_left/right one-sided (>=3 dom, 0 other) sweeps MAGNITUDE on the proven side first + demotes opposite to last; balanced/switch keep opposite-first (V9.63).")
_cs_log_color_raw("V9.79: BF real-dominance broadened to switch AA — v9.78's reorder was gated to static/slow, but the one-sided locks were aa=switch (idx=8 real 10R/0L still fired BF:opposite LEFT; idx=12 9R/0L fired BF:opposite LEFT) and fell through to the opposite-first default. A >=3-vs-0 REAL split is a confirmed lock regardless of AA-class, so the dominant-side magnitude sweep now applies to ALL non-defensive aa_types. Genuine alternators (real hits both sides, idx=6 L=2 R=1) stay opposite-first.")
_cs_log_color_raw("V9.81: PERSISTENCE GAP — per-player learning DID save + reload (7 players on disk, boots in dump), but boot restored measured/samples/side/best-modes and NEVER seeded s.real_left/right. The saved sl/sr ARE real hit counts (only bumped on a confirmed hit), yet a known 17-hit enemy rebooted with real_right=0 → one_sided BF ordering (needs real>=3), alt_side_pick real-dominance, and the confidence real-weight cap all stayed OFF. Magnitude + side recalled but the 'locked one side' intelligence did not — looked like nothing persisted. Boot now seeds real_left/right from saved sl/sr (cap 10) when no session real hit held on that side yet.")
_cs_log_color_raw("V9.80: three fixes targeting the idx=10 problem enemy (def static, miss-rate 50%). (1) SERVER-FAIL FILTER HONESTY — the bt>8 branch pardoned ANY high-backtrack miss outright, even one whose magnitude was also wrong (idx=10 our=57 meas=45 err=11.9 bt=24; idx=9 our=29.7 meas=19.3 err=10.4 bt=25). bt>8 now pardons only when err<=8 (or no measurement); a high-bt + high-err miss COUNTS — headline no longer flattered by our own overshoots. (2) DEF-CYCLE DOMINANCE — a ratio-dominant def enemy (idx=10 real R=5 L=1, not one_sided since L≠0) wasted shots on opposite/wrong-sign (BF:opposite 0%, BF:+58 0%); now leads the proven side's def magnitude + demotes opposite. (3) DEF_DELTA CAP — def_delta latched a lone 57.8° fingerprint while per-side measured R was 45° → BF:def+ overshot 12°; dd now capped toward dominant per-side measured.")
_cs_log_color_raw("V9.76: AA-classify oscillation-freeze — the V9.10 anti-flap counted commits in a 10s window, which a SLOW static<->switch<->static revert (spread >10s) dodged entirely (real-dump idx=3/7/11 flapped at long range on yaw noise; idx=7 mode-thrashed switch->static->switch into a miss right after a hit). Now an A->B->A revert (committing back to a type just left) freezes the classifier 5s regardless of timing. A genuine progression (static->switch->jitter) never reverts so real AA changes are untouched.")
_cs_log_color_raw("V9.75: AIR magnitude boost — the air-branch now boosts an undershot RebuildServerYaw to the known measured/passive air magnitude (keeps the rebuilt side), porting the ground Networked-Boost that already hits 4/4=100%. RebuildServerYaw gives a reliable SIDE but undershoots magnitude in air; a never-hit-but-passively-known air enemy fired the raw short angle and missed (real-dump idx=9: passive/measured 33.9°, rebuild +15° R = correct side 18.9° short → miss). Only fires in the trust-rebuild fall-through (corr-aware / both-sides / cold blocks unchanged).")
_cs_log_color_raw("V9.38: correction guard is side-aware + correct-angle serverfails retry same side once; BF now trusts strong passive desync before max_desync.")
_cs_log_color_raw("V9.64: two bimodal/asymmetric fixes from the v9.63 session dump. (1) Air-CorrFlip now respects the V9.63 two_side_switcher guard — it was the worst mode (0/2): on a bimodal enemy it flipped side on corr_diff and fired the FAR-side magnitude on the wrong side (idx=3 shot 51.1° vs meas 23.6, idx=6 29.3° vs 7.6). When both sides have real hits OR bimodal flag set, KEEP the air side, let BF cover both. (2) ack_angle_err now references the PER-SIDE magnitude we actually fire, not the global EMA — idx=1 fired its learned R-side 40.8° on-target but err was computed vs global 31.2° → fake err 9.6 → a clean server-fail got counted as a real miss + mode-blacklisted. Unimodal unchanged.")
_cs_log_color_raw("V9.39: sample-count EMA alpha ramp (0.55 on hit 1-2, 0.42 on hit 3-4, then 0.30) on global + both per-side — converges in 2-3 hits instead of 5-6, faster + smoother lock (side settles sooner, fewer first-shot mode flips).")
_cs_log_color_raw("V9.40: point-blank stale-record fix — non-sniper close-priority now forces multipoint (was sniper-only) so a single-point head shot stops whiffing on an enemy running at you (correct angle, high bt, reason=correction). + bt-driven backtrack-resistance (high event.backtrack on correction/prediction-error now counts, was string-only).")
_cs_log_color_raw("V9.41: air-guess magnitude is per-player passive-aware — uses THIS enemy's measured/passive-seeded desync before the blind floor (v9.37's max(median,42) overshot low-desync air enemies by ~30° and ignored 50+ passive obs we already had). Blind floor softened 42→36.")
_cs_log_color_raw("V9.44: serverfail-retry magnitude fix — retry now shoots the LEARNED desync, not max(|shot delta|, measured). The old max() memorised a magnitude OVERSHOOT (a kept-side err>5 miss) into serverfail_retry_mag and BF:retry repeated it — fatal on a LOCKED enemy (logs: idx=3, 18 hits, known 22.3°, shot 41.9° twice). Stops the overshoot feedback loop.")
_cs_log_color_raw("V9.45: seed-only keep-side fix — the 'magnitude matched measured → server fail, keep side' branch now requires a REAL hit (real_active>=1) or genuine backtrack (bt>6). On a never-hit enemy measured_desync is pure passive seed; matching it proved nothing and froze the side on the WRONG guess forever (logs: idx=8, p_hits=0/2, seed 52.2°L, shot left twice, 2nd shot bt=0). Now explores the other side instead.")
_cs_log_color_raw("V9.46: teleport-on-peek detection — horizontal origin delta vs max run-speed reveals a blink-peek (lag-switch / fakelag-flush). On detect, time-box 0.4s that disables extrapolation (yaw_rate from before the blink can't predict the landing) + forces full-spread multipoint at close range so NL's stale backtrack record still lands. Reacts on the FIRST peek instead of after 2 misses; never touches side/EMA so v9.45 + learned patterns stay intact.")
_cs_log_color_raw("V9.47: side-conflict overrides high-bt keep when angle was off — a learned wrong-side shot with a LARGE magnitude error (>10) now flips even under bt>8, because a clean stale-record reject leaves err~0. Old order let bt>8 short-circuit the flip and retry the wrong side (logs: idx=8, 1 R-hit, shot L -21.6 vs meas 39.5 err=17.9 bt=12 — kept L; next real hit confirmed R). err~0 + side-conflict still keeps (switch-stale / v9.42 overshoot / v9.44 locked protected).")
_cs_log_color_raw("V9.48: alt_side_pick uses REAL-hit dominance when both sides have real hits — the seeded-inclusive sample counts (sl/sr carry passive+seeded entries) mispinned a genuine 50/50 switch enemy. Logs: idx=4 sl=3 sr=1 pinned LEFT for Predicted-Alt but real hits were 1L/1R and the correct side was RIGHT (Predicted-Alt 0/2). Balanced real data now alternates off last_hit_side; one-sided enemies (rr=0) keep the old seeded dom path so streak{L=9 R=0} is unaffected.")
_cs_log_color_raw("V9.58: chernobl-style TABS — split the single tab into Main / Resolver / ESP+Advisor / Advanced horizontal tabs (distinct ui.create first-args) + ui.sidebar(name,icon). Re-tabbing re-keys UI elements once, toggles reset on first reload -> click a preset to restore. No logic change.")
_cs_log_color_raw("V9.57: cosmetic — chernobl-style menu groups (icon + 'Sel01 \194\187 Section' headers) + multi-color welcome label (username/version in accent). Group rename re-keys UI elements once, so toggles reset on first reload — click a preset to restore. No logic change.")
_cs_log_color_raw("V9.56: LBY-Snap-Guess miss-flip is now bt/measurement-aware (matches the generic V9.42/V9.47 logic this older branch never got). It used to flip side on err>5, but err=inf when there is no measurement (first contact, measDesync=0) so it flipped blindly on EVERY first-contact miss — and a high bt (>8) is a server stale-record reject, not a side error. Logs: idx=2 our=29 meas=0 err=inf bt=13 flipped to -1 while the generic path KEPT side=1 the same tick (the two handlers disagreed). Now: no measurement + high bt -> keep + retry the guess once, never flip an unconfirmed side.")
_cs_log_color_raw("V9.55: honest hit-rate — server-fail filter now reuses the ack_serverfail_like signal (err<=5 OR bt>8) the mode-blacklist already trusts, instead of filtering EVERY kept-side miss. A bt=0 keep with a real magnitude error is the resolver's own side-misprediction on a switch/bimodal enemy (logs: idx=1 bimodal L=40°/R=17.5° kept side ×3 at bt=0 err=10-40 — counted as netcode, inflating session 76.5%->96.3%). Those now count; only clean stale-record rejects (bt>8 / err~0) stay excluded. No aim change, stats only.")
_cs_log_color_raw("V9.65: PERF/smoothness — RebuildServerYaw is now memoised per (tick, player). It was recomputed up to ~5x per resolve per enemy (once in resolve_player + once in each pick_first_shot branch), every call an FFI-heavy anim_state + velocity + LBY read. The result depends only on this-tick player state, so caching is behaviour-identical — pure FFI-work reduction (lighter per-tick load, smoother frametimes in 5-man HvH). No aim/learning change.")
_cs_log_color_raw("V9.70: pose-promotion is NON-STICKY (real-dump bug #2). v9.69 promoted on the FIRST threshold cross and never demoted, so a small-sample fluke locked in: idx 16 hit 1.28σ at n=20, was marked '<<< BEST', then DECAYED to 0.58σ at n=23 while still showing best. Now we re-scan all indices every hit and pick the current best meeting STRICTER gates (n≥25, 6+ per side, |sep|≥1.3); if none holds, g_pose_best_idx clears → honest dump. A real body_yaw index must HOLD its separation as samples grow; noise self-demotes. On the user's build no index sustained ≥1.3 (max ~0.78) → this NL build does not cleanly expose body_yaw, so pose-read stays a dead end here and the OTHER levers (v9.66 prediction, speed-bucket, on-shot, switch-period) carry.")
_cs_log_color_raw("V9.71: PERF + DEAD-CODE batch (full-code audit). Perf: (a) UI :get() reads cached once per tick in tick_cache (close-range/air-resolve/aa-classify/classify-int — were per-enemy×64Hz menu-API calls); (b) yaw_rate_buf + recent_resolved are circular rings now (table.remove(1) shifted per tick per enemy; recent_resolved also reuses entry tables → zero alloc steady-state); (c) ESP label compute (confidence() circular stddev + mode-string finds + string.format + color objects) throttled to 5Hz per enemy in _espc_* cache — draw path just blits; (d) constant render colors hoisted to module globals; (e) HUD panel text/position/conf-color pre-formatted at the 10Hz refresh. Dead code REMOVED: exp_head_focus + exp_hitbox_chain toggles (dead since v9.18 deleted the HEAD-FOCUS override block — they set state nothing read; 'Head + Chest Fallback' strategy now equals 'Head Bias'), apply_hitbox_chain(), DegToRad/RadToDeg. Frees 4 main-chunk locals.")
_cs_log_color_raw("V9.73: real-dump fixes (v9.72 logs). (1) ONE-SIDED SWITCH UNSTICK — a switch enemy with correct magnitude (err<2) that takes 2 consecutive correct-angle KEEPs on the same side now FLIPS instead of looping KEEP forever (idx=4 aa=switch L=3/47.9 R=0, 6+ KEEP err=0.0, 75% miss — the switch had moved sides). (2) BF:retry CAP — a static enemy with samples that takes 2 correct-angle keeps commits the measured desync (Static-Meas) instead of jittering the magnitude (idx=2 our 42.7→43.3→38.2→50.9 vs meas 41.6, missCount 4 no converge). (3) COLD-AIR GATE — Air with zero hit-EMA + no passive baseline no longer fires a blind trusted angle; it alternates side by miss-count at a high air prior (idx=2 Air measDesync=0 samples=0 delta=27.4 MISS). (4) conf<15 SKIPS speculative correction — let the BF cycle sweep sides instead of guessing flips on a conf=5 player. (5) re-track NO LONGER CLOBBERS session-learned per-side EMAs from the persistent LearnedModel (kept mid-session momentum; the repeated boots were wiping it). (6) correct-angle server-fail keeps tagged so Static-Meas mode-confidence is never decayed (mode_stats already gated; flag makes it explicit).")
_cs_log_color_raw("V9.72: real-dump fixes (SSG-Pro session 6/11). (1) SPREAD-MISS FILTER — reason='spread' means the angle was accepted and the bullet RNG'd; it now skips mode-stats/learning/per-player counters + mode-blacklist exactly like server-fails (real-dump: idx=4 took 2 spread misses that polluted Slow-Passive + BF:def+ stats and read as 0/3 resolver failure). s.missed still escalates baim/multipoint = the correct anti-spread response. New counter sel01_session_spreadfails + [SESSION] dump line. (2) PASSIVE-SIDE KEEP on blind first-contact — the explore-flip now checks passive_n_left/right (new per-side obs counters): when 20+ obs lean 2:1 to the side we just shot, a first-contact magnitude miss keeps the side (idx=6: 550 passive obs backed R, err=11.8 was magnitude, flip to L was wrong — 4 later real R-hits). V9.49 never-hit explore still breaks frozen guesses after 2 keeps. (3) Boot-log throttle keyed OUTSIDE PlayerState (dormancy reset recreated s and wiped the throttle → same boot logged 3×).")
_cs_log_color_raw("V9.69: pose-calibration scorer FIXED (real-dump bug). The v9.67 sign-vs-running-mean scorer FALSELY read 'eff 100%' on every CONSTANT pose index when the early hits were one-sided (dump: 3 right-side hits → idx 0/1/4/5/9/11.. all 0%/eff100%) — it would have promoted a garbage constant index. New scorer uses SEPARATION: track the param's mean on LEFT hits vs RIGHT hits; body_yaw is the index whose two side-means split cleanly (|meanR-meanL| ≥ 1.2σ). Promotion now needs 20+ hits, 5+ on EACH side, real variance. Dump shows sep(σ) + nL/nR + meanL→meanR. To calibrate: fight enemies you hit on BOTH sides.")
_cs_log_color_raw("V9.68: presets brought up to v9.65-67. ALL 6 presets now set the new levers explicitly (were untouched → left on user state). pose-collect ON everywhere (pure data, harmless). SSG-Pro (BALANCED, your main): pose-collect + on-shot flip ON, pose-USE + switch-period OFF until you validate the 'Dump Pose Calibration' index — SSG aim stays effectively identical, only learns + handles on-shot AA. Dynamic = experimental showcase (switch-period ON too). Defensive = data-only (no aim-changing levers). The toggle-less v9.65 perf / v9.66 prediction rework / v9.67 speed-bucket were already active in every preset.")
_cs_log_color_raw("V9.67: four new resolver levers (all opt-in toggles, default OFF except #C which is a safe refinement). #A POSE-PARAM CALIBRATION — collect pose[0..23] vs known hit-side on every HIT, auto-find the index that encodes body_yaw → turns SIDE from a statistical guess into a DIRECT read (toggle 'Pose Calibration' + 'Use Calibrated Pose Side' + 'Dump Pose Calibration' button). #B SWITCH-PERIOD — observe the server's per-tick predicted feet-yaw side (visible without a hit), detect a regular flip interval, predict which side the fake is on at shot-land (toggle 'Switch-Period Side Predict'). #C SPEED-BUCKET magnitude — split measured desync into standing vs moving buckets (real desync shrinks with speed) and use the bucket matching shot-time speed in the global fallback. #D ON-SHOT FLIP — learn enemies whose desync flips the tick they fire (2 wrong-side misses inside their fire window) and flip the resolved side in that window (toggle 'On-Shot Side-Flip Learn'). All three direct-side sources resolve through one central branch; inert for anyone who doesn't opt in.")
_cs_log_color_raw("V9.66: PREDICTION rework. (#1) Unified predictor — interp-comp (lerp+ping/2) + tick-lead now fold into ONE term; old code threw away the interp-comp whenever the lead fired (you got one OR the other, never both vs a strafer). (#2) Decel-damping — track yaw_accel; when the enemy is braking (accel opposes rate) the LEAD portion shrinks to 0.3×, so a corner-peek-STOP is no longer overshot (the scout 1-tap case). interp-comp never damped. (#5) dead predict_yaw_ahead (inlined) + predict_position (never called) removed → 2 main-chunk locals freed. (#6) yaw_rate_consistent threshold tightened 60→35 / 0.7→0.5 so a jittery spinner stops passing as a clean steady spin.")
_cs_log_color_raw("V9.54: serverfail-retry magnitude is now PER-SIDE on bimodal enemies — the retry froze the GLOBAL desync EMA (s.measured_desync), but a two-mode enemy (idx=10 L=46.2° R=29.7°, diff 16°) has very different per-side magnitudes and the global average swings mid-round. The kept side then re-fired a wrong magnitude for up to 64 ticks (logs: idx=10 retried 15.7° at a 29.7° R side, err=16). Now mirrors effective_desync's per-side pick (measured_left/right with >=1 real sample). Identical to global on unimodal enemies; strictly more accurate on bimodal.")
_cs_log_color_raw("V9.53: ESP made COMPACT (v9.52 words too big). Now ONE short line per enemy, smaller font: [aa-icon] [side-arrow] [deg] [learn-icon] e.g. '⇄ → 29° ★'. AA-icon: ▬static ⇄switch ≈jitter ⟳spin. Learn-icon: 🔒locked / ★learned / ·learning. Confidence = the bar (color), no second text line. Netcode shrunk to '⚠×N bt pk'. SIDE-DOM mini-bar REMOVED (redundant — side already in the arrow; was just clutter). Confidence bar stays.")
_cs_log_color_raw("V9.52: ESP labels rewritten in PLAIN WORDS (the v9.51 glyphs ⇄ ·2+53 ★ 🔒 👁 🛡net× were unreadable). Now two clean stacked lines per enemy: MAIN (mode color) = 'TYPE SIDE DEG' e.g. 'SWITCH  R 36°  PRED'; STATE (progress color) = 'LEARNED 4  72%' (NEW / SEEN / LEARNING n / LEARNED n / LOCKED n + confidence%). Netcode tag is now words: 'FAKELAG' (backtrack-resistant) / 'NET×N' (server-fails) / 'PEEK' (teleport-peek). Flash + dots + dom-bar + wedge unchanged (visual, not cryptic). Nothing removed — just readable.")
_cs_log_color_raw("V9.51: on-model ESP visuals — (A) desync wedge: white line = enemy real eye_yaw, mode-color line = our resolved fake-yaw, drawn from the pelvis so the angle between them IS the desync. (B) hit/miss flash: a ~0.45s fading box around the model, green=hit / red=miss / blue=server-fail. (C) netcode tag: 🛡bt + ⚠net×N + ⚡peek above the label so you see THIS enemy fake-lags (resolver 'miss' = server-side). (D) AA-glyph ▣static ⇄switch ∿jitter ⊛spinner prefixed to the label. (E) shot-dots: last 6 results as a colored dot row. (F) side-dom mini-bar under the conf bar (orange L vs blue R real-hit split). Three new toggles (Desync Wedge / Hit-Miss Flash / Enhanced Tags), all default ON in the SSG-Pro preset.")
_cs_log_color_raw("V9.50: server-fail filter readout — the V9.49 netcode-miss counter (sel01_session_serverfails + per-player s.serverfail_misses) is now surfaced in the copy-dump ([SESSION] shows N filtered + the raw pre-filter %) AND the HUD corner ('Netcode: N server-fails filtered'). Makes the headline hit-rate trustworthy: you can see how many correct-angle shots the server rejected vs real resolver misses. Counter clears on Reset Session Stats. Pure observability, no resolver-behaviour change.")
_cs_log_color_raw("V9.49: confirmed server-fail keeps no longer pollute stats — a correct angle (err~0) the server rejects via a stale backtrack record (high bt, side kept) is netcode, not a resolver miss. It's now excluded from session hit-rate, per-mode stats, per-player rate AND the persistent learned ratio (s.missed still increments so BF cycle + force-baim escalate). Logs: idx=9 fired -21.8° ×3 into bt 20→10→5 err=0 then hit shot 4; idx=4 kept ×3 err=0.3 across Air+Jitter-Cls — these dragged session ~56% when true resolver rate was ~82% and falsely flagged Air as 'weak'. Plus never-hit explore: after 2 consecutive correct-angle keeps on a real_active==0 enemy, flip once to break a frozen wrong-side guess (idx=5 0/2 shot LEFT while passive leaned RIGHT 42.9°); a single real hit disables it.")
_cs_log_color_raw("V9.43: backtrack-resistance escalates faster — point-blank fakelaggers with correct angle (our=meas, err=0) but server-reject (bt 7-10) now flip the resistant flag after 2 high-bt fails OR one bt>12, instead of 3 (was wasting 2 sure shots). Pairs with v9.40 full-spread multipoint to catch slightly-stale records.")
_cs_log_color_raw("V9.42: side-flip from SIDE evidence not magnitude error — ack_angle_err is a MAGNITUDE metric (wrong-side miss = small err, magnitude overshoot = large err), so old 'err>5 → flip' flipped the correct side on magnitude misses (idx=4: real 36°L, we 55°L, wrongly flipped R). Now flip only on learned side-conflict or blind first-contact; magnitude misses keep side, BF cycles the magnitude.")
_cs_log_color_raw("V9.63: two-side switcher fixes — (A) BF 'opposite' now inverts the side WE JUST SHOT (last_shot_side) not -last_hit_side, so after a correction-flip BF genuinely alternates L/R/L/R and sweeps both sides instead of locking back onto the just-tried wrong side (logs: idx=3 Recall +41.9 MISS→flip L, then BF:opposite +24.4 R again, +58 R again, all while enemy sat on R → 60% miss). (B) confirmed two-side switcher / bimodal enemies (real hits BOTH sides OR s.bimodal) treat a low-error / high-bt miss as a MAGNITUDE problem: KEEP the shot side + let the BF sweep cover both, never flip on the noisy per-side sample lead that flips every shot. (C) PERSIST: Export button now ALSO writes learned.lua (the ONLY file load reads — learned.json was never loaded back, so Export-then-restart looked like it didn't reload). Load result now shows on the event ticker too, not just the console line that scrolls past.")
_cs_log_color_raw("V9.62: serverfail-retry magnitude USE-SITE guard (V9.44 fixed the setter, this guards the getter) — if the stored serverfail_retry_mag deviates >15° from the CURRENT learned per-side desync, the stored value is suspect (slot reuse / poisoned from an earlier engagement) and the fresh learned magnitude is used instead. Caught idx=11: BF:retry fired -44.5° on a proven 25.4° enemy (learned L=24.9°), a 19.6° overshoot whose origin wasn't derivable from the shot's own data. Free hardening: agrees with stored when sane, overrides only on wild drift.")
_cs_log_color_raw("V9.61: sticky AA-classification for well-learned enemies — once we've HIT an enemy 4+ times (real_active), reclassifying its AA type on borderline yaw_cache noise just thrashes the resolver mode/label every few seconds (logs: idx=5 still+slow enemy flapped jitter<->static 6+ times while hitting 4/4; the slow flap dodged the 10s anti-flap window). Cold enemies stay responsive (7 evals / 2s lock); learned ones now need 14 consecutive evals + 4s lock to flip. measured_desync + side adapt independently so slower aa_type ≠ worse aim — pure smoothness. No hit-path change.")
_cs_log_color_raw("V9.60: 'Air*' no longer pollutes best_mode storage — Air/Air-Alt/Air-CorrFlip are POSITIONAL (enemy airborne), not an AA-pattern, but were saved as best_static/best_switch when an enemy was hit mid-air. The known-player fast-path never uses them (only acts on Static/Jitter) so zero benefit, but intel.mode_match compared the grounded resolve (e.g. Static-Meas) against the stored 'Air' → false mismatch → +15 conf cancel threshold → good shots cancelled on known enemies (logs: idx=3 sw=Air, name_369738400 s=Air). Added '^Air' to the save-filter + the load migration (same V9.0 precedent that dropped BF:/*-Guess). Stats/cancel only, no aim-path change.")
_cs_log_color_raw("V9.74: jitter+defAA BF fix + dump visibility + air/BF:retry guard (v9.73 logs). (1) pick_bruteforce_angle SKIPS the def_delta (BF:def+) cycle when aa_type=='jitter' — jitter oscillates between two yaw positions so there is NO stable defensive delta; BF:def+ kept whiffing (idx=3 0/1) while BF:opposite (full opposite hemisphere) is what catches jitter. Falls through to the standard BF oscillation; aim_ack logs the jitter+defAA+no-samples case. (2) copy-dump [P] lines now show passive_n_left/right as pL=/pR= so the v9.72 passive-side-keep is verifiable from a dump. (3) resolve_player air-branch YIELDS to a pending BF:retry — the retry is consumed only inside pick_bruteforce_angle, which the air-branch short-circuits with an unconditional return, so a KEEP-scheduled retry that coincided with the enemy going airborne was eaten (idx=14 KEEP scheduled, logged mode=Air not BF:retry). (4) IMPROVEMENT HINTS: jitter+defAA hint + 0-real/30+passive-obs hint.")
_cs_log_color_raw("Logging: " .. (log_enabled:get() and ("ON" .. (log_verbose:get() and " (verbose)" or ""))  or "OFF"))
_cs_log_color_raw("=========================================")
