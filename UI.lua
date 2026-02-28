-- ============================================================
--  SilvermoonStimming_UI.lua
-- ============================================================

SilvermoonStimmingUI = {}
local UI = SilvermoonStimmingUI

local TWO_PI = math.pi * 2

local COL = {
    gold        = { 1.0,  0.82, 0.0  },
    green       = { 0.0,  1.0,  0.5  },
    blue        = { 0.4,  0.8,  1.0  },
    orange      = { 1.0,  0.6,  0.1  },
    dim         = { 0.55, 0.55, 0.55 },
    bg          = { 0.05, 0.05, 0.07, 0.88 },
    border_idle = { 0.25, 0.25, 0.30, 1    },
    border_lap  = { 1.0,  0.82, 0.0,  1    },
}

local STATE_COL = {
    OFF_TRACK = COL.dim,
    IN_CENTER = COL.orange,
    ON_TRACK  = COL.green,
}

local W           = {}       -- widget refs
local minimized   = false
local manualShow  = false    -- true if user opened via /lt toggle while off-map

local FULL_H = 148
local MINI_H = 62

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function SetCol(widget, col, a)
    widget:SetColorTexture(col[1], col[2], col[3], a or col[4] or 1)
end

local function HSep(parent, yOff)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, yOff)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOff)
    t:SetHeight(1)
    t:SetColorTexture(0.3, 0.3, 0.35, 0.8)
    return t
end

-- ── Build ─────────────────────────────────────────────────────────────────────

