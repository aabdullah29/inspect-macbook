# Windows Laptop Used-Purchase Audit (interactive)
#
# Run in PowerShell (no admin needed; admin unlocks a few extra checks):
#   powershell -ExecutionPolicy Bypass -File .\laptop-audit.ps1
# or paste the whole script into a PowerShell window.
#
# Read-only except an optional report file, a test beep/voice and an optional browser tab.
# Manual tests and the final reset / sign-in test are still required.

$ErrorActionPreference = 'SilentlyContinue'

$script:Ok = 0; $script:Check = 0; $script:Fail = 0
function Pass($n, $m)  { $script:Ok++;    Write-Host ("{0,-8} {1,-26} {2}" -f '[OK]',    $n, $m) -ForegroundColor Green }
function Warn($n, $m)  { $script:Check++; Write-Host ("{0,-8} {1,-26} {2}" -f '[CHECK]', $n, $m) -ForegroundColor Yellow }
function Bad($n, $m)   { $script:Fail++;  Write-Host ("{0,-8} {1,-26} {2}" -f '[FAIL]',  $n, $m) -ForegroundColor Red }
function Info($n, $m)  {                  Write-Host ("{0,-8} {1,-26} {2}" -f '[INFO]',  $n, $m) -ForegroundColor Cyan }
function Section($t)   { Write-Host ''; Write-Host "=== $t ===" -ForegroundColor White }

function Ask($q, $def) {
    if ($def) { $a = Read-Host "$q [$def]" } else { $a = Read-Host $q }
    if ([string]::IsNullOrWhiteSpace($a)) { return $def }
    return $a.Trim()
}
function YesNo($q) { $a = Read-Host "$q [y/N]"; return ($a -match '^(y|yes)$') }
function Num($s) { if ("$s" -match '(\d+(\.\d+)?)') { return [double]$Matches[1] } return $null }

# ---------- detect ----------
$cs    = Get-CimInstance Win32_ComputerSystem
$csp   = Get-CimInstance Win32_ComputerSystemProduct
$bios  = Get-CimInstance Win32_BIOS
$cpu   = Get-CimInstance Win32_Processor | Select-Object -First 1
$os    = Get-CimInstance Win32_OperatingSystem
$ramBytes = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum
if (-not $ramBytes) { $ramBytes = $cs.TotalPhysicalMemory }
$ramGB = [math]::Round($ramBytes / 1GB)
$serial = $bios.SerialNumber
$isLaptop = $false
if ($cs.PCSystemType -eq 2 -or (Get-CimInstance Win32_Battery)) { $isLaptop = $true }

Write-Host ''
Write-Host '================ Windows Laptop Audit - setup ================'
Write-Host 'Answer what the SELLER ADVERTISED. Press Enter to accept [default].'
Write-Host ("Detected here: {0} {1} | {2} | {3} GB RAM" -f $cs.Manufacturer, $cs.Model, $cpu.Name.Trim(), $ramGB)

$expBrand   = Ask 'Brand (e.g. Dell, HP, Lenovo, ASUS, Acer, MSI)' $cs.Manufacturer
$expModel   = Ask 'Model / series (blank = skip)' ''
$expCpu     = Ask 'CPU (e.g. i5-1135G7, i7, Ryzen 7 5800H, blank = skip)' ''
$expRam     = Ask 'RAM in GB' "$ramGB"
$expStorage = Ask 'Storage in GB (e.g. 256, 512, 1000, blank = skip)' ''
$expScreen  = Ask 'Screen size in inches (blank = skip)' ''
$expGpu     = Ask 'Dedicated GPU advertised? (e.g. RTX 3050, none, blank = skip)' ''
$minHealth  = [double](Ask 'Minimum acceptable battery health %' '80')
$maxCycles  = [double](Ask 'Maximum acceptable battery cycles' '500')
$expYear    = Ask 'Expected year of manufacture (blank = skip)' ''
$seller     = Ask "Seller's name / listing (for the report, optional)" ''
$openWarranty = YesNo 'Open the manufacturer warranty page at the end?'
$runManual    = YesNo 'Walk through the interactive manual checklist (y/n questions)?'
$save         = YesNo 'Save the report to your Desktop?'

