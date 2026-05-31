-- ╔══════════════════════════════════════════════════╗
-- ║  Sel01-WalkBot                                     ║
-- ║  Version: 1.4                                      ║
-- ║  Greedy nav-bot: map + enemy detect, walk-to-foe  ║
-- ║  by seltonmt01                                     ║
-- ╚══════════════════════════════════════════════════╝
-- @name Sel01-WalkBot
-- @version 1.4
-- @author seltonmt01
-- @description Greedy walk-bot. Detects map + enemies, walks the local player
--   toward a chosen target using NL movement cmd (move_yaw + forwardmove) with
--   trace-based obstacle avoidance, auto-jump, and stuck-breakout. NO nav-mesh
--   (Option A MVP) — walks straight at the target and strafes/jumps around walls.
--   Aiming stays with the user / ragebot; this only drives MOVEMENT.
--
-- Confirmed NL API used (from real build scripts externalapaha / chernobl / JAG0YAW):
--   cmd.move_yaw (deg, world walk direction) + cmd.forwardmove (±450) + cmd.sidemove + cmd.in_jump
--   utils.trace_line(start, end, skip_ent) -> {fraction, end_pos}
--   entity.get_players(true) (enemies) / entity.get_local_player() / p.m_vecOrigin / p:get_eye_position()
--   globals.mapname / globals.tickcount / globals.realtime

local SEL01_WB_VERSION = "1.4"

local ffi_ok, ffi = pcall(require, "ffi")

-- ─── small helpers ───────────────────────────────────────
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end

local function v_len2d(v)
    return math.sqrt((v.x or 0) ^ 2 + (v.y or 0) ^ 2)
end

-- world direction (deg) from vector a -> b, as NL move_yaw expects (atan2(dy,dx))
local function dir_yaw(a, b)
    return math.deg(math.atan2((b.y - a.y), (b.x - a.x)))
end

