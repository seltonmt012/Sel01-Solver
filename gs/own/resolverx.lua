_G.try_require = function(module, message)

    local success, result = pcall(require, module)

    if success then 
        return result 
    else 
        return error(message) 
    end
end
local ffi = require "ffi"

local RESOLVER_VERSION = "2.9"   -- bump on every change so the load banner proves the fresh copy




ffi.cdef[[
    struct c_animstate { 
        char pad[ 3 ];
        char m_bForceWeaponUpdate; //0x5
        char pad1[ 91 ];
        void* m_pBaseEntity; //0x60
        void* m_pActiveWeapon; //0x64
        void* m_pLastActiveWeapon; //0x68
        float m_flLastClientSideAnimationUpdateTime; //0x6C
        int m_iLastClientSideAnimationUpdateFramecount; //0x70
        float m_flAnimUpdateDelta; //0x74
        float m_flEyeYaw; //0x78
        float m_flPitch; //0x7C
        float flSpeedNormalized;
        float m_flGoalFeetYaw; //0x80
        float flAffectedFraction;
        float flDuckAmount;
        float m_flCurrentFeetYaw; //0x84
        float m_flCurrentTorsoYaw; //0x88
        float m_flUnknownVelocityLean; //0x8C
        float m_flLeanAomunt; //0x90
        char pad2[ 4 ];
        float m_flFeetCycle; //0x98
        float m_flFeetYawRate; //0x9C
        char pad3[ 4 ];
        float m_fDuckAmount; //0xA4
        float m_fLandingDuckAdditiveSomething; //0xA8
        char pad4[ 4 ];
        float m_vOriginX; //0xB0
        float m_vOriginY; //0xB4
        float m_vOriginZ; //0xB8
        float m_vLastOriginX; //0xBC
        float m_vLastOriginY; //0xC0
        float m_vLastOriginZ; //0xC4
        float m_vVelocityX; //0xC8
        float m_vVelocityY; //0xCC
        char pad5[ 4 ];
        float m_flUnknownFloat1; //0xD4
        char pad6[ 8 ];
        float m_flUnknownFloat2; //0xE0
        float m_flUnknownFloat3; //0xE4
        float m_flUnknown; //0xE8
        float m_flSpeed2D; //0xEC
        float m_flUpVelocity; //0xF0
        float m_flSpeedNormalized; //0xF4
        float m_flFeetSpeedForwardsOrSideWays; //0xF8
        float m_flFeetSpeedUnknownForwardOrSideways; //0xFC
        float m_flTimeSinceStartedMoving; //0x100
        float m_flTimeSinceStoppedMoving; //0x104
        bool m_bOnGround; //0x108
        bool m_bInHitGroundAnimation; //0x109
        float m_flTimeSinceInAir; //0x10A
        float m_flLastOriginZ; //0x10E
        float m_flHeadHeightOrOffsetFromHittingGroundAnimation; //0x112
        float m_flStopToFullRunningFraction; //0x116
        char pad7[ 4 ]; //0x11A
        float m_flMagicFraction; //0x11E
        char pad8[ 60 ]; //0x122
        float m_flWorldForce; //0x15E
        char pad9[ 462 ]; //0x162
        float m_flPlaybackRate; //0x0028
        float m_flMaxYaw; //0x334
    };

    typedef struct
    {
        float   m_anim_time;		
        float   m_fade_out_time;	
        int     m_flags;			
        int     m_activity;			
        int     m_priority;			
        int     m_order;			
        int     m_sequence;			
        float   m_prev_cycle;		
        float   m_weight;			
        float   m_weight_delta_rate;
        float   m_playback_rate;	
        float   m_cycle;			
        void* m_owner;			
        int     m_bits;				
    } C_AnimationLayer;
    typedef uintptr_t (__thiscall* GetClientEntityHandle_4242425_t)(void*, uintptr_t);

    typedef int(__thiscall* get_clipboard_text_count)(void*);
	typedef void(__thiscall* set_clipboard_text)(void*, const char*, int);
	typedef void(__thiscall* get_clipboard_text)(void*, int, const char*, int);
    typedef bool(__thiscall* console_is_visible)(void*);
    typedef void*(__thiscall* get_client_entity_t)(void*, int);
    typedef uintptr_t (__thiscall* GetClientEntity_123123_t)(void*, int);
]]


