#!/bin/bash
# MacBook Used-Purchase Audit (interactive) — Apple silicon + Intel
#
# One command, answers a few questions, then audits the Mac.
#   bash macbook-audit-interactive.sh
# or paste it into Terminal. Read-only except an optional report file and a test sound.
# Manual tests and Apple Diagnostics are still required.

set +e

# ---------- input (works when pasted or piped: always read from the terminal) ----------
if { exec 3</dev/tty; } 2>/dev/null; then :; else exec 3<&0; fi

ask() {            # ask "Question" "default" -> sets REPLY_VAL
  local q="$1" def="$2" a
  if [ -n "$def" ]; then printf "%s [%s]: " "$q" "$def" >&2; else printf "%s: " "$q" >&2; fi
  IFS= read -r a <&3
  a="$(echo "$a" | sed 's/^ *//;s/ *$//')"
  REPLY_VAL="${a:-$def}"
}

choose() {         # choose "Question" default_index opt1 opt2 ... -> sets REPLY_VAL
  local q="$1" def="$2" i=1 a; shift 2
  echo >&2; echo "$q" >&2
  for o in "$@"; do printf "  %d) %s\n" "$i" "$o" >&2; i=$((i+1)); done
  printf "Choose 1-%d [%s]: " "$#" "$def" >&2
  IFS= read -r a <&3; a="${a:-$def}"
  case "$a" in ''|*[!0-9]*) a="$def";; esac
  [ "$a" -ge 1 ] 2>/dev/null && [ "$a" -le "$#" ] || a="$def"
  eval "REPLY_VAL=\${$a}"
}

yn() {             # yn "Question" -> returns 0 for yes
  local a; printf "%s [y/N]: " "$1" >&2; IFS= read -r a <&3
  case "$a" in y|Y|yes|YES) return 0;; *) return 1;; esac
}

num() { echo "$1" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1; }

OK=0; CHECK=0; FAIL=0
pass(){ OK=$((OK+1));       printf "%-8s %-26s %s\n" "[OK]"    "$1" "$2"; }
warn(){ CHECK=$((CHECK+1)); printf "%-8s %-26s %s\n" "[CHECK]" "$1" "$2"; }
fail(){ FAIL=$((FAIL+1));   printf "%-8s %-26s %s\n" "[FAIL]" "$1" "$2"; }
info(){                     printf "%-8s %-26s %s\n" "[INFO]"  "$1" "$2"; }

# ---------- detect machine ----------
HW="$(system_profiler SPHardwareDataType 2>/dev/null)"
hw(){ echo "$HW" | awk -F': ' -v k="$1" '$0 ~ "^[[:space:]]*"k":" {print $2; exit}'; }
MODEL="$(hw 'Model Name')"; IDENT="$(hw 'Model Identifier')"
CHIP="$(hw 'Chip')"; [ -n "$CHIP" ] || CHIP="$(hw 'Processor Name')"
MEMORY="$(hw 'Memory')"
SERIAL="$(echo "$HW" | awk -F': ' '/Serial Number \(system\)/ {print $2; exit}')"
ACTIVATION="$(echo "$HW" | awk -F': ' '/Activation Lock Status/ {print $2; exit}')"
MODEL_NO="$(hw 'Model Number')"; [ -n "$MODEL_NO" ] || MODEL_NO="$(hw 'Part Number')"
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = "1" ]; then DET_ARCH="Apple silicon"; else DET_ARCH="Intel"; fi

echo >&2
echo "================ MacBook Audit — setup ================" >&2
echo "Answer what the SELLER ADVERTISED. Press Enter to accept [default]." >&2
echo "Detected here: ${MODEL:-?} | ${CHIP:-?} | ${MEMORY:-?} | $DET_ARCH" >&2

if [ "$DET_ARCH" = "Apple silicon" ]; then d=1; else d=2; fi
choose "Processor type advertised?" "$d" "Apple silicon (M1/M2/M3/M4...)" "Intel"
case "$REPLY_VAL" in Apple*) EXP_ARCH="Apple silicon";; *) EXP_ARCH="Intel";; esac

choose "Model line?" 2 "MacBook Air" "MacBook Pro" "Other"
EXP_LINE="$REPLY_VAL"

if [ "$EXP_ARCH" = "Apple silicon" ]; then
  ask "Chip (e.g. M2, M3 Pro, M1 Max)" "$(echo "$CHIP" | sed 's/Apple //')"
else
  ask "CPU (e.g. i5, i7, i9, Core i7)" "$(echo "$CHIP" | grep -oE 'i[3579]' | head -1)"
