# Elecraft K4 Direct Protocol Reference

**Version:** 1.0
**Date:** 2026-01-08
**Source:** K4 Programmer's Reference Rev. D5, TR4QT Implementation Analysis, K4Inspector Dissector

## Overview

The K4 Direct protocol is Elecraft's native TCP/IP control interface for the K4 transceiver. It provides low-latency radio control via simple ASCII text commands transmitted over Ethernet.

### Connection Parameters
- **Protocol:** TCP/IP
- **Control Port:** 9200
- **Discovery Port:** 9100 (UDP broadcast)
- **Encoding:** Latin-1/ASCII
- **Message Format:** `COMMAND[PARAMS];` (semicolon-terminated)
- **Discovery Message:** `"findk4"` (UDP broadcast)
- **Discovery Response:** `"k4:index:ip:serial"` (e.g., `k4:0:192.168.1.100:278`)

### Protocol Characteristics
- **Latency:** 5-10ms typical (vs 50-100ms for Hamlib)
- **Update Model:** Push-based via AI5 (Auto Information) mode
- **VFO Encoding:** Commands with `$` after 2-letter code target VFO B
- **No Polling Required:** Radio pushes state changes when AI5 is enabled

---

## Command Reference

### Format Conventions

#### General Syntax
```
CMD[PARAMS];        # VFO A
CMD$[PARAMS];       # VFO B (most commands)
```

#### Parameter Types
- `f` = Frequency (11 digits, Hz, zero-padded)
- `n` = Integer (variable length)
- `nnn` = Fixed-length integer (zero-padded)
- `t` = Text string
- `0/1` = Boolean (0=off/false, 1=on/true)

---

## Command Categories

### 1. Frequency & VFO Control

#### FA - VFO A Frequency
**Syntax:** `FA[fffffffffff];`
**Parameters:** 11-digit frequency in Hz (0-99999999999)
**Example:** `FA00014200000;` = 14.200 MHz
**Response:** `FA[frequency];`

#### FB - VFO B Frequency
**Syntax:** `FB[fffffffffff];`
**Parameters:** 11-digit frequency in Hz
**Example:** `FB00007100000;` = 7.100 MHz
**Response:** `FB[frequency];`

#### UP - VFO A Frequency Up
**Syntax:** `UP;`
**Action:** Increments VFO A frequency by current tuning step
**Response:** None (triggers AI update if enabled)

#### DN - VFO A Frequency Down
**Syntax:** `DN;`
**Action:** Decrements VFO A frequency by current tuning step
**Response:** None (triggers AI update if enabled)

#### UPB - VFO B Frequency Up
**Syntax:** `UPB;`
**Action:** Increments VFO B frequency by current tuning step
**Response:** None

#### DNB - VFO B Frequency Down
**Syntax:** `DNB;`
**Action:** Decrements VFO B frequency by current tuning step
**Response:** None

#### BN - Band Number
**Syntax:** `BN[nn];` or `BN$[nn];`
**Parameters:** Band number (00-10)
**Values:**
- `00` = 160m (1.8-2.0 MHz)
- `01` = 80m (3.5-4.0 MHz)
- `02` = 60m (5.3-5.4 MHz)
- `03` = 40m (7.0-7.3 MHz)
- `04` = 30m (10.1-10.15 MHz)
- `05` = 20m (14.0-14.35 MHz)
- `06` = 17m (18.068-18.168 MHz)
- `07` = 15m (21.0-21.45 MHz)
- `08` = 12m (24.89-24.99 MHz)
- `09` = 10m (28.0-29.7 MHz)
- `10` = 6m (50-54 MHz)

**Example:** `BN05;` = Select 20m band
**Response:** `BN[nn];`

#### AB - VFO Copy/Swap/Init
**Syntax:** `AB[n];`
**Parameters:**
- `0` = Copy VFO A to VFO B
- `1` = Swap VFO A and VFO B
- `2` = Init VFO B from VFO A

**Response:** None

---

### 2. Operating Mode