$report = $null
if ($save) {
    $report = Join-Path ([Environment]::GetFolderPath('Desktop')) ("laptop-audit-{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))
    Start-Transcript -Path $report | Out-Null
}

Write-Host ''
Write-Host '============================================================'
Write-Host (" Windows Laptop Used-Purchase Audit    {0}" -f (Get-Date))
if ($seller) { Write-Host " Seller/listing: $seller" }
Write-Host '============================================================'
Write-Host ("Expected: {0} {1} | CPU {2} | RAM {3} GB | storage {4} GB | screen {5} | GPU {6} | year {7}" -f $expBrand, $expModel, $expCpu, $expRam, $expStorage, $expScreen, $expGpu, $expYear)

# ---------- identity ----------
Section 'IDENTITY'
Info 'Manufacturer' $cs.Manufacturer
Info 'Model'        $cs.Model
Info 'Product name' $csp.Name
Info 'Serial'       $serial
Info 'UUID'         $csp.UUID
Info 'BIOS'         ("{0} {1} ({2})" -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion, $bios.ReleaseDate)
Info 'Form factor'  $(if ($isLaptop) { 'Laptop (battery / mobile chassis found)' } else { 'Not detected as a laptop' })

# ---------- config ----------
Section '1. CONFIGURATION vs ADVERTISED'
if (-not $isLaptop) { Warn 'Laptop detected' 'No battery / mobile chassis found - is this really a laptop?' }

if ($expBrand) {
    if ($cs.Manufacturer -match [regex]::Escape($expBrand)) { Pass 'Brand' $cs.Manufacturer }
    else { Bad 'Brand' ("{0} (advertised {1})" -f $cs.Manufacturer, $expBrand) }
}
if ($expModel) {
    $hay = "$($cs.Model) $($csp.Name) $($csp.Version)"
    if ($hay -match [regex]::Escape($expModel)) { Pass 'Model' $hay.Trim() }
    else { Warn 'Model' ("{0} - could not match '{1}'; confirm with the serial lookup" -f $hay.Trim(), $expModel) }
}
if ($expCpu) {
    $norm = { param($s) ($s -replace '[\s\(\)\-]|\(R\)|\(TM\)', '').ToLower() }
    if ((& $norm $cpu.Name) -like ("*" + (& $norm $expCpu) + "*")) { Pass 'CPU' $cpu.Name.Trim() }
    else { Bad 'CPU' ("{0} (advertised {1})" -f $cpu.Name.Trim(), $expCpu) }
} else { Info 'CPU' $cpu.Name.Trim() }
Info 'Cores / threads' ("{0} / {1}" -f $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)

if ($expRam) {
    if ([math]::Abs($ramGB - [double]$expRam) -le 1) { Pass 'RAM' "$ramGB GB" } else { Bad 'RAM' "$ramGB GB (advertised $expRam GB)" }
} else { Info 'RAM' "$ramGB GB" }
$mods = Get-CimInstance Win32_PhysicalMemory
if ($mods) {
    foreach ($m in $mods) { Info 'RAM module' ("{0} GB {1} MHz {2} ({3})" -f [math]::Round($m.Capacity/1GB), $m.Speed, $m.Manufacturer, $m.DeviceLocator) }
    $speeds = $mods | Select-Object -ExpandProperty Speed -Unique
    if (@($speeds).Count -gt 1) { Warn 'RAM modules' 'Mismatched speeds - upgraded/mixed RAM' }
}

$gpus = Get-CimInstance Win32_VideoController
foreach ($g in $gpus) { Info 'GPU' $g.Name }
if ($expGpu -and $expGpu -notmatch '^(none|no)$') {
    if (($gpus.Name -join ' ') -match [regex]::Escape($expGpu)) { Pass 'GPU' "$expGpu found" } else { Bad 'GPU' "'$expGpu' not found (see list above)" }
} elseif ($expGpu -match '^(none|no)$') { Info 'GPU' 'Integrated only advertised' }

if ($serial -and $serial -notmatch '^(To be filled|Default string|0+|None|System Serial Number)') { Pass 'Serial number' "$serial (compare with the laptop sticker + box)" }
else { Bad 'Serial number' "Missing/placeholder ('$serial') - board may have been replaced or re-flashed" }

if ($expYear) { Info 'Year' ("BIOS date {0}; expected {1}" -f $bios.ReleaseDate, $expYear) }

# ---------- OS ----------
Section '2. OPERATING SYSTEM'
Info 'Windows' ("{0} {1} build {2}" -f $os.Caption, $os.Version, $os.BuildNumber)
$lic = Get-CimInstance SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -and $_.Name -like 'Windows*' } | Select-Object -First 1
if ($lic -and $lic.LicenseStatus -eq 1) { Pass 'Windows activation' 'Licensed' } else { Warn 'Windows activation' 'Not activated or unknown' }
try { if (Confirm-SecureBootUEFI) { Pass 'Secure Boot' 'Enabled' } else { Warn 'Secure Boot' 'Disabled' } } catch { Warn 'Secure Boot' 'Not supported / need admin' }
$tpm = Get-Tpm
if ($tpm -and $tpm.TpmPresent) { Pass 'TPM' ("Present, ready={0}" -f $tpm.TpmReady) } else { Warn 'TPM' 'Not detected / need admin' }

