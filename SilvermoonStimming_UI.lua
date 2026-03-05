-- ============================================================
--  SilvermoonStimming_UI.lua
-- ============================================================

SilvermoonStimmingUI = {}
local UI = SilvermoonStimmingUI
local L  = SilvermoonStimmingL

local TWO_PI = math.pi * 2

local function Notify(msg)
    UIErrorsFrame:AddMessage(msg, 1, 0.82, 0)
end

-- ── Palette ───────────────────────────────────────────────────────────────────

local COL = {
    gold        = { 1.0,  0.82, 0.0  },
    green       = { 0.0,  1.0,  0.5  },
    blue        = { 0.4,  0.8,  1.0  },
    orange      = { 1.0,  0.6,  0.1  },
    dim         = { 0.55, 0.55, 0.55 },
    bg          = { 0.05, 0.05, 0.07, 0.88 },
    border_idle = { 0.25, 0.25, 0.30, 1    },
    border_lap  = { 1.0,  0.82, 0.0,  1    },
    tab_active  = { 1.0,  0.82, 0.0  },
    tab_idle    = { 0.45, 0.45, 0.50 },
    tab_bg_act  = { 0.12, 0.12, 0.16, 1 },
    tab_bg_idle = { 0.07, 0.07, 0.10, 1 },
    btn_cap     = { 0.15, 0.55, 0.25, 1 },
    btn_bounds  = { 0.12, 0.12, 0.18, 1 },
    btn_bounds_a= { 0.20, 0.45, 0.65, 1 },
}

local STATE_COL = {
    OFF_TRACK = COL.dim,
    IN_CENTER = COL.orange,
    ON_TRACK  = COL.green,
}

-- ── Layout constants ──────────────────────────────────────────────────────────

local FRAME_W  = 210
local FULL_H   = 222   -- unified height for both tabs
local MINI_H   = 80

-- Y offsets of content panels (tabs sit at -26..-44, content below that)
local CONTENT_TOP = -46   -- first separator of each panel

-- ── Widget tables ─────────────────────────────────────────────────────────────

local W   = {}   -- shared / Silvermoon panel widgets
local WC  = {}   -- Custom panel widgets
local WT  = {}   -- Tab button widgets

local activeTab   = "silvermoon"   -- "silvermoon" | "custom"
local currentSlot = 1
local minimized   = false
local manualShow  = false

-- ── Helpers ───────────────────────────────────────────────────────────────────

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

local function MakeButton(parent, label, w, h, r, g, b, a)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    btn:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left=2, right=2, top=2, bottom=2 },
    })
    btn:SetBackdropColor(r or 0.1, g or 0.1, b or 0.14, a or 1)
    btn:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.9)
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetText(label)
    fs:SetJustifyH("CENTER")
    btn._label = fs
    return btn
end

-- ── Shared progress bar (always at bottom of frame) ──────────────────────────

local function BuildProgressBar(f)
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
end

-- ── Tab row ───────────────────────────────────────────────────────────────────

local function RefreshTabAppearance()
    local smActive = activeTab == "silvermoon"

    -- Silvermoon tab
    WT.smTab:SetBackdropColor(unpack(smActive and COL.tab_bg_act or COL.tab_bg_idle))
    WT.smTab._label:SetTextColor(unpack(smActive and COL.tab_active or COL.tab_idle))

    -- Custom tab
    WT.cusTab:SetBackdropColor(unpack((not smActive) and COL.tab_bg_act or COL.tab_bg_idle))
    WT.cusTab._label:SetTextColor(unpack((not smActive) and COL.tab_active or COL.tab_idle))
end

local function BuildTabRow(f)
    local TAB_Y = -26
    local TAB_H = 18
    local half  = (FRAME_W - 22) / 2 - 1   -- leave room for min/close buttons

    WT.smTab = MakeButton(f, L["TAB_SILVERMOON"], half, TAB_H)
    WT.smTab:SetPoint("TOPLEFT", f, "TOPLEFT", 10, TAB_Y)

    WT.cusTab = MakeButton(f, L["TAB_CUSTOM"], half, TAB_H)
    WT.cusTab:SetPoint("TOPLEFT", WT.smTab, "TOPRIGHT", 2, 0)

    WT.smTab:SetScript("OnClick", function() UI.SwitchTab("silvermoon") end)
    WT.cusTab:SetScript("OnClick", function() UI.SwitchTab("custom") end)

    RefreshTabAppearance()