#### MD - Operating Mode
**Syntax:** `MD[n];` or `MD$[n];`
**Parameters:** Mode code (0-9)
**Values:**
- `0` = None
- `1` = LSB (Lower Sideband)
- `2` = USB (Upper Sideband)
- `3` = CW (Morse Code)
- `4` = FM (Frequency Modulation)
- `5` = AM (Amplitude Modulation)
- `6` = Data (requires DT sub-mode)
- `7` = CW-R (CW Reverse)
- `9` = Data-R (Data Reverse)

**Example:** `MD3;` = Set CW mode
**Response:** `MD[n];`

#### DT - Data Sub-mode
**Syntax:** `DT[n];` or `DT$[n];`
**Parameters:** Sub-mode code (0-3)
**Values:**
- `0` = DATA A (Audio FSK)
- `1` = AFSK A (AFSK Audio)
- `2` = FSK D (Direct FSK input)
- `3` = PSK D (Direct PSK input)

**Example:** `DT0;` = Set DATA A mode
**Response:** `DT[n];`

#### DR - Data Mode Baud Rate
**Syntax:** `DR[n];`
**Parameters:** Baud rate selection
- `0` = 45 baud (FSK)
- `1` = 75 baud (FSK)
- `2` = 31 baud (PSK)
- `3` = 63 baud (PSK)

**Response:** `DR[n];`

---

### 3. RIT/XIT & Split

#### RT - RIT On/Off
**Syntax:** `RT[0/1];` or `RT$[0/1];`
**Parameters:** 0=off, 1=on
**Example:** `RT1;` = Enable RIT
**Response:** `RT[0/1];`

#### XT - XIT On/Off
**Syntax:** `XT[0/1];` or `XT$[0/1];`
**Parameters:** 0=off, 1=on
**Example:** `XT1;` = Enable XIT
**Response:** `XT[0/1];`

#### RO - RIT/XIT Offset
**Syntax:** `RO[+/-nnnn];` or `RO$[+/-nnnn];`
**Parameters:** Signed offset in Hz (-9999 to +9999)
**Format:** Sign (1 char) + 4-digit value
**Example:** `RO+0100;` = +100 Hz offset
**Response:** `RO[offset];`

#### RC - Clear RIT/XIT
**Syntax:** `RC;`
**Action:** Resets RIT/XIT offset to 0
**Response:** Echo

#### FT - Split Mode
**Syntax:** `FT[0/1];`
**Parameters:** 0=off, 1=on
**Example:** `FT1;` = Enable split
**Response:** `FT[0/1];`

#### LK - VFO Lock
**Syntax:** `LK[0/1];` or `LK$[0/1];`
**Parameters:** 0=unlocked, 1=locked
**Example:** `LK1;` = Lock VFO
**Response:** `LK[0/1];`

---

### 4. Transmit/Receive

#### TX - Go to Transmit
**Syntax:** `TX;`
**Action:** Activates transmit mode
**Response:** Echo (triggers AI update)

#### RX - Go to Receive
**Syntax:** `RX;`
**Action:** Returns to receive mode
**Response:** Echo (triggers AI update)

#### TS - TX Test Mode
**Syntax:** `TS[0/1];`
**Parameters:** 0=off, 1=on
**Action:** Enables control verification without RF output
**Response:** `TS[0/1];`

---

### 5. CW & Keying

#### KS - CW Keyer Speed
**Syntax:** `KS[nnn];`
**Parameters:** Speed in WPM (008-100), 3 digits, zero-padded
**Example:** `KS025;` = 25 WPM
**Response:** `KS[nnn];`

#### KY - CW/DATA Message Text
**Syntax:** `KY [text];`
**Parameters:** Text to send (space after KY)
**Example:** `KY CQ TEST;`
**Response:** None (no echo)
**Stop Transmission:** Send ASCII 0x04 (Ctrl-D) followed by `;RX;`

