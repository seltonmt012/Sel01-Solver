-- ╔══════════════════════════════════════════════════╗
-- ║  Sel01-PlantBot                                    ║
-- ║  Version: 1.9                                      ║
-- ║  One job: walk to a marked A spot, plant the C4,   ║
-- ║  walk to a marked safe spot, done. Auto-picks T.   ║
-- ║  by seltonmt01                                     ║
-- ╚══════════════════════════════════════════════════╝
-- @name Sel01-PlantBot
-- @version 1.9
-- @author seltonmt01
-- @description Standalone plant-bot. You MARK two spots once (persisted per map):
--   the A plant spot + the safe spot. Then it loops every round:
--   GOTO_A  -> greedy-walk straight to the marked A spot (equips the bomb on the way)
--   PLANT   -> stop + hold +attack until the SERVER reports the bomb down (v1.4/v1.8)
--   RETREAT -> greedy-walk straight to the marked safe spot
--   DONE    -> release control (your WASD works) until next round / respawn, then loop
--   Auto-joins T whenever a team is not assigned (handles the round team-select menu).
--   Movement ONLY — aiming stays with the ragebot. While idle/done it does NOT touch
--   the cmd, so your normal keys work.

local SEL01_PB_VERSION = "1.9"

local ffi_ok, ffi = pcall(require, "ffi")

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
    -- v1.8 plant hold-lock
    attack_since = 0,           -- when the current uninterrupted +attack hold started (0 = not pressing)
    arm_read_ok  = false,       -- the arming netvar has read TRUE at least once on this build
    warmup       = false,
    round_t      = nil,         -- m_fRoundStartTime — changes = new round
    round_state  = "LIVE",
    -- v1.5 nav-mesh routing (same parser as Sel01-WalkBot)
    nav_map      = nil,
    nav_path     = nil,         -- cached A* route (list of area centers)
    nav_goal_id  = nil,
    nav_start_id = nil,         -- area we last re-pathed FROM (churn detection)
    nav_path_t   = 0,
    nav_path_len = 0,
    -- v1.9 diagnostics
    logs         = {},          -- ring buffer of decision lines (Dump button)
    goal_d_prev  = nil,         -- last heartbeat distance to the current goal
    repaths      = 0,
}

-- button drains (module globals: closures run before `state` helpers bind)
_pb_mark_a    = false
_pb_mark_safe = false
_pb_clear     = false
_pb_print_pos = false
_pb_dumplog   = false

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

local pb_enable, pb_radius, pb_speed, pb_jump, pb_probe, pb_safe_radius, pb_autot, pb_hud, pb_debug, pb_nav, pb_bhop
pcall(function()
    pb_enable      = g_main:switch("Enable PlantBot")
    pb_autot       = g_main:switch("Auto-Join T (pick T every round)")
    g_main:button("Mark A Spot (stand on plant spot)",  function() _pb_mark_a    = true end)
    g_main:button("Mark Safe Spot (stand on safe spot)", function() _pb_mark_safe = true end)
    g_main:button("Clear Marks (this map)",              function() _pb_clear     = true end)
    pb_nav         = g_main:switch("Use Nav-Mesh Routing (real map paths)")
    pb_radius      = g_main:slider("A-Site Plant Radius", 60, 600, 120)
    pb_safe_radius = g_main:slider("Safe-Spot Arrive Radius", 80, 600, 180)
    pb_speed       = g_main:slider("Move Speed", 50, 450, 450)
    pb_jump        = g_main:switch("Allow Jumping (obstacles / step-up / wedge escape)")
    pb_bhop        = g_main:switch("Bunny-Hop on long open stretches (faster travel)")
    pb_probe       = g_main:slider("Obstacle Probe (units)", 20, 140, 55)
    pb_hud         = g_hud:switch("HUD Overlay")
    pb_debug       = g_hud:switch("Debug Info (live phase/stuck/nav console logs)")
    g_hud:button("Print My Pos (console)", function() _pb_print_pos = true end)
    g_hud:button("Dump PlantBot Logs (console)", function() _pb_dumplog = true end)
    g_hud:label(" ")
    pb_vc_label    = g_hud:label("\aAAAAAAFFv" .. SEL01_PB_VERSION .. " — checking for updates...")
end)
pcall(function() if pb_nav then pb_nav:set(true) end end)
pcall(function() if pb_bhop then pb_bhop:set(true) end end)
pcall(function() if pb_hud then pb_hud:set(true) end end)
pcall(function() if pb_autot then pb_autot:set(true) end end)

-- ─── v1.9 diagnostic log ring (WalkBot pattern) ──────────
-- Every interesting decision (phase change, nav re-path, avoid / boxed / wedge, plant
-- arming) lands in `state.logs` ALWAYS, so a run can be diagnosed after the fact via the
-- Dump button. When "Debug Info" is on it ALSO prints live to the game console, throttled
-- per message KEY so one recurring event can't spam. Writer multi-fallback client.log ->
-- print (Solver pattern). `pb_debug` is a local declared above; this closure reads it at
-- call time so the ref stays live.
local PB_LOG_CAP = 160
local pb_log_last = {}
local function pb_console(text)
    if not pcall(function() client.log(text) end) then pcall(function() print(text) end) end