fi
EXP_CHIP="$REPLY_VAL"

ask "Screen size in inches (13/14/15/16, blank = skip)" ""; EXP_SCREEN="$REPLY_VAL"
ask "RAM in GB (e.g. 8, 16, 24)" "$(num "$MEMORY")";        EXP_RAM="$REPLY_VAL"
ask "Storage in GB (e.g. 256, 512, 1000)" "";               EXP_STORAGE="$REPLY_VAL"
ask "Expected model year (blank = skip)" "";                EXP_YEAR="$REPLY_VAL"
ask "Number of USB-C/Thunderbolt ports" "2";               EXP_PORTS="$REPLY_VAL"
ask "Minimum acceptable battery health %" "85";             MIN_HEALTH="$REPLY_VAL"
ask "Maximum acceptable battery cycles" "500";              MAX_CYCLES="$REPLY_VAL"
ask "Seller's name / listing (for the report, optional)" ""; SELLER="$REPLY_VAL"

OPEN_APPLE=0; yn "Open Apple Check Coverage in the browser at the end?" && OPEN_APPLE=1
RUN_MANUAL=0; yn "Walk through the interactive manual checklist (y/n questions)?" && RUN_MANUAL=1
SAVE=0;       yn "Save the report to ~/Desktop?" && SAVE=1

if [ "$SAVE" = 1 ]; then
  REPORT="$HOME/Desktop/macbook-audit-$(date '+%Y-%m-%d-%H%M%S').txt"
  exec > >(tee "$REPORT")
fi

echo
echo "============================================================"
echo " MacBook Used-Purchase Audit        $(date)"
[ -n "$SELLER" ] && echo " Seller/listing: $SELLER"
echo "============================================================"
echo "Expected: $EXP_ARCH | $EXP_LINE ${EXP_SCREEN:+${EXP_SCREEN}\"} | chip ${EXP_CHIP:-any} | RAM ${EXP_RAM:-any} GB | storage ${EXP_STORAGE:-any} GB | year ${EXP_YEAR:-any} | ports ${EXP_PORTS}"

echo
echo "=== IDENTITY ==="
info "Model"        "${MODEL:-Unknown}"
info "Identifier"   "${IDENT:-Unknown}"
info "Serial"       "${SERIAL:-Unknown}"
info "Model/Part no." "${MODEL_NO:-Not reported by macOS}"
info "Processor"    "${CHIP:-Unknown}"

echo
echo "=== 1. CONFIGURATION vs ADVERTISED ==="
[ -n "$MODEL" ] && pass "Mac model" "$MODEL" || fail "Mac model" "Could not read"

if [ "$DET_ARCH" = "$EXP_ARCH" ]; then pass "Processor type" "$DET_ARCH"
else fail "Processor type" "Detected $DET_ARCH, advertised $EXP_ARCH"; fi

case "$EXP_LINE" in
  "MacBook Air") echo "$MODEL" | grep -qi "MacBook Air" && pass "Model line" "$MODEL" || fail "Model line" "Detected '$MODEL', advertised MacBook Air";;
  "MacBook Pro") echo "$MODEL" | grep -qi "MacBook Pro" && pass "Model line" "$MODEL" || fail "Model line" "Detected '$MODEL', advertised MacBook Pro";;
esac

if [ -n "$EXP_CHIP" ]; then
  # normalise: compare case-insensitively with spaces removed
  a="$(echo "$CHIP" | tr 'A-Z' 'a-z' | tr -d ' ')"; b="$(echo "$EXP_CHIP" | tr 'A-Z' 'a-z' | tr -d ' ')"
  case "$a" in *"$b"*) pass "Chip / CPU" "$CHIP";; *) fail "Chip / CPU" "$CHIP (advertised: $EXP_CHIP)";; esac
  # "M2" must not silently accept "M2 Pro"
  if [ "$EXP_ARCH" = "Apple silicon" ]; then
    case "$b" in *pro|*max|*ultra) :;; *) echo "$a" | grep -qE "(pro|max|ultra)$" && fail "Chip tier" "$CHIP is a higher/different tier than '$EXP_CHIP'";; esac
  fi
else info "Chip / CPU" "$CHIP (nothing to compare)"; fi

MEM_GB="$(num "$MEMORY")"
if [ -n "$EXP_RAM" ] && [ -n "$MEM_GB" ]; then
  [ "$MEM_GB" = "$(num "$EXP_RAM")" ] && pass "Memory" "${MEM_GB} GB" || fail "Memory" "${MEM_GB} GB (advertised $EXP_RAM GB)"
else info "Memory" "${MEMORY:-Unknown}"; fi