**Completion Estimation:**
K4 doesn't send completion notification. Estimate duration:
```
duration_ms = (text.length * 1200) / (cwSpeed * 5) * 1.2
```
- 1200 = dit duration at 1 WPM
- 5 = average chars per word
- 1.2 = 20% buffer

#### CW - CW Pitch
**Syntax:** `CW[nnnn];`
**Parameters:** Pitch frequency in Hz (300-1000)
**Example:** `CW0600;` = 600 Hz sidetone
**Response:** `CW[nnnn];`

---

### 6. Audio & Gain Controls

#### AG - AF Gain
**Syntax:** `AG[nnn];` or `AG$[nnn];`
**Parameters:** Gain level (0-255)
**Example:** `AG050;`
**Response:** `AG[nnn];`

#### MG - Microphone Gain
**Syntax:** `MG[nn];`
**Parameters:** Gain level (0-80)
**Example:** `MG050;`
**Response:** `MG[nn];`

#### RG - RF Gain
**Syntax:** `RG[nnn];` or `RG$[nnn];`
**Parameters:** DSP scalar gain (0-255)
**Example:** `RG250;`
**Response:** `RG[nnn];`

#### CP - Speech Compression
**Syntax:** `CP[nn];`
**Parameters:** Compression level (0-20)
**Example:** `CP10;`
**Response:** `CP[nn];`

#### SQ - Squelch
**Syntax:** `SQ[nnn];` or `SQ$[nnn];`
**Parameters:** Squelch level (0-255, FM mode)
**Example:** `SQ100;`
**Response:** `SQ[nnn];`

---

### 7. Signal Processing

#### GT - AGC Mode
**Syntax:** `GT[n];` or `GT$[n];`
**Parameters:** AGC mode (0-2)
**Values:**
- `0` = Off
- `1` = Slow
- `2` = Fast

**Example:** `GT1;` = Slow AGC
**Response:** `GT[n];`

#### PA - Preamp
**Syntax:** `PA[n];` or `PA$[n];`
**Parameters:** Preamp selection (0-3)
**Values:**
- `0` = Off
- `1` = 10dB
- `2` = 18/20dB (varies by band)
- `3` = Dual (both preamps)

**Example:** `PA1;` = 10dB preamp
**Response:** `PA[n];`

#### RA - RX Attenuator
**Syntax:** `RA[nn];` or `RA$[nn];`
**Parameters:** Attenuation in 3dB steps (0-30)
**Example:** `RA09;` = 9dB attenuation
**Response:** `RA[nn];`

#### BW - Receiver Filter Bandwidth
**Syntax:** `BW[nnnn];` or `BW$[nnnn];`
**Parameters:** Bandwidth in Hz (mode-specific)
**Example:** `BW2700;` = 2.7 kHz filter
**Response:** `BW[nnnn];`

#### NB - Noise Blanker
**Syntax:** `NB[n];` or `NB$[n];`
**Parameters:** 0=off, 1=on, 2=auto
**Example:** `NB1;`
**Response:** `NB[n];`

#### FP - Filter Preset
**Syntax:** `FP[n];` or `FP$[n];`
**Parameters:** Preset number (1-5)
**Example:** `FP3;` = Select preset 3
**Response:** `FP[n];`

---

### 8. Antenna & Hardware

#### AN - TX Antenna Selection
**Syntax:** `AN[n];`
**Parameters:** Antenna number (1-6)
**Example:** `AN1;` = TX antenna 1
**Response:** `AN[n];`

#### AR - RX Antenna Selection
**Syntax:** `AR[n];` or `AR$[n];`
**Parameters:** Antenna number (1-6)
**Example:** `AR2;` = RX antenna 2
**Response:** `AR[n];`

#### AT - ATU Mode Control
**Syntax:** `AT[n];`
**Parameters:** ATU mode (0-1)
**Values:**
- `0` = Bypass
- `1` = Auto tune

**Example:** `AT1;` = Enable ATU
**Response:** `AT[n];`

---

### 9. Power & Monitoring

