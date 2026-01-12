-- K4Direct Protocol Dissector for Wireshark
-- Elecraft K4 Direct Interface Protocol Inspector
-- Protocol: ASCII text-based commands terminated with semicolon (;)

-- Create the protocol
local k4_proto = Proto("k4direct", "K4 Direct Protocol")

-- Protocol fields
local fields = k4_proto.fields
fields.command = ProtoField.string("k4direct.command", "Command")
fields.vfo = ProtoField.string("k4direct.vfo", "VFO")
fields.full_message = ProtoField.string("k4direct.message", "Full Message")

-- IMPORTANT: Frequency field uses uint32 instead of uint64
-- ISSUE: ProtoField.uint64 causes Wireshark Lua API errors when calling TreeItem:add()
--        Error: "calling 'add' on bad self (userdata expected, got number)"
-- ROOT CAUSE: Wireshark's Lua API (as of v4.x) has issues with uint64 ProtoField types
--             in the 3-parameter form: subtree:add(field, buffer, value)
-- WORKAROUND: Use uint32 which works correctly with the Lua API
-- VALIDATION: uint32 max = 4,294,967,295 Hz = 4.2 GHz
--             K4 max frequency = 54 MHz (HF) or ~500 MHz (with XVTR)
--             uint32 is sufficient for all K4 use cases
-- TESTED: All real K4 captures parse correctly with uint32
fields.frequency = ProtoField.uint32("k4direct.frequency", "Frequency (Hz)", base.DEC)
fields.mode = ProtoField.uint8("k4direct.mode", "Mode", base.DEC)
fields.data_submode = ProtoField.uint8("k4direct.data_submode", "Data Sub-mode", base.DEC)
fields.rit_offset = ProtoField.int16("k4direct.rit_offset", "RIT Offset (Hz)", base.DEC)
fields.xit_offset = ProtoField.int16("k4direct.xit_offset", "XIT Offset (Hz)", base.DEC)
fields.rit_enabled = ProtoField.bool("k4direct.rit_enabled", "RIT Enabled")
fields.xit_enabled = ProtoField.bool("k4direct.xit_enabled", "XIT Enabled")
fields.split_enabled = ProtoField.bool("k4direct.split_enabled", "Split Enabled")
fields.tx_state = ProtoField.bool("k4direct.tx_state", "Transmitting")
fields.cw_speed = ProtoField.uint8("k4direct.cw_speed", "CW Speed (WPM)", base.DEC)
fields.cw_text = ProtoField.string("k4direct.cw_text", "CW Text")
fields.band_number = ProtoField.uint8("k4direct.band_number", "Band Number", base.DEC)
fields.filter_preset = ProtoField.uint8("k4direct.filter_preset", "Filter Preset", base.DEC)
fields.ai_level = ProtoField.uint8("k4direct.ai_level", "AI Level", base.DEC)
fields.radio_id = ProtoField.uint8("k4direct.radio_id", "Radio ID", base.DEC)
fields.active_vfo = ProtoField.string("k4direct.active_vfo", "Active VFO")
fields.scan_active = ProtoField.bool("k4direct.scan_active", "Scan Active")
fields.om_string = ProtoField.string("k4direct.om_string", "OM Option String")
fields.om_model = ProtoField.string("k4direct.om_model", "Radio Model")
fields.om_atu = ProtoField.bool("k4direct.om_atu", "ATU (KAT4)")
fields.om_pa = ProtoField.bool("k4direct.om_pa", "PA (KPA4)")
fields.om_xvtr = ProtoField.bool("k4direct.om_xvtr", "XVTR (Transverter)")
fields.om_subrx = ProtoField.bool("k4direct.om_subrx", "SUB RX (KRX4 + KDDC4)")
fields.om_hdr = ProtoField.bool("k4direct.om_hdr", "HDR MODULE (KHDR4 + KDDC4-2)")
fields.om_k40mini = ProtoField.bool("k4direct.om_k40mini", "K40 Mini")
fields.om_linear = ProtoField.bool("k4direct.om_linear", "Linear Amp")
fields.om_kpa1500 = ProtoField.bool("k4direct.om_kpa1500", "KPA1500 Amp")
fields.om_k4id = ProtoField.bool("k4direct.om_k4id", "K4 Identifier")
fields.power_output = ProtoField.uint16("k4direct.power_output", "Power Output (0.1W)", base.DEC)
fields.cw_pitch = ProtoField.uint16("k4direct.cw_pitch", "CW Pitch (Hz)", base.DEC)
fields.ag_gain = ProtoField.uint8("k4direct.ag_gain", "AF Gain", base.DEC)
fields.mg_gain = ProtoField.uint8("k4direct.mg_gain", "Mic Gain", base.DEC)
fields.rg_gain = ProtoField.uint8("k4direct.rg_gain", "RF Gain", base.DEC)
fields.cp_level = ProtoField.uint8("k4direct.cp_level", "Speech Compression", base.DEC)
fields.nb_level = ProtoField.uint8("k4direct.nb_level", "Noise Blanker", base.DEC)
fields.sm_reading = ProtoField.uint8("k4direct.sm_reading", "S-Meter", base.DEC)
fields.sq_level = ProtoField.uint8("k4direct.sq_level", "Squelch", base.DEC)
fields.agc_mode = ProtoField.uint8("k4direct.agc_mode", "AGC Mode", base.DEC)
fields.preamp = ProtoField.uint8("k4direct.preamp", "Preamp", base.DEC)
fields.attenuator = ProtoField.uint8("k4direct.attenuator", "Attenuator", base.DEC)
fields.bandwidth = ProtoField.uint16("k4direct.bandwidth", "Bandwidth (Hz)", base.DEC)
fields.antenna = ProtoField.uint8("k4direct.antenna", "Antenna", base.DEC)
fields.atu_status = ProtoField.uint8("k4direct.atu_status", "ATU Status", base.DEC)
fields.vfo_lock = ProtoField.bool("k4direct.vfo_lock", "VFO Lock")
fields.subrx_enabled = ProtoField.bool("k4direct.subrx_enabled", "Sub RX Enabled")
fields.spot_enabled = ProtoField.bool("k4direct.spot_enabled", "Spot Enabled")
fields.data_baud_rate = ProtoField.uint8("k4direct.data_baud_rate", "Data Baud Rate", base.DEC)
fields.menu_id = ProtoField.uint8("k4direct.menu_id", "Menu ID", base.DEC)
fields.menu_value = ProtoField.uint16("k4direct.menu_value", "Menu Value", base.DEC)

