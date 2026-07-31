-- ╔══════════════════════════════════════════════════╗
-- ║  Sel01-PlantBot                                    ║
-- ║  Version: 1.4                                      ║
-- ║  One job: walk to a marked A spot, plant the C4,   ║
-- ║  walk to a marked safe spot, done. Auto-picks T.   ║
-- ║  by seltonmt01                                     ║
-- ╚══════════════════════════════════════════════════╝
-- @name Sel01-PlantBot
-- @version 1.4
-- @author seltonmt01
-- @description Standalone plant-bot. You MARK two spots once (persisted per map):
--   the A plant spot + the safe spot. Then it loops every round:
--   GOTO_A  -> greedy-walk straight to the marked A spot (equips the bomb on the way)
--   PLANT   -> stop + hold +attack until the SERVER reports the bomb down (v1.4)
--   RETREAT -> greedy-walk straight to the marked safe spot
--   DONE    -> release control (your WASD works) until next round / respawn, then loop
--   Auto-joins T whenever a team is not assigned (handles the round team-select menu).
--   Movement ONLY — aiming stays with the ragebot. While idle/done it does NOT touch
--   the cmd, so your normal keys work.

local SEL01_PB_VERSION = "1.4"

-- ─── small helpers ───────────────────────────────────────
local function v_len2d(v) return math.sqrt((v.x or 0) ^ 2 + (v.y or 0) ^ 2) end
local function dist2d(ax, ay, bx, by) return math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) end
local function dir_yaw_xy(ax, ay, bx, by) return math.deg(math.atan2(by - ay, bx - ax)) end
local function norm_ang(a) while a > 180 do a = a - 360 end while a < -180 do a = a + 360 end return a end

local function safe_mapname()
    local md = nil
    pcall(function() md = common.get_map_data() end)
    if md then
        local n = md.shortname or md.map or md.name
        if n and n ~= "" then return tostring(n) end
    end
    local ok, m = pcall(function() return globals.mapname end)
    if ok and m and m ~= "" then return tostring(m) end
    return "unknown"
end

-- ─── runtime state ───────────────────────────────────────
local state = {
    phase        = "IDLE",      -- IDLE / NEED_MARK / GOTO_A / PLANT / RETREAT / DONE
    mapname      = "unknown",
    spots_map    = nil,         -- map the loaded a_spot/safe_spot belong to
    a_spot       = nil,         -- {x,y,z} plant spot
    safe_spot    = nil,         -- {x,y,z} retreat spot
    team         = 0,
    activity     = "IDLE",
    diag         = "init",
    last_origin  = nil,
    stuck_since  = 0,
    avoid_dir    = 0,
    jump_until   = 0,
    escape_yaw   = nil,
    escape_until = 0,
    block        = "clear",
    pass_crouch  = false,
    plant_hold_t = 0,
    equip_t      = 0,
    team_pick_t  = 0,
    had_c4       = false,
    was_alive    = false,
    -- v1.4 plant / round tracking
    arm_started  = false,       -- CC4 m_bStartedArming seen (or bomb_beginplant fired)
    bomb_down    = false,       -- bomb_planted event fired this round
    rearm_until  = 0,           -- release +attack until this time (re-press after an abort)
    reposition_until = 0,       -- walk onto the mark again while the plant refuses to start
    aborts       = 0,
    warmup       = false,
    round_t      = nil,         -- m_fRoundStartTime — changes = new round
    round_state  = "LIVE",
}

-- button drains (module globals: closures run before `state` helpers bind)
_pb_mark_a    = false
_pb_mark_safe = false
_pb_clear     = false
_pb_print_pos = false

-- ─── UI ──────────────────────────────────────────────────
local TAB = "Sel01-PlantBot"
local g_main, g_hud
local ok_ui = pcall(function()
    g_main = ui.create(TAB, "Plant Bot")
    g_hud  = ui.create(TAB, "Display", 2)
end)
if not ok_ui or not g_main then
    pcall(function() g_main = ui.create(TAB, "Plant Bot") end)
    pcall(function() g_hud  = g_main end)
end