#### PO - Power Output
**Syntax:** `PO;` (query only)
**Response:** `PO[nnnn];`
**Format:** Power in tenths of watts
**Example:** `PO0050;` = 5.0 watts
**Conversion:** `watts = value / 10.0`

#### SM - S-Meter Reading
**Syntax:** `SM;` or `SM$;` (query)
**Response:** `SM[nnnn];`
**Format:** S-meter value (0-9999)
**Example:** `SM0050;`

---

### 10. Sub Receiver & Features

#### SB - Sub RX Enable
**Syntax:** `SB[0/1];`
**Parameters:** 0=off, 1=on
**Example:** `SB1;` = Enable sub receiver
**Response:** `SB[0/1];`

#### SP - Spot Enable
**Syntax:** `SP[0/1];`
**Parameters:** 0=off, 1=on
**Action:** Generates reference tone at current frequency
**Example:** `SP1;`
**Response:** `SP[0/1];`

---

### 11. Status & Configuration

#### IF - Basic Radio Information
**Syntax:** `IF;`
**Response:** `IF[data];` (36+ characters)
**Format:** `IF[f]*****+yyyyrx*00tmvspbd*;`

**Field Breakdown:**

| Position | Length | Field | Description |
|----------|--------|-------|-------------|
| 0-1 | 2 | CMD | "IF" command |
| 2-12 | 11 | Freq | Operating frequency (Hz) |
| 13-17 | 5 | Spaces | Filler |
| 18 | 1 | Sign | RIT/XIT offset sign (+/-) |
| 19-22 | 4 | Offset | RIT/XIT offset (Hz) |
| 23 | 1 | RIT | RIT enabled (0/1) |
| 24 | 1 | XIT | XIT enabled (0/1) |
| 25-27 | 3 | Const | Always " 00" |
| 28 | 1 | TX | Transmit state (0=RX, 1=TX) |
| 29 | 1 | Mode | Operating mode (0-9) |
| 30 | 1 | VFO | Active VFO (0=A, 1=B) |
| 31 | 1 | Scan | Scan in progress (0/1) |
| 32 | 1 | Split | Split mode (0/1) |
| 33 | 1 | Band | Band change flag |
| 34 | 1 | Data | Data sub-mode (0-3) |
| 35 | 1 | Term | Semicolon |

**Example:**
```
IF00014200000     +0000001001000301;
  └─14.200 MHz    └─RIT +0Hz, RIT off, XIT off
                    └─RX, CW, VFO A, no split, DATA A
```

#### AI - Auto Information Mode
**Syntax:** `AI[n];`
**Parameters:** AI level (0-5)
**Values:**
- `0` = Off (no automatic updates)
- `1` = Basic updates
- `2` = Extended updates
- `3` = More comprehensive
- `5` = Most comprehensive (recommended for TR4QT/TR4W)

**Example:** `AI5;` = Enable full auto-info
**Response:** `AI[n];`
**Effect:** Radio pushes state changes automatically

#### SI - System Auto Info
**Syntax:** `SI[n];`
**Parameters:** Module-specific AI4 reporting
**Response:** `SI[n];`

#### ID - Radio Identification
**Syntax:** `ID;`
**Response:** `ID[nnn];`
**Values:**
- `017` = K4 transceiver
- Other values = Different Elecraft radios

**Example Response:** `ID017;` (K4)

#### OM - Option Module Info
**Syntax:** `OM;`
**Response:** `OM [string];`
**Format:** Position-based option string

**Position Map:**
```
Position: 0 1 2 3 4 5 6 7 8 9 ...
Example:  A P - S - - - - 4 - ...
```

**Character Meanings:**

| Pos | Char | Option | Description |
|-----|------|--------|-------------|
| 0 | A | ATU | KAT4 Automatic Antenna Tuner |
| 1 | P | PA | KPA4 Power Amplifier |
| 2 | X | XVTR | Transverter installed |
| 3 | S | SUB RX | KRX4 + KDDC4 (standard in K4D) |
| 4 | H | HDR | KHDR4 + KDDC4-2 (standard in K4HD) |
| 5 | M | K40 Mini | K40 Mini model |
| 6 | L | Linear | Generic linear amp detected |
| 7 | 1 | KPA1500 | KPA1500 specific amp |
| 8 | 4 | K4 ID | K4 identifier flag |

