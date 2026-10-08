#!/bin/bash
set +e

# MacBook Used-Purchase Audit
# Read-only automated audit. Manual tests and Apple Diagnostics are still required.
#
# Optional expected values:
#   chmod +x macbook-audit-v2.sh
#   EXPECTED_CHIP="M2" EXPECTED_MEMORY_GB=24 EXPECTED_STORAGE_GB=512 ./macbook-audit-v2.sh
#
# Save while displaying:
#   chmod +x macbook-audit-v2.sh
#   ./macbook-audit-v2.sh | tee "macbook-audit-$(date '+%Y-%m-%d-%H%M%S').txt"

EXPECTED_CHIP="${EXPECTED_CHIP:-}"
EXPECTED_MEMORY_GB="${EXPECTED_MEMORY_GB:-}"
EXPECTED_STORAGE_GB="${EXPECTED_STORAGE_GB:-}"

OK=0; CHECK=0; FAIL=0

pass(){ OK=$((OK+1)); printf "%-7s %-25s %s\n" "[OK]" "$1" "$2"; }
warn(){ CHECK=$((CHECK+1)); printf "%-7s %-25s %s\n" "[CHECK]" "$1" "$2"; }
fail(){ FAIL=$((FAIL+1)); printf "%-7s %-25s %s\n" "[FAIL]" "$1" "$2"; }

HW="$(system_profiler SPHardwareDataType 2>/dev/null)"
MODEL="$(echo "$HW" | awk -F': ' '/^[[:space:]]*Model Name:/ {print $2; exit}')"
IDENTIFIER="$(echo "$HW" | awk -F': ' '/^[[:space:]]*Model Identifier:/ {print $2; exit}')"
CHIP="$(echo "$HW" | awk -F': ' '/^[[:space:]]*Chip:/ {print $2; exit}')"
MEMORY="$(echo "$HW" | awk -F': ' '/^[[:space:]]*Memory:/ {print $2; exit}')"
SERIAL="$(echo "$HW" | awk -F': ' '/Serial Number \(system\):/ {print $2; exit}')"
ACTIVATION="$(echo "$HW" | awk -F': ' '/Activation Lock Status:/ {print $2; exit}')"

BAT="$(system_profiler SPPowerDataType 2>/dev/null)"
CYCLES="$(echo "$BAT" | awk -F': ' '/Cycle Count:/ {print $2; exit}')"
CONDITION="$(echo "$BAT" | awk -F': ' '/Condition:/ {print $2; exit}')"
CAPACITY="$(echo "$BAT" | awk -F': ' '/Maximum Capacity:/ {print $2; exit}')"
SOC="$(echo "$BAT" | awk -F': ' '/State of Charge \(%\):/ {print $2; exit}')"
CHARGING="$(echo "$BAT" | awk -F': ' '/^[[:space:]]*Charging:/ {print $2; exit}')"

echo
echo "============================================================"
echo " MacBook Used-Purchase Audit"
echo " $(date)"
echo "============================================================"

echo
echo "=== PURCHASE SUMMARY ==="
echo "Model              : ${MODEL:-Unknown}"
echo "Model Identifier   : ${IDENTIFIER:-Unknown}"
echo "Chip               : ${CHIP:-Unknown}"
echo "Memory             : ${MEMORY:-Unknown}"
echo "Serial             : ${SERIAL:-Unknown}"
echo "Activation Lock    : ${ACTIVATION:-Not reported}"
echo "Battery Cycles     : ${CYCLES:-Unknown}"
echo "Battery Condition  : ${CONDITION:-Unknown}"
echo "Battery Capacity   : ${CAPACITY:-Unknown}"
echo

echo "=== 1. HARDWARE / CONFIGURATION ==="
[ -n "$MODEL" ] && pass "Mac model" "$MODEL" || fail "Mac model" "Could not read model"

