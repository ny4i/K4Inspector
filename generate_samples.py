#!/usr/bin/env python3
"""
Generate sample PCAP files for K4 Direct protocol testing.
These are synthetic captures showing various K4 commands.
"""

import struct
import time

# PCAP global header
PCAP_GLOBAL_HEADER = struct.pack('<IHHiIII',
    0xa1b2c3d4,  # Magic number
    2,           # Major version
    4,           # Minor version
    0,           # Timezone offset
    0,           # Timestamp accuracy
    65535,       # Snaplen
    1            # Network (Ethernet)
)

def create_ethernet_frame(src_mac, dst_mac, payload):
    """Create Ethernet frame."""
    src = bytes.fromhex(src_mac.replace(':', ''))
    dst = bytes.fromhex(dst_mac.replace(':', ''))
    ethertype = struct.pack('>H', 0x0800)  # IPv4
    return dst + src + ethertype + payload

def create_ipv4_packet(src_ip, dst_ip, payload, protocol=6):
    """Create IPv4 packet."""
    version_ihl = 0x45  # IPv4, 20 byte header
    dscp_ecn = 0
    total_length = 20 + len(payload)
    identification = 0x1234
    flags_fragment = 0x4000  # Don't fragment
    ttl = 64
    checksum = 0  # Will calculate

    src = bytes(map(int, src_ip.split('.')))
    dst = bytes(map(int, dst_ip.split('.')))

    header = struct.pack('>BBHHHBBH4s4s',
        version_ihl, dscp_ecn, total_length, identification,
        flags_fragment, ttl, protocol, checksum, src, dst
    )

    # Calculate checksum
    checksum = calculate_checksum(header)
    header = struct.pack('>BBHHHBBH4s4s',
        version_ihl, dscp_ecn, total_length, identification,
        flags_fragment, ttl, protocol, checksum, src, dst
    )

    return header + payload

def create_tcp_packet(src_port, dst_port, seq, ack, flags, payload):
    """Create TCP packet."""
    data_offset = 5 << 4  # 20 bytes, no options
    window = 65535
    checksum = 0
    urgent = 0

    header = struct.pack('>HHIIBBHHH',
        src_port, dst_port, seq, ack,
        data_offset, flags, window, checksum, urgent
    )

    return header + payload

