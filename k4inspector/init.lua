-- K4Direct Protocol Dissector for Wireshark
-- Elecraft K4 Direct Interface Protocol Inspector
-- Protocol: ASCII text-based commands terminated with semicolon (;)

-- Create the protocol
local k4_proto = Proto("k4direct", "K4 Direct Protocol")

-- Require modules
local k4_fields = require("k4inspector.fields")
local k4_parsers = require("k4inspector.parsers")

-- Register protocol fields
k4_proto.fields = k4_fields

-- Parse individual K4 command using table-driven dispatch
local function parse_k4_command(msg, msg_subtree, buffer, offset)
    if #msg < 2 then
        msg_subtree:add(k4_fields.full_message, buffer(offset, #msg), msg)
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

        msg_subtree:add(k4_fields.command, buffer(offset, #cmd), cmd)
        if #data > 0 then
            msg_subtree:add(k4_fields.full_message, buffer(offset + #cmd, #data), data)
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
    msg_subtree:add(k4_fields.command, buffer(offset, 2), cmd)
    msg_subtree:add(k4_fields.vfo, buffer(offset, data_start - 1), vfo)

    -- Check for query format (command followed by ?)
    if data == "?" then
        msg_subtree:add(k4_fields.full_message, buffer(offset + data_start - 1, 1), "?")
        local info = cmd .. " Query"
        if vfo == "VFO B" then
            info = info .. " (VFO B)"
        end
        return info
    end

    -- Special cases that need different call signatures
    local info
    if cmd == "IF" then
        info = k4_parsers.parse_if_command(msg, msg_subtree, buffer, offset)
    elseif cmd == "OM" then
        info = k4_parsers.parse_om_command(data, msg_subtree, buffer, offset, data_start)
    else
        -- Lookup parser in registry
        local parser = k4_parsers.command_parsers[cmd]
        if parser then
            info = parser(cmd, data, msg_subtree, buffer, offset, data_start)
        else
            -- Unknown command - show raw data
            if #data > 0 then
                msg_subtree:add(k4_fields.full_message, buffer(offset + data_start - 1, #data), data)
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