-- Mode value strings
local mode_names = {
    [0] = "None",
    [1] = "LSB",
    [2] = "USB",
    [3] = "CW",
    [4] = "FM",
    [5] = "AM",
    [6] = "Data",
    [7] = "CW-R",
    [9] = "Data-R"
}

-- Data sub-mode value strings
local data_submode_names = {
    [0] = "DATA A (Audio FSK)",
    [1] = "AFSK A",
    [2] = "FSK D (Direct)",
    [3] = "PSK D (Direct)"
}

-- AGC mode names
local agc_names = {
    [0] = "Off",
    [1] = "Slow",
    [2] = "Medium",
    [3] = "Fast"
}

-- Preamp names
local preamp_names = {
    [0] = "Off",
    [1] = "10dB",
    [2] = "18-20dB",
    [3] = "Dual (Main 10dB + Sub 18-20dB)"
}

-- ATU status names
local atu_names = {
    [0] = "Bypass",
    [1] = "Auto",
    [2] = "Tune"
}

-- Band names
local band_names = {
    [0] = "160m",
    [1] = "80m",
    [2] = "60m",
    [3] = "40m",
    [4] = "30m",
    [5] = "20m",
    [6] = "17m",
    [7] = "15m",
    [8] = "12m",
    [9] = "10m",
    [10] = "6m"
}

-- Data baud rate names
local baud_rate_names = {
    [0] = "45 baud (FSK)",
    [1] = "75 baud (FSK)",
    [2] = "31 baud (PSK)",
    [3] = "63 baud (PSK)"
}