end

-- ── Silvermoon panel ──────────────────────────────────────────────────────────

local function BuildSilvermoonPanel(f)
    W.smPanel = CreateFrame("Frame", nil, f)
    W.smPanel:SetPoint("TOPLEFT",     f, "TOPLEFT",  0, CONTENT_TOP)
    W.smPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 26)

    local p = W.smPanel

    HSep(p, 0)

    local sessionLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -8)
    sessionLabel:SetText(L["LABEL_SESSION"])
    sessionLabel:SetTextColor(unpack(COL.dim))

    W.session = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    W.session:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -7)
    W.session:SetText("0")
    W.session:SetTextColor(unpack(COL.green))

    HSep(p, -44)

    W.total = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.total:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -54)
    W.total:SetText(string.format(L["LABEL_TOTAL"], 0))
    W.total:SetTextColor(unpack(COL.dim))

    W.best = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.best:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -54)
    W.best:SetText(L["LABEL_BEST_NONE"])
    W.best:SetTextColor(unpack(COL.gold))

    HSep(p, -74)

    W.dir = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.dir:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -84)
    W.dir:SetText(L["STATE_OFF_TRACK"])
    W.dir:SetTextColor(unpack(COL.dim))

    W.pct = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.pct:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -84)
    W.pct:SetText("0%")
    W.pct:SetTextColor(unpack(COL.dim))

    HSep(p, -104)

    -- Mini-mode widgets (live on the main frame, not panel, for positioning simplicity)
    W.miniSession = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.miniSession:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -50)
    W.miniSession:SetText(string.format(L["LABEL_MINI_LAPS"], 0))
    W.miniSession:SetTextColor(unpack(COL.green))
    W.miniSession:Hide()

    W.miniPct = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.miniPct:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -50)
    W.miniPct:SetText("0%")
    W.miniPct:SetTextColor(unpack(COL.dim))
    W.miniPct:Hide()
end

-- ── Custom panel ──────────────────────────────────────────────────────────────

-- Forward declarations for custom panel refresh
local RefreshCustomPanel
local RefreshBoundsButtons

-- Populated once inside BuildCustomPanel; used by RefreshBoundsButtons.
local BOUNDS_BTNS = {}

