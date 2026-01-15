-- k4inspector/parsers.lua
-- This file contains all the parsing functions for the K4Direct dissector.

local k4_fields = require("k4inspector.fields")
local k4_constants = require("k4inspector.constants")
local k4_validators = require("k4inspector.validators")

local M = {}

-- Parse IF command (comprehensive status response)
function M.parse_if_command(msg, subtree, buffer, offset)
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
        subtree:add(k4_fields.full_message, buffer(offset, #msg), msg .. " [len=" .. data_len .. "]")
        return "IF (incomplete, len=" .. data_len .. ")"
    end

    local pos = 1
    local info_parts = {}

    -- Frequency (11 digits)
    local freq_str = data:sub(pos, pos + 10)
    local freq = tonumber(freq_str)
    if freq then
        local freq_item = subtree:add(k4_fields.frequency, buffer(offset + pos + 1, 11), freq)
        freq_item:append_text(" (" .. k4_validators.format_frequency(freq) .. ")")

        -- Validate frequency range
        local warning = k4_validators.validate_frequency(freq)
        if warning then
            freq_item:append_text(" " .. warning)
        end

        table.insert(info_parts, k4_validators.format_frequency(freq))
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
        subtree:add(k4_fields.rit_offset, buffer(offset + pos + 1, 5), offset_val)
    end
    pos = pos + 5

    -- RIT enabled
    local rit_char = data:sub(pos, pos)
    local rit_enabled = (rit_char == "1")
    subtree:add(k4_fields.rit_enabled, buffer(offset + pos + 1, 1), rit_enabled)
    pos = pos + 1

    -- XIT enabled
    local xit_char = data:sub(pos, pos)
    local xit_enabled = (xit_char == "1")
    subtree:add(k4_fields.xit_enabled, buffer(offset + pos + 1, 1), xit_enabled)
    pos = pos + 1

    -- Skip space and "00"
    pos = pos + 3

    -- TX/RX state
    local tx_char = data:sub(pos, pos)
    local is_tx = (tx_char == "1")
    subtree:add(k4_fields.tx_state, buffer(offset + pos + 1, 1), is_tx)
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
        local mode_item = subtree:add(k4_fields.mode, buffer(offset + pos + 1, 1), mode_val)

        -- Validate mode value
        local warning = k4_validators.validate_mode(mode_val)
        if warning then
            mode_item:append_text(" " .. warning)
        end

        if k4_constants.mode_names[mode_val] then
            mode_item:append_text(" (" .. k4_constants.mode_names[mode_val] .. ")")
            table.insert(info_parts, k4_constants.mode_names[mode_val])
        end
    end
    pos = pos + 1

    -- Skip literal "0" for compatibility
    pos = pos + 1

    -- Scan active
    local scan_char = data:sub(pos, pos)
    local scan_active = (scan_char == "1")
    subtree:add(k4_fields.scan_active, buffer(offset + pos + 1, 1), scan_active)
    pos = pos + 1

    -- Split mode
    local split_char = data:sub(pos, pos)
    local split_enabled = (split_char == "1")
    subtree:add(k4_fields.split_enabled, buffer(offset + pos + 1, 1), split_enabled)
    pos = pos + 1

    -- Skip band (1 char)
    pos = pos + 1

    -- Data mode (0 = off, 1 = on)
    local datamode_char = data:sub(pos, pos)
    local datamode_val = tonumber(datamode_char)
    if datamode_val and datamode_val > 0 then
        local datamode_item = subtree:add(k4_fields.data_submode, buffer(offset + pos + 1, 1), datamode_val)
        if k4_constants.data_submode_names[datamode_val] then
            datamode_item:append_text(" (" .. k4_constants.data_submode_names[datamode_val] .. ")")
        end
    end

    return "IF " .. table.concat(info_parts, ", ")
end

-- Parse OM command - Option Module info with hardware detection
-- Format: "OM APXSHML14---;" where each position indicates an option module
function M.parse_om_command(data, subtree, buffer, offset, data_start)
    if #data == 0 then return "OM" end

    local option_str = data
    subtree:add(k4_fields.om_string, buffer(offset + data_start - 1, #data), option_str)

    local modules = {}

    -- Position 0: ATU (KAT4)
    if option_str:sub(1, 1) == "A" then
        subtree:add(k4_fields.om_atu, buffer(offset + data_start - 1, 1), true)
        table.insert(modules, "ATU")
    elseif option_str:sub(1, 1) == "-" then
        subtree:add(k4_fields.om_atu, buffer(offset + data_start - 1, 1), false)
    end

    -- Position 1: PA (KPA4)
    if option_str:sub(2, 2) == "P" then
        subtree:add(k4_fields.om_pa, buffer(offset + data_start, 1), true)
        table.insert(modules, "PA")
    elseif option_str:sub(2, 2) ~= "" then
        subtree:add(k4_fields.om_pa, buffer(offset + data_start, 1), false)
    end

    -- Position 2: XVTR (Transverter)
    if option_str:sub(3, 3) == "X" then
        subtree:add(k4_fields.om_xvtr, buffer(offset + data_start + 1, 1), true)
        table.insert(modules, "XVTR")
    elseif option_str:sub(3, 3) ~= "" then
        subtree:add(k4_fields.om_xvtr, buffer(offset + data_start + 1, 1), false)
    end

    -- Position 3: SUB RX (KRX4 + KDDC4)
    if option_str:sub(4, 4) == "S" then
        subtree:add(k4_fields.om_subrx, buffer(offset + data_start + 2, 1), true)
        table.insert(modules, "SUB RX")
    elseif option_str:sub(4, 4) ~= "" then
        subtree:add(k4_fields.om_subrx, buffer(offset + data_start + 2, 1), false)
    end

    -- Position 4: HDR MODULE (KHDR4 + KDDC4-2)
    if option_str:sub(5, 5) == "H" then
        subtree:add(k4_fields.om_hdr, buffer(offset + data_start + 3, 1), true)
        table.insert(modules, "HDR")
    elseif option_str:sub(5, 5) ~= "" then
        subtree:add(k4_fields.om_hdr, buffer(offset + data_start + 3, 1), false)
    end

    -- Position 5: K40 Mini
    if option_str:sub(6, 6) == "M" then
        subtree:add(k4_fields.om_k40mini, buffer(offset + data_start + 4, 1), true)
        table.insert(modules, "K40 Mini")
    elseif option_str:sub(6, 6) ~= "" then
        subtree:add(k4_fields.om_k40mini, buffer(offset + data_start + 4, 1), false)
    end

    -- Position 6/7: Linear Amp or KPA1500
    if #option_str >= 8 then
        if option_str:sub(8, 8) == "K" then
            subtree:add(k4_fields.om_kpa1500, buffer(offset + data_start + 6, 1), true)
            table.insert(modules, "KPA1500")
        elseif option_str:sub(8, 8) ~= "" then
            subtree:add(k4_fields.om_kpa1500, buffer(offset + data_start + 6, 1), false)
            if option_str:sub(7, 7) == "L" then
                subtree:add(k4_fields.om_linear, buffer(offset + data_start + 5, 1), true)
                table.insert(modules, "Linear")
            elseif option_str:sub(7, 7) ~= "" then
                subtree:add(k4_fields.om_linear, buffer(offset + data_start + 5, 1), false)
            end
        end
    end

    -- Position 8: K4 Identifier (4 for basic, D for K4D high-performance DDC)
    if #option_str >= 9 then
        if option_str:sub(9, 9) == "4" then
            subtree:add(k4_fields.om_k4id, buffer(offset + data_start + 7, 1), true)
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

    subtree:add(k4_fields.om_model, buffer(offset, #data + data_start - 1), radio_model)

    local info = "OM " .. radio_model
    if #modules > 0 then
        info = info .. " [" .. table.concat(modules, ", ") .. "]"
    end

    return info
end

-- Parse frequency command (FA, FB)
function M.parse_frequency(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data == 11 then
        local freq = tonumber(data)
        if freq then
            local freq_item = msg_subtree:add(k4_fields.frequency, buffer(offset + data_start - 1, 11), freq)
            freq_item:append_text(" (" .. k4_validators.format_frequency(freq) .. ")")

            -- Validate frequency range
            local warning = k4_validators.validate_frequency(freq)
            if warning then
                freq_item:append_text(" " .. warning)
            end

            return cmd .. " " .. k4_validators.format_frequency(freq)
        end
    end
    return cmd
end

-- Parse boolean command (RT, XT, FT, LK, SB, SP, etc)
function M.parse_boolean(cmd, data, field, on_text, off_text)
    return function(c, d, subtree, buffer, offset, data_start)
        local enabled = (d == "1")
        subtree:add(field, buffer(offset + data_start - 1, #d), enabled)
        return c .. " " .. (enabled and (on_text or "On") or (off_text or "Off"))
    end
end

-- Parse numeric value with unit suffix
function M.parse_numeric(cmd, data, field, unit, scale)
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
function M.parse_named_value(cmd, data, field, names, validator)
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
function M.parse_offset(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 5 then
        local sign_char = data:sub(1, 1)
        local offset_str = data:sub(2, 5)
        local offset_val = tonumber(offset_str)
        if offset_val then
            if sign_char == "-" then
                offset_val = -offset_val
            end
            msg_subtree:add(k4_fields.rit_offset, buffer(offset + data_start - 1, #data), offset_val)
            return cmd .. " " .. offset_val .. " Hz"
        end
    end
    return cmd
end

-- Parse raw data (just show the data)
function M.parse_raw(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data > 0 then
        msg_subtree:add(k4_fields.full_message, buffer(offset + data_start - 1, #data), data)
        return cmd .. " " .. data
    end
    return cmd
end

-- Parse no-data command (TX, RX, UP, DN, RC)
function M.parse_no_data(cmd, description)
    return function(c, d, subtree, buffer, offset, data_start)
        return description
    end
end

-- Parse CW text command (KY)
function M.parse_cw_text(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data > 1 then
        local cw_text = data:sub(2) -- Skip leading space
        msg_subtree:add(k4_fields.cw_text, buffer(offset + data_start, #cw_text), cw_text)
        return cmd .. ' "' .. cw_text .. '"'
    end
    return cmd
end

-- Parse power output (PO - tenths of watts)
function M.parse_power(cmd, data, msg_subtree, buffer, offset, data_start)
    local power = tonumber(data)
    if power then
        msg_subtree:add(k4_fields.power_output, buffer(offset + data_start - 1, #data), power)
        return string.format("PO %.1fW", power / 10.0)
    end
    return cmd
end

-- Parse ID command with K4 detection
function M.parse_id(cmd, data, msg_subtree, buffer, offset, data_start)
    local radio_id = tonumber(data)
    if radio_id then
        local id_item = msg_subtree:add(k4_fields.radio_id, buffer(offset + data_start - 1, #data), radio_id)
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
function M.parse_menu(cmd, data, msg_subtree, buffer, offset, data_start)
    local dot_pos = data:find("%.")
    if dot_pos and #data >= dot_pos then
        local menu_id_str = data:sub(1, dot_pos - 1)
        local menu_val_str = data:sub(dot_pos + 1)

        local menu_id = tonumber(menu_id_str)
        local menu_val = tonumber(menu_val_str)

        if menu_id and menu_val then
            -- Add menu ID field
            local id_item = msg_subtree:add(k4_fields.menu_id, buffer(offset + data_start - 1, #menu_id_str), menu_id)
            if k4_constants.menu_names[menu_id] then
                id_item:append_text(" (" .. k4_constants.menu_names[menu_id] .. ")")
            end

            -- Add menu value field
            msg_subtree:add(k4_fields.menu_value, buffer(offset + data_start - 1 + dot_pos, #menu_val_str), menu_val)

            -- Build info string
            local info = "ME "
            if k4_constants.menu_names[menu_id] then
                info = info .. k4_constants.menu_names[menu_id] .. " = " .. menu_val
            else
                info = info .. menu_id .. " = " .. menu_val
            end

            return info
        end
    end
    return cmd
end

-- Parse FI command (IF Center Frequency)
-- Format: FInnnnnnnnnnn; (11-digit Hz, same as FA/FB)
function M.parse_if_center(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data == 11 then
        local freq = tonumber(data)
        if freq then
            local freq_item = msg_subtree:add(k4_fields.if_center_freq, buffer(offset + data_start - 1, 11), freq)
            freq_item:append_text(" (" .. k4_validators.format_frequency(freq) .. ")")

            -- Validate frequency range
            local warning = k4_validators.validate_frequency(freq)
            if warning then
                freq_item:append_text(" " .. warning)
            end

            return cmd .. " " .. k4_validators.format_frequency(freq)
        end
    end
    return cmd
end

-- Parse IS command (IF Shift / Center Pitch)
-- Format: IS nnnn; where nnnn = pitch (x10 Hz)
-- NOTE: Has SPACE before value!
function M.parse_if_shift(cmd, data, msg_subtree, buffer, offset, data_start)
    -- Strip leading space if present
    local trimmed_data = data:match("^%s*(.*)$")
    local shift_val = tonumber(trimmed_data)

    if shift_val then
        msg_subtree:add(k4_fields.if_shift, buffer(offset + data_start - 1, #data), shift_val)
        return string.format("IS %d Hz", shift_val * 10)
    end
    return cmd
end

-- Parse ES command (TX SSB/ESSB Mode and Bandwidth)
-- Format: ESnbb; where n=mode (0/1), bb=bandwidth in 100 Hz units (30-45)
function M.parse_essb(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 3 then
        local mode_val = tonumber(data:sub(1, 1))
        local bw_val = tonumber(data:sub(2, 3))

        if mode_val and bw_val then
            local mode_item = msg_subtree:add(k4_fields.essb_mode, buffer(offset + data_start - 1, 1), mode_val)
            if k4_constants.essb_mode_names[mode_val] then
                mode_item:append_text(" (" .. k4_constants.essb_mode_names[mode_val] .. ")")
            end

            local bw_hz = bw_val * 100
            msg_subtree:add(k4_fields.essb_bandwidth, buffer(offset + data_start, 2), bw_hz)

            local mode_str = k4_constants.essb_mode_names[mode_val] or "Unknown"
            return string.format("ES %s %.1f kHz", mode_str, bw_hz / 1000.0)
        end
    end
    return cmd
end

-- Parse VG command (VOX Gain)
-- Format: VGmnnn; where m=mode (V/D), nnn=gain (000-060)
function M.parse_vox_gain(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 4 then
        local mode_char = data:sub(1, 1)
        local gain_val = tonumber(data:sub(2, 4))

        if gain_val then
            local mode_name = k4_constants.vox_gain_mode_names[mode_char] or "Unknown"

            msg_subtree:add(k4_fields.vox_gain_mode, buffer(offset + data_start - 1, 1), mode_char):append_text(" (" .. mode_name .. ")")
            msg_subtree:add(k4_fields.vox_gain, buffer(offset + data_start, 3), gain_val)

            return string.format("VOX Gain %s %d", mode_name, gain_val)
        end
    end
    return cmd
end

-- Parse AP command (APF - Audio Peak Filter)
-- Format: APmb; where m=mode (0/1), b=bandwidth (0/1/2)
function M.parse_apf(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 2 then
        local mode_val = tonumber(data:sub(1, 1))
        local bw_val = tonumber(data:sub(2, 2))

        if mode_val and bw_val then
            local mode_item = msg_subtree:add(k4_fields.apf_mode, buffer(offset + data_start - 1, 1), mode_val)
            if k4_constants.apf_mode_names[mode_val] then
                mode_item:append_text(" (" .. k4_constants.apf_mode_names[mode_val] .. ")")
            end

            local bw_item = msg_subtree:add(k4_fields.apf_bandwidth, buffer(offset + data_start, 1), bw_val)
            if k4_constants.apf_bandwidth_names[bw_val] then
                bw_item:append_text(" (" .. k4_constants.apf_bandwidth_names[bw_val] .. ")")
            end

            local mode_str = k4_constants.apf_mode_names[mode_val] or "Unknown"
            local bw_str = k4_constants.apf_bandwidth_names[bw_val] or string.format("BW%d", bw_val)
            return string.format("APF %s %s", mode_str, bw_str)
        end
    end
    return cmd
end

-- Parse VX command (VOX On/Off)
-- Format: VXmn; where m=mode (C/V/D), n=state (0/1)
function M.parse_vox(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 2 then
        local mode_char = data:sub(1, 1)
        local state_char = data:sub(2, 2)

        local mode_names = {
            C = "CW/Direct Data",
            V = "Voice",
            D = "AF Data"
        }

        local mode_name = mode_names[mode_char] or "Unknown"
        local state_val = (state_char == "1") and 1 or 0

        -- Add mode field
        msg_subtree:add(k4_fields.vox_mode, buffer(offset + data_start - 1, 1), mode_char):append_text(" (" .. mode_name .. ")")

        -- Add state field
        msg_subtree:add(k4_fields.vox_state, buffer(offset + data_start, 1), state_val)

        local state_str = (state_val == 1) and "ON" or "OFF"
        return "VOX " .. mode_name .. " " .. state_str
    end
    return cmd
end

-- Parse EQ command (TE - TX EQ, RE - RX EQ)
-- Format: CMDabcdefgh; where a-h are 3-char signed values (-16 to +16 dB)
-- Bands: a=100Hz, b=200Hz, c=400Hz, d=800Hz, e=1200Hz, f=1600Hz, g=2400Hz, h=3200Hz
function M.parse_eq(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 24 then  -- 8 bands * 3 chars each
        local eq_k4_fields = {
            {k4_fields.eq_band_100, "100 Hz"},
            {k4_fields.eq_band_200, "200 Hz"},
            {k4_fields.eq_band_400, "400 Hz"},
            {k4_fields.eq_band_800, "800 Hz"},
            {k4_fields.eq_band_1200, "1200 Hz"},
            {k4_fields.eq_band_1600, "1600 Hz"},
            {k4_fields.eq_band_2400, "2400 Hz"},
            {k4_fields.eq_band_3200, "3200 Hz"}
        }

        local eq_type = (cmd == "TE") and "TX EQ" or "RX EQ"
        local eq_values = {}
        local all_flat = true

        for i = 1, 8 do
            local band_start = (i - 1) * 3 + 1
            local band_str = data:sub(band_start, band_start + 2)
            local band_val = tonumber(band_str)

            if band_val then
                msg_subtree:add(eq_k4_fields[i][1], buffer(offset + data_start - 1 + band_start - 1, 3), band_val)
                table.insert(eq_values, string.format("%s:%+d dB", eq_k4_fields[i][2], band_val))
                if band_val ~= 0 then
                    all_flat = false
                end
            end
        end

        if all_flat then
            return eq_type .. " Flat"
        else
            return eq_type .. " (" .. table.concat(eq_values, ", ") .. ")"
        end
    end
    return cmd
end

-- Parse PC command (Power Control)
-- Format: PCnnnr; where nnn=power (3 digits), r=range (L/H/X, optional, defaults to L)
function M.parse_power_control(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 3 then
        local power_str = data:sub(1, 3)
        local range_char = "L"  -- Default to Low range if omitted

        if #data >= 4 then
            local last_char = data:sub(4, 4)
            if last_char == "L" or last_char == "H" or last_char == "X" then
                range_char = last_char
            end
        end

        local power_raw = tonumber(power_str)
        if power_raw then
            -- Add power value field
            msg_subtree:add(k4_fields.power_control, buffer(offset + data_start - 1, 3), power_raw)

            -- Add range field
            local range_item = msg_subtree:add(k4_fields.power_range, buffer(offset + data_start - 1, #data), range_char)

            -- Calculate actual power based on range
            local power_display
            local range_name
            if range_char == "L" then
                power_display = string.format("%.1f W", power_raw / 10.0)
                range_name = "Low (QRP 0.1-10.0 W)"
            elseif range_char == "H" then
                power_display = string.format("%.0f W", power_raw)
                range_name = "High (QRO 1-110 W)"
            elseif range_char == "X" then
                power_display = string.format("%.1f mW", power_raw / 10.0)
                range_name = "Milliwatt (XVTR 0.1-10.0 mW)"
            end

            range_item:append_text(" (" .. range_name .. ")")

            return "PC " .. power_display .. " (" .. range_char .. ")"
        end
    end
    return cmd
end

-- =============================================================================
-- BATCH 3: COMPLEX STRUCTURED COMMANDS
-- =============================================================================

-- Parse SD command (VOX or QSK Delay)
-- Format: SDxyzzz; where x=QSK (0/1), y=mode (C/V/D), zzz=delay in 10ms
function M.parse_vox_delay(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 5 then
        local qsk = tonumber(data:sub(1, 1))
        local mode_char = data:sub(2, 2)
        local delay = tonumber(data:sub(3, 5))

        if qsk and delay and k4_constants.vox_delay_mode_names[mode_char] then
            msg_subtree:add(k4_fields.qsk_full, buffer(offset + data_start - 1, 1), qsk == 1)
            msg_subtree:add(k4_fields.vox_delay_mode, buffer(offset + data_start, 1), mode_char)
            msg_subtree:add(k4_fields.vox_delay, buffer(offset + data_start + 1, 3), delay)

            local qsk_str = (qsk == 1) and "Full QSK" or k4_constants.vox_delay_mode_names[mode_char]
            local delay_str = string.format("%d ms", delay * 10)
            return string.format("SD %s %s", qsk_str, delay_str)
        end
    end
    return cmd
end

-- Parse MS command (Mic Setup)
-- Format: MSabcde; where a=front preamp (0-2), b=front bias (0-1), c=front controls (0-1),
--                        d=rear preamp (0-1), e=rear bias (0-1)
function M.parse_mic_setup(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 5 then
        local a = tonumber(data:sub(1, 1))
        local b = tonumber(data:sub(2, 2))
        local c = tonumber(data:sub(3, 3))
        local d = tonumber(data:sub(4, 4))
        local e = tonumber(data:sub(5, 5))

        if a and b and c and d and e then
            local front_db = k4_constants.front_mic_preamp_db[a] or 0
            local rear_db = k4_constants.rear_mic_preamp_db[d] or 0

            msg_subtree:add(k4_fields.front_mic_preamp, buffer(offset + data_start - 1, 1), front_db)
            msg_subtree:add(k4_fields.front_mic_bias, buffer(offset + data_start, 1), b == 1)
            msg_subtree:add(k4_fields.front_mic_controls, buffer(offset + data_start + 1, 1), c == 1)
            msg_subtree:add(k4_fields.rear_mic_preamp, buffer(offset + data_start + 2, 1), rear_db)
            msg_subtree:add(k4_fields.rear_mic_bias, buffer(offset + data_start + 3, 1), e == 1)

            return string.format("MS Front:%ddB/%s/%s Rear:%ddB/%s",
                front_db, b == 1 and "Bias" or "NoBias", c == 1 and "Ctrl" or "NoCtrl",
                rear_db, e == 1 and "Bias" or "NoBias")
        end
    end
    return cmd
end

-- Parse KP command (Keyer Paddle and Weight Setup)
-- Format: KPionnn; where i=iambic (A/B), o=orientation (N/R), nnn=weight (090-125)
function M.parse_keyer_paddle(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 5 then
        local iambic = data:sub(1, 1)
        local orient = data:sub(2, 2)
        local weight = tonumber(data:sub(3, 5))

        if weight and k4_constants.keyer_iambic_names[iambic] and k4_constants.paddle_orientation_names[orient] then
            msg_subtree:add(k4_fields.keyer_iambic_mode, buffer(offset + data_start - 1, 1), iambic)
            msg_subtree:add(k4_fields.paddle_orientation, buffer(offset + data_start, 1), orient)
            msg_subtree:add(k4_fields.keyer_weight, buffer(offset + data_start + 1, 3), weight)

            local weight_ratio = string.format("%.2f", weight / 100.0)
            return string.format("KP %s %s Weight:%s",
                k4_constants.keyer_iambic_names[iambic], k4_constants.paddle_orientation_names[orient], weight_ratio)
        end
    end
    return cmd
end

-- Parse LO command (Line Out)
-- Format: LOlllrrrm; where lll=left level (0-040), rrr=right level, m=mode (0/1)
function M.parse_line_out(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 7 then
        local left = tonumber(data:sub(1, 3))
        local right = tonumber(data:sub(4, 6))
        local mode = tonumber(data:sub(7, 7))

        if left and right and mode then
            msg_subtree:add(k4_fields.line_out_left, buffer(offset + data_start - 1, 3), left)
            msg_subtree:add(k4_fields.line_out_right, buffer(offset + data_start + 2, 3), right)
            msg_subtree:add(k4_fields.line_out_mode, buffer(offset + data_start + 5, 1), mode)

            local mode_str = k4_constants.line_out_mode_names[mode] or "Unknown"
            return string.format("LO L:%d R:%d %s", left, right, mode_str)
        end
    end
    return cmd
end

-- Parse LI command (Line Input)
-- Format: LIuuullls; where uuu=USB-B level, lll=LINE IN level, s=source (0/1)
function M.parse_line_in(cmd, data, msg_subtree, buffer, offset, data_start)
    if #data >= 7 then
        local usb = tonumber(data:sub(1, 3))
        local line = tonumber(data:sub(4, 6))
        local source = tonumber(data:sub(7, 7))

        if usb and line and source then
            msg_subtree:add(k4_fields.line_in_usb, buffer(offset + data_start - 1, 3), usb)
            msg_subtree:add(k4_fields.line_in_line, buffer(offset + data_start + 2, 3), line)
            msg_subtree:add(k4_fields.line_in_source, buffer(offset + data_start + 5, 1), source)

            local source_str = k4_constants.line_in_source_names[source] or "Unknown"
            return string.format("LI USB:%d LINE:%d Source:%s", usb, line, source_str)
        end
    end
    return cmd
end

-- =============================================================================
-- BATCH 4: ALTERNATE FORMAT COMMANDS
-- =============================================================================

-- Parse NB$ command (Noise Blanker)
-- Format: NB$nnm; (full) or NB$m; (alternate) where nn=level (0-15), m=on/off (0/1)
function M.parse_noise_blanker(cmd, data, msg_subtree, buffer, offset, data_start)
    -- Strip leading $ if present
    if data:sub(1, 1) == "$" then
        data = data:sub(2)
        data_start = data_start + 1
    end

    if #data >= 3 then
        -- Full format: NB$nnm;
        local level = tonumber(data:sub(1, 2))
        local state = tonumber(data:sub(3, 3))

        if level and state then
            msg_subtree:add(k4_fields.noise_blanker_level, buffer(offset + data_start - 1, 2), level)
            msg_subtree:add(k4_fields.noise_blanker_state, buffer(offset + data_start + 1, 1), state == 1)
            return string.format("NB Level:%d %s", level, state == 1 and "ON" or "OFF")
        end
    elseif #data >= 1 then
        -- Alternate format: NB$m;
        local state = tonumber(data:sub(1, 1))

        if state then
            msg_subtree:add(k4_fields.noise_blanker_state, buffer(offset + data_start - 1, 1), state == 1)
            return string.format("NB %s", state == 1 and "ON" or "OFF")
        end
    end
    return cmd
end

-- Parse NM$ command (Manual Notch)
-- Format: NM$nnnnm; (full) or NM$m; (alternate) where nnnn=pitch (150-5000 Hz), m=on/off
function M.parse_manual_notch(cmd, data, msg_subtree, buffer, offset, data_start)
    -- Strip leading $ if present
    if data:sub(1, 1) == "$" then
        data = data:sub(2)
        data_start = data_start + 1
    end

    if #data >= 5 then
        -- Full format: NM$nnnnm;
        local pitch = tonumber(data:sub(1, 4))
        local state = tonumber(data:sub(5, 5))

        if pitch and state then
            msg_subtree:add(k4_fields.manual_notch_pitch, buffer(offset + data_start - 1, 4), pitch)
            msg_subtree:add(k4_fields.manual_notch_state, buffer(offset + data_start + 3, 1), state == 1)
            return string.format("NM %d Hz %s", pitch, state == 1 and "ON" or "OFF")
        end
    elseif #data >= 1 then
        -- Alternate format: NM$m;
        local state = tonumber(data:sub(1, 1))

        if state then
            msg_subtree:add(k4_fields.manual_notch_state, buffer(offset + data_start - 1, 1), state == 1)
            return string.format("NM %s", state == 1 and "ON" or "OFF")
        end
    end
    return cmd
end

-- Parse NR$ command (Noise Reduction)
-- Format: NR$nnm; where nn=level (0-10), m=on/off (0/1)
function M.parse_noise_reduction(cmd, data, msg_subtree, buffer, offset, data_start)
    -- Strip leading $ if present
    if data:sub(1, 1) == "$" then
        data = data:sub(2)
        data_start = data_start + 1
    end

    if #data >= 3 then
        local level = tonumber(data:sub(1, 2))
        local state = tonumber(data:sub(3, 3))

        if level and state then
            msg_subtree:add(k4_fields.noise_reduction_level, buffer(offset + data_start - 1, 2), level)
            msg_subtree:add(k4_fields.noise_reduction_state, buffer(offset + data_start + 1, 1), state == 1)
            return string.format("NR Level:%d %s", level, state == 1 and "ON" or "OFF")
        end
    end
    return cmd
end

-- Parse PA$ command (Preamp)
-- Format: PA$nm; (full) or PA$n; (type only) where n=type (0/1/2/3), m=on/off (0/1)
function M.parse_preamp(cmd, data, msg_subtree, buffer, offset, data_start)
    -- Strip leading $ if present
    if data:sub(1, 1) == "$" then
        data = data:sub(2)
        data_start = data_start + 1
    end

    if #data >= 2 then
        -- Full format: PA$nm;
        local ptype = tonumber(data:sub(1, 1))
        local state = tonumber(data:sub(2, 2))

        if ptype and state then
            msg_subtree:add(k4_fields.preamp_type, buffer(offset + data_start - 1, 1), ptype)
            msg_subtree:add(k4_fields.preamp_state, buffer(offset + data_start, 1), state == 1)

            local type_str = k4_constants.preamp_type_names[ptype] or string.format("Type%d", ptype)
            return string.format("PA %s %s", type_str, state == 1 and "ON" or "OFF")
        end
    elseif #data >= 1 then
        -- Alternate format: PA$n; (type only, no state)
        local ptype = tonumber(data:sub(1, 1))

        if ptype then
            msg_subtree:add(k4_fields.preamp_type, buffer(offset + data_start - 1, 1), ptype)
            local type_str = k4_constants.preamp_type_names[ptype] or string.format("Type%d", ptype)
            return string.format("PA %s", type_str)
        end
    end
    return cmd
end

-- Parse PL$ command (PL/CTCSS Tone)
-- Format: PL$nnm; where nn=tone# (01-50), m=on/off (0/1)
-- Note: PL doesn't use $ on wire, format is PLnnm;
function M.parse_pl_tone(cmd, data, msg_subtree, buffer, offset, data_start)
    -- PL doesn't have $ on wire, but strip it if present for consistency
    if data:sub(1, 1) == "$" then
        data = data:sub(2)
        data_start = data_start + 1
    end

    -- Check if data is exactly 3 digits (nnm format)
    if #data == 3 then
        local tone_num = tonumber(data:sub(1, 2))
        local state = tonumber(data:sub(3, 3))

        if tone_num and state ~= nil then
            msg_subtree:add(k4_fields.pl_tone_number, buffer(offset + data_start - 1, 2), tone_num)
            msg_subtree:add(k4_fields.pl_tone_state, buffer(offset + data_start + 1, 1), state == 1)

            local freq = k4_constants.pl_tone_freqs[tone_num]
            local tone_str = freq and string.format("%.1f Hz", freq) or string.format("Tone#%d", tone_num)
            return string.format("PL %s %s", tone_str, state == 1 and "ON" or "OFF")
        end
    end
    return cmd
end

-- Parse RA$ command (RX Attenuator)
-- Format: RA$nnm; (full) or RA$nn; (dB only) where nn=dB (0/3/6/9/12/15/18/21), m=on/off (0/1)
function M.parse_rx_atten(cmd, data, msg_subtree, buffer, offset, data_start)
    -- Strip leading $ if present
    if data:sub(1, 1) == "$" then
        data = data:sub(2)
        data_start = data_start + 1
    end

    if #data >= 3 then
        -- Full format: RA$nnm;
        local atten = tonumber(data:sub(1, 2))
        local state = tonumber(data:sub(3, 3))

        if atten and state then
            msg_subtree:add(k4_fields.rx_atten_db, buffer(offset + data_start - 1, 2), atten)
            msg_subtree:add(k4_fields.rx_atten_state, buffer(offset + data_start + 1, 1), state == 1)
            return string.format("RA %d dB %s", atten, state == 1 and "ON" or "OFF")
        end
    elseif #data >= 2 then
        -- Alternate format: RA$nn; (dB only, no state)
        local atten = tonumber(data:sub(1, 2))

        if atten then
            msg_subtree:add(k4_fields.rx_atten_db, buffer(offset + data_start - 1, 2), atten)
            return string.format("RA %d dB", atten)
        end
    end
    return cmd
end

M.command_parsers = {
    -- Frequency
    FA = M.parse_frequency,
    FB = M.parse_frequency,

    -- Mode & Data
    MD = M.parse_named_value("MD", nil, k4_fields.mode, k4_constants.mode_names, k4_validators.validate_mode),
    DT = M.parse_named_value("DT", nil, k4_fields.data_submode, k4_constants.data_submode_names, k4_validators.validate_data_submode),

    -- RIT/XIT
    RO = M.parse_offset,
    RT = M.parse_boolean("RT", nil, k4_fields.rit_enabled),
    XT = M.parse_boolean("XT", nil, k4_fields.xit_enabled),
    RC = M.parse_no_data("RC", "RC (Clear RIT/XIT)"),

    -- Split & VFO
    FT = M.parse_boolean("FT", nil, k4_fields.split_enabled),
    LK = M.parse_boolean("LK", nil, k4_fields.vfo_lock),
    UP = M.parse_no_data("UP", "UP VFO Up"),
    DN = M.parse_no_data("DN", "DN VFO Down"),

    -- TX/RX
    TX = M.parse_no_data("TX", "TX (Transmit)"),
    RX = M.parse_no_data("RX", "RX (Receive)"),
    TS = M.parse_boolean("TS", nil, k4_fields.tx_state),

    -- CW
    KS = M.parse_numeric("KS", nil, k4_fields.cw_speed, " WPM"),
    KY = M.parse_cw_text,
    CW = M.parse_numeric("CW", nil, k4_fields.cw_pitch, " Hz"),

    -- Band & Filter
    BN = M.parse_named_value("BN", nil, k4_fields.band_number, k4_constants.band_names, k4_validators.validate_band),
    FP = M.parse_numeric("FP", nil, k4_fields.filter_preset),

    -- Gain Controls
    AG = M.parse_numeric("AG", nil, k4_fields.ag_gain),
    MG = M.parse_numeric("MG", nil, k4_fields.mg_gain),
    RG = M.parse_numeric("RG", nil, k4_fields.rg_gain),
    CP = M.parse_numeric("CP", nil, k4_fields.cp_level),
    SQ = M.parse_numeric("SQ", nil, k4_fields.sq_level),

    -- Signal Processing
    GT = M.parse_named_value("GT", nil, k4_fields.agc_mode, k4_constants.agc_names, k4_validators.validate_agc),
    BW = M.parse_numeric("BW", nil, k4_fields.bandwidth, " Hz"),

    -- Antenna & ATU
    AN = M.parse_numeric("AN", nil, k4_fields.antenna),
    AR = M.parse_numeric("AR", nil, k4_fields.antenna),
    AT = M.parse_named_value("AT", nil, k4_fields.atu_status, k4_constants.atu_names, k4_validators.validate_atu),

    -- Power & Monitoring
    PO = M.parse_power,
    SM = M.parse_numeric("SM", nil, k4_fields.sm_reading),

    -- Sub Receiver & Features
    SB = M.parse_boolean("SB", nil, k4_fields.subrx_enabled),
    SP = M.parse_boolean("SP", nil, k4_fields.spot_enabled),

    -- Configuration & Status
    AI = M.parse_numeric("AI", nil, k4_fields.ai_level),
    ID = M.parse_id,

    -- Data mode
    DR = M.parse_named_value("DR", nil, k4_fields.data_baud_rate, k4_constants.baud_rate_names),

    -- Raw data commands
    DA = M.parse_raw,
    SI = M.parse_raw,
    PS = M.parse_raw,
    AB = M.parse_named_value("AB", nil, k4_fields.vfo_operation, k4_constants.vfo_operation_names),
    AF = M.parse_raw,
    DM = M.parse_raw,
    FC = M.parse_raw,

    -- Menu Parameter
    ME = M.parse_menu,

    -- Batch 1: Simple commands
    BI = M.parse_boolean("BI", nil, k4_fields.band_independence),
    DV = M.parse_boolean("DV", nil, k4_fields.diversity_mode),
    DO = M.parse_boolean("DO", nil, k4_fields.digout1),
    FX = M.parse_named_value("FX", nil, k4_fields.audio_effects, k4_constants.audio_effects_names),
    NA = M.parse_boolean("NA", nil, k4_fields.auto_notch),
    TD = M.parse_numeric("TD", nil, k4_fields.tx_delay),
    TG = M.parse_numeric("TG", nil, k4_fields.tx_gain),
    VI = M.parse_numeric("VI", nil, k4_fields.voice_input),
    MI = M.parse_named_value("MI", nil, k4_fields.mic_input, k4_constants.mic_input_names),

    -- Batch 2: Special format commands
    FI = M.parse_if_center,
    IS = M.parse_if_shift,
    ES = M.parse_essb,
    VG = M.parse_vox_gain,
    AP = M.parse_apf,

    -- Batch 3: Complex structured commands
    SD = M.parse_vox_delay,
    MS = M.parse_mic_setup,
    KP = M.parse_keyer_paddle,
    LO = M.parse_line_out,
    LI = M.parse_line_in,

    -- Batch 4: Alternate format commands
    NB = M.parse_noise_blanker,
    NM = M.parse_manual_notch,
    NR = M.parse_noise_reduction,
    PA = M.parse_preamp,
    PL = M.parse_pl_tone,
    RA = M.parse_rx_atten,

    -- Complex commands (to be implemented)
    MA = M.parse_raw, -- Manual Notch
    TE = M.parse_eq,
    TA = M.parse_raw, -- TX Antenna
    RE = M.parse_eq,
    PC = M.parse_power_control,
    VX = M.parse_vox,
}

return M