def calculate_checksum(data):
    """Calculate Internet checksum."""
    if len(data) % 2 == 1:
        data += b'\x00'

    s = sum(struct.unpack('>%dH' % (len(data) // 2), data))
    s = (s >> 16) + (s & 0xffff)
    s += s >> 16
    return ~s & 0xffff

def write_packet(f, timestamp, packet_data):
    """Write a packet to PCAP file."""
    ts_sec = int(timestamp)
    ts_usec = int((timestamp - ts_sec) * 1000000)
    incl_len = len(packet_data)
    orig_len = len(packet_data)

    packet_header = struct.pack('<IIII', ts_sec, ts_usec, incl_len, orig_len)
    f.write(packet_header)
    f.write(packet_data)

def create_k4_packet(src_ip, dst_ip, src_port, dst_port, seq, ack, flags, k4_data):
    """Create complete packet with K4 Direct protocol data."""
    tcp = create_tcp_packet(src_port, dst_port, seq, ack, flags, k4_data.encode('ascii'))
    ip = create_ipv4_packet(src_ip, dst_ip, tcp)
    eth = create_ethernet_frame('60:22:32:6f:95:4f', '64:4b:f0:38:2d:0a', ip)
    return eth

def generate_basic_commands():
    """Generate basic_commands.pcap - Simple command exchanges."""
    print("Generating basic_commands.pcap...")

    with open('samples/basic_commands.pcap', 'wb') as f:
        f.write(PCAP_GLOBAL_HEADER)

        timestamp = time.time()
        seq_client = 1000
        seq_server = 2000
        ack_flags = 0x10  # ACK
        psh_ack_flags = 0x18  # PSH+ACK

        # Client requests frequency
        k4_data = "FA;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.001

        # Server responds with frequency
        k4_data = "FA00014074000;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_server += len(k4_data)
        timestamp += 0.01

        # Client requests mode
        k4_data = "MD;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.001

        # Server responds with mode
        k4_data = "MD3;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_server += len(k4_data)
        timestamp += 0.01

        # Client sets VFO B frequency
        k4_data = "FB$00007200000;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.001

def generate_if_status():
    """Generate if_status.pcap - IF command responses."""
    print("Generating if_status.pcap...")

    with open('samples/if_status.pcap', 'wb') as f:
        f.write(PCAP_GLOBAL_HEADER)

        timestamp = time.time()
        seq_client = 1000
        seq_server = 2000
        psh_ack_flags = 0x18

        # Client requests status
        k4_data = "IF;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.002

        # Server responds with comprehensive status - RX, LSB mode
        k4_data = "IF00014074000     +000000 0001001001 ;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_server += len(k4_data)
        timestamp += 0.5

        # Another IF query
        k4_data = "IF;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.002

        # Server responds - TX active, USB mode, RIT enabled with +150 Hz offset
        k4_data = "IF00014074000     +015010 0102001001 ;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_server += len(k4_data)
        timestamp += 0.5

        # IF with Data mode and sub-mode
        k4_data = "IF;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.002

        k4_data = "IF00021074000     +000000 0006001001 ;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)

def generate_panadapter():
    """Generate panadapter_commands.pcap - # commands."""
    print("Generating panadapter_commands.pcap...")

    with open('samples/panadapter_commands.pcap', 'wb') as f:
        f.write(PCAP_GLOBAL_HEADER)

        timestamp = time.time()
        seq_client = 1000
        seq_server = 2000
        psh_ack_flags = 0x18

        # Set panadapter span
        k4_data = "#SPN$46125;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.01

        # Set reference level
        k4_data = "#REF$-20;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.01

        # Configure auto-ref
        k4_data = "#AR1506+001;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.01

        # Set VFO cursor display
        k4_data = "#VFA2;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.01

        # Waterfall color mode
        k4_data = "#WFC$1;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)

def generate_mixed_session():
    """Generate mixed_session.pcap - Realistic usage session."""
    print("Generating mixed_session.pcap...")

    with open('samples/mixed_session.pcap', 'wb') as f:
        f.write(PCAP_GLOBAL_HEADER)

        timestamp = time.time()
        seq_client = 1000
        seq_server = 2000
        psh_ack_flags = 0x18

        # Initial status query
        k4_data = "IF;OM;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.002

        # Server responds with IF and OM
        k4_data = "IF00014074000     +000000 0001001001 ;OM AP-S----4--;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_server += len(k4_data)
        timestamp += 0.1

        # Change frequency and mode
        k4_data = "FA00007074000;MD2;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.01

        # Enable RIT with offset
        k4_data = "RT$1;RO$+00150;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.01

        # Adjust gains
        k4_data = "AG050;RG200;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.01

        # Go to transmit
        k4_data = "TX;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.5

        # Status check while transmitting
        k4_data = "IF;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.002

        k4_data = "IF00007074000     +015010 0102001001 ;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_server += len(k4_data)
        timestamp += 0.1

        # Return to receive
        k4_data = "RX;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)

def generate_om_hardware():
    """Generate om_hardware.pcap - Various OM configurations."""
    print("Generating om_hardware.pcap...")

    with open('samples/om_hardware.pcap', 'wb') as f:
        f.write(PCAP_GLOBAL_HEADER)

        timestamp = time.time()
        seq_client = 1000
        seq_server = 2000
        psh_ack_flags = 0x18

        # Request OM
        k4_data = "OM;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.002

        # K4 with ATU, PA, SUB RX (no HDR)
        k4_data = "OM AP-S----4--;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_server += len(k4_data)
        timestamp += 0.5

        # K4D (high-performance DDC version)
        k4_data = "OM;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.002

        k4_data = "OM AP-SH---4D-;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_server += len(k4_data)
        timestamp += 0.5

        # K4HD (high-performance with HDR module)
        k4_data = "OM;"
        pkt = create_k4_packet('192.168.1.52', '192.168.73.108', 54000, 9200,
                               seq_client, seq_server, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)
        seq_client += len(k4_data)
        timestamp += 0.002

        k4_data = "OM AP-SH---4DH;"
        pkt = create_k4_packet('192.168.73.108', '192.168.1.52', 9200, 54000,
                               seq_server, seq_client, psh_ack_flags, k4_data)
        write_packet(f, timestamp, pkt)

if __name__ == '__main__':
    import os

    # Create samples directory if it doesn't exist
    os.makedirs('samples', exist_ok=True)

    print("Generating K4 Direct protocol sample PCAP files...")
    print()

    generate_basic_commands()
    generate_if_status()
    generate_panadapter()
    generate_mixed_session()
    generate_om_hardware()

    print()
    print("Sample PCAP files generated successfully!")
    print("Files are in the samples/ directory")