# ---------- battery ----------
Section '3. BATTERY'
$bat = Get-CimInstance Win32_Battery
if (-not $bat) { Warn 'Battery' 'No battery detected' }
else {
    $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData).DesignedCapacity | Select-Object -First 1
    $full   = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity).FullChargedCapacity | Select-Object -First 1
    $cycles = (Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount).CycleCount | Select-Object -First 1

    if (-not $design -or -not $full -or $null -eq $cycles) {
        # fall back to powercfg battery report (XML)
        $xmlPath = Join-Path $env:TEMP 'batt-report.xml'
        powercfg /batteryreport /output $xmlPath /xml | Out-Null
        if (Test-Path $xmlPath) {
            [xml]$x = Get-Content $xmlPath
            $b = $x.BatteryReport.Batteries.Battery | Select-Object -First 1
            if (-not $design) { $design = [double]$b.DesignCapacity }
            if (-not $full)   { $full   = [double]$b.FullChargeCapacity }
            if ($null -eq $cycles) { $cycles = [int]$b.CycleCount }
            Remove-Item $xmlPath -Force
        }
    }
    Info 'Status' ("{0}% charge, BatteryStatus={1}" -f $bat.EstimatedChargeRemaining, $bat.BatteryStatus)
    if ($design -and $full -and $design -gt 0) {
        $health = [math]::Round(100 * $full / $design)
        Info 'Capacity' ("design {0} mWh, full-charge now {1} mWh" -f $design, $full)
        if ($health -ge $minHealth) { Pass 'Battery health' "$health% (min $minHealth%)" } else { Warn 'Battery health' "$health% is below your $minHealth% minimum - negotiate or walk" }
    } else { Warn 'Battery health' 'Could not read design/full capacity' }
    if ($null -ne $cycles -and $cycles -gt 0) {
        if ($cycles -le $maxCycles) { Pass 'Battery cycles' "$cycles (max $maxCycles)" } else { Warn 'Battery cycles' "$cycles exceeds your max of $maxCycles" }
    } else { Info 'Battery cycles' 'Not reported by this laptop (common) - use the vendor tool or powercfg /batteryreport' }
    $ps = (Get-CimInstance Win32_PortableBattery)
    if ($ps) { Info 'Battery maker' ("{0} {1}" -f $ps.Manufacturer, $ps.Name) }
    Info 'AC power' $(if ($bat.BatteryStatus -in 2,6,7,8,9) { 'Charger connected' } else { 'On battery (plug in charger and re-run to confirm charging)' })
}