math.angle_diff = function(dest, src)
    local delta = 0.0

    delta = math.fmod(dest - src, 360.0)

    if dest > src then
        if delta >= 180 then delta = delta - 360 end
    else
        if delta <= -180 then delta = delta + 360 end
    end

    return delta
end
math.normalize = function(angle)
    if angle < -180 then
       angle = angle + 360
    end
    if angle > 180 then
       angle = angle - 360
    end
    return angle
 end
math.lerp = function(name, value, speed)
    local delta = globals.frametime() * speed
    return name + (value - name) * math.min(delta, 1)
end
math.clamp = function(v, min, max)
    if min > max then min, max = max, min end
    if v > max then return max end
    if v < min then return min end
    return v
end
math.clamp2 = function(v, min, max) 
    local num = v;
    num = num < min and min or num; 
    num = num > max and max or num; 
    return num 
end
math.approach_angle = function(target, value, speed)
    target = math.anglemod(target)
    value = math.anglemod(value)
    local delta = target - value
    if speed < 0 then speed = -speed end
    if delta < -180 then
        delta = delta + 360
    elseif delta > 180 then
        delta = delta - 360
    end
    if delta > speed then
        value = value + speed
    elseif delta < -speed then
        value = value - speed
    else
        value = target
    end
    return value
end
math.angle_normalize = function(angle)
    local ang = 0.0
    ang = math.fmod(angle, 360.0)
    if ang < 0.0 then ang = ang + 360 end
    return ang
end
local Safepoint =   {};
local Desync =      {};
local Pitch =   {};
local Records = {};
local VTable = {
    Entry = function(instance, index, type) return ffi.cast(type, (ffi.cast("void***", instance)[0])[index]) end,
    Bind = function(self, module, interface, index, typestring)
        local instance = client.create_interface(module, interface)
        local fnptr = self.Entry(instance, index, ffi.typeof(typestring))
        return function(...) return fnptr(instance, ...) end
    end
}

local entity_list_ptr = ffi.cast("void***", client.create_interface("client.dll", "VClientEntityList003"))
local get_client_entity_fn = ffi.cast("GetClientEntityHandle_4242425_t", entity_list_ptr[0][3])
local get_client_entity_by_handle_fn = ffi.cast("GetClientEntityHandle_4242425_t", entity_list_ptr[0][4])
local voidptr = ffi.typeof("void***")
local rawientitylist = client.create_interface("client_panorama.dll", "VClientEntityList003") or error("VClientEntityList003 wasnt found", 2)
local ientitylist = ffi.cast(voidptr, rawientitylist) or error("rawientitylist is nil", 2)
local get_client_entity = ffi.cast("get_client_entity_t", ientitylist[0][3]) or error("get_client_entity is nil", 2)
local NativeGetClientEntity = VTable:Bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")
entity.get_address = function(idx)
    return get_client_entity_fn(entity_list_ptr, idx)
end
entity.get_animstate = function(idx)
    local addr = entity.get_address(idx)
    if not addr then return end
    return ffi.cast("struct c_animstate**", addr + 0x9960)[0]
end
entity.GetSimulationTime = function(ent)
    local pointer = NativeGetClientEntity(ent)
    if pointer then return entity.get_prop(ent, "m_flSimulationTime"), ffi.cast("float*", ffi.cast("uintptr_t", pointer) + 0x26C)[0] else return 0 end
end
entity.get_animlayer = function(idx)
    local addr = entity.get_address(idx)
    if not addr then return end
    return ffi.cast("C_AnimationLayer**", ffi.cast('uintptr_t', addr) + 0x9960)[0]
end
local Menu = {}
Menu["Enable Resolver"] = ui.new_checkbox("Rage", "Other", "Enable Resolver")
Menu["Prediction Type"] = ui.new_combobox("Rage", "Other", "Prediction Type",{"Experimental","Fast","Default", "Auto"})
Menu["Interp Floor"] = ui.new_checkbox("Rage", "Other", "Interp floor (high ping)")
Menu["Magnitude Search"] = ui.new_checkbox("Rage", "Other", "Magnitude search")
Menu["Jitter Detect"] = ui.new_checkbox("Rage", "Other", "Jitter detection")
Menu["Debug Logs"] = ui.new_checkbox("Rage", "Other", "Resolver Debug Logs")
-- Sensible defaults for the new toggles (users on a fresh install get them ON)
ui.set(Menu["Interp Floor"], true)
ui.set(Menu["Magnitude Search"], true)
ui.set(Menu["Jitter Detect"], true)
local Desync = {}




