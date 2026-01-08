# K4 Inspector

A Wireshark protocol dissector for the Elecraft K4 Direct interface protocol, written in Lua.

Decodes ASCII text-based commands used to control the Elecraft K4 amateur radio transceiver over TCP/IP.

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

The dissector is pre-configured for TCP port **9200** (K4 Direct control port). It also includes a heuristic dissector that can automatically identify K4 traffic on other ports.

To add additional ports, edit `k4_inspector.lua`:

```lua
local tcp_port = DissectorTable.get("tcp.port")
tcp_port:add(9200, k4_proto)
tcp_port:add(YOUR_PORT, k4_proto)  -- Add your custom port
```

## Usage

1. Capture network traffic containing K4 Direct protocol packets (TCP port 9200)
2. The dissector will automatically decode K4 packets
3. Filter for K4 protocol using: `k4direct` in the Wireshark filter bar

### Supported Commands

The dissector parses and decodes the following K4 commands:

- **FA/FB** - VFO A/B Frequency (displayed in MHz)
- **MD** - Operating Mode (LSB, USB, CW, FM, AM, Data, CW-R, Data-R)
- **DT** - Data Sub-mode (DATA A, AFSK A, FSK D, PSK D)
- **IF** - Comprehensive Status Response (all transceiver parameters)
- **KS** - CW Speed (WPM)
- **KY** - CW Text Transmission
- **RT/XT** - RIT/XIT Enable/Disable
- **RO** - RIT/XIT Offset (Hz)
- **FT** - Split Mode
- **TX/RX** - Transmit/Receive State
- **BN** - Band Number (160m-6m)
- **FP** - Filter Preset (1-5)
- **AI** - Auto Information Level (0-5)
- **ID** - Radio ID (identifies K4 as ID 17)
- **UP/DN** - VFO Bump Up/Down
- **RC** - Clear RIT/XIT
- **OM** - Option Modules Query

### VFO Support

The dissector automatically detects and displays which VFO (A or B) each command targets:
- VFO A commands: Standard format (e.g., `FA`, `MD`)
- VFO B commands: `$` suffix after command (e.g., `FB`, `MD$`)

### Example Filters

```
k4direct                          # Show all K4 Direct traffic
k4direct.frequency                # Show frequency changes
k4direct.mode                     # Show mode changes
k4direct.tx_state == 1            # Show only TX packets
k4direct.command == "IF"          # Show IF status responses
k4direct.vfo == "VFO B"           # Show VFO B commands only
```

## Protocol Details

### Message Format

K4 Direct uses ASCII text-based commands over TCP/IP:
- **Format**: Two-letter command + parameters + semicolon terminator (`;`)
- **Example**: `FA00014200000;` (set VFO A to 14.200 MHz)
- **Encoding**: Latin-1/ASCII
- **Port**: TCP 9200

### IF Command Structure

The IF (status query) command returns comprehensive transceiver information in a 36+ character response:

```
IF00014200000     +0000001001000301;
  └─Frequency     └─RIT/XIT offset and state
                    └─TX/RX, Mode, VFO, Split, Data mode
```

Decoded fields include: frequency, RIT/XIT offset and enable status, TX/RX state, operating mode, active VFO, scan status, split mode, and data sub-mode.

## Testing

1. Capture K4 traffic using Wireshark on the network interface connected to your K4
2. Place sample `.pcap` or `.pcapng` files in the `samples/` directory for testing
3. Open captures in Wireshark with the dissector installed
4. Verify protocol decoding is correct by expanding the "K4 Direct Protocol" tree

## Troubleshooting

### Dissector Not Loading

- Check Wireshark's Lua console: **Tools** → **Lua** → **Evaluate**
- Look for errors in: **Help** → **About Wireshark** → **Wireshark Log**
- Verify the file is in the correct plugins directory
- Try reloading Lua plugins: `Ctrl+Shift+L` (Windows/Linux) or `Cmd+Shift+L` (macOS)

### Protocol Not Dissecting

- Verify traffic is on TCP port 9200 (or use the heuristic dissector for other ports)
- Check that packets contain semicolon-terminated commands
- Use display filter `tcp.port == 9200` to verify K4 traffic is being captured
- The heuristic dissector looks for common K4 commands (FA, FB, MD, IF, etc.)

### No Traffic Visible

- Ensure you're capturing on the correct network interface
- Check that your K4 is connected to the network and communication is active
- Use `tcp.port == 9200` filter to isolate K4 traffic
- Verify firewall settings allow capturing on the interface

## About K4 Direct Protocol

The K4 Direct interface is Elecraft's native TCP/IP control protocol for the K4 transceiver. It provides low-latency control compared to serial-based protocols like Hamlib. The protocol uses simple ASCII commands for all radio functions including frequency control, mode selection, CW keying, and status monitoring.

This dissector was developed by analyzing the TR4QT/TR4W logging software implementation.

## Contributing

Contributions are welcome! If you find bugs or want to add support for additional K4 commands, please submit an issue or pull request.