if [ -n "$EXP_SCREEN" ]; then
  DP="$(system_profiler SPDisplaysDataType 2>/dev/null)"
  echo "$DP $MODEL" | grep -q "${EXP_SCREEN}" && pass "Screen size" "${EXP_SCREEN}-inch (matches model/display text)" \
    || warn "Screen size" "Could not confirm ${EXP_SCREEN}\" from macOS — check Apple coverage lookup"
fi
if [ -n "$EXP_YEAR" ]; then
  info "Model year" "macOS doesn't report it; Apple Check Coverage / About This Mac shows it — expected $EXP_YEAR"
fi
[ -n "$SERIAL" ] && pass "Serial number" "$SERIAL (compare with bottom case + box)" || fail "Serial number" "Could not read"

echo
echo "=== 2. OPERATING SYSTEM ==="
OSV="$(sw_vers -productVersion 2>/dev/null)"; OSB="$(sw_vers -buildVersion 2>/dev/null)"
info "macOS" "${OSV:-?} ($OSB)"
OSM="$(echo "$OSV" | cut -d. -f1)"
if [ -n "$OSM" ] && [ "$OSM" -ge 26 ] 2>/dev/null; then
  pass "Parts & Service" "macOS 26+: open Settings > General > About > Parts & Service (Genuine/Used OK; Unknown = CHECK)"
else
  warn "Parts & Service" "macOS older than 26 — can't check parts history; update if practical"
fi
if [ "$DET_ARCH" = "Intel" ]; then
  echo "$HW" | grep -qi "T2\|Secure Enclave" || ioreg -l 2>/dev/null | grep -qi "Apple T2" \
    && info "T2 chip" "Present (2018+ Intel; Activation Lock applies)" || info "T2 chip" "Not detected (pre-2018 Intel: check firmware password manually)"
fi

echo
echo "=== 3. BATTERY ==="
BAT="$(system_profiler SPPowerDataType 2>/dev/null)"
CYCLES="$(num "$(echo "$BAT" | awk -F': ' '/Cycle Count/ {print $2; exit}')")"
COND="$(echo "$BAT" | awk -F': ' '/Condition:/ {print $2; exit}')"
CAPPCT="$(num "$(echo "$BAT" | awk -F': ' '/Maximum Capacity/ {print $2; exit}')")"
WATT="$(echo "$BAT" | awk -F': ' '/Wattage/ {print $2; exit}')"
RAW="$(ioreg -rn AppleSmartBattery 2>/dev/null)"
DESIGN="$(echo "$RAW" | awk -F'= ' '/"DesignCapacity"/ {print $2; exit}')"
RAWMAX="$(echo "$RAW" | awk -F'= ' '/"AppleRawMaxCapacity"/ {print $2; exit}')"
[ -n "$RAWMAX" ] || RAWMAX="$(echo "$RAW" | awk -F'= ' '/"MaxCapacity"/ {print $2; exit}')"
HEALTH="$CAPPCT"
if [ -z "$HEALTH" ] && [ -n "$DESIGN" ] && [ -n "$RAWMAX" ] && [ "$DESIGN" -gt 100 ] 2>/dev/null; then
  HEALTH="$(awk "BEGIN{printf \"%d\", $RAWMAX*100/$DESIGN}")"
fi
if [ -z "$CYCLES" ] && [ -z "$RAW" ]; then warn "Battery" "No battery data (desktop Mac, or battery not detected)"; else
  info "Condition" "${COND:-Unknown}"
  info "Cycles / health" "${CYCLES:-?} cycles, ${HEALTH:-?}% health  (design ${DESIGN:-?} mAh, now ${RAWMAX:-?} mAh)"
  case "$COND" in Normal) pass "Battery condition" "Normal";; "") warn "Battery condition" "Not reported";; *) fail "Battery condition" "$COND";; esac
  if [ -n "$HEALTH" ]; then
    [ "$HEALTH" -ge "$MIN_HEALTH" ] 2>/dev/null && pass "Battery health" "${HEALTH}% (min ${MIN_HEALTH}%)" || warn "Battery health" "${HEALTH}% is below your ${MIN_HEALTH}% minimum — negotiate or walk"
  else warn "Battery health" "Could not compute"; fi
  if [ -n "$CYCLES" ]; then
    [ "$CYCLES" -le "$MAX_CYCLES" ] 2>/dev/null && pass "Battery cycles" "$CYCLES (max $MAX_CYCLES)" || warn "Battery cycles" "$CYCLES exceeds your max of $MAX_CYCLES"
  fi
