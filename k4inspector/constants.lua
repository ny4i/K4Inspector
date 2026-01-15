-- k4inspector/constants.lua
-- This file contains all the constant lookup tables for the K4Direct dissector.

local M = {}

-- Mode value strings
M.mode_names = {
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
M.data_submode_names = {
    [0] = "DATA A (Audio FSK)",
    [1] = "AFSK A",
    [2] = "FSK D (Direct)",
    [3] = "PSK D (Direct)"
}

-- AGC mode names
M.agc_names = {
    [0] = "Off",
    [1] = "Slow",
    [2] = "Medium",
    [3] = "Fast"
}

-- Preamp names
M.preamp_names = {
    [0] = "Off",
    [1] = "10dB",
    [2] = "18-20dB",
    [3] = "Dual (Main 10dB + Sub 18-20dB)"
}

-- ATU status names
M.atu_names = {
    [0] = "Bypass",
    [1] = "Auto",
    [2] = "Tune"
}

-- Band names
M.band_names = {
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
M.baud_rate_names = {
    [0] = "45 baud (FSK)",
    [1] = "75 baud (FSK)",
    [2] = "31 baud (PSK)",
    [3] = "63 baud (PSK)"
}

-- Audio effects names
M.audio_effects_names = {
    [0] = "Off",
    [1] = "Delay (Sim Stereo)",
    [2] = "Pitch-Map"
}

-- Mic input names
M.mic_input_names = {
    [0] = "Front Mic",
    [1] = "Rear Mic",
    [2] = "LINE In",
    [3] = "Front Mic + LINE In",
    [4] = "Rear Mic + LINE In"
}

-- VFO operation names (AB command)
M.vfo_operation_names = {
    [0] = "FA>FB (freq only)",
    [1] = "FB>FA (freq only)",
    [2] = "FA/FB Swap (freq only)",
    [3] = "All A>B",
    [4] = "All B>A",
    [5] = "All A/B Swap"
}

-- ESSB mode names
M.essb_mode_names = {
    [0] = "SSB",
    [1] = "ESSB"
}

-- APF mode names
M.apf_mode_names = {
    [0] = "Off",
    [1] = "On"
}

-- APF bandwidth names
M.apf_bandwidth_names = {
    [0] = "Narrow (30 Hz)",
    [1] = "Wide (50 Hz)",
    [2] = "Wide (150 Hz)"
}

-- VOX Gain mode names
M.vox_gain_mode_names = {
    V = "Voice",
    D = "AF Data"
}

-- Batch 3: Complex structured command lookup tables

-- VOX/QSK Delay mode names (SD command)
M.vox_delay_mode_names = {
    C = "CW/Direct Data",
    V = "Voice",
    D = "AF Data"
}

-- Mic preamp dB values (MS command)
M.front_mic_preamp_db = {[0] = 0, [1] = 10, [2] = 20}
M.rear_mic_preamp_db = {[0] = 0, [1] = 14}

-- Keyer iambic mode (KP command)
M.keyer_iambic_names = {A = "Iambic A", B = "Iambic B"}

-- Paddle orientation (KP command)
M.paddle_orientation_names = {N = "Normal", R = "Reversed"}

-- Line out mode (LO command)
M.line_out_mode_names = {
    [0] = "Independent",
    [1] = "Right uses Left"
}

-- Line in source (LI command)
M.line_in_source_names = {
    [0] = "USB-B (Sound Card)",
    [1] = "LINE IN Jack"
}

-- Batch 4: Alternate format command lookup tables

-- Preamp type names (PA$ command)
M.preamp_type_names = {
    [0] = "Off",
    [1] = "10 dB",
    [2] = "18 dB / 20 dB LNA",
    [3] = "10 dB + 20 dB LNA (12-6m)"
}

-- PL/CTCSS tone frequencies (PL$ command)
M.pl_tone_freqs = {
    [1] = 67.0, [2] = 69.3, [3] = 71.9, [4] = 74.4, [5] = 77.0,
    [6] = 79.7, [7] = 82.5, [8] = 85.4, [9] = 88.5, [10] = 91.5,
    [11] = 94.8, [12] = 97.4, [13] = 100.0, [14] = 103.5, [15] = 107.2,
    [16] = 110.9, [17] = 114.8, [18] = 118.8, [19] = 123.0, [20] = 127.3,
    [21] = 131.8, [22] = 136.5, [23] = 141.3, [24] = 146.2, [25] = 151.4,
    [26] = 156.7, [27] = 159.8, [28] = 162.2, [29] = 165.5, [30] = 167.9,
    [31] = 171.3, [32] = 173.8, [33] = 177.3, [34] = 179.9, [35] = 183.5,
    [36] = 186.2, [37] = 189.9, [38] = 192.8, [39] = 196.6, [40] = 199.5,
    [41] = 203.5, [42] = 206.5, [43] = 210.7, [44] = 218.1, [45] = 225.7,
    [46] = 229.1, [47] = 233.6, [48] = 241.8, [49] = 250.3, [50] = 254.1
}

-- Menu parameter names (ME command)
M.menu_names = {
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

return M