**Model Detection:**
- Base: K4
- If S + 4: K4D (with Sub RX)
- If S + H + 4: K4HD (with Sub RX and HDR)

**Example:** `OM AP-S----4--;`
- Position 0: `A` = ATU installed
- Position 1: `P` = PA installed
- Position 2: `-` = No XVTR
- Position 3: `S` = Sub RX installed
- Position 8: `4` = K4 identifier
- **Result:** K4D with ATU, PA, and Sub RX

---

### 12. System Control

#### PS - Power Control
**Syntax:** `PS[n];`
**Parameters:** Power control (0-2)
**Values:**
- `0` = Power off
- `1` = Power on
- `2` = Restart

**Response:** `PS[n];`

#### DA - Digital Audio Control
**Syntax:** `DAMP[m][nnnnn];`
**Parameters:**
- `m` = Message bank (1-8)
- `nnnnn` = Position in message (00000 = start)

**Example:** `DAMP100000;` = Play DVK message 1 from start
**Response:** None

#### DM - DTMF Tone
**Syntax:** `DM[n];`
**Parameters:** DTMF digit/character
**Response:** `DM[n];`

#### FC - Panadapter Center
**Syntax:** `FC[fffffffffff];`
**Parameters:** Center frequency (11 digits, Hz)
**Response:** `FC[frequency];`

#### AF - Audio Feedback
**Syntax:** `AF[n];`
**Parameters:** Feedback mode
**Response:** `AF[n];`

---

## Initialization Sequence

**Recommended connection sequence for applications:**

1. **Connect to TCP port 9200**
2. **Enable AI5 mode** for automatic updates:
   ```
   AI5;
   ```
3. **Query initial state (VFO A):**
   ```
   FA;      # Frequency A
   MD;      # Mode A
   DT;      # Data sub-mode A
   RT;      # RIT state
   XT;      # XIT state
   RO;      # RIT/XIT offset
   FT;      # Split state
   KS;      # CW speed
   BN;      # Band number
   IF;      # Comprehensive status
   ```
4. **Query initial state (VFO B):**
   ```
   FB;      # Frequency B
   MD$;     # Mode B
   DT$;     # Data sub-mode B
   ```
5. **Query radio configuration:**
   ```
   ID;      # Radio ID (verify K4 = 017)
   OM;      # Option modules
   ```

---

## VFO A/B Command Syntax

Most commands support VFO selection via the `$` suffix:

### VFO A (Default)
Standard command format:
```
FA00014200000;    # Set VFO A frequency
MD3;              # Set VFO A mode to CW
RT1;              # Enable RIT on VFO A
```

### VFO B ($ Suffix)
Insert `$` after the 2-letter command:
```
FB00007100000;    # Set VFO B frequency (special: FB not FA$)
MD$3;             # Set VFO B mode to CW
RT$1;             # Enable RIT on VFO B
```

### Special Cases
- **Frequency commands:** Use `FA` and `FB` (not `FA$` for VFO B)
- **IF query:** Only works for current active VFO
- **Global commands:** Some commands (TX, RX, ID, OM) don't have VFO variants

---

## Error Handling

### No Response Timeout
K4 Direct is asynchronous. Commands may not receive immediate responses. Rely on AI5 updates for state changes.

### Invalid Commands
Radio silently ignores invalid commands. No error response is generated.

### Command Verification
Use AI5 mode to receive confirmation of state changes via automatic status updates.

---

## Implementation Notes