-- normalize an angle to [-180,180]
local function norm_ang(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end

-- map name: NL exposes it via common.get_map_data() (.shortname e.g. "de_mirage"),
-- NOT globals.mapname (which is nil on this build — that was the "doesn't detect
-- mirage" bug). Returns nil when no map is loaded (menu / loading).
local function safe_mapname()
    local md = nil
    pcall(function() md = common.get_map_data() end)
    if md then
        local n = md.shortname or md.map or md.name
        if n and n ~= "" then return tostring(n) end
    end
    -- fallback: some builds still carry globals.mapname
    local ok, m = pcall(function() return globals.mapname end)
    if ok and m and m ~= "" then return tostring(m) end
    return "unknown"
end

-- ─── UI ──────────────────────────────────────────────────
local TAB = "Sel01-WalkBot"
local g_main, g_hud
local ok_ui = pcall(function()
    g_main = ui.create(TAB, "Walk Bot")
    g_hud  = ui.create(TAB, "Display", 2)
end)
if not ok_ui or not g_main then
    -- single-arg fallback for builds with a different ui.create signature
    pcall(function() g_main = ui.create(TAB, "Walk Bot") end)
    pcall(function() g_hud  = g_main end)
end

local wb_enable, wb_mode, wb_stopdist, wb_jump, wb_probe, wb_speed, wb_hud, wb_debug
local wb_peekslow, wb_peekrng, wb_slowspd, wb_bhop, wb_clantag, wb_nav
local wb_holdcnr, wb_holdmin, wb_approach, wb_crouch, wb_autolearn, wb_primary
pcall(function()
    wb_enable   = g_main:switch("Enable WalkBot")                 -- the on/off switch (no hotkey)
    wb_mode     = g_main:combo("Target Pick", "Nearest", "Lowest HP", "Most Visible", "Crosshair")
    wb_stopdist = g_main:slider("Stop Distance", 80, 2000, 450)
    wb_speed    = g_main:slider("Move Speed", 50, 450, 450)
    wb_jump     = g_main:switch("Allow Jumping (OFF = never jumps — recommended)")
    wb_probe    = g_main:slider("Obstacle Probe (units)", 20, 140, 55)
    -- peek slow-walk: when a visible enemy is near, slow-walk + jiggle so their
    -- resolver misses our moving/desynced model while our ragebot lands.
    wb_approach = g_main:slider("Approach Over (far = just close distance)", 700, 3000, 1300)
    wb_peekslow = g_main:switch("Slow-Walk Peek (near visible enemy)")
    wb_peekrng  = g_main:slider("Peek Range (slow-walk under)", 200, 1500, 750)
    wb_slowspd  = g_main:slider("Slow-Walk Speed", 40, 160, 110)
    -- hold a corner + shoulder-peek + wait for the enemy to push, instead of
    -- charging straight in (HvH-correct positioning).
    wb_holdcnr  = g_main:switch("Hold Corner (bait the push, don't rush)")
    wb_holdmin  = g_main:slider("Hold Until Enemy Within", 120, 900, 220)
    wb_crouch   = g_main:switch("Crouch When Exposed (enemy behind corner)")
    wb_primary  = g_main:switch("Auto Primary Weapon (deploy on round start)")
    -- roam: when NO enemy, follow recorded waypoints (walk the route yourself once,
    -- the bot replays it). No waypoints -> wander+avoid so it still explores.
    g_main:button("Record Waypoint (drop my pos)", function() _wb_pending_record = true end)
    g_main:button("Clear Waypoints (this map)",    function() _wb_pending_clear  = true end)
    wb_autolearn = g_main:switch("Auto-Learn Route (remembers across restart)")
    wb_bhop     = g_main:switch("Bunny-Hop on routes (faster A->B, no target only)")
    wb_clantag  = g_main:switch("Clantag 'WalkBot rn' when active")
    wb_nav      = g_main:switch("Load Nav-Mesh (real map routes — experimental)")
    wb_hud      = g_hud:switch("HUD Overlay")
    wb_debug    = g_hud:switch("Debug Info")
end)
-- sensible defaults (switches default off; flip the ones we want on)
pcall(function() if wb_peekslow then wb_peekslow:set(true) end end)
pcall(function() if wb_bhop then wb_bhop:set(true) end end)
pcall(function() if wb_clantag then wb_clantag:set(true) end end)
pcall(function() if wb_holdcnr then wb_holdcnr:set(true) end end)
pcall(function() if wb_crouch then wb_crouch:set(true) end end)
pcall(function() if wb_autolearn then wb_autolearn:set(true) end end)
pcall(function() if wb_primary then wb_primary:set(true) end end)
pcall(function() if wb_nav then wb_nav:set(true) end end)
pcall(function() if wb_hud then wb_hud:set(true) end end)

-- ─── runtime state ───────────────────────────────────────
local state = {
    target_idx   = nil,
    target_dist  = 0,
    mapname      = "unknown",
    activity     = "IDLE",     -- IDLE / WALK / AVOID / JUMP / STUCK / STOP / NO-TARGET
    last_origin  = nil,
    last_move_t  = 0,
    stuck_since  = 0,
    avoid_dir    = 0,          -- last avoidance rotation sign (-1/0/1) for hysteresis
    jump_until   = 0,
    diag         = "init",     -- debug: why we are / aren't moving
    enemy_count  = 0,
    block        = "clear",    -- clear / front / boxed / wall
    peek_flip_t  = 0,          -- slow-walk strafe-jiggle timer
    peek_side    = 1,          -- current jiggle side
    -- roam / waypoints
    waypoints    = {},         -- list of {x,y,z} for the current map
    wp_idx       = 1,          -- current patrol index
    wp_map       = nil,        -- map the loaded waypoints belong to
    wander_yaw   = 0,          -- heading while wandering (no waypoints)
    wander_t     = 0,          -- last wander redirect time
    clantag_set  = false,      -- current clantag mirror
    bhop_flip_t  = 0,          -- air-strafe side timer (bhop on routes)
    bhop_side    = 1,
    -- hold-corner / shoulder-peek
    peek_phase   = "in",       -- "out" (revealing) / "in" (behind cover)
    peek_phase_t = 0,
    hold_since   = 0,          -- when we started holding (timeout -> push)
    escape_yaw   = nil,        -- committed hard-escape heading while wedged
    escape_until = 0,
    stuck_hard   = false,      -- compute_move sets this when wedged > 1.2s
    team         = 0,          -- 2 = T, 3 = CT
    last_enemy_pos = nil,      -- last seen enemy origin (HUNT direction when roaming)
    tgt_state    = "?",        -- target motion: stand / push / move
    crouching    = false,      -- crouch-when-exposed active (HUD)
    learn_t      = 0,          -- last auto-learn waypoint drop
    last_enemy_t = 0,          -- when we last saw an enemy (HUNT freshness)
    learned_count = 0,         -- auto-learned waypoints this session
    enemy_history = {},        -- per-enemy-index last seen {x,y,z,t} (not all visible)
    pass_crouch  = false,      -- ducking to fit through a low passage (mirage vents etc)
    wpn_t        = 0,          -- last auto-primary deploy
    bad_spots    = {},         -- learned stuck spots {x,y} (persisted, avoided)
}
-- button -> tick drain flags (module globals: button closures run before `state`
-- helpers are bound; globals dodge the forward-reference trap, Solver pattern).
_wb_pending_record = false
_wb_pending_clear  = false

-- ─── helpers needing NL API (all pcall-guarded for version variance) ──
local function get_lp()
    local lp = nil
    pcall(function() lp = entity.get_local_player() end)
    if lp == nil then return nil end
    local alive = false
    pcall(function() alive = lp:is_alive() end)
    if not alive then return nil end
    return lp
end

local function get_origin(ent)
    local o = nil
    pcall(function() o = ent.m_vecOrigin end)
    return o
end

local function get_eye(ent)
    local e = nil
    pcall(function() e = ent:get_eye_position() end)
    if e == nil then
        local o = get_origin(ent)
        if o then e = vector(o.x, o.y, o.z + 64) end
    end
    return e
end

-- line-of-sight: is `to_ent` directly visible from lp eyes? (trace fraction ~1 or hits target)
local function has_los(lp, to_ent)
    local from = get_eye(lp)
    local to = get_eye(to_ent)
    if not from or not to then return false end
    local res = nil
    pcall(function() res = utils.trace_line(from, to, lp) end)
    if not res then return false end
    local frac = res.fraction or 0
    return frac >= 0.97
end

-- gather alive, non-dormant enemies
local function get_enemies()
    local list = {}
    local players = nil
    pcall(function() players = entity.get_players(true) end)
    if not players then return list end
    for _, p in ipairs(players) do
        local ok_alive, alive = pcall(function() return p:is_alive() end)
        local dorm = false
        pcall(function() dorm = p:is_dormant() end)
        if ok_alive and alive and not dorm and get_origin(p) then
            list[#list + 1] = p
        end
    end
    return list
end

-- pick target per UI mode; returns entity + 2d distance
local function pick_target(lp)
    local enemies = get_enemies()
    if #enemies == 0 then return nil, 0 end
    local lo = get_origin(lp)
    if not lo then return nil, 0 end
    local mode = "Nearest"
    pcall(function() mode = wb_mode:get() end)

    local best, best_score, best_dist = nil, nil, 0
    for _, e in ipairs(enemies) do
        local eo = get_origin(e)
        if eo then
            local d = v_len2d(vector(eo.x - lo.x, eo.y - lo.y, 0))
            local score
            if mode == "Lowest HP" then
                local hp = 100
                pcall(function() hp = e.m_iHealth or 100 end)
                score = hp * 10000 + d                 -- lowest hp first, then nearest
            elseif mode == "Most Visible" then
                local vis = has_los(lp, e) and 0 or 1
                score = vis * 1e9 + d                  -- visible first, then nearest
            elseif mode == "Crosshair" then
                -- smallest angle between our view yaw and the dir to enemy
                local vyaw = 0
                pcall(function() vyaw = lp.m_angEyeAngles.y end)
                local ay = math.abs(norm_ang(dir_yaw(lo, eo) - vyaw))
                score = ay * 100 + d
            else -- Nearest
                score = d
            end
            if best_score == nil or score < best_score then
                best, best_score, best_dist = e, score, d
            end
        end
    end
    return best, best_dist
end

-- MASK_SOLID_BRUSHONLY: world geometry only, NOT players. Spawn is crowded with
-- teammates/enemies; without this the movement probes hit them and the bot wedges in
-- spawn (the round-start STUCK). The 4th trace_line arg is the content mask (chernobl
-- passes 0xFFFFFFFF = everything; we want brushes only).
local PROBE_MASK = 0x400B

-- probe in walk direction; true = clear. Traces at BODY height (z+40, not knee) so
-- small steps the game auto-climbs (<=18u) don't false-trigger avoidance, AND at head
-- height (z+62) so we catch low overhangs. World-only (ignores players).
local function probe_clear(lp, lo, yaw_deg, dist)
    local rad = math.rad(yaw_deg)
    local dx, dy = math.cos(rad) * dist, math.sin(rad) * dist
    local function ray(h)
        local res = nil
        pcall(function()
            res = utils.trace_line(vector(lo.x, lo.y, lo.z + h), vector(lo.x + dx, lo.y + dy, lo.z + h), lp, PROBE_MASK)
        end)
        return (not res) or (res.fraction or 1) >= 0.99   -- trace fail -> assume clear
    end
    return ray(40) and ray(62)
end

-- low-passage check: is the way blocked standing but CLEAR when ducked? (mirage CT
-- connector / window low spots etc). Clear at knee height (z+18) but blocked at body.
local function crouch_passable(lp, lo, yaw_deg, dist)
    local rad = math.rad(yaw_deg)
    local dx, dy = math.cos(rad) * dist, math.sin(rad) * dist
    local res = nil
    pcall(function()
        res = utils.trace_line(vector(lo.x, lo.y, lo.z + 18), vector(lo.x + dx, lo.y + dy, lo.z + 18), lp, PROBE_MASK)
    end)
    return (not res) or (res.fraction or 1) >= 0.99      -- knee-level clear -> duckable
end

-- is the front obstacle LOW enough that a jump clears it? foot blocked (caller knows)
-- + head-height path clear => it's a box/step/crate, jumping helps. Both blocked =>
-- a tall wall, jumping is pointless (was the "jumps where stuck" complaint).
local function can_step_up(lp, lo, yaw_deg, dist)
    local rad = math.rad(yaw_deg)
    local fx, fy = math.cos(rad) * dist, math.sin(rad) * dist
    local hi_from = vector(lo.x, lo.y, lo.z + 50)   -- ~jump apex height
    local hi_to   = vector(lo.x + fx, lo.y + fy, lo.z + 50)
    local res = nil
    pcall(function() res = utils.trace_line(hi_from, hi_to, lp, PROBE_MASK) end)
    if not res then return false end                -- unknown -> don't waste a jump
    return (res.fraction or 1) >= 0.99              -- clear up high => step-up jumpable
end

-- ─── waypoints (per-map, persisted via NL files API) ─────
local function wp_path(map) return "nl/Sel01-WalkBot/" .. tostring(map or "unknown") .. ".txt" end

local function wp_save()
    local lines = {}
    for _, w in ipairs(state.waypoints) do
        lines[#lines + 1] = string.format("%.1f %.1f %.1f", w.x, w.y, w.z)
    end
    pcall(function() files.write(wp_path(state.wp_map), table.concat(lines, "\n")) end)
end

local function wp_load(map)
    state.waypoints = {}
    state.wp_idx = 1
    state.wp_map = map
    local data = nil
    pcall(function() data = files.read(wp_path(map)) end)
    if data then
        for line in tostring(data):gmatch("[^\r\n]+") do
            local x, y, z = line:match("(-?[%d.]+)%s+(-?[%d.]+)%s+(-?[%d.]+)")
            if x then state.waypoints[#state.waypoints + 1] = {x = tonumber(x), y = tonumber(y), z = tonumber(z)} end
        end
    end
end

-- ─── learned bad spots (where we keep getting stuck) — persisted, avoided ───
local function bad_path(map) return "nl/Sel01-WalkBot/" .. tostring(map or "unknown") .. "_bad.txt" end
local function bad_save()
    local lines = {}
    for _, s in ipairs(state.bad_spots) do lines[#lines + 1] = string.format("%.1f %.1f", s.x, s.y) end
    pcall(function() files.write(bad_path(state.wp_map), table.concat(lines, "\n")) end)
end
local function bad_load(map)
    state.bad_spots = {}
    local data = nil
    pcall(function() data = files.read(bad_path(map)) end)
    if data then
        for line in tostring(data):gmatch("[^\r\n]+") do
            local x, y = line:match("(-?[%d.]+)%s+(-?[%d.]+)")
            if x then state.bad_spots[#state.bad_spots + 1] = { x = tonumber(x), y = tonumber(y) } end
        end
    end
end
local function near_bad(x, y, r)
    for _, s in ipairs(state.bad_spots) do
        local dx, dy = s.x - x, s.y - y
        if dx * dx + dy * dy < r * r then return true end
    end
    return false
end
local function record_bad(lo)
    if #state.bad_spots >= 120 then return end
    if near_bad(lo.x, lo.y, 140) then return end          -- already known
    state.bad_spots[#state.bad_spots + 1] = { x = lo.x, y = lo.y }
    bad_save()
end

-- auto-learn the route while travelling: drop a waypoint when we're >220u from every
-- existing one. Builds + PERSISTS a route over time (survives script restart, no manual
-- recording needed). Capped so the file can't grow forever.
local function auto_learn(lo, now, base_act)
    if not (base_act == "ROAM" or base_act == "WANDER" or base_act == "APPROACH") then return end
    local on = false
    pcall(function() on = wb_autolearn and wb_autolearn:get() end)
    if not on then return end
    if (now - (state.learn_t or 0)) < 0.6 then return end
    state.learn_t = now
    if #state.waypoints >= 250 then return end
    if near_bad(lo.x, lo.y, 160) then return end          -- don't memorise a known-bad spot
    local nd = 1e18
    for _, w in ipairs(state.waypoints) do
        local dx, dy = w.x - lo.x, w.y - lo.y
        local d = dx * dx + dy * dy
        if d < nd then nd = d end
    end
    if nd > 220 * 220 then
        state.waypoints[#state.waypoints + 1] = { x = lo.x, y = lo.y, z = lo.z }
        state.learned_count = (state.learned_count or 0) + 1
        wp_save()                                       -- persist immediately
    end
end

-- corner assessment (trace-based, no nav needed): am I behind a corner relative to
-- the enemy? Direct eye-line blocked but a sideways-offset line is clear => stepping
-- to that side reveals them => hold here and shoulder-peek that side. Returns:
--   "hold_corner", side  -> behind cover, peek toward `side` (1 right / -1 left)
--   "open", 0            -> no usable corner, fight/approach normally
local function assess_corner(lp, lo, to)
    local fe, te = get_eye(lp), get_eye(to)
    if not fe or not te then return "open", 0 end
    -- world-only (PROBE_MASK): a teammate standing in the line shouldn't fake a corner.
    local function clear(from)
        local r = nil
        pcall(function() r = utils.trace_line(from, te, lp, PROBE_MASK) end)
        return r and (r.fraction or 0) >= 0.95
    end
    if clear(fe) then return "open", 0 end              -- we already see them -> not a hold
    local yaw = math.rad(dir_yaw(lo, to))
    local px, py = -math.sin(yaw), math.cos(yaw)        -- unit perpendicular to enemy dir
    -- try several side offsets; first one that reveals the enemy = the peek side. More
    -- distances = catches more real corners (was a single 45u probe = missed many).
    for _, off in ipairs({ 38, 64, 95, 130 }) do
        if clear(vector(lo.x + px * off, lo.y + py * off, fe.z)) then return "hold_corner", 1 end
        if clear(vector(lo.x - px * off, lo.y - py * off, fe.z)) then return "hold_corner", -1 end
    end
    return "open", 0
end

-- read the target's motion: is it standing still, and (if moving) coming toward us?
-- standing camper -> bait longer; pushing -> wait for the push; runner -> close in.
local function target_motion(target, lo, to)
    local v = nil
    pcall(function() v = target.m_vecVelocity end)
    local spd = v and v_len2d(v) or 0
    if spd < 25 then return "stand", spd end
    local tx, ty = lo.x - to.x, lo.y - to.y                 -- vector toward us
    local dot = ((v.x or 0) * tx + (v.y or 0) * ty)
    return (dot > 0 and "push" or "move"), spd
end

-- are we standing in the OPEN, no cover within ~64u to either side (perpendicular to
-- the enemy)? Used to crouch when the enemy is around a corner and we're exposed —
-- a smaller / ducked target lowers their hit chance on the peek.
local function self_exposed(lp, lo, to)
    local yaw = math.rad(dir_yaw(lo, to))
    local px, py = -math.sin(yaw), math.cos(yaw)
    local function cover_side(s)
        local res = nil
        pcall(function()
            res = utils.trace_line(vector(lo.x, lo.y, lo.z + 40),
                                   vector(lo.x + px * 64 * s, lo.y + py * 64 * s, lo.z + 40), lp)
        end)
        return res and (res.fraction or 1) < 0.85       -- wall close this side = cover
    end
    return not cover_side(1) and not cover_side(-1)     -- no cover either side = exposed
end

-- shared: take a desired world yaw, probe-avoid obstacles + handle stuck, return the
-- adjusted move_yaw. Sets state.activity/block/diag and schedules jumps. base_act is
-- the activity label this caller wants ("WALK" / "ROAM" / "WANDER").
local function compute_move(lp, lo, want_yaw, now, base_act)
    local probe = 55
    pcall(function() probe = wb_probe:get() end)
    local aj = true
    pcall(function() aj = wb_jump and wb_jump:get() end)
    local move_yaw = want_yaw
    state.activity = base_act
    state.block = "clear"
    state.stuck_hard = false

    -- if we recently committed a hard-escape heading, KEEP driving it (don't re-decide
    -- every tick — re-deciding is what makes it dance back and forth into the same wall).
    if state.escape_yaw and now < (state.escape_until or 0) then
        state.activity = "STUCK"; state.block = "escape"
        state.diag = base_act .. " hard-escape (committed)"
        if aj then state.jump_until = math.max(state.jump_until or 0, now + 0.10) end
        state.last_origin = lo
        return state.escape_yaw
    end

    -- LOOK-AHEAD probe further than the side fans, so we turn BEFORE hitting the wall
    state.pass_crouch = false
    local look = math.min(probe * 2.2, 130)
    if not probe_clear(lp, lo, want_yaw, look) and crouch_passable(lp, lo, want_yaw, probe) then
        -- blocked standing but clear ducked -> low passage (mirage vent / CT connector
        -- gap): duck + push straight through instead of avoiding.
        state.pass_crouch = true
        state.block = "duck-pass"
        state.diag = base_act .. " duck-pass (low gap)"
    elseif not probe_clear(lp, lo, want_yaw, look) then
        state.block = "front"
        local found = false
        local order = state.avoid_dir >= 0 and {1, -1} or {-1, 1}
        for _, s in ipairs(order) do
            for _, ang in ipairs({20, 40, 60, 80, 105, 135}) do
                if probe_clear(lp, lo, want_yaw + s * ang, probe) then
                    move_yaw = want_yaw + s * ang; state.avoid_dir = s; found = true; break
                end
            end
            if found then break end
        end
        if found then
            state.diag = string.format("%s avoid %+.0f", base_act, move_yaw - want_yaw)
        else
            state.block = "boxed"
            if aj and can_step_up(lp, lo, want_yaw, probe) then
                state.jump_until = now + 0.12; state.activity = "JUMP"; state.block = "step"
                state.diag = base_act .. " step-up jump"
            else
                move_yaw = want_yaw + (state.avoid_dir ~= 0 and state.avoid_dir or 1) * 110
                state.diag = base_act .. " boxed WALL -> turn"
            end
        end
    end

    -- ESCALATING stuck breakout (shared by walk / roam / wander)
    if state.last_origin then
        local moved = v_len2d(vector(lo.x - state.last_origin.x, lo.y - state.last_origin.y, 0))
        if moved < 1.5 then
            if state.stuck_since == 0 then state.stuck_since = now end
            local dur = now - state.stuck_since
            if dur > 1.2 then
                -- WEDGED: commit a back+side escape heading for ~0.8s + jump, and flip the
                -- preferred avoid side so we don't re-wedge the same way.
                state.activity = "STUCK"; state.stuck_hard = true; state.block = "wedged"
                local side = (state.avoid_dir ~= 0 and state.avoid_dir) or 1
                state.escape_yaw = norm_ang(want_yaw + 160 * side)
                state.escape_until = now + 0.8
                state.avoid_dir = -side
                if aj then state.jump_until = now + 0.18 end
                state.diag = base_act .. " WEDGED -> hard escape"
                move_yaw = state.escape_yaw
                state.stuck_since = now
                record_bad(lo)                              -- learn: this is a bad spot
            elseif dur > 0.35 then
                state.activity = "STUCK"
                move_yaw = want_yaw + (state.avoid_dir ~= 0 and state.avoid_dir or 1) * 90
                if aj and can_step_up(lp, lo, want_yaw, probe) then state.jump_until = now + 0.15 end
                state.diag = base_act .. " stuck -> strafe"
            end
        else
            state.stuck_since = 0
        end
    end
    state.last_origin = lo
    auto_learn(lo, now, base_act)
    return move_yaw
end

-- ═══ NAV-MESH (CSGO .nav parser) ═════════════════════════
-- Every official map ships csgo/maps/<map>.nav (the mesh CSGO's own bots use):
-- magic 0xFEEDFACE, version 16, subversion 1 (verified on this install). We parse
-- the walkable areas + their connections into a graph. v0.5 = parse + readout only
-- (prove the bytes line up in-game); v0.6 adds A* + path-following on top.
local nav = { ok = false, map = nil, count = 0, areas = nil, err = "not loaded" }

-- read the raw .nav bytes via FFI fopen ONLY. NL's files.read raises a popup error
-- dialog on a missing / unreadable path that pcall does NOT suppress (v0.8 bug:
-- 'cannot read this file') — so we never touch it. fopen returns NULL on miss, clean.
-- We pre-copy the maps into nl/Sel01-WalkBot/ (game-root relative) for a guaranteed
-- readable spot, plus try the live csgo/maps and an absolute install path.
-- Reading the binary .nav: files.read TRUNCATES at the first null byte (the nav header
-- has 0x00 at byte 5), and ffi.C.fopen is unavailable in the NL sandbox. So we read via
-- kernel32 ReadFile (ffi.load works here — the Solver uses it for clipboard). Reads the
-- full binary, no truncation. Navs are pre-copied into nl/Sel01-WalkBot/.
local nav_k32, nav_cdef_ok
if ffi_ok and ffi then
    nav_cdef_ok = pcall(ffi.cdef, [[
        void* CreateFileA(const char* name, unsigned long access, unsigned long share, void* sec, unsigned long disp, unsigned long flags, void* templ);
        int ReadFile(void* h, void* buf, unsigned long nNumberOfBytesToRead, unsigned long* lpNumberOfBytesRead, void* lpOverlapped);
        unsigned long GetFileSize(void* h, void* lpFileSizeHigh);
        int CloseHandle(void* h);
    ]])
    local ok; ok, nav_k32 = pcall(ffi.load, "kernel32")
    if not ok then nav_k32 = nil end
end

local NAV_BASES = {
    "nl/Sel01-WalkBot/",
    "E:/SteamLibrary/steamapps/common/Counter-Strike Global Offensive/nl/Sel01-WalkBot/",
    "csgo/maps/",
    "E:/SteamLibrary/steamapps/common/Counter-Strike Global Offensive/csgo/maps/",
}

local function nav_read(map)
    if not (ffi_ok and ffi and nav_cdef_ok and nav_k32) then return nil, "no ffi/kernel32" end
    local INVALID = ffi.cast("void*", -1)
    for _, base in ipairs(NAV_BASES) do
        local got = nil
        pcall(function()
            local h = nav_k32.CreateFileA(base .. map .. ".nav", 0x80000000, 1, nil, 3, 0x80, nil)
            if h ~= nil and h ~= INVALID then
                local sz = tonumber(nav_k32.GetFileSize(h, nil)) or 0
                if sz > 64 and sz < 50000000 then
                    local buf = ffi.new("uint8_t[?]", sz)
                    local rd = ffi.new("unsigned long[1]")
                    if nav_k32.ReadFile(h, buf, sz, rd, nil) ~= 0 then
                        got = ffi.string(buf, tonumber(rd[0]))
                    end
                end
                nav_k32.CloseHandle(h)
            end
        end)
        if got and #got > 64 then return got, "kernel32 " .. base end
    end
    return nil, "kernel32 read failed (navs in nl/Sel01-WalkBot/?)"
end

-- parse with a given layout variant; returns areas table + final offset, or errors.
local function nav_parse_variant(raw, vis_entry, tail_bytes)
    local n = #raw
    local base = ffi.cast("const uint8_t*", raw)
    local off = 0
    local function need(k) if off + k > n then error("eof@" .. off) end end
    local function u8()  need(1); local v = base[off]; off = off + 1; return v end
    local function u16() need(2); local v = ffi.cast("const uint16_t*", base + off)[0]; off = off + 2; return tonumber(v) end
    local function u32() need(4); local v = ffi.cast("const uint32_t*", base + off)[0]; off = off + 4; return tonumber(v) end
    local function f32() need(4); local v = ffi.cast("const float*",    base + off)[0]; off = off + 4; return tonumber(v) end
    local function skip(k) if k > 0 then need(k); off = off + k end end

    if u32() ~= 0xFEEDFACE then error("bad magic") end
    local major = u32()
    local minor = (major >= 10) and u32() or 0
    skip(4)                                   -- bspSize
    if major >= 14 then u8() end              -- isAnalyzed
    local placeCount = u16()
    for _ = 1, placeCount do local len = u16(); skip(len) end
    if major >= 12 then u8() end              -- hasUnnamedAreas (verified present in v16)
    local areaCount = u32()
    -- sanity: real maps have a few thousand areas (de_mirage = 903). >60000 means the
    -- alignment is off (the v1.2 bug let 231169 through because the cap was 300000).
    if areaCount == 0 or areaCount > 60000 then error("bad areaCount " .. areaCount) end

    local areas = {}
    for _ = 1, areaCount do
        local id = u32()
        if major <= 8 then u8() elseif major < 13 then u16() else u32() end   -- flags
        local nwx, nwy, nwz = f32(), f32(), f32()
        local sex, sey, sez = f32(), f32(), f32()
        f32(); f32()                                                         -- neZ, swZ
        local conns = {}
        for _ = 1, 4 do local c = u32(); for _ = 1, c do conns[#conns + 1] = u32() end end
        local hc = u8(); skip(hc * 17)                                       -- hiding spots
        if major < 15 then local ac = u8(); skip(ac * 14) end                -- approach (pre-v15)
        local ec = u32()                                                     -- encounter paths
        for _ = 1, ec do skip(10); local sc = u8(); skip(sc * 5) end
        u16()                                                                -- placeId
        for _ = 1, 2 do local c = u32(); skip(c * 4) end                     -- ladders
        skip(8)                                                              -- earliest occupy x2
        if major >= 11 then skip(16) end                                    -- light intensity
        if major >= 16 then local vc = u32(); skip(vc * vis_entry) end       -- visible areas
        if major >= 16 then skip(4) end                                     -- inherit visibility
        skip(tail_bytes)                                                     -- variant trailing
        areas[id] = { id = id, x = (nwx + sex) * 0.5, y = (nwy + sey) * 0.5,
                      z = (nwz + sez) * 0.5, nwx = nwx, nwy = nwy, sex = sex, sey = sey,
                      conns = conns }
    end
    return areas, areaCount, off
end

-- try layout variants, accept the one that consumes ~the whole file (self-correct
-- for the few CSGO fields whose width is ambiguous in the docs).
local function nav_load(map)
    nav = { ok = false, map = map, count = 0, areas = nil, err = "loading" }
    if not (ffi_ok and ffi) then nav.err = "no ffi"; return end
    local raw, how = nav_read(map)
    if not raw then nav.err = how; return end
    local n = #raw
    local best
    for _, vis in ipairs({ 5, 8 }) do
        for _, tail in ipairs({ 0, 1 }) do
            local ok, areas, cnt, off = pcall(nav_parse_variant, raw, vis, tail)
            if ok and math.abs(off - n) <= 16 then
                best = { areas = areas, count = cnt, vis = vis, tail = tail, off = off }
                break
            end
        end
        if best then break end
    end
    if best then
        nav.ok = true; nav.areas = best.areas; nav.count = best.count
        nav.err = string.format("ok (%s, vis=%d tail=%d)", how, best.vis, best.tail)
    else
        nav.err = "parse desync (offsets off) — report so I can fix the layout"
    end
end

-- nearest area center to a world point (linear; only for the v0.5 readout / occasional
-- repath in v0.6, never per-tick). Returns area, dist2d.
local function nav_nearest(x, y)
    if not (nav.ok and nav.areas) then return nil, 0 end
    local best, bestd
    for _, a in pairs(nav.areas) do
        local dx, dy = a.x - x, a.y - y
        local d = dx * dx + dy * dy
        if not bestd or d < bestd then best, bestd = a, d end
    end
    return best, bestd and math.sqrt(bestd) or 0
end

-- ─── main movement driver ────────────────────────────────
local function walkbot_tick(cmd)
    -- single on/off via the switch — no hotkey (user request)
    local on = false
    pcall(function() on = wb_enable and wb_enable:get() end)
    if not on then state.activity = "IDLE"; state.diag = "disabled (switch off)"; return end

    state.mapname = safe_mapname()

    local lp = get_lp()
    if not lp then state.activity = "IDLE"; state.diag = "no local player / dead"; return end

    local now = 0
    pcall(function() now = globals.realtime end)
    pcall(function() state.team = tonumber(lp.m_iTeam) or 0 end)

    -- auto primary weapon: keep the rifle/sniper deployed. "slot1" is a no-op when the
    -- primary is already out, so it's safe to repeat — covers round-start pistol/knife.
    do
        local pon = false; pcall(function() pon = wb_primary and wb_primary:get() end)
        if pon and (now - (state.wpn_t or 0)) > 1.5 then
            state.wpn_t = now
            if not pcall(function() utils.console_exec("slot1") end) then
                pcall(function() engine.execute_client_cmd("slot1") end)
            end
        end
    end

    -- ── drain Record / Clear waypoint buttons + map-change reload ──
    local lo = get_origin(lp)
    if _wb_pending_record then
        _wb_pending_record = false
        if lo then state.waypoints[#state.waypoints + 1] = {x = lo.x, y = lo.y, z = lo.z}; wp_save() end
    end
    if _wb_pending_clear then
        _wb_pending_clear = false
        state.waypoints = {}; state.wp_idx = 1; wp_save()
    end
    if state.wp_map ~= state.mapname then wp_load(state.mapname); bad_load(state.mapname) end
    -- nav-mesh: (re)load on map change when the toggle is on
    local use_nav = false
    pcall(function() use_nav = wb_nav and wb_nav:get() end)
    if use_nav and nav.map ~= state.mapname then nav_load(state.mapname) end
    if not lo then state.activity = "IDLE"; state.diag = "no origin"; return end

    local enemies = get_enemies()
    state.enemy_count = #enemies
    -- enemy HISTORY: remember where each enemy was last seen (not all are visible at
    -- once). Used to HUNT toward the freshest memory when nobody is currently pickable.
    for _, e in ipairs(enemies) do
        local eo = get_origin(e)
        if eo then
            local idx = 0; pcall(function() idx = e:get_index() end)
            state.enemy_history[idx] = { x = eo.x, y = eo.y, z = eo.z, t = now }
        end
    end
    local target, dist = pick_target(lp)

    -- ════════ ENGAGE: we have a target ════════
    if target then
        local to = get_origin(target)
        if to then
            pcall(function() state.target_idx = target:get_index() end)
            state.target_dist = dist
            local stop_d = 450; pcall(function() stop_d = wb_stopdist:get() end)
            local peekslow = false; pcall(function() peekslow = wb_peekslow and wb_peekslow:get() end)
            local peekrng = 750; pcall(function() peekrng = wb_peekrng and wb_peekrng:get() end)
            local approach_far = 1300; pcall(function() approach_far = wb_approach:get() end)
            state.last_enemy_pos = {x = to.x, y = to.y, z = to.z}

            -- distance-first decisions: how the target is moving + can we actually see it
            local mstate = target_motion(target, lo, to)   -- stand / push / move
            state.tgt_state = mstate
            local visible = has_los(lp, target)

            -- ── FAR (round start): don't peek/jiggle. Just close the distance roughly in
            -- the enemy's direction (toward A etc). Get fancy only once we're closer. ──
            if dist > approach_far then
                local move_yaw = compute_move(lp, lo, dir_yaw(lo, to), now, "APPROACH")
                local spd = 450; pcall(function() spd = wb_speed:get() end)
                if state.activity == "APPROACH" then
                    state.diag = string.format("APPROACH d=%.0f enemy=%s (close distance)", dist, mstate)
                end
                pcall(function() cmd.move_yaw = move_yaw; cmd.forwardmove = spd; cmd.sidemove = 0 end)
                if state.pass_crouch then pcall(function() cmd.in_duck = true end) end
                if now <= (state.jump_until or 0) then pcall(function() cmd.in_jump = true end) end
                return
            end

            -- ── HOLD CORNER: behind a corner -> shoulder-peek + wait. Hold LONGER vs a
            -- camper (standing) and basically wait out a pusher (they come to us). ──
            local holdcnr = false; pcall(function() holdcnr = wb_holdcnr and wb_holdcnr:get() end)
            local holdmin = 350; pcall(function() holdmin = wb_holdmin:get() end)
            if holdcnr and dist > holdmin then
                local cmode, pside = assess_corner(lp, lo, to)
                if cmode == "hold_corner" then
                    if state.hold_since == 0 then state.hold_since = now end
                    local htimeout = (mstate == "stand") and 12.0 or (mstate == "push") and 16.0 or 9.0
                    if (now - state.hold_since) < htimeout then
                        local dur = (state.peek_phase == "out") and 0.22 or 0.55
                        if (now - (state.peek_phase_t or 0)) > dur then
                            state.peek_phase = (state.peek_phase == "out") and "in" or "out"
                            state.peek_phase_t = now
                        end
                        local yaw = math.rad(dir_yaw(lo, to))
                        local px, py = -math.sin(yaw), math.cos(yaw)
                        local s = (state.peek_phase == "out") and pside or -pside
                        local move_yaw = compute_move(lp, lo, math.deg(math.atan2(py * s, px * s)), now, "HOLD")
                        local sw = 110; pcall(function() sw = wb_slowspd:get() end)
                        if state.activity == "HOLD" then
                            state.diag = string.format("HOLD peek=%s side=%d d=%.0f enemy=%s", state.peek_phase, pside, dist, mstate)
                        end
                        pcall(function() cmd.move_yaw = move_yaw; cmd.forwardmove = sw; cmd.sidemove = 0 end)
                        state.last_origin = lo
                        return
                    end   -- else: held too long -> fall through and push
                else
                    state.hold_since = 0
                end
            else
                state.hold_since = 0
            end

            -- ── AGGRESSIVE peek ONLY when the enemy is VISIBLE. Close but NOT visible
            -- (sitting around a corner) -> do NOT blind-jiggle into the angle; slow-
            -- approach to gain the sightline carefully instead. ──
            local want_yaw = dir_yaw(lo, to)
            local close = dist <= stop_d
            local aggressive = close and visible
            if aggressive then
                if (now - (state.peek_flip_t or 0)) > 0.30 then
                    state.peek_side = -(state.peek_side or 1); state.peek_flip_t = now
                end
                want_yaw = want_yaw + (state.peek_side or 1) * 75
            end

            local move_yaw = compute_move(lp, lo, want_yaw, now, "WALK")
            local near = (peekslow and dist <= peekrng) or close
            local spd = 450; pcall(function() spd = wb_speed:get() end)
            if near then
                local sw = 110; pcall(function() sw = wb_slowspd:get() end); spd = sw
                if state.activity == "WALK" or state.activity == "AVOID" then state.activity = "PEEK" end
                state.diag = string.format("%s d=%.0f enemy=%s%s",
                    visible and "PEEK-visible" or "careful-approach", dist, mstate,
                    aggressive and " +jiggle" or "")
            else
                state.diag = string.format("engage #%s d=%.0f enemy=%s", tostring(state.target_idx), dist, mstate)
            end
            -- CROUCH when EXPOSED: enemy around a corner (not visible) + we're standing in
            -- the open + in combat range -> duck = smaller target, lowers their hit chance.
            -- Separate mechanic from slow-walk (own toggle); both can apply together.
            local cr_on = false; pcall(function() cr_on = wb_crouch and wb_crouch:get() end)
            state.crouching = cr_on and (not visible) and dist <= peekrng and self_exposed(lp, lo, to)
            pcall(function() cmd.move_yaw = move_yaw; cmd.forwardmove = spd; cmd.sidemove = 0 end)
            if state.crouching or state.pass_crouch then pcall(function() cmd.in_duck = true end) end
            -- no jumping near an enemy; step-up only while still far
            if dist > peekrng and now <= (state.jump_until or 0) then
                pcall(function() cmd.in_jump = true end)
            end
            return
        end
    end

    -- ════════ ROAM: no target -> patrol waypoints, else wander ════════
    state.target_idx = nil
    state.crouching = false
    local move_yaw
    -- freshest enemy memory (seen < 25s ago) — priority: go where an enemy actually was.
    local hgoal, ht = nil, 0
    for _, h in pairs(state.enemy_history) do
        if (now - h.t) < 25 and h.t > ht then hgoal, ht = h, h.t end
    end
    if hgoal then
        move_yaw = compute_move(lp, lo, dir_yaw(lo, hgoal), now, "ROAM")
        if state.activity == "ROAM" then
            state.diag = string.format("HUNT last-seen enemy d=%.0f age=%.0fs",
                v_len2d(vector(hgoal.x - lo.x, hgoal.y - lo.y, 0)), now - ht)
        end
    elseif #state.waypoints > 0 then
        local wp = state.waypoints[state.wp_idx] or state.waypoints[1]
        local d = v_len2d(vector(wp.x - lo.x, wp.y - lo.y, 0))
        -- reached it OR can't reach it (wedged) -> advance, so we don't grind a wall
        if d < 90 or state.stuck_hard then
            state.wp_idx = (state.wp_idx % #state.waypoints) + 1
            wp = state.waypoints[state.wp_idx]
            d = v_len2d(vector(wp.x - lo.x, wp.y - lo.y, 0))
        end
        move_yaw = compute_move(lp, lo, dir_yaw(lo, wp), now, "ROAM")
        if state.activity == "ROAM" then
            state.diag = string.format("ROAM route wp %d/%d d=%.0f", state.wp_idx, #state.waypoints, d)
        end
    elseif v_len2d(vector(lo.x, lo.y, 0)) > 600 then
        -- LEAVE SPAWN: nothing learned yet + no enemy seen. Most CSGO maps are centered
        -- near world origin, so head toward (0,0) = mid to get OUT of spawn instead of
        -- circling it. Small position-seeded jitter so a wall doesn't pin us.
        local jitter = (math.floor(math.abs(lo.x) + now) % 40) - 20
        move_yaw = compute_move(lp, lo, dir_yaw(lo, { x = 0, y = 0 }) + jitter, now, "WANDER")
        if state.activity == "WANDER" then
            state.diag = string.format("LEAVE-SPAWN -> mid d=%.0f", v_len2d(vector(lo.x, lo.y, 0)))
        end
    else
        -- near mid, nothing known: gentle wander. Repick on block / wedge / every ~3s.
        if (now - (state.wander_t or 0)) > 3.0 or state.block == "boxed" or state.stuck_hard then
            local turn = 90 + (math.floor(math.abs(lo.x) + math.abs(lo.y) + now) % 140)
            state.wander_yaw = norm_ang((state.wander_yaw or 0) + turn)
            state.wander_t = now
        end
        move_yaw = compute_move(lp, lo, state.wander_yaw or 0, now, "WANDER")
        if state.activity == "WANDER" then
            state.diag = "WANDER (exploring near mid)"
        end
    end

    local spd = 450; pcall(function() spd = wb_speed:get() end)
    pcall(function() cmd.move_yaw = move_yaw; cmd.forwardmove = spd; cmd.sidemove = 0 end)
    if state.pass_crouch then pcall(function() cmd.in_duck = true end) end

    -- ── bunny-hop while travelling (no target only): jump on every ground-touch so
    -- A->B is faster, with a light auto air-strafe to keep speed. Disabled while
    -- engaging (you can't aim mid-air). Suppressed when wedged (STUCK) so we don't
    -- bhop into a wall forever. ──
    -- jumping master gate: bhop + step-up jumps only when Allow Jumping is on (default
    -- OFF -> bot never jumps, per request).
    local jump_ok = false
    pcall(function() jump_ok = wb_jump and wb_jump:get() end)
    local bhop = false
    pcall(function() bhop = wb_bhop and wb_bhop:get() end)
    if jump_ok and bhop and state.activity ~= "STUCK" then
        local onground = true
        pcall(function() onground = bit.band(tonumber(lp.m_fFlags) or 1, 1) == 1 end)
        if onground then
            pcall(function() cmd.in_jump = true end)
        else
            if (now - (state.bhop_flip_t or 0)) > 0.25 then
                state.bhop_side = -(state.bhop_side or 1); state.bhop_flip_t = now
            end
            pcall(function() cmd.sidemove = (state.bhop_side or 1) * 450 end)
        end
    elseif jump_ok and now <= (state.jump_until or 0) then
        pcall(function() cmd.in_jump = true end)
    end
end

pcall(function() events.createmove:set(walkbot_tick) end)

-- ─── clantag while active ────────────────────────────────
-- set_clan_tag is a game-state write -> only takes effect from net_update_end
-- (the render thread silently drops it; bloodwings pattern). Only writes on change.
local function update_clantag()
    local want = ""
    local on, tagon = false, false
    pcall(function() on = wb_enable and wb_enable:get() end)
    pcall(function() tagon = wb_clantag and wb_clantag:get() end)
    if on and tagon then want = "WalkBot rn" end
    if want ~= state.clantag_set then
        pcall(function() common.set_clan_tag(want) end)
        state.clantag_set = want
    end
end
if not pcall(function() events.net_update_end:set(update_clantag) end) then
    pcall(function() events.net_update_end(update_clantag) end)
end

-- ─── HUD ─────────────────────────────────────────────────
local COL = {
    title  = function() return color(120, 200, 255, 255) end,
    label  = function() return color(180, 180, 180, 255) end,
    val    = function() return color(255, 255, 255, 255) end,
    walk   = function() return color(120, 230, 120, 255) end,
    avoid  = function() return color(255, 200, 90, 255) end,
    stuck  = function() return color(255, 110, 110, 255) end,
    stop   = function() return color(120, 200, 255, 255) end,
    peek   = function() return color(200, 120, 255, 255) end,
    roam   = function() return color(120, 220, 200, 255) end,
    hold   = function() return color(255, 160, 60, 255) end,
    idle   = function() return color(150, 150, 150, 255) end,
}
local function act_color(a)
    if a == "WALK" then return COL.walk()
    elseif a == "AVOID" or a == "JUMP" then return COL.avoid()
    elseif a == "STUCK" then return COL.stuck()
    elseif a == "STOP" then return COL.stop()
    elseif a == "PEEK" then return COL.peek()
    elseif a == "HOLD" then return COL.hold()
    elseif a == "ROAM" or a == "WANDER" or a == "APPROACH" then return COL.roam()
    else return COL.idle() end
end

local function render_hud()
    local show, dbg = false, false
    pcall(function() show = wb_hud and wb_hud:get() end)
    pcall(function() dbg  = wb_debug and wb_debug:get() end)
    if not (show or dbg) then return end

    pcall(function()
        local ss = render.screen_size()
        local x = 18
        local y = math.floor(ss.y * 0.52)
        local line = 16
        render.text(4, vector(x, y), COL.title(), nil, "Sel01-WalkBot v" .. SEL01_WB_VERSION)
        y = y + line
        local tname = (state.team == 2 and "T") or (state.team == 3 and "CT") or "?"
        render.text(3, vector(x, y), COL.label(), nil, "Map: ")
        render.text(3, vector(x + 38, y), COL.val(), nil, state.mapname .. "  [" .. tname .. "]")
        y = y + line
        render.text(3, vector(x, y), COL.label(), nil, "State: ")
        render.text(3, vector(x + 46, y), act_color(state.activity), nil,
            state.activity .. (state.crouching and "  +DUCK" or ""))
        y = y + line
        if state.target_idx then
            render.text(3, vector(x, y), COL.label(), nil, "Target: ")
            render.text(3, vector(x + 52, y), COL.val(), nil,
                string.format("#%d  %.0fu  [%s]", state.target_idx, state.target_dist, tostring(state.tgt_state)))
        else
            render.text(3, vector(x, y), COL.label(), nil, "Target: none")
        end
        y = y + line
        render.text(3, vector(x, y), COL.label(), nil, "Waypoints: ")
        render.text(3, vector(x + 72, y), COL.val(), nil,
            string.format("%d  (idx %d)", #state.waypoints, state.wp_idx or 0))
        -- ── debug block: WHY it is / isn't doing what it's doing ──
        if dbg then
            y = y + line + 4
            render.text(3, vector(x, y), COL.title(), nil, "── debug ──")
            y = y + line
            render.text(3, vector(x, y), COL.label(), nil,
                string.format("enemies: %d   block: %s", state.enemy_count or 0, state.block or "-"))
            y = y + line
            render.text(3, vector(x, y), COL.label(), nil, "why: ")
            render.text(3, vector(x + 32, y), act_color(state.activity), nil, tostring(state.diag))
            y = y + line
            -- raw map data so a mis-detect is visible
            local raw = "nil"
            pcall(function()
                local md = common.get_map_data()
                if md then raw = tostring(md.shortname or md.map or md.name or "?") end
            end)
            render.text(3, vector(x, y), COL.label(), nil, "map_data.shortname: ")
            render.text(3, vector(x + 128, y), COL.val(), nil, raw)
            -- nav-mesh status
            y = y + line
            local navcol = nav.ok and COL.walk() or COL.stuck()
            render.text(3, vector(x, y), COL.label(), nil, "Nav: ")
            render.text(3, vector(x + 34, y), navcol, nil,
                nav.ok and string.format("%d areas  %s", nav.count, tostring(nav.err))
                       or tostring(nav.err))
        end
    end)
end
pcall(function() events.render:set(render_hud) end)

-- ─── shutdown ────────────────────────────────────────────
pcall(function()
    events.shutdown:set(function()
        pcall(function() common.set_clan_tag("") end)   -- restore tag
        pcall(function() events.createmove:unset() end)
        pcall(function() events.render:unset() end)
        pcall(function() events.net_update_end:unset() end)
    end)
end)

-- ─── load banner ─────────────────────────────────────────
local function log(t) pcall(function() print(t) end) end
log("==============================================")
log("Sel01-WalkBot v" .. SEL01_WB_VERSION .. " loaded — by seltonmt01")
log("Map: " .. safe_mapname())
log("Greedy bot: engage enemies (slow-walk peek) OR roam routes when none.")
log("No target -> patrol recorded Waypoints (bunny-hop) or wander+avoid if none.")
log("Record a route: walk it yourself, tap 'Record Waypoint' at each spot.")
log("Toggle 'Enable WalkBot' to activate (no hotkey). Debug Info shows why.")
log("Aiming stays with ragebot — this drives MOVEMENT only.")
log("==============================================")
