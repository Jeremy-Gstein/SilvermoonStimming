-- ============================================================
--  Locales/enUS.lua
--  Default locale — all other locale files fall back to these.
--  To add a new language, create e.g. Locales/frFR.lua and
--  only override the keys that differ.
-- ============================================================

local ADDON = "SilvermoonStimming"

-- Shared locale table. Populated by each locale file.
-- Using rawget fallback so missing keys in other locales
-- silently return the enUS string rather than nil.
SilvermoonStimmingL = setmetatable({}, {
    __index = function(t, k)
        return k   -- return the key itself as last-resort fallback
    end
})

local L = SilvermoonStimmingL

-- ── System / chat ──────────────────────────────────────────────────────────
L["LOADED"]              = "|cff00ff7fSilvermoonStimming|r loaded.  |cff888888/lt for commands|r"
L["ON_TRACK"]            = "|cff00ff7fSilvermoonStimming:|r On track."
L["LEFT_TRACK"]          = "|cff00ff7fSilvermoonStimming:|r Left track."
L["DIR_REVERSED"]        = "|cff00ff7fSilvermoonStimming:|r Direction reversed — resetting lap angle."
L["RESET_DONE"]          = "|cff00ff7fSilvermoonStimming:|r Reset."
L["NO_LAPS_YET"]         = "|cff00ff7fSilvermoonStimming:|r No laps yet."
L["NO_POSITION"]         = "|cff00ff7fDebug:|r No position (wrong map)."
L["HELP_LINE"]           = "|cff00ff7fSilvermoonStimming|r  /lt debug  /lt best  /lt reset  /lt toggle"

-- ── Lap completion ────────────────────────────────────────────────────────
-- %d = lap number, %s = direction label, %.1f = seconds
L["LAP_COMPLETE"]        = "|cff00ff7fSilvermoonStimming:|r Lap |cffffff00#%d|r  %s  Time: |cffffff00%.1fs|r"
L["LAP_TOO_FAST"]        = "|cffff4444SilvermoonStimming:|r Lap too fast (%.1fs) -- ignored."
L["DIR_CW"]              = "|cff00ccff->  CW|r"
L["DIR_CCW"]             = "|cffff9900<- CCW|r"

-- ── Debug / slash ─────────────────────────────────────────────────────────
-- pos=(%.4f,%.4f)  zone=%s  angle=%.1f  acc=%.1f  progress=%.0f%%  session=%d
L["DEBUG_LINE"]          = "|cff00ff7fDebug:|r pos=(%.4f,%.4f)  zone=%s  angle=%.1f  acc=%.1f  progress=%.0f%%  session=%d"
-- Best: %.1fs  Total: %d
L["BEST_LINE"]           = "|cff00ff7fSilvermoonStimming:|r Best: |cffffff00%.1fs|r  Total: %d"

-- ── HUD — title & buttons ─────────────────────────────────────────────────
L["HUD_TITLE"]           = "|cffffd700Silvermoon|r |cffaaaaaa Stimming|r"
L["BTN_MINIMIZE"]        = "-"
L["BTN_RESTORE"]         = "+"
L["BTN_CLOSE"]           = "x"

-- ── HUD — labels ─────────────────────────────────────────────────────────
L["LABEL_SESSION"]       = "SESSION"
L["LABEL_TOTAL"]         = "Total: %d"
L["LABEL_BEST"]          = "Best: %.1fs"
L["LABEL_BEST_NONE"]     = "Best: --"
-- %d laps (mini mode)
L["LABEL_MINI_LAPS"]     = "%d laps"

-- ── HUD — state strings ───────────────────────────────────────────────────
L["STATE_OFF_TRACK"]     = "Off track"
L["STATE_IN_CENTER"]     = "In center"
L["STATE_STARTING"]      = "Starting..."
L["STATE_CW"]            = "-> Clockwise"
L["STATE_CCW"]           = "<- Counter-CW"

-- ── HUD — tabs ────────────────────────────────────────────────────────────
L["TAB_SILVERMOON"]      = "Silvermoon"
L["TAB_CUSTOM"]          = "Custom"

-- ── Custom location panel ─────────────────────────────────────────────────
L["CUSTOM_NO_SLOTS"]     = "No custom locations saved."
L["CUSTOM_NO_CENTER"]    = "No location set."
L["CUSTOM_SLOT_NAME"]    = "Custom %d"
L["BTN_CAPTURE"]         = "Set Location"
L["BTN_RECAPTURE"]       = "Recapture"
L["BTN_ADD_SLOT"]        = "+"
L["BTN_BOUNDS_SMALL"]    = "Small"
L["BTN_BOUNDS_MEDIUM"]   = "Medium"
L["BTN_BOUNDS_LARGE"]    = "Large"
L["CUSTOM_CAPTURED"]     = "|cff00ff7fSilvermoonStimming:|r Location set — %s (%.4f, %.4f)"
L["CUSTOM_MAX_SLOTS"]    = "|cffff4444SilvermoonStimming:|r Maximum 5 custom locations reached."
L["CUSTOM_SLOT_LABEL"]   = "%s  |cff888888(%d/%d)|r"
L["CUSTOM_RENAME_HINT"]  = "Click to rename  |cffff4444(type DELETE to remove)|r"
L["CUSTOM_NO_POS"]       = "|cffff4444SilvermoonStimming:|r Cannot capture position — move to a valid map area first."
