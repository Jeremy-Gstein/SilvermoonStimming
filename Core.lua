-- ============================================================
--  SilvermoonStimming_Core.lua
--  State machine + angle-accumulation lap counter.
--
--  States
--  -------
--  "OFF_TRACK"  - player is outside the outer box
--  "IN_CENTER"  - player is inside the inner ellipse (tracking suspended)
--  "ON_TRACK"   - player is in the valid ring zone; angle accumulates
--
--  Lap logic
--  ---------
--  accumulatedAngle grows (CW) or shrinks (CCW) each tick.
--  Every time floor(|accumulatedAngle| / 2pi) increases by 1 = one lap.
--  On direction reversal accumulatedAngle resets to 0 -- clean slate.
-- ============================================================

local CFG    = SilvermoonStimmingConfig
local TWO_PI = math.pi * 2

-- Saved-variable defaults
local DB_DEFAULTS = {
    bestLapSeconds = nil,
    totalLaps      = 0,
    sessionLaps    = 0,
}

SilvermoonStimmingCore = {}

-- Runtime state
local W_ticker         = nil
local state            = "OFF_TRACK"
local previousAngle    = nil
local accumulatedAngle = 0
local completedLaps    = 0
local lapStartTime     = nil
local direction        = CFG.DIR_NONE

-- ── Position ─────────────────────────────────────────────────────────────────

local function GetPlayerPos()
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID ~= CFG.MAP_ID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    return pos.x, pos.y
end

-- ── Zone checks ──────────────────────────────────────────────────────────────

local function InOuterBox(x, y)
    local b, p = CFG.OUTER_BOX, CFG.OUTER_BUFFER
    return x >= (b.minX - p) and x <= (b.maxX + p)
       and y >= (b.minY - p) and y <= (b.maxY + p)
end

-- Ellipse check: (dx/rx)^2 + (dy/ry)^2 <= 1, no sqrt needed
local function InInnerEllipse(x, y)
    local e  = CFG.INNER_ELLIPSE
    local dx = (x - CFG.CENTER.x) / e.rx
    local dy = (y - CFG.CENTER.y) / e.ry
    return (dx * dx + dy * dy) <= 1
end

-- ── Angle helpers ─────────────────────────────────────────────────────────────

local function NormaliseDelta(d)
    while d >  math.pi do d = d - TWO_PI end
    while d <= -math.pi do d = d + TWO_PI end
    return d
end

-- ── State transitions ─────────────────────────────────────────────────────────

local function ResetRunState()
    accumulatedAngle = 0
    completedLaps    = 0
    lapStartTime     = GetTime()
    previousAngle    = nil
    direction        = CFG.DIR_NONE
end

local function EnterTrack(x, y)
    state         = "ON_TRACK"
    previousAngle = math.atan2(y - CFG.CENTER.y, x - CFG.CENTER.x)
    if lapStartTime == nil then lapStartTime = GetTime() end
    SilvermoonStimmingUI.OnStateChange(state)
    print("|cff00ff7fSilvermoonStimming:|r On track.")
end

local function EnterCenter()
    state         = "IN_CENTER"
    previousAngle = nil
    SilvermoonStimmingUI.OnStateChange(state)
end

local function LeaveTrack()
    state = "OFF_TRACK"
    SilvermoonStimmingUI.OnStateChange(state)
    print("|cff00ff7fSilvermoonStimming:|r Left track.")
end

-- ── Lap counting ──────────────────────────────────────────────────────────────

local function CheckLap()
    local lapsNow = math.floor(math.abs(accumulatedAngle) / TWO_PI)
    if lapsNow <= completedLaps then return end

    local elapsed = lapStartTime and (GetTime() - lapStartTime) or 999
    if elapsed < CFG.MIN_LAP_SECONDS then
        print("|cffff4444SilvermoonStimming:|r Lap too fast (" .. string.format("%.1f", elapsed) .. "s) -- ignored.")
        ResetRunState()
        return
    end

    completedLaps = lapsNow
    SilvermoonStimmingDB.totalLaps   = SilvermoonStimmingDB.totalLaps + 1
    SilvermoonStimmingDB.sessionLaps = SilvermoonStimmingDB.sessionLaps + 1

    if not SilvermoonStimmingDB.bestLapSeconds
    or elapsed < SilvermoonStimmingDB.bestLapSeconds then
        SilvermoonStimmingDB.bestLapSeconds = elapsed
    end

    local dirLabel = (direction == CFG.DIR_CW) and "|cff00ccff->  CW|r" or "|cffff9900<- CCW|r"
    print(string.format(
        "|cff00ff7fSilvermoonStimming:|r Lap |cffffff00#%d|r  %s  Time: |cffffff00%.1fs|r",
        SilvermoonStimmingDB.totalLaps, dirLabel, elapsed
    ))

    lapStartTime = GetTime()
    SilvermoonStimmingUI.OnLapComplete(SilvermoonStimmingDB)
end

-- ── Main tick ─────────────────────────────────────────────────────────────────