# ---------- storage ----------
Section '4. STORAGE'
$disks = Get-PhysicalDisk
if (-not $disks) { Warn 'Storage' 'Could not read physical disks' }
foreach ($d in $disks) {
    $szGB = [math]::Round($d.Size / 1e9)
    Info 'Disk' ("{0} - {1} GB {2}/{3}" -f $d.FriendlyName, $szGB, $d.MediaType, $d.BusType)
    if ($d.HealthStatus -eq 'Healthy') { Pass 'Disk health' ("{0}: Healthy" -f $d.FriendlyName) } else { Bad 'Disk health' ("{0}: {1}" -f $d.FriendlyName, $d.HealthStatus) }
    $rel = $d | Get-StorageReliabilityCounter
    if ($rel) {
        $wear = $rel.Wear
        Info 'Disk wear/age' ("wear={0} powerOnHours={1} temp={2}C readErrors={3} writeErrors={4}" -f $wear, $rel.PowerOnHours, $rel.Temperature, $rel.ReadErrorsTotal, $rel.WriteErrorsTotal)
        if ($null -ne $wear -and $wear -ge 80) { Warn 'Disk wear' "$wear% used" }
        if ($rel.ReadErrorsTotal -gt 0 -or $rel.WriteErrorsTotal -gt 0) { Warn 'Disk errors' 'Read/write errors recorded' }
    } else { Info 'Disk counters' 'Not available (try running as Administrator)' }
}
if ($expStorage) {
    $exp = [double]$expStorage; if ($exp -le 4) { $exp = $exp * 1000 }
    $bootDisk = $disks | Sort-Object Size -Descending | Select-Object -First 1
    if ($bootDisk) {
        $g = $bootDisk.Size / 1e9
        if ($g -ge $exp * 0.9 -and $g -le $exp * 1.1) { Pass 'Storage capacity' ("{0} GB (advertised {1} GB class)" -f [math]::Round($g), $exp) }
        else { Bad 'Storage capacity' ("{0} GB (advertised {1} GB)" -f [math]::Round($g), $exp) }
    }
}
Get-Volume | Where-Object { $_.DriveLetter -and $_.Size } | ForEach-Object {
    Info 'Volume' ("{0}: {1} GB, {2} GB free" -f $_.DriveLetter, [math]::Round($_.Size/1GB), [math]::Round($_.SizeRemaining/1GB))
}