fi
[ -n "$WATT" ] && info "Charger connected" "${WATT}" || info "Charger connected" "None detected (plug in the charger and re-run to see wattage)"

echo
echo "=== 4. STORAGE ==="
DISK="$(diskutil list 2>/dev/null | grep -m1 -oE '/dev/disk[0-9]+ \(internal, physical\)' | sed 's/ (internal, physical)//')"
[ -n "$DISK" ] || DISK="/dev/disk0"
DI="$(diskutil info "$DISK" 2>/dev/null)"
RAWSZ="$(echo "$DI" | awk -F': ' '/Disk Size/ {print $2; exit}')"
SMART="$(echo "$DI" | awk -F': ' '/SMART Status/ {print $2; exit}' | xargs)"
SZ="$(echo "$RAWSZ" | grep -oE '[0-9]+(\.[0-9]+)? (GB|TB)' | head -1)"
SZ_GB="$(echo "$SZ" | awk '{ if ($2=="TB") print $1*1000; else print $1 }')"
info "Internal disk" "$DISK — ${RAWSZ:-Unknown}"
if [ -n "$EXP_STORAGE" ] && [ -n "$SZ_GB" ]; then
  EXP_S="$(num "$EXP_STORAGE")"; [ "$EXP_S" -le 4 ] 2>/dev/null && EXP_S=$((EXP_S*1000))
  if awk "BEGIN{exit !($SZ_GB >= $EXP_S*0.93 && $SZ_GB <= $EXP_S*1.1)}"; then pass "Storage capacity" "$SZ (advertised ${EXP_S} GB class)"
  else fail "Storage capacity" "$SZ (advertised ${EXP_S} GB)"; fi
fi
case "$SMART" in
  Verified) pass "SMART status" "Verified";;
  "")       if [ "$DET_ARCH" = "Apple silicon" ]; then info "SMART status" "Not reported (normal on Apple silicon — use Apple Diagnostics)"; else warn "SMART status" "Not reported"; fi;;
  *)        fail "SMART status" "$SMART";;
esac
FS="$(diskutil verifyVolume / 2>&1)"
echo "$FS" | grep -qiE "appears to be OK|exit code is 0" && pass "Filesystem check" "APFS volume appears OK" || warn "Filesystem check" "Review verifyVolume output"

echo
echo "=== 5. MDM / MANAGEMENT ==="
ME="$(profiles status -type enrollment 2>&1)"
echo "$ME" | sed 's/^/    /'
DEP="$(echo "$ME" | awk -F': ' '/Enrolled via DEP/ {print $2; exit}' | xargs)"
MDM="$(echo "$ME" | awk -F': ' '/MDM enrollment/ {print $2; exit}' | xargs)"
if [ "$DEP" = "Yes" ] || [ "$MDM" = "Yes" ] || echo "$MDM" | grep -qi "user approved"; then
  fail "MDM enrollment" "DEP=${DEP:-?} MDM=${MDM:-?} — managed by an organisation, walk away unless released"
elif [ "$DEP" = "No" ] && [ "$MDM" = "No" ]; then pass "MDM enrollment" "DEP=No, MDM=No"
else warn "MDM enrollment" "Could not determine (DEP='${DEP}', MDM='${MDM}')"; fi
PL="$(profiles list 2>&1)"
echo "$PL" | grep -qi "no configuration profiles" && pass "Config profiles" "None" || warn "Config profiles" "Profiles present or unreadable — inspect in System Settings > Privacy & Security > Profiles"

echo
echo "=== 6. DEVICE DETECTION ==="
DP="$(system_profiler SPDisplaysDataType 2>/dev/null)"
RES="$(echo "$DP" | awk -F': ' '/Resolution:/ {print $2; exit}')"
[ -n "$RES" ] && pass "Internal display" "$RES" || warn "Internal display" "Not read"
system_profiler SPCameraDataType 2>/dev/null | grep -qi camera && pass "Camera" "Detected" || warn "Camera" "Not detected"
system_profiler SPAudioDataType 2>/dev/null | grep -qiE "speaker|microphone" && pass "Audio" "Detected" || warn "Audio" "Not detected"
system_profiler SPBluetoothDataType 2>/dev/null | grep -qiE "Bluetooth Controller|Address:" && pass "Bluetooth" "Detected" || warn "Bluetooth" "Not detected"
WF="$(system_profiler SPAirPortDataType 2>/dev/null)"
echo "$WF" | grep -qiE "Card Type|Wi-Fi" && pass "Wi-Fi hardware" "Detected" || warn "Wi-Fi hardware" "Not detected"
TB="$(system_profiler SPThunderboltDataType 2>/dev/null)"
PC="$(echo "$TB" | grep -c "Receptacle")"; [ "$PC" -gt 0 ] || PC="$(echo "$TB" | grep -c "Port:")"
if [ "$PC" -ge "$EXP_PORTS" ] 2>/dev/null; then pass "USB-C ports" "$PC entries (expected $EXP_PORTS) — still test each for charge + data"
else warn "USB-C ports" "$PC entries, expected $EXP_PORTS — test every port"; fi

