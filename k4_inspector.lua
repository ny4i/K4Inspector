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
fields.frequency = ProtoField.uint64("k4direct.frequency", "Frequency (Hz)", base.DEC)
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

-- Band number value strings
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

-- Format frequency for display (Hz to MHz)
local function format_frequency(freq_hz)
    local freq_mhz = freq_hz / 1000000.0
    return string.format("%.6f MHz", freq_mhz)
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

    if #data < 34 then
        subtree:add(fields.full_message, buffer(offset, #msg), msg)
        return
    end

    local pos = 1

    -- Frequency (11 digits)
    local freq_str = data:sub(pos, pos + 10)
    local freq = tonumber(freq_str)
    if freq then
        subtree:add(fields.frequency, buffer(offset + pos + 1, 11), freq):append_text(" (" .. format_frequency(freq) .. ")")
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
    subtree:add(fields.rit_enabled, buffer(offset + pos + 1, 1), rit_char == "1")
    pos = pos + 1

    -- XIT enabled
    local xit_char = data:sub(pos, pos)
    subtree:add(fields.xit_enabled, buffer(offset + pos + 1, 1), xit_char == "1")
    pos = pos + 1

    -- Skip space and "00"
    pos = pos + 3

    -- TX/RX state
    local tx_char = data:sub(pos, pos)
    subtree:add(fields.tx_state, buffer(offset + pos + 1, 1), tx_char == "1")
    pos = pos + 1

    -- Mode
    local mode_char = data:sub(pos, pos)
    local mode_val = tonumber(mode_char)
    if mode_val then
        local mode_item = subtree:add(fields.mode, buffer(offset + pos + 1, 1), mode_val)
        if mode_names[mode_val] then
            mode_item:append_text(" (" .. mode_names[mode_val] .. ")")
        end
    end
    pos = pos + 1

    -- Active VFO
    local vfo_char = data:sub(pos, pos)
    local vfo_name = (vfo_char == "1") and "VFO B" or "VFO A"
    subtree:add(fields.active_vfo, buffer(offset + pos + 1, 1), vfo_name)
    pos = pos + 1

    -- Scan active
    local scan_char = data:sub(pos, pos)
    subtree:add(fields.scan_active, buffer(offset + pos + 1, 1), scan_char == "1")
    pos = pos + 1

    -- Split enabled
    local split_char = data:sub(pos, pos)
    subtree:add(fields.split_enabled, buffer(offset + pos + 1, 1), split_char == "1")
    pos = pos + 1

    -- Skip band byte
    pos = pos + 1

    -- Data sub-mode
    if pos <= #data then
        local datamode_char = data:sub(pos, pos)
        local datamode_val = tonumber(datamode_char)
        if datamode_val then
            local datamode_item = subtree:add(fields.data_submode, buffer(offset + pos + 1, 1), datamode_val)
            if data_submode_names[datamode_val] then
                datamode_item:append_text(" (" .. data_submode_names[datamode_val] .. ")")
            end
        end
    end
end

-- Parse OM command (Option Modules)
-- Format: "OM APXSHML14---;" where each position indicates an option module
local function parse_om_command(data, subtree, buffer, offset, data_start)
    if #data == 0 then return "OM" end

    -- Skip leading space if present
    local option_str = data
    if option_str:sub(1,1) == " " then
        option_str = option_str:sub(2)
    end

    -- Add the full option string
    subtree:add(fields.om_string, buffer(offset + data_start - 1, #data), option_str)

    local modules = {}
    local radio_model = "K4"

    -- Position 0: A = ATU (KAT4)
    if #option_str > 0 and option_str:sub(1,1) == "A" then
        subtree:add(fields.om_atu, buffer(offset + data_start - 1, 1), true)
        table.insert(modules, "ATU")
    else
        subtree:add(fields.om_atu, buffer(offset + data_start - 1, 1), false)
    end

    -- Position 1: P = PA (KPA4)
    if #option_str > 1 and option_str:sub(2,2) == "P" then
        subtree:add(fields.om_pa, buffer(offset + data_start, 1), true)
        table.insert(modules, "PA")
    else
        if #option_str > 1 then
            subtree:add(fields.om_pa, buffer(offset + data_start, 1), false)
        end
    end

    -- Position 2: X = XVTR (Transverter)
    if #option_str > 2 and option_str:sub(3,3) == "X" then
        subtree:add(fields.om_xvtr, buffer(offset + data_start + 1, 1), true)
        table.insert(modules, "XVTR")
    else
        if #option_str > 2 then
            subtree:add(fields.om_xvtr, buffer(offset + data_start + 1, 1), false)
        end
    end

    -- Position 3: S = SUB RX (KRX4 + 2nd KDDC4, standard in K4D)
    local has_subrx = false
    if #option_str > 3 and option_str:sub(4,4) == "S" then
        subtree:add(fields.om_subrx, buffer(offset + data_start + 2, 1), true)
        table.insert(modules, "SUB RX")
        has_subrx = true
    else
        if #option_str > 3 then
            subtree:add(fields.om_subrx, buffer(offset + data_start + 2, 1), false)
        end
    end

    -- Position 4: H = HDR MODULE (KHDR4 + KDDC4-2, standard in K4HD)
    local has_hdr = false
    if #option_str > 4 and option_str:sub(5,5) == "H" then
        subtree:add(fields.om_hdr, buffer(offset + data_start + 3, 1), true)
        table.insert(modules, "HDR")
        has_hdr = true
    else
        if #option_str > 4 then
            subtree:add(fields.om_hdr, buffer(offset + data_start + 3, 1), false)
        end
    end

    -- Position 5: M = K40 Mini
    if #option_str > 5 and option_str:sub(6,6) == "M" then
        subtree:add(fields.om_k40mini, buffer(offset + data_start + 4, 1), true)
        table.insert(modules, "K40 Mini")
    else
        if #option_str > 5 then
            subtree:add(fields.om_k40mini, buffer(offset + data_start + 4, 1), false)
        end
    end

    -- Position 6: L = Linear amp detected (generic)
    -- Position 7: 1 = KPA1500 amp detected (specific)
    local has_kpa1500 = (#option_str > 7 and option_str:sub(8,8) == "1")
    local has_generic_linear = (#option_str > 6 and option_str:sub(7,7) == "L")

    if has_kpa1500 then
        if #option_str > 7 then
            subtree:add(fields.om_kpa1500, buffer(offset + data_start + 6, 1), true)
        end
        table.insert(modules, "KPA1500")
    else
        if #option_str > 7 then
            subtree:add(fields.om_kpa1500, buffer(offset + data_start + 6, 1), false)
        end
        if has_generic_linear then
            if #option_str > 6 then
                subtree:add(fields.om_linear, buffer(offset + data_start + 5, 1), true)
            end
            table.insert(modules, "Linear Amp")
        else
            if #option_str > 6 then
                subtree:add(fields.om_linear, buffer(offset + data_start + 5, 1), false)
            end
        end
    end

    -- Position 8: 4 = K4 identifier
    local has_k4id = false
    if #option_str > 8 and option_str:sub(9,9) == "4" then
        subtree:add(fields.om_k4id, buffer(offset + data_start + 7, 1), true)
        has_k4id = true
    else
        if #option_str > 8 then
            subtree:add(fields.om_k4id, buffer(offset + data_start + 7, 1), false)
        end
    end

    -- Determine radio model based on options
    if has_k4id then
        if has_subrx and has_hdr then
            radio_model = "K4HD"
        elseif has_subrx then
            radio_model = "K4D"
        end
    end

    subtree:add(fields.om_model, buffer(offset, #data + data_start - 1), radio_model)

    -- Build info string
    local info = "OM " .. radio_model
    if #modules > 0 then
        info = info .. ": " .. table.concat(modules, ", ")
    end

    return info
end

-- Parse individual K4 command
local function parse_k4_command(msg, subtree, buffer, offset)
    if #msg < 2 then
        subtree:add(fields.full_message, buffer(offset, #msg), msg)
        return msg
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
    subtree:add(fields.command, buffer(offset, 2), cmd)
    subtree:add(fields.vfo, buffer(offset, data_start - 1), vfo)

    local info = cmd

    -- Parse based on command type
    if cmd == "FA" or cmd == "FB" then
        -- Frequency VFO A or B
        if #data == 11 then
            local freq = tonumber(data)
            if freq then
                subtree:add(fields.frequency, buffer(offset + data_start - 1, 11), freq):append_text(" (" .. format_frequency(freq) .. ")")
                info = cmd .. " " .. format_frequency(freq)
            end
        end

    elseif cmd == "MD" then
        -- Mode
        local mode_val = tonumber(data)
        if mode_val then
            local mode_item = subtree:add(fields.mode, buffer(offset + data_start - 1, #data), mode_val)
            if mode_names[mode_val] then
                mode_item:append_text(" (" .. mode_names[mode_val] .. ")")
                info = cmd .. " " .. mode_names[mode_val]
            end
        end

    elseif cmd == "DT" then
        -- Data sub-mode
        local submode_val = tonumber(data)
        if submode_val then
            local submode_item = subtree:add(fields.data_submode, buffer(offset + data_start - 1, #data), submode_val)
            if data_submode_names[submode_val] then
                submode_item:append_text(" (" .. data_submode_names[submode_val] .. ")")
                info = cmd .. " " .. data_submode_names[submode_val]
            end
        end

    elseif cmd == "IF" then
        -- Comprehensive status response
        parse_if_command(msg, subtree, buffer, offset)
        info = "IF Status Response"

    elseif cmd == "KS" then
        -- CW Speed
        local speed = tonumber(data)
        if speed then
            subtree:add(fields.cw_speed, buffer(offset + data_start - 1, #data), speed)
            info = cmd .. " " .. speed .. " WPM"
        end

    elseif cmd == "KY" then
        -- CW Text (text follows space)
        if #data > 1 then
            local cw_text = data:sub(2) -- Skip leading space
            subtree:add(fields.cw_text, buffer(offset + data_start, #cw_text), cw_text)
            info = cmd .. " \"" .. cw_text .. "\""
        end

    elseif cmd == "RO" then
        -- RIT/XIT Offset
        if #data >= 5 then
            local sign_char = data:sub(1, 1)
            local offset_str = data:sub(2, 5)
            local offset_val = tonumber(offset_str)
            if offset_val then
                if sign_char == "-" then
                    offset_val = -offset_val
                end
                subtree:add(fields.rit_offset, buffer(offset + data_start - 1, #data), offset_val)
                info = cmd .. " " .. offset_val .. " Hz"
            end
        end

    elseif cmd == "RT" then
        -- RIT On/Off
        local enabled = (data == "1")
        subtree:add(fields.rit_enabled, buffer(offset + data_start - 1, #data), enabled)
        info = cmd .. " " .. (enabled and "On" or "Off")

    elseif cmd == "XT" then
        -- XIT On/Off
        local enabled = (data == "1")
        subtree:add(fields.xit_enabled, buffer(offset + data_start - 1, #data), enabled)
        info = cmd .. " " .. (enabled and "On" or "Off")

    elseif cmd == "FT" then
        -- Split On/Off
        local enabled = (data == "1")
        subtree:add(fields.split_enabled, buffer(offset + data_start - 1, #data), enabled)
        info = cmd .. " " .. (enabled and "On" or "Off")

    elseif cmd == "TX" then
        -- Transmit
        subtree:add(fields.tx_state, buffer(offset, 2), true)
        info = "TX (Transmit)"

    elseif cmd == "RX" then
        -- Receive
        subtree:add(fields.tx_state, buffer(offset, 2), false)
        info = "RX (Receive)"

    elseif cmd == "BN" then
        -- Band Number
        local band_num = tonumber(data)
        if band_num then
            local band_item = subtree:add(fields.band_number, buffer(offset + data_start - 1, #data), band_num)
            if band_names[band_num] then
                band_item:append_text(" (" .. band_names[band_num] .. ")")
                info = cmd .. " " .. band_names[band_num]
            end
        end

    elseif cmd == "FP" then
        -- Filter Preset
        local preset = tonumber(data)
        if preset then
            subtree:add(fields.filter_preset, buffer(offset + data_start - 1, #data), preset)
            info = cmd .. " Preset " .. preset
        end

    elseif cmd == "AI" then
        -- Auto Information Level
        local level = tonumber(data)
        if level then
            subtree:add(fields.ai_level, buffer(offset + data_start - 1, #data), level)
            info = cmd .. " Level " .. level
        end

    elseif cmd == "ID" then
        -- Radio ID
        local radio_id = tonumber(data)
        if radio_id then
            local id_item = subtree:add(fields.radio_id, buffer(offset + data_start - 1, #data), radio_id)
            if radio_id == 17 then
                id_item:append_text(" (K4)")
                info = "ID K4"
            end
        end

    elseif cmd == "UP" or cmd == "DN" then
        -- VFO bump up/down
        info = cmd .. " VFO " .. (cmd == "UP" and "Up" or "Down")

    elseif cmd == "RC" then
        -- Clear RIT/XIT
        info = "RC (Clear RIT/XIT)"

    elseif cmd == "OM" then
        -- Option Modules - parse detailed option information
        info = parse_om_command(data, subtree, buffer, offset, data_start)

    else
        -- Unknown command - just show the data
        if #data > 0 then
            subtree:add(fields.full_message, buffer(offset + data_start - 1, #data), data)
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
            local msg_subtree = subtree:add(k4_proto, buffer(offset, msg_len), "Command: " .. msg .. ";")

            local info = parse_k4_command(msg, msg_subtree, buffer, offset)
            table.insert(info_parts, info)

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

-- Heuristic function to detect K4 protocol
local function k4_heuristic(buffer, pinfo, tree)
    if buffer:len() < 3 then return false end

    local data = buffer():string()

    -- Check if it looks like K4 command format
    -- Must contain semicolon and start with 2 letters
    if not data:match(";") then return false end

    -- Check for common K4 commands
    local common_commands = {
        "FA", "FB", "MD", "IF", "KS", "KY", "RT", "XT", "RO",
        "FT", "TX", "RX", "BN", "FP", "AI", "ID", "UP", "DN",
        "RC", "OM", "DT", "DA"
    }

    local first_two = data:sub(1, 2)
    for _, cmd in ipairs(common_commands) do
        if first_two == cmd then
            k4_proto.dissector(buffer, pinfo, tree)
            return true
        end
    end

    -- Check if it has VFO B marker
    if buffer:len() >= 3 and data:sub(3, 3) == "$" then
        local cmd = data:sub(1, 2)
        for _, common_cmd in ipairs(common_commands) do
            if cmd == common_cmd then
                k4_proto.dissector(buffer, pinfo, tree)
                return true
            end
        end
    end

    return false
end

-- Register the protocol on TCP port
-- K4 control port is 9200
local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(9200, k4_proto)

-- Also register heuristic dissector for unknown ports
k4_proto:register_heuristic("tcp", k4_heuristic)

-- Optionally register on additional ports if needed
-- tcp_port:add(50001, k4_proto)  -- Example: add another port
