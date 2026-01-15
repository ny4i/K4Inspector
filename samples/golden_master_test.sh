#!/bin/bash
# Golden master validation test for K4Inspector
# Validates that liveK4.pcapng parses to known-correct values

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GOLDEN_FILE="$SCRIPT_DIR/liveK4.golden"
ACTUAL_FILE="/tmp/k4inspector_actual.txt"

# Fields to validate (order matters for diff)
FIELDS="-e k4direct.command -e k4direct.frequency -e k4direct.mode -e k4direct.band_number -e k4direct.cw_speed -e k4direct.tx_state -e k4direct.rit_enabled -e k4direct.xit_enabled -e k4direct.split_enabled"

generate_output() {
    LC_ALL=C tshark -X lua_script:"$PROJECT_DIR/k4inspector/init.lua" \
           -r "$SCRIPT_DIR/liveK4.pcapng" \
           -Y k4direct \
           -T fields $FIELDS 2>/dev/null | \
    LC_ALL=C tr -d '\r' | \
    grep -v '^$' | \
    cat -n
}

if [ "$1" == "--generate" ]; then
    echo "Generating golden master file..."
    generate_output > "$GOLDEN_FILE"
    lines=$(wc -l < "$GOLDEN_FILE" | tr -d ' ')
    echo "Generated $GOLDEN_FILE with $lines entries"

    # Show sample of what was captured
    echo ""
    echo "Sample entries (first 10):"
    head -10 "$GOLDEN_FILE"
    exit 0
fi

if [ ! -f "$GOLDEN_FILE" ]; then
    echo "ERROR: Golden master file not found: $GOLDEN_FILE"
    echo "Run with --generate first to create it"
    exit 1
fi

echo "Validating liveK4.pcapng against golden master..."

# Generate current output
generate_output > "$ACTUAL_FILE"

# Compare
if diff -q "$GOLDEN_FILE" "$ACTUAL_FILE" > /dev/null 2>&1; then
    lines=$(wc -l < "$GOLDEN_FILE" | tr -d ' ')
    echo "✓ PASS: All $lines parsed values match golden master"
    rm -f "$ACTUAL_FILE"
    exit 0
else
    echo "✗ FAIL: Output differs from golden master"
    echo ""
    echo "Differences (expected vs actual):"
    diff -u "$GOLDEN_FILE" "$ACTUAL_FILE" | head -50
    echo ""
    echo "Full diff saved to: $ACTUAL_FILE"
    exit 1
fi
