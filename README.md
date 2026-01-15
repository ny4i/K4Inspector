# K4 Inspector

A Wireshark protocol dissector for the Elecraft K4 Direct interface protocol, written in Lua.

Decodes ASCII text-based commands used to control the Elecraft K4 amateur radio transceiver over TCP/IP.

## Installation

### Method 1: User Plugin Directory (Recommended)

1. Find your Wireshark personal plugins directory:
   - In Wireshark, go to **Help** → **About Wireshark** → **Folders** tab
   - Look for "Personal Lua Plugins" path

2. Copy the entire `k4inspector/` directory to that location:
   ```bash
   cp -r k4inspector/ ~/.local/lib/wireshark/plugins/
   ```

3. Reload Lua plugins in Wireshark:
   - Press `Ctrl+Shift+L` (Windows/Linux) or `Cmd+Shift+L` (macOS)
   - Or restart Wireshark

### Method 2: Global Plugin Directory

Copy the `k4inspector/` directory to Wireshark's global plugins directory (requires admin/root):
- **Windows**: `C:\Program Files\Wireshark\plugins\k4inspector\`
- **macOS**: `/Applications/Wireshark.app/Contents/PlugIns/wireshark/k4inspector/`
- **Linux**: `/usr/lib/wireshark/plugins/k4inspector/`

### Method 3: Load Directly

Run Wireshark with the `-X` option:
```bash
wireshark -X lua_script:path/to/k4inspector/init.lua
```

## Configuration

The dissector is pre-configured for TCP port **9200** (K4 Direct control port). It also includes a heuristic dissector that can automatically identify K4 traffic on other ports.

To add additional ports, edit `k4inspector/init.lua`:

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

The dissector parses and decodes **50+ K4 Direct commands** organized by category:

#### Frequency & VFO Control
- **FA/FB** - VFO A/B Frequency (displayed in MHz)
- **UP/DN** - VFO Bump Up/Down
- **BN** - Band Number (160m-6m)
- **AB** - VFO Copy/Swap/Init

#### Operating Mode
- **MD** - Operating Mode (LSB, USB, CW, FM, AM, Data, CW-R, Data-R)
- **DT** - Data Sub-mode (DATA A, AFSK A, FSK D, PSK D)
- **DR** - Data Mode Baud Rate

#### RIT/XIT & Split
- **RT/XT** - RIT/XIT Enable/Disable
- **RO** - RIT/XIT Offset (Hz)
- **RC** - Clear RIT/XIT
- **FT** - Split Mode
- **LK** - VFO Lock

#### Transmit/Receive
- **TX/RX** - Transmit/Receive State
- **TS** - TX Test Mode

#### CW & Keying
- **KS** - CW Speed (WPM)
- **KY** - CW/DATA Message Text
- **CW** - CW Pitch (Hz)

#### Audio & Gain Controls
- **AG** - AF Gain
- **MG** - Microphone Gain
- **RG** - RF Gain
- **CP** - Speech Compression
- **SQ** - Squelch

#### Signal Processing
- **GT** - AGC Mode (Off/Slow/Fast)
- **PA** - Preamp (Off/10dB/18-20dB/Dual)
- **RA** - RX Attenuator (dB)
- **BW** - Receiver Bandwidth (Hz)
- **NB** - Noise Blanker
- **FP** - Filter Preset (1-5)

#### Antenna & Hardware
- **AN** - TX Antenna Selection
- **AR** - RX Antenna Selection
- **AT** - ATU Status (Bypass/Auto)

#### Power & Monitoring
- **PO** - Power Output (watts)
- **SM** - S-Meter Reading

#### Sub Receiver & Features
- **SB** - Sub RX Enable
- **SP** - Spot Enable/Disable

#### Status & Configuration
- **IF** - Basic Radio Information (comprehensive status)
- **AI** - Auto Information Level (0-5)
- **SI** - System Auto Info
- **ID** - Radio ID (K4 = 17)
- **OM** - Option Module Info (detailed hardware detection)

#### System Control
- **PS** - Power On/Off/Restart Control
- **DA** - Digital Audio Control
- **DM** - DTMF Tone
- **FC** - Panadapter Center
- **AF** - Audio Feedback

See `K4-Protocol-Reference.md` for complete protocol specification and implementation details.

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

### Automated Testing

Run the automated test suite to verify the dissector works correctly:

```bash
./run_tests.sh
```

This script runs two types of tests:

**1. Smoke Tests** - For each sample capture:
- Verifies no Lua errors occur during parsing
- Reports number of commands successfully parsed

**2. Golden Master Validation** - For liveK4.pcapng:
- Compares parsed field values against known-correct output
- Validates 136 parsed values (frequency, mode, band, etc.)
- Catches regressions in parsing logic

**Example output:**
```
==========================================
K4Inspector Dissector Automated Tests
==========================================

  basic_commands.pcap            ✓ PASS (10 commands parsed)
  if_status.pcap                 ✓ PASS (11 commands parsed)
  liveK4.pcapng                  ✓ PASS (141 commands parsed)
  ...

==========================================
Golden Master Validation
==========================================

Validating liveK4.pcapng against golden master...
✓ PASS: All 136 parsed values match golden master

==========================================
Final Results
==========================================
  Smoke tests passed: 7
  Golden master: 1
  Failed: 0

✓ All tests passed!
```

### Updating the Golden Master

If you intentionally change parsing behavior, regenerate the golden master:

```bash
samples/golden_master_test.sh --generate
```

### Manual Testing

1. Capture K4 traffic using Wireshark on the network interface connected to your K4
2. Place sample `.pcap` or `.pcapng` files in the `samples/` directory for testing
3. Open captures in Wireshark with the dissector installed
4. Verify protocol decoding is correct by expanding the "K4 Direct Protocol" tree

### Sample Captures

See `samples/README.md` for details on included test captures:
- **liveK4.pcapng** - Real production K4 traffic (155KB)
- 5 synthetic captures covering specific protocol features

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