-- Menu parameter names (ME command)
local menu_names = {
    [1] = "Speaker, Internal",
    [2] = "TX ALC",
    [3] = "Fan Speed Min",
    [4] = "KAT4 ATU Option",
    [5] = "KRX4 2ND RX Option",
    [6] = "KPA4 PA Option",
    [7] = "AGC Hold Time",
    [8] = "AGC Decay, Slow",
    [9] = "AGC Decay, Fast",
    [10] = "AGC Threshold",
    [11] = "AGC Attack",
    [12] = "AGC Slope",
    [13] = "AGC Noise Pulse Reject",
    [14] = "TX 2-Tone Generator",
    [15] = "TX Gain Cal via TUNE",
    [27] = "Wattmeter Cal",
    [28] = "TX Gain Cal",
    [30] = "Spectrum Trace Fill",
    [33] = "Radio Serial Number",
    [34] = "Radio Type",
    [36] = "LCD Brightness",
    [37] = "LED Brightness",
    [38] = "VFO Counts per Turn",
    [39] = "AF Limiter (AGC off)",
    [40] = "Reference Freq",
    [41] = "VFO B Different Band",
    [42] = "RIT CLR 2nd Tap Restore",
    [43] = "IP Address",
    [44] = "RIT Knob Alt. Function",
    [45] = "VFO Coarse Tuning",
    [46] = "Per-Band Power",
    [48] = "AutoRef Averaging",
    [49] = "AutoRef Debounce",
    [50] = "AutoRef Offset",
    [52] = "TX DLY, Key Out to RF Out",
    [53] = "TX Inhibit Mode",
    [54] = "Serial RS232: DTR",
    [55] = "Serial RS232: RTS",
    [57] = "Serial RS232: Baud Rate",
    [58] = "Serial USB-PC1: DTR",
    [59] = "Serial USB-PC1: RTS",
    [60] = "Serial USB-PC1: Baud Rate",
    [61] = "Serial USB-PC2: DTR",
    [62] = "Serial USB-PC2: RTS",
    [63] = "Serial USB-PC2: Baud Rate",
    [64] = "FSK Dual-Tone RX Filter",
    [65] = "Serial RS232: Auto Info",
    [66] = "Serial USB-PC1: Auto Info",
    [67] = "Serial USB-PC2: Auto Info",
    [69] = "TUNE LP (Low power TUNE)",
    [70] = "Ext. Monitor Function",
    [71] = "Ext. Monitor Location",
    [72] = "Speakers + Phones",
    [73] = "RX Auto Attenuation",
    [74] = "Mouse L/R Button QSY",
    [75] = "XVTR OUT Test",
    [76] = "XVTR Band <n> Mode",
    [77] = "XVTR Band <n> R.F.",
    [78] = "XVTR Band <n> I.F.",
    [79] = "XVTR Band <n> Offset",
    [80] = "Screen Cap File",
    [83] = "Speakers, External",
    [84] = "FSK Polarity",
    [85] = "FSK Mark-Tone",
    [86] = "XVTR Band # Select",
    [87] = "Message Repeat Interval",
    [88] = "FM Deviation, Voice",
    [89] = "FM Deviation, Tone",
    [90] = "Spectrum Freq. Marks",
    [91] = "RX 1.5 MHz High-Pass Fil.",
    [92] = "Spectrum Amplitude Units",
    [93] = "Preamp 3 (12/10/6 m)",
    [97] = "RX Dyn. Range Optimization",
    [98] = "XVTR Band <n> Power Out",
    [100] = "DIGOUT1 (ACC jack, pin 11)",
    [101] = "TX Monitor Level, Line Out",
    [102] = "RX CW IIR Filters (50-200 Hz)",
    [103] = "TX Noise Gate Threshold",
    [104] = "CW TX in SSB Mode",
    [105] = "RX Audio Mix with Sub On",
    [106] = "RX All-Mode Squelch",
    [107] = "Mouse Pointer Size, LCD",
    [108] = "TX Audio LF Cutoff, SSB",
    [109] = "Mouse Pointer Size, Ext. Mon.",
    [110] = "TX DLY, Unkey to Receive",
    [111] = "TX QSK Method",
    [112] = "TX Monitor Method, Voice",
    [113] = "RX Audio Gain Boost",
    [114] = "TX Monitor Level, Remote"
}

-- Format frequency for display
local function format_frequency(freq_hz)
    local freq_mhz = freq_hz / 1000000.0
    return string.format("%.6f MHz", freq_mhz)
end

-- =============================================================================
-- VALIDATION FUNCTIONS - Detect invalid/suspicious values
-- =============================================================================

-- Validate frequency range (returns warning message or nil if valid)
local function validate_frequency(freq)
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
local function validate_mode(mode)
    if not mode then return nil end

    -- Valid K4 modes: 0-7, 9
    if mode == 8 or mode > 9 then
        return "⚠ Invalid mode value " .. mode .. " (valid: 0-7, 9)"
    end

    return nil  -- Valid
end

-- Validate data sub-mode (returns warning message or nil if valid)
local function validate_data_submode(submode)
    if not submode then return nil end

    -- Valid data sub-modes: 0-3
    if submode > 3 then
        return "⚠ Invalid data sub-mode " .. submode .. " (valid: 0-3)"
    end

    return nil  -- Valid
end

-- Validate band number (returns warning message or nil if valid)
local function validate_band(band)
    if not band then return nil end

    -- Valid bands: 0-10 (160m to 6m)
    if band > 10 then
        return "⚠ Invalid band " .. band .. " (valid: 0-10)"
    end

    return nil  -- Valid
end

-- Validate AGC mode (returns warning message or nil if valid)
local function validate_agc(agc)
    if not agc then return nil end

    -- Valid AGC: 0-3 (Off, Slow, Med, Fast)
    if agc > 3 then
        return "⚠ Invalid AGC mode " .. agc .. " (valid: 0-3)"
    end

    return nil  -- Valid
end

-- Validate preamp setting (returns warning message or nil if valid)
local function validate_preamp(preamp)
    if not preamp then return nil end

    -- Valid preamp: 0-3
    if preamp > 3 then
        return "⚠ Invalid preamp " .. preamp .. " (valid: 0-3)"
    end

    return nil  -- Valid
end