local pb_enable, pb_radius, pb_speed, pb_jump, pb_probe, pb_safe_radius, pb_autot, pb_hud, pb_debug
pcall(function()
    pb_enable      = g_main:switch("Enable PlantBot")
    pb_autot       = g_main:switch("Auto-Join T (pick T every round)")
    g_main:button("Mark A Spot (stand on plant spot)",  function() _pb_mark_a    = true end)
    g_main:button("Mark Safe Spot (stand on safe spot)", function() _pb_mark_safe = true end)
    g_main:button("Clear Marks (this map)",              function() _pb_clear     = true end)
    pb_radius      = g_main:slider("A-Site Plant Radius", 60, 600, 120)
    pb_safe_radius = g_main:slider("Safe-Spot Arrive Radius", 80, 600, 180)
    pb_speed       = g_main:slider("Move Speed", 50, 450, 450)
    pb_jump        = g_main:switch("Allow Jumping (OFF = never jumps)")
    pb_probe       = g_main:slider("Obstacle Probe (units)", 20, 140, 55)
    pb_hud         = g_hud:switch("HUD Overlay")
    pb_debug       = g_hud:switch("Debug Info")
    g_hud:button("Print My Pos (console)", function() _pb_print_pos = true end)
end)
pcall(function() if pb_hud then pb_hud:set(true) end end)
pcall(function() if pb_autot then pb_autot:set(true) end end)

-- ─── NL helpers (pcall-guarded for version variance) ─────
local function get_lp_any()
    local lp = nil
    pcall(function() lp = entity.get_local_player() end)
    return lp
end
local function get_lp()
    local lp = get_lp_any()
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

local function exec(c)
    if not pcall(function() utils.console_exec(c) end) then
        pcall(function() engine.execute_client_cmd(c) end)
    end
end

-- equip the C4 (slot5). Throttled so we don't fight weapon switching every tick.
local function equip_c4(now)
    if (now - (state.equip_t or 0)) < 0.4 then return end
    state.equip_t = now
    exec("slot5")
end

-- is the C4 the active weapon right now? (used only for plant-complete + HUD)
local function active_is_c4(lp)
    local is = false
    pcall(function()
        local w = lp:get_weapon()
        if w then
            local cn = (w.get_class_name and w:get_class_name()) or (w.get_name and w:get_name()) or ""
            if tostring(cn):lower():find("c4") then is = true end
        end
    end)
    return is
end

-- ─── v1.4: bomb / round truth ────────────────────────────
-- v1.3 called the plant "done" as soon as `active_is_c4` went false. That read is
-- unreliable (get_weapon / class-name shape varies per build), so the bot dropped
-- +attack ~0.6s in and the plant was CANCELLED every time. Now the plant is only
-- finished when the SERVER says the bomb is down.
local function gr_get(name)
    local v = nil
    pcall(function()
        local gr = entity.get_game_rules()
        if gr then v = gr[name] end
    end)
    return v