-- Dead neural-net removed in v2.8 (was fully inert: string-keyed input vs numeric read -> constant
-- 0.5 output, and it was never called at runtime). Pure statistical resolver now.
function calculate_interp(ping_ms, interp_ratio, updaterate)
    local server_update_interval = 1000 / updaterate
    local base_interp = interp_ratio / updaterate

    local ping_buffer = (ping_ms * 0.25) / 1000

    -- Final recommended interp
    return math.max(base_interp, ping_buffer)
end

-- Statistical resolver state (per enemy) --------------------
local HITGROUPS = {"generic","head","chest","stomach","left arm","right arm","left leg","right leg","neck","?","gear"}
local function group_name(i) return i and HITGROUPS[i + 1] or "?" end
local function side_name(s) return (s and s < 0) and "LEFT" or "RIGHT" end
local ShotInfo = {}   -- [shot.id] = snapshot at fire time
local ResolveState = {}
-- Session reason-tally: lets the debug log show at a glance how many misses were real resolver
-- faults (flip) vs netcode we correctly kept (stale/ping/spread). Reset on load.
local Stats = { hits = 0, flip = 0, kept = 0, netcode = 0, spread = 0, ping = 0, unreg = 0, lowhc = 0 }
-- A miss fired below this hitchance is a ragebot gamble shot (spread/desperation), not a resolver
-- side error -> it must never flip the forced side (v2.9). Logs showed 4-13% HC misses churning sides.
local LOW_HC = 30
-- Magnitude search ladder: once a side is PROVEN (>=1 hit) but we still miss fresh on it, the real
-- body is likely at a smaller desync than the max-58 we force. mag_probe steps this ladder; a hit
-- locks the value (mag_bias). Starts at 58 so a genuine full-desync enemy re-confirms immediately.
local MAG_LADDER = { 58, 46, 34, 52, 40, 28 }
local function mag_probe(rs)
    rs.mag_step = (rs.mag_step or 1) + 1
    if rs.mag_step > #MAG_LADDER then rs.mag_step = 1 end
    rs.mag_bias = MAG_LADDER[rs.mag_step]
end
-- Cross-round side memory keyed by steamid: ResolveState is keyed by entity INDEX, which the
-- server reuses across rounds (a player gets a new slot on restart -> learned dominance is lost,
-- costing a first-contact miss every round). SideMemory survives index reuse so first contact on
-- a known player seeds the side that has actually been hitting, not a blind 50/50 default.
local SideMemory = {}   -- [sid] = { l = confirmed-left hits, r = confirmed-right hits }
local function get_sid(ent)
    local ok, sid = pcall(entity.get_steam64, ent)
    if ok and sid then return sid end
    return nil
end
local function get_rs(ent)
    local r = ResolveState[ent]
    if not r then
        r = { side = 1, miss = 0, hits_l = 0, hits_r = 0 }
        ResolveState[ent] = r
    end
    return r
end

-- Cached cvar refs + last-applied interp (avoid per-tick lookups/writes)
local cv_interpolate = cvar.cl_interpolate
local cv_interp_ratio = cvar.cl_interp_ratio
local cv_interp = cvar.cl_interp
local pred_ints_set = false
local pred_last_interp = nil
local resolver_was_on = false