# ---------- management / ownership ----------
Section '5. MANAGEMENT / OWNERSHIP'
if ($cs.PartOfDomain) { Bad 'Domain joined' ("Joined to {0} - company laptop, must be removed" -f $cs.Domain) } else { Pass 'Domain joined' 'No' }
$dsreg = (dsregcmd /status) 2>$null | Out-String
if ($dsreg -match 'AzureAdJoined\s*:\s*YES') { Bad 'Entra/Azure AD' 'Joined to an organisation - walk away unless released' } elseif ($dsreg) { Pass 'Entra/Azure AD' 'Not joined' } else { Warn 'Entra/Azure AD' 'Could not query dsregcmd' }
if ($dsreg -match 'MdmUrl\s*:\s*\S+') { Bad 'MDM (Intune etc.)' 'MDM enrollment URL present' } else { Pass 'MDM (Intune etc.)' 'No MDM URL found' }
if (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' | Where-Object { $_.GetValue('ProviderID') }) { Warn 'MDM enrollments' 'Enrollment records exist in registry' }
$users = Get-LocalUser | Where-Object { $_.Enabled }
Info 'Local accounts' ($users.Name -join ', ')
$bl = Get-BitLockerVolume -MountPoint $env:SystemDrive
if ($bl) { Info 'BitLocker' ("{0} (if ON: seller must provide recovery/ sign out of their account)" -f $bl.ProtectionStatus) } else { Info 'BitLocker' 'Not readable without admin' }
Write-Host 'MANUAL: BIOS/UEFI supervisor password, manufacturer lock, or "Find My Device" tied to seller account -' -ForegroundColor Gray
Write-Host '        confirmed only by a factory reset (Settings > System > Recovery) + first-run setup.' -ForegroundColor Gray

# ---------- devices ----------
Section '6. DEVICE DETECTION'
$mon = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | Select-Object -First 1
if ($mon -and $mon.MaxHorizontalImageSize) {
    $diag = [math]::Round([math]::Sqrt([math]::Pow($mon.MaxHorizontalImageSize,2) + [math]::Pow($mon.MaxVerticalImageSize,2)) / 2.54, 1)
    Info 'Panel size' "$diag inch (from EDID)"
    if ($expScreen) { if ([math]::Abs($diag - [double]$expScreen) -le 0.7) { Pass 'Screen size' "$diag inch" } else { Bad 'Screen size' "$diag inch (advertised $expScreen)" } }
}
$vc = $gpus | Select-Object -First 1
if ($vc.CurrentHorizontalResolution) { Pass 'Display' ("{0}x{1} @ {2} Hz" -f $vc.CurrentHorizontalResolution, $vc.CurrentVerticalResolution, $vc.CurrentRefreshRate) } else { Warn 'Display' 'Could not read' }

if (Get-PnpDevice -Class Camera, Image -Status OK) { Pass 'Camera' 'Detected' } else { Warn 'Camera' 'Not detected' }
if (Get-PnpDevice -Class AudioEndpoint -Status OK) { Pass 'Audio' 'Endpoints present' } else { Warn 'Audio' 'No audio endpoints' }
if (Get-PnpDevice -Class Bluetooth -Status OK) { Pass 'Bluetooth' 'Detected' } else { Warn 'Bluetooth' 'Not detected' }
$wifi = Get-NetAdapter -Physical | Where-Object { $_.Name -match 'Wi-?Fi|Wireless' -or $_.InterfaceDescription -match 'Wireless|Wi-?Fi|802.11' }
if ($wifi) { Pass 'Wi-Fi hardware' $wifi[0].InterfaceDescription } else { Warn 'Wi-Fi hardware' 'Not detected' }
$kb = Get-PnpDevice -Class Keyboard -Status OK; $tp = Get-PnpDevice -Class HIDClass -Status OK | Where-Object { $_.FriendlyName -match 'touch|pad|precision' }
if ($kb) { Pass 'Keyboard device' 'Detected' } else { Warn 'Keyboard device' 'Not detected' }
if ($tp) { Pass 'Touchpad device' 'Detected' } else { Warn 'Touchpad device' 'Not detected' }
$fp = Get-PnpDevice -Class Biometric -Status OK
if ($fp) { Info 'Fingerprint/IR' ($fp.FriendlyName -join ', ') } else { Info 'Fingerprint/IR' 'None (fine if not advertised)' }
$problem = Get-PnpDevice -PresentOnly | Where-Object { $_.Status -eq 'Error' }
if ($problem) { Warn 'Device Manager' ("{0} device(s) with problems: {1}" -f @($problem).Count, (($problem | Select-Object -First 5 -ExpandProperty FriendlyName) -join '; ')) } else { Pass 'Device Manager' 'No problem devices' }

# ---------- crashes ----------
Section '7. CRASH / HARDWARE ERROR HISTORY (30 days)'
$since = (Get-Date).AddDays(-30)
$unexp = Get-WinEvent -FilterHashtable @{LogName='System'; Id=41; StartTime=$since} -MaxEvents 50
$bug   = Get-WinEvent -FilterHashtable @{LogName='System'; Id=1001; ProviderName='Microsoft-Windows-WER-SystemErrorReporting'; StartTime=$since} -MaxEvents 50
$whea  = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$since} -MaxEvents 50
$diskE = Get-WinEvent -FilterHashtable @{LogName='System'; Id=7,11,51,153; StartTime=$since} -MaxEvents 50
if (@($unexp).Count -eq 0) { Pass 'Unexpected shutdowns' 'None' } else { Warn 'Unexpected shutdowns' ("{0} (power loss / crash)" -f @($unexp).Count) }
if (@($bug).Count -eq 0)   { Pass 'Blue screens' 'None' } else { Warn 'Blue screens' ("{0} bugcheck event(s)" -f @($bug).Count) }
if (@($whea).Count -eq 0)  { Pass 'WHEA hardware errors' 'None' } else { Bad 'WHEA hardware errors' ("{0} - CPU/RAM/PCIe errors logged" -f @($whea).Count) }
if (@($diskE).Count -eq 0) { Pass 'Disk errors' 'None' } else { Warn 'Disk errors' ("{0} disk error event(s)" -f @($diskE).Count) }