if [ -n "$CHIP" ]; then
  if [ -n "$EXPECTED_CHIP" ]; then
    [[ "$CHIP" == *"$EXPECTED_CHIP"* ]] && pass "Chip" "$CHIP (expected)" || fail "Chip" "$CHIP (EXPECTED: $EXPECTED_CHIP)"
  else
    pass "Chip detected" "$CHIP (set EXPECTED_CHIP to compare)"
  fi
else fail "Chip" "Could not read chip"; fi

MEM_GB="$(echo "$MEMORY" | grep -oE '[0-9]+' | head -1)"
if [ -n "$MEM_GB" ]; then
  if [ -n "$EXPECTED_MEMORY_GB" ]; then
    [ "$MEM_GB" -eq "$EXPECTED_MEMORY_GB" ] && pass "Unified memory" "${MEM_GB} GB (expected)" || fail "Unified memory" "${MEM_GB} GB (EXPECTED: ${EXPECTED_MEMORY_GB} GB)"
  else
    pass "Unified memory" "${MEM_GB} GB (set EXPECTED_MEMORY_GB to compare)"
  fi
else fail "Unified memory" "Could not read memory"; fi

[ -n "$SERIAL" ] && pass "Serial number" "$SERIAL" || fail "Serial number" "Could not read serial"

echo
echo "=== 2. BATTERY ==="
echo "Cycle Count        : ${CYCLES:-Unknown}"
echo "Condition          : ${CONDITION:-Unknown}"
echo "Maximum Capacity   : ${CAPACITY:-Unknown}"
echo "Current Charge     : ${SOC:-Unknown}%"
echo "Charging           : ${CHARGING:-Unknown}"

[ "$CONDITION" = "Normal" ] && pass "Battery condition" "Normal" || warn "Battery condition" "${CONDITION:-Unknown} — investigate"

CAP_NUM="$(echo "$CAPACITY" | grep -oE '[0-9]+' | head -1)"
if [ -n "$CAP_NUM" ]; then
  if [ "$CAP_NUM" -ge 90 ]; then pass "Battery capacity" "${CAP_NUM}%"
  elif [ "$CAP_NUM" -ge 80 ]; then warn "Battery capacity" "${CAP_NUM}% — inspect/value accordingly"
  else warn "Battery capacity" "${CAP_NUM}% — significantly reduced"; fi
else warn "Battery capacity" "Could not read"; fi

CYCLE_NUM="$(echo "$CYCLES" | grep -oE '^[0-9]+')"
if [ -n "$CYCLE_NUM" ]; then
  if [ "$CYCLE_NUM" -le 300 ]; then pass "Battery cycles" "$CYCLE_NUM"
  elif [ "$CYCLE_NUM" -le 700 ]; then warn "Battery cycles" "$CYCLE_NUM — inspect condition/capacity"
  else warn "Battery cycles" "$CYCLE_NUM — high usage"; fi
else warn "Battery cycles" "Could not read"; fi

echo
echo "=== 3. INTERNAL STORAGE ==="
DISK_LIST="$(diskutil list 2>/dev/null)"
INTERNAL_DISK="$(echo "$DISK_LIST" | grep -m1 -oE '/dev/disk[0-9]+ \(internal, physical\)' | sed 's/ (internal, physical)//')"
[ -n "$INTERNAL_DISK" ] || INTERNAL_DISK="/dev/disk0"

DISK_INFO="$(diskutil info "$INTERNAL_DISK" 2>/dev/null)"
RAW_SIZE="$(echo "$DISK_INFO" | awk -F': ' '/Disk Size/ {print $2; exit}')"
SMART="$(echo "$DISK_INFO" | awk -F': ' '/SMART Status/ {print $2; exit}')"

echo "Internal disk      : $INTERNAL_DISK"
echo "Disk size          : ${RAW_SIZE:-Unknown}"
echo "SMART status       : ${SMART:-Not reported}"