local Resolver = {
    layers = {},
    safepoints = {},
    cache = {},
    rotation = {
        CENTER = 1,
        LEFT = 2,
        RIGHT = 3
    },

    GetMaxDesync = function(self, m_nAnimationState)
        local speedfactor = m_nAnimationState.flSpeedNormalized
        local avg_speedfactor = (m_nAnimationState.flAffectedFraction * -0.3 - 0.2) * speedfactor + 1
        local duck_amount = m_nAnimationState.flDuckAmount

        if duck_amount > 0 then
            local duck_speed = duck_amount * speedfactor
            avg_speedfactor = avg_speedfactor + (duck_speed * (0.5 - avg_speedfactor))
        end

        return avg_speedfactor
    end,
    updateLayers = function(self, idx)
        local resolver = self
        if not idx then return end
        local layers = entity.get_animlayer(idx)
        if not layers then return end
        if not resolver.layers[idx] then
            resolver.layers[idx] = {}
        end
        for i = 1, 12 do
            local layer = layers[i]
            if not layer then goto continue  end
            if not resolver.layers[idx][i] then
                resolver.layers[idx][i] = {}
            end
            resolver.layers[idx][i].m_playback_rate = layer.m_playback_rate or resolver.layers[idx][i].m_playback_rate
            resolver.layers[idx][i].m_sequence = layer.m_sequence or resolver.layers[idx][i].m_sequence
            ::continue::
        end
    end,
    isLBYFlexing = function(self, idx)
        local resolver = self
        if not resolver.layers[idx] then return end
        for i = 1, 12 do
            if not resolver.layers[idx][i] then goto continue end
            if not resolver.layers[idx][i].m_sequence then goto continue end

            if resolver.layers[idx][i].m_sequence == 979 then return true end

            ::continue::
        end
        return false
    end,
    find_desync = function(self, ent)
        local resolver = self
        local animstate = entity.get_animstate(ent)
        if not animstate then return nil end

        local rs = get_rs(ent)
        local sid = get_sid(ent)
        -- Entity index changed hands (round restart / slot reuse): the old occupant's dominance
        -- counts would poison the new player's miss-flip logic (a "proven" side that isn't his).
        -- Reset the index-local transient state; the returning player's real side comes back from
        -- SideMemory in the seed below.
        if sid and rs.sid ~= sid then
            rs.sid = sid
            rs.hits_l, rs.hits_r = 0, 0
            rs.miss, rs.side_miss = 0, 0
            rs.seeded = false
            rs.mag_bias, rs.mag_step = nil, nil
            rs.jitter, rs.lean_flips, rs.lean_seen = false, 0, 0
        end

        -- Magnitude: base = anim max-desync factor (pose param is unreliable on this build). Once the
        -- side is proven but we still miss fresh, mag_probe searches the ladder and stores mag_bias;
        -- a hit locks it. Until a bias is set we force the max (58), which suits full-desync enemies.
        local base_mag = math.clamp2(58 * (resolver:GetMaxDesync(animstate) or 0), 0, 58)
        if base_mag < 2 then base_mag = 58 end  -- standing/near-zero read -> assume full desync
        local mag = (ui.get(Menu["Magnitude Search"]) and rs.mag_bias) or base_mag

        local adiff = math.angle_diff(animstate.m_flEyeYaw, animstate.m_flGoalFeetYaw)

        -- Jitter/switch-AA detection: count how often the live feet-lean sign flips over a ~1s window.
        -- A jitter enemy flips constantly, which fools both a static forced side and the fresh-miss
        -- flip logic. When rs.jitter is set the miss handler stops trusting the lean as flip evidence.
        if ui.get(Menu["Jitter Detect"]) then
            if math.abs(adiff) > 8 then
                local sgn = adiff > 0 and 1 or -1
                if rs.lean_sign and rs.lean_sign ~= sgn then rs.lean_flips = (rs.lean_flips or 0) + 1 end
                rs.lean_sign = sgn
            end
            rs.lean_seen = (rs.lean_seen or 0) + 1
            if rs.lean_seen >= 64 then   -- ~1s at 64 tick
                rs.jitter = (rs.lean_flips or 0) >= 6
                rs.lean_flips, rs.lean_seen = 0, 0
            end
        else
            rs.jitter = false
        end
        -- First contact: seed side. Priority: cross-round steamid memory (this player's proven
        -- dominant side) > feet-vs-eye lean > blind default. Beats a 50/50 guess on known enemies.
        if not rs.seeded and rs.hits_l == 0 and rs.hits_r == 0 and rs.miss == 0 then
            local m = sid and SideMemory[sid]
            if m and m.l ~= m.r then
                rs.side = (m.l > m.r) and -1 or 1   -- proven dominant side from prior rounds
            elseif adiff > 5 then rs.side = 1
            elseif adiff < -5 then rs.side = -1 end
            rs.seeded = true
        end
        -- Side is persistent: hit keeps it, miss flips it (see hit_logs/miss_logs).
        -- Do NOT overwrite from dominance each tick or a mid-round AA switch can never correct.
        local side = rs.side

        rs.last_mag = mag       -- snapshot for aim_fire debug
        rs.last_side = side
        rs.last_adiff = adiff   -- eye-vs-goalfeet lean at resolve time, for miss diagnosis
        return {
            desync = mag,
            side = side,
            angle_diff = adiff,
        }
    end,
    Animlayer = function(self)
        if not ui.get(Menu["Enable Resolver"]) then
            -- On disable, clear our forces once so enemies aren't stuck at last resolved value
            if resolver_was_on then
                local players = entity.get_players(true)
                for i = 1, #players do plist.set(players[i], "Force body yaw", false) end
                resolver_was_on = false
            end
            return
        end
        resolver_was_on = true
        local lp = entity.get_local_player()
        if not lp or lp <= 0 then return end
        if (entity.get_prop(lp, 'm_iHealth') or 0) < 1 then return end

        -- Pre-resolve ALL enemies every tick so a target switch is instantly resolved
        local players = entity.get_players(true)
        for i = 1, #players do
            local ent = players[i]
            if entity.is_alive(ent) then
                local d = self:find_desync(ent)
                if d then
                    plist.set(ent, "Force body yaw", true)
                    plist.set(ent, "Force body yaw value", math.clamp2(d.desync * d.side, -58, 58))
                    -- LBY-flex detection (anim layer sequence 979): a real yaw snap to the lower-body
                    -- yaw. Observational for now -> surfaced in the debug log so LBY enemies are visible.
                    local ok = pcall(function() self:updateLayers(ent) end)
                    local rs2 = ResolveState[ent]
                    if ok and rs2 then rs2.lby = self:isLBYFlexing(ent) and true or false end
                end
            end
        end
    end,
    Prediction = function(self)
        local lp = entity.get_local_player()
        if not lp or lp <= 0 then return end
        local value = 0.031
        if ui.get(Menu["Prediction Type"]) == "Default" then
        value = 0.031
        elseif ui.get(Menu["Prediction Type"]) == "Fast" then
            value = 0.025
        elseif ui.get(Menu["Prediction Type"]) == "Experimental" then
            value = 0
        elseif ui.get(Menu["Prediction Type"]) == "Auto" then
            local ratio = 1
            local latency = client.real_latency()
            if latency <= 10 then
                ratio = 1
            elseif latency >= 11 and latency <= 30 then
                ratio = 2
            elseif latency > 30 then
                ratio = 3 
            end
            value = calculate_interp(latency, ratio,64)
        end

        -- Interp floor: interp 0 (Experimental) at high ping shoots stale backtrack records -- the
        -- dominant miss cause in the logs (high-BT '?' misses). Never let interp drop to ~0 when ping
        -- is high; a 1-tick floor (1/64) restores a small buffer without the sluggishness of Default.
        if ui.get(Menu["Interp Floor"]) then
            local lat = client.real_latency() or 0
            local ms = lat < 5 and lat * 1000 or lat   -- normalize seconds-or-ms reading to ms
            if ms > 40 and value < 0.0155 then value = 0.0155 end
        end

        if not pred_ints_set then
            cv_interpolate:set_int(1)
            cv_interp_ratio:set_int(1)
            pred_ints_set = true
        end
        if value ~= pred_last_interp then
            cv_interp:set_float(value)
            pred_last_interp = value
        end
    end
}


