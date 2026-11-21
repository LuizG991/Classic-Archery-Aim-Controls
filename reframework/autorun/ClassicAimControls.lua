-- ClassicAimControls.lua  (v4.13.1)
-- Dragon's Dogma 2 | REFramework
-- Archer and Magick Archer (and the Warfarer, only while a bow / magick bow is the equipped weapon):
--   Hold LT        = aim (the game already does this)
--   RT (while aim) = shoot, and keep aiming as long as LT is held
--   Release LT     = cancel the aim WITHOUT shooting
--                    (aim ready: sends ActCancel before releasing)
--
-- Works on the game's input layer (app.UserInput).
-- Mapping found in the game's pad assign:
--   LT = AimHold + ShootRelease + ThrowRelease + JobSpecialAction
--        + GimmickAction + Shift1OnlySpecificJob
--   RT = Grab, RB = ActCancel, X = AttackS, Y = AttackL
-- In the vanilla game, releasing LT shoots (ShootRelease). This mod splits that:
-- RT shoots, releasing LT cancels.
--
-- Shooting uses the vanilla "release to shoot" action (ShootRelease), sent as a short pulse
-- while AimHold stays on. The shot is held back while the bow is busy (preparing a skill arrow,
-- shooting, cancelling) and sent as soon as the game can accept it. If the game ignores it,
-- the mod tries again (the second try releases the whole aim, exactly like letting go of LT).
-- Piercing Dart (PrepareFullBend) is a held state with no "ready" node, so it can be shot at any time.
--
-- Fire trigger: the action your RT is bound to (Grab by default, AttackS if you rebound it).
-- "Auto" accepts Grab, AttackS and AttackL. The trigger is hidden from the game while aiming.
--
-- Warfarer (v4.6): the Warfarer is CurrentJob 10. The vocation of the weapon in hand is read from
-- Human.Chara.WeaponJob (the same field Enhanced Warfarer Vocation uses), with the Arisen weapon list
-- as a fallback. The mod is only active when that weapon vocation is Archer (2) or Magick Archer (8),
-- so every other weapon keeps the vanilla controls.
--
-- Channeled skills (v4.7): Cloudburst Shot (HeavyRain) and Cataract Shot (RandomShot) keep shooting
-- while you press and release the aim again (in the vanilla game: LT down, LT up, LT down, LT up...).
-- For these skills every RT press is a full "release the aim", followed a few frames later by a new
-- "press the aim", so each RT press is one more volley / arrow, exactly like tapping LT in vanilla.
-- Cataract Shot can be shot while it is still preparing (like vanilla), with no minimum.
-- Cloudburst Shot needs the aim held for a while before each release. Two independent timers:
--   first volley   = 2.6 s after the skill was activated   (cloud_first)
--   later volleys  = 2.5 s after the previous volley        (cloud_charge)
-- Either one can be lowered freely: the first timer is not limited by the second one.
-- RT presses before the timer ends are ignored (no queue), so spamming RT never ends the skill early.
-- To add another skill that behaves this way, add a piece of its node name to CHANNEL_SKILLS.
--
-- Throwing objects uses the same controls as the bow: while you carry an object, LT aims the throw,
-- RT throws it (the mod sends the game's own throw input: the whole aim is released) and releasing
-- LT cancels the aim without throwing.
--
-- Settings can be saved with the "Save settings" button (REFramework menu > Settings). They are
-- stored in <game folder>/reframework/data/ClassicAimControls/config.json and loaded on startup.
-- "Enabled", "Show debug" and "Record trace" are never saved.
--
-- Game controls: the "Apply classic aim controls" button (Recommended game controls) edits the game's
-- gamepad bindings in memory: Vocation Action = LT, Cancel = RB, Light Attack = RT, Grab = X.
-- Optionally it is applied automatically every time the game starts.
--
-- Install: <game folder>/reframework/autorun/ClassicAimControls.lua

local NAME, VERSION = "ClassicAimControls", "4.13.1"

local CFG = {
    enabled       = true,
    only_jobs     = true,    -- Archer (2) and Magick Archer (8) only
    warfarer      = true,    -- Warfarer (10): also active, but only with a bow / magick bow equipped
    reaim         = true,    -- aim again after a shot if the game leaves the aim
    actcancel     = true,    -- cancel a ready aim by sending ActCancel (RB action)
    ready_frames  = 0,       -- aim frames until the bow counts as ready (0 = always ready)
    buffer_frames = 0,       -- an RT press that comes too early is kept for this long (0 = off)
    act_frames    = 3,       -- frames holding ActCancel
    trigger       = 1,       -- 1 = Auto (Grab/AttackS/AttackL) | 2 = Grab | 3 = AttackS | 4 = AttackL
    cloud_first   = 2.6,     -- Cloudburst Shot: seconds from the skill activation to the first volley
    cloud_charge  = 2.5,     -- Cloudburst Shot: seconds from one volley to the next (independent of cloud_first)
    apply_on_start = false,  -- apply the classic aim controls (LT / RB / RT / X) automatically on startup
    debug         = false,
    trace         = false,
}
local JOBS = { [2] = true, [8] = true }

-- Saved settings
local CONFIG_PATH = NAME .. "/config.json"
local NOT_SAVED = { enabled = true, debug = true, trace = true }

local function load_config()
    local ok, data = pcall(json.load_file, CONFIG_PATH)
    if not (ok and type(data) == "table") then return end
    for k, v in pairs(data) do
        if CFG[k] ~= nil and not NOT_SAVED[k] and type(v) == type(CFG[k]) then CFG[k] = v end
    end
end

local function save_config()
    local data = {}
    for k, v in pairs(CFG) do
        if not NOT_SAVED[k] then data[k] = v end
    end
    return (pcall(json.dump_file, CONFIG_PATH, data))
end

load_config()
local WARFARER = 10

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function Get(Obj, Field)
    if not Obj then return nil end
    local Ok, V = pcall(Obj.get_field, Obj, Field)
    if Ok then return V end
    return nil
end

local function Set(Obj, Field, Value)
    if not Obj then return false end
    return (pcall(Obj.set_field, Obj, Field, Value))
end

local function Call(Obj, Sig, ...)
    if not Obj then return nil end
    local Ok, V = pcall(Obj.call, Obj, Sig, ...)
    if Ok then return V end
    return nil
end

local function Addr(Obj)
    if not Obj then return nil end
    local Ok, A = pcall(Obj.get_address, Obj)
    return Ok and A or nil
end

local function Str(V)
    if V == nil or type(V) == "string" then return V end
    local Ok, S = pcall(V.call, V, "ToString()")
    if Ok and type(S) == "string" then return S end
    return tostring(V)
end

local function Safe(F, ...)
    local Ok, Err = pcall(F, ...)
    if not Ok then log.debug("[" .. NAME .. "] " .. tostring(Err)) end
end

------------------------------------------------------------------------
-- Input flags (app.CharacterInput.Flag)
------------------------------------------------------------------------
local FL, FLAG_LIST = {}, {}
do
    local td = sdk.find_type_definition("app.CharacterInput.Flag")
    if td then
        for _, f in ipairs(td:get_fields()) do
            if f:is_static() then
                local ok, v = pcall(function() return f:get_data(nil) end)
                if ok and type(v) == "number" then
                    FL[f:get_name()] = v
                    FLAG_LIST[#FLAG_LIST + 1] = { name = f:get_name(), value = v }
                end
            end
        end
    end
end

local AIM, SHOOT, THROW, GRAB, ACTC = FL.AimHold, FL.ShootRelease, FL.ThrowRelease, FL.Grab, FL.ActCancel
local ATKS, ATKL = FL.AttackS or 0, FL.AttackL or 0
local READY = (AIM and SHOOT and THROW and GRAB and ACTC and FL.GimmickAction
    and FL.JobSpecialAction and FL.Shift1OnlySpecificJob) and true or false

local TRIG_BITS = { (GRAB or 0) | ATKS | ATKL, GRAB or 0, ATKS, ATKL }

-- GROUP = every flag the game raises together when LT is pressed
-- M     = every flag this mod may read and rewrite
local GROUP, M = 0, 0
if READY then
    GROUP = AIM | FL.GimmickAction | FL.JobSpecialAction | FL.Shift1OnlySpecificJob | SHOOT | THROW
    M = GROUP | GRAB | ACTC | ATKS | ATKL
else
    log.error("[" .. NAME .. "] input flags not found; mod disabled")
end

local function flag_names(mask)
    if type(mask) ~= "number" or mask == 0 then return "-" end
    local out = {}
    for _, e in ipairs(FLAG_LIST) do
        local v = e.value
        local ok, hit = pcall(function() return v ~= 0 and (v & (v - 1)) == 0 and (mask & v) ~= 0 end)
        if ok and hit then out[#out + 1] = e.name end
    end
    table.sort(out)
    return #out > 0 and table.concat(out, "+") or string.format("0x%X", mask)
end

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local S = {
    frame = 0, Player = nil, Input = nil, InputAddr = nil,
    n0 = nil, n1 = nil, job = nil, job_frame = -999, job_diag = "?",
    cur_job = nil, weapon_job = nil, wf_diag = "-",
    realOn = 0, outOn = 0,
    state = "idle", fired_at = -1000, fire_phase = 0, reaim_step = 0,
    aim_since = 0, buffer_until = -1, cancel_at = 0, fire_node = nil, fire_changed = false, retries = 0, hard = false, chan = false, gap = 1, chan_charge = 0, next_ok = 0, queue_until = 0,
    in_chan = false,
    ctrl_msg = nil, ctrl_done = false, ctrl_tries = 0,
    shots = 0, cancels = 0,
    last_out = 0, last_trig = 0, last_rel = 0,
}

local Trace = {}
local function push(Ev)
    if not CFG.trace then return end
    Trace[#Trace + 1] = Ev
    if #Trace > 2000 then table.remove(Trace, 1) end
end

-- Warfarer: vocation (1..9) of the weapon in hand. Returns job, source (or nil, reason).
local function read_weapon_job(ply, hum)
    -- 1) Human.Chara.WeaponJob (what Enhanced Warfarer Vocation reads)
    local chara = nil
    pcall(function() chara = hum:get_Chara() end)
    if chara then
        local wj = nil
        pcall(function() wj = sdk.to_int64(chara.WeaponJob) end)
        if type(wj) == "number" and wj >= 1 and wj <= 9 then return wj, "Chara.WeaponJob" end
    end
    -- 2) fallback: the current Arisen weapon, from the equipment data
    local found = nil
    pcall(function()
        local im = sdk.get_managed_singleton("app.ItemManager")
        local eq = im and im:getEquipData(ply:get_CharaID())
        if not eq then return end
        local data = eq:get_field("Data")
        local idx = data and data:get_field("<CurrentArisenWeaponIndex>k__BackingField")
        local list = eq:get_ArisenWeaponList()
        if type(idx) ~= "number" or not list then return end
        for i = 0, list:get_size() - 1 do
            local e = list:get_element(i)
            for k = 1, 2 do
                local w = (k == 1) and e.Main or e.Sub
                if w then
                    local ep, wp = w:call("get_EquipParam()"), w:call("get_WeaponParam()")
                    if ep and wp then
                        if w:call("get_ArisenEquipNo()") == idx + 1 then found = tonumber(ep:call("getJob()")) end
                        break
                    end
                end
            end
            if found then return end
        end
    end)
    if found and found >= 1 and found <= 9 then return found, "EquipData" end
    return nil, "unknown"
end

-- Returns the "effective" vocation: the player's vocation, or for the Warfarer the vocation of the weapon
-- in hand. Also fills S.cur_job / S.weapon_job for the debug panel.
local function read_job()
    local steps = {}
    local function try(label, fn)
        local ok, v = pcall(fn)
        steps[#steps + 1] = label .. ":" .. ((ok and v ~= nil) and "ok" or (ok and "nil" or "error"))
        if ok then return v end
        return nil
    end
    local cm  = try("CharMgr", function() return sdk.get_managed_singleton("app.CharacterManager") end)
    local ply = cm and try("Player", function() return cm:call("get_ManualPlayer") end)
    local hum = ply and try("Human", function() return ply:call("get_Human") end)
    local ctx = hum and (try("JobContext", function() return hum:call("get_JobContext") end)
        or try("JobContext.f", function() return hum:get_field("<JobContext>k__BackingField") end))
    local job = ctx and (try("CurrentJob", function() return ctx:get_field("CurrentJob") end)
        or try("CurrentJob.get", function() return ctx:call("get_CurrentJob") end))
    S.job_diag = table.concat(steps, " | ")
    S.cur_job = (type(job) == "number") and job or nil
    S.weapon_job, S.wf_diag = nil, "-"
    if S.cur_job == WARFARER then
        if not CFG.warfarer then S.wf_diag = "Warfarer support off"; return nil end
        local wj, how = read_weapon_job(ply, hum)
        S.weapon_job, S.wf_diag = wj, how
        return wj
    end
    return S.cur_job
end

local function is_active()
    if not (CFG.enabled and READY) then return false end
    if not CFG.only_jobs then return true end
    -- the Warfarer can swap weapons at any time, so re-check more often there
    local gap = (S.cur_job == WARFARER) and 10 or 30
    if S.frame - S.job_frame > gap then S.job, S.job_frame = read_job(), S.frame end
    return S.job ~= nil and JOBS[S.job] == true
end

local function node_name(Player, layer)
    return Str(Call(Get(Get(Player, "<ActionManager>k__BackingField"), "Fsm"),
        "getCurrentNodeName(System.UInt32)", layer))
end

------------------------------------------------------------------------
-- Writing flags (keeps On/Trig/Rel/Old consistent, like WarriorAutoCombo)
------------------------------------------------------------------------
local function ReadFlags(Input)
    local On, Trig = Get(Input, "ButtonOnFlags"), Get(Input, "ButtonTriggerFlags")
    local Rel, Old = Get(Input, "ButtonReleaseFlags"), Get(Input, "OldButtonOnFlags")
    if type(On) ~= "number" or type(Trig) ~= "number" or type(Rel) ~= "number" or type(Old) ~= "number" then
        return nil
    end
    return On, Trig, Rel, Old
end

local function write(Input, On, Trig, Rel, Old, out, trig, rel)
    Old = (Old & ~M) | S.outOn           -- what we exposed on the previous frame
    S.outOn = out
    Set(Input, "OldButtonOnFlags",   Old)
    Set(Input, "ButtonOnFlags",      (On & ~M) | out)
    Set(Input, "ButtonTriggerFlags", (Trig & ~M) | trig)
    Set(Input, "ButtonReleaseFlags", (Rel & ~M) | rel)
end

------------------------------------------------------------------------
-- Main logic (once per frame, after the game updates the player's input)
------------------------------------------------------------------------
-- The bow can only accept a shot when it is not shooting, cancelling, or still preparing a skill
-- arrow (those go Prepare -> Ready). Piercing Dart ("PrepareFullBend") stays in its prepare node
-- until it is shot, so it is always shootable.
local function now() return os.clock() end

-- Skills that keep shooting while the aim is pressed and released again.
--   shoot_prep: it can be shot while the "Prepare" node is still active (vanilla allows it)
--   first:      CFG key with the seconds from the skill activation to the first volley (nil = none)
--   charge:     CFG key with the seconds between the following volleys (nil = none)
--   queue:      remember one RT press that came too early (false = ignore it)
local CHANNEL_SKILLS = {
    { name = "HeavyRain",  shoot_prep = false, first = "cloud_first", charge = "cloud_charge", queue = false },  -- Cloudburst Shot
    { name = "RandomShot", shoot_prep = true,  first = nil,           charge = nil,            queue = true  },  -- Cataract Shot
}
local CH_GAP = 3                                        -- frames the aim stays released between volleys

local function channel_of(n1)
    for _, c in ipairs(CHANNEL_SKILLS) do
        if n1:find(c.name, 1, true) then return c end
    end
    return nil
end

local function is_channel(n1) return channel_of(n1) ~= nil end

local function can_shoot(n1)
    if n1:find("Cancel", 1, true) then return false end
    if n1:sub(1, 6) == "Catch." or n1:find("Carry", 1, true) then
        -- carrying an object or a creature: it can be thrown only while the throw aim node is active.
        -- Aim nodes seen so far end in "Aim": Catch.Carry_Root.CarryAim,
        -- Locomotion.CarryObject.CarryObjectAim, Catch.CarrySmallAnimal_Root.CarrySmallAnimalAim.
        -- Not "...AimEnd" (aim ending) and not "...Wait".
        return n1:sub(-3) == "Aim"
    end
    local ch = channel_of(n1)
    if ch then
        if n1:find("Finish", 1, true) then return false end
        if n1:find("Prepare", 1, true) then
            return ch.shoot_prep == true
        end
        return true                      -- "Shoot" nodes accept more volleys
    end
    if n1:find("Shoot", 1, true) then return false end
    if n1:find("PrepareSpecialArrow", 1, true) then return false end
    return true
end

-- Carrying an object or creature: nodes like "Catch.Carry_Root.CarryAim", "Locomotion.CarryObject.CarryObjectAim"
-- and "Catch.CarrySmallAnimal_Root.CarrySmallAnimalAim" (aiming the throw), "...AimEnd" (aim ending).
local function is_carrying(n0, n1)
    return n1:find("Carry", 1, true) ~= nil or n1:sub(1, 6) == "Catch."
        or n0:find("Carry", 1, true) ~= nil or n0:sub(1, 6) == "Catch."
end

local function process(Input)
    local On, Trig, Rel, Old = ReadFlags(Input)
    if not On then return end

    local realOn = On & M
    S.realOn = realOn

    if not is_active() then
        if S.outOn ~= realOn then write(Input, On, Trig, Rel, Old, realOn, Trig & M, Rel & M) end
        S.outOn = realOn
        S.state, S.reaim_step = "idle", 0
        return
    end

    local out, trig, rel = realOn, Trig & M, Rel & M
    local lt_held = (realOn & AIM) ~= 0
    local lt_rel  = (Rel & AIM) ~= 0
    local TB = TRIG_BITS[CFG.trigger] or TRIG_BITS[1]
    local rt_trig = (Trig & TB) ~= 0
    local touched = false
    local prev_state = S.state
    local n1 = S.n1 or ""
    local ready = (S.frame - S.aim_since) >= CFG.ready_frames
    local shootable = can_shoot(n1)
    local t = now()
    local chnode = channel_of(n1)
    if chnode then
        if not S.in_chan then                -- a channeled skill was just activated
            S.in_chan, S.queue_until = true, 0
            S.next_ok = (chnode.first and (t + CFG[chnode.first])) or 0
        end
        if chnode.queue and rt_trig then S.queue_until = t + 2.0 end   -- Cataract: remember one RT press
    else
        S.in_chan, S.next_ok, S.queue_until = false, 0, 0
    end

    -- While aiming, the RT action (Grab / AttackS / AttackL) must not reach the game
    if lt_held or S.state ~= "idle" then
        if ((out | trig | rel) & TB) ~= 0 then touched = true end
        out, trig, rel = out & ~TB, trig & ~TB, rel & ~TB
    end

    local function fire()
        local ch = channel_of(n1)
        local carry = is_carrying("", n1)    -- carrying an object: RT throws it
        S.chan, S.gap = ch ~= nil, (ch or carry) and CH_GAP or 1
        S.chan_charge = (ch and ch.charge and CFG[ch.charge]) or 0
        -- The full release (like letting go of LT) is only used for channeled skills and as the second
        -- attempt of Piercing Dart (FullBend). A normal shot that the game ignores is simply dropped.
        S.hard = ch ~= nil or carry or (S.retries >= 1 and n1:find("FullBend", 1, true) ~= nil)
        if S.hard then                       -- retry: release the whole aim, like letting go of LT
            out = out & ~GROUP
            rel = rel | GROUP
        else                                 -- first try: ShootRelease pulse, AimHold stays on
            out = out & ~SHOOT
            rel = rel | SHOOT
        end
        touched = true
        S.fire_node, S.fire_changed = n1, false
        S.buffer_until, S.queue_until = -1, 0
        S.state, S.fired_at, S.fire_phase = "fired", S.frame, 1
        S.shots = S.shots + 1
    end

    local function release_vanilla()         -- release LT without ShootRelease
        if lt_rel then rel = rel & ~SHOOT; touched = true end
        S.cancels = S.cancels + 1
        S.state = "idle"
    end

    if S.state == "idle" and lt_held then
        S.state, S.aim_since, S.buffer_until = "aim", S.frame, -1
    end

    if S.state == "aim" then
        if not lt_held then
            if CFG.actcancel and ready then
                S.state, S.cancel_at = "cancel", S.frame
                S.cancels = S.cancels + 1
            else
                release_vanilla()            -- aim not ready: the game cancels by itself
            end
        else
            if rt_trig then S.buffer_until, S.retries = S.frame + CFG.buffer_frames, 0 end
            if (S.frame <= S.buffer_until or t <= S.queue_until) and ready and shootable and t >= S.next_ok then
                fire()
            end
        end
    elseif S.state == "fired" then
        if not lt_held then
            if S.chan and CFG.actcancel then     -- channeled skill: cancel it cleanly
                S.state, S.cancel_at = "cancel", S.frame
                S.cancels = S.cancels + 1
            else
                release_vanilla()
            end
        else
            local k = S.frame - S.fired_at
            if n1 ~= S.fire_node then S.fire_changed = true end   -- the game reacted: the shot was accepted
            if S.fire_phase == 1 then        -- the released flag(s) go back to "pressed"
                if S.hard and k < S.gap then -- keep the aim released for a few frames
                    out = out & ~GROUP
                    touched = true
                else
                    trig = trig | (S.hard and GROUP or SHOOT)
                    touched = true
                    S.fire_phase = 2
                    if S.chan_charge > 0 then S.next_ok = t + S.chan_charge end   -- charge starts now
                end
            end
            if rt_trig then S.buffer_until, S.retries = S.frame + CFG.buffer_frames, 0 end
            if S.chan and S.fire_phase == 2 and (S.frame <= S.buffer_until or t <= S.queue_until)
               and shootable and t >= S.next_ok then
                fire()                       -- channeled skill: every RT press is one more volley
            end
            local waited = S.frame - S.fired_at
            local aimish = n1:find("RestartAim", 1, true) or n1:find("StartAim", 1, true)
                        or n1:find("Ready", 1, true)
            local function back_to_aim()
                -- Piercing Dart only: if the node never changed since the shot, the game ignored it: try again
                if not S.fire_changed and S.retries < 2 and (S.fire_node or ""):find("FullBend", 1, true) then
                    S.retries = S.retries + 1
                    S.buffer_until = math.max(S.buffer_until, S.frame + 20)
                end
                S.state, S.aim_since = "aim", S.frame
            end
            if waited >= 3 and aimish then
                back_to_aim()                -- the game is aiming again (or never left the aim)
            elseif CFG.reaim and waited >= 10
                   and (n1:find("Cancel", 1, true) or n1:find("UpperBodyDefault", 1, true)) then
                S.state, S.reaim_step = "reaim", 1
            elseif waited >= 20 and shootable and not (S.chan and is_channel(n1)) then
                back_to_aim()
            elseif waited > 200 then
                S.state, S.aim_since = "aim", S.frame
            end
        end
    end

    if S.state == "reaim" then
        if not lt_held then
            release_vanilla()
        elseif S.reaim_step == 1 then        -- frame 1: release the aim (no shot)
            out = out & ~GROUP
            rel = rel | (GROUP & ~(SHOOT | THROW))
            touched = true
            S.reaim_step = 2
        else                                 -- frame 2: press it again
            trig = trig | GROUP
            touched = true
            S.state, S.reaim_step, S.aim_since = "aim", 0, S.frame
        end
    end

    if S.state == "cancel" then
        -- LT is already released, but the game keeps "seeing" the aim as held while ActCancel acts
        local since = S.frame - S.cancel_at
        out  = out | GROUP
        rel  = rel & ~GROUP
        trig = trig & ~GROUP
        touched = true
        if since < CFG.act_frames then
            out = out | ACTC
            if since == 0 then trig = trig | ACTC end
        elseif since == CFG.act_frames then
            out = out & ~ACTC
            rel = rel | ACTC
        end
        local done = since > CFG.act_frames
            and (n1:find("Cancel", 1, true) or n1:find("AimEnd", 1, true) or n1:sub(1, 10) == "Locomotion")
        if done or since > 90 then
            if lt_held then                  -- the player pressed LT again
                S.state, S.reaim_step = "reaim", 1
            else                             -- release the aim silently
                out = out & ~GROUP
                rel = rel | (GROUP & ~(SHOOT | THROW))
                S.state = "idle"
            end
        end
    end

    if touched or S.outOn ~= out then write(Input, On, Trig, Rel, Old, out, trig, rel) end

    S.last_out, S.last_trig, S.last_rel = out, trig, rel
    if CFG.trace and (touched or S.state ~= prev_state) then
        push({ f = S.frame, st = S.state, ready = ready, can = shootable, chan = S.chan, n1 = S.n1, real = flag_names(realOn),
               out = flag_names(out), trig = flag_names(trig), rel = flag_names(rel) })
    end
end

------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------
local PendingInput = nil
local td_ui = sdk.find_type_definition("app.UserInput")
local m_update = td_ui and td_ui:get_method("update(System.Boolean, System.Boolean)")
if m_update then
    sdk.hook(m_update,
        function(Args)
            PendingInput = nil
            if not S.InputAddr or sdk.to_int64(Args[2]) ~= S.InputAddr then return end
            PendingInput = S.Input
            -- give the game the REAL state of the managed bits so it computes edges correctly
            if READY and S.outOn ~= S.realOn then
                local On = Get(S.Input, "ButtonOnFlags")
                if type(On) == "number" then Set(S.Input, "ButtonOnFlags", (On & ~M) | S.realOn) end
            end
        end,
        function(Ret)
            local Input = PendingInput
            PendingInput = nil
            if Input and READY then Safe(process, Input) end
            return Ret
        end)
else
    log.error("[" .. NAME .. "] app.UserInput.update not found")
end

------------------------------------------------------------------------
-- Game controls (the game's gamepad assign)
------------------------------------------------------------------------
local function enum_map(typename)
    local t = {}
    local td = sdk.find_type_definition(typename)
    if td then
        for _, f in ipairs(td:get_fields()) do
            if f:is_static() then
                local ok, v = pcall(function() return f:get_data(nil) end)
                if ok and type(v) == "number" then t[f:get_name()] = v end
            end
        end
    end
    return t
end

local ACTION_ID = enum_map("app.CharacterInput.Action")
local PAD_BTN   = enum_map("via.hid.GamePadButton")

-- game action (app.CharacterInput.Action) -> gamepad button (via.hid.GamePadButton)
local CONTROL_LAYOUT = {
    -- Vocation Action = LT (the game raises all of these together from the LT button)
    JobSpecialAction = "LTrigBottom", AimHold = "LTrigBottom", ShootRelease = "LTrigBottom",
    ThrowRelease = "LTrigBottom", GimmickAction = "LTrigBottom", Shift1OnlySpecificJob = "LTrigBottom",
    -- Cancel = RB
    ActCancel = "RTrigTop",
    -- Light Attack = RT
    AttackS = "RTrigBottom",
    -- Grab = X
    Grab = "RLeft",
}

-- Returns the number of entries changed and an optional note
local function apply_controls()
    local target, missing = {}, {}
    for action, button in pairs(CONTROL_LAYOUT) do
        local aid, bid = ACTION_ID[action], PAD_BTN[button]
        if aid and bid then target[aid] = bid else missing[#missing + 1] = action end
    end
    local note = (#missing > 0) and ("Unknown actions: " .. table.concat(missing, ", ")) or nil

    local manager = sdk.get_managed_singleton("app.UserInputManager")
    local assign = manager and Call(manager, "getCurrentCharacterPadAssign")
    local list = Get(assign, "AssignList")
    if not list then return 0, "pad assign not found" end

    local patched = 0
    local function patch(item, index)
        local btn = target[Get(item, "Action")]
        if btn and Set(item, "Button", btn) then
            if index then Call(list, "set_Item", index, item) end   -- write back (items may be copies)
            patched = patched + 1
        end
    end

    local count = Call(list, "get_Count")
    if type(count) == "number" then
        for i = 0, count - 1 do
            local item = Call(list, "get_Item", i)
            if item then patch(item, i) end
        end
    else
        local ok, elements = pcall(function() return list:get_elements() end)
        if ok and elements then
            for _, item in pairs(elements) do patch(item, nil) end
        end
    end
    return patched, note
end

-- Runs apply_controls and stores a message for the menu; returns the number of entries changed
local function apply_controls_ui()
    local ok, n, note = pcall(apply_controls)
    if not ok then
        S.ctrl_msg = "Could not apply the controls: " .. tostring(n)
        return 0
    end
    if n == 0 then
        S.ctrl_msg = "Could not apply the controls (" .. tostring(note or "no matching entries") .. ")."
    else
        S.ctrl_msg = string.format("Controls applied (%d entries).%s", n, note and (" " .. note) or "")
    end
    return n
end

re.on_frame(function()
    S.frame = S.frame + 1
    S.Player = Call(sdk.get_managed_singleton("app.CharacterManager"), "get_ManualPlayer()")
    S.Input = Get(S.Player, "<Input>k__BackingField")
    S.InputAddr = Addr(S.Input)
    S.n0 = node_name(S.Player, 0)
    S.n1 = node_name(S.Player, 1)

    if CFG.apply_on_start and not S.ctrl_done and S.frame >= 120 and S.frame % 60 == 0 then
        S.ctrl_tries = S.ctrl_tries + 1
        if apply_controls_ui() > 0 or S.ctrl_tries >= 10 then S.ctrl_done = true end
    end
end)

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local TRIGGER_OPTS = { "Auto (Grab / AttackS / AttackL)", "Grab", "AttackS", "AttackL" }

re.on_draw_ui(function()
    if not imgui.tree_node(NAME .. " v" .. VERSION) then return end
    local _
    _, CFG.enabled = imgui.checkbox("Enabled", CFG.enabled)
    if not READY then imgui.text("Input flags not found: mod disabled") end

    if imgui.tree_node("Recommended game controls##" .. NAME) then
        imgui.text("Vocation Action = LT, Cancel = RB, Light Attack = RT, Grab = X")
        if imgui.button("Apply classic aim controls##" .. NAME) then apply_controls_ui() end
        _, CFG.apply_on_start = imgui.checkbox("Apply automatically on startup", CFG.apply_on_start)
        imgui.text('(click "Save settings", inside Settings, to keep this option)')
        if S.ctrl_msg then imgui.text(S.ctrl_msg) end
        imgui.tree_pop()
    end

    if imgui.tree_node("Settings##" .. NAME) then
        if imgui.button("Save settings##" .. NAME) then
            S.save_msg = save_config() and "Settings saved." or "Could not save the settings."
            S.save_t = now()
        end
        if S.save_msg and now() - (S.save_t or 0) < 4 then
            imgui.same_line()
            imgui.text(S.save_msg)
        end
        _, CFG.only_jobs     = imgui.checkbox("Archer / Magick Archer only (bow equipped)", CFG.only_jobs)
        _, CFG.warfarer      = imgui.checkbox("Also work as Warfarer (only with a bow / magick bow equipped)", CFG.warfarer)
        _, CFG.reaim         = imgui.checkbox("Aim again after the shot (if the game leaves the aim)", CFG.reaim)
        _, CFG.actcancel     = imgui.checkbox("Cancel a ready aim with ActCancel (RB)", CFG.actcancel)
        _, CFG.ready_frames  = imgui.slider_int("Frames until the bow is ready", CFG.ready_frames, 0, 150)
        _, CFG.buffer_frames = imgui.slider_int("RT buffer (frames)", CFG.buffer_frames, 0, 180)
        _, CFG.trigger       = imgui.combo("Fire trigger (action RT is bound to)", CFG.trigger, TRIGGER_OPTS)
        _, CFG.cloud_first   = imgui.slider_float("Cloudburst: first volley delay, from activation (s)", CFG.cloud_first, 0.0, 6.0)
        _, CFG.cloud_charge  = imgui.slider_float("Cloudburst: delay between volleys (s)", CFG.cloud_charge, 0.0, 6.0)
        _, CFG.debug         = imgui.checkbox("Show debug", CFG.debug)
        _, CFG.trace         = imgui.checkbox("Record trace", CFG.trace)

        if CFG.debug then
            imgui.text(string.format("Vocation: %s  weapon vocation (Warfarer): %s [%s]",
                tostring(S.cur_job), tostring(S.weapon_job), S.wf_diag))
            imgui.text(string.format("Effective job: %s  active: %s", tostring(S.job), tostring(is_active())))
            imgui.text("Job detection: " .. S.job_diag)
            imgui.text("State: " .. S.state .. string.format("   aim frames: %d", S.frame - S.aim_since))
            imgui.text("Bow can shoot now: " .. tostring(can_shoot(S.n1 or "")))
        imgui.text("Carrying an object: " .. tostring(is_carrying(S.n0 or "", S.n1 or "")))
            imgui.text("Channeled skill (Cloudburst / Cataract): " .. tostring(is_channel(S.n1 or "")))
            imgui.text(string.format("Next volley allowed in: %.2fs", math.max(0, S.next_ok - now())))
            imgui.text("Action node, layer 0: " .. tostring(S.n0))
            imgui.text("Action node, layer 1: " .. tostring(S.n1))
            imgui.text("Real (managed):  " .. flag_names(S.realOn))
            imgui.text("Output:          " .. flag_names(S.outOn))
            imgui.text("Output trigger:  " .. flag_names(S.last_trig))
            imgui.text("Output release:  " .. flag_names(S.last_rel))
            imgui.text(string.format("Shots (RT): %d   Cancels (LT release): %d", S.shots, S.cancels))
        end

        if CFG.trace then
            imgui.text(string.format("%d events in trace", #Trace))
            if imgui.button("Save trace.json") then json.dump_file(NAME .. "/trace.json", Trace) end
            imgui.same_line()
            if imgui.button("Clear") then Trace = {} end
        end
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)

log.info("[" .. NAME .. "] v" .. VERSION .. " loaded")