local function BuildCustomPanel(f)
    WC.panel = CreateFrame("Frame", nil, f)
    WC.panel:SetPoint("TOPLEFT",     f, "TOPLEFT",  0, CONTENT_TOP)
    WC.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 26)
    WC.panel:Hide()

    local p = WC.panel

    -- ── Slot navigation row ───────────────────────────────────────────────
    HSep(p, 0)

    WC.prevBtn = MakeButton(p, "<", 22, 18, 0.1, 0.1, 0.14)
    WC.prevBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -4)
    WC.prevBtn._label:SetTextColor(unpack(COL.dim))
    WC.prevBtn:SetScript("OnClick", function()
        local slots = SilvermoonStimmingDB.customLocations
        if #slots == 0 then return end
        currentSlot = currentSlot - 1
        if currentSlot < 1 then currentSlot = #slots end
        SilvermoonStimmingDB.activeCustomSlot = currentSlot
        RefreshCustomPanel()
        SilvermoonStimmingCore.SetProfile("custom", currentSlot)
    end)

    WC.slotLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    WC.slotLabel:SetPoint("LEFT",  WC.prevBtn, "RIGHT", 4, 0)
    WC.slotLabel:SetPoint("RIGHT", p, "RIGHT", -60, 0)
    WC.slotLabel:SetJustifyH("CENTER")
    WC.slotLabel:SetWordWrap(false)
    WC.slotLabel:SetText(L["CUSTOM_NO_SLOTS"])
    WC.slotLabel:SetTextColor(unpack(COL.dim))
    -- Enable mouse so OnMouseUp / OnEnter / OnLeave fire
    WC.slotLabel:EnableMouse(true)

    WC.nextBtn = MakeButton(p, ">", 22, 18, 0.1, 0.1, 0.14)
    WC.nextBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -34, -4)
    WC.nextBtn._label:SetTextColor(unpack(COL.dim))
    WC.nextBtn:SetScript("OnClick", function()
        local slots = SilvermoonStimmingDB.customLocations
        if #slots == 0 then return end
        currentSlot = currentSlot + 1
        if currentSlot > #slots then currentSlot = 1 end
        SilvermoonStimmingDB.activeCustomSlot = currentSlot
        RefreshCustomPanel()
        SilvermoonStimmingCore.SetProfile("custom", currentSlot)
    end)

    -- Add slot button
    WC.addBtn = MakeButton(p, L["BTN_ADD_SLOT"], 22, 18, 0.12, 0.30, 0.12)
    WC.addBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -4)
    WC.addBtn._label:SetTextColor(unpack(COL.green))
    WC.addBtn:SetScript("OnClick", function()
        local slots = SilvermoonStimmingDB.customLocations
        if #slots >= 5 then
            Notify(L["CUSTOM_MAX_SLOTS"])
            return
        end
        local newSlot = {
            name           = string.format(L["CUSTOM_SLOT_NAME"], #slots + 1),
            mapID          = nil,
            center         = nil,
            boundsSize     = "medium",
            totalLaps      = 0,
            sessionLaps    = 0,
            bestLapSeconds = nil,
        }
        table.insert(slots, newSlot)
        currentSlot = #slots
        SilvermoonStimmingDB.activeCustomSlot = currentSlot
        RefreshCustomPanel()
        SilvermoonStimmingCore.SetProfile("custom", currentSlot)
    end)

    HSep(p, -26)

    -- ── Rename EditBox (hidden until slot label is clicked) ───────────────
    WC.renameBox = CreateFrame("EditBox", "SilvermoonStimmingRenameBox", p, "BackdropTemplate")
    WC.renameBox:SetSize(FRAME_W - 22, 20)
    WC.renameBox:SetPoint("TOPLEFT", p, "TOPLEFT", 11, -30)
    WC.renameBox:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left=3, right=3, top=3, bottom=3 },
    })
    WC.renameBox:SetBackdropColor(0.08, 0.08, 0.12, 1)
    WC.renameBox:SetBackdropBorderColor(unpack(COL.gold))
    WC.renameBox:SetFontObject("GameFontNormalSmall")
    WC.renameBox:SetTextColor(unpack(COL.gold))
    WC.renameBox:SetMaxLetters(40)
    WC.renameBox:SetAutoFocus(false)
    WC.renameBox:SetJustifyH("CENTER")
    WC.renameBox:Hide()

    local committing = false
    local function CommitRename()
        if committing then return end
        committing = true
        local slots = SilvermoonStimmingDB.customLocations
        if #slots == 0 then WC.renameBox:Hide() committing = false return end
        local newName = strtrim(WC.renameBox:GetText())
        WC.renameBox:Hide()
        WC.captureBtn:Show()

        if newName == "DELETE" then
            table.remove(slots, currentSlot)
            if currentSlot > #slots then currentSlot = math.max(1, #slots) end
            SilvermoonStimmingDB.activeCustomSlot = currentSlot
            committing = false
            if #slots == 0 then
                UI.SwitchTab("silvermoon")
            else
                RefreshCustomPanel()
                SilvermoonStimmingCore.SetProfile("custom", currentSlot)
            end
            return
        end

        if newName ~= "" then
            slots[currentSlot].name = newName
        end
        committing = false
        RefreshCustomPanel()
    end

    WC.renameBox:SetScript("OnEnterPressed", CommitRename)
    WC.renameBox:SetScript("OnEscapePressed", function()
        WC.renameBox:Hide()
        WC.captureBtn:Show()
    end)
    WC.renameBox:SetScript("OnEditFocusLost", CommitRename)

    -- Make slot label clickable to open rename box
    WC.slotLabel:SetScript("OnMouseUp", function()
        local slots = SilvermoonStimmingDB.customLocations
        if #slots == 0 then return end
        WC.captureBtn:Hide()
        WC.renameBox:SetText(slots[currentSlot].name or "")
        WC.renameBox:Show()
        WC.renameBox:SetFocus()
        WC.renameBox:HighlightText()
    end)
    WC.slotLabel:SetScript("OnEnter", function()
        local slots = SilvermoonStimmingDB.customLocations
        if #slots == 0 then return end
        GameTooltip:SetOwner(WC.slotLabel, "ANCHOR_TOP")
        GameTooltip:SetText(L["CUSTOM_RENAME_HINT"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    WC.slotLabel:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── Capture button ────────────────────────────────────────────────────
    WC.captureBtn = MakeButton(p, L["BTN_CAPTURE"], FRAME_W - 22, 20,
        COL.btn_cap[1], COL.btn_cap[2], COL.btn_cap[3], COL.btn_cap[4])
    WC.captureBtn:SetPoint("TOPLEFT",  p, "TOPLEFT",  11, -30)
    WC.captureBtn._label:SetTextColor(0.7, 1.0, 0.7)
    WC.captureBtn:SetScript("OnClick", function()
        local slots = SilvermoonStimmingDB.customLocations
        if #slots == 0 then return end
        local mapID, x, y = SilvermoonStimmingCore.CaptureCurrentPosition()
        if not mapID then
            Notify(L["CUSTOM_NO_POS"])
            return
        end
        local slot = slots[currentSlot]
        slot.mapID  = mapID
        slot.center = { x = x, y = y }
        -- Auto-name from zone if still default name
        local zoneName = GetZoneText()
        if zoneName and zoneName ~= "" then
            slot.name = zoneName
        end
        Notify(string.format(L["CUSTOM_CAPTURED"], slot.name, x, y))
        RefreshCustomPanel()
        SilvermoonStimmingCore.SetProfile("custom", currentSlot)
    end)

    -- ── Bounds buttons ────────────────────────────────────────────────────
    local bw = (FRAME_W - 22 - 4) / 3
    WC.boundsSmall  = MakeButton(p, L["BTN_BOUNDS_SMALL"],  bw, 18)
    WC.boundsMedium = MakeButton(p, L["BTN_BOUNDS_MEDIUM"], bw, 18)
    WC.boundsLarge  = MakeButton(p, L["BTN_BOUNDS_LARGE"],  bw, 18)

    WC.boundsSmall:SetPoint( "TOPLEFT",  p, "TOPLEFT",  11, -54)
    WC.boundsMedium:SetPoint("TOPLEFT",  WC.boundsSmall,  "TOPRIGHT", 2, 0)
    WC.boundsLarge:SetPoint( "TOPLEFT",  WC.boundsMedium, "TOPRIGHT", 2, 0)

    -- Populate module-level ref so RefreshBoundsButtons needs no per-call allocation.
    BOUNDS_BTNS.small  = WC.boundsSmall
    BOUNDS_BTNS.medium = WC.boundsMedium
    BOUNDS_BTNS.large  = WC.boundsLarge

    local function SetBoundsSize(size)
        local slots = SilvermoonStimmingDB.customLocations
        if #slots == 0 then return end
        local slot = slots[currentSlot]
        slot.boundsSize = size
        RefreshBoundsButtons(size)
        SilvermoonStimmingCore.RefreshCustomConfig(currentSlot)
    end
    WC.boundsSmall:SetScript( "OnClick", function() SetBoundsSize("small")  end)
    WC.boundsMedium:SetScript("OnClick", function() SetBoundsSize("medium") end)
    WC.boundsLarge:SetScript( "OnClick", function() SetBoundsSize("large")  end)

    HSep(p, -76)

    -- ── Session stat ──────────────────────────────────────────────────────
    local sessionLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -84)
    sessionLabel:SetText(L["LABEL_SESSION"])
    sessionLabel:SetTextColor(unpack(COL.dim))

    WC.session = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    WC.session:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -81)
    WC.session:SetText("0")
    WC.session:SetTextColor(unpack(COL.green))

    HSep(p, -104)

    WC.total = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    WC.total:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -112)
    WC.total:SetText(string.format(L["LABEL_TOTAL"], 0))
    WC.total:SetTextColor(unpack(COL.dim))

    WC.best = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    WC.best:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -112)
    WC.best:SetText(L["LABEL_BEST_NONE"])
    WC.best:SetTextColor(unpack(COL.gold))

    -- Tracking state line (dir + pct, shared with Silvermoon logic via UI.OnTick)
    HSep(p, -128)

    WC.dir = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    WC.dir:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -136)
    WC.dir:SetText(L["STATE_OFF_TRACK"])
    WC.dir:SetTextColor(unpack(COL.dim))

    WC.pct = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    WC.pct:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -136)
    WC.pct:SetText("0%")
    WC.pct:SetTextColor(unpack(COL.dim))
