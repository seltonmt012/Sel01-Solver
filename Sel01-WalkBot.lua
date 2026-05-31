-- ╔══════════════════════════════════════════════════╗
-- ║  Sel01-WalkBot                                     ║
-- ║  Version: 0.3                                      ║
-- ║  Greedy nav-bot: map + enemy detect, walk-to-foe  ║
-- ║  by seltonmt01                                     ║
-- ╚══════════════════════════════════════════════════╝
-- @name Sel01-WalkBot
-- @version 0.3
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

local SEL01_WB_VERSION = "0.3"

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

local wb_enable, wb_mode, wb_stopdist, wb_autojump, wb_probe, wb_speed, wb_hud, wb_debug
local wb_peekslow, wb_peekrng, wb_slowspd
pcall(function()
    wb_enable   = g_main:switch("Enable WalkBot")                 -- the on/off switch (no hotkey)
    wb_mode     = g_main:combo("Target Pick", "Nearest", "Lowest HP", "Most Visible", "Crosshair")
    wb_stopdist = g_main:slider("Stop Distance", 80, 2000, 450)
    wb_speed    = g_main:slider("Move Speed", 50, 450, 450)
    wb_autojump = g_main:switch("Auto-Jump Obstacles (only when step-up clears)")
    wb_probe    = g_main:slider("Obstacle Probe (units)", 20, 140, 55)
    -- peek slow-walk: when a visible enemy is near, slow-walk + jiggle so their
    -- resolver misses our moving/desynced model while our ragebot lands.
    wb_peekslow = g_main:switch("Slow-Walk Peek (near visible enemy)")
    wb_peekrng  = g_main:slider("Peek Range (slow-walk under)", 200, 1500, 750)
    wb_slowspd  = g_main:slider("Slow-Walk Speed", 40, 160, 110)
    wb_hud      = g_hud:switch("HUD Overlay")
    wb_debug    = g_hud:switch("Debug Info")
end)
-- sensible defaults (switches default off; flip the ones we want on)
pcall(function() if wb_autojump then wb_autojump:set(true) end end)
pcall(function() if wb_peekslow then wb_peekslow:set(true) end end)
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
}

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