local e_player_flags = {
    ON_GROUND = bit.lshift(1, 0),
    DUCKING = bit.lshift(1, 1),
    ANIMDUCKING = bit.lshift(1, 2),
    WATERJUMP = bit.lshift(1, 3),
    ON_TRAIN = bit.lshift(1, 4),
    IN_RAIN = bit.lshift(1, 5),
    FROZEN = bit.lshift(1, 6),
    ATCONTROLS = bit.lshift(1, 7),
    CLIENT = bit.lshift(1, 8),
    FAKECLIENT = bit.lshift(1, 9),
    IN_WATER = bit.lshift(1, 10)
}

entity.get_state = function(ent)
    if not ent then return end
    local flags = entity.get_prop(ent, "m_fFlags")
    local ducked = entity.get_prop(ent, 'm_flDuckAmount') > 0.7
    local state = nil
    if bit.band(flags, e_player_flags.ON_GROUND) ~= 0 then
        state = "standing"
    elseif ducked then
        state = "ducking"
    elseif bit.band(flags, e_player_flags.ON_GROUND) == 0 and bit.band(flags, e_player_flags.DUCKING) == 0
    then
        state = "jumping"
    end

    return state
end
hit_logs = function(shot)
    local hitgroup_names = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear"}
    local group = hitgroup_names[shot.hitgroup + 1] or "?"
    local rs = ResolveState[shot.target]
    Stats.hits = Stats.hits + 1
    if rs then
        rs.miss = 0
        rs.side_miss = 0
        rs.unproven_miss = 0
        rs.mag_step = nil   -- this magnitude worked; keep mag_bias locked, restart search only if we start missing again
        if rs.side < 0 then rs.hits_l = rs.hits_l + 1 else rs.hits_r = rs.hits_r + 1 end
        -- Cap dominance: uncapped counts make a mid-round AA switch take many hits to overcome (a
        -- 20-vs-0 lead needs 20 opposite hits before flip logic even sees the new side as stronger).
        -- Capping keeps the resolver responsive to switches while still favouring the proven side.
        if rs.hits_l > 12 then rs.hits_l = 12 end
        if rs.hits_r > 12 then rs.hits_r = 12 end
        -- Persist confirmed side across rounds (survives entity-index reuse)
        local sid = get_sid(shot.target)
        if sid then
            local m = SideMemory[sid]
            if not m then m = { l = 0, r = 0 }; SideMemory[sid] = m end
            if rs.side < 0 then m.l = m.l + 1 else m.r = m.r + 1 end
            if m.l > 20 then m.l = 20 end
            if m.r > 20 then m.r = 20 end
        end
    end
    print("Registered Hit to "..entity.get_player_name(shot.target) .."`s in to the "..group .. " for " ..shot.damage .. " ( "..(entity.get_prop(shot.target, "m_iHealth") or 0) .. " health remaining) | BT: "..globals.tickcount() - shot.tick .. " | Desync: "..(plist.get(shot.target,"Force body yaw value") or 0))

    if ui.get(Menu["Debug Logs"]) then
        local si = ShotInfo[shot.id]
        local want = si and group_name(si.want_group) or "?"
        local dl = rs and rs.hits_l or 0
        local dr = rs and rs.hits_r or 0
        client.color_log(120, 255, 120, string.format(
            "[RESOLVER HIT] %s | hit=%s wanted=%s dmg=%d hc=%s%% | forced=%s mag=%.1f | dom L%d/R%d | BT=%d",
            entity.get_player_name(shot.target) or "?", group, want, shot.damage or 0,
            si and tostring(si.hitchance) or "?",
            si and side_name(si.side) or "?", si and si.mag or 0,
            dl, dr, globals.tickcount() - (shot.tick or globals.tickcount())))
        if want ~= "?" and want ~= group then
            client.color_log(255, 200, 80, string.format(
                "   ^ wanted %s but hit %s -> hitchance/multipoint issue, not the resolver side", want, group))
        end
    end
    ShotInfo[shot.id] = nil