end

-- Called after build; updates every custom-panel widget to match currentSlot.
RefreshCustomPanel = function()
    local slots = SilvermoonStimmingDB and SilvermoonStimmingDB.customLocations or {}
    local count = #slots

    local hasSlots = count > 0
    WC.prevBtn:SetEnabled(hasSlots)
    WC.nextBtn:SetEnabled(hasSlots)
    WC.captureBtn:SetEnabled(hasSlots)

    if not hasSlots then
        WC.slotLabel:SetText(L["CUSTOM_NO_SLOTS"])
        WC.slotLabel:SetTextColor(unpack(COL.dim))
        WC.captureBtn:SetAlpha(0.4)
        WC.boundsSmall:SetAlpha(0.3)
        WC.boundsMedium:SetAlpha(0.3)
        WC.boundsLarge:SetAlpha(0.3)
        WC.session:SetText("0")
        WC.total:SetText(string.format(L["LABEL_TOTAL"], 0))
        WC.best:SetText(L["LABEL_BEST_NONE"])
        WC.dir:SetText(L["STATE_OFF_TRACK"])
        WC.pct:SetText("0%")
        return
    end

    -- Clamp slot index
    if currentSlot > count then currentSlot = count end
    if currentSlot < 1     then currentSlot = 1     end

    local slot = slots[currentSlot]

    -- Slot label: "Name  (2/4)"
    local label = string.format(L["CUSTOM_SLOT_LABEL"], slot.name, currentSlot, count)
    WC.slotLabel:SetText(label)
    WC.slotLabel:SetTextColor(unpack(COL.gold))

    -- Capture button label: Capture vs Recapture
    WC.captureBtn._label:SetText(slot.center and L["BTN_RECAPTURE"] or L["BTN_CAPTURE"])
    WC.captureBtn:SetAlpha(1.0)

    -- Bounds buttons
    local hasCenter = slot.center ~= nil
    WC.boundsSmall:SetAlpha( hasCenter and 1.0 or 0.4)
    WC.boundsMedium:SetAlpha(hasCenter and 1.0 or 0.4)
    WC.boundsLarge:SetAlpha( hasCenter and 1.0 or 0.4)
    WC.boundsSmall:SetEnabled( hasCenter)
    WC.boundsMedium:SetEnabled(hasCenter)
    WC.boundsLarge:SetEnabled( hasCenter)
    RefreshBoundsButtons(slot.boundsSize or "medium")

    -- Stats
    WC.session:SetText(tostring(slot.sessionLaps or 0))
    WC.total:SetText(string.format(L["LABEL_TOTAL"], slot.totalLaps or 0))
    WC.best:SetText(slot.bestLapSeconds
        and string.format(L["LABEL_BEST"], slot.bestLapSeconds)
        or  L["LABEL_BEST_NONE"])
