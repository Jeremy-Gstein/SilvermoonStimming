-- ============================================================
--  SilvermoonStimming_Config.lua
-- ============================================================

SilvermoonStimmingConfig = {

    -- ── Map ──────────────────────────────────────────────────────────────────
    MAP_ID = 2393,
    CENTER = { x = 0.45585238933563, y = 0.70795303583145 },

    -- ── Outer boundary: axis-aligned box + buffer ─────────────────────────
    -- Calibrated from in-game cardinal points.
    -- OUTER_BUFFER expands the box on all 4 sides to prevent corner clipping.
    OUTER_BOX = {
        minX = 0.3936,
        maxX = 0.5181,
        minY = 0.6179,
        maxY = 0.8042,
    },
    OUTER_BUFFER = 0.018,

    -- ── Inner exclusion: ellipse fitted to inner calibration points ────────
    -- rx = half the east-west span of the inner ring  (0.4870 - 0.4217) / 2
    -- ry = half the north-south span                  (0.7618 - 0.6649) / 2
    -- Ellipse gives smooth rounded corners vs the clipping rectangular box.
    INNER_ELLIPSE = {
        rx = 0.0355,   -- horizontal semi-axis
        ry = 0.0510,   -- vertical semi-axis
    },

    -- ── Behaviour ─────────────────────────────────────────────────────────
    POLL_RATE          = 0.25,
    TELEPORT_THRESHOLD = math.pi / 2,  -- delta > 90 deg = discard
    MIN_LAP_SECONDS    = 10,

    -- Direction enum (do not change values)
    DIR_NONE = 0,
    DIR_CW   = 1,
    DIR_CCW  = -1,
}
