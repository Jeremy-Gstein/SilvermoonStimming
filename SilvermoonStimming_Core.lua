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
--
--  Multi-profile support
--  ----------------------
--  activeCFG  - the config object the tick uses (either the built-in
--               Silvermoon config or a derived custom config).
--  activeDB   - the SavedVariables sub-table lap stats write to.
--               Points to SilvermoonStimmingDB (Silvermoon tab) or a
--               customLocations slot (Custom tab).
--  Call SilvermoonStimmingCore.SetProfile() to switch between them.
-- ============================================================

local CFG_SILVERMOON = SilvermoonStimmingConfig   -- original, never mutated
local L              = SilvermoonStimmingL
local TWO_PI         = math.pi * 2

-- Active-profile pointers (switched by SetProfile)
local activeCFG  = CFG_SILVERMOON
local activeDB   = nil              -- set once DB loads in ADDON_LOADED
local activeMode = "silvermoon"     -- "silvermoon" | "custom"

-- Saved-variable defaults (Silvermoon tab)
local DB_DEFAULTS = {
    bestLapSeconds   = nil,
    totalLaps        = 0,
    sessionLaps      = 0,
    activeCustomSlot = 1,
    activeTab        = "silvermoon",
    customLocations  = {},
}

SilvermoonStimmingCore = {}

-- Runtime state
local W_ticker         = nil
local inActiveZone     = false
local Tick             -- forward declaration

local function StartTicker()
    if inActiveZone and not W_ticker then
        W_ticker = C_Timer.NewTicker(activeCFG.POLL_RATE, Tick)
    end
end

local function StopTicker()
    if W_ticker then W_ticker:Cancel() ; W_ticker = nil end
end

local state            = "OFF_TRACK"
local previousAngle    = nil
local accumulatedAngle = 0
local completedLaps    = 0
local lapStartTime     = nil
local direction        = CFG_SILVERMOON.DIR_NONE

-- ── Custom config builder ─────────────────────────────────────────────────────

local function BuildCustomConfig(slot)
    local presets = CFG_SILVERMOON.BOUNDS_PRESETS
    local off     = presets[slot.boundsSize or "medium"] or presets.medium
    local cx, cy  = slot.center.x, slot.center.y
    return {
        MAP_ID = slot.mapID,
        CENTER = { x = cx, y = cy },
        OUTER_BOX = {
            minX = cx - off.x,
            maxX = cx + off.x,
            minY = cy - off.y,
            maxY = cy + off.y,
        },
        OUTER_BUFFER       = 0.012,
        INNER_ELLIPSE      = { rx = off.x * 0.28, ry = off.y * 0.28 },
        POLL_RATE          = CFG_SILVERMOON.POLL_RATE,
        TELEPORT_THRESHOLD = CFG_SILVERMOON.TELEPORT_THRESHOLD,
        MIN_LAP_SECONDS    = CFG_SILVERMOON.MIN_LAP_SECONDS,
        DIR_NONE           = CFG_SILVERMOON.DIR_NONE,
        DIR_CW             = CFG_SILVERMOON.DIR_CW,
        DIR_CCW            = CFG_SILVERMOON.DIR_CCW,
    }
end

-- ── Position ──────────────────────────────────────────────────────────────────

local function GetPlayerPos()
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID ~= activeCFG.MAP_ID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    return pos.x, pos.y
end

-- ── Zone detection ────────────────────────────────────────────────────────────

local SILVERMOON_MAPS = { [2393] = true }

local function IsInActiveZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    if activeMode == "silvermoon" then
        if SILVERMOON_MAPS[mapID] then return true end
        local zone = GetZoneText()
        return zone and zone:find("Silvermoon") ~= nil
    else
        return activeCFG.MAP_ID ~= nil and mapID == activeCFG.MAP_ID
    end
end

-- ── Geometry ──────────────────────────────────────────────────────────────────

local function InOuterBox(x, y)
    local b, p = activeCFG.OUTER_BOX, activeCFG.OUTER_BUFFER
    return x >= (b.minX - p) and x <= (b.maxX + p)
       and y >= (b.minY - p) and y <= (b.maxY + p)
end

