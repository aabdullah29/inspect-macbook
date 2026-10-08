#!/bin/bash

# MacBook Pro M2 Used-Purchase Audit
# Read-only information collector.
# It does NOT prove Activation Lock status, physical condition,
# original parts, or absence of hidden/intermittent faults.

# MacBook Used-Purchase Audit
# Read-only automated audit. Manual tests and Apple Diagnostics are still required.
#
# Optional expected values:
#   chmod +x macbook-audit.sh
#   ./macbook-audit.sh
#
# Save while displaying:
#   chmod +x macbook-audit.sh
#   ./macbook-audit.sh | tee "macbook-audit-$(date '+%Y-%m-%d-%H%M%S').txt"

set +e

echo "============================================================"
echo " MacBook Pro M2 Used-Purchase Audit"
echo " $(date)"
echo "============================================================"

echo
echo "=== HARDWARE OVERVIEW ==="
system_profiler SPHardwareDataType

echo
echo "=== SERIAL NUMBER ==="
ioreg -l | awk -F'"' '/IOPlatformSerialNumber/ {print $4; exit}'

echo
echo "=== BATTERY ==="
system_profiler SPPowerDataType

echo
echo "=== STORAGE ==="
diskutil list

echo
echo "=== STARTUP VOLUME ==="
diskutil info /

echo
echo "=== FILESYSTEM CHECK ==="
diskutil verifyVolume /

echo
echo "=== MDM / ENROLLMENT STATUS ==="
profiles status -type enrollment 2>&1

echo
echo "=== MDM / ENROLLMENT DETAILS ==="
sudo profiles show -type enrollment 2>&1

echo
echo "=== CONFIGURATION PROFILES ==="
profiles list 2>&1

echo
echo "=== USB ==="
system_profiler SPUSBDataType

echo
echo "=== THUNDERBOLT / USB4 ==="
system_profiler SPThunderboltDataType 2>&1

echo
echo "=== DISPLAY ==="
system_profiler SPDisplaysDataType

echo
echo "=== AUDIO ==="
system_profiler SPAudioDataType

echo
echo "=== CAMERA ==="
system_profiler SPCameraDataType 2>&1

echo
echo "=== NETWORK ==="
system_profiler SPNetworkDataType 2>&1

echo
echo "=== WI-FI ==="
system_profiler SPAirPortDataType 2>&1

echo
echo "=== BLUETOOTH ==="
system_profiler SPBluetoothDataType 2>&1

echo
echo "=== RECENT KERNEL PANIC LOG CHECK ==="
log show --last 1d --predicate 'eventMessage CONTAINS[c] "panic"' --style compact 2>/dev/null | tail -50

echo
echo "============================================================"
echo " MANUAL CHECKS STILL REQUIRED"
echo " - Activation Lock / Find My"
echo " - Clean erase and activation"
echo " - Remote Management during Setup Assistant"
echo " - Apple serial/model lookup"
echo " - Physical dent, hinge and chassis inspection"
echo " - Display pixel/flicker inspection"
echo " - Keyboard / trackpad / Touch ID / Touch Bar"
echo " - Camera / microphone / speakers"
echo " - Both USB-C ports and charging"
echo " - Apple Diagnostics (Command-D from Startup Options)"
echo "============================================================"