end
local function pb_log(key, throttle, fmt, ...)
    local now = 0; pcall(function() now = globals.realtime end)
    local msg = (select('#', ...) > 0) and string.format(fmt, ...) or fmt
    local r = state.logs
    r[#r + 1] = string.format("[%7.1f] %s", now, msg)
    if #r > PB_LOG_CAP then table.remove(r, 1) end
    local dbg = false
    pcall(function() dbg = pb_debug and pb_debug:get() end)
    if not dbg then return end
    if (now - (pb_log_last[key] or -1e9)) >= (throttle or 0) then
        pb_log_last[key] = now
        pb_console(string.format("[PB %5.1f] %s", now, msg))
    end
end

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
-- horizontal speed — logs only (the stuck detector still works off origin delta)
local function hspeed_of(ent)
    local v = nil
    pcall(function() v = ent.m_vecVelocity end)
    if not v then return 0 end
    return v_len2d(v)
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
-- CC4 netvar: true from the first arming tick until planted / aborted.
-- v1.8: `lp:get_weapon()` is build-dependent and returns nil / a shape without the
-- netvar on some builds. A false "not arming" made the caller exec slot5 mid-arm,
-- which CANCELS the plant every 0.4s (bot only ever "tapped" +attack). Two extra
-- sources now back it up: the CC4 world entity, and the bomb_beginplant event flag.
local function c4_arming(lp)
    local a = false
    pcall(function()
        local w = lp:get_weapon()
        if w and w.m_bStartedArming then a = true end
    end)
    if not a then
        pcall(function()
            local t = entity.get_entities("CC4")
            for i = 1, (t and #t or 0) do
                local e = t[i]
                if e and e.m_bStartedArming then a = true; break end
            end
        end)
    end
    if a then state.arm_read_ok = true end   -- this build DOES expose the netvar
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
    state.attack_since     = 0
    state.rearm_until      = 0
    state.reposition_until = 0
    state.last_origin      = nil
    state.stuck_since      = 0
    state.escape_yaw       = nil
    state.escape_until     = 0
    state.jump_until       = 0
    state.diag             = why or "reset"
    state.goal_d_prev      = nil
    pb_log("reset", 0, "RUN RESET (%s)", why or "reset")
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

-- ═══ NAV-MESH (v1.5 — same parser as Sel01-WalkBot) ══════
-- Straight-line walking rams every wall between spawn and the site. The .nav mesh is
-- the graph CSGO's own bots route on, so with it loaded the bot knows the real way to A
-- (doors, ramps, connectors) and only needs the traces for local obstacle dodging.
-- Reads the SAME pre-copied navs the WalkBot uses (nl/Sel01-WalkBot/<map>.nav) so you
-- do not have to copy the maps twice.
local nav = { ok = false, map = nil, count = 0, areas = nil, err = "not loaded" }

-- Binary read via kernel32: files.read TRUNCATES at the first null byte (nav header has
-- 0x00 at byte 5) and raises an unsuppressable popup on a missing path. CreateFileA just
-- returns INVALID_HANDLE on a miss — clean.
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
    "nl/Sel01-PlantBot/",
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
    return nil, "no nav (copy csgo/maps/<map>.nav to nl/Sel01-WalkBot/)"
end

-- SCAN-BASED parser: the documented v16 area layout has a build-specific ~99-byte
-- undocumented trailing block per area, and area ids are non-contiguous. So we read each
-- area header + connections, then scan forward for the next plausible header.
local function nav_parse_scan(raw)
    local n = #raw
    local base = ffi.cast("const uint8_t*", raw)
    local function u16(o) return tonumber(ffi.cast("const uint16_t*", base + o)[0]) end
    local function u32(o) return tonumber(ffi.cast("const uint32_t*", base + o)[0]) end
    local function f32(o) return tonumber(ffi.cast("const float*",    base + o)[0]) end

    if n < 64 or u32(0) ~= 0xFEEDFACE then return nil, "bad magic", 0 end
    local major = u32(4)
    local off = 12 + 4
    if major >= 14 then off = off + 1 end
    local placeCount = u16(off); off = off + 2
    for _ = 1, placeCount do off = off + 2 + u16(off) end
    if major >= 12 then off = off + 1 end
    local areaCount = u32(off); off = off + 4
    if areaCount < 1 or areaCount > 60000 then return nil, "bad areaCount " .. areaCount, 0 end

    local function plaus(o)
        if o + 44 > n then return false end
        if u32(o + 4) ~= 0 then return false end
        for k = 0, 5 do
            local f = f32(o + 8 + 4 * k)
            if f ~= f then return false end
            if (f < 0 and -f or f) > 8000 then return false end
        end
        local nwz, sez = f32(o + 16), f32(o + 28)
        local nez, swz = f32(o + 32), f32(o + 36)
        local zlo = (nwz < sez and nwz or sez) - 200
        local zhi = (nwz > sez and nwz or sez) + 200
        if nez < zlo or nez > zhi or swz < zlo or swz > zhi then return false end
        local nwx, nwy = f32(o + 8), f32(o + 12)
        local sex, sey = f32(o + 20), f32(o + 24)
        local ext = (sex - nwx < 0 and nwx - sex or sex - nwx)
                  + (sey - nwy < 0 and nwy - sey or sey - nwy)
        local mag = (nwx < 0 and -nwx or nwx) + (nwy < 0 and -nwy or nwy)
        if not (ext > 16 and ext < 12000 and mag > 30) then return false end
        local h = o + 40
        for _ = 1, 4 do
            local c = u32(h); h = h + 4
            if c > 40 then return false end
            h = h + 4 * c
            if h > n then return false end
        end
        return true
    end

    local areas = {}
    local got = 0
    for a = 1, areaCount do
        if not plaus(off) then
            return areas, string.format("stopped @%d/%d (got %d)", a, areaCount, got), got
        end
        local id = u32(off)
        local nwx, nwy, nwz = f32(off + 8), f32(off + 12), f32(off + 16)
        local sex, sey, sez = f32(off + 20), f32(off + 24), f32(off + 28)
        local h = off + 40
        local conns = {}
        for _ = 1, 4 do
            local c = u32(h); h = h + 4
            for _ = 1, c do conns[#conns + 1] = u32(h); h = h + 4 end
        end
        areas[id] = { id = id, x = (nwx + sex) * 0.5, y = (nwy + sey) * 0.5,
                      z = (nwz + sez) * 0.5, conns = conns }
        got = got + 1
        if a == areaCount then break end
        local limit = math.min(h + 16000, n - 44)
        local found, p = nil, h
        while p < limit do
            if plaus(p) then found = p; break end
            p = p + 1
        end
        if not found then
            return areas, string.format("ended early %d/%d", got, areaCount), got
        end
        off = found
    end
    return areas, nil, got
end

local function nav_load(map)
    nav = { ok = false, map = map, count = 0, areas = nil, err = "loading" }
    state.nav_path = nil; state.nav_goal_id = nil; state.nav_path_len = 0
    if not (ffi_ok and ffi) then nav.err = "no ffi"; return end
    local raw, how = nav_read(map)
    if not raw then nav.err = tostring(how); return end
    local ok, areas, err, cnt = pcall(nav_parse_scan, raw)
    if not ok then nav.err = "parse crash"; return end
    cnt = cnt or 0
    if areas then
        local got, edges = 0, 0
        for _, ar in pairs(areas) do got = got + 1; edges = edges + #(ar.conns or {}) end
        nav.areas = areas; nav.count = got; nav.edges = edges
        nav.ok = got >= 50
        nav.err = string.format("%s %d/%d areas, %d links", nav.ok and "OK" or "too few", got, cnt, edges)
    else
        nav.err = "parse failed: " .. tostring(err)
    end
end

local function nav_nearest(x, y)
    if not (nav.ok and nav.areas) then return nil end
    local best, bestd
    for _, a in pairs(nav.areas) do
        local dx, dy = a.x - x, a.y - y
        local d = dx * dx + dy * dy
        if not bestd or d < bestd then best, bestd = a, d end
    end
    return best
end

-- A* over the area graph -> ordered list of area centers
local function nav_astar(startId, goalId)
    local areas = nav.areas
    if not (areas and areas[startId] and areas[goalId]) then return nil end
    if startId == goalId then return { areas[goalId] } end
    local goal = areas[goalId]
    local function hcost(a) local dx, dy = a.x - goal.x, a.y - goal.y; return math.sqrt(dx * dx + dy * dy) end
    local open, came, g, f, closed = { [startId] = true }, {}, { [startId] = 0 }, { [startId] = hcost(areas[startId]) }, {}
    local guard = 0
    while next(open) and guard < 6000 do
        guard = guard + 1
        local cur, curf
        for id in pairs(open) do if not curf or f[id] < curf then cur, curf = id, f[id] end end
        if cur == goalId then
            local path, c = {}, cur
            while c do table.insert(path, 1, areas[c]); c = came[c] end
            return path
        end
        open[cur] = nil; closed[cur] = true
        local ca = areas[cur]
        for _, nb in ipairs(ca.conns) do
            local na = areas[nb]
            if na and not closed[nb] then
                local dx, dy = ca.x - na.x, ca.y - na.y
                local tg = g[cur] + math.sqrt(dx * dx + dy * dy)
                if not g[nb] or tg < g[nb] then
                    came[nb] = cur; g[nb] = tg; f[nb] = tg + hcost(na); open[nb] = true
                end
            end
        end
    end
    return nil
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

-- yaw toward a world goal, ROUTED through the mesh when loaded, else straight line.
-- Path cached per goal-area, re-pathed every 1.5s, nodes popped as we reach them.
local function nav_dir(lp, lo, gx, gy, now)
    local use = false
    pcall(function() use = pb_nav and pb_nav:get() end)
    if not (use and nav.ok) then
        state.nav_path_len = 0
        pb_log("nav_off", 5.0, "nav unused (%s) -> straight line", use and tostring(nav.err) or "toggle off")
        return dir_yaw_xy(lo.x, lo.y, gx, gy)
    end
    local ga = nav_nearest(gx, gy)
    local sa = nav_nearest(lo.x, lo.y)
    if not (ga and sa) then
        state.nav_path_len = 0
        pb_log("nav_area", 3.0, "no nav area under %s -> straight line", (not sa) and "ME" or "GOAL")
        return dir_yaw_xy(lo.x, lo.y, gx, gy)
    end
    if state.nav_goal_id ~= ga.id or not state.nav_path or (now - (state.nav_path_t or 0)) > 1.5 then
        local prev_start = state.nav_start_id
        state.nav_path = nav_astar(sa.id, ga.id)
        state.nav_goal_id = ga.id
        state.nav_start_id = sa.id
        state.nav_path_t = now
        state.repaths = (state.repaths or 0) + 1
        if not state.nav_path then
            pb_log("nav_fail", 1.0, "A* FAILED start=%d goal=%d (areas=%d) -> straight line", sa.id, ga.id, nav.count or 0)
        else
            pb_log("nav_path", 1.0, "re-path #%d start=%d%s goal=%d -> %d nodes (first %.0f,%.0f d=%.0f)",
                   state.repaths, sa.id, (prev_start and prev_start ~= sa.id) and "*" or "",
                   ga.id, #state.nav_path, state.nav_path[1].x, state.nav_path[1].y,
                   dist2d(lo.x, lo.y, state.nav_path[1].x, state.nav_path[1].y))
        end
    end
    local path = state.nav_path
    if not path or #path == 0 then state.nav_path_len = 0; return dir_yaw_xy(lo.x, lo.y, gx, gy) end

    -- v1.9 ANTI-PING-PONG. A* always returns the START area as node 1, and an area center
    -- can sit 200-300u BEHIND us when we stand at that area's edge (exactly the situation
    -- just before a corner). The old code only popped nodes closer than 130u, so the bot
    -- turned around, walked back to its own area center, popped it, and walked forward
    -- again — the "goes back right before the corner, then forward again" oscillation,
    -- restarted by every 1.5s re-path. Three pop rules now run after every (re)path:
    --   1. the node of the area we are STANDING in is never a target
    --   2. a leading node that a LATER node beats on straight-line distance is a detour
    --      backwards -> skip it, but only when that later node is trace-clear (never cut
    --      a corner through a wall)
    --   3. the usual reach-radius pop
    local popped, skipped = 0, 0
    if #path > 1 and path[1].id == sa.id then table.remove(path, 1); popped = popped + 1 end
    while #path > 1 do
        local d1 = dist2d(lo.x, lo.y, path[1].x, path[1].y)
        local d2 = dist2d(lo.x, lo.y, path[2].x, path[2].y)
        if d1 < 130 then
            table.remove(path, 1); popped = popped + 1
        elseif d2 <= d1 and probe_clear(lp, lo, dir_yaw_xy(lo.x, lo.y, path[2].x, path[2].y), math.min(d2, 200)) then
            table.remove(path, 1); popped = popped + 1; skipped = skipped + 1
        else
            break
        end
    end
    if popped > 0 then
        pb_log("nav_pop", 0.5, "advanced +%d node(s)%s, %d left, next (%.0f,%.0f) d=%.0f",
               popped, (skipped > 0) and string.format(" [%d backward skipped]", skipped) or "",
               #path, path[1].x, path[1].y, dist2d(lo.x, lo.y, path[1].x, path[1].y))
    end
    state.nav_path_len = #path
    state.nav_node_d = dist2d(lo.x, lo.y, path[1].x, path[1].y)
    -- last node reached: aim at the real mark, not the area center
    if #path <= 1 then return dir_yaw_xy(lo.x, lo.y, gx, gy) end
    return dir_yaw_xy(lo.x, lo.y, path[1].x, path[1].y)
end

-- (probe_clear + PROBE_MASK live above nav_dir — the path-pop rules trace too)
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

    local hspd = hspeed_of(lp)

    if state.escape_yaw and now < (state.escape_until or 0) then
        state.activity = "STUCK"; state.block = "escape"; state.diag = base_act .. " hard-escape"
        if aj then state.jump_until = math.max(state.jump_until or 0, now + 0.10) end
        state.last_origin = lo
        pb_log("escape", 0.5, "%s ESCAPE-HOLD yaw=%.0f (%.2fs left) hspd=%.0f @(%.0f,%.0f)",
               base_act, state.escape_yaw, (state.escape_until or 0) - now, hspd, lo.x, lo.y)
        return state.escape_yaw
    end

    local look = math.min(probe * 2.2, 130)
    if not probe_clear(lp, lo, want_yaw, look) and crouch_passable(lp, lo, want_yaw, probe) then
        state.pass_crouch = true; state.block = "duck-pass"; state.diag = base_act .. " duck-pass"
        pb_log("duck", 1.0, "%s duck-pass (low gap ahead, want=%.0f)", base_act, want_yaw)
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
            pb_log("avoid", 0.5, "%s AVOID %+.0f (want=%.0f -> go=%.0f) hspd=%.0f @(%.0f,%.0f)",
                   base_act, move_yaw - want_yaw, want_yaw, move_yaw, hspd, lo.x, lo.y)
        else
            state.block = "boxed"
            if aj and can_step_up(lp, lo, want_yaw, probe) then
                state.jump_until = now + 0.12; state.activity = "JUMP"; state.block = "step"
                state.diag = base_act .. " step-up jump"
                pb_log("step", 0.5, "%s step-up jump (want=%.0f)", base_act, want_yaw)
            else
                move_yaw = want_yaw + (state.avoid_dir ~= 0 and state.avoid_dir or 1) * 110
                state.diag = base_act .. " boxed WALL -> turn"
                pb_log("boxed", 0.5, "%s BOXED — no clear fan angle, want=%.0f -> turn %.0f hspd=%.0f @(%.0f,%.0f)",
                       base_act, want_yaw, move_yaw, hspd, lo.x, lo.y)
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
                state.wedges = (state.wedges or 0) + 1
                pb_log("wedge", 0, "%s WEDGED #%d @(%.0f,%.0f) hspd=%.0f moved=%.1f want=%.0f block=%s -> escape %.0f for 0.8s",
                       base_act, state.wedges, lo.x, lo.y, hspd, moved, want_yaw, state.block, state.escape_yaw)
            elseif dur > 0.35 then
                state.activity = "STUCK"
                move_yaw = want_yaw + (state.avoid_dir ~= 0 and state.avoid_dir or 1) * 90
                if aj and can_step_up(lp, lo, want_yaw, probe) then state.jump_until = now + 0.15 end
                state.diag = base_act .. " stuck -> strafe"
                pb_log("strafe", 0.5, "%s stuck %.1fs (moved=%.1f hspd=%.0f) -> strafe %+.0f",
                       base_act, dur, moved, hspd, move_yaw - want_yaw)
            end
        else
            if state.stuck_since ~= 0 then
                pb_log("unstuck", 0.5, "%s recovered after %.1fs (moved=%.1f hspd=%.0f)",
                       base_act, now - state.stuck_since, moved, hspd)
            end
            state.stuck_since = 0
        end
    end
    state.last_origin = lo
    return move_yaw
end

-- v1.9 bunny-hop on long OPEN stretches. The bot walks the same route every round, so
-- once the lane ahead is provably clear it is free speed. Hard-gated off anywhere it
-- would cost time or break something: near a corner (short forward probe / a shoulder
-- blocked / the heading just changed), while avoiding / ducking / wedged, near the next
-- nav node, and near the goal — a jump on the plant spot cancels the arm.
local function bhop_ok(lp, lo, yaw, now, goal_d)
    local on = false
    pcall(function() on = pb_bhop and pb_bhop:get() end)
    if not on then return false end
    if state.block ~= "clear" or state.activity == "STUCK" or state.pass_crouch then return false end
    if state.escape_yaw and now < (state.escape_until or 0) then return false end
    if (goal_d or 0) < 400 then return false end
    if state.nav_path_len > 0 and (state.nav_node_d or 1e9) < 220 then return false end
    -- a fresh turn means we are ON a corner right now -> walk it, hop after it
    if math.abs(norm_ang(yaw - (state.bhop_yaw or yaw))) > 25 then
        state.bhop_yaw = yaw; state.bhop_steady_t = now; return false
    end
    state.bhop_yaw = yaw
    if (now - (state.bhop_steady_t or 0)) < 0.4 then return false end
    -- geometry: long lane ahead AND both shoulders open = not a corner / doorway
    if not probe_clear(lp, lo, yaw, 360) then return false end
    if not (probe_clear(lp, lo, yaw + 35, 170) and probe_clear(lp, lo, yaw - 35, 170)) then return false end
    return true
end

local function apply_move(cmd, move_yaw, now, lp, lo, goal_d)
    local spd = 450
    pcall(function() spd = pb_speed:get() end)
    pcall(function() cmd.move_yaw = move_yaw; cmd.forwardmove = spd; cmd.sidemove = 0 end)
    if state.pass_crouch then pcall(function() cmd.in_duck = true end) end
    if now < (state.jump_until or 0) then pcall(function() cmd.in_jump = true end) end

    if lp and lo and bhop_ok(lp, lo, move_yaw, now, goal_d) then
        local onground = true
        pcall(function() onground = bit.band(tonumber(lp.m_fFlags) or 1, 1) == 1 end)
        if onground then
            pcall(function() cmd.in_jump = true end)
        else
            -- light auto air-strafe keeps the speed we gained
            if (now - (state.bhop_flip_t or 0)) > 0.25 then
                state.bhop_side = -(state.bhop_side or 1); state.bhop_flip_t = now
            end
            pcall(function() cmd.sidemove = (state.bhop_side or 1) * 450 end)
        end
        if not state.bhop_on then
            pb_log("bhop", 0, "BHOP start (%s) yaw=%.0f goal_d=%.0f node_d=%.0f",
                   state.phase, move_yaw, goal_d or -1, state.nav_node_d or -1)
        end
        state.bhop_on = true
        state.activity = "BHOP"
    elseif state.bhop_on then
        pb_log("bhop", 0, "BHOP stop (block=%s act=%s goal_d=%.0f)", state.block, state.activity, goal_d or -1)
        state.bhop_on = false
    end
end

-- ─── main tick ───────────────────────────────────────────
local function plantbot_tick(cmd)
    state.mapname = safe_mapname()
    if state.spots_map ~= state.mapname then marks_load(state.mapname) end

    -- v1.5: (re)load the nav mesh on map change while the toggle is on
    do
        local use_nav = false
        pcall(function() use_nav = pb_nav and pb_nav:get() end)
        if use_nav and state.mapname ~= "unknown" and state.nav_map ~= state.mapname then
            state.nav_map = state.mapname
            pcall(nav_load, state.mapname)
            pcall(function() print("[PlantBot] nav " .. state.mapname .. ": " .. tostring(nav.err)) end)
        end
    end

    local now = 0
    pcall(function() now = globals.realtime end)

    -- drain the Dump-Logs button (works whether the bot is enabled or not)
    if _pb_dumplog then
        _pb_dumplog = false
        pb_console(string.format("──── PlantBot v%s log dump (%d lines) ────", SEL01_PB_VERSION, #state.logs))
        pb_console(string.format("map=%s phase=%s act=%s nav=%s aborts=%d wedges=%d repaths=%d",
            tostring(state.mapname), tostring(state.phase), tostring(state.activity),
            tostring(nav.err), state.aborts or 0, state.wedges or 0, state.repaths or 0))
        for _, ln in ipairs(state.logs) do pb_console(ln) end
        pb_console("──── end PlantBot log dump ────")
    end

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
        pb_log("phase", 0, "PHASE -> GOTO_A (%s) @(%.0f,%.0f) A=(%.0f,%.0f) d=%.0f nav=%s",
               respawned and "respawn" or "enabled", lo.x, lo.y, state.a_spot.x, state.a_spot.y,
               dist2d(lo.x, lo.y, state.a_spot.x, state.a_spot.y), tostring(nav.err))
    end

    local has_c4 = active_is_c4(lp)

    -- bomb already down (we planted it, or a teammate did) -> nothing left but retreat
    if (state.phase == "GOTO_A" or state.phase == "PLANT") and bomb_is_planted() then
        pb_log("phase", 0, "PHASE %s -> RETREAT (bomb is down)", state.phase)
        state.phase = "RETREAT"; state.diag = "bomb is down -> retreat"
        state.goal_d_prev = nil
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
            state.attack_since = 0
            state.diag = "at A -> planting"
            state.goal_d_prev = nil
            pb_log("phase", 0, "PHASE GOTO_A -> PLANT (d=%.0f <= r=%.0f) @(%.0f,%.0f)", d, radius, lo.x, lo.y)
            return
        end
        -- routed through the nav mesh when loaded (real map path), else straight line
        local mv = compute_move(lp, lo, nav_dir(lp, lo, a.x, a.y, now), now, "GOTO_A")
        apply_move(cmd, mv, now, lp, lo, d)

    elseif state.phase == "PLANT" then
        local arming_live = c4_arming(lp)               -- netvar / CC4 entity (may be blind)
        if arming_live then state.arm_started = true end
        -- v1.8: treat the bomb_beginplant event as arming too. The netvar read is blind on
        -- some builds; without this the bot kept exec'ing slot5 mid-arm -> plant cancelled.
        local arming = arming_live or state.arm_started

        -- not standing in the bomb zone (or the plant refuses to start) -> close the gap first
        local zone = in_bomb_zone(lp)
        if (not arming) and (zone == false or now < (state.reposition_until or 0)) then
            local a = state.a_spot
            if dist2d(lo.x, lo.y, a.x, a.y) > 25 then
                equip_c4(now)
                local mv = compute_move(lp, lo, dir_yaw_xy(lo.x, lo.y, a.x, a.y), now, "PLANT")
                apply_move(cmd, mv, now)            -- never bhop here (jump = plant cancelled)
                state.plant_hold_t = now            -- hold clock only starts once we are there
                state.attack_since = 0              -- not pressing while we walk
                state.diag = (zone == false) and "not in bomb zone -> closing" or "re-positioning on mark"
                pb_log("plant_move", 1.0, "PLANT %s (d=%.0f zone=%s)",
                       (zone == false) and "not in bomb zone -> closing" or "re-positioning",
                       dist2d(lo.x, lo.y, a.x, a.y), tostring(zone))
                state.had_c4 = has_c4
                return
            end
        end

        -- v1.8: a slot switch mid-arm cancels the plant, and BOTH `arming` and `has_c4` come
        -- from reads that can silently fail. So slot5 is now hard-locked the moment we have
        -- been holding +attack for 0.3s — recovery goes through the reposition branch below,
        -- which clears attack_since first.
        local pressing_for = (state.attack_since or 0) > 0 and (now - state.attack_since) or 0
        if (not arming) and (not has_c4) and pressing_for < 0.3 then equip_c4(now) end

        -- freeze completely and HOLD +attack. Any movement / duck / jump aborts the plant.
        local release = now < (state.rearm_until or 0)   -- brief release so a re-press registers
        state.jump_until = 0; state.pass_crouch = false
        pcall(function() cmd.move_yaw = 0; cmd.forwardmove = 0; cmd.sidemove = 0 end)
        pcall(function() cmd.in_attack = (not release) end)
        pcall(function() cmd.in_jump = false end)
        pcall(function() cmd.in_duck = false end)
        if release then state.attack_since = 0
        elseif (state.attack_since or 0) == 0 then state.attack_since = now end

        local held = now - (state.plant_hold_t or 0)
        state.activity = "PLANT"
        state.diag = arming and string.format("arming %.1fs — holding", held)
                    or (release and "re-press +attack" or "holding +attack")

        pb_log("plant", 1.0, "PLANT hold %.1fs arming=%s(live=%s read_ok=%s) zone=%s c4=%s press=%.1fs",
               held, tostring(arming), tostring(arming_live), tostring(state.arm_read_ok),
               tostring(zone), tostring(has_c4), pressing_for)

        if bomb_is_planted() then
            -- the ONLY real completion signal (server side), v1.3 guessed from the weapon
            state.phase = "RETREAT"; state.diag = "planted -> retreat"
            state.goal_d_prev = nil
            pb_log("phase", 0, "PHASE PLANT -> RETREAT (BOMB PLANTED after %.1fs, %d aborts)", held, state.aborts or 0)
        elseif state.arm_read_ok and state.arm_started and (not arming_live) and held > 1.0 then
            -- arming stopped without a plant = aborted (bumped / damaged) -> release + re-press
            state.arm_started = false
            state.rearm_until = now + 0.2
            state.plant_hold_t = now
            state.attack_since = 0
            state.aborts = (state.aborts or 0) + 1
            state.diag = "plant aborted -> re-arm"
            pb_log("abort", 0, "PLANT ABORTED #%d after %.1fs -> release 0.2s + re-press", state.aborts, held)
        elseif (not state.arm_started) and held > 3.0 then
            -- +attack does nothing here (wrong spot / bomb not out) -> step back onto the mark
            state.reposition_until = now + 0.6
            state.rearm_until = now + 0.2
            state.plant_hold_t = now
            state.attack_since = 0          -- unlock slot5 for the recovery re-equip
            state.diag = "plant not starting -> re-position"
            pb_log("noplant", 0, "+attack did nothing for 3.0s (zone=%s c4=%s) -> re-position on mark",
                   tostring(zone), tostring(has_c4))
        elseif state.arm_started and held > 12.0 then
            state.phase = "RETREAT"; state.diag = "plant timeout -> retreat"
            state.goal_d_prev = nil
            pb_log("phase", 0, "PHASE PLANT -> RETREAT (TIMEOUT 12s, plant never completed)")
        end

    elseif state.phase == "RETREAT" then
        local s = state.safe_spot
        local d = dist2d(lo.x, lo.y, s.x, s.y)
        local arrive = 180
        pcall(function() arrive = pb_safe_radius:get() end)
        if d <= arrive then
            state.phase = "DONE"; state.activity = "DONE"; state.diag = "at safe spot -> done"
            pb_log("phase", 0, "PHASE RETREAT -> DONE (d=%.0f <= %.0f)", d, arrive)
            return
        end
        local mv = compute_move(lp, lo, nav_dir(lp, lo, s.x, s.y, now), now, "RETREAT")
        apply_move(cmd, mv, now, lp, lo, d)

    else -- DONE: release control (your WASD works), wait for next respawn to loop
        state.activity = "DONE"; state.diag = "done — waiting next round"
        -- no cmd writes
    end

    -- 2s heartbeat: the goal distance TREND is what exposes a route problem — a rising
    -- distance while travelling means the bot is walking away from the goal (nav node
    -- behind us / avoid fan turned us around), which is the log line to look for.
    -- self-throttled: pb_log ALWAYS pushes to the ring, so an un-gated 64Hz heartbeat
    -- would flush every useful line out of the 160-line buffer.
    if (now - (state.hb_t or 0)) >= 2.0
       and (state.phase == "GOTO_A" or state.phase == "RETREAT" or state.phase == "PLANT") then
        state.hb_t = now
        local g = (state.phase == "RETREAT") and state.safe_spot or state.a_spot
        local gd = g and dist2d(lo.x, lo.y, g.x, g.y) or -1
        local trend = "?"
        if state.goal_d_prev then
            local dd = gd - state.goal_d_prev
            trend = (dd < -8) and string.format("closing %.0f", -dd)
                 or ((dd > 8) and string.format("AWAY +%.0f", dd) or "flat")
        end
        pb_log("hb", 0, "%s d=%.0f (%s) @(%.0f,%.0f) hspd=%.0f act=%s block=%s nav=%d node_d=%.0f bhop=%s | %s",
               state.phase, gd, trend, lo.x, lo.y, hspeed_of(lp), tostring(state.activity),
               tostring(state.block), state.nav_path_len or 0, state.nav_node_d or -1,
               tostring(state.bhop_on or false), tostring(state.diag))
        state.goal_d_prev = gd
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
            render.text(3, vector(x, y), col(180, 180, 180), nil, "nav: ")
            render.text(3, vector(x + 34, y), nav.ok and col(120, 230, 120) or col(255, 160, 90), nil,
                tostring(nav.err) .. (state.nav_path_len > 0 and ("  path " .. state.nav_path_len) or "")); y = y + line
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
pcall(function() events.render:set(function()
    render_hud()
    if pb_vc_draw then pb_vc_draw() end   -- v1.6 on-screen version banner (load-time only)
end) end)

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

-- ═══ VERSION CHECK (GitHub, v1.5) ════════════════════════
-- One fetch of versions.txt from the repo at load. No nagging: the result is a single
-- line in the menu (Display group) plus one console line — nothing drawn on screen.
local VC_URL = "https://raw.githubusercontent.com/seltonmt012/Sel01-Solver/master/versions.txt"
local VC_KEY = "plantbot"

-- v1.6: ON-SCREEN banner (the menu label alone is easy to miss). "checking version..."
-- while the request is in flight, then a short green "up to date" or a longer red
-- "OUTDATED", both fading out. Nothing stays on screen afterwards.
pb_vc_font = nil
pcall(function() pb_vc_font = render.load_font("Verdana", 26, "b") end)
pb_vc_scr  = { text = "checking version...", r = 190, g = 190, b = 190, hold = nil }
pb_vc_gate = (globals.realtime or 0) + 4.0   -- let the Solver's fullscreen intro finish first
function pb_vc_draw()
    local st = pb_vc_scr
    if not st then return end
    local now = globals.realtime or 0
    if now < pb_vc_gate then return end
    local shown = now - pb_vc_gate
    local drawing = st
    if st.hold and shown < 1.2 then
        drawing = { text = "checking version...", r = 190, g = 190, b = 190 }
    elseif st.hold then
        if not st.t_until then st.t_until = now + st.hold end
        if now >= st.t_until then pb_vc_scr = nil; return end
    elseif shown > 14 then
        pb_vc_scr = nil; return
    end
    local a = 255
    if drawing.t_until then
        local left = drawing.t_until - now
        if left < 1.0 then a = math.floor(255 * left) end
    end
    pcall(function()
        local ss = render.screen_size()
        local y  = ss.y * 0.81
        local col = color(drawing.r, drawing.g, drawing.b, a)
        local f, w = pb_vc_font, nil
        if f then pcall(function() w = render.measure_text(f, nil, drawing.text) end) end
        if f and w then
            render.text(f, vector(ss.x / 2 - w.x / 2, y), col, nil, drawing.text)
        else
            render.text(5, vector(ss.x / 2, y), col, "c", drawing.text)
        end
    end)
end
local function vc_screen(text, r, g, b, secs)
    pb_vc_scr = { text = text, r = r, g = g, b = b, hold = secs }
end

local function vc_num(v)
    local a, b = tostring(v):match("(%d+)%.(%d+)")
    return (tonumber(a) or 0) * 1000 + (tonumber(b) or 0)
end
local function vc_set(text) pcall(function() if pb_vc_label then pb_vc_label:name(text) end end) end
local function vc_apply(body)
    local latest
    for line in tostring(body):gmatch("[^\r\n]+") do
        local k, v = line:match("^%s*([%w_]+)%s*=%s*([%d%.]+)")
        if k == VC_KEY then latest = v end
    end
    if not latest then
        vc_set("\aAAAAAAFFv" .. SEL01_PB_VERSION .. " - update check: no entry")
        vc_screen("Sel01-PlantBot v" .. SEL01_PB_VERSION .. "  -  version unknown", 190, 190, 190, 4)
        return
    end
    if vc_num(latest) > vc_num(SEL01_PB_VERSION) then
        vc_set("\aFF5555FFUPDATE: v" .. latest .. " available (you run v" .. SEL01_PB_VERSION .. ")")
        vc_screen("Sel01-PlantBot OUTDATED  -  v" .. latest .. " available (you run v" .. SEL01_PB_VERSION .. ")",
                  255, 85, 85, 15)
        pcall(function() print("[PlantBot] update available: v" .. latest .. " (you run v" .. SEL01_PB_VERSION
            .. ") - github.com/seltonmt012/Sel01-Solver") end)
    else
        vc_set("\a55DD55FFv" .. SEL01_PB_VERSION .. " - up to date")
        vc_screen("Sel01-PlantBot v" .. SEL01_PB_VERSION .. "  -  up to date", 85, 221, 85, 4)
    end
end
local function vc_check()
    local started = false
    pcall(function()
        http.get(VC_URL, function(ok, resp)
            if ok and resp and (resp.status == nil or resp.status == 200) and resp.body then
                pcall(vc_apply, resp.body)
            else
                vc_set("\aAAAAAAFFv" .. SEL01_PB_VERSION .. " - update check failed")
                vc_screen("Sel01-PlantBot v" .. SEL01_PB_VERSION .. "  -  update check failed", 190, 190, 190, 4)
            end
        end)
        started = true
    end)
    if started then return end
    -- fallback for builds without `http`: urlmon download to disk, then read it back
    pcall(function()
        if not (ffi_ok and ffi) then return end
        pcall(ffi.cdef, [[
            void* __stdcall URLDownloadToFileA(void* a, const char* url, const char* file, int r, int cb);
            bool DeleteUrlCacheEntryA(const char* url);
        ]])
        local um, wi = ffi.load("UrlMon"), ffi.load("WinInet")
        local path = "nl/Sel01-PlantBot/versions.txt"
        pcall(function() files.create_folder("nl/Sel01-PlantBot/") end)
        pcall(function() files.write(path, "") end)   -- files.read popups on a missing path
        pcall(function() wi.DeleteUrlCacheEntryA(VC_URL) end)
        um.URLDownloadToFileA(nil, VC_URL, path, 0, 0)
        local body = files.read(path)
        if body and #body > 0 then vc_apply(body) end
    end)
    if pb_vc_scr and tostring(pb_vc_scr.text):find("checking") then
        vc_screen("Sel01-PlantBot v" .. SEL01_PB_VERSION .. "  -  update check failed", 190, 190, 190, 4)
    end
end
pcall(vc_check)

-- ─── load banner ─────────────────────────────────────────
local function log(t) pcall(function() print(t) end) end
log("==============================================")
log("Sel01-PlantBot v" .. SEL01_PB_VERSION .. " loaded — by seltonmt01")
log("Map: " .. safe_mapname())
log("1) Stand on the A plant spot -> click 'Mark A Spot'.")
log("2) Stand on the safe spot    -> click 'Mark Safe Spot'.")
log("3) Enable PlantBot. It walks A -> plants -> retreats -> loops each round.")
log("Auto-Join T keeps you on Terrorists through the team-select menu.")
log("v1.9: 'Debug Info' = live console logs, 'Dump PlantBot Logs' = last 160 decisions.")
log("v1.9: nav anti-ping-pong (no more walking back right before a corner) + bhop on")
log("      long open stretches (never near a corner, never on the plant spot).")
log("==============================================")
