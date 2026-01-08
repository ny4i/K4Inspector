# Sample Captures

This directory contains sample packet captures for testing the K4 protocol dissector.

## Usage

1. Place your `.pcap` or `.pcapng` files here
2. Open them in Wireshark with the K4 dissector installed
3. Verify that the K4 protocol is being correctly decoded

## Note

Sample capture files (`.pcap`, `.pcapng`) are excluded from git by default via `.gitignore` to keep the repository size small. If you want to include specific sample files, you can force-add them:

```bash
git add -f samples/your-sample.pcap
```