local function Build()
    -- Main frame
    local f = CreateFrame("Frame", "SilvermoonStimmingHUD", UIParent, "BackdropTemplate")
    f:SetSize(210, FULL_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 380, 190)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata("MEDIUM")
    f:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    f:SetBackdropColor(COL.bg[1], COL.bg[2], COL.bg[3], COL.bg[4])
    f:SetBackdropBorderColor(unpack(COL.border_idle))
    W.frame = f

    -- ── Title row ──────────────────────────────────────────────────────────
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    title:SetText("|cffffd700Silvermoon|r |cffaaaaaa Stimming|r")
    W.title = title

    -- Status dot
    W.dot = f:CreateTexture(nil, "OVERLAY")
    W.dot:SetSize(8, 8)
    W.dot:SetPoint("LEFT", title, "RIGHT", 6, 0)
    SetCol(W.dot, COL.dim)

    -- Minimize button (–)
    local minBtn = CreateFrame("Button", nil, f)
    minBtn:SetSize(16, 16)
    minBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -6)
    minBtn:SetNormalFontObject("GameFontNormalSmall")
    minBtn:SetText("—")
    minBtn:GetFontString():SetTextColor(0.7, 0.7, 0.7)
    minBtn:SetScript("OnClick", function() UI.ToggleMinimize() end)
    minBtn:SetScript("OnEnter", function() minBtn:GetFontString():SetTextColor(1,1,1) end)
    minBtn:SetScript("OnLeave", function() minBtn:GetFontString():SetTextColor(0.7,0.7,0.7) end)
    W.minBtn = minBtn

    -- Close button (×)
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    closeBtn:SetNormalFontObject("GameFontNormalSmall")
    closeBtn:SetText("×")
    closeBtn:GetFontString():SetTextColor(0.7, 0.7, 0.7)
    closeBtn:SetScript("OnClick", function()
        manualShow = false
        f:Hide()
    end)
    closeBtn:SetScript("OnEnter", function() closeBtn:GetFontString():SetTextColor(1, 0.3, 0.3) end)
    closeBtn:SetScript("OnLeave", function() closeBtn:GetFontString():SetTextColor(0.7, 0.7, 0.7) end)
    W.closeBtn = closeBtn

    -- ── Full view widgets (hidden when minimized) ───────────────────────────
    W.fullWidgets = {}

    local sep1 = HSep(f, -26)
    table.insert(W.fullWidgets, sep1)

    local sessionLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
    sessionLabel:SetText("SESSION")
    sessionLabel:SetTextColor(unpack(COL.dim))
    table.insert(W.fullWidgets, sessionLabel)

    W.session = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    W.session:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -31)
    W.session:SetText("0")
    W.session:SetTextColor(unpack(COL.green))
    table.insert(W.fullWidgets, W.session)

    local sep2 = HSep(f, -54)
    table.insert(W.fullWidgets, sep2)

    W.total = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.total:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -62)
    W.total:SetText("Total: 0")
    W.total:SetTextColor(unpack(COL.dim))
    table.insert(W.fullWidgets, W.total)

    W.best = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.best:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -62)
    W.best:SetText("Best: --")
    W.best:SetTextColor(unpack(COL.gold))
    table.insert(W.fullWidgets, W.best)

    local sep3 = HSep(f, -78)
    table.insert(W.fullWidgets, sep3)

    W.dir = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.dir:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -86)
    W.dir:SetText("Off track")
    W.dir:SetTextColor(unpack(COL.dim))
    table.insert(W.fullWidgets, W.dir)

    W.pct = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.pct:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -86)
    W.pct:SetText("0%")
    W.pct:SetTextColor(unpack(COL.dim))
    table.insert(W.fullWidgets, W.pct)

    local sep4 = HSep(f, -102)
    table.insert(W.fullWidgets, sep4)

    -- ── Progress bar (always visible) ─────────────────────────────────────
    W.barBg = f:CreateTexture(nil, "BACKGROUND")
    W.barBg:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  11, 11)
    W.barBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 11)
    W.barBg:SetHeight(12)
    W.barBg:SetColorTexture(0.12, 0.12, 0.15, 1)

    W.bar = f:CreateTexture(nil, "ARTWORK")
    W.bar:SetPoint("BOTTOMLEFT", W.barBg, "BOTTOMLEFT", 0, 0)
    W.bar:SetHeight(12)
    W.bar:SetWidth(1)
    SetCol(W.bar, COL.green)

    -- Mini session label (only visible when minimized)
    W.miniSession = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.miniSession:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -29)
    W.miniSession:SetText("0 laps")
    W.miniSession:SetTextColor(unpack(COL.green))
    W.miniSession:Hide()

    -- Mini percent (right-aligned, same row as miniSession)
    W.miniPct = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.miniPct:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -29)
    W.miniPct:SetText("0%")
    W.miniPct:SetTextColor(unpack(COL.dim))
    W.miniPct:Hide()
end

-- ── Minimize / Maximize ───────────────────────────────────────────────────────

function UI.ToggleMinimize()
    minimized = not minimized

    if minimized then
        W.frame:SetHeight(MINI_H)
        for _, w in ipairs(W.fullWidgets) do w:Hide() end
        W.miniSession:Show()
        W.miniPct:Show()
        -- reanchor bar to fill mini frame
        W.barBg:SetPoint("BOTTOMLEFT",  W.frame, "BOTTOMLEFT",  11, 6)
        W.barBg:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", -11, 6)
        W.minBtn:SetText("+")
    else
        W.frame:SetHeight(FULL_H)
        for _, w in ipairs(W.fullWidgets) do w:Show() end
        W.miniSession:Hide()
        W.miniPct:Hide()
        W.barBg:SetPoint("BOTTOMLEFT",  W.frame, "BOTTOMLEFT",  11, 11)
        W.barBg:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", -11, 11)
        W.minBtn:SetText("—")
    end
end

-- ── Zone-based auto show/hide ─────────────────────────────────────────────────

function UI.OnZoneEnter()
    if W.frame and not manualShow then
        W.frame:Show()
    end
end

function UI.OnZoneLeave()
    if W.frame and not manualShow then
        W.frame:Hide()
    end
end

-- ── Public callbacks ──────────────────────────────────────────────────────────

function UI.Init(db)
    if not W.frame then Build() end
    UI.Refresh(db)
    -- Start hidden; zone events will show it when in Silvermoon
    W.frame:Hide()
