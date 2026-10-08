# Native automated audit script

Save the separate script from this repository as:

```text
macbook-audit.sh
```

Then run:

```bash
chmod +x macbook-audit.sh
./macbook-audit.sh
```

For save report in text file run:

```bash
chmod +x macbook-audit.sh
./macbook-audit.sh | tee "macbook-audit-$(date '+%Y-%m-%d-%H%M%S').txt"
```

For Summary run:
Note: change this info with the expected info before run
`EXPECTED_CHIP="M2" EXPECTED_MEMORY_GB=24 EXPECTED_STORAGE_GB=512`

```bash
chmod +x macbook-audit-v2.sh
EXPECTED_CHIP="M2" EXPECTED_MEMORY_GB=24 EXPECTED_STORAGE_GB=512 ./macbook-audit-v2.sh
```

and

```bash
chmod +x macbook-audit-v3.sh
EXPECTED_CHIP="M2" EXPECTED_MEMORY_GB=24 EXPECTED_STORAGE_GB=512 ./macbook-audit-v3.sh
```

For save the summary in text file run:

```bash
chmod +x macbook-audit-v2.sh
EXPECTED_CHIP="M2" EXPECTED_MEMORY_GB=24 EXPECTED_STORAGE_GB=512 \
./macbook-audit-v2.sh | tee "macbook-audit-$(date '+%Y-%m-%d-%H%M%S').txt"
```

and

```bash
chmod +x macbook-audit-v3.sh
EXPECTED_CHIP="M2" EXPECTED_MEMORY_GB=24 EXPECTED_STORAGE_GB=512 \
./macbook-audit-v3.sh | tee "macbook-audit-$(date '+%Y-%m-%d-%H%M%S').txt"
```

## What Does the Audit Script Do?

The audit script is a **quick automated technical audit** for the MacBook. Its purpose is to save you from manually opening many **System Information** and **Terminal** screens.

It does **not replace the manual inspection checklist or Apple Diagnostics**. It should be used as an additional verification tool.

### What the Script Checks

When you run the script, it collects information about:

- **Mac Model & Chip**
  - Apple silicon / M2 information
  - Hardware model information

- **Memory**
  - Installed unified memory
  - Useful for confirming the advertised **24 GB**

- **Storage**
  - Internal disk information
  - Storage capacity
  - APFS/volume information
  - Basic filesystem verification

- **Battery**
  - Battery cycle count
  - Battery condition
  - Maximum capacity
  - Charging/power information

- **Display**
  - Connected display information
  - Resolution and display details

- **USB / Thunderbolt**
  - Connected USB/Thunderbolt hardware
  - Useful when testing USB-C ports with a USB-C device

- **Camera**
  - Camera hardware detection information

- **Audio**
  - Audio device information

- **Network**
  - Wi-Fi/network hardware information

- **Bluetooth**
  - Bluetooth hardware information

- **Device Management / MDM**
  - Enrollment-related information
  - Helps identify possible organization/device management

- **Crash / Kernel Panic History**
  - Recent panic information
  - Useful for identifying possible system instability

### What the Script Does NOT Prove

The script cannot automatically prove that:

- The Mac is 100% genuine
- Every internal component is original
- The display has no dead/stuck pixels
- Every keyboard key works correctly
- The trackpad is mechanically healthy
- The hinge is physically healthy
- The dent has not caused hidden structural damage
- The speakers sound good
- The camera image quality is good
- The battery is physically healthy beyond the information reported by macOS
- Activation Lock has been removed
- The Mac will not become organization-managed during setup
- There are no intermittent hardware problems

These things require **manual inspection and testing**.

### Recommended Inspection Process

Use the tools together:

| Tool | Purpose |
|---|---|
| **Manual Checklist** | Physical and functional inspection |
| **Audit Script** | Automated information collection |
| **Apple Diagnostics** | Apple's built-in hardware diagnostic |
| **Erase + Activation Test** | Ownership, Activation Lock and Remote Management verification |

### Recommended Order

1. Perform the **manual physical inspection**
2. Perform the **functional tests**
3. Run the **audit script**
4. Compare the script results with the information shown by macOS
5. Run **Apple Diagnostics**
6. At the very end, perform:
   - Apple Account / Find My removal
   - Erase All Content and Settings
   - Setup Assistant
   - Activation check
   - Remote Management check
7. **Only pay after all important checks pass**
