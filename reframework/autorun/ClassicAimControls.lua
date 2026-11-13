-- ClassicAimControls.lua  (v4.5)
-- Dragon's Dogma 2 | REFramework
-- Archer and Magick Archer:
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
-- Install: <game folder>/reframework/autorun/ClassicAimControls.lua

local NAME, VERSION = "ClassicAimControls", "4.5.0"

local CFG = {
    enabled       = true,
    only_jobs     = true,    -- Archer (2) and Magick Archer (8) only
    reaim         = true,    -- aim again after a shot if the game leaves the aim
    actcancel     = true,    -- cancel a ready aim by sending ActCancel (RB action)
    ready_frames  = 0,       -- aim frames until the bow counts as ready (0 = always ready)
    buffer_frames = 0,       -- an RT press that comes too early is kept for this long (0 = off)
    act_frames    = 3,       -- frames holding ActCancel
    trigger       = 1,       -- 1 = Auto (Grab/AttackS/AttackL) | 2 = Grab | 3 = AttackS | 4 = AttackL
    debug         = false,
    trace         = false,
}
local JOBS = { [2] = true, [8] = true }

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
    realOn = 0, outOn = 0,
    state = "idle", fired_at = -1000, fire_phase = 0, reaim_step = 0,
    aim_since = 0, buffer_until = -1, cancel_at = 0, fire_node = nil, retries = 0, hard = false,
    shots = 0, cancels = 0,
    last_out = 0, last_trig = 0, last_rel = 0,
}

local Trace = {}
local function push(Ev)
    if not CFG.trace then return end
    Trace[#Trace + 1] = Ev
    if #Trace > 2000 then table.remove(Trace, 1) end
end

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
    if type(job) == "number" then return job end
    return nil
end

local function is_active()
    if not (CFG.enabled and READY) then return false end
    if not CFG.only_jobs then return true end
    if S.frame - S.job_frame > 30 then S.job, S.job_frame = read_job(), S.frame end
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
local function can_shoot(n1)
    if n1:find("Shoot", 1, true) or n1:find("Cancel", 1, true) then return false end
    if n1:find("PrepareSpecialArrow", 1, true) then return false end
    return true
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

    -- While aiming, the RT action (Grab / AttackS / AttackL) must not reach the game
    if lt_held or S.state ~= "idle" then
        if ((out | trig | rel) & TB) ~= 0 then touched = true end
        out, trig, rel = out & ~TB, trig & ~TB, rel & ~TB
    end

    local function fire()
        S.hard = S.retries >= 1
        if S.hard then                       -- retry: release the whole aim, like letting go of LT
            out = out & ~GROUP
            rel = rel | GROUP
        else                                 -- first try: ShootRelease pulse, AimHold stays on
            out = out & ~SHOOT
            rel = rel | SHOOT
        end
        touched = true
        S.fire_node, S.buffer_until = n1, -1
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
            if S.frame <= S.buffer_until and ready and shootable then fire() end
        end
    elseif S.state == "fired" then
        if not lt_held then
            release_vanilla()
        else
            if S.fire_phase == 1 then        -- the released flag(s) go back to "pressed"
                trig = trig | (S.hard and GROUP or SHOOT)
                touched = true
                S.fire_phase = 2
            end
            if rt_trig then S.buffer_until, S.retries = S.frame + CFG.buffer_frames, 0 end
            local waited = S.frame - S.fired_at
            local aimish = n1:find("RestartAim", 1, true) or n1:find("StartAim", 1, true)
                        or n1:find("Ready", 1, true)
            local function back_to_aim()
                -- if the node never changed, the game ignored the shot: try again
                if n1 == S.fire_node and S.retries < 2 then
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
            elseif waited >= 20 and shootable then
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
            and (n1:find("Cancel", 1, true) or n1:find("UpperBodyDefault", 1, true))
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
        push({ f = S.frame, st = S.state, ready = ready, can = shootable, n1 = S.n1, real = flag_names(realOn),
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

re.on_frame(function()
    S.frame = S.frame + 1
    S.Player = Call(sdk.get_managed_singleton("app.CharacterManager"), "get_ManualPlayer()")
    S.Input = Get(S.Player, "<Input>k__BackingField")
    S.InputAddr = Addr(S.Input)
    S.n0 = node_name(S.Player, 0)
    S.n1 = node_name(S.Player, 1)
end)

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local TRIGGER_OPTS = { "Auto (Grab / AttackS / AttackL)", "Grab", "AttackS", "AttackL" }

re.on_draw_ui(function()
    if not imgui.tree_node(NAME .. " v" .. VERSION) then return end
    local _
    _, CFG.enabled       = imgui.checkbox("Enabled", CFG.enabled)
    _, CFG.only_jobs     = imgui.checkbox("Archer / Magick Archer only", CFG.only_jobs)
    _, CFG.reaim         = imgui.checkbox("Aim again after the shot (if the game leaves the aim)", CFG.reaim)
    _, CFG.actcancel     = imgui.checkbox("Cancel a ready aim with ActCancel (RB)", CFG.actcancel)
    _, CFG.ready_frames  = imgui.slider_int("Frames until the bow is ready", CFG.ready_frames, 0, 150)
    _, CFG.buffer_frames = imgui.slider_int("RT buffer (frames)", CFG.buffer_frames, 0, 180)
    _, CFG.trigger       = imgui.combo("Fire trigger (action RT is bound to)", CFG.trigger, TRIGGER_OPTS)
    _, CFG.debug         = imgui.checkbox("Show debug", CFG.debug)
    _, CFG.trace         = imgui.checkbox("Record trace", CFG.trace)

    if not READY then imgui.text("Input flags not found: mod disabled") end

    if CFG.debug then
        imgui.text(string.format("Job: %s  active: %s", tostring(S.job), tostring(is_active())))
        imgui.text("Job detection: " .. S.job_diag)
        imgui.text("State: " .. S.state .. string.format("   aim frames: %d", S.frame - S.aim_since))
        imgui.text("Bow can shoot now: " .. tostring(can_shoot(S.n1 or "")))
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
end)

log.info("[" .. NAME .. "] v" .. VERSION .. " loaded")