end

RefreshBoundsButtons = function(active)
    for size, btn in pairs(BOUNDS_BTNS) do
        if size == active then
            btn:SetBackdropColor(unpack(COL.btn_bounds_a))
            btn._label:SetTextColor(unpack(COL.blue))
        else
            btn:SetBackdropColor(unpack(COL.btn_bounds))
            btn._label:SetTextColor(unpack(COL.dim))
        end
    end
end

-- ── Tab switching ─────────────────────────────────────────────────────────────

function UI.SwitchTab(tab)
    activeTab = tab
    SilvermoonStimmingDB.activeTab = tab
    RefreshTabAppearance()
    if not minimized then W.frame:SetHeight(FULL_H) end

    if tab == "silvermoon" then
        W.smPanel:Show()
        WC.panel:Hide()
        SilvermoonStimmingCore.SetProfile("silvermoon")
        UI.Refresh(SilvermoonStimmingDB)
    else
        W.smPanel:Hide()
        WC.panel:Show()
        local slots = SilvermoonStimmingDB.customLocations
        currentSlot = SilvermoonStimmingDB.activeCustomSlot or 1
        if currentSlot > #slots then currentSlot = math.max(1, #slots) end
        RefreshCustomPanel()
        if #slots > 0 then
            SilvermoonStimmingCore.SetProfile("custom", currentSlot)
        end
    end
end

-- ── Build ─────────────────────────────────────────────────────────────────────

