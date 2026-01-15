#!/bin/bash
# Automated test runner for K4Inspector dissector
# Validates that all sample captures parse without Lua errors

set -e

SAMPLES_DIR="samples"
PASS=0
FAIL=0
ERRORS=""

echo "=========================================="
echo "K4Inspector Dissector Automated Tests"
echo "=========================================="
echo ""

# Check if tshark is available
if ! command -v tshark &> /dev/null; then
    echo "ERROR: tshark not found. Please install Wireshark."
    echo ""
    echo "Installation:"
    echo "  macOS:   brew install --cask wireshark"
    echo "  Ubuntu:  sudo apt-get install tshark"
    echo "  Windows: Download from https://www.wireshark.org/"
    exit 1
fi



if [ ! -f "k4inspector/init.lua" ]; then
    echo "ERROR: k4inspector/init.lua not found."
    exit 1
fi
echo ""

# Test each PCAP file
for pcap in "$SAMPLES_DIR"/*.pcap "$SAMPLES_DIR"/*.pcapng; do
    if [ ! -f "$pcap" ]; then
        continue
    fi

    filename=$(basename "$pcap")
    printf "  %-30s " "$filename"

    # Run tshark and capture output
    output=$(tshark -X lua_script:k4inspector/init.lua -r "$pcap" -Y k4direct -T fields -e k4direct.command 2>&1)
    exit_code=$?

    # Check for Lua errors
    if echo "$output" | grep -qi "lua error"; then
        echo "✗ FAIL - Lua error detected"
        FAIL=$((FAIL+1))
        ERRORS="${ERRORS}\n  ${filename}: Lua error in dissector"
    elif [ $exit_code -ne 0 ]; then
        echo "✗ FAIL - tshark error (exit code $exit_code)"
        FAIL=$((FAIL+1))
        ERRORS="${ERRORS}\n  ${filename}: tshark returned error code $exit_code"
    elif [ -z "$output" ]; then
        echo "⚠ WARN - No K4 commands found"
        # Still count as pass since it might be a different capture
        PASS=$((PASS+1))
    else
        # Count number of commands parsed
        cmd_count=$(echo "$output" | wc -l | tr -d ' ')
        echo "✓ PASS ($cmd_count commands parsed)"
        PASS=$((PASS+1))
    fi
done

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "Errors:"
    echo -e "$ERRORS"
fi

echo ""

# Run golden master validation test
echo "=========================================="
echo "Golden Master Validation"
echo "=========================================="
echo ""

if [ -f "samples/golden_master_test.sh" ]; then
    if samples/golden_master_test.sh; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
    fi
else
    echo "⚠ SKIP - Golden master test not found"
fi

echo ""
echo "=========================================="
echo "Final Results"
echo "=========================================="
echo "  Smoke tests passed: $((PASS-1))"
echo "  Golden master: $([ -f samples/golden_master_test.sh ] && echo "1" || echo "0")"
echo "  Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