end


miss_logs = function(shot)
    local hitgroup_names = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear"}
    local group = hitgroup_names[shot.hitgroup + 1] or "?"
    local reasons = {
        ["spread"] = "Spread",
        ["prediction error"] = "Extrapolation",
        ["death"] = "Ping",
        ["unregistered shot"] = "Unregistered",
        ["?"] = "?"
    }
    local rs = ResolveState[shot.target]
    local old_side = rs and rs.side or 0
    local bt = globals.tickcount() - (shot.tick or globals.tickcount())
    local flipped = false
    local kept_proven = false
    local netcode_keep = false
    local lowhc_keep = false
    -- Only a FRESH-record "?" miss is real wrong-side evidence. A high-BT miss shot a stale
    -- backtrack record; "prediction error"/Extrapolation is a position error; Ping/Spread are RNG.
    -- Flipping side on any of those throws away a correct side and causes L<->R oscillation.
    local resolver_miss = (shot.reason == "?" or shot.reason == "prediction error" or shot.reason == nil)
    if rs and resolver_miss then
        rs.miss = rs.miss + 1
        -- side_miss counts CONSECUTIVE fresh misses that mean a real AA switch. If the last one was
        -- long ago (different engagement), it's stale -> decay it so an old miss can't push an
        -- unrelated new one to the flip threshold and flip a still-correct side.
        local now = globals.curtime()
        if rs.last_rmiss and now - rs.last_rmiss > 3 then rs.side_miss = 0 end
        rs.last_rmiss = now
        local cur = rs.side
        local cur_hits = (cur < 0) and rs.hits_l or rs.hits_r
        local opp_hits = (cur < 0) and rs.hits_r or rs.hits_l
        local fresh = (shot.reason == "?" or shot.reason == nil) and bt <= 6
        local si = ShotInfo[shot.id]
        local low_hc = si and type(si.hitchance) == "number" and si.hitchance < LOW_HC
        if low_hc then
            -- gamble shot fired below LOW_HC%: bullet-RNG territory, not a side error -> never flip.
            -- (v2.9: logs showed 4-13% HC misses churning the forced side.)
            lowhc_keep = true
        elseif cur_hits == 0 or opp_hits > cur_hits then
            -- unproven/weaker side. Only a FRESH (low-BT) miss is real side evidence -> flip to search
            -- the other side + 2D magnitude search after a full L/R cycle. A stale/high-BT or
            -- Extrapolation unproven miss is NETCODE, not a wrong side -> keep and wait (SideMemory /
            -- lean seed stays). v2.9: this branch used to flip on BT 14-21 stale records = pure churn.
            if fresh then
                rs.side = -cur
                rs.unproven_miss = (rs.unproven_miss or 0) + 1
                if ui.get(Menu["Magnitude Search"]) and rs.unproven_miss >= 4 and rs.unproven_miss % 2 == 0 then
                    mag_probe(rs)   -- both sides exhausted at this mag -> next desync value
                end
                flipped = true
            else
                rs.unproven_miss = 0
                netcode_keep = true
            end
        elseif fresh then
            -- proven side + FRESH miss. Two ways it's really the wrong side: 2 fresh misses in a row,
            -- OR (only on a non-jitter enemy) the live feet-lean sign disagrees with the side we
            -- forced -> two independent signals agree, flip on the first miss. Otherwise the side is
            -- probably right and the MAGNITUDE is off -> probe the ladder before blaming the side.
            local lean = rs.last_adiff or 0
            local lean_disagrees = (not rs.jitter) and math.abs(lean) > 15 and ((lean > 0) ~= (cur > 0))
            rs.side_miss = (rs.side_miss or 0) + 1
            if rs.side_miss >= 2 or lean_disagrees then
                rs.side = -cur
                rs.side_miss = 0
                rs.mag_bias, rs.mag_step = nil, nil
                if cur < 0 then rs.hits_l = math.floor(rs.hits_l * 0.5)
                else rs.hits_r = math.floor(rs.hits_r * 0.5) end
                flipped = true
            else
                kept_proven = true
                -- On a JITTER enemy the miss is the switching SIDE, not the magnitude -> probing mag
                -- would just fire wrong values; hold side and let side_miss reach the flip threshold.
                if not rs.jitter and ui.get(Menu["Magnitude Search"]) then
                    mag_probe(rs)   -- stable enemy: side likely right, magnitude likely wrong -> next desync value
                end
            end
        else
            -- proven side + stale record / extrapolation -> netcode, keep (don't oscillate)
            netcode_keep = true
        end
    end

    -- Session tally by outcome (netcode-vs-resolver ratio, shown in the debug STATS line)
    if flipped then Stats.flip = Stats.flip + 1
    elseif lowhc_keep then Stats.lowhc = Stats.lowhc + 1
    elseif kept_proven then Stats.kept = Stats.kept + 1
    elseif netcode_keep then Stats.netcode = Stats.netcode + 1
    elseif shot.reason == "spread" then Stats.spread = Stats.spread + 1
    elseif shot.reason == "death" then Stats.ping = Stats.ping + 1
    elseif shot.reason == "unregistered shot" then Stats.unreg = Stats.unreg + 1 end

    print(string.format("Missed %s`s %s due to %s | Desync: %i | BT: %i",entity.get_player_name(shot.target),group,reasons[shot.reason] or shot.reason or "?",plist.get(shot.target,"Force body yaw value") or 0,globals.tickcount() - shot.tick) )

    if ui.get(Menu["Debug Logs"]) then
        local si = ShotInfo[shot.id]
        local want = si and group_name(si.want_group) or "?"
        local dl = rs and rs.hits_l or 0
        local dr = rs and rs.hits_r or 0
        local lean = rs and rs.last_adiff or 0
        client.color_log(255, 110, 110, string.format(
            "[RESOLVER MISS] %s | reason=%s wanted=%s wouldhit=%s | forced=%s mag=%.1f hc=%s%% | dom L%d/R%d lean=%.0f jit=%d lby=%d | miss#%d BT=%d",
            entity.get_player_name(shot.target) or "?", reasons[shot.reason] or shot.reason or "?",
            want, group, side_name(old_side), si and si.mag or 0,
            si and tostring(si.hitchance) or "?", dl, dr, lean, (rs and rs.jitter) and 1 or 0,
            (rs and rs.lby) and 1 or 0,
            rs and rs.miss or 0, globals.tickcount() - (shot.tick or globals.tickcount())))
        -- Netcode-vs-resolver ratio for the whole session: flips = our real faults, the rest we
        -- correctly kept. If flips stay low while netcode/ping/spread pile up, side logic is fine.
        client.color_log(150, 150, 150, string.format(
            "   [STATS] hits=%d | flip=%d kept=%d netcode=%d lowhc=%d spread=%d ping=%d unreg=%d",
            Stats.hits, Stats.flip, Stats.kept, Stats.netcode, Stats.lowhc, Stats.spread, Stats.ping, Stats.unreg))
        if flipped then
            client.color_log(255, 200, 80, string.format(
                "   ^ FRESH miss (BT=%d) likely WRONG SIDE (%s) -> flipping to %s", bt, side_name(old_side), side_name(rs and rs.side or 0)))
        elseif lowhc_keep then
            client.color_log(180, 180, 180, string.format(
                "   ^ low hitchance gamble (%s%% < %d) -> side kept, not a resolver fault",
                si and tostring(si.hitchance) or "?", LOW_HC))
        elseif netcode_keep and (rs and (rs.hits_l == 0 and rs.hits_r == 0)) then
            client.color_log(120, 200, 255, string.format(
                "   ^ unproven side + stale record (BT=%d) -> KEPT, waiting for a fresh miss (netcode, not a side error)", bt))
        elseif kept_proven then
            local ch = (old_side < 0) and (rs and rs.hits_l or 0) or (rs and rs.hits_r or 0)
            if rs and rs.jitter then
                client.color_log(120, 200, 255, string.format(
                    "   ^ %s proven (%d hits) -> KEPT side (jitter enemy, holding for switch, BT=%d)",
                    side_name(old_side), ch, bt))
            else
                client.color_log(120, 200, 255, string.format(
                    "   ^ %s proven (%d hits) -> KEPT side, probing magnitude=%.0f (BT=%d)",
                    side_name(old_side), ch, rs and rs.mag_bias or 0, bt))
            end
        elseif netcode_keep then
            client.color_log(120, 200, 255, string.format(
                "   ^ STALE RECORD (BT=%d) / extrapolation -> KEPT side (backtrack/interp issue, not resolver)", bt))
        elseif shot.reason == "spread" then
            client.color_log(180, 180, 180, "   ^ spread (bullet RNG) -> side kept, not a resolver fault")
        elseif shot.reason == "unregistered shot" then
            client.color_log(180, 180, 180, "   ^ unregistered shot (server rejected the hit) -> side kept, not a resolver fault")
        end
    end
    ShotInfo[shot.id] = nil
end
local function animation_fix()
    if not ui.get(Menu["Enable Resolver"]) then return end
    local players = entity.get_players(true)
    for i = 1, #players do
        local player = players[i]
        if entity.is_alive(player) then
            local anim_state = entity.get_prop(player, "m_flPoseParameter[0]")
            if anim_state then
                entity.set_prop(player, "m_flPoseParameter[0]", anim_state + 0.01)
                entity.set_prop(player, "m_flPoseParameter[0]", anim_state)
            end
        end
    end
end

local target_paint = function()
    local threat = client.current_threat()
    if not threat then return end
    renderer.indicator(255,255, 255,255, "Target: " .. (entity.get_player_name(threat) or "?") )
end

client.set_event_callback("paint", function()
    target_paint()
end)
client.set_event_callback("aim_fire", function(e)
    local rs = ResolveState[e.target]
    ShotInfo[e.id] = {
        target = e.target,
        want_group = e.hitgroup,
        hitchance = e.hitchance or e.hit_chance,
        side = rs and (rs.last_side or rs.side) or 0,
        mag = rs and (rs.last_mag or 0) or 0,
    }
end)
client.set_event_callback("aim_hit", hit_logs)
client.set_event_callback("aim_miss", miss_logs)
client.set_event_callback("net_update_start", function()
    -- animation_fix() DISABLED: it wrote enemy m_flPoseParameter every tick, a prime suspect for
    -- the Extrapolation miss flood (corrupts enemy anim/backtrack records). Re-enable to A/B test.
    Resolver:Animlayer()
    Resolver:Prediction()
end)

-- Load banner: prints the running version so we always know the fresh copy is loaded
client.color_log(120, 200, 255, "[Resolverown] loaded  |  version " .. RESOLVER_VERSION .. "  |  BT-aware side (unproven too) + mag search + jitter/LBY + interp floor + low-hc guard")