### Message Parsing
```cpp
// Receive buffer pattern
void onReadyRead()
{
    QByteArray data = socket->readAll();
    receiveBuffer += QString::fromLatin1(data);

    // Process complete messages (terminated with ;)
    while (receiveBuffer.contains(';')) {
        int idx = receiveBuffer.indexOf(';');
        QString message = receiveBuffer.left(idx);
        receiveBuffer = receiveBuffer.mid(idx + 1);

        if (!message.isEmpty()) {
            processMessage(message);
        }
    }
}
```

### Command Sending
```cpp
void sendCommand(const QString& cmd, VFO vfo)
{
    QString fullCmd = cmd;

    // Add VFO B suffix if needed
    if (vfo == VFO::VFO_B && !cmd.contains('$')) {
        if (fullCmd.length() >= 2) {
            fullCmd.insert(2, '$');  // Insert $ after 2-letter command
        }
    }

    // Ensure semicolon terminator
    if (!fullCmd.endsWith(';')) {
        fullCmd += ';';
    }

    socket->write(fullCmd.toLatin1());
    socket->flush();
}
```

### IF Command Parser
```cpp
bool parseIFCommand(const QString& response, RadioState& state)
{
    QString data = response.mid(2);  // Remove "IF"
    if (data.startsWith("$")) data = data.mid(1);  // Remove "$" for VFO B

    if (data.length() < 34) return false;

    int pos = 0;

    // Frequency (11 digits)
    state.frequency = data.mid(pos, 11).toLongLong();
    pos += 11;

    // Skip 5 spaces
    pos += 5;

    // RIT/XIT offset (sign + 4 digits)
    int sign = (data[pos] == '-') ? -1 : 1;
    pos++;
    state.ritOffset = data.mid(pos, 4).toInt() * sign;
    pos += 4;

    // RIT/XIT enabled
    state.ritEnabled = (data[pos] == '1');
    pos++;
    state.xitEnabled = (data[pos] == '1');
    pos++;

    // Skip " 00"
    pos += 3;

    // TX/RX, Mode, VFO, Scan, Split, Band, Data mode
    state.transmitting = (data[pos] == '1');
    pos++;
    state.mode = data.mid(pos, 1).toInt();
    pos++;
    state.activeVFO = (data[pos] == '1') ? VFO::VFO_B : VFO::VFO_A;
    pos++;
    state.scanActive = (data[pos] == '1');
    pos++;
    state.splitEnabled = (data[pos] == '1');
    pos++;
    pos++;  // Skip band byte
    state.dataSubmode = data.mid(pos, 1).toInt();

    return true;
}
```

---

## Performance Characteristics

### Latency Comparison
- **K4 Direct:** 5-10ms typical
- **Hamlib (serial):** 50-100ms typical
- **10x improvement** for frequency/mode changes

### Update Model
- **Pull (Polling):** Not required with AI5
- **Push (AI5):** Radio sends updates automatically
- **Efficient:** No unnecessary network traffic

### CW Latency
- **K4 Direct:** 10-20ms
- **Hamlib:** 100-150ms
- **5-10x improvement** for CW keying

---

## References

- **K4 Programmer's Reference:** [https://ftp.elecraft.com/K4/Manuals%20Downloads/K4ProgrammersReferencerev.D5.html](https://ftp.elecraft.com/K4/Manuals%20Downloads/K4ProgrammersReferencerev.D5.html)
- **TR4QT Implementation:** `/Users/toms/projects/TR4QT/src/radio/K4Radio.cpp`
- **K4Inspector Dissector:** This project (Wireshark protocol dissector)

---

## Document Version History

- **1.0** (2026-01-08): Initial release with 50+ commands documented
  - Based on K4 Programmer's Reference Rev. D5
  - Includes TR4QT implementation patterns
  - Validated against K4Inspector Wireshark dissector

---

## Contributing

This document is maintained alongside the K4Inspector Wireshark dissector project. Contributions, corrections, and additions are welcome. Please submit issues or pull requests to the project repository.

---

*This protocol reference was created through analysis of the official K4 Programmer's Reference, the TR4QT open-source logging software implementation, and real-world packet captures analyzed with the K4Inspector Wireshark dissector.*
