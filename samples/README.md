# K4 Direct Protocol Sample Captures

This directory contains synthetic PCAP files for testing and demonstrating the K4Inspector dissector.

## Sample Files

### 1. basic_commands.pcap
**Purpose:** Test basic command parsing and request/response flow
**Contains:**
- `FA;` - Request VFO A frequency
- `FA00014074000;` - Response: 14.074 MHz
- `MD;` - Request mode
- `MD3;` - Response: CW mode
- `FB$00007200000;` - Set VFO B to 7.2 MHz

**Expected Results:**
- All commands parse without errors
- Frequency displays as "14.074000 MHz"
- Mode shows as "3 (CW)"
- VFO B marker correctly identified

**How to verify:**
```
tshark -r basic_commands.pcap -Y "k4direct.command == FA" -T fields -e k4direct.frequency
# Should output: 14074000
```

---

### 2. if_status.pcap
**Purpose:** Test comprehensive IF (status) command parsing
**Contains:**
- Multiple IF command queries and responses
- RX state: `IF00014074000     +000000 0001001001 ;`
  - 14.074 MHz, LSB mode, RX, no RIT/XIT
- TX state: `IF00014074000     +015010 0102001001 ;`
  - 14.074 MHz, USB mode, TX active, RIT +150 Hz
- Data mode: `IF00021074000     +000000 0006001001 ;`
  - 21.074 MHz, Data mode, sub-mode 0 (DATA A)

**Expected Results:**
- All IF fields parse correctly:
  - Frequency
  - RIT/XIT offset and enable status
  - TX/RX state
  - Mode and data sub-mode
  - Split status
- Info column shows comprehensive summary

**How to verify:**
```
tshark -r if_status.pcap -Y "k4direct.tx_state == 1"
# Should show packet with TX active
```

---

### 3. panadapter_commands.pcap
**Purpose:** Test # command (panadapter/display) parsing
**Contains:**
- `#SPN$46125;` - Set span to 46.125 kHz
- `#REF$-20;` - Set reference level to -20 dBm
- `#AR1506+001;` - Configure auto-ref (avg=15, debounce=6, offset=0, mode=on)
- `#VFA2;` - VFO A cursor display mode AUTO
- `#WFC$1;` - Waterfall color mode 1 (color)

**Expected Results:**
- All # commands parse with correct command name extraction
- Command: `#SPN$`, Data: `46125`
- Command: `#AR`, Data: `1506+001`
- No errors on variable-length command names

**How to verify:**
```
tshark -r panadapter_commands.pcap -T fields -e k4direct.command
# Should show: #SPN$, #REF$, #AR, #VFA, #WFC$
```

---

### 4. mixed_session.pcap
**Purpose:** Test realistic multi-command usage session
**Contains:**
- Initial status queries: `IF;OM;`
- Frequency and mode changes: `FA00007074000;MD2;`
- RIT configuration: `RT$1;RO$+00150;`
- Gain adjustments: `AG050;RG200;`
- TX/RX transitions with status monitoring

**Expected Results:**
- Multiple commands per packet parse correctly
- OM command identifies K4 with ATU, PA, SUB RX
- State transitions visible in IF responses
- Info column shows comma-separated command list

**How to verify:**
```
tshark -r mixed_session.pcap -T fields -e k4direct.command | sort | uniq
# Should show: AG, FA, IF, MD, OM, RG, RO$, RT$, RX, TX
```

---

### 5. om_hardware.pcap
**Purpose:** Test OM (Option Module) hardware detection
**Contains:**
- `OM AP-S----4--;` - K4 with ATU, PA, SUB RX
- `OM AP-SH---4D-;` - K4D (high-performance DDC)
- `OM AP-SH---4DH;` - K4HD (with HDR module)

**Expected Results:**
- Radio model correctly identified:
  - First: "K4" (base model)
  - Second: "K4D" (DDC flag at position 9)
  - Third: "K4HD" (DDC + HDR flags)
- Hardware modules parsed:
  - ATU (KAT4) - position 0
  - PA (KPA4) - position 1
  - SUB RX - position 3
  - HDR MODULE - position 4

**How to verify:**
```
tshark -r om_hardware.pcap -Y "k4direct.om_model" -T fields -e k4direct.om_model
# Should output: K4, K4D, K4HD
```

---

## Using These Samples

### Quick Test
Load any sample in Wireshark to verify the dissector is working:
```bash
wireshark samples/basic_commands.pcap
```

The K4 Direct Protocol should automatically dissect the traffic on port 9200.

### Automated Testing
Use tshark to verify parsing:
```bash
# Test all samples
for f in samples/*.pcap; do
    echo "Testing $f..."
    tshark -r "$f" -Y k4direct -T fields -e k4direct.command >/dev/null && echo "✓ OK" || echo "✗ FAIL"
done
```

### Filter Examples
```bash
# Show only frequency changes
tshark -r samples/mixed_session.pcap -Y "k4direct.command == FA || k4direct.command == FB"

# Show TX events
tshark -r samples/mixed_session.pcap -Y "k4direct.tx_state == 1"

# Extract all frequencies
tshark -r samples/if_status.pcap -T fields -e k4direct.frequency
```

---

## Generating New Samples

The samples were created using `generate_samples.py`. To regenerate or create new samples:

```bash
python3 generate_samples.py
```

This creates synthetic PCAP files with proper Ethernet/IP/TCP headers and K4 Direct protocol payloads.

### Adding New Test Cases

Edit `generate_samples.py` to add new command sequences:

```python
def generate_new_test():
    """Generate new_test.pcap - Description here."""
    print("Generating new_test.pcap...")

    with open('samples/new_test.pcap', 'wb') as f:
        f.write(PCAP_GLOBAL_HEADER)

        timestamp = time.time()
        k4_data = "YourCommand;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108',
                               54000, 9200, 1000, 2000, 0x18, k4_data)
        write_packet(f, timestamp, pkt)
```

---

## Expected Behavior Summary

| File | Packets | Commands Tested | Key Validation |
|------|---------|----------------|----------------|
| basic_commands.pcap | 5 | FA, FB, MD | Frequency parsing, VFO detection |
| if_status.pcap | 6 | IF | All IF fields, TX/RX state |
| panadapter_commands.pcap | 5 | #SPN$, #REF$, #AR, #VFA, #WFC$ | # command name extraction |
| mixed_session.pcap | 11 | FA, MD, RT$, RO$, AG, RG, TX, RX, IF, OM | Multi-command packets |
| om_hardware.pcap | 6 | OM | Hardware detection, model ID |

**Total:** 33 packets across 5 files covering 20+ distinct command types.