local function Build()
    local f = CreateFrame("Frame", "SilvermoonStimmingHUD", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FULL_H)
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

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    title:SetText(L["HUD_TITLE"])
    W.title = title

    -- Status dot
    W.dot = f:CreateTexture(nil, "OVERLAY")
    W.dot:SetSize(8, 8)
    W.dot:SetPoint("LEFT", title, "RIGHT", 6, 0)
    SetCol(W.dot, COL.dim)

    -- Minimize button
    local minBtn = CreateFrame("Button", nil, f)
    minBtn:SetSize(16, 16)
    minBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -6)
    minBtn:SetNormalFontObject("GameFontNormalSmall")
    minBtn:SetText(L["BTN_MINIMIZE"])
    minBtn:GetFontString():SetTextColor(0.7, 0.7, 0.7)
    minBtn:SetScript("OnClick", function() UI.ToggleMinimize() end)
    minBtn:SetScript("OnEnter", function() minBtn:GetFontString():SetTextColor(1,1,1) end)
    minBtn:SetScript("OnLeave", function() minBtn:GetFontString():SetTextColor(0.7,0.7,0.7) end)
    W.minBtn = minBtn

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    closeBtn:SetNormalFontObject("GameFontNormalSmall")
    closeBtn:SetText(L["BTN_CLOSE"])
    closeBtn:GetFontString():SetTextColor(0.7, 0.7, 0.7)
    closeBtn:SetScript("OnClick", function()
        manualShow = false
        f:Hide()
    end)
    closeBtn:SetScript("OnEnter", function() closeBtn:GetFontString():SetTextColor(1, 0.3, 0.3) end)
    closeBtn:SetScript("OnLeave", function() closeBtn:GetFontString():SetTextColor(0.7, 0.7, 0.7) end)
    W.closeBtn = closeBtn

    -- Tab row, panels, progress bar
    BuildTabRow(f)
    BuildSilvermoonPanel(f)
    BuildCustomPanel(f)
    BuildProgressBar(f)
end

-- ── Minimize / Restore ────────────────────────────────────────────────────────

-- Applies the current value of `minimized` to all frame elements.
-- Call any time the frame is about to be shown to guarantee consistency.
local function ApplyMinimizedState()
    if not W.frame or not W.barBg then return end
    if minimized then
        W.frame:SetHeight(MINI_H)
        W.smPanel:Hide()
        WC.panel:Hide()
        WT.smTab:Hide()
        WT.cusTab:Hide()
        W.miniSession:Show()
        W.miniPct:Show()
        W.barBg:SetPoint("BOTTOMLEFT",  W.frame, "BOTTOMLEFT",  11, 6)
        W.barBg:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", -11, 6)
        W.minBtn:SetText(L["BTN_RESTORE"])
    else
        W.frame:SetHeight(FULL_H)
        W.miniSession:Hide()
        W.miniPct:Hide()
        WT.smTab:Show()
        WT.cusTab:Show()
        RefreshTabAppearance()
        if activeTab == "silvermoon" then
            W.smPanel:Show()
            WC.panel:Hide()
        else
            WC.panel:Show()
            W.smPanel:Hide()
        end
        W.barBg:SetPoint("BOTTOMLEFT",  W.frame, "BOTTOMLEFT",  11, 11)
        W.barBg:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", -11, 11)
        W.minBtn:SetText(L["BTN_MINIMIZE"])
    end
end

function UI.ToggleMinimize()
    minimized = not minimized
    ApplyMinimizedState()
end

-- ── Zone-based auto show/hide ─────────────────────────────────────────────────

function UI.OnZoneEnter()
    if not W.frame or manualShow then return end
    ApplyMinimizedState()
    W.frame:Show()
end

function UI.OnZoneLeave()
    if W.frame and not manualShow then W.frame:Hide() end
end

-- ── Public callbacks ──────────────────────────────────────────────────────────

function UI.Init(db)
    if not W.frame then Build() end
    activeTab   = db.activeTab or "silvermoon"
    currentSlot = db.activeCustomSlot or 1
    UI.Refresh(db)
    -- Restore Core profile so IsInActiveZone() is correct before the first zone event.
    if activeTab == "custom" and currentSlot <= #db.customLocations
    and db.customLocations[currentSlot].center then
        SilvermoonStimmingCore.SetProfile("custom", currentSlot)
        RefreshCustomPanel()
    else
        activeTab = "silvermoon"   -- fall back if slot is empty or gone
        SilvermoonStimmingCore.SetProfile("silvermoon")
    end
    -- Refresh tab appearance AFTER any fallback so highlight always matches reality.
    RefreshTabAppearance()
    W.frame:Hide()
end

function UI.Toggle()
    if not W.frame then return end
    if W.frame:IsShown() then
        manualShow = false
        W.frame:Hide()
    else
        manualShow = true
        ApplyMinimizedState()
        W.frame:Show()
    end
end

