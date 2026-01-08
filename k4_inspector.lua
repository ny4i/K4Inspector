-- K4 Protocol Dissector for Wireshark
-- Protocol Inspector for K4

-- Create the protocol
local k4_proto = Proto("k4", "K4 Protocol")

-- Define protocol fields
local fields = k4_proto.fields
fields.version = ProtoField.uint8("k4.version", "Version", base.DEC)
fields.message_type = ProtoField.uint8("k4.message_type", "Message Type", base.HEX)
fields.length = ProtoField.uint16("k4.length", "Length", base.DEC)
fields.payload = ProtoField.bytes("k4.payload", "Payload")

-- Dissector function
function k4_proto.dissector(buffer, pinfo, tree)
    -- Set protocol column
    pinfo.cols.protocol = "K4"

    -- Check if packet is too small
    local length = buffer:len()
    if length == 0 then return end

    -- Create protocol tree
    local subtree = tree:add(k4_proto, buffer(), "K4 Protocol Data")

    -- TODO: Add your protocol dissection logic here
    -- Example structure (adjust based on your actual protocol):
    -- subtree:add(fields.version, buffer(0, 1))
    -- subtree:add(fields.message_type, buffer(1, 1))
    -- subtree:add(fields.length, buffer(2, 2))

    -- For now, just show the raw data
    subtree:add(fields.payload, buffer())

    -- Set info column
    pinfo.cols.info = string.format("K4 Protocol (Length: %d)", length)
end

-- Register the protocol
-- TODO: Update with your actual port or heuristic dissector
-- For TCP:
local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(0, k4_proto)  -- Change 0 to your actual port number

-- For UDP:
-- local udp_port = DissectorTable.get("udp.port")
-- udp_port:add(0, k4_proto)  -- Change 0 to your actual port number

-- For heuristic dissection (when port is unknown):
-- function k4_proto.heuristic(buffer, pinfo, tree)
--     if buffer:len() < 4 then return false end
--     -- Add logic to identify K4 protocol
--     -- Return true if it's K4, false otherwise
--     return false
-- end
-- k4_proto:register_heuristic("tcp", k4_proto.heuristic)
