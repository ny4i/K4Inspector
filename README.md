# K4 Inspector

A Wireshark protocol dissector for the K4 protocol, written in Lua.

## Installation

### Method 1: User Plugin Directory (Recommended)

1. Find your Wireshark personal plugins directory:
   - In Wireshark, go to **Help** → **About Wireshark** → **Folders** tab
   - Look for "Personal Lua Plugins" path

2. Copy `k4_inspector.lua` to that directory

3. Reload Lua plugins in Wireshark:
   - Press `Ctrl+Shift+L` (Windows/Linux) or `Cmd+Shift+L` (macOS)
   - Or restart Wireshark

### Method 2: Global Plugin Directory

Copy `k4_inspector.lua` to Wireshark's global plugins directory (requires admin/root):
- **Windows**: `C:\Program Files\Wireshark\plugins\`
- **macOS**: `/Applications/Wireshark.app/Contents/PlugIns/wireshark/`
- **Linux**: `/usr/lib/wireshark/plugins/` or `/usr/local/lib/wireshark/plugins/`

### Method 3: Load Directly

Run Wireshark with the `-X` option:
```bash
wireshark -X lua_script:path/to/k4_inspector.lua
```

## Configuration

The dissector currently registers on TCP port 0 (disabled by default). Update the port number in `k4_inspector.lua`:

```lua
local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(YOUR_PORT_NUMBER, k4_proto)
```

## Usage

1. Capture network traffic containing K4 protocol packets
2. The dissector will automatically decode K4 packets
3. Filter for K4 protocol using: `k4` in the Wireshark filter bar

## Development

### Protocol Structure

Update the protocol fields in `k4_inspector.lua` to match your K4 protocol specification.

### Testing

1. Use sample captures in the `samples/` directory
2. Open captures in Wireshark with the dissector installed
3. Verify protocol decoding is correct

## Troubleshooting

### Dissector Not Loading

- Check Wireshark's Lua console: **Tools** → **Lua** → **Evaluate**
- Look for errors in: **Help** → **About Wireshark** → **Wireshark Log**

### Protocol Not Dissecting

- Verify the correct port/protocol is configured
- Check if a heuristic dissector is needed for your use case

## License

[Add your license here]

## Contributing

[Add contributing guidelines here]