-- trace a short probe from the feet in walk direction; true = clear
local function probe_clear(lp, lo, yaw_deg, dist)
    local rad = math.rad(yaw_deg)
    local ahead = vector(lo.x + math.cos(rad) * dist,
                         lo.y + math.sin(rad) * dist,
                         lo.z + 18)               -- knee height so we ignore floor
    local res = nil
    pcall(function() res = utils.trace_line(vector(lo.x, lo.y, lo.z + 18), ahead, lp) end)
    if not res then return true end               -- trace failed -> assume clear, keep moving
    return (res.fraction or 1) >= 0.99
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
    pcall(function() res = utils.trace_line(hi_from, hi_to, lp) end)
    if not res then return false end                -- unknown -> don't waste a jump
    return (res.fraction or 1) >= 0.99              -- clear up high => step-up jumpable
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

    state.enemy_count = #get_enemies()
    local target, dist = pick_target(lp)
    if not target then
        state.activity = "NO-TARGET"; state.target_idx = nil
        state.diag = (state.enemy_count == 0) and "no enemies alive/non-dormant"
                     or "enemies exist but none pickable (no origin?)"
        return
    end
    pcall(function() state.target_idx = target:get_index() end)
    state.target_dist = dist

    local lo = get_origin(lp)
    local to = get_origin(target)
    if not lo or not to then state.activity = "IDLE"; state.diag = "missing origin"; return end

    local los = has_los(lp, target)
    local stop_d = 450
    pcall(function() stop_d = wb_stopdist:get() end)
    local peekslow = false
    pcall(function() peekslow = wb_peekslow and wb_peekslow:get() end)
    local peekrng = 750
    pcall(function() peekrng = wb_peekrng and wb_peekrng:get() end)
    -- peek-slow zone: a VISIBLE enemy within peek range. We slow-walk (+ strafe
    -- jiggle at close range) so their resolver misses our moving / desynced model
    -- while our ragebot lands. This intentionally OVERRIDES the hard STOP — standing
    -- still is the easiest thing to resolve, so we keep micro-moving instead.
    local peek_active = peekslow and los and dist <= peekrng

    -- hard STOP only when peek-slow is OFF (legacy behaviour)
    if not peek_active and dist <= stop_d and los then
        state.activity = "STOP"; state.block = "clear"
        state.diag = string.format("in range %.0f<=%.0f + LoS -> holding", dist, stop_d)
        state.last_origin = lo
        return
    end

    -- desired walk direction (world)
    local want_yaw = dir_yaw(lo, to)
    -- close + peeking: strafe-jiggle sideways instead of walking into them; flip
    -- side ~3x/sec so the magnitude/side the enemy resolver sees keeps changing.
    if peek_active and dist <= stop_d then
        if (now - (state.peek_flip_t or 0)) > 0.30 then
            state.peek_side = -(state.peek_side or 1)
            state.peek_flip_t = now
        end
        want_yaw = want_yaw + (state.peek_side or 1) * 75
    end

    -- ── obstacle avoidance: probe straight, then fan out ──
    local probe = 55
    pcall(function() probe = wb_probe:get() end)
    local move_yaw = want_yaw
    state.activity = "WALK"; state.block = "clear"
    state.diag = string.format("walk #%s d=%.0f yaw=%.0f", tostring(state.target_idx), dist, want_yaw)
    local aj = true
    pcall(function() aj = wb_autojump and wb_autojump:get() end)
    if not probe_clear(lp, lo, want_yaw, probe) then
        state.activity = "AVOID"; state.block = "front"
        -- try increasing rotations both sides, prefer last successful side (hysteresis)
        local found = false
        local order = state.avoid_dir >= 0 and {1, -1} or {-1, 1}
        for _, s in ipairs(order) do
            for _, ang in ipairs({25, 50, 75, 100}) do
                if probe_clear(lp, lo, want_yaw + s * ang, probe) then
                    move_yaw = want_yaw + s * ang
                    state.avoid_dir = s
                    found = true
                    break
                end
            end
            if found then break end
        end
        if found then
            state.diag = string.format("avoid: rotated %+.0f around front block", move_yaw - want_yaw)
        else
            -- fully boxed in front: jump ONLY if it's a step/box (head-height clears).
            -- A tall wall stays "wall" and we DON'T waste a jump (the old code jumped
            -- on every boxed-in tick even against full walls).
            state.block = "boxed"
            if aj and can_step_up(lp, lo, want_yaw, probe) then
                state.jump_until = now + 0.12; state.activity = "JUMP"
                state.block = "step"; state.diag = "boxed but low -> step-up jump"
            else
                state.diag = "boxed by a WALL (no jump; rotating to escape)"
                move_yaw = want_yaw + (state.avoid_dir ~= 0 and state.avoid_dir or 1) * 90
            end
        end
    end

    -- ── stuck detection: barely moved while trying to walk ──
    if state.last_origin then
        local moved = v_len2d(vector(lo.x - state.last_origin.x, lo.y - state.last_origin.y, 0))
        if moved < 1.5 then
            if state.stuck_since == 0 then state.stuck_since = now
            elseif (now - state.stuck_since) > 0.35 then
                state.activity = "STUCK"
                -- breakout: strafe hard sideways. Jump ONLY if a step-up actually
                -- clears (don't bunny-hop against a wall we're wedged on).
                move_yaw = want_yaw + (state.avoid_dir ~= 0 and state.avoid_dir or 1) * 90
                if aj and can_step_up(lp, lo, want_yaw, probe) then
                    state.jump_until = now + 0.15
                    state.diag = "stuck -> step-up jump + strafe"
                else
                    state.diag = "stuck -> strafe breakout (no jump, not a step)"
                end
                state.stuck_since = now      -- re-arm so we keep nudging
            end
        else
            state.stuck_since = 0
        end
    end
    state.last_origin = lo

    -- ── speed: full run, or slow-walk inside the peek zone ──
    local spd = 450
    pcall(function() spd = wb_speed:get() end)
    if peek_active then
        local sw = 110
        pcall(function() sw = wb_slowspd:get() end)
        spd = sw
        -- show PEEK unless a more urgent state (STUCK/JUMP) is active
        if state.activity == "WALK" or state.activity == "AVOID" then state.activity = "PEEK" end
        state.diag = string.format("PEEK slow-walk d=%.0f spd=%.0f%s", dist, spd,
            (dist <= stop_d) and " +jiggle" or "")
    end

    -- ── write movement to the user command ──
    pcall(function()
        cmd.move_yaw   = move_yaw
        cmd.forwardmove = spd
        cmd.sidemove    = 0
    end)
    -- jump window
    if now <= (state.jump_until or 0) then
        pcall(function() cmd.in_jump = true end)
    end
end

pcall(function() events.createmove:set(walkbot_tick) end)

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
    idle   = function() return color(150, 150, 150, 255) end,
}
local function act_color(a)
    if a == "WALK" then return COL.walk()
    elseif a == "AVOID" or a == "JUMP" then return COL.avoid()
    elseif a == "STUCK" then return COL.stuck()
    elseif a == "STOP" then return COL.stop()
    elseif a == "PEEK" then return COL.peek()
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
        render.text(3, vector(x, y), COL.label(), nil, "Map: ")
        render.text(3, vector(x + 38, y), COL.val(), nil, state.mapname)
        y = y + line
        render.text(3, vector(x, y), COL.label(), nil, "State: ")
        render.text(3, vector(x + 46, y), act_color(state.activity), nil, state.activity)
        y = y + line
        if state.target_idx then
            render.text(3, vector(x, y), COL.label(), nil, "Target: ")
            render.text(3, vector(x + 52, y), COL.val(), nil,
                string.format("#%d  %.0fu", state.target_idx, state.target_dist))
        else
            render.text(3, vector(x, y), COL.label(), nil, "Target: none")
        end
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
        end
    end)
end
pcall(function() events.render:set(render_hud) end)

-- ─── shutdown ────────────────────────────────────────────
pcall(function()
    events.shutdown:set(function()
        pcall(function() events.createmove:unset() end)
        pcall(function() events.render:unset() end)
    end)
end)

-- ─── load banner ─────────────────────────────────────────
local function log(t) pcall(function() print(t) end) end
log("==============================================")
log("Sel01-WalkBot v" .. SEL01_WB_VERSION .. " loaded — by seltonmt01")
log("Map: " .. safe_mapname())
log("Greedy MVP: walk-to-enemy + trace avoidance + auto-jump.")
log("Toggle 'Enable WalkBot' switch to activate (no hotkey). Debug Info switch shows why.")
log("Aiming stays with ragebot — this drives MOVEMENT only.")
log("==============================================")