if [ -n "$EXPECTED_STORAGE_GB" ] && [ -n "$RAW_SIZE" ]; then
  SIZE_GB="$(echo "$RAW_SIZE" | grep -oE '[0-9]+(\.[0-9]+)? GB' | head -1 | awk '{print $1}')"
  if [ -n "$SIZE_GB" ] && awk "BEGIN {exit !($SIZE_GB >= $EXPECTED_STORAGE_GB*0.95)}"; then
    pass "Storage capacity" "$RAW_SIZE (expected class)"
  else
    fail "Storage capacity" "$RAW_SIZE (EXPECTED: ${EXPECTED_STORAGE_GB} GB class)"
  fi
else
  pass "Storage detected" "${RAW_SIZE:-Unknown}"
fi

[ "$SMART" = "Verified" ] && pass "SMART status" "Verified" || warn "SMART status" "${SMART:-Not reported}"

FS_CHECK="$(diskutil verifyVolume / 2>&1)"
if echo "$FS_CHECK" | grep -q "appears to be OK" && echo "$FS_CHECK" | grep -q "exit code is 0"; then
  pass "Filesystem check" "APFS volume appears OK"
else
  warn "Filesystem check" "Review verification output if needed"
fi

echo
echo "=== 4. MDM / ORGANIZATION ENROLLMENT ==="
MDM_STATUS="$(profiles status -type enrollment 2>&1)"
echo "$MDM_STATUS"

if echo "$MDM_STATUS" | grep -qiE "MDM enrollment: No|Enrolled via DEP: No"; then
  pass "MDM enrollment" "No enrollment reported"
elif echo "$MDM_STATUS" | grep -qiE "MDM enrollment: Yes|Enrolled via DEP: Yes"; then
  fail "MDM enrollment" "Enrollment detected — investigate before purchase"
else
  warn "MDM enrollment" "Could not determine automatically"
fi

PROFILE_STATUS="$(profiles list 2>&1)"
if echo "$PROFILE_STATUS" | grep -qi "There are no configuration profiles"; then
  pass "Configuration profiles" "None reported"
elif echo "$PROFILE_STATUS" | grep -qiE "configuration profile|ProfileIdentifier|Payload"; then
  warn "Configuration profiles" "Profiles detected — inspect manually"
else
  warn "Configuration profiles" "Could not determine"
fi

echo
echo "=== 5. DEVICE DETECTION ==="
DISPLAY_INFO="$(system_profiler SPDisplaysDataType 2>/dev/null)"
DISPLAY_RES="$(echo "$DISPLAY_INFO" | awk -F': ' '/Resolution:/ {print $2; exit}')"
[ -n "$DISPLAY_RES" ] && pass "Internal display" "$DISPLAY_RES" || warn "Internal display" "Could not read display"

CAMERA_INFO="$(system_profiler SPCameraDataType 2>/dev/null)"
echo "$CAMERA_INFO" | grep -qi "Camera" && pass "Camera" "Hardware detected" || warn "Camera" "Could not detect"

AUDIO_INFO="$(system_profiler SPAudioDataType 2>/dev/null)"
echo "$AUDIO_INFO" | grep -qiE "Speakers|Microphone" && pass "Audio devices" "Built-in audio detected" || warn "Audio devices" "Could not detect"

echo
echo "=== 6. USB-C / THUNDERBOLT ==="
TB_INFO="$(system_profiler SPThunderboltDataType 2>/dev/null)"
PORT_COUNT="$(echo "$TB_INFO" | grep -c "Receptacle:")"
if [ "$PORT_COUNT" -ge 2 ]; then pass "USB-C/Thunderbolt ports" "$PORT_COUNT port entries detected"
else warn "USB-C/Thunderbolt ports" "$PORT_COUNT entries detected — test every port manually"; fi
echo "IMPORTANT: detection does NOT prove charging/data functionality."

echo
echo "=== 7. NETWORK HARDWARE ==="
WIFI_INFO="$(system_profiler SPAirPortDataType 2>/dev/null)"
BT_INFO="$(system_profiler SPBluetoothDataType 2>/dev/null)"
echo "$WIFI_INFO" | grep -qi "Card Type: Wi-Fi" && pass "Wi-Fi hardware" "Detected" || warn "Wi-Fi hardware" "Could not detect"
echo "$WIFI_INFO" | grep -qi "Status: Connected" && pass "Wi-Fi connection" "Connected" || warn "Wi-Fi connection" "Not connected"
echo "$BT_INFO" | grep -qi "Bluetooth Controller" && pass "Bluetooth hardware" "Detected" || warn "Bluetooth hardware" "Could not detect"