# ---------- manual checklist ----------
$script:ManY = 0; $script:ManN = 0; $script:ManS = 0
function Manual($t) {
    $a = Read-Host "  $t [y=ok / n=problem / Enter=skip]"
    if ($a -match '^(y|yes)$') { $script:ManY++; Pass 'Manual' $t }
    elseif ($a -match '^(n|no)$') { $script:ManN++; Bad 'Manual' $t }
    else { $script:ManS++; Warn 'Manual' "$t - skipped" }
}
if ($runManual) {
    Section '8. MANUAL CHECKLIST'
    Write-Host 'Playing a test sound...'
    try { Add-Type -AssemblyName System.Speech; $sp = New-Object System.Speech.Synthesis.SpeechSynthesizer; $sp.Speak('Left speaker. Right speaker.') } catch { [console]::beep(800, 400) }
    Manual 'Heard the sound clearly from both speakers'
    Manual 'No dents, cracks, gaps, bulging or missing screws on the body'
    Manual 'Hinges are firm, lid holds any angle, no creaks'
    Manual 'Display: no dead pixels, flicker, lines, yellow tint or backlight bleed (try full white/black/red/green/blue)'
    Manual 'Every keyboard key works (test in Notepad / keyboardtester.com), backlight works'
    Manual 'Touchpad moves, clicks and gestures work across the whole surface'
    Manual 'Webcam shows an image (Camera app) and microphone records (Voice Recorder)'
    Manual 'Wi-Fi connects and loads a website; Bluetooth pairs with a device'
    Manual 'Every USB / USB-C / HDMI / SD / headphone port works (plug in something real)'
    Manual 'Charger is original, laptop charges, no heat or smell'
    Manual 'Fans spin, no grinding, temps sane after 5 min of stress (e.g. open several videos)'
    Manual 'Serial on the bottom sticker matches the serial above'
    Manual 'Manufacturer warranty/serial lookup shows the expected model'
    Manual 'BIOS/UEFI opens with NO password prompt'
    Manual 'After a factory reset: first-run setup shows NO previous account, company enrollment or lock'
}

# ---------- result ----------
Write-Host ''
Write-Host '============================================================'
Write-Host ' RESULT'
Write-Host '============================================================'
Write-Host ("OK {0} | CHECK {1} | FAIL {2}" -f $script:Ok, $script:Check, $script:Fail)
if ($script:Fail -gt 0)      { Write-Host 'OVERALL: FAIL - investigate before paying' -ForegroundColor Red }
elseif ($script:Check -gt 0) { Write-Host 'OVERALL: CHECK items before paying' -ForegroundColor Yellow }
else                         { Write-Host 'OVERALL: automated checks look good' -ForegroundColor Green }
if (-not $runManual) { Write-Host 'Manual checklist NOT run - physical, display, keyboard, ports and the reset/sign-in test are still required.' }
Write-Host 'This is a supporting audit, not a hardware certification. Never pay before the reset + first-run test passes.'

if ($openWarranty -and $serial) {
    Set-Clipboard -Value $serial
    $url = switch -Regex ($cs.Manufacturer) {
        'Dell'   { 'https://www.dell.com/support/home/' }
        'HP|Hewlett' { 'https://support.hp.com/checkwarranty' }
        'LENOVO' { 'https://pcsupport.lenovo.com/warrantylookup' }
        'ASUS'   { 'https://www.asus.com/support/' }
        'Acer'   { 'https://www.acer.com/support' }
        'Micro-Star|MSI' { 'https://www.msi.com/support' }
        default  { 'https://www.google.com/search?q=' + [uri]::EscapeDataString("$($cs.Manufacturer) warranty check serial") }
    }
    Write-Host "Serial copied to clipboard; opening $url"
    Start-Process $url
}
if ($report) { Stop-Transcript | Out-Null; Write-Host "Report saved: $report" }