local function InInnerEllipse(x, y)
    local e  = activeCFG.INNER_ELLIPSE
    local dx = (x - activeCFG.CENTER.x) / e.rx
    local dy = (y - activeCFG.CENTER.y) / e.ry
    return (dx * dx + dy * dy) <= 1
end

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
    direction        = activeCFG.DIR_NONE
end

local function EnterTrack(x, y)
    state         = "ON_TRACK"
    previousAngle = math.atan2(y - activeCFG.CENTER.y, x - activeCFG.CENTER.x)
    if lapStartTime == nil then lapStartTime = GetTime() end
    SilvermoonStimmingUI.OnStateChange(state)
    print(L["ON_TRACK"])
end

local function EnterCenter()
    state         = "IN_CENTER"
    previousAngle = nil
    SilvermoonStimmingUI.OnStateChange(state)
end

local function LeaveTrack()
    state = "OFF_TRACK"
    SilvermoonStimmingUI.OnStateChange(state)
    print(L["LEFT_TRACK"])
end

-- ── Lap counting ──────────────────────────────────────────────────────────────

local function CheckLap()
    local lapsNow = math.floor(math.abs(accumulatedAngle) / TWO_PI)
    if lapsNow <= completedLaps then return end

    local elapsed = lapStartTime and (GetTime() - lapStartTime) or 999
    if elapsed < activeCFG.MIN_LAP_SECONDS then
        print(string.format(L["LAP_TOO_FAST"], elapsed))
        ResetRunState()
        return
    end

    completedLaps        = lapsNow
    activeDB.totalLaps   = activeDB.totalLaps + 1
    activeDB.sessionLaps = activeDB.sessionLaps + 1

    if not activeDB.bestLapSeconds
    or elapsed < activeDB.bestLapSeconds then
        activeDB.bestLapSeconds = elapsed
    end

    local dirLabel = (direction == activeCFG.DIR_CW) and L["DIR_CW"] or L["DIR_CCW"]
    print(string.format(L["LAP_COMPLETE"], activeDB.totalLaps, dirLabel, elapsed))

    lapStartTime = GetTime()
    SilvermoonStimmingUI.OnLapComplete(activeDB)
end

-- ── Main tick ─────────────────────────────────────────────────────────────────

Tick = function()
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

    local current = math.atan2(y - activeCFG.CENTER.y, x - activeCFG.CENTER.x)
    if previousAngle == nil then
        previousAngle = current
        return
    end

    local delta = NormaliseDelta(current - previousAngle)

    if math.abs(delta) > activeCFG.TELEPORT_THRESHOLD then
        previousAngle = current
        return
    end

    local newDir = (delta > 0.001 and activeCFG.DIR_CW)
                or (delta < -0.001 and activeCFG.DIR_CCW)
                or direction

    if newDir ~= activeCFG.DIR_NONE and newDir ~= direction and direction ~= activeCFG.DIR_NONE then
        print(L["DIR_REVERSED"])
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

-- ── Public API ────────────────────────────────────────────────────────────────

-- Switch the active tracking profile.
--   mode = "silvermoon"  → built-in Silvermoon geometry + SilvermoonStimmingDB
--   mode = "custom"      → geometry from customLocations[slotIndex]
function SilvermoonStimmingCore.SetProfile(mode, slotIndex)
    StopTicker()
    state            = "OFF_TRACK"
    accumulatedAngle = 0
    completedLaps    = 0
    lapStartTime     = nil
    previousAngle    = nil
    activeMode       = mode

    if mode == "silvermoon" then
        activeCFG = CFG_SILVERMOON
        activeDB  = SilvermoonStimmingDB
    else
        local slot = SilvermoonStimmingDB.customLocations[slotIndex]
        if not slot or not slot.center then
            -- No valid center yet; park in a neutral state
            activeCFG    = CFG_SILVERMOON
            activeDB     = slot or SilvermoonStimmingDB
            inActiveZone = false
            SilvermoonStimmingUI.OnStateChange("OFF_TRACK")
            return
        end
        activeCFG = BuildCustomConfig(slot)
        activeDB  = slot
    end

    direction = activeCFG.DIR_NONE
    SilvermoonStimmingUI.OnStateChange("OFF_TRACK")

    -- Re-evaluate zone after a short delay so map data is current
    C_Timer.After(0.05, function()
        inActiveZone = IsInActiveZone()
    end)