echo
echo "=== 8. RECENT CRASH / KERNEL PANIC REVIEW ==="
PANIC_FILES=0
for DIR in "$HOME/Library/Logs/DiagnosticReports" "/Library/Logs/DiagnosticReports"; do
  if [ -d "$DIR" ]; then
    COUNT="$(find "$DIR" -maxdepth 1 -type f \( -iname "*panic*" -o -iname "*watchdog*" \) -mtime -30 2>/dev/null | wc -l | tr -d ' ')"
    PANIC_FILES=$((PANIC_FILES + COUNT))
  fi
done

if [ "$PANIC_FILES" -eq 0 ]; then
  pass "Recent panic reports" "No panic/watchdog report files found in last 30 days"
else
  warn "Recent panic reports" "$PANIC_FILES panic/watchdog report file(s) found in last 30 days"
  find "$HOME/Library/Logs/DiagnosticReports" "/Library/Logs/DiagnosticReports" -maxdepth 1 -type f \( -iname "*panic*" -o -iname "*watchdog*" \) -mtime -30 -print 2>/dev/null
fi

echo
echo "=== 9. APPLE DIAGNOSTICS ==="
echo "NOT RUN BY THIS SCRIPT."
echo "Apple silicon: shut down -> hold power -> Startup Options -> Command-D."
echo "Record the exact Apple Diagnostics result/code."

echo
echo "=== 10. OWNERSHIP / ACTIVATION ==="
echo "Final ownership test is MANUAL:"
echo "  1. Seller removes Apple Account / Find My."
echo "  2. Erase All Content and Settings."
echo "  3. Connect Wi-Fi in Setup Assistant."
echo "  4. Confirm no previous-owner Activation Lock."
echo "  5. Confirm no unexpected Remote Management."

if [ "$ACTIVATION" = "Disabled" ]; then
  pass "Current Activation Lock" "Disabled"
elif [ "$ACTIVATION" = "Enabled" ]; then
  warn "Current Activation Lock" "Enabled — can be normal for current owner; MUST be removed before purchase"
else
  warn "Current Activation Lock" "Unknown"
fi

echo
echo "=== 11. MANUAL TESTS STILL REQUIRED ==="
echo "[ ] Physical dent/chassis/hinge"
echo "[ ] Display pixels/flicker"
echo "[ ] Keyboard every key"
echo "[ ] Trackpad clicks/gestures"
echo "[ ] Touch ID / Touch Bar"
echo "[ ] Camera / microphone / speakers"
echo "[ ] Headphone jack"
echo "[ ] Wi-Fi stability/internet"
echo "[ ] Bluetooth pairing"
echo "[ ] BOTH USB-C ports: charging + data"
echo "[ ] Charger/cable"
echo "[ ] Short battery discharge test"
echo "[ ] Apple Diagnostics"
echo "[ ] Clean erase + Setup Assistant"
echo "[ ] Activation Lock"
echo "[ ] Remote Management"

echo
echo "============================================================"
echo " AUTOMATED RESULT"
echo "============================================================"
echo "OK       : $OK"
echo "CHECK    : $CHECK"
echo "FAIL     : $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "OVERALL  : FAIL / INVESTIGATE BEFORE PURCHASE"
elif [ "$CHECK" -gt 0 ]; then
  echo "OVERALL  : CHECK ITEMS BEFORE PURCHASE"
else
  echo "OVERALL  : AUTOMATED CHECKS LOOK GOOD"
fi
echo
echo "This is a supporting audit, NOT a complete hardware certification."
echo "Complete manual testing, Apple Diagnostics, and the final erase/activation test before paying."
echo "============================================================"