echo
echo "=== 7. CRASH / PANIC HISTORY (30 days) ==="
PF="$(find "$HOME/Library/Logs/DiagnosticReports" /Library/Logs/DiagnosticReports -maxdepth 1 -type f \( -iname "*panic*" -o -iname "*watchdog*" -o -iname "Kernel*" \) -mtime -30 2>/dev/null)"
if [ -z "$PF" ]; then pass "Panic reports" "None in last 30 days"; else warn "Panic reports" "$(echo "$PF" | wc -l | tr -d ' ') file(s)"; echo "$PF" | sed 's/^/    /'; fi

echo
echo "=== 8. OWNERSHIP ==="
case "$ACTIVATION" in
  Disabled) pass "Activation Lock" "Disabled";;
  Enabled)  warn "Activation Lock" "Enabled — seller must sign out of Apple Account / Find My before you pay";;
  *)        warn "Activation Lock" "Not reported — do the erase + Setup Assistant test";;
esac

# ---------- interactive manual checklist ----------
MAN_Y=0; MAN_N=0; MAN_S=0
mt() {  # mt "Test description"
  local a; printf "  %s [y=ok / n=problem / Enter=skip]: " "$1" >&2; IFS= read -r a <&3
  case "$a" in y|Y) MAN_Y=$((MAN_Y+1)); pass "Manual" "$1";; n|N) MAN_N=$((MAN_N+1)); fail "Manual" "$1";; *) MAN_S=$((MAN_S+1)); warn "Manual" "$1 — skipped";; esac
}
if [ "$RUN_MANUAL" = 1 ]; then
  echo
  echo "=== 9. MANUAL CHECKLIST ==="
  echo "Playing a test sound..." >&2
  afplay /System/Library/Sounds/Ping.aiff 2>/dev/null
  mt "Heard the sound from BOTH speakers (left/right)"
  mt "No dents, cracks, gaps or bulging in chassis / lid / bottom case"
  mt "Hinge smooth, lid holds position, screen alignment even"
  mt "Display: no dead/stuck pixels, flicker, burn-in, or lines (test white/black/R/G/B)"
  mt "Every keyboard key registers"
  mt "Trackpad click + gestures work across the whole surface"
  [ "$EXP_LINE" = "MacBook Pro" ] && mt "Touch ID / Touch Bar work (if fitted)"
  mt "Camera image works (Photo Booth) and microphone records"
  mt "Wi-Fi connects and loads a website"
  mt "Bluetooth pairs with a device"
  mt "Headphone jack works (if fitted)"
  i=1; while [ "$i" -le "$EXP_PORTS" ]; do mt "USB-C port $i charges the Mac AND detects a USB device"; i=$((i+1)); done
  mt "Charger and cable are original, not frayed/hot"
  mt "No abnormal fan noise, heat or slowdown in 5 min of normal use"
  mt "Apple Diagnostics (Command-D / power button hold) reported 'No issues found'"
  mt "Serial on bottom case / box matches the serial above"
  mt "After seller erases: Setup Assistant shows NO Activation Lock and NO Remote Management"
fi

echo
echo "============================================================"
echo " RESULT"
echo "============================================================"
echo "OK $OK | CHECK $CHECK | FAIL $FAIL"
if [ "$FAIL" -gt 0 ]; then echo "OVERALL: FAIL — investigate before paying"
elif [ "$CHECK" -gt 0 ]; then echo "OVERALL: CHECK items before paying"
else echo "OVERALL: automated checks look good"; fi
[ "$RUN_MANUAL" = 1 ] || echo "Manual checklist NOT run — physical, display, keyboard, ports, Diagnostics and the erase/activation test are still required."
echo "This is a supporting audit, not a hardware certification. Never pay before the erase + activation test passes."
[ -n "$REPORT" ] && echo "Report saved: $REPORT"

if [ "$OPEN_APPLE" = 1 ] && [ -n "$SERIAL" ]; then
  printf "%s" "$SERIAL" | pbcopy 2>/dev/null
  echo "Serial copied to clipboard; opening Apple Check Coverage (verify model/serial there)."
  open "https://checkcoverage.apple.com/" 2>/dev/null
fi