end

-- Rebuild active custom config after a boundsSize change.
function SilvermoonStimmingCore.RefreshCustomConfig(slotIndex)
    if activeMode == "custom" then
        local slot = SilvermoonStimmingDB.customLocations[slotIndex]
        if slot and slot.center then
            StopTicker()
            activeCFG = BuildCustomConfig(slot)
            ResetRunState()
        end
    end
end

-- Capture the player's current map position.
-- Returns: mapID, x, y  on success; nil on failure.
function SilvermoonStimmingCore.CaptureCurrentPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    return mapID, pos.x, pos.y
end

-- Return current mode ("silvermoon" | "custom") and active slot index or nil.
function SilvermoonStimmingCore.GetActiveMode()
    return activeMode,
           (activeMode == "custom" and SilvermoonStimmingDB.activeCustomSlot or nil)
end

-- ── Addon frame ───────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame", "SilvermoonStimmingFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_STARTED_MOVING")
frame:RegisterEvent("PLAYER_STOPPED_MOVING")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SilvermoonStimming" then
        if not SilvermoonStimmingDB then SilvermoonStimmingDB = {} end
        for k, v in pairs(DB_DEFAULTS) do
            if SilvermoonStimmingDB[k] == nil then
                SilvermoonStimmingDB[k] = (type(v) == "table") and {} or v
            end
        end
        SilvermoonStimmingDB.sessionLaps = 0
        for _, slot in ipairs(SilvermoonStimmingDB.customLocations) do
            slot.sessionLaps = 0
        end

        activeDB = SilvermoonStimmingDB
        SilvermoonStimmingUI.Init(SilvermoonStimmingDB)
        print(L["LOADED"])

    elseif event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "PLAYER_ENTERING_WORLD"
    then
        C_Timer.After(1.0, function()
            if IsInActiveZone() then
                inActiveZone = true
                SilvermoonStimmingUI.OnZoneEnter()
            else
                inActiveZone = false
                StopTicker()
                if state ~= "OFF_TRACK" then LeaveTrack() end
                ResetRunState()
                SilvermoonStimmingUI.OnZoneLeave()
            end
        end)

    elseif event == "PLAYER_STARTED_MOVING"
        or event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        StartTicker()

    elseif event == "PLAYER_STOPPED_MOVING" then
        StopTicker()
        Tick()
    end
end)

-- ── Slash commands ────────────────────────────────────────────────────────────

SLASH_SILVERMOONST1 = "/silvermoon"
SLASH_SILVERMOONST2 = "/lt"

SlashCmdList["SILVERMOONST"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "reset" then
        ResetRunState()
        activeDB.totalLaps      = 0
        activeDB.sessionLaps    = 0
        activeDB.bestLapSeconds = nil
        print(L["RESET_DONE"])
        SilvermoonStimmingUI.OnLapComplete(activeDB)

    elseif cmd == "debug" then
        local x, y = GetPlayerPos()
        if x then
            local ang      = math.atan2(y - activeCFG.CENTER.y, x - activeCFG.CENTER.x)
            local zone     = "OFF_TRACK"
            if InOuterBox(x, y) then
                zone = InInnerEllipse(x, y) and "IN_CENTER" or "ON_TRACK"
            end
            local progress = (math.abs(accumulatedAngle) % TWO_PI) / TWO_PI * 100
            print(string.format(L["DEBUG_LINE"], x, y, zone, math.deg(ang),
                math.deg(accumulatedAngle), progress, activeDB.sessionLaps))
        else
            print(L["NO_POSITION"])
        end

    elseif cmd == "best" then
        if activeDB.bestLapSeconds then
            print(string.format(L["BEST_LINE"], activeDB.bestLapSeconds, activeDB.totalLaps))
        else
            print(L["NO_LAPS_YET"])
        end

    elseif cmd == "toggle" then
        SilvermoonStimmingUI.Toggle()

    else
        print(L["HELP_LINE"])
    end
end