end

function UI.Toggle()
    if not W.frame then return end
    if W.frame:IsShown() then
        manualShow = false
        W.frame:Hide()
    else
        manualShow = true
        W.frame:Show()
    end
end

function UI.Refresh(db)
    if not W.session then return end
    local s = tostring(db.sessionLaps or 0)
    W.session:SetText(s)
    W.miniSession:SetText(s .. " laps")
    if W.miniPct then W.miniPct:SetTextColor(unpack(COL.green)) end
    W.total:SetText("Total: " .. (db.totalLaps or 0))
    if db.bestLapSeconds then
        W.best:SetText(string.format("Best: %.1fs", db.bestLapSeconds))
    else
        W.best:SetText("Best: --")
    end
end

function UI.OnStateChange(newState)
    if not W.dot then return end
    local col = STATE_COL[newState] or COL.dim
    SetCol(W.dot, col)

    if newState == "OFF_TRACK" then
        if W.dir then W.dir:SetText("Off track") ; W.dir:SetTextColor(unpack(COL.dim)) end
        if W.pct then W.pct:SetText("0%")        ; W.pct:SetTextColor(unpack(COL.dim)) end
        if W.bar then SetCol(W.bar, COL.dim) end
    elseif newState == "IN_CENTER" then
        if W.dir then W.dir:SetText("In center")  ; W.dir:SetTextColor(unpack(COL.orange)) end
        if W.bar then SetCol(W.bar, COL.orange) end
    end
end

function UI.OnTick(accumulatedAngle, direction)
    if not W.bar or not W.barBg then return end

    local CFG      = SilvermoonStimmingConfig
    local fraction = (math.abs(accumulatedAngle) % TWO_PI) / TWO_PI
    local bgW      = W.barBg:GetWidth()
    W.bar:SetWidth(math.max(1, bgW * fraction))

    local pct = math.floor(fraction * 100)
    if W.pct     then W.pct:SetText(pct .. "%") end
    if W.miniPct then W.miniPct:SetText(pct .. "%") end

    if direction == CFG.DIR_CW then
        if W.dir then W.dir:SetText("-> Clockwise")   ; W.dir:SetTextColor(unpack(COL.blue))   end
        if W.pct     then W.pct:SetTextColor(unpack(COL.blue))   end
        if W.miniPct then W.miniPct:SetTextColor(unpack(COL.blue)) end
        SetCol(W.bar, COL.blue)
    elseif direction == CFG.DIR_CCW then
        if W.dir then W.dir:SetText("<- Counter-CW") ; W.dir:SetTextColor(unpack(COL.orange)) end
        if W.pct     then W.pct:SetTextColor(unpack(COL.orange)) end
        if W.miniPct then W.miniPct:SetTextColor(unpack(COL.orange)) end
        SetCol(W.bar, COL.orange)
    else
        if W.dir then W.dir:SetText("Starting...")   ; W.dir:SetTextColor(unpack(COL.dim))    end
        if W.pct     then W.pct:SetTextColor(unpack(COL.dim))    end
        if W.miniPct then W.miniPct:SetTextColor(unpack(COL.dim))    end
        SetCol(W.bar, COL.dim)
    end
end

function UI.OnLapComplete(db)
    UI.Refresh(db)
    if not W.frame then return end
    W.frame:SetBackdropBorderColor(unpack(COL.border_lap))
    if W.session then W.session:SetTextColor(1, 1, 1) end
    if W.miniSession then W.miniSession:SetTextColor(1, 1, 1) end
    C_Timer.After(0.4, function()
        if W.session     then W.session:SetTextColor(unpack(COL.green))     end
        if W.miniSession then W.miniSession:SetTextColor(unpack(COL.green)) end
    end)
    C_Timer.After(1.8, function()
        if W.frame then W.frame:SetBackdropBorderColor(unpack(COL.border_idle)) end
    end)
end