end
local function bomb_is_planted()
    if state.bomb_down then return true end
    if gr_get("m_bBombPlanted") then return true end
    local n = 0
    pcall(function()
        local t = entity.get_entities("CPlantedC4")
        n = (t and #t) or 0
    end)
    return n > 0
end
-- CC4 netvar: true from the first arming tick until planted / aborted
local function c4_arming(lp)
    local a = false
    pcall(function()
        local w = lp:get_weapon()
        if w and w.m_bStartedArming then a = true end
    end)
    return a
end
local function in_bomb_zone(lp)
    local z = nil
    pcall(function() z = lp.m_bInBombZone end)
    return z
end

-- one full run reset (new round / warmup end / respawn)
local function run_reset(why)
    state.phase            = "IDLE"
    state.bomb_down        = false
    state.arm_started      = false
    state.plant_hold_t     = 0
    state.rearm_until      = 0
    state.reposition_until = 0
    state.last_origin      = nil
    state.stuck_since      = 0
    state.escape_yaw       = nil
    state.escape_until     = 0
    state.jump_until       = 0
    state.diag             = why or "reset"
end

-- event.userid -> is that me? (object identity, JAG0YAW pattern — never read enemy props)
local function ev_is_me(e)
    local mine = false
    pcall(function()
        local ent = entity.get(e.userid, true)
        mine = (ent ~= nil and ent == entity.get_local_player())
    end)
    return mine
end

pcall(function() events.bomb_beginplant:set(function(e) if ev_is_me(e) then state.arm_started = true end end) end)
pcall(function() events.bomb_abortplant:set(function(e)
    if ev_is_me(e) then state.arm_started = false; state.aborts = (state.aborts or 0) + 1; state.rearm_until = 0 end
end) end)
-- planted by ANYONE ends our job -> retreat
pcall(function() events.bomb_planted:set(function() state.bomb_down = true end) end)
pcall(function() events.round_prestart:set(function() run_reset("round prestart") end) end)
pcall(function() events.round_start:set(function() run_reset("round start") end) end)

-- ─── marks: persisted per map ────────────────────────────
local function marks_path(map) return "nl/Sel01-PlantBot/" .. tostring(map or "unknown") .. ".txt" end
local function marks_save()
    local lines = {}
    if state.a_spot    then lines[#lines + 1] = string.format("A %.1f %.1f %.1f", state.a_spot.x, state.a_spot.y, state.a_spot.z) end
    if state.safe_spot then lines[#lines + 1] = string.format("S %.1f %.1f %.1f", state.safe_spot.x, state.safe_spot.y, state.safe_spot.z) end
    pcall(function() files.write(marks_path(state.spots_map or state.mapname), table.concat(lines, "\n")) end)
end
local function marks_load(map)
    state.a_spot = nil; state.safe_spot = nil; state.spots_map = map
    local data = nil
    pcall(function() data = files.read(marks_path(map)) end)
    if data then
        for line in tostring(data):gmatch("[^\r\n]+") do
            local tag, x, y, z = line:match("(%a)%s+(-?[%d.]+)%s+(-?[%d.]+)%s+(-?[%d.]+)")
            if tag == "A" then state.a_spot = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
            elseif tag == "S" then state.safe_spot = { x = tonumber(x), y = tonumber(y), z = tonumber(z) } end
        end
    end
end

-- ─── obstacle traces (world geometry only — NOT players) ─
local PROBE_MASK = 0x400B
local function probe_clear(lp, lo, yaw_deg, dist)
    local rad = math.rad(yaw_deg)
    local dx, dy = math.cos(rad) * dist, math.sin(rad) * dist
    local function ray(h)
        local res = nil
        pcall(function()
            res = utils.trace_line(vector(lo.x, lo.y, lo.z + h), vector(lo.x + dx, lo.y + dy, lo.z + h), lp, PROBE_MASK)
        end)
        return (not res) or (res.fraction or 1) >= 0.99
    end
    return ray(40) and ray(62)
end
local function crouch_passable(lp, lo, yaw_deg, dist)
    local rad = math.rad(yaw_deg)
    local dx, dy = math.cos(rad) * dist, math.sin(rad) * dist
    local res = nil
    pcall(function()
        res = utils.trace_line(vector(lo.x, lo.y, lo.z + 18), vector(lo.x + dx, lo.y + dy, lo.z + 18), lp, PROBE_MASK)
    end)
    return (not res) or (res.fraction or 1) >= 0.99
end
local function can_step_up(lp, lo, yaw_deg, dist)
    local rad = math.rad(yaw_deg)
    local fx, fy = math.cos(rad) * dist, math.sin(rad) * dist
    local res = nil
    pcall(function()
        res = utils.trace_line(vector(lo.x, lo.y, lo.z + 50), vector(lo.x + fx, lo.y + fy, lo.z + 50), lp, PROBE_MASK)
    end)
    if not res then return false end
    return (res.fraction or 1) >= 0.99
end

-- ─── shared greedy mover (trimmed from WalkBot compute_move) ──
local function compute_move(lp, lo, want_yaw, now, base_act)
    local probe = 55
    pcall(function() probe = pb_probe:get() end)
    local aj = false
    pcall(function() aj = pb_jump and pb_jump:get() end)
    local move_yaw = want_yaw
    state.activity = base_act
    state.block = "clear"
    state.pass_crouch = false

    if state.escape_yaw and now < (state.escape_until or 0) then
        state.activity = "STUCK"; state.block = "escape"; state.diag = base_act .. " hard-escape"
        if aj then state.jump_until = math.max(state.jump_until or 0, now + 0.10) end
        state.last_origin = lo
        return state.escape_yaw
    end

    local look = math.min(probe * 2.2, 130)
    if not probe_clear(lp, lo, want_yaw, look) and crouch_passable(lp, lo, want_yaw, probe) then
        state.pass_crouch = true; state.block = "duck-pass"; state.diag = base_act .. " duck-pass"
    elseif not probe_clear(lp, lo, want_yaw, look) then
        state.block = "front"
        local found = false
        local order = state.avoid_dir >= 0 and { 1, -1 } or { -1, 1 }
        for _, s in ipairs(order) do
            for _, ang in ipairs({ 20, 40, 60, 80, 105, 135 }) do
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

    if state.last_origin then
        local moved = v_len2d(vector(lo.x - state.last_origin.x, lo.y - state.last_origin.y, 0))
        if moved < 1.5 then
            if state.stuck_since == 0 then state.stuck_since = now end
            local dur = now - state.stuck_since
            if dur > 1.2 then
                state.activity = "STUCK"; state.block = "wedged"
                local side = (state.avoid_dir ~= 0 and state.avoid_dir) or 1
                state.escape_yaw = norm_ang(want_yaw + 160 * side)
                state.escape_until = now + 0.8
                state.avoid_dir = -side
                if aj then state.jump_until = now + 0.18 end
                state.diag = base_act .. " WEDGED -> hard escape"
                move_yaw = state.escape_yaw
                state.stuck_since = now
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
    return move_yaw
end

local function apply_move(cmd, move_yaw, now)
    local spd = 450
    pcall(function() spd = pb_speed:get() end)
    pcall(function() cmd.move_yaw = move_yaw; cmd.forwardmove = spd; cmd.sidemove = 0 end)
    if state.pass_crouch then pcall(function() cmd.in_duck = true end) end
    if now < (state.jump_until or 0) then pcall(function() cmd.in_jump = true end) end
end

-- ─── main tick ───────────────────────────────────────────
local function plantbot_tick(cmd)
    state.mapname = safe_mapname()
    if state.spots_map ~= state.mapname then marks_load(state.mapname) end

    local now = 0
    pcall(function() now = globals.realtime end)

    -- drain mark buttons (use current origin, alive or not — you stand on the spot)
    if _pb_mark_a or _pb_mark_safe or _pb_print_pos or _pb_clear then
        local any = get_lp_any()
        local o = any and get_origin(any)
        if _pb_clear then _pb_clear = false; state.a_spot = nil; state.safe_spot = nil; marks_save()
            pcall(function() print("[PlantBot] marks cleared for " .. state.mapname) end) end
        if o then
            if _pb_mark_a then _pb_mark_a = false; state.a_spot = { x = o.x, y = o.y, z = o.z }; marks_save()
                pcall(function() print(string.format("[PlantBot] A spot marked: %.0f %.0f %.0f", o.x, o.y, o.z)) end) end
            if _pb_mark_safe then _pb_mark_safe = false; state.safe_spot = { x = o.x, y = o.y, z = o.z }; marks_save()
                pcall(function() print(string.format("[PlantBot] safe spot marked: %.0f %.0f %.0f", o.x, o.y, o.z)) end) end
            if _pb_print_pos then _pb_print_pos = false
                pcall(function() print(string.format("[PlantBot] pos = %.0f %.0f %.0f  (map %s)", o.x, o.y, o.z, state.mapname)) end) end
        else
            _pb_mark_a = false; _pb_mark_safe = false; _pb_print_pos = false
        end
    end

    local on = false
    pcall(function() on = pb_enable and pb_enable:get() end)
    if not on then state.phase = "IDLE"; state.activity = "OFF"; state.diag = "disabled"; return end

    -- team read + auto-join T. 2=T, 3=CT.
    local any = get_lp_any()
    pcall(function() state.team = (any and tonumber(any.m_iTeam)) or 0 end)
    local alive_now = false
    pcall(function() alive_now = any and any:is_alive() end)
    local autot = false
    pcall(function() autot = pb_autot and pb_autot:get() end)
    -- CRITICAL: `jointeam` while ALIVE makes the game SUICIDE you to switch — that's the
    -- "I spawn and instantly die" bug. So ONLY issue it when we are NOT alive (team-select
    -- menu / spectator), where switching is free. When alive on CT we wait for the next
    -- death instead of forcing it. Never fires when already T.
    if autot and not alive_now and state.team ~= 2 and (now - (state.team_pick_t or 0)) > 2.0 then
        state.team_pick_t = now
        exec("jointeam 2")        -- pick / force Terrorists (only while dead = safe)
    end

    -- ── v1.4 round tracking ──
    -- events.round_start covers the normal case; this poll is the fallback for builds
    -- where the event does not fire (and it also catches a mid-round round reset).
    -- m_fRoundStartTime is re-stamped by the server on every fresh round.
    local rst = gr_get("m_fRoundStartTime")
    if rst and state.round_t and math.abs(rst - state.round_t) > 0.01 then run_reset("new round") end
    if rst then state.round_t = rst end

    -- warmup: planting is disabled -> park, and start a fresh run the moment it ends
    local warmup = gr_get("m_bWarmupPeriod") and true or false
    if state.warmup and not warmup then run_reset("warmup over -> run") end
    state.warmup = warmup
    if warmup then
        state.round_state = "WARMUP"
        state.phase = "IDLE"; state.activity = "WARMUP"; state.diag = "warmup — waiting for live round"
        return              -- no cmd writes -> your WASD works
    end

    local lp = get_lp()
    if not lp then
        -- dead / in team menu: arm a fresh run for when we respawn. Don't touch cmd.
        if state.was_alive then state.phase = "IDLE" end
        state.was_alive = false
        state.activity = "DEAD"; state.diag = "dead / not spawned"
        return
    end
    local respawned = not state.was_alive
    state.was_alive = true
    local lo = get_origin(lp)
    if not lo then state.activity = "IDLE"; state.diag = "no origin"; return end

    -- need both marks before we can run
    if not (state.a_spot and state.safe_spot) then
        state.phase = "NEED_MARK"
        state.activity = "NEED_MARK"
        state.diag = (state.a_spot and "" or "mark A  ") .. (state.safe_spot and "" or "mark Safe")
        return  -- no cmd writes -> your WASD works
    end

    -- freeze time: the server ignores movement anyway, and standing still would trip
    -- the stuck detector. Hold, keep the bomb in hand, start moving when it unfreezes.
    if gr_get("m_bFreezePeriod") then
        state.round_state = "FREEZE"
        state.activity = "FREEZE"; state.diag = "freeze time — waiting"
        state.last_origin = nil; state.stuck_since = 0
        equip_c4(now)
        return
    end
    state.round_state = "LIVE"

    -- start a run: on respawn, or when enabled while idle/done and alive
    if respawned or state.phase == "IDLE" or state.phase == "NEED_MARK" then
        run_reset("run start")
        state.phase = "GOTO_A"; state.diag = "run start"
    end

    local has_c4 = active_is_c4(lp)

    -- bomb already down (we planted it, or a teammate did) -> nothing left but retreat
    if (state.phase == "GOTO_A" or state.phase == "PLANT") and bomb_is_planted() then
        state.phase = "RETREAT"; state.diag = "bomb is down -> retreat"
    end

    -- ── state machine ──
    if state.phase == "GOTO_A" then
        equip_c4(now)                                   -- take the bomb in hand on the way
        local a = state.a_spot
        local d = dist2d(lo.x, lo.y, a.x, a.y)
        local radius = 120
        pcall(function() radius = pb_radius:get() end)
        if d <= radius then
            state.phase = "PLANT"; state.plant_hold_t = now
            state.arm_started = false; state.rearm_until = 0; state.reposition_until = 0
            state.diag = "at A -> planting"
            return
        end
        local mv = compute_move(lp, lo, dir_yaw_xy(lo.x, lo.y, a.x, a.y), now, "GOTO_A")
        apply_move(cmd, mv, now)

    elseif state.phase == "PLANT" then
        local arming = c4_arming(lp)
        if arming then state.arm_started = true end

        -- not standing in the bomb zone (or the plant refuses to start) -> close the gap first
        local zone = in_bomb_zone(lp)
        if (not arming) and (zone == false or now < (state.reposition_until or 0)) then
            local a = state.a_spot
            if dist2d(lo.x, lo.y, a.x, a.y) > 25 then
                equip_c4(now)
                local mv = compute_move(lp, lo, dir_yaw_xy(lo.x, lo.y, a.x, a.y), now, "PLANT")
                apply_move(cmd, mv, now)
                state.plant_hold_t = now            -- hold clock only starts once we are there
                state.diag = (zone == false) and "not in bomb zone -> closing" or "re-positioning on mark"
                state.had_c4 = has_c4
                return
            end
        end

        -- take the bomb out ONLY before arming starts: a slot switch mid-arm cancels the plant
        if (not arming) and (not has_c4) then equip_c4(now) end

        -- freeze completely and HOLD +attack. Any movement / duck / jump aborts the plant.
        local release = now < (state.rearm_until or 0)   -- brief release so a re-press registers
        state.jump_until = 0; state.pass_crouch = false
        pcall(function() cmd.move_yaw = 0; cmd.forwardmove = 0; cmd.sidemove = 0 end)
        pcall(function() cmd.in_attack = (not release) end)
        pcall(function() cmd.in_jump = false end)
        pcall(function() cmd.in_duck = false end)

        local held = now - (state.plant_hold_t or 0)
        state.activity = "PLANT"
        state.diag = arming and string.format("arming %.1fs — holding", held)
                    or (release and "re-press +attack" or "holding +attack")

        if bomb_is_planted() then
            -- the ONLY real completion signal (server side), v1.3 guessed from the weapon
            state.phase = "RETREAT"; state.diag = "planted -> retreat"
        elseif state.arm_started and (not arming) and held > 1.0 then
            -- arming stopped without a plant = aborted (bumped / damaged) -> release + re-press
            state.arm_started = false
            state.rearm_until = now + 0.2
            state.plant_hold_t = now
            state.aborts = (state.aborts or 0) + 1
            state.diag = "plant aborted -> re-arm"
        elseif (not state.arm_started) and held > 3.0 then
            -- +attack does nothing here (wrong spot / bomb not out) -> step back onto the mark
            state.reposition_until = now + 0.6
            state.rearm_until = now + 0.2
            state.plant_hold_t = now
            state.diag = "plant not starting -> re-position"
        elseif state.arm_started and held > 12.0 then
            state.phase = "RETREAT"; state.diag = "plant timeout -> retreat"
        end

    elseif state.phase == "RETREAT" then
        local s = state.safe_spot
        local d = dist2d(lo.x, lo.y, s.x, s.y)
        local arrive = 180
        pcall(function() arrive = pb_safe_radius:get() end)
        if d <= arrive then
            state.phase = "DONE"; state.activity = "DONE"; state.diag = "at safe spot -> done"
            return
        end
        local mv = compute_move(lp, lo, dir_yaw_xy(lo.x, lo.y, s.x, s.y), now, "RETREAT")
        apply_move(cmd, mv, now)

    else -- DONE: release control (your WASD works), wait for next respawn to loop
        state.activity = "DONE"; state.diag = "done — waiting next round"
        -- no cmd writes
    end

    state.had_c4 = has_c4
end
pcall(function() events.createmove:set(plantbot_tick) end)

-- ─── HUD ─────────────────────────────────────────────────
local function col(r, g, b, a) return color(r, g, b, a or 255) end
local function phase_color(p)
    if p == "GOTO_A" then return col(120, 230, 120)
    elseif p == "PLANT" then return col(255, 180, 60)
    elseif p == "RETREAT" then return col(120, 200, 255)
    elseif p == "DONE" then return col(160, 160, 255)
    elseif p == "NEED_MARK" then return col(255, 110, 110)
    else return col(150, 150, 150) end
end

local function render_hud()
    local show, dbg = false, false
    pcall(function() show = pb_hud and pb_hud:get() end)
    pcall(function() dbg  = pb_debug and pb_debug:get() end)
    if not (show or dbg) then return end

    pcall(function()
        local ss = render.screen_size()
        local x = 18
        local y = math.floor(ss.y * 0.50)
        local line = 16
        render.text(4, vector(x, y), col(120, 200, 255), nil, "Sel01-PlantBot v" .. SEL01_PB_VERSION); y = y + line
        local tname = (state.team == 2 and "T") or (state.team == 3 and "CT") or "?"
        render.text(3, vector(x, y), col(180, 180, 180), nil, "Map: ")
        render.text(3, vector(x + 38, y), col(255, 255, 255), nil, state.mapname .. "  [" .. tname .. "]"); y = y + line
        render.text(3, vector(x, y), col(180, 180, 180), nil, "Phase: ")
        render.text(3, vector(x + 50, y), phase_color(state.phase), nil, state.phase); y = y + line
        render.text(3, vector(x, y), col(180, 180, 180), nil, "Act: ")
        render.text(3, vector(x + 34, y), col(255, 255, 255), nil,
            state.activity .. (state.pass_crouch and "  +DUCK" or "")); y = y + line
        render.text(3, vector(x, y), col(180, 180, 180), nil, "Marks: ")
        render.text(3, vector(x + 50, y), state.a_spot and col(120, 230, 120) or col(255, 110, 110), nil, "A")
        render.text(3, vector(x + 66, y), state.safe_spot and col(120, 230, 120) or col(255, 110, 110), nil, "Safe"); y = y + line
        render.text(3, vector(x, y), col(180, 180, 180), nil, "Round: ")
        render.text(3, vector(x + 50, y),
            (state.round_state == "LIVE") and col(120, 230, 120) or col(255, 200, 90), nil,
            tostring(state.round_state) .. (state.bomb_down and "  BOMB DOWN" or ""))
        if dbg then
            y = y + line + 4
            render.text(3, vector(x, y), col(120, 200, 255), nil, "── debug ──"); y = y + line
            render.text(3, vector(x, y), col(180, 180, 180), nil, "C4: ")
            render.text(3, vector(x + 28, y), state.had_c4 and col(120, 230, 120) or col(255, 160, 90), nil,
                state.had_c4 and "in hand" or "not active"); y = y + line
            render.text(3, vector(x, y), col(180, 180, 180), nil, "arm: ")
            render.text(3, vector(x + 34, y), state.arm_started and col(120, 230, 120) or col(160, 160, 160), nil,
                (state.arm_started and "started" or "no") .. "  aborts " .. tostring(state.aborts or 0)); y = y + line
            render.text(3, vector(x, y), col(180, 180, 180), nil, "block: ")
            render.text(3, vector(x + 46, y), col(255, 255, 255), nil, tostring(state.block)); y = y + line
            render.text(3, vector(x, y), col(180, 180, 180), nil, "why: ")
            render.text(3, vector(x + 32, y), phase_color(state.phase), nil, tostring(state.diag))
        end
    end)
end
pcall(function() events.render:set(render_hud) end)

-- ─── shutdown ────────────────────────────────────────────
pcall(function()
    events.shutdown:set(function()
        pcall(function() events.createmove:unset() end)
        pcall(function() events.render:unset() end)
        pcall(function() events.bomb_beginplant:unset() end)
        pcall(function() events.bomb_abortplant:unset() end)
        pcall(function() events.bomb_planted:unset() end)
        pcall(function() events.round_prestart:unset() end)
        pcall(function() events.round_start:unset() end)
    end)
end)

-- ─── load banner ─────────────────────────────────────────
local function log(t) pcall(function() print(t) end) end
log("==============================================")
log("Sel01-PlantBot v" .. SEL01_PB_VERSION .. " loaded — by seltonmt01")
log("Map: " .. safe_mapname())
log("1) Stand on the A plant spot -> click 'Mark A Spot'.")
log("2) Stand on the safe spot    -> click 'Mark Safe Spot'.")
log("3) Enable PlantBot. It walks A -> plants -> retreats -> loops each round.")
log("Auto-Join T keeps you on Terrorists through the team-select menu.")
log("==============================================")
