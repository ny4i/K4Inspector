-- k4inspector/validators.lua
-- This file contains all the validation functions for the K4Direct dissector.

local M = {}

-- Format frequency for display
function M.format_frequency(freq_hz)
    local freq_mhz = freq_hz / 1000000.0
    return string.format("%.6f MHz", freq_mhz)
end

-- Validate frequency range (returns warning message or nil if valid)
function M.validate_frequency(freq)
    if not freq or freq == 0 then
        return nil  -- Empty/query command
    end

    -- K4 HF range: 500 kHz to 54 MHz
    if freq < 500000 then
        return "⚠ Frequency below 500 kHz (K4 minimum)"
    end

    -- K4 with transverter: up to ~500 MHz is reasonable
    if freq > 500000000 then
        return "⚠ Frequency above 500 MHz (suspect, check transverter)"
    end

    -- Warn if frequency seems unrealistic (typo/corruption)
    if freq > 54000000 and freq < 100000000 then
        return "⚠ Frequency 54-100 MHz (unusual, verify transverter)"
    end

    return nil  -- Valid
end

-- Validate mode value (returns warning message or nil if valid)
function M.validate_mode(mode)
    if not mode then return nil end

    -- Valid K4 modes: 0-7, 9
    if mode == 8 or mode > 9 then
        return "⚠ Invalid mode value " .. mode .. " (valid: 0-7, 9)"
    end

    return nil  -- Valid
end

-- Validate data sub-mode (returns warning message or nil if valid)
function M.validate_data_submode(submode)
    if not submode then return nil end

    -- Valid data sub-modes: 0-3
    if submode > 3 then
        return "⚠ Invalid data sub-mode " .. submode .. " (valid: 0-3)"
    end

    return nil  -- Valid
end

-- Validate band number (returns warning message or nil if valid)
function M.validate_band(band)
    if not band then return nil end

    -- Valid bands: 0-10 (160m to 6m)
    if band > 10 then
        return "⚠ Invalid band " .. band .. " (valid: 0-10)"
    end

    return nil  -- Valid
end

-- Validate AGC mode (returns warning message or nil if valid)
function M.validate_agc(agc)
    if not agc then return nil end

    -- Valid AGC: 0-3 (Off, Slow, Med, Fast)
    if agc > 3 then
        return "⚠ Invalid AGC mode " .. agc .. " (valid: 0-3)"
    end

    return nil  -- Valid
end

-- Validate preamp setting (returns warning message or nil if valid)
function M.validate_preamp(preamp)
    if not preamp then return nil end

    -- Valid preamp: 0-3
    if preamp > 3 then
        return "⚠ Invalid preamp " .. preamp .. " (valid: 0-3)"
    end

    return nil  -- Valid
end

-- Validate ATU status (returns warning message or nil if valid)
function M.validate_atu(atu)
    if not atu then return nil end

    -- Valid ATU: 0-2 (Bypass, Auto, Tune)
    if atu > 2 then
        return "⚠ Invalid ATU status " .. atu .. " (valid: 0-2)"
    end

    return nil  -- Valid
end

-- Validate generic range (returns warning message or nil if valid)
function M.validate_range(value, min_val, max_val, name)
    if not value then return nil end

    if value < min_val or value > max_val then
        return string.format("⚠ %s value %d out of range (%d-%d)", name, value, min_val, max_val)
    end

    return nil  -- Valid
end

return M