-- Refresh the Silvermoon tab stats from db.
function UI.Refresh(db)
    if not W.session then return end
    W.session:SetText(tostring(db.sessionLaps or 0))
    W.miniSession:SetText(string.format(L["LABEL_MINI_LAPS"], db.sessionLaps or 0))
    W.total:SetText(string.format(L["LABEL_TOTAL"], db.totalLaps or 0))
    W.best:SetText(db.bestLapSeconds
        and string.format(L["LABEL_BEST"], db.bestLapSeconds)
        or  L["LABEL_BEST_NONE"])
end

function UI.OnStateChange(newState)
    if not W.dot then return end
    local col = STATE_COL[newState] or COL.dim
    SetCol(W.dot, col)

    local dirW = (activeTab == "silvermoon") and W.dir   or WC.dir
    local pctW = (activeTab == "silvermoon") and W.pct   or WC.pct

    if newState == "OFF_TRACK" then
        if dirW then dirW:SetText(L["STATE_OFF_TRACK"]) ; dirW:SetTextColor(unpack(COL.dim)) end
        if pctW then pctW:SetText("0%")                 ; pctW:SetTextColor(unpack(COL.dim)) end
        if W.bar then SetCol(W.bar, COL.dim) end
    elseif newState == "IN_CENTER" then
        if dirW then dirW:SetText(L["STATE_IN_CENTER"]) ; dirW:SetTextColor(unpack(COL.orange)) end
        if W.bar then SetCol(W.bar, COL.orange) end
    end
end

function UI.OnTick(accumulatedAngle, direction)
    if not W.bar or not W.barBg then return end

    local fraction = (math.abs(accumulatedAngle) % TWO_PI) / TWO_PI
    local bgW      = W.barBg:GetWidth()
    W.bar:SetWidth(math.max(1, bgW * fraction))

    local pct  = math.floor(fraction * 100)
    local isSM = activeTab == "silvermoon"
    local dirW = isSM and W.dir   or WC.dir
    local pctW = isSM and W.pct   or WC.pct

    -- Only update the visible tab's pct label; the hidden one stays
    -- stale until the next tab switch which calls Refresh/RefreshCustomPanel.
    if pctW    then pctW:SetText(pct .. "%") end
    if W.miniPct then W.miniPct:SetText(pct .. "%") end

    -- direction is always 1 (CW), -1 (CCW), or 0 (none) — compare directly.
    if direction > 0 then
        if dirW then dirW:SetText(L["STATE_CW"])      ; dirW:SetTextColor(unpack(COL.blue))   end
        if pctW then pctW:SetTextColor(unpack(COL.blue))   end
        if W.miniPct then W.miniPct:SetTextColor(unpack(COL.blue)) end
        SetCol(W.bar, COL.blue)
    elseif direction < 0 then
        if dirW then dirW:SetText(L["STATE_CCW"])     ; dirW:SetTextColor(unpack(COL.orange)) end
        if pctW then pctW:SetTextColor(unpack(COL.orange)) end
        if W.miniPct then W.miniPct:SetTextColor(unpack(COL.orange)) end
        SetCol(W.bar, COL.orange)
    else
        if dirW then dirW:SetText(L["STATE_STARTING"]) ; dirW:SetTextColor(unpack(COL.dim))   end
        if pctW then pctW:SetTextColor(unpack(COL.dim))   end
        if W.miniPct then W.miniPct:SetTextColor(unpack(COL.dim)) end
        SetCol(W.bar, COL.dim)
    end
end

function UI.OnLapComplete(db)
    -- Refresh whichever panel is active
    if activeTab == "silvermoon" then
        UI.Refresh(db)
        if W.session then W.session:SetTextColor(1, 1, 1) end
        if W.miniSession then W.miniSession:SetTextColor(1, 1, 1) end
        C_Timer.After(0.4, function()
            if W.session     then W.session:SetTextColor(unpack(COL.green))     end
            if W.miniSession then W.miniSession:SetTextColor(unpack(COL.green)) end
        end)
    else
        RefreshCustomPanel()
        if WC.session then WC.session:SetTextColor(1, 1, 1) end
        C_Timer.After(0.4, function()
            if WC.session then WC.session:SetTextColor(unpack(COL.green)) end
        end)
    end

    if not W.frame then return end
    W.frame:SetBackdropBorderColor(unpack(COL.border_lap))
    C_Timer.After(1.8, function()
        if W.frame then W.frame:SetBackdropBorderColor(unpack(COL.border_idle)) end
    end)
end