local function Tick()
    local x, y = GetPlayerPos()

    if not x then
        if state ~= "OFF_TRACK" then LeaveTrack() end
        return
    end

    if not InOuterBox(x, y) then
        if state ~= "OFF_TRACK" then LeaveTrack() end
        return
    end

    if InInnerEllipse(x, y) then
        if state == "ON_TRACK" then EnterCenter() end
        return
    end

    if state ~= "ON_TRACK" then
        EnterTrack(x, y)
        return
    end

    -- Angle accumulation
    local current = math.atan2(y - CFG.CENTER.y, x - CFG.CENTER.x)
    if previousAngle == nil then
        previousAngle = current
        return
    end

    local delta = NormaliseDelta(current - previousAngle)

    if math.abs(delta) > CFG.TELEPORT_THRESHOLD then
        previousAngle = current
        return
    end

    local newDir = (delta > 0.001 and CFG.DIR_CW)
                or (delta < -0.001 and CFG.DIR_CCW)
                or direction

    -- Direction reversal: zero out accumulated angle for a clean slate
    if newDir ~= CFG.DIR_NONE and newDir ~= direction and direction ~= CFG.DIR_NONE then
        print("|cff00ff7fSilvermoonStimming:|r Direction reversed.")
        ResetRunState()
        previousAngle = current
        direction     = newDir
        SilvermoonStimmingUI.OnTick(0, direction)
        return
    end

    direction        = newDir
    accumulatedAngle = accumulatedAngle + delta
    previousAngle    = current

    CheckLap()
    SilvermoonStimmingUI.OnTick(accumulatedAngle, direction)
end

-- ── Addon frame ───────────────────────────────────────────────────────────────

-- Silvermoon map IDs: the city itself (2393) plus any sub-zones that
-- share the same map parent. We check the zone name as a fallback.
local SILVERMOON_MAPS = { [2393] = true }

local function IsInSilvermoon()
    local mapID = C_Map.GetBestMapForUnit("player")
    if SILVERMOON_MAPS[mapID] then return true end
    -- Fallback: zone name contains "Silvermoon"
    local zone = GetZoneText()
    return zone and zone:find("Silvermoon") ~= nil
end

local frame = CreateFrame("Frame", "SilvermoonStimmingFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SilvermoonStimming" then
        if not SilvermoonStimmingDB then SilvermoonStimmingDB = {} end
        for k, v in pairs(DB_DEFAULTS) do
            if SilvermoonStimmingDB[k] == nil then SilvermoonStimmingDB[k] = v end
        end
        SilvermoonStimmingDB.sessionLaps = 0

        W_ticker = C_Timer.NewTicker(CFG.POLL_RATE, Tick)
        SilvermoonStimmingUI.Init(SilvermoonStimmingDB)
        print("|cff00ff7fSilvermoonStimming|r loaded.  |cff888888/lt for commands|r")

    elseif event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "PLAYER_ENTERING_WORLD"
    then
        -- Small delay so map data is ready after zone transition
        C_Timer.After(1.0, function()
            if IsInSilvermoon() then
                if not W_ticker then
                    W_ticker = C_Timer.NewTicker(CFG.POLL_RATE, Tick)
                end
                SilvermoonStimmingUI.OnZoneEnter()
            else
                if W_ticker then W_ticker:Cancel() ; W_ticker = nil end
                if state ~= "OFF_TRACK" then LeaveTrack() end
                ResetRunState()
                SilvermoonStimmingUI.OnZoneLeave()
            end
        end)
    end
end)

-- ── Slash commands ────────────────────────────────────────────────────────────

SLASH_SILVERMOONST1 = "/silvermoon"
SLASH_SILVERMOONST2 = "/lt"

SlashCmdList["SILVERMOONST"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "reset" then
        ResetRunState()
        SilvermoonStimmingDB.totalLaps      = 0
        SilvermoonStimmingDB.sessionLaps    = 0
        SilvermoonStimmingDB.bestLapSeconds = nil
        print("|cff00ff7fSilvermoonStimming:|r Reset.")
        SilvermoonStimmingUI.Init(SilvermoonStimmingDB)

    elseif cmd == "debug" then
        local x, y = GetPlayerPos()
        if x then
            local ang      = math.atan2(y - CFG.CENTER.y, x - CFG.CENTER.x)
            local zone     = "OFF_TRACK"
            if InOuterBox(x, y) then
                zone = InInnerEllipse(x, y) and "IN_CENTER" or "ON_TRACK"
            end
            local progress = (math.abs(accumulatedAngle) % TWO_PI) / TWO_PI * 100
            print(string.format(
                "|cff00ff7fDebug:|r pos=(%.4f,%.4f)  zone=%s  angle=%.1f  acc=%.1f  progress=%.0f%%  session=%d",
                x, y, zone, math.deg(ang), math.deg(accumulatedAngle), progress, SilvermoonStimmingDB.sessionLaps
            ))
        else
            print("|cff00ff7fDebug:|r No position (wrong map).")
        end

    elseif cmd == "best" then
        if SilvermoonStimmingDB.bestLapSeconds then
            print(string.format("|cff00ff7fSilvermoonStimming:|r Best: |cffffff00%.1fs|r  Total: %d",
                SilvermoonStimmingDB.bestLapSeconds, SilvermoonStimmingDB.totalLaps))
        else
            print("|cff00ff7fSilvermoonStimming:|r No laps yet.")
        end

    elseif cmd == "toggle" then
        SilvermoonStimmingUI.Toggle()

    else
        print("|cff00ff7fSilvermoonStimming|r  /lt debug  /lt best  /lt reset  /lt toggle")
    end
end