-- Validate ATU status (returns warning message or nil if valid)
local function validate_atu(atu)
    if not atu then return nil end

    -- Valid ATU: 0-2 (Bypass, Auto, Tune)
    if atu > 2 then
        return "⚠ Invalid ATU status " .. atu .. " (valid: 0-2)"
    end

    return nil  -- Valid
end

-- Validate generic range (returns warning message or nil if valid)
local function validate_range(value, min_val, max_val, name)
    if not value then return nil end

    if value < min_val or value > max_val then
        return string.format("⚠ %s value %d out of range (%d-%d)", name, value, min_val, max_val)
    end

    return nil  -- Valid
end

-- Parse IF command (comprehensive status response)
local function parse_if_command(msg, subtree, buffer, offset)
    -- IF command format: IF[f]*****+yyyyrx*00tmvspbd1*;
    -- Position: IF 00014200000     +0000001001000301;
    --              0123456789012345678901234567890123456

    local data = msg:sub(3) -- Remove "IF" or "IF$"
    if data:sub(1,1) == "$" then
        data = data:sub(2) -- Remove "$" for VFO B
    end

    -- Spec says 36 chars, but trailing space may be trimmed
    -- Debug: show actual length
    local data_len = #data
    if data_len < 34 then
        subtree:add(fields.full_message, buffer(offset, #msg), msg .. " [len=" .. data_len .. "]")
        return "IF (incomplete, len=" .. data_len .. ")"
    end

    local pos = 1
    local info_parts = {}

    -- Frequency (11 digits)
    local freq_str = data:sub(pos, pos + 10)
    local freq = tonumber(freq_str)
    if freq then
        local freq_item = subtree:add(fields.frequency, buffer(offset + pos + 1, 11), freq)
        freq_item:append_text(" (" .. format_frequency(freq) .. ")")

        -- Validate frequency range
        local warning = validate_frequency(freq)
        if warning then
            freq_item:append_text(" " .. warning)
        end

        table.insert(info_parts, format_frequency(freq))
    end
    pos = pos + 11

    -- Skip 5 spaces
    pos = pos + 5

    -- RIT/XIT offset (sign + 4 digits)
    local sign_char = data:sub(pos, pos)
    local offset_str = data:sub(pos + 1, pos + 4)
    local offset_val = tonumber(offset_str)
    if offset_val then
        if sign_char == "-" then
            offset_val = -offset_val
        end
        subtree:add(fields.rit_offset, buffer(offset + pos + 1, 5), offset_val)
    end
    pos = pos + 5

    -- RIT enabled
    local rit_char = data:sub(pos, pos)
    local rit_enabled = (rit_char == "1")
    subtree:add(fields.rit_enabled, buffer(offset + pos + 1, 1), rit_enabled)
    pos = pos + 1

    -- XIT enabled
    local xit_char = data:sub(pos, pos)
    local xit_enabled = (xit_char == "1")
    subtree:add(fields.xit_enabled, buffer(offset + pos + 1, 1), xit_enabled)
    pos = pos + 1

    -- Skip space and "00"
    pos = pos + 3

    -- TX/RX state
    local tx_char = data:sub(pos, pos)
    local is_tx = (tx_char == "1")
    subtree:add(fields.tx_state, buffer(offset + pos + 1, 1), is_tx)
    if is_tx then
        table.insert(info_parts, "TX")
    else
        table.insert(info_parts, "RX")
    end
    pos = pos + 1

    -- Mode
    local mode_char = data:sub(pos, pos)
    local mode_val = tonumber(mode_char)
    if mode_val then
        local mode_item = subtree:add(fields.mode, buffer(offset + pos + 1, 1), mode_val)

        -- Validate mode value
        local warning = validate_mode(mode_val)
        if warning then
            mode_item:append_text(" " .. warning)
        end

        if mode_names[mode_val] then
            mode_item:append_text(" (" .. mode_names[mode_val] .. ")")
            table.insert(info_parts, mode_names[mode_val])
        end
    end
    pos = pos + 1

    -- Skip literal "0" for compatibility
    pos = pos + 1

    -- Scan active
    local scan_char = data:sub(pos, pos)
    local scan_active = (scan_char == "1")
    subtree:add(fields.scan_active, buffer(offset + pos + 1, 1), scan_active)
    pos = pos + 1

    -- Split mode
    local split_char = data:sub(pos, pos)
    local split_enabled = (split_char == "1")
    subtree:add(fields.split_enabled, buffer(offset + pos + 1, 1), split_enabled)
    pos = pos + 1

    -- Skip band (1 char)
    pos = pos + 1

    -- Data mode (0 = off, 1 = on)
    local datamode_char = data:sub(pos, pos)
    local datamode_val = tonumber(datamode_char)
    if datamode_val and datamode_val > 0 then
        local datamode_item = subtree:add(fields.data_submode, buffer(offset + pos + 1, 1), datamode_val)
        if data_submode_names[datamode_val] then
            datamode_item:append_text(" (" .. data_submode_names[datamode_val] .. ")")
        end
    end

    return "IF " .. table.concat(info_parts, ", ")
end

-- Parse OM command - Option Module info with hardware detection
-- Format: "OM APXSHML14---;" where each position indicates an option module
local function parse_om_command(data, subtree, buffer, offset, data_start)
    if #data == 0 then return "OM" end

    local option_str = data
    subtree:add(fields.om_string, buffer(offset + data_start - 1, #data), option_str)

    local modules = {}

    -- Position 0: ATU (KAT4)
    if option_str:sub(1, 1) == "A" then
        subtree:add(fields.om_atu, buffer(offset + data_start - 1, 1), true)
        table.insert(modules, "ATU")
    elseif option_str:sub(1, 1) == "-" then
        subtree:add(fields.om_atu, buffer(offset + data_start - 1, 1), false)
    end

    -- Position 1: PA (KPA4)
    if option_str:sub(2, 2) == "P" then
        subtree:add(fields.om_pa, buffer(offset + data_start, 1), true)
        table.insert(modules, "PA")
    elseif option_str:sub(2, 2) ~= "" then
        subtree:add(fields.om_pa, buffer(offset + data_start, 1), false)
    end

    -- Position 2: XVTR (Transverter)
    if option_str:sub(3, 3) == "X" then
        subtree:add(fields.om_xvtr, buffer(offset + data_start + 1, 1), true)
        table.insert(modules, "XVTR")
    elseif option_str:sub(3, 3) ~= "" then
        subtree:add(fields.om_xvtr, buffer(offset + data_start + 1, 1), false)
    end

    -- Position 3: SUB RX (KRX4 + KDDC4)
    if option_str:sub(4, 4) == "S" then
        subtree:add(fields.om_subrx, buffer(offset + data_start + 2, 1), true)
        table.insert(modules, "SUB RX")
    elseif option_str:sub(4, 4) ~= "" then
        subtree:add(fields.om_subrx, buffer(offset + data_start + 2, 1), false)
    end

    -- Position 4: HDR MODULE (KHDR4 + KDDC4-2)
    if option_str:sub(5, 5) == "H" then
        subtree:add(fields.om_hdr, buffer(offset + data_start + 3, 1), true)
        table.insert(modules, "HDR")
    elseif option_str:sub(5, 5) ~= "" then
        subtree:add(fields.om_hdr, buffer(offset + data_start + 3, 1), false)
    end

    -- Position 5: K40 Mini
    if option_str:sub(6, 6) == "M" then
        subtree:add(fields.om_k40mini, buffer(offset + data_start + 4, 1), true)
        table.insert(modules, "K40 Mini")
    elseif option_str:sub(6, 6) ~= "" then
        subtree:add(fields.om_k40mini, buffer(offset + data_start + 4, 1), false)
    end

    -- Position 6/7: Linear Amp or KPA1500
    if #option_str >= 8 then
        if option_str:sub(8, 8) == "K" then
            subtree:add(fields.om_kpa1500, buffer(offset + data_start + 6, 1), true)
            table.insert(modules, "KPA1500")
        elseif option_str:sub(8, 8) ~= "" then
            subtree:add(fields.om_kpa1500, buffer(offset + data_start + 6, 1), false)
            if option_str:sub(7, 7) == "L" then
                subtree:add(fields.om_linear, buffer(offset + data_start + 5, 1), true)
                table.insert(modules, "Linear")
            elseif option_str:sub(7, 7) ~= "" then
                subtree:add(fields.om_linear, buffer(offset + data_start + 5, 1), false)
            end
        end
    end

    -- Position 8: K4 Identifier (4 for basic, D for K4D high-performance DDC)
    if #option_str >= 9 then
        if option_str:sub(9, 9) == "4" then
            subtree:add(fields.om_k4id, buffer(offset + data_start + 7, 1), true)
        end
    end

    -- Determine radio model based on options
    local radio_model = "K4"
    if #option_str >= 10 and option_str:sub(10, 10) == "D" then
        radio_model = "K4D"  -- High-performance DDC version
        if option_str:sub(5, 5) == "H" then
            radio_model = "K4HD"  -- K4D with HDR module
        end
    end

    subtree:add(fields.om_model, buffer(offset, #data + data_start - 1), radio_model)

    local info = "OM " .. radio_model
    if #modules > 0 then
        info = info .. " [" .. table.concat(modules, ", ") .. "]"
    end

    return info
end

-- =============================================================================
-- PARSER FUNCTIONS - Table-driven architecture
-- Each parser follows signature: parse_XXX(cmd, data, msg_subtree, buffer, offset, data_start)
-- Returns: info string for display
-- =============================================================================

-- Parse frequency command (FA, FB)
local function parse_frequency(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data == 11 then
        local freq = tonumber(data)
        if freq then
            local freq_item = msg_subtree:add(fields.frequency, buffer(offset + data_start - 1, 11), freq)
            freq_item:append_text(" (" .. format_frequency(freq) .. ")")

            -- Validate frequency range
            local warning = validate_frequency(freq)
            if warning then
                freq_item:append_text(" " .. warning)
            end

            return cmd .. " " .. format_frequency(freq)
        end
    end
    return cmd
end

-- Parse boolean command (RT, XT, FT, LK, SB, SP, etc)
local function parse_boolean(cmd, data, field, on_text, off_text)
    return function(c, d, subtree, buffer, offset, data_start)
        local enabled = (d == "1")
        subtree:add(field, buffer(offset + data_start - 1, #d), enabled)
        return c .. " " .. (enabled and (on_text or "On") or (off_text or "Off"))
    end
end

-- Parse numeric value with unit suffix
local function parse_numeric(cmd, data, field, unit, scale)
    return function(c, d, subtree, buffer, offset, data_start)
        local val = tonumber(d)
        if val then
            subtree:add(field, buffer(offset + data_start - 1, #d), val)
            if scale then val = val * scale end
            return c .. " " .. val .. (unit or "")
        end
        return c
    end
end

-- Parse numeric value with name lookup
-- validator: optional validation function that returns warning message or nil
local function parse_named_value(cmd, data, field, names, validator)
    return function(c, d, subtree, buffer, offset, data_start)
        local val = tonumber(d)
        if val then
            local item = subtree:add(field, buffer(offset + data_start - 1, #d), val)

            -- Validate if validator provided
            if validator then
                local warning = validator(val)
                if warning then
                    item:append_text(" " .. warning)
                end
            end

            if names[val] then
                item:append_text(" (" .. names[val] .. ")")
                return c .. " " .. names[val]
            end
            return c .. " " .. val
        end
        return c
    end
end

-- Parse offset command (RO - RIT/XIT offset)
local function parse_offset(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 5 then
        local sign_char = data:sub(1, 1)
        local offset_str = data:sub(2, 5)
        local offset_val = tonumber(offset_str)
        if offset_val then
            if sign_char == "-" then
                offset_val = -offset_val
            end
            msg_subtree:add(fields.rit_offset, buffer(offset + data_start - 1, #data), offset_val)
            return cmd .. " " .. offset_val .. " Hz"
        end
    end
    return cmd
end

-- Parse raw data (just show the data)
local function parse_raw(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data > 0 then
        msg_subtree:add(fields.full_message, buffer(offset + data_start - 1, #data), data)
        return cmd .. " " .. data
    end
    return cmd
end

-- Parse no-data command (TX, RX, UP, DN, RC)
local function parse_no_data(cmd, description)
    return function(c, d, subtree, buffer, offset, data_start)
        return description
    end
end

-- Parse CW text command (KY)
local function parse_cw_text(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data > 1 then
        local cw_text = data:sub(2) -- Skip leading space
        msg_subtree:add(fields.cw_text, buffer(offset + data_start, #cw_text), cw_text)
        return cmd .. ' "' .. cw_text .. '"'
    end
    return cmd
end

-- Parse power output (PO - tenths of watts)
local function parse_power(cmd, data, msg_subtree, buffer, offset, data_start)
    local power = tonumber(data)
    if power then
        msg_subtree:add(fields.power_output, buffer(offset + data_start - 1, #data), power)
        return string.format("PO %.1fW", power / 10.0)
    end
    return cmd
end

-- Parse ID command with K4 detection
local function parse_id(cmd, data, msg_subtree, buffer, offset, data_start)
    local radio_id = tonumber(data)
    if radio_id then
        local id_item = msg_subtree:add(fields.radio_id, buffer(offset + data_start - 1, #data), radio_id)
        if radio_id == 17 then
            id_item:append_text(" (K4)")
            return "ID K4"
        end
        return "ID " .. radio_id
    end
    return cmd
end

-- Parse ME command (Menu Parameter)
-- Format: MEiiii.nnnn; where iiii=menu ID, nnnn=value
local function parse_menu(cmd, data, msg_subtree, buffer, offset, data_start)
    local dot_pos = data:find("%.")
    if dot_pos and #data >= dot_pos then
        local menu_id_str = data:sub(1, dot_pos - 1)
        local menu_val_str = data:sub(dot_pos + 1)

        local menu_id = tonumber(menu_id_str)
        local menu_val = tonumber(menu_val_str)

        if menu_id and menu_val then
            -- Add menu ID field
            local id_item = msg_subtree:add(fields.menu_id, buffer(offset + data_start - 1, #menu_id_str), menu_id)
            if menu_names[menu_id] then
                id_item:append_text(" (" .. menu_names[menu_id] .. ")")
            end

            -- Add menu value field
            msg_subtree:add(fields.menu_value, buffer(offset + data_start - 1 + dot_pos, #menu_val_str), menu_val)

            -- Build info string
            local info = "ME "
            if menu_names[menu_id] then
                info = info .. menu_names[menu_id] .. " = " .. menu_val
            else
                info = info .. menu_id .. " = " .. menu_val
            end

            return info
        end
    end
    return cmd
end

-- =============================================================================
-- COMMAND REGISTRY - Maps command codes to parser functions
-- =============================================================================

local command_parsers = {
    -- Frequency
    FA = parse_frequency,
    FB = parse_frequency,

    -- Mode & Data
    MD = parse_named_value("MD", nil, fields.mode, mode_names, validate_mode),
    DT = parse_named_value("DT", nil, fields.data_submode, data_submode_names, validate_data_submode),

    -- RIT/XIT
    RO = parse_offset,
    RT = parse_boolean("RT", nil, fields.rit_enabled),
    XT = parse_boolean("XT", nil, fields.xit_enabled),
    RC = parse_no_data("RC", "RC (Clear RIT/XIT)"),

    -- Split & VFO
    FT = parse_boolean("FT", nil, fields.split_enabled),
    LK = parse_boolean("LK", nil, fields.vfo_lock),
    UP = parse_no_data("UP", "UP VFO Up"),
    DN = parse_no_data("DN", "DN VFO Down"),

    -- TX/RX
    TX = parse_no_data("TX", "TX (Transmit)"),
    RX = parse_no_data("RX", "RX (Receive)"),
    TS = parse_boolean("TS", nil, fields.tx_state),

    -- CW
    KS = parse_numeric("KS", nil, fields.cw_speed, " WPM"),
    KY = parse_cw_text,
    CW = parse_numeric("CW", nil, fields.cw_pitch, " Hz"),

    -- Band & Filter
    BN = parse_named_value("BN", nil, fields.band_number, band_names, validate_band),
    FP = parse_numeric("FP", nil, fields.filter_preset),

    -- Gain Controls
    AG = parse_numeric("AG", nil, fields.ag_gain),
    MG = parse_numeric("MG", nil, fields.mg_gain),
    RG = parse_numeric("RG", nil, fields.rg_gain),
    CP = parse_numeric("CP", nil, fields.cp_level),
    NB = parse_numeric("NB", nil, fields.nb_level),
    SQ = parse_numeric("SQ", nil, fields.sq_level),

    -- Signal Processing
    GT = parse_named_value("GT", nil, fields.agc_mode, agc_names, validate_agc),
    PA = parse_named_value("PA", nil, fields.preamp, preamp_names, validate_preamp),
    RA = parse_numeric("RA", nil, fields.attenuator, "dB"),
    BW = parse_numeric("BW", nil, fields.bandwidth, " Hz"),

    -- Antenna & ATU
    AN = parse_numeric("AN", nil, fields.antenna),
    AR = parse_numeric("AR", nil, fields.antenna),
    AT = parse_named_value("AT", nil, fields.atu_status, atu_names, validate_atu),

    -- Power & Monitoring
    PO = parse_power,
    SM = parse_numeric("SM", nil, fields.sm_reading),

    -- Sub Receiver & Features
    SB = parse_boolean("SB", nil, fields.subrx_enabled),
    SP = parse_boolean("SP", nil, fields.spot_enabled),

    -- Configuration & Status
    AI = parse_numeric("AI", nil, fields.ai_level),
    ID = parse_id,

    -- Data mode
    DR = parse_named_value("DR", nil, fields.data_baud_rate, baud_rate_names),

    -- Raw data commands
    DA = parse_raw,
    SI = parse_raw,
    PS = parse_raw,
    AB = parse_raw,
    AF = parse_raw,
    DM = parse_raw,
    FC = parse_raw,

    -- Menu Parameter
    ME = parse_menu,

    -- Missing commands from real capture (add as raw for now)
    AP = parse_raw, -- Auto Peak
    TD = parse_raw, -- TX Delay
    NR = parse_raw, -- Noise Reduction
    NM = parse_raw, -- Notch Mode
    NA = parse_raw, -- Notch Auto
    MA = parse_raw, -- Manual Notch
    IS = parse_raw, -- IF Shift
    VI = parse_raw, -- Voice Input
    VG = parse_raw, -- VOX Gain
    TG = parse_raw, -- TX Gain
    TE = parse_raw, -- TX Enable
    TA = parse_raw, -- TX Antenna
    SD = parse_raw, -- CW Sidetone
    RE = parse_raw, -- Receiver Enable
    PC = parse_raw, -- Power Control
    MS = parse_raw, -- Monitor/Sidetone
    MI = parse_raw, -- Mic Input
    LO = parse_raw, -- Lock
    LI = parse_raw, -- Line Input
    KP = parse_raw, -- Keyer Paddle
    FX = parse_raw, -- Fixed/Tracking
    ES = parse_raw, -- Error Status
    DV = parse_raw, -- Diversity
    DO = parse_raw, -- Data Output
    BI = parse_raw, -- Band Info
    VX = parse_raw, -- VOX
    PL = parse_raw, -- PL Tone
    FI = parse_raw, -- Filter
}

-- Parse individual K4 command using table-driven dispatch
local function parse_k4_command(msg, msg_subtree, buffer, offset)
    if #msg < 2 then
        msg_subtree:add(fields.full_message, buffer(offset, #msg), msg)
        return msg
    end

    -- Check for # commands (panadapter/display commands)
    if msg:sub(1, 1) == "#" then
        local cmd_end = 2
        while cmd_end <= #msg do
            local c = msg:sub(cmd_end, cmd_end)
            if c:match("[0-9%+%-/]") then break end
            cmd_end = cmd_end + 1
        end
        local cmd = msg:sub(1, cmd_end - 1)
        local data = msg:sub(cmd_end)

        msg_subtree:add(fields.command, buffer(offset, #cmd), cmd)
        if #data > 0 then
            msg_subtree:add(fields.full_message, buffer(offset + #cmd, #data), data)
        end
        return cmd .. " " .. data
    end

    -- Extract command (2 letters)
    local cmd = msg:sub(1, 2)
    local vfo = "VFO A"
    local data_start = 3

    -- Check for VFO B marker ($)
    if #msg >= 3 and msg:sub(3, 3) == "$" then
        vfo = "VFO B"
        data_start = 4
    end

    local data = msg:sub(data_start)

    -- Add command and VFO
    msg_subtree:add(fields.command, buffer(offset, 2), cmd)
    msg_subtree:add(fields.vfo, buffer(offset, data_start - 1), vfo)

    -- Special cases that need different call signatures
    local info
    if cmd == "IF" then
        info = parse_if_command(msg, msg_subtree, buffer, offset)
    elseif cmd == "OM" then
        info = parse_om_command(data, msg_subtree, buffer, offset, data_start)
    else
        -- Lookup parser in registry
        local parser = command_parsers[cmd]
        if parser then
            info = parser(cmd, data, msg_subtree, buffer, offset, data_start)
        else
            -- Unknown command - show raw data
            if #data > 0 then
                msg_subtree:add(fields.full_message, buffer(offset + data_start - 1, #data), data)
            end
            info = cmd
        end
    end

    if vfo == "VFO B" then
        info = info .. " (VFO B)"
    end

    return info
end

-- Main dissector function
function k4_proto.dissector(buffer, pinfo, tree)
    -- Set protocol column
    pinfo.cols.protocol = "K4Direct"

    -- Get buffer length
    local length = buffer:len()
    if length == 0 then return end

    -- Get the buffer as a string
    local data = buffer():string()

    -- Create protocol tree
    local subtree = tree:add(k4_proto, buffer(), "K4 Direct Protocol")

    -- Parse multiple commands in the packet (semicolon-delimited)
    local offset = 0
    local info_parts = {}

    for msg in data:gmatch("([^;]+)") do
        if #msg > 0 then
            local msg_len = #msg + 1 -- Include semicolon

            -- Check if we have enough buffer for the full message (prevents Range out of bounds)
            local actual_len = math.min(msg_len, length - offset)
            if actual_len > 0 then
                local msg_subtree = subtree:add(k4_proto, buffer(offset, actual_len), "Command: " .. msg .. ";")
                local info = parse_k4_command(msg, msg_subtree, buffer, offset)
                table.insert(info_parts, info)
            end

            offset = offset + msg_len
        end
    end

    -- Set info column
    if #info_parts > 0 then
        pinfo.cols.info = table.concat(info_parts, ", ")
    else
        pinfo.cols.info = "K4 Direct Protocol"
    end
end

-- Heuristic dissector to auto-detect K4 traffic on unknown ports
local function k4_heuristic(buffer, pinfo, tree)
    local length = buffer:len()
    if length == 0 then return false end

    local data = buffer():string()

    -- Check for common K4 commands
    local k4_patterns = {
        "^FA", "^FB", "^MD", "^IF", "^BN", "^KS", "^RT",
        "^XT", "^AG", "^RG", "^MG", "^OM", "^ID", "^AI",
        "^#"  -- Panadapter commands
    }

    for _, pattern in ipairs(k4_patterns) do
        if data:match(pattern) then
            -- Looks like K4 protocol, dissect it
            k4_proto.dissector(buffer, pinfo, tree)
            return true
        end
    end

    return false
end

-- Register the protocol
local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(9200, k4_proto)

-- Register heuristic dissector
k4_proto:register_heuristic("tcp", k4_heuristic)
